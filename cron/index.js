require('dotenv').config();
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

// Ensure log folder exists
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir);
}

// Database Connection Pool
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 5,
    queueLimit: 0,
    enableKeepAlive: true,
    keepAliveInitialDelay: 30000,
    dateStrings: ['DATE'] // Prevents mysql2 from shifting dates to UTC local Date objects
});

// Memory Map to keep track of scheduled timeouts
// Key: `${eventId}_${type}` -> Value: { timeoutId, triggerTimeISO }
const scheduledTimeouts = new Map();

// Timezone & Date Helper Functions
function getColombianNow() {
    return new Date(new Date().toLocaleString("en-US", { timeZone: "America/Bogota" }));
}

function getColombianDateString(offsetDays = 0) {
    const date = new Date(Date.now() + offsetDays * 24 * 60 * 60 * 1000);
    const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: 'America/Bogota',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit'
    });
    const parts = formatter.formatToParts(date);
    const partValues = {};
    parts.forEach(p => partValues[p.type] = p.value);
    return `${partValues.year}-${partValues.month}-${partValues.day}`;
}

function getColombianTime(dateStr, timeStr) {
    const cleanTime = timeStr || '00:00:00';
    // Constructs exact date in ISO representing Colombia timezone (UTC-5)
    return new Date(`${dateStr}T${cleanTime}-05:00`);
}

function formatTime12h(timeStr) {
    if (!timeStr) return '';
    const [hoursStr, minutesStr] = timeStr.split(':');
    const hours = parseInt(hoursStr, 10);
    const esPM = hours >= 12;
    const hours12 = hours % 12 || 12;
    return `${hours12}:${minutesStr} ${esPM ? 'PM' : 'AM'}`;
}

// ---------------------------------------------------------------------------
//  PERSONALIZACIÓN DE MENSAJES
// ---------------------------------------------------------------------------

// Categorías que se notifican como recordatorio matutino (7 a.m.) y NO con el
// patrón de "media hora antes + hora exacta" de las reuniones.
const CATEGORIAS_TODO_EL_DIA = new Set(['arriendo', 'aceite_moto', 'servicios', 'aniversario', 'mesiversario']);

// Metadatos visuales por categoría (emoji + nombre legible).
const CATEGORIA_META = {
    reunion:      { emoji: '📅', nombre: 'Reunión' },
    cumpleanos:   { emoji: '🎂', nombre: 'Cumpleaños' },
    moto:         { emoji: '🏍️', nombre: 'Moto' },
    carro:        { emoji: '🚗', nombre: 'Carro' },
    casa:         { emoji: '🏠', nombre: 'Casa' },
    arriendo:     { emoji: '🏠', nombre: 'Arriendo' },
    aceite_moto:  { emoji: '🛢️', nombre: 'Cambio de aceite' },
    mecanica:     { emoji: '🔧', nombre: 'Mecánica' },
    servicios:    { emoji: '🧾', nombre: 'Servicios públicos' },
    doctor:       { emoji: '🩺', nombre: 'Cita médica' },
    medicamentos: { emoji: '💊', nombre: 'Medicamentos' },
    dentista:     { emoji: '🦷', nombre: 'Odontología' },
    cita_amor:    { emoji: '❤️', nombre: 'Cita romántica' },
    aniversario:  { emoji: '💑', nombre: 'Aniversario' },
    matrimonio:   { emoji: '💍', nombre: 'Matrimonio' },
    mesiversario: { emoji: '🌹', nombre: 'Mesiversario' }
};
function metaCategoria(cat) {
    return CATEGORIA_META[cat] || { emoji: '📌', nombre: 'Recordatorio' };
}

// Un evento es "de crédito" si nació automáticamente desde el módulo de finanzas
// (lleva tarjeta_credito_id). Esos van siempre en el resumen de las 7 a.m.
function esCreditoEvent(ev) {
    return ev.tarjeta_credito_id !== null && ev.tarjeta_credito_id !== undefined;
}

// Un evento se notifica en el resumen matutino (7 a.m.) si: es de crédito, no
// tiene hora definida, o pertenece a una categoría de "todo el día".
function esTodoElDia(ev) {
    if (esCreditoEvent(ev)) return true;
    if (!ev.hora) return true;
    return CATEGORIAS_TODO_EL_DIA.has(ev.categoria);
}

