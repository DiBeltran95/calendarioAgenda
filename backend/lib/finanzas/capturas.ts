// Pagos capturados automáticamente para registrarlos en Finanzas.
//
// Ni Apple ni Google permiten a una app leer las compras de Apple Pay o
// Google Wallet. Lo que sí existe, y es lo que usan las apps de finanzas:
//  * iPhone (iOS 17+): una automatización de la app Atajos con el disparador
//    "Transacción" de Wallet. En cada pago con Apple Pay el Atajo envía monto,
//    comercio y tarjeta a POST /api/capturas/atajo con la clave personal del
//    usuario en la cabecera X-Clave (no necesita sesión ni push).
//  * Android: la app lee (con permiso del usuario) las notificaciones de
//    Google Wallet y de los bancos, las interpreta y las sube a POST /api/capturas.
// Cada pago queda "pendiente" hasta que el usuario le asigna categoría y
// cuenta en la app (que crea la transacción con la ruta de siempre).

import crypto from 'crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool } from 'mysql2/promise';
import { publicar } from '../tiempoReal';

interface Log {
    info: (m: string) => void;
    error: (e: unknown, m?: string) => void;
}

const DDL = [
    `CREATE TABLE IF NOT EXISTS finanzas_capturas (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        origen VARCHAR(20) NOT NULL,
        tipo VARCHAR(10) NOT NULL DEFAULT 'gasto',
        monto DECIMAL(14,2) NOT NULL,
        moneda VARCHAR(5) NOT NULL DEFAULT 'COP',
        comercio VARCHAR(120) NOT NULL DEFAULT '',
        tarjeta VARCHAR(80) NOT NULL DEFAULT '',
        app VARCHAR(80) NOT NULL DEFAULT '',
        texto VARCHAR(500) NOT NULL DEFAULT '',
        fecha DATETIME NOT NULL,
        estado VARCHAR(12) NOT NULL DEFAULT 'pendiente',
        transaccion_id INT NULL,
        categoria VARCHAR(50) NULL,
        cuenta_id INT NULL,
        huella CHAR(40) NOT NULL,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_captura (user_id, huella),
        KEY idx_captura_estado (user_id, estado, fecha)
    )`,
    `CREATE TABLE IF NOT EXISTS finanzas_capturas_claves (
        user_id INT PRIMARY KEY,
        clave CHAR(40) NOT NULL UNIQUE,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        usado TIMESTAMP NULL
    )`
];

export async function migrarCapturas(pool: Pool, log: Log) {
    for (const q of DDL) await pool.query(q);
    log.info('[Capturas] Tablas listas');
}

const ORIGENES = new Set(['apple_pay', 'android', 'manual']);
const MAX_LOTE = 50;

/**
 * Convierte un monto escrito como lo muestran iOS o los bancos a número:
 * "$25.000", "$ 25.000,50", "COP 1.250.000", "25,000.00", "$12.5", "25000".
 */
export function montoDesdeTexto(v: unknown): number | null {
    if (typeof v === 'number') return Number.isFinite(v) && v > 0 ? Math.round(v * 100) / 100 : null;
    if (typeof v !== 'string') return null;
    let s = v.replace(/[^\d.,]/g, '');
    if (!s) return null;
    const ultPunto = s.lastIndexOf('.');
    const ultComa = s.lastIndexOf(',');
    const sep = Math.max(ultPunto, ultComa);
    // Decimal solo si hay 1–2 cifras tras el último separador; si no, son miles.
    if (sep >= 0 && s.length - sep - 1 <= 2 && s.length - sep - 1 > 0) {
        s = s.slice(0, sep).replace(/[.,]/g, '') + '.' + s.slice(sep + 1);
    } else {
        s = s.replace(/[.,]/g, '');
    }
    const n = Number(s);
    return Number.isFinite(n) && n > 0 ? Math.round(n * 100) / 100 : null;
}

const texto = (v: unknown, max: number) => (typeof v === 'string' ? v.replace(/\s+/g, ' ').trim().slice(0, max) : '');

