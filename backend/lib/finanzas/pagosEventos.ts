// Pagar un evento de dinero (arriendo, una cuota de Addi…) desde la app: se elige
// de qué cuenta salió el dinero y los saldos quedan al día.
//
//  * Cuota de una compra a crédito (el evento tiene tarjeta_credito_id): es una
//    transferencia de la cuenta a la tarjeta. La deuda baja y NO es un gasto
//    nuevo, porque la compra ya se contó como gasto el día que se hizo.
//  * Otro gasto: un gasto normal en la cuenta elegida.
//  * Un ingreso esperado: un ingreso en la cuenta elegida.
//
// Queda anotado en eventos_pagos para poder deshacerlo con exactitud. La ruta
// anterior (toggle-pago) y el enlace público de confirmación no cambian.

import type { FastifyInstance } from 'fastify';
import type { Pool, PoolConnection } from 'mysql2/promise';
import { fechaValida } from './inversiones';

interface Log {
    info: (m: string) => void;
    error: (e: unknown, m?: string) => void;
}

export async function migrarPagosEventos(pool: Pool, log: Log) {
    await pool.query(`CREATE TABLE IF NOT EXISTS eventos_pagos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        evento_id INT NOT NULL,
        transaccion_id INT NULL,
        transferencia_id INT NULL,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_pago_evento (evento_id)
    )`);
    log.info('[Pagos de eventos] Tabla lista');
}

/** Lo máximo que cabe en una transacción (DECIMAL(12,2)). */
const MONTO_MAXIMO = 9_999_999_999.99;

/** Cuánto cambia el saldo. En tarjetas de crédito el saldo es deuda. */
export function deltaSaldo(entraDinero: boolean, tipoCuenta: string | undefined, monto: number): number {
    return entraDinero === (tipoCuenta === 'tarjeta_credito') ? -monto : monto;
}

class ErrorRuta extends Error {
    constructor(readonly status: number, mensaje: string) {
        super(mensaje);
    }
}