const DIAS_SEMANA = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

function fechaLegible(dateStr) {
    const d = new Date(`${dateStr}T12:00:00-05:00`);
    return `${DIAS_SEMANA[d.getDay()]} ${d.getDate()} de ${MESES[d.getMonth()]} de ${d.getFullYear()}`;
}

function formatCOP(n) {
    return '$' + Number(n || 0).toLocaleString('es-CO');
}

const CONFIRM_BASE_URL = 'https://vapcaqueta.alwaysdata.net/confirmar';

// --- Constructores de mensaje para eventos TEMPORIZADOS (con hora exacta) ---

function buildTimedExactMsg(event) {
    const meta = metaCategoria(event.categoria);
    const hora = formatTime12h(event.hora);
    const ubic = event.ubicacion ? `\n📍 *Lugar:* ${event.ubicacion}` : '';

    let cuerpo;
    switch (event.categoria) {
        case 'reunion':
            cuerpo = `Es momento de tu reunión *${event.titulo}*. ¡Que sea muy productiva!`;
            break;
        case 'doctor':
        case 'dentista':
            cuerpo = `Es la hora de tu cita: *${event.titulo}*. Lleva tus documentos y llega con tiempo. 🩺`;
            break;
        case 'medicamentos':
            cuerpo = `Es momento de tomar tu medicamento: *${event.titulo}*. Cuida tu salud. 💊`;
            break;
        case 'cita_amor':
            cuerpo = `Llegó la hora de tu cita: *${event.titulo}*. ¡Disfruta cada momento! ❤️`;
            break;
        case 'mecanica':
        case 'moto':
        case 'carro':
            cuerpo = `Recordatorio: *${event.titulo}*. Dale el mantenimiento que merece. 🔧`;
            break;
        case 'matrimonio':
            cuerpo = `Hoy es el gran momento: *${event.titulo}*. 💍`;
            break;
        default:
            cuerpo = `Tu compromiso *${event.titulo}* es ahora mismo.`;
    }

    let msg = `${meta.emoji} *${meta.nombre} — ¡Es la hora!*\n\n${cuerpo}\n\n🕒 *Hora:* ${hora}${ubic}`;
    if (event.uuid_confirmacion && event.tipo_transaccion && event.tipo_transaccion !== 'ninguno') {
        msg += `\n\n🔗 *Confirma y registra el gasto aquí:*\n${CONFIRM_BASE_URL}/${event.uuid_confirmacion}`;
    }
    return msg;
}

function buildTimedPreMsg(event) {
    const meta = metaCategoria(event.categoria);
    const hora = formatTime12h(event.hora);
    const ubic = event.ubicacion ? `\n📍 *Lugar:* ${event.ubicacion}` : '';
    return `⏰ *Faltan 30 minutos* ${meta.emoji}\n\nTu ${meta.nombre.toLowerCase()} *${event.titulo}* comienza a las *${hora}*.${ubic}\n\n💡 Te avisaremos de nuevo a la hora exacta.`;
}

// WhatsApp Send Message Function
async function sendWhatsAppMessage(whatsapp, text) {
    try {
        const cleanedJid = whatsapp.replace(/\D/g, '');
        if (!cleanedJid) return false;

        const response = await fetch('https://whatsapp.alwaysdata.net/api/messages/text', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': process.env.WHATSAPP_API_KEY || 'e0015f66b77a90f580860d1f3abe4dd6426f7320852416f815515a1323c515d8'
            },
            body: JSON.stringify({
                jid: cleanedJid,
                text: text
            })
        });

        const data = await response.json();
        console.log(`[WhatsApp] Sent notification to ${cleanedJid}, status: ${response.status}`, data);
        return response.ok;
    } catch (error) {
        console.error(`[WhatsApp] Error sending message to ${whatsapp}:`, error);
        return false;
    }
}

