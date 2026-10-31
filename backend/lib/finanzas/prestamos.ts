// Préstamos que la persona le hace a otros, con o sin intereses.
//
// Cada préstamo guarda su historia en movimientos con fecha:
//  * desembolso: sale dinero hacia la otra persona (el inicial o "prestar más").
//  * abono: la persona devuelve dinero; se separa en capital e intereses.
//
// Mover dinero funciona como una transferencia: cambia el saldo de la cuenta pero
// no es gasto ni ingreso, porque sigue siendo dinero de la persona. Las ganancias
// se reconocen día a día a partir de interes_desde (ver ganancias.ts) y suman a lo
// que le deben; cobrar esos intereses solo los pasa de "por cobrar" a la cuenta.
// Lo que se debe lo calcula la app con los movimientos e interes_causado.

import type { FastifyInstance } from 'fastify';
import type { Pool, PoolConnection } from 'mysql2/promise';
import { hoyColombia, intentarPonerAlDia, ponerPrestamoAlDia, quitarGanancias } from './ganancias';
import { efectoEnCuenta, fechaValida } from './inversiones';

interface Log {
    info: (m: string) => void;
    error: (e: unknown, m?: string) => void;
}

const DDL = [
    `CREATE TABLE IF NOT EXISTS finanzas_prestamos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        persona VARCHAR(120) NOT NULL,
        tasa_mensual DECIMAL(6,3) NOT NULL DEFAULT 0,
        interes_desde DATE NULL,
        vencimiento DATE NULL,
        cerrado_en DATE NULL,
        nota VARCHAR(300) NOT NULL DEFAULT '',
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_prestamo_usuario (user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS finanzas_prestamo_movimientos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        prestamo_id INT NOT NULL,
        tipo VARCHAR(12) NOT NULL,
        capital DECIMAL(14,2) NOT NULL,
        interes DECIMAL(14,2) NOT NULL DEFAULT 0,
        fecha DATE NOT NULL,
        cuenta_id INT NULL,
        nota VARCHAR(300) NOT NULL DEFAULT '',
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_mov_prestamo (prestamo_id, fecha),
        CONSTRAINT fk_mov_prestamo FOREIGN KEY (prestamo_id) REFERENCES finanzas_prestamos(id) ON DELETE CASCADE
    )`
];

export async function migrarPrestamos(pool: Pool, log: Log) {
    for (const q of DDL) await pool.query(q);
    log.info('[Préstamos] Tablas listas');
}

/** Lo máximo que cabe en un saldo (DECIMAL(12,2)). */
const MONTO_MAXIMO = 9_999_999_999.99;

/** Cuánto cambia el saldo de la cuenta. En tarjetas de crédito el saldo es deuda. */
export function efectoPrestamo(tipoMovimiento: string, tipoCuenta: string, monto: number): number {
    return efectoEnCuenta(tipoMovimiento === 'desembolso' ? 'aporte' : 'retiro', tipoCuenta, monto);
}

export interface DatosPrestamo {
    persona: string;
    tasa_mensual: number;
    interes_desde: string | null;
    vencimiento: string | null;
    nota: string;
}

export function normalizarPrestamo(b: any): DatosPrestamo | string {
    const persona = String(b?.persona ?? '').trim();
    if (persona.length < 2) return 'Escribe a quién le prestaste';
    const tasa = b?.tasa_mensual == null || b.tasa_mensual === '' ? 0 : Number(b.tasa_mensual);
    if (!Number.isFinite(tasa) || tasa < 0 || tasa > 100) return 'El interés debe estar entre 0 y 100% al mes';
    const desde = b?.interes_desde == null || b.interes_desde === '' ? null : b.interes_desde;
    if (tasa > 0 && desde === null) return 'Elige desde qué fecha corren los intereses';
    if (desde !== null && !fechaValida(desde)) return 'La fecha de los intereses no es válida';
    const vencimiento = b?.vencimiento == null || b.vencimiento === '' ? null : b.vencimiento;
    if (vencimiento !== null && !fechaValida(vencimiento)) return 'La fecha de pago no es válida';
    return {
        persona: persona.slice(0, 120),
        tasa_mensual: Math.round(tasa * 1000) / 1000,
        interes_desde: tasa > 0 ? desde : null,
        vencimiento,
        nota: String(b?.nota ?? '').trim().slice(0, 300)
    };
}

export interface MovimientoPrestamo {
    tipo: string;
    capital: number;
    interes: number;
    fecha: string;
    cuenta_id: number | null;
    nota: string;
}

