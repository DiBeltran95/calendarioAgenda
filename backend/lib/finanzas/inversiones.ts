// Inversiones y patrimonio: ganado, una casa, un vehículo, un negocio…
//
// Cada inversión guarda su historia en movimientos con fecha y monto:
//  * aporte: entra dinero a la inversión; sale de una cuenta o, sin cuenta, es
//    algo que la persona ya tenía.
//  * retiro: venta de una parte; el dinero llega a una cuenta (o a ninguna).
//  * venta: se vende todo y la inversión queda cerrada.
//  * valoracion: "hoy vale esto"; no mueve dinero de ninguna cuenta.
//
// Mover dinero a una inversión funciona como una transferencia: cambia el saldo
// de la cuenta pero NO es un gasto del mes (el dinero sigue siendo patrimonio).
// El valor actual y la ganancia los calcula la app a partir de los movimientos.

import type { FastifyInstance } from 'fastify';
import type { Pool, PoolConnection } from 'mysql2/promise';

interface Log {
    info: (m: string) => void;
    error: (e: unknown, m?: string) => void;
}

const DDL = [
    `CREATE TABLE IF NOT EXISTS finanzas_inversiones (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        nombre VARCHAR(120) NOT NULL,
        tipo VARCHAR(20) NOT NULL DEFAULT 'otro',
        nota VARCHAR(300) NOT NULL DEFAULT '',
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_inversion_usuario (user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS finanzas_inversion_movimientos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        inversion_id INT NOT NULL,
        tipo VARCHAR(12) NOT NULL,
        monto DECIMAL(14,2) NOT NULL,
        fecha DATE NOT NULL,
        cuenta_id INT NULL,
        nota VARCHAR(300) NOT NULL DEFAULT '',
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_mov_inversion (inversion_id, fecha),
        CONSTRAINT fk_mov_inversion FOREIGN KEY (inversion_id) REFERENCES finanzas_inversiones(id) ON DELETE CASCADE
    )`
];

export async function migrarInversiones(pool: Pool, log: Log) {
    for (const q of DDL) await pool.query(q);
    log.info('[Inversiones] Tablas listas');
}

const TIPOS = new Set(['ganado', 'inmueble', 'vehiculo', 'negocio', 'otro']);
const TIPOS_MOVIMIENTO = new Set(['aporte', 'retiro', 'venta', 'valoracion']);

/** Lo máximo que cabe en el saldo de una cuenta (DECIMAL(12,2)). */
const MONTO_MAXIMO = 9_999_999_999.99;

/** Cuánto cambia el saldo de la cuenta. En tarjetas de crédito el saldo es deuda. */
export function efectoEnCuenta(tipoMovimiento: string, tipoCuenta: string, monto: number): number {
    if (tipoMovimiento === 'valoracion') return 0;
    const saleDinero = tipoMovimiento === 'aporte';
    const credito = tipoCuenta === 'tarjeta_credito';
    return saleDinero === credito ? monto : -monto;
}

export function fechaValida(v: unknown): v is string {
    if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
    const [a, m, d] = v.split('-').map(Number) as [number, number, number];
    const f = new Date(Date.UTC(a, m - 1, d));
    return f.getUTCFullYear() === a && f.getUTCMonth() === m - 1 && f.getUTCDate() === d;
}

export interface MovimientoEntrada {
    tipo: string;
    monto: number;
    fecha: string;
    cuenta_id: number | null;
    nota: string;
}

/** Valida un movimiento. Devuelve el mensaje de error si algo no está bien. */
export function normalizarMovimiento(b: any): MovimientoEntrada | string {
    const tipo = String(b?.tipo ?? '');
    if (!TIPOS_MOVIMIENTO.has(tipo)) return 'Tipo de movimiento no válido';
    const monto = Number(b?.monto);
    const minimo = tipo === 'valoracion' ? 0 : 0.01;
    if (!Number.isFinite(monto) || monto < minimo || monto > MONTO_MAXIMO) {
        return tipo === 'valoracion' ? 'Escribe cuánto vale hoy' : 'El monto debe ser mayor a 0';
    }
    if (!fechaValida(b?.fecha)) return 'La fecha no es válida';
    const cuenta = b?.cuenta_id == null || b.cuenta_id === '' ? null : Number(b.cuenta_id);
    if (cuenta !== null && !Number.isInteger(cuenta)) return 'La cuenta no es válida';
    return {
        tipo,
        monto: Math.round(monto * 100) / 100,
        fecha: b.fecha,
        // Actualizar el valor no mueve dinero de ninguna cuenta.
        cuenta_id: tipo === 'valoracion' ? null : cuenta,
        nota: String(b?.nota ?? '').trim().slice(0, 300)
    };
}