// Holiday Cache
const holidayCache = {};
async function getHolidays(year) {
    if (holidayCache[year]) return holidayCache[year];
    try {
        console.log(`[Holidays] Fetching holidays for year ${year}...`);
        const response = await fetch(`https://date.nager.at/api/v3/PublicHolidays/${year}/CO`);
        if (response.ok) {
            const data = await response.json();
            holidayCache[year] = data;
            return data;
        }
    } catch (error) {
        console.error(`[Holidays] Error fetching holidays for ${year}:`, error);
    }
    return [];
}

// Helper to execute and double-check trigger status
async function executeEventReminder(event, tipo, triggerISO, message) {
    const connection = await pool.getConnection();
    try {
        // Double-check: Make sure the event still exists in the database and has NOT changed its date/time
        // Force date formatting inside SQL to avoid driver differences
        const [rows] = await connection.query(
            "SELECT id, DATE_FORMAT(fecha, '%Y-%m-%d') as fecha, hora FROM eventos WHERE id = ?",
            [event.id]
        );

        if (rows.length === 0) {
            console.log(`[Cron] Event ${event.id} was deleted. Aborting notification.`);
            return;
        }

        const currentEvent = rows[0];
        const eventDateStr = String(currentEvent.fecha);

        const currentTriggerStr = getColombianTime(eventDateStr, currentEvent.hora).toISOString();
        
        let targetISO = currentTriggerStr;
        if (tipo === 'evento_30m') {
            const exactTrigger = getColombianTime(eventDateStr, currentEvent.hora);
            targetISO = new Date(exactTrigger.getTime() - 30 * 60 * 1000).toISOString();
        }

        if (targetISO !== triggerISO) {
            console.log(`[Cron] Event ${event.id} scheduled time changed (Current target: ${targetISO}, Timer trigger: ${triggerISO}). Aborting outdated timer.`);
            return;
        }

        // Try inserting first to lock it (optimistic locking / unique constraint)
        try {
            await connection.query(
                "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES (?, ?, ?)",
                [tipo, event.id, triggerISO]
            );
        } catch (dbErr) {
            if (dbErr.code === 'ER_DUP_ENTRY') {
                console.log(`[Cron] Notification ${tipo} for event ${event.id} at ${triggerISO} already sent or claimed by another process.`);
                return;
            }
            throw dbErr;
        }

        // If we reached here, the INSERT succeeded. We are the unique owner of this notification trigger.
        const success = await sendWhatsAppMessage(event.whatsapp, message);
        if (!success) {
            // Delete the lock so it can be retried on next execution if WhatsApp failed
            await connection.query(
                "DELETE FROM notificaciones_enviadas WHERE tipo = ? AND referencia_id = ? AND fecha_referencia = ?",
                [tipo, event.id, triggerISO]
            );
            console.log(`[Cron] Failed to send WhatsApp message. Lock released for event ${event.id}`);
        } else {
            console.log(`[Cron] Successfully sent and saved ${tipo} reminder for event ${event.id}`);
        }
    } catch (err) {
        console.error(`[Cron] Error executing event reminder for ${event.id}:`, err);
    } finally {
        connection.release();
    }
}