/** Fecha ISO o "ahora" (UTC) → DATETIME de MySQL. Rechaza fechas absurdas. */
function fechaDe(v: unknown): string {
    const d = typeof v === 'string' || typeof v === 'number' ? new Date(v) : new Date();
    const ahora = Date.now();
    const ok = !Number.isNaN(d.getTime()) && d.getTime() < ahora + 86_400_000 && d.getTime() > ahora - 90 * 86_400_000;
    return (ok ? d : new Date()).toISOString().slice(0, 19).replace('T', ' ');
}

export interface CapturaEntrada {
    origen: string;
    tipo: 'gasto' | 'ingreso';
    monto: number;
    comercio: string;
    tarjeta: string;
    app: string;
    texto: string;
    fecha: string;
    huella: string;
}

/** Valida y normaliza un pago recibido. Devuelve null si no sirve. */
export function normalizarCaptura(b: any, origenPorDefecto: string): CapturaEntrada | null {
    if (!b || typeof b !== 'object') return null;
    const monto = montoDesdeTexto(b.monto);
    if (!monto || monto > 1_000_000_000) return null;
    const origen = ORIGENES.has(b.origen) ? b.origen : origenPorDefecto;
    const comercio = texto(b.comercio, 120);
    const tarjeta = texto(b.tarjeta, 80);
    const fecha = fechaDe(b.fecha);
    // La misma compra puede llegar dos veces (Atajo repetido, notificación
    // actualizada): la huella la identifica por contenido, minuto incluido.
    const huella = crypto
        .createHash('sha1')
        .update(texto(b.huella, 200) || [origen, monto.toFixed(2), comercio.toLowerCase(), tarjeta.toLowerCase(), fecha.slice(0, 16)].join('|'))
        .digest('hex');
    return {
        origen,
        tipo: b.tipo === 'ingreso' ? 'ingreso' : 'gasto',
        monto,
        comercio,
        tarjeta,
        app: texto(b.app, 80),
        texto: texto(b.texto, 500),
        fecha,
        huella
    };
}

const SELECT = `SELECT id, origen, tipo, monto, moneda, comercio, tarjeta, app, texto,
        DATE_FORMAT(fecha, '%Y-%m-%dT%H:%i:%sZ') AS fecha, estado, transaccion_id, categoria, cuenta_id
    FROM finanzas_capturas`;

const fila = (r: any) => ({ ...r, monto: Number(r.monto) });

