// Ganancias automáticas, día a día, de lo que genera rendimiento:
//  * Cuentas (Nu, una cajita, un CDT…): interés compuesto sobre el saldo a partir
//    de una tasa efectiva anual. Cada día es un ingreso en la cuenta: sube el saldo.
//  * Préstamos con interés: interés simple mensual sobre el capital pendiente. Cada
//    día es un ingreso sin cuenta, porque la plata aún no ha llegado: se suma a lo
//    que la persona debe. Cuando la paga, pasa de "por cobrar" a la cuenta.
//
// Cada día que corre genera una fila en finanzas_transacciones, así se refleja en
// el historial, en el mes y en el patrimonio sin más cambios. finanzas_ganancias
// anota de dónde salió cada una: evita contar un día dos veces y permite quitarlas
// todas si la cuenta o el préstamo se eliminan. Un día cuenta cuando ya pasó su
// anterior: lo creado hoy empieza a sumar mañana.

import type { FastifyInstance } from 'fastify';
import type { Pool, PoolConnection } from 'mysql2/promise';
import { fechaValida } from './inversiones';
import { deltaSaldo } from './pagosEventos';

interface Log {
    info: (m: string) => void;
    error: (e: unknown, m?: string) => void;
}

export type Origen = 'cuenta' | 'prestamo';

export const CATEGORIA_RENDIMIENTOS = 'rendimientos';
export const CATEGORIA_INTERESES = 'intereses_prestamo';

/** Hoy en Colombia, sea cual sea la zona horaria del servidor. */
export function hoyColombia(ahora = new Date()): string {
    return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota', year: 'numeric', month: '2-digit', day: '2-digit' }).format(ahora);
}

export function sumarDias(fecha: string, dias: number): string {
    const [a, m, d] = fecha.split('-').map(Number) as [number, number, number];
    return new Date(Date.UTC(a, m - 1, d + dias)).toISOString().slice(0, 10);
}

const redondear = (v: number) => Math.round(v * 100) / 100;

/** Lo que gana un saldo en un día con una tasa efectiva anual. */
export function rendimientoDiario(saldo: number, tasaEA: number): number {
    if (saldo <= 0 || tasaEA <= 0) return 0;
    return redondear(saldo * (Math.pow(1 + tasaEA / 100, 1 / 365) - 1));
}

/** Lo que causa un capital en un día con un interés simple mensual (mes de 30 días). */
export function interesDiario(capital: number, tasaMensual: number): number {
    if (capital <= 0 || tasaMensual <= 0) return 0;
    return redondear((capital * tasaMensual) / 100 / 30);
}

/** Cuenta Nu de la persona que pidió empezar a calcularla desde este día. */
const CORREO_CUENTA_NU = 'di.beltran@udla.edu.co';
const NU_DESDE = '2026-10-30';

export async function activarCuentaNu(pool: Pool) {
    await pool.execute(
        `UPDATE finanzas_cuentas c JOIN usuarios u ON u.id = c.user_id
         SET c.ganancias_desde = ?, c.ganancias_tasa = c.interes_tasa
         WHERE LOWER(TRIM(u.email)) = ? AND c.tipo <> 'tarjeta_credito'
           AND (LOWER(TRIM(c.nombre)) = 'nu' OR LOWER(TRIM(c.nombre)) LIKE 'nu %' OR LOWER(TRIM(c.nombre)) LIKE 'nubank%')`,
        [NU_DESDE, CORREO_CUENTA_NU]
    );
}

export async function migrarGanancias(pool: Pool, log: Log) {
    await pool.query(`CREATE TABLE IF NOT EXISTS finanzas_ganancias (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        origen VARCHAR(10) NOT NULL,
        origen_id INT NOT NULL,
        fecha DATE NOT NULL,
        transaccion_id INT NULL,
        UNIQUE KEY uq_ganancia_dia (origen, origen_id, fecha),
        KEY idx_ganancia_usuario (user_id)
    )`);
    // Columnas propias y no interes_tasa: la web la pone en 0 al editar una cuenta que no sea CDT.
    let nuevas = false;
    for (const columna of ['ganancias_tasa DECIMAL(6,3) NOT NULL DEFAULT 0', 'ganancias_desde DATE NULL']) {
        try {
            await pool.query(`ALTER TABLE finanzas_cuentas ADD COLUMN ${columna}`);
            nuevas = true;
        } catch (e: any) {
            if (e.code !== 'ER_DUP_FIELDNAME') throw e;
        }
    }
    // Solo la vez que se crean las columnas: si luego la apagan, sigue apagada.
    if (nuevas) await activarCuentaNu(pool).catch((e) => log.error(e, '[Ganancias] No se pudo activar la cuenta Nu'));
    log.info('[Ganancias] Listas');
}