// Main Cron Checking Routines
async function checkEventReminders() {
    const connection = await pool.getConnection();
    try {
        const todayStr = getColombianDateString(0);
        const tomorrowStr = getColombianDateString(1);

        // Fetch events for today and tomorrow for verified users
        const [events] = await connection.query(
            `SELECT e.id, e.titulo, DATE_FORMAT(e.fecha, '%Y-%m-%d') as fecha, e.hora, e.categoria, e.ubicacion, e.costo, e.tipo_transaccion, e.tarjeta_credito_id, e.uuid_confirmacion, u.whatsapp
             FROM eventos e
             JOIN usuarios u ON e.user_id = u.id
             WHERE e.fecha IN (?, ?) AND u.verificado = true`,
            [todayStr, tomorrowStr]
        );

        const ahora = new Date();
        const pastLimit = new Date(ahora.getTime() - 60 * 60 * 1000); // 1 hour ago limit to avoid spamming past events
        const LOOK_AHEAD = 5 * 60 * 1000; // 5 minutes lookahead to schedule precise timeouts

        for (const event of events) {
            // Los eventos "de todo el día" (sin hora, de crédito o categorías como
            // arriendo/aceite/servicios/aniversario/mesiversario) NO se notifican aquí:
            // se consolidan en el resumen matutino de las 7 a.m.
            if (esTodoElDia(event)) continue;

            const eventDateStr = String(event.fecha);

            const exactTrigger = getColombianTime(eventDateStr, event.hora);
            const preTrigger = new Date(exactTrigger.getTime() - 30 * 60 * 1000);

            // --- 1. Exact time reminder ---
            const exactDelay = exactTrigger.getTime() - Date.now();
            const exactKey = `${event.id}_exacto`;

            if (exactDelay <= 0) {
                // Past or immediate execution
                if (exactDelay >= -60 * 60 * 1000) {
                    const triggerISO = exactTrigger.toISOString();
                    const msg = buildTimedExactMsg(event);
                    await executeEventReminder(event, 'evento_exacto', triggerISO, msg);
                }
            } else if (exactDelay <= LOOK_AHEAD) {
                // Schedule exact timer in the near future
                const triggerISO = exactTrigger.toISOString();
                const existing = scheduledTimeouts.get(exactKey);

                if (existing) {
                    if (existing.triggerTimeISO !== triggerISO) {
                        // Rescheduled: clear and reschedule
                        clearTimeout(existing.timeoutId);
                        scheduledTimeouts.delete(exactKey);
                    } else {
                        // Already scheduled correctly
                        continue;
                    }
                }

                const timeoutId = setTimeout(async () => {
                    scheduledTimeouts.delete(exactKey);
                    const msg = buildTimedExactMsg(event);
                    await executeEventReminder(event, 'evento_exacto', triggerISO, msg);
                }, exactDelay);

                scheduledTimeouts.set(exactKey, { timeoutId, triggerTimeISO: triggerISO });
                console.log(`[Cron] Scheduled exact timer for event ${event.id} in ${exactDelay}ms (Time: ${exactTrigger.toLocaleString()})`);
            }

            // --- 2. 30 minutes pre-reminder ---
            const preDelay = preTrigger.getTime() - Date.now();
            const preKey = `${event.id}_30m`;

            if (preDelay <= 0 && exactTrigger > Date.now()) {
                // Past or immediate execution
                if (preDelay >= -60 * 60 * 1000) {
                    const triggerISO = preTrigger.toISOString();
                    const msg = buildTimedPreMsg(event);
                    await executeEventReminder(event, 'evento_30m', triggerISO, msg);
                }
            } else if (preDelay > 0 && preDelay <= LOOK_AHEAD) {
                // Schedule pre-timer in the near future
                const triggerISO = preTrigger.toISOString();
                const existing = scheduledTimeouts.get(preKey);

                if (existing) {
                    if (existing.triggerTimeISO !== triggerISO) {
                        // Rescheduled: clear and reschedule
                        clearTimeout(existing.timeoutId);
                        scheduledTimeouts.delete(preKey);
                    } else {
                        // Already scheduled correctly
                        continue;
                    }
                }

                const timeoutId = setTimeout(async () => {
                    scheduledTimeouts.delete(preKey);
                    const msg = buildTimedPreMsg(event);
                    await executeEventReminder(event, 'evento_30m', triggerISO, msg);
                }, preDelay);

                scheduledTimeouts.set(preKey, { timeoutId, triggerTimeISO: triggerISO });
                console.log(`[Cron] Scheduled 30m timer for event ${event.id} in ${preDelay}ms (Time: ${preTrigger.toLocaleString()})`);
            }
        }
    } catch (error) {
        console.error('[Cron Events] Error checking event reminders:', error);
    } finally {
        connection.release();
    }
}

// ---------------------------------------------------------------------------
//  RESUMEN MATUTINO (7 a.m.)
//  Consolida en UN SOLO mensaje por usuario todo lo "de todo el día":
//  cumpleaños, recordatorios/pagos sin hora, pagos de tarjeta de crédito,
//  festivo del día y aviso de puente festivo (viernes/sábado).
// ---------------------------------------------------------------------------