export function registrarCapturas(server: FastifyInstance, deps: { pool: Pool }) {
    const { pool } = deps;
    const auth = { preValidation: [(server as any).authenticate] };

    async function guardar(userId: number, entradas: CapturaEntrada[]) {
        const nuevas: any[] = [];
        for (const e of entradas) {
            const [r]: any = await pool.query(
                `INSERT IGNORE INTO finanzas_capturas (user_id, origen, tipo, monto, comercio, tarjeta, app, texto, fecha, huella)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [userId, e.origen, e.tipo, e.monto, e.comercio, e.tarjeta, e.app, e.texto, e.fecha, e.huella]
            );
            if (r.affectedRows === 1) {
                const [[f]]: any = await pool.query(`${SELECT} WHERE id = ?`, [r.insertId]);
                nuevas.push(fila(f));
            }
        }
        // La app abierta lo muestra al instante ("Pago detectado").
        for (const c of nuevas) publicar(userId, 'captura', { captura: c });
        return nuevas;
    }

    // Atajo de iPhone: sin sesión, con la clave personal.
    server.post('/api/capturas/atajo', async (req: any, reply) => {
        const clave = String(req.headers['x-clave'] ?? req.body?.clave ?? '').trim();
        if (!/^[a-f0-9]{40}$/.test(clave)) return reply.status(401).send({ message: 'Falta la clave del atajo. Cópiala desde la app (Finanzas → Pagos automáticos).' });
        const [[k]]: any = await pool.query('SELECT user_id FROM finanzas_capturas_claves WHERE clave = ?', [clave]);
        if (!k) return reply.status(401).send({ message: 'Clave inválida. Genera una nueva en la app y actualiza el atajo.' });
        const e = normalizarCaptura({ ...req.body, origen: 'apple_pay' }, 'apple_pay');
        if (!e) return reply.status(400).send({ message: 'No se encontró un monto válido' });
        await pool.query('UPDATE finanzas_capturas_claves SET usado = NOW() WHERE user_id = ?', [k.user_id]);
        const nuevas = await guardar(k.user_id, [e]);
        // Texto corto: el Atajo puede mostrarlo como notificación.
        return { ok: true, nueva: nuevas.length > 0, mensaje: `Pago de ${e.comercio || 'Apple Pay'} guardado. Clasifícalo en Agendaservi.` };
    });

    // App Android: lote de notificaciones ya interpretadas.
    server.post('/api/capturas', auth, async (req: any, reply) => {
        const lista = Array.isArray(req.body?.capturas) ? req.body.capturas.slice(0, MAX_LOTE) : [];
        const entradas = lista.map((b: any) => normalizarCaptura(b, 'android')).filter(Boolean) as CapturaEntrada[];
        if (lista.length && !entradas.length) return reply.status(400).send({ message: 'Ningún pago válido' });
        const nuevas = await guardar(req.user.id, entradas);
        return { recibidas: lista.length, nuevas: nuevas.length };
    });

    server.get('/api/capturas', auth, async (req: any) => {
        const estado = ['pendiente', 'registrada', 'descartada'].includes(req.query?.estado) ? req.query.estado : 'pendiente';
        const [rows]: any = await pool.query(`${SELECT} WHERE user_id = ? AND estado = ? ORDER BY fecha DESC LIMIT 200`, [req.user.id, estado]);
        return rows.map(fila);
    });

    /**
     * Marca un pago como registrado (tras crear la transacción) o descartado.
     * Se guarda la categoría y la cuenta elegidas: así la app aprende qué
     * sugerir la próxima vez para el mismo comercio o tarjeta.
     */
    server.put('/api/capturas/:id', auth, async (req: any, reply) => {
        const estado = req.body?.estado;
        if (!['registrada', 'descartada', 'pendiente'].includes(estado)) return reply.status(400).send({ message: 'Estado inválido' });
        const [r]: any = await pool.query(
            'UPDATE finanzas_capturas SET estado = ?, transaccion_id = ?, categoria = ?, cuenta_id = ? WHERE id = ? AND user_id = ?',
            [estado, req.body?.transaccion_id ?? null, texto(req.body?.categoria, 50) || null, req.body?.cuenta_id ?? null, req.params.id, req.user.id]
        );
        if (!r.affectedRows) return reply.status(404).send({ message: 'Pago no encontrado' });
        const [[f]]: any = await pool.query(`${SELECT} WHERE id = ?`, [req.params.id]);
        return fila(f);
    });

    /** Lo aprendido: categoría y cuenta usadas por comercio y por tarjeta. */
    server.get('/api/capturas/preferencias', auth, async (req: any) => {
        const [rows]: any = await pool.query(
            `SELECT comercio, tarjeta, categoria, cuenta_id FROM finanzas_capturas
             WHERE user_id = ? AND estado = 'registrada' AND categoria IS NOT NULL ORDER BY fecha DESC LIMIT 300`,
            [req.user.id]
        );
        return rows;
    });

    server.get('/api/capturas/clave', auth, async (req: any) => {
        const [[k]]: any = await pool.query('SELECT clave, usado FROM finanzas_capturas_claves WHERE user_id = ?', [req.user.id]);
        if (k) return { clave: k.clave, usado: k.usado };
        const clave = crypto.randomBytes(20).toString('hex');
        await pool.query('INSERT INTO finanzas_capturas_claves (user_id, clave) VALUES (?, ?)', [req.user.id, clave]);
        return { clave, usado: null };
    });

    // Nueva clave: la anterior deja de funcionar (si se compartió por error).
    server.post('/api/capturas/clave', auth, async (req: any) => {
        const clave = crypto.randomBytes(20).toString('hex');
        await pool.query('INSERT INTO finanzas_capturas_claves (user_id, clave) VALUES (?, ?) ON DUPLICATE KEY UPDATE clave = VALUES(clave), usado = NULL', [req.user.id, clave]);
        return { clave, usado: null };
    });
}