/** Registra la ganancia de un día. */
async function anotar(conn: PoolConnection, uid: number, origen: Origen, origenId: number, fecha: string, monto: number, cuentaId: number | null, descripcion: string, categoria: string) {
    const [t]: any = await conn.execute(
        'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [uid, cuentaId, 'ingreso', monto, descripcion.slice(0, 255), fecha, categoria]
    );
    await conn.execute('INSERT INTO finanzas_ganancias (user_id, origen, origen_id, fecha, transaccion_id) VALUES (?, ?, ?, ?, ?)', [uid, origen, origenId, fecha, t.insertId]);
}

async function ultimoDia(conn: PoolConnection, origen: Origen, origenId: number): Promise<string | null> {
    const [f]: any = await conn.execute("SELECT DATE_FORMAT(MAX(fecha), '%Y-%m-%d') AS ultimo FROM finanzas_ganancias WHERE origen = ? AND origen_id = ?", [origen, origenId]);
    return f[0].ultimo;
}

/**
 * Quita lo ya sumado (todo, o lo posterior a [despuesDe]) con sus ingresos, y
 * devuelve a los saldos lo que esos ingresos habían sumado.
 */
export async function quitarGanancias(conn: PoolConnection, uid: number, origen: Origen, origenId: number, despuesDe?: string): Promise<number> {
    const filtro = despuesDe ? 'AND g.fecha > ?' : '';
    const args = despuesDe ? [uid, origen, origenId, despuesDe] : [uid, origen, origenId];
    const [porCuenta]: any = await conn.execute(
        `SELECT t.cuenta_id, c.tipo, SUM(t.monto) AS total
         FROM finanzas_ganancias g
         JOIN finanzas_transacciones t ON t.id = g.transaccion_id AND t.user_id = g.user_id
         LEFT JOIN finanzas_cuentas c ON c.id = t.cuenta_id AND c.user_id = t.user_id
         WHERE g.user_id = ? AND g.origen = ? AND g.origen_id = ? ${filtro}
         GROUP BY t.cuenta_id, c.tipo`,
        args
    );
    let quitado = 0;
    for (const f of porCuenta) {
        const total = Number(f.total);
        quitado += total;
        if (f.cuenta_id != null && f.tipo) {
            await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [-deltaSaldo(true, f.tipo, total), f.cuenta_id, uid]);
        }
    }
    await conn.execute(
        `DELETE t FROM finanzas_transacciones t JOIN finanzas_ganancias g ON g.transaccion_id = t.id AND g.user_id = t.user_id
         WHERE g.user_id = ? AND g.origen = ? AND g.origen_id = ? ${filtro}`,
        args
    );
    await conn.execute(`DELETE g FROM finanzas_ganancias g WHERE g.user_id = ? AND g.origen = ? AND g.origen_id = ? ${filtro}`, args);
    return quitado;
}