/** Error de negocio con su código HTTP: deshace la operación y se le explica a la app. */
class ErrorRuta extends Error {
    constructor(readonly status: number, mensaje: string) {
        super(mensaje);
    }
}

export function registrarInversiones(server: FastifyInstance, { pool }: { pool: Pool }) {
    const auth = { preValidation: [(server as any).authenticate] };

    /** Todo o nada: si algo falla, ni el movimiento ni el saldo quedan a medias. */
    async function atomico(reply: any, f: (c: PoolConnection) => Promise<unknown>) {
        const conn = await pool.getConnection();
        try {
            await conn.beginTransaction();
            const r = await f(conn);
            await conn.commit();
            return r;
        } catch (e) {
            await conn.rollback();
            if (e instanceof ErrorRuta) return reply.status(e.status).send({ message: e.message });
            server.log.error(e);
            return reply.status(500).send({ message: 'No se pudo guardar la inversión. Inténtalo de nuevo.' });
        } finally {
            conn.release();
        }
    }

    /** Aplica (+1) o revierte (-1) el efecto de un movimiento en su cuenta. */
    async function moverCuenta(conn: PoolConnection, userId: number, m: { tipo: string; monto: number; cuenta_id: number | null }, signo: 1 | -1) {
        if (m.cuenta_id == null) return;
        const [filas]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ? FOR UPDATE', [m.cuenta_id, userId]);
        if (!filas.length) {
            // Si la cuenta ya se borró no hay saldo que revertir; para mover dinero sí tiene que existir.
            if (signo === -1) return;
            throw new ErrorRuta(404, 'Cuenta no encontrada');
        }
        const delta = efectoEnCuenta(m.tipo, filas[0].tipo, m.monto) * signo;
        await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [delta, m.cuenta_id, userId]);
    }

    async function insertarMovimiento(conn: PoolConnection, userId: number, inversionId: number, m: MovimientoEntrada) {
        await moverCuenta(conn, userId, m, 1);
        const [r]: any = await conn.execute(
            'INSERT INTO finanzas_inversion_movimientos (user_id, inversion_id, tipo, monto, fecha, cuenta_id, nota) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, inversionId, m.tipo, m.monto, m.fecha, m.cuenta_id, m.nota]
        );
        return r.insertId as number;
    }

    function datosInversion(b: any): { nombre: string; tipo: string; nota: string } | string {
        const nombre = String(b?.nombre ?? '').trim();
        if (nombre.length < 2) return 'Escribe un nombre para la inversión';
        const tipo = String(b?.tipo ?? 'otro');
        if (!TIPOS.has(tipo)) return 'Tipo de inversión no válido';
        return { nombre: nombre.slice(0, 120), tipo, nota: String(b?.nota ?? '').trim().slice(0, 300) };
    }

    // Lista con su historia, del movimiento más antiguo al más reciente.
    server.get('/api/finanzas/inversiones', auth, async (req: any) => {
        const uid = req.user.id;
        const [inversiones]: any = await pool.query(
            'SELECT id, nombre, tipo, nota FROM finanzas_inversiones WHERE user_id = ? ORDER BY id DESC',
            [uid]
        );
        const [movimientos]: any = await pool.query(
            `SELECT m.id, m.inversion_id, m.tipo, m.monto, DATE_FORMAT(m.fecha, '%Y-%m-%d') AS fecha, m.cuenta_id, m.nota, c.nombre AS cuenta_nombre
             FROM finanzas_inversion_movimientos m
             LEFT JOIN finanzas_cuentas c ON c.id = m.cuenta_id AND c.user_id = m.user_id
             WHERE m.user_id = ?
             ORDER BY m.fecha, m.id`,
            [uid]
        );
        return inversiones.map((i: any) => ({
            ...i,
            movimientos: movimientos.filter((m: any) => m.inversion_id === i.id).map((m: any) => ({ ...m, monto: Number(m.monto) }))
        }));
    });

    // Nueva inversión con su primer aporte: queda la fecha, el monto y de dónde salió.
    server.post('/api/finanzas/inversiones', auth, async (req: any, reply) => {
        const datos = datosInversion(req.body);
        if (typeof datos === 'string') return reply.status(400).send({ message: datos });
        const aporte = normalizarMovimiento({ ...req.body, tipo: 'aporte' });
        if (typeof aporte === 'string') return reply.status(400).send({ message: aporte });
        return atomico(reply, async (conn) => {
            const [r]: any = await conn.execute('INSERT INTO finanzas_inversiones (user_id, nombre, tipo, nota) VALUES (?, ?, ?, ?)', [req.user.id, datos.nombre, datos.tipo, datos.nota]);
            await insertarMovimiento(conn, req.user.id, r.insertId, aporte);
            return { id: r.insertId };
        });
    });

    server.put('/api/finanzas/inversiones/:id', auth, async (req: any, reply) => {
        const datos = datosInversion(req.body);
        if (typeof datos === 'string') return reply.status(400).send({ message: datos });
        const [r]: any = await pool.execute('UPDATE finanzas_inversiones SET nombre = ?, tipo = ?, nota = ? WHERE id = ? AND user_id = ?', [datos.nombre, datos.tipo, datos.nota, req.params.id, req.user.id]);
        if (!r.affectedRows) return reply.status(404).send({ message: 'Inversión no encontrada' });
        return { ok: true };
    });

    // Borrarla deshace lo que movió: las cuentas vuelven a como estaban.
    server.delete('/api/finanzas/inversiones/:id', auth, async (req: any, reply) => {
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [filas]: any = await conn.execute('SELECT tipo, monto, cuenta_id FROM finanzas_inversion_movimientos WHERE inversion_id = ? AND user_id = ?', [req.params.id, uid]);
            const [r]: any = await conn.execute('DELETE FROM finanzas_inversiones WHERE id = ? AND user_id = ?', [req.params.id, uid]);
            if (!r.affectedRows) throw new ErrorRuta(404, 'Inversión no encontrada');
            for (const m of filas) await moverCuenta(conn, uid, { ...m, monto: Number(m.monto) }, -1);
            return { ok: true };
        });
    });

    server.post('/api/finanzas/inversiones/:id/movimientos', auth, async (req: any, reply) => {
        const m = normalizarMovimiento(req.body);
        if (typeof m === 'string') return reply.status(400).send({ message: m });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [inv]: any = await conn.execute('SELECT id FROM finanzas_inversiones WHERE id = ? AND user_id = ?', [req.params.id, uid]);
            if (!inv.length) throw new ErrorRuta(404, 'Inversión no encontrada');
            return { id: await insertarMovimiento(conn, uid, inv[0].id, m) };
        });
    });

    // Corregir: se revierte lo anterior y se aplica lo nuevo, en una sola operación.
    server.put('/api/finanzas/inversion-movimientos/:id', auth, async (req: any, reply) => {
        const m = normalizarMovimiento(req.body);
        if (typeof m === 'string') return reply.status(400).send({ message: m });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [filas]: any = await conn.execute('SELECT tipo, monto, cuenta_id FROM finanzas_inversion_movimientos WHERE id = ? AND user_id = ?', [req.params.id, uid]);
            if (!filas.length) throw new ErrorRuta(404, 'Movimiento no encontrado');
            await moverCuenta(conn, uid, { ...filas[0], monto: Number(filas[0].monto) }, -1);
            await moverCuenta(conn, uid, m, 1);
            await conn.execute('UPDATE finanzas_inversion_movimientos SET tipo = ?, monto = ?, fecha = ?, cuenta_id = ?, nota = ? WHERE id = ? AND user_id = ?', [m.tipo, m.monto, m.fecha, m.cuenta_id, m.nota, req.params.id, uid]);
            return { ok: true };
        });
    });

    server.delete('/api/finanzas/inversion-movimientos/:id', auth, async (req: any, reply) => {
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [filas]: any = await conn.execute('SELECT tipo, monto, cuenta_id FROM finanzas_inversion_movimientos WHERE id = ? AND user_id = ?', [req.params.id, uid]);
            if (!filas.length) throw new ErrorRuta(404, 'Movimiento no encontrado');
            await moverCuenta(conn, uid, { ...filas[0], monto: Number(filas[0].monto) }, -1);
            await conn.execute('DELETE FROM finanzas_inversion_movimientos WHERE id = ? AND user_id = ?', [req.params.id, uid]);
            return { ok: true };
        });
    });
}