/** Valida un movimiento. Devuelve el mensaje de error si algo no está bien. */
export function normalizarMovimientoPrestamo(b: any): MovimientoPrestamo | string {
    const tipo = String(b?.tipo ?? '');
    if (tipo !== 'desembolso' && tipo !== 'abono') return 'Tipo de movimiento no válido';
    const capital = b?.capital == null ? 0 : Number(b.capital);
    const interes = b?.interes == null ? 0 : Number(b.interes);
    if (![capital, interes].every((n) => Number.isFinite(n) && n >= 0 && n <= MONTO_MAXIMO)) return 'El monto no es válido';
    if (tipo === 'desembolso' && (capital <= 0 || interes > 0)) return 'Escribe cuánto prestaste';
    if (capital + interes <= 0) return 'El abono debe ser mayor a 0';
    if (!fechaValida(b?.fecha)) return 'La fecha no es válida';
    const cuenta = b?.cuenta_id == null || b.cuenta_id === '' ? null : Number(b.cuenta_id);
    if (cuenta !== null && !Number.isInteger(cuenta)) return 'La cuenta no es válida';
    return {
        tipo,
        capital: Math.round(capital * 100) / 100,
        interes: Math.round(interes * 100) / 100,
        fecha: b.fecha,
        cuenta_id: cuenta,
        nota: String(b?.nota ?? '').trim().slice(0, 300)
    };
}

class ErrorRuta extends Error {
    constructor(readonly status: number, mensaje: string) {
        super(mensaje);
    }
}