/** Suma a la cuenta lo que falte hasta hoy. La llamada debe ir dentro de una transacción. */
export async function ponerCuentaAlDia(conn: PoolConnection, uid: number, cuentaId: number, hoy: string): Promise<number> {
    const [f]: any = await conn.execute(
        `SELECT nombre, tipo, saldo, ganancias_tasa, DATE_FORMAT(ganancias_desde, '%Y-%m-%d') AS desde, plazo_dias, DATE_FORMAT(fecha_inicio, '%Y-%m-%d') AS inicio
         FROM finanzas_cuentas WHERE id = ? AND user_id = ? FOR UPDATE`,
        [cuentaId, uid]
    );
    const c = f[0];
    const tasa = Number(c?.ganancias_tasa ?? 0);
    if (!c || !c.desde || tasa <= 0 || c.tipo === 'tarjeta_credito') return 0;
    const ultimo = await ultimoDia(conn, 'cuenta', cuentaId);
    const fin = c.tipo === 'cdt' && Number(c.plazo_dias) > 0 && c.inicio ? [hoy, sumarDias(c.inicio, Number(c.plazo_dias))].sort()[0]! : hoy;
    let saldo = Number(c.saldo);
    let sumado = 0;
    let dias = 0;
    for (let d = sumarDias(ultimo && ultimo > c.desde ? ultimo : c.desde, 1); d <= fin; d = sumarDias(d, 1)) {
        const monto = rendimientoDiario(saldo, tasa);
        if (monto <= 0) continue;
        await anotar(conn, uid, 'cuenta', cuentaId, d, monto, cuentaId, `Ganancia: ${c.nombre}`, CATEGORIA_RENDIMIENTOS);
        saldo = redondear(saldo + monto);
        sumado = redondear(sumado + monto);
        dias++;
    }
    if (sumado > 0) await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [sumado, cuentaId, uid]);
    return dias;
}

/** Causa los intereses que falten hasta hoy. La llamada debe ir dentro de una transacción. */
export async function ponerPrestamoAlDia(conn: PoolConnection, uid: number, prestamoId: number, hoy: string): Promise<number> {
    const [f]: any = await conn.execute(
        `SELECT persona, tasa_mensual, DATE_FORMAT(interes_desde, '%Y-%m-%d') AS desde, DATE_FORMAT(cerrado_en, '%Y-%m-%d') AS cerrado
         FROM finanzas_prestamos WHERE id = ? AND user_id = ? FOR UPDATE`,
        [prestamoId, uid]
    );
    const p = f[0];
    const tasa = Number(p?.tasa_mensual ?? 0);
    if (!p || !p.desde || tasa <= 0) return 0;
    const [movs]: any = await conn.execute(
        `SELECT tipo, capital, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha FROM finanzas_prestamo_movimientos WHERE prestamo_id = ? AND user_id = ? ORDER BY fecha, id`,
        [prestamoId, uid]
    );
    const ultimo = await ultimoDia(conn, 'prestamo', prestamoId);
    const fin = p.cerrado && p.cerrado < hoy ? p.cerrado : hoy;
    let i = 0;
    let capital = 0;
    let dias = 0;
    for (let d = sumarDias(ultimo && ultimo > p.desde ? ultimo : p.desde, 1); d <= fin; d = sumarDias(d, 1)) {
        // El interés de un día corre sobre lo que se debía al terminar el anterior.
        while (i < movs.length && movs[i].fecha < d) {
            capital += movs[i].tipo === 'desembolso' ? Number(movs[i].capital) : -Number(movs[i].capital);
            i++;
        }
        const monto = interesDiario(capital, tasa);
        if (monto <= 0) continue;
        await anotar(conn, uid, 'prestamo', prestamoId, d, monto, null, `Intereses: ${p.persona}`, CATEGORIA_INTERESES);
        dias++;
    }
    return dias;
}

async function atomica<T>(pool: Pool, f: (c: PoolConnection) => Promise<T>): Promise<T> {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const r = await f(conn);
        await conn.commit();
        return r;
    } catch (e) {
        await conn.rollback();
        throw e;
    } finally {
        conn.release();
    }
}

/** Personas ya revisadas hoy, para no consultar en cada petición. */
const revisados = new Map<number, string>();

/** Pone al día todo lo que genera ganancias de una persona. Repetirlo no suma de nuevo. */
export async function ponerUsuarioAlDia(pool: Pool, uid: number, hoy = hoyColombia()): Promise<number> {
    if (revisados.get(uid) === hoy) return 0;
    const [cuentas]: any = await pool.execute('SELECT id FROM finanzas_cuentas WHERE user_id = ? AND ganancias_desde IS NOT NULL AND ganancias_tasa > 0', [uid]);
    const [prestamos]: any = await pool.execute('SELECT id FROM finanzas_prestamos WHERE user_id = ? AND tasa_mensual > 0 AND interes_desde IS NOT NULL', [uid]);
    let dias = 0;
    for (const c of cuentas) dias += await atomica(pool, (conn) => ponerCuentaAlDia(conn, uid, c.id, hoy));
    for (const p of prestamos) dias += await atomica(pool, (conn) => ponerPrestamoAlDia(conn, uid, p.id, hoy));
    revisados.set(uid, hoy);
    return dias;
}