function construirResumen({ todayStr, bdays, recordatorios, creditos, todayHoliday, puente }) {
    const partes = [];
    partes.push('☀️ *Buenos días* ☀️');
    partes.push(`Esto es lo que tienes para hoy, ${fechaLegible(todayStr)}:`);

    if (todayHoliday) {
        partes.push(`\n🇨🇴 *Día festivo*\nHoy es festivo en Colombia: *${todayHoliday.localName}*. ¡Disfruta de este merecido descanso! 🏖️`);
    }

    if (bdays.length > 0) {
        let s = '\n🎂 *Cumpleaños de hoy*';
        for (const b of bdays) {
            s += `\n• *${b.nombre}*`;
            if (b.telefono) s += ` — 📞 ${b.telefono}`;
            if (b.mensaje) s += `\n   _"${b.mensaje}"_`;
        }
        s += '\n¡No olvides felicitarle en su día! 🥳';
        partes.push(s);
    }

    if (recordatorios.length > 0) {
        let s = '\n📋 *Recordatorios y pagos de hoy*';
        for (const e of recordatorios) {
            const meta = metaCategoria(e.categoria);
            let linea = `\n• ${meta.emoji} *${e.titulo}*`;
            if (e.costo && Number(e.costo) > 0) linea += ` — ${formatCOP(e.costo)}`;
            if (e.ubicacion) linea += ` _(${e.ubicacion})_`;
            s += linea;
        }
        partes.push(s);
    }

    if (creditos.length > 0) {
        let total = 0;
        let s = '\n💳 *Pagos de tarjeta de crédito*';
        for (const e of creditos) {
            total += Number(e.costo || 0);
            s += `\n• *${e.titulo}*`;
            if (e.costo && Number(e.costo) > 0) s += ` — ${formatCOP(e.costo)}`;
        }
        if (creditos.length > 1) s += `\n💰 *Total de hoy:* ${formatCOP(total)}`;
        s += '\n_Paga a tiempo para mantener tu vida crediticia sana y evitar intereses._';
        partes.push(s);
    }

    if (puente) {
        partes.push(`\n🏖️ *¡Puente festivo a la vista!*\nEste lunes es festivo por *${puente.holiday.localName}*. ¡Prepárate para un fin de semana largo! ✈️`);
    }

    partes.push('\n✨ Que tengas un día excelente. Estamos contigo para que no se te escape nada.');
    return partes.join('\n');
}

async function checkDailyDigest() {
    const colNow = getColombianNow();
    if (colNow.getHours() < 7) return; // Sólo a partir de las 7:00 a.m. (hora Colombia)

    const connection = await pool.getConnection();
    try {
        const todayStr = getColombianDateString(0);
        const dow = colNow.getDay(); // 0 = domingo ... 5 = viernes, 6 = sábado
        const year = Number(todayStr.slice(0, 4));

        // Festivo de hoy
        const holidays = await getHolidays(year);
        const todayHoliday = holidays.find(h => h.date === todayStr) || null;

        // Puente: viernes (5) o sábado (6) -> revisar si el próximo lunes es festivo
        let puente = null;
        if (dow === 5 || dow === 6) {
            const offset = dow === 5 ? 3 : 2;
            const lunesStr = getColombianDateString(offset);
            const lunesHols = await getHolidays(Number(lunesStr.slice(0, 4)));
            const h = lunesHols.find(x => x.date === lunesStr);
            if (h) puente = { fecha: lunesStr, holiday: h };
        }

        const [users] = await connection.query("SELECT id, whatsapp FROM usuarios WHERE verificado = true");

        for (const user of users) {
            // Cumpleaños de hoy de este usuario
            const [bdays] = await connection.query(
                `SELECT id, nombre, mensaje, telefono FROM cumpleanos WHERE user_id = ? AND DATE_FORMAT(fecha, '%m-%d') = ?`,
                [user.id, todayStr.slice(5)]
            );

            // Eventos de hoy de este usuario, filtrando los "de todo el día"
            const [evs] = await connection.query(
                `SELECT id, titulo, hora, categoria, ubicacion, costo, tipo_transaccion, tarjeta_credito_id
                 FROM eventos WHERE user_id = ? AND DATE_FORMAT(fecha, '%Y-%m-%d') = ?`,
                [user.id, todayStr]
            );
            const todoElDia = evs.filter(esTodoElDia);
            const creditos = todoElDia.filter(esCreditoEvent);
            const recordatorios = todoElDia.filter(e => !esCreditoEvent(e));

            // ¿Hay algo que comunicar hoy?
            const hayContenido = bdays.length > 0 || todoElDia.length > 0 || todayHoliday || puente;
            if (!hayContenido) continue;

            // Lock único por usuario y día: garantiza UN solo resumen diario
            try {
                await connection.query(
                    "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES ('resumen_diario', ?, ?)",
                    [user.id, todayStr]
                );
            } catch (dbErr) {
                if (dbErr.code === 'ER_DUP_ENTRY') continue; // Ya se envió hoy
                throw dbErr;
            }

            const msg = construirResumen({ todayStr, bdays, recordatorios, creditos, todayHoliday, puente });
            const success = await sendWhatsAppMessage(user.whatsapp, msg);
            if (!success) {
                await connection.query(
                    "DELETE FROM notificaciones_enviadas WHERE tipo = 'resumen_diario' AND referencia_id = ? AND fecha_referencia = ?",
                    [user.id, todayStr]
                );
                console.log(`[Digest] Falló el envío; lock liberado para user ${user.id}`);
            } else {
                console.log(`[Digest] Resumen diario enviado a user ${user.id} (${bdays.length} cumple, ${recordatorios.length} recordatorios, ${creditos.length} créditos)`);
            }
        }
    } catch (error) {
        console.error('[Digest] Error en el resumen diario:', error);
    } finally {
        connection.release();
    }
}