export function registrarPrestamos(server: FastifyInstance, { pool }: { pool: Pool }) {
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
            return reply.status(500).send({ message: 'No se pudo guardar el préstamo. Inténtalo de nuevo.' });
        } finally {
            conn.release();
        }
    }

    /** Aplica (+1) o revierte (-1) lo que un movimiento movió en su cuenta. */
    async function moverCuenta(conn: PoolConnection, uid: number, m: { tipo: string; capital: unknown; interes: unknown; cuenta_id: number | null }, signo: 1 | -1) {
        if (m.cuenta_id == null) return;
        const [f]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ? FOR UPDATE', [m.cuenta_id, uid]);
        if (!f.length) {
            // Si la cuenta ya se borró no hay saldo que revertir; para mover dinero sí tiene que existir.
            if (signo === -1) return;
            throw new ErrorRuta(404, 'Cuenta no encontrada');
        }
        const delta = efectoPrestamo(m.tipo, f[0].tipo, Number(m.capital) + Number(m.interes)) * signo;
        await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [delta, m.cuenta_id, uid]);
    }

    /** Bloquea el préstamo para que dos abonos a la vez no se pisen. */
    async function prestamoDe(conn: PoolConnection, uid: number, id: any): Promise<number> {
        const [f]: any = await conn.execute('SELECT id FROM finanzas_prestamos WHERE id = ? AND user_id = ? FOR UPDATE', [id, uid]);
        if (!f.length) throw new ErrorRuta(404, 'Préstamo no encontrado');
        return f[0].id;
    }

    /** Rehace los intereses posteriores a [fecha]: desde ahí cambió lo que se debía. */
    async function recalcular(conn: PoolConnection, uid: number, prestamoId: number, fecha: string | null) {
        await quitarGanancias(conn, uid, 'prestamo', prestamoId, fecha ?? undefined);
        await ponerPrestamoAlDia(conn, uid, prestamoId, hoyColombia());
    }

    /** Lo que dejó el cambio tiene que tener sentido; si no, se deshace todo. */
    async function verificar(conn: PoolConnection, uid: number, prestamoId: number) {
        const [f]: any = await conn.execute(
            `SELECT COALESCE(SUM(CASE tipo WHEN 'desembolso' THEN capital ELSE -capital END), 0) AS pendiente,
                    COALESCE(SUM(interes), 0) AS cobrado,
                    COALESCE(SUM(tipo = 'desembolso'), 0) AS desembolsos
             FROM finanzas_prestamo_movimientos WHERE prestamo_id = ? AND user_id = ?`,
            [prestamoId, uid]
        );
        if (Number(f[0].desembolsos) === 0) throw new ErrorRuta(400, 'Un préstamo necesita un monto prestado. Si no aplica, elimina el préstamo completo.');
        if (Number(f[0].pendiente) < -0.005) throw new ErrorRuta(400, 'El capital abonado supera lo que falta por pagar');
        const [g]: any = await conn.execute(
            `SELECT COALESCE(SUM(t.monto), 0) AS causado FROM finanzas_ganancias g
             JOIN finanzas_transacciones t ON t.id = g.transaccion_id WHERE g.origen = 'prestamo' AND g.origen_id = ? AND g.user_id = ?`,
            [prestamoId, uid]
        );
        // Un peso de margen por los redondeos de cada día.
        if (Number(f[0].cobrado) > Number(g[0].causado) + 1) throw new ErrorRuta(400, 'Los intereses cobrados superan los acumulados');
    }

    server.get('/api/finanzas/prestamos', auth, async (req: any) => {
        const uid = req.user.id;
        await intentarPonerAlDia(pool, uid, server.log as any);
        const [prestamos]: any = await pool.query(
            `SELECT p.id, p.persona, p.tasa_mensual, p.nota, DATE_FORMAT(p.interes_desde, '%Y-%m-%d') AS interes_desde,
                    DATE_FORMAT(p.vencimiento, '%Y-%m-%d') AS vencimiento, DATE_FORMAT(p.cerrado_en, '%Y-%m-%d') AS cerrado_en,
                    (SELECT COALESCE(SUM(t.monto), 0) FROM finanzas_ganancias g JOIN finanzas_transacciones t ON t.id = g.transaccion_id
                     WHERE g.origen = 'prestamo' AND g.origen_id = p.id AND g.user_id = p.user_id) AS interes_causado
             FROM finanzas_prestamos p WHERE p.user_id = ? ORDER BY p.id DESC`,
            [uid]
        );
        const [movimientos]: any = await pool.query(
            `SELECT m.id, m.prestamo_id, m.tipo, m.capital, m.interes, DATE_FORMAT(m.fecha, '%Y-%m-%d') AS fecha, m.cuenta_id, m.nota, c.nombre AS cuenta_nombre
             FROM finanzas_prestamo_movimientos m
             LEFT JOIN finanzas_cuentas c ON c.id = m.cuenta_id AND c.user_id = m.user_id
             WHERE m.user_id = ?
             ORDER BY m.fecha, m.id`,
            [uid]
        );
        return prestamos.map((p: any) => ({
            ...p,
            tasa_mensual: Number(p.tasa_mensual),
            interes_causado: Number(p.interes_causado),
            movimientos: movimientos
                .filter((m: any) => m.prestamo_id === p.id)
                .map((m: any) => ({ ...m, capital: Number(m.capital), interes: Number(m.interes) }))
        }));
    });

    // Nuevo préstamo con su primer desembolso: queda la fecha, el monto y de dónde salió.
    server.post('/api/finanzas/prestamos', auth, async (req: any, reply) => {
        const datos = normalizarPrestamo(req.body);
        if (typeof datos === 'string') return reply.status(400).send({ message: datos });
        const m = normalizarMovimientoPrestamo({ capital: req.body?.capital, fecha: req.body?.fecha, cuenta_id: req.body?.cuenta_id, tipo: 'desembolso' });
        if (typeof m === 'string') return reply.status(400).send({ message: m });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [r]: any = await conn.execute(
                'INSERT INTO finanzas_prestamos (user_id, persona, tasa_mensual, interes_desde, vencimiento, nota) VALUES (?, ?, ?, ?, ?, ?)',
                [uid, datos.persona, datos.tasa_mensual, datos.interes_desde, datos.vencimiento, datos.nota]
            );
            await moverCuenta(conn, uid, m, 1);
            await conn.execute('INSERT INTO finanzas_prestamo_movimientos (user_id, prestamo_id, tipo, capital, fecha, cuenta_id) VALUES (?, ?, ?, ?, ?, ?)', [uid, r.insertId, m.tipo, m.capital, m.fecha, m.cuenta_id]);
            await ponerPrestamoAlDia(conn, uid, r.insertId, hoyColombia());
            return { id: r.insertId };
        });
    });

    // Cambiar la tasa o la fecha rehace los intereses: si estaba mal, se corrige todo.
    server.put('/api/finanzas/prestamos/:id', auth, async (req: any, reply) => {
        const datos = normalizarPrestamo(req.body);
        if (typeof datos === 'string') return reply.status(400).send({ message: datos });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const id = await prestamoDe(conn, uid, req.params.id);
            await conn.execute('UPDATE finanzas_prestamos SET persona = ?, tasa_mensual = ?, interes_desde = ?, vencimiento = ?, nota = ? WHERE id = ? AND user_id = ?', [datos.persona, datos.tasa_mensual, datos.interes_desde, datos.vencimiento, datos.nota, id, uid]);
            await recalcular(conn, uid, id, null);
            await verificar(conn, uid, id);
            return { ok: true };
        });
    });

    // Dejar de cobrarlo (se saldó de otra forma o se dio por perdido), o reabrirlo.
    server.post('/api/finanzas/prestamos/:id/cerrar', auth, async (req: any, reply) => {
        const cerrado = req.body?.cerrado !== false;
        const fecha = cerrado ? req.body?.fecha : null;
        if (cerrado && !fechaValida(fecha)) return reply.status(400).send({ message: 'La fecha no es válida' });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const id = await prestamoDe(conn, uid, req.params.id);
            await conn.execute('UPDATE finanzas_prestamos SET cerrado_en = ? WHERE id = ? AND user_id = ?', [fecha, id, uid]);
            if (cerrado) await quitarGanancias(conn, uid, 'prestamo', id, fecha);
            else await ponerPrestamoAlDia(conn, uid, id, hoyColombia());
            return { ok: true };
        });
    });

    // Borrarlo deshace todo: las cuentas vuelven a como estaban y sus ganancias se van.
    server.delete('/api/finanzas/prestamos/:id', auth, async (req: any, reply) => {
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const id = await prestamoDe(conn, uid, req.params.id);
            const [filas]: any = await conn.execute('SELECT tipo, capital, interes, cuenta_id FROM finanzas_prestamo_movimientos WHERE prestamo_id = ? AND user_id = ?', [id, uid]);
            for (const m of filas) await moverCuenta(conn, uid, m, -1);
            await quitarGanancias(conn, uid, 'prestamo', id);
            await conn.execute('DELETE FROM finanzas_prestamos WHERE id = ? AND user_id = ?', [id, uid]);
            return { ok: true };
        });
    });

    server.post('/api/finanzas/prestamos/:id/movimientos', auth, async (req: any, reply) => {
        const m = normalizarMovimientoPrestamo(req.body);
        if (typeof m === 'string') return reply.status(400).send({ message: m });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const id = await prestamoDe(conn, uid, req.params.id);
            await moverCuenta(conn, uid, m, 1);
            const [r]: any = await conn.execute(
                'INSERT INTO finanzas_prestamo_movimientos (user_id, prestamo_id, tipo, capital, interes, fecha, cuenta_id, nota) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                [uid, id, m.tipo, m.capital, m.interes, m.fecha, m.cuenta_id, m.nota]
            );
            await recalcular(conn, uid, id, m.fecha);
            await verificar(conn, uid, id);
            return { id: r.insertId };
        });
    });

    /** El movimiento con su préstamo ya bloqueado. */
    async function movimientoDe(conn: PoolConnection, uid: number, id: any) {
        const [f]: any = await conn.execute(
            `SELECT id, prestamo_id, tipo, capital, interes, cuenta_id, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha FROM finanzas_prestamo_movimientos WHERE id = ? AND user_id = ?`,
            [id, uid]
        );
        if (!f.length) throw new ErrorRuta(404, 'Movimiento no encontrado');
        await prestamoDe(conn, uid, f[0].prestamo_id);
        return f[0];
    }

    // Corregir: se revierte lo anterior y se aplica lo nuevo, en una sola operación.
    server.put('/api/finanzas/prestamo-movimientos/:id', auth, async (req: any, reply) => {
        const m = normalizarMovimientoPrestamo(req.body);
        if (typeof m === 'string') return reply.status(400).send({ message: m });
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const mov = await movimientoDe(conn, uid, req.params.id);
            await moverCuenta(conn, uid, mov, -1);
            await moverCuenta(conn, uid, m, 1);
            await conn.execute(
                'UPDATE finanzas_prestamo_movimientos SET tipo = ?, capital = ?, interes = ?, fecha = ?, cuenta_id = ?, nota = ? WHERE id = ? AND user_id = ?',
                [m.tipo, m.capital, m.interes, m.fecha, m.cuenta_id, m.nota, mov.id, uid]
            );
            await recalcular(conn, uid, mov.prestamo_id, mov.fecha < m.fecha ? mov.fecha : m.fecha);
            await verificar(conn, uid, mov.prestamo_id);
            return { ok: true };
        });
    });

    server.delete('/api/finanzas/prestamo-movimientos/:id', auth, async (req: any, reply) => {
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const mov = await movimientoDe(conn, uid, req.params.id);
            await moverCuenta(conn, uid, mov, -1);
            await conn.execute('DELETE FROM finanzas_prestamo_movimientos WHERE id = ? AND user_id = ?', [mov.id, uid]);
            await recalcular(conn, uid, mov.prestamo_id, mov.fecha);
            await verificar(conn, uid, mov.prestamo_id);
            return { ok: true };
        });
    });
}