/** Para las pruebas y para cuando algo cambia lo que hay que calcular. */
export function olvidarRevision(uid?: number) {
    if (uid === undefined) revisados.clear();
    else revisados.delete(uid);
}

/** Lo mismo, sin que un fallo aquí tumbe la petición que lo pidió: los datos siguen sirviendo. */
export async function intentarPonerAlDia(pool: Pool, uid: number, log: Pick<Log, 'error'>) {
    try {
        await ponerUsuarioAlDia(pool, uid);
    } catch (e) {
        log.error(e, '[Ganancias] No se pudo poner al día');
    }
}

/** Revisa cada hora, para que todo quede al día aunque nadie abra la app. */
export function iniciarGanancias(pool: Pool, log: Pick<Log, 'error'>) {
    const revisar = async () => {
        try {
            const [filas]: any = await pool.query(
                `SELECT user_id FROM finanzas_cuentas WHERE ganancias_desde IS NOT NULL AND ganancias_tasa > 0
                 UNION SELECT user_id FROM finanzas_prestamos WHERE tasa_mensual > 0 AND interes_desde IS NOT NULL`
            );
            for (const f of filas) await intentarPonerAlDia(pool, f.user_id, log);
        } catch (e) {
            log.error(e, '[Ganancias] Falló la revisión');
        }
    };
    void revisar();
    setInterval(revisar, 60 * 60 * 1000).unref();
}

/** Al eliminar una cuenta: sus ganancias también se van. */
export async function quitarGananciasDeCuenta(pool: Pool, uid: number, cuentaId: number) {
    await atomica(pool, (conn) => quitarGanancias(conn, uid, 'cuenta', cuentaId));
}

export function registrarGanancias(server: FastifyInstance, { pool }: { pool: Pool }) {
    const auth = { preValidation: [(server as any).authenticate] };

    // Activa, cambia o apaga las ganancias de una cuenta.
    //  * recalcular: rehace lo ya sumado con la tasa y la fecha nuevas (la tasa estaba
    //    mal). Sin él, lo anterior se queda y lo nuevo aplica de aquí en adelante.
    //  * sin fecha se apaga; quitar: también borra lo que ya se había sumado.
    server.put('/api/finanzas/cuentas/:id/ganancias', auth, async (req: any, reply) => {
        const uid = req.user.id;
        const b = req.body ?? {};
        const desde = b.desde == null || b.desde === '' ? null : b.desde;
        if (desde !== null && !fechaValida(desde)) return reply.status(400).send({ message: 'La fecha no es válida' });
        const tasa = desde === null ? 0 : Number(b.tasa);
        if (!Number.isFinite(tasa) || tasa < 0 || tasa > 100) return reply.status(400).send({ message: 'La tasa debe estar entre 0 y 100%' });
        if (desde !== null && tasa === 0) return reply.status(400).send({ message: 'Escribe la tasa efectiva anual' });
        const [f]: any = await pool.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [req.params.id, uid]);
        if (!f.length) return reply.status(404).send({ message: 'Cuenta no encontrada' });
        if (f[0].tipo === 'tarjeta_credito') return reply.status(400).send({ message: 'Una tarjeta de crédito no genera ganancias' });
        const id = Number(req.params.id);
        const quitado = await atomica(pool, async (conn) => {
            const borrar = desde === null ? b.quitar === true : b.recalcular === true;
            const q = borrar ? await quitarGanancias(conn, uid, 'cuenta', id) : 0;
            await conn.execute('UPDATE finanzas_cuentas SET ganancias_tasa = ?, ganancias_desde = ? WHERE id = ? AND user_id = ?', [tasa, desde, id, uid]);
            await ponerCuentaAlDia(conn, uid, id, hoyColombia());
            return q;
        });
        return { ok: true, quitado };
    });
}