// Process CDT daily yield calculations and maturity WhatsApp alerts
async function checkCDTYields() {
    const connection = await pool.getConnection();
    try {
        const todayStr = getColombianDateString(0);

        // Fetch active CDTs for verified users
        const [cdts] = await connection.query(
            `SELECT c.id, c.user_id, c.nombre, c.saldo, c.interes_tasa, DATE_FORMAT(c.fecha_inicio, '%Y-%m-%d') as fecha_inicio, c.plazo_dias, u.whatsapp 
             FROM finanzas_cuentas c 
             JOIN usuarios u ON c.user_id = u.id 
             WHERE c.tipo = 'cdt' AND c.interes_tasa > 0 AND c.fecha_inicio <= ? AND u.verificado = true`,
            [todayStr]
        );

        for (const c of cdts) {
            try {
                // Calculate maturity date: start_date + plazo_dias
                const start = new Date(c.fecha_inicio + 'T00:00:00-05:00');
                const hasMaturity = c.plazo_dias && Number(c.plazo_dias) > 0;

                let isMaturityDay = false;
                let isExpired = false;

                if (hasMaturity) {
                    const end = new Date(start.getTime() + Number(c.plazo_dias) * 24 * 60 * 60 * 1000);
                    const endStr = end.toISOString().split('T')[0];
                    isMaturityDay = (todayStr === endStr);
                    isExpired = (todayStr > endStr);
                }

                // If not expired (or if it's a Cajita with no maturity), calculate and register interest yield for today
                if (!isExpired) {
                    const txDesc = `Rendimiento diario CDT: ${c.nombre} (ID: ${c.id})`;
                    // Check if yield transaction already exists for today
                    const [existing] = await connection.query(
                        "SELECT id FROM finanzas_transacciones WHERE cuenta_id = ? AND descripcion = ? AND fecha = ?",
                        [c.id, txDesc, todayStr]
                    );

                    if (existing.length === 0) {
                        const r = Number(c.interes_tasa) / 100;
                        const dailyFactor = Math.pow(1 + r, 1 / 365) - 1;
                        const dailyYield = Number(c.saldo) * dailyFactor;

                        if (dailyYield > 0.005) {
                            await connection.beginTransaction();
                            try {
                                // Insert transaction
                                await connection.query(
                                    `INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria) 
                                     VALUES (?, ?, 'ingreso', ?, ?, ?, 'ahorro')`,
                                    [c.user_id, c.id, dailyYield.toFixed(2), txDesc, todayStr]
                                );

                                // Add to CDT balance
                                await connection.query(
                                    "UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ?",
                                    [dailyYield.toFixed(2), c.id]
                                );

                                await connection.commit();
                                console.log(`[CDT Cron] Paid daily yield of $${dailyYield.toFixed(2)} to CDT "${c.nombre}" (ID: ${c.id})`);
                            } catch (txErr) {
                                await connection.rollback();
                                throw txErr;
                            }
                        }
                    }
                }

                // If today is the maturity day, send WhatsApp alert
                if (isMaturityDay) {
                    const lockType = 'cdt_vencimiento';
                    try {
                        // Optimistic lock to prevent duplicate sends across processes
                        await connection.query(
                            "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES (?, ?, ?)",
                            [lockType, c.id, todayStr]
                        );

                        const msg = `⏰ *¡Tu CDT "${c.nombre}" ha vencido hoy!* ⏰\n\n💰 *Monto Disponible:* $${Number(c.saldo).toLocaleString('es-CO')}\n📉 *Tasa Pactada:* ${c.interes_tasa}% E.A.\n⏳ *Plazo:* ${c.plazo_dias} días\n\nTu inversión está lista para ser cobrada o reinvertida en tu panel de Finanzas. ¡Excelente trabajo construyendo tu ahorro! 🥳`;
                        
                        const success = await sendWhatsAppMessage(c.whatsapp, msg);
                        if (!success) {
                            // Roll back lock on failure
                            await connection.query(
                                "DELETE FROM notificaciones_enviadas WHERE tipo = ? AND referencia_id = ? AND fecha_referencia = ?",
                                [lockType, c.id, todayStr]
                            );
                        } else {
                            console.log(`[CDT Cron] Successfully sent maturity WhatsApp alert for CDT "${c.nombre}" to ${c.whatsapp}`);
                        }
                    } catch (dbErr) {
                        if (dbErr.code !== 'ER_DUP_ENTRY') {
                            throw dbErr;
                        }
                        // Lock already acquired (already sent)
                    }
                }
            } catch (cdtErr) {
                console.error(`[CDT Cron] Error processing CDT ID ${c.id}:`, cdtErr);
            }
        }
    } catch (error) {
        console.error('[CDT Cron] Error checking CDT yields:', error);
    } finally {
        connection.release();
    }
}

