// Tareas del cron para el agendamiento de citas (tablas agenda_* del backend).
//
//  · Cola de notificaciones (push_cola): el backend encola avisos para la app
//    (nueva cita, cancelación…) y aquí se envían por push. Si el usuario no
//    tiene la app con push activo, se usa el WhatsApp de respaldo.
//  · Recordatorio al cliente por WhatsApp ~2 horas antes de su cita.
//  · Las reservas que no se confirmaron en 15 minutos se marcan como expiradas.

const push = require('./push');

const WEB_BASE = (process.env.WEB_BASE_URL || 'https://agendaservi.com').replace(/\/+$/, '');
const MINUTOS_CODIGO = 15;

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

function fechaLegible(fecha) {
    const d = new Date(`${fecha}T12:00:00Z`);
    return `${DIAS[d.getUTCDay()]} ${d.getUTCDate()} de ${MESES[d.getUTCMonth()]}`;
}

function hora12(hora) {
    const [h, m] = String(hora).split(':').map(Number);
    return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${h >= 12 ? 'p. m.' : 'a. m.'}`;
}

function pesos(n) {
    return '$' + Math.round(Number(n || 0)).toLocaleString('es-CO').replace(/,/g, '.');
}

function mensajeRecordatorio(c) {
    const l = [`📅 *${fechaLegible(c.fecha)}* · 🕒 *${hora12(c.hora_inicio)}*`, `✨ ${c.servicio_nombre} (${c.duracion_min} min)`, `👤 Con ${c.profesional}`];
    if (Number(c.precio) > 0) l.push(`💵 ${pesos(c.precio)}`);
    if (c.direccion) l.push(`📍 ${c.direccion}`);
    const nombre = String(c.cliente_nombre).trim().split(/\s+/)[0];
    return (
        `⏰ *Recordatorio de tu cita*\n\n` +
        `${nombre}, en un rato tienes cita en *${c.negocio}*:\n\n` +
        `${l.join('\n')}\n\n` +
        `Si no puedes asistir, cancela aquí para liberar el espacio:\n${WEB_BASE}/cita/${c.token}`
    );
}

/** Minutos que faltan (hora de Bogotá, UTC−5) para una fecha y hora. */
function minutosHasta(fecha, hora, ahora = Date.now()) {
    return (new Date(`${fecha}T${hora}:00-05:00`).getTime() - ahora) / 60000;
}

let avisoSinTablas = false;
function sinTablas(err) {
    if (err && err.code === 'ER_NO_SUCH_TABLE') {
        if (!avisoSinTablas) console.log('[Citas] Las tablas de agendamiento aún no existen (el backend las crea al arrancar).');
        avisoSinTablas = true;
        return true;
    }
    return false;
}

/**
 * Envía los avisos encolados por el backend. Push a todos los teléfonos del
 * usuario; si no tiene ninguno activo (o FCM no está configurado), WhatsApp.
 */
async function procesarColaPush(pool, enviarWhatsApp) {
    let filas;
    try {
        [filas] = await pool.query(
            `SELECT q.*, u.whatsapp FROM push_cola q JOIN usuarios u ON u.id = q.user_id
             WHERE q.procesado = 0 AND q.creado > NOW() - INTERVAL 1 DAY ORDER BY q.id LIMIT 50`
        );
    } catch (err) {
        if (!sinTablas(err)) console.error('[Citas] Error leyendo la cola de push:', err);
        return;
    }
    for (const q of filas) {
        try {
            let entregado = false;
            let pendiente = false;
            if (push.configurado()) {
                const [devs] = await pool.query('SELECT id, token FROM dispositivos_push WHERE user_id = ? AND avisos = 1', [q.user_id]);
                for (const d of devs) {
                    const r = await push.enviar(
                        push.construirMensaje(d.token, { tipo: 'cita', clave: q.clave, titulo: q.titulo, cuerpo: q.cuerpo, canal: q.canal, ruta: q.ruta, ttlSeg: 6 * 3600 })
                    );
                    if (r === 'ok') {
                        entregado = true;
                        await pool.query('UPDATE dispositivos_push SET ultimo_envio = NOW(), confirmado = 1 WHERE id = ?', [d.id]);
                    } else if (r === 'invalido') {
                        await pool.query('DELETE FROM dispositivos_push WHERE id = ?', [d.id]);
                    } else {
                        pendiente = true;
                    }
                }
            }
            // Falló por algo temporal: se reintenta en la próxima vuelta (máx. 5).
            if (!entregado && pendiente && q.intentos < 4) {
                await pool.query('UPDATE push_cola SET intentos = intentos + 1 WHERE id = ?', [q.id]);
                continue;
            }
            if (!entregado && q.whatsapp_respaldo && q.whatsapp) {
                entregado = await enviarWhatsApp(q.whatsapp, q.whatsapp_respaldo);
            }
            await pool.query('UPDATE push_cola SET procesado = 1, intentos = intentos + 1 WHERE id = ?', [q.id]);
            console.log(`[Citas] Aviso ${q.clave} para user ${q.user_id}: ${entregado ? 'entregado' : 'sin canal disponible'}`);
        } catch (err) {
            console.error(`[Citas] Error procesando aviso ${q.id}:`, err);
        }
    }
}

/** Recordatorio al cliente ~2 h antes (solo si la cita se agendó con más anticipación). */
async function recordarCitas(pool, enviarWhatsApp, ahora = Date.now()) {
    const hoy = new Date(ahora - 5 * 3600 * 1000).toISOString().slice(0, 10);
    let citas;
    try {
        [citas] = await pool.query(
            `SELECT c.id, c.token, DATE_FORMAT(c.fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(c.hora_inicio, '%H:%i') AS hora_inicio, c.servicio_nombre, c.duracion_min,
                    c.precio, c.cliente_nombre, c.cliente_whatsapp, n.nombre AS negocio, n.direccion, p.nombre AS profesional
             FROM agenda_citas c JOIN agenda_negocios n ON n.id = c.negocio_id JOIN agenda_profesionales p ON p.id = c.profesional_id
             WHERE c.estado = 'confirmada' AND c.cliente_whatsapp IS NOT NULL AND c.fecha BETWEEN ? AND DATE_ADD(?, INTERVAL 1 DAY)
               -- Quien agendó hace menos de 2 h no necesita recordatorio.
               AND c.confirmada_en < NOW() - INTERVAL 2 HOUR`,
            [hoy, hoy]
        );
    } catch (err) {
        if (!sinTablas(err)) console.error('[Citas] Error leyendo citas para recordatorio:', err);
        return;
    }
    for (const c of citas) {
        const faltan = minutosHasta(c.fecha, c.hora_inicio, ahora);
        if (faltan > 120 || faltan < 20) continue;
        try {
            await pool.query("INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES ('cita_recordatorio', ?, ?)", [c.id, c.fecha]);
        } catch (err) {
            if (err.code === 'ER_DUP_ENTRY') continue;
            throw err;
        }
        const ok = await enviarWhatsApp(c.cliente_whatsapp, mensajeRecordatorio(c));
        if (!ok) await pool.query("DELETE FROM notificaciones_enviadas WHERE tipo = 'cita_recordatorio' AND referencia_id = ? AND fecha_referencia = ?", [c.id, c.fecha]);
        else console.log(`[Citas] Recordatorio enviado para la cita ${c.id}`);
    }
}

/** Reservas sin confirmar a tiempo: liberan su turno (la disponibilidad ya las ignora). */
async function expirarPendientes(pool) {
    try {
        const [r] = await pool.query(
            `UPDATE agenda_citas SET estado = 'expirada', codigo = NULL WHERE estado = 'pendiente' AND creado < NOW() - INTERVAL ${MINUTOS_CODIGO} MINUTE`
        );
        if (r.affectedRows) console.log(`[Citas] ${r.affectedRows} reserva(s) sin confirmar expiradas.`);
    } catch (err) {
        if (!sinTablas(err)) console.error('[Citas] Error expirando reservas:', err);
    }
}

async function tareasCitas(pool, enviarWhatsApp) {
    await expirarPendientes(pool);
    await procesarColaPush(pool, enviarWhatsApp);
    await recordarCitas(pool, enviarWhatsApp);
}

module.exports = { tareasCitas, procesarColaPush, recordarCitas, expirarPendientes, mensajeRecordatorio, minutosHasta };