export function registrarPagosEventos(server: FastifyInstance, { pool }: { pool: Pool }) {
    const auth = { preValidation: [(server as any).authenticate] };

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
            return reply.status(500).send({ message: 'No se pudo registrar el pago. Inténtalo de nuevo.' });
        } finally {
            conn.release();
        }
    }

    async function tipoDeCuenta(conn: PoolConnection, userId: number, id: number): Promise<string | undefined> {
        const [f]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ? FOR UPDATE', [id, userId]);
        return f[0]?.tipo;
    }

    async function moverSaldo(conn: PoolConnection, userId: number, id: number, delta: number) {
        await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [delta, id, userId]);
    }

    server.post('/api/events/:id/pagar', auth, async (req: any, reply) => {
        const uid = req.user.id;
        const b = req.body ?? {};
        return atomico(reply, async (conn) => {
            const [filas]: any = await conn.execute(
                `SELECT id, titulo, costo, tipo_transaccion, estado_pago, tarjeta_credito_id, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha
                 FROM eventos WHERE id = ? AND user_id = ? FOR UPDATE`,
                [req.params.id, uid]
            );
            const ev = filas[0];
            if (!ev) throw new ErrorRuta(404, 'Evento no encontrado');
            if (ev.tipo_transaccion !== 'gasto' && ev.tipo_transaccion !== 'ingreso') throw new ErrorRuta(400, 'Este evento no tiene un pago');
            if (ev.estado_pago === 'pagado') throw new ErrorRuta(409, 'Este evento ya está pagado');

            const monto = b.monto === undefined ? Number(ev.costo) : Number(b.monto);
            if (!Number.isFinite(monto) || monto < 0 || monto > MONTO_MAXIMO) throw new ErrorRuta(400, 'El monto no es válido');
            const fecha = b.fecha ?? ev.fecha;
            if (!fechaValida(fecha)) throw new ErrorRuta(400, 'La fecha no es válida');

            let transaccionId: number | null = null;
            let transferenciaId: number | null = null;
            const cuentaId = b.cuenta_id == null ? null : Number(b.cuenta_id);

            if (cuentaId !== null) {
                if (monto <= 0) throw new ErrorRuta(400, 'El monto debe ser mayor a 0');
                const tipo = await tipoDeCuenta(conn, uid, cuentaId);
                if (!tipo) throw new ErrorRuta(404, 'Cuenta no encontrada');
                const ingreso = ev.tipo_transaccion === 'ingreso';
                const tarjeta = !ingreso && ev.tarjeta_credito_id ? ev.tarjeta_credito_id : null;
                const tipoTarjeta = tarjeta ? await tipoDeCuenta(conn, uid, tarjeta) : undefined;

                if (tipoTarjeta) {
                    if (cuentaId === tarjeta) throw new ErrorRuta(400, 'Elige otra cuenta: una deuda no se paga con ella misma');
                    const [r]: any = await conn.execute(
                        'INSERT INTO finanzas_transferencias (user_id, cuenta_origen_id, cuenta_destino_id, monto, descripcion, fecha) VALUES (?, ?, ?, ?, ?, ?)',
                        [uid, cuentaId, tarjeta, monto, `Pago: ${ev.titulo}`.slice(0, 255), fecha]
                    );
                    transferenciaId = r.insertId;
                    await moverSaldo(conn, uid, cuentaId, deltaSaldo(false, tipo, monto));
                    await moverSaldo(conn, uid, tarjeta, deltaSaldo(true, tipoTarjeta, monto));
                } else {
                    const [r]: any = await conn.execute(
                        'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria) VALUES (?, ?, ?, ?, ?, ?, ?)',
                        [uid, cuentaId, ev.tipo_transaccion, monto, String(ev.titulo).slice(0, 255), fecha, String(b.categoria || 'otros').slice(0, 50)]
                    );
                    transaccionId = r.insertId;
                    await moverSaldo(conn, uid, cuentaId, deltaSaldo(ingreso, tipo, monto));
                }
            }

            await conn.execute('UPDATE eventos SET estado_pago = ?, costo = ? WHERE id = ? AND user_id = ?', ['pagado', monto, ev.id, uid]);
            // Pudo quedar uno viejo si la web lo volvió a pendiente; ese dinero ya no se toca.
            await conn.execute('DELETE FROM eventos_pagos WHERE evento_id = ?', [ev.id]);
            if (cuentaId !== null) {
                await conn.execute('INSERT INTO eventos_pagos (user_id, evento_id, transaccion_id, transferencia_id) VALUES (?, ?, ?, ?)', [uid, ev.id, transaccionId, transferenciaId]);
            }
            return { ok: true, movio_dinero: cuentaId !== null };
        });
    });

    // Vuelve a pendiente y deshace lo que ese pago movió. Si el pago no movió
    // dinero (o se hizo antes de esta función) solo cambia el estado.
    server.delete('/api/events/:id/pago', auth, async (req: any, reply) => {
        const uid = req.user.id;
        return atomico(reply, async (conn) => {
            const [r]: any = await conn.execute('UPDATE eventos SET estado_pago = ? WHERE id = ? AND user_id = ?', ['pendiente', req.params.id, uid]);
            if (!r.affectedRows) throw new ErrorRuta(404, 'Evento no encontrado');
            const [pagos]: any = await conn.execute('SELECT id, transaccion_id, transferencia_id FROM eventos_pagos WHERE evento_id = ? AND user_id = ?', [req.params.id, uid]);
            const pago = pagos[0];
            let devolvio = false;
            if (pago?.transferencia_id) {
                const [t]: any = await conn.execute('SELECT monto, cuenta_origen_id, cuenta_destino_id FROM finanzas_transferencias WHERE id = ? AND user_id = ?', [pago.transferencia_id, uid]);
                if (t[0]) {
                    const monto = Number(t[0].monto);
                    await moverSaldo(conn, uid, t[0].cuenta_origen_id, -deltaSaldo(false, await tipoDeCuenta(conn, uid, t[0].cuenta_origen_id), monto));
                    await moverSaldo(conn, uid, t[0].cuenta_destino_id, -deltaSaldo(true, await tipoDeCuenta(conn, uid, t[0].cuenta_destino_id), monto));
                    await conn.execute('DELETE FROM finanzas_transferencias WHERE id = ?', [pago.transferencia_id]);
                    devolvio = true;
                }
            }
            if (pago?.transaccion_id) {
                const [t]: any = await conn.execute('SELECT tipo, monto, cuenta_id FROM finanzas_transacciones WHERE id = ? AND user_id = ?', [pago.transaccion_id, uid]);
                if (t[0]) {
                    if (t[0].cuenta_id) {
                        await moverSaldo(conn, uid, t[0].cuenta_id, -deltaSaldo(t[0].tipo === 'ingreso', await tipoDeCuenta(conn, uid, t[0].cuenta_id), Number(t[0].monto)));
                    }
                    await conn.execute('DELETE FROM finanzas_transacciones WHERE id = ?', [pago.transaccion_id]);
                    devolvio = true;
                }
            }
            if (pago) await conn.execute('DELETE FROM eventos_pagos WHERE id = ?', [pago.id]);
            return { ok: true, devolvio };
        });
    });
}