// Database Initialization
async function initDb() {
    const connection = await pool.getConnection();
    try {
        await connection.query(`
            CREATE TABLE IF NOT EXISTS notificaciones_enviadas (
                id INT AUTO_INCREMENT PRIMARY KEY,
                tipo VARCHAR(50) NOT NULL,
                referencia_id INT NOT NULL,
                fecha_referencia VARCHAR(50) NOT NULL,
                fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_envio (tipo, referencia_id, fecha_referencia)
            )
        `);
        console.log('[Init] ensured notificaciones_enviadas table exists.');
    } catch (err) {
        console.error('[Init] Error verifying notificaciones_enviadas table:', err);
    } finally {
        connection.release();
    }
}

// Main Process
async function main() {
    console.log('[Cron] Starting standalone precise scheduler service...');
    await initDb();

    // Check immediately on startup
    await checkEventReminders();
    await checkCDTYields();
    // El resumen diario se autolimita a partir de las 7:00 a.m. (hora Colombia)
    await checkDailyDigest();

    // Interval checks
    const POLL_INTERVAL = 30000; // 30 seconds
    setInterval(async () => {
        try {
            console.log(`[Cron] Running polling loop... Timestamp: ${new Date().toLocaleString()}`);
            await checkEventReminders();
            await checkCDTYields();
            // Resumen matutino consolidado (cumpleaños + recordatorios + créditos
            // + festivos + puente). Internamente sólo actúa desde las 7:00 a.m.
            await checkDailyDigest();
        } catch (err) {
            console.error('[Cron] Error in polling loop:', err);
        }
    }, POLL_INTERVAL);
}

// Sólo arranca el servicio si se ejecuta directamente (node index.js).
// Al importarlo (p. ej. para pruebas) NO se inicia el bucle ni la BD.
if (require.main === module) {
    main().catch(err => {
        console.error('[Cron] Fatal error in main loop:', err);
        process.exit(1);
    });
}

// Exponemos las funciones puras (sin BD) para pruebas y reutilización.
module.exports = {
    construirResumen,
    buildTimedExactMsg,
    buildTimedPreMsg,
    esTodoElDia,
    esCreditoEvent,
    metaCategoria,
    fechaLegible,
    formatCOP,
    formatTime12h
};
