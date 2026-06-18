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
            `SELECT e.id, e.titulo, DATE_FORMAT(e.fecha, '%Y-%m-%d') as fecha, e.hora, e.ubicacion, e.uuid_confirmacion, u.whatsapp 
             FROM eventos e 
             JOIN usuarios u ON e.user_id = u.id 
             WHERE e.fecha IN (?, ?) AND u.verificado = true`,
            [todayStr, tomorrowStr]
        );

        const ahora = new Date();
        const pastLimit = new Date(ahora.getTime() - 60 * 60 * 1000); // 1 hour ago limit to avoid spamming past events
        const LOOK_AHEAD = 5 * 60 * 1000; // 5 minutes lookahead to schedule precise timeouts

        for (const event of events) {
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
                    let msg = `🚀 *Comienza tu evento* 🚀\n\nTu evento *${event.titulo}* está programado para comenzar ahora.\n\n🕒 *Hora:* ${formatTime12h(event.hora)}\n📍 *Ubicación:* ${event.ubicacion || 'Sin ubicación definida'}\n\n¡Éxitos!`;
                    if (event.uuid_confirmacion) {
                        msg += `\n\n🔗 *Confirma y registra gastos aquí:* https://vapcaqueta.alwaysdata.net/confirmar/${event.uuid_confirmacion}`;
                    }
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
                    let msg = `🚀 *Comienza tu evento* 🚀\n\nTu evento *${event.titulo}* está programado para comenzar ahora.\n\n🕒 *Hora:* ${formatTime12h(event.hora)}\n📍 *Ubicación:* ${event.ubicacion || 'Sin ubicación definida'}\n\n¡Éxitos!`;
                    if (event.uuid_confirmacion) {
                        msg += `\n\n🔗 *Confirma y registra gastos aquí:* https://vapcaqueta.alwaysdata.net/confirmar/${event.uuid_confirmacion}`;
                    }
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
                    const msg = `⏰ *Recordatorio anticipado* (30 minutos) ⏰\n\nTu evento *${event.titulo}* comenzará en 30 minutos.\n\n🕒 *Hora:* ${formatTime12h(event.hora)}\n📍 *Ubicación:* ${event.ubicacion || 'Sin ubicación definida'}\n\n💡 Te avisaremos nuevamente a la hora exacta.`;
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
                    const msg = `⏰ *Recordatorio anticipado* (30 minutos) ⏰\n\nTu evento *${event.titulo}* comenzará en 30 minutos.\n\n🕒 *Hora:* ${formatTime12h(event.hora)}\n📍 *Ubicación:* ${event.ubicacion || 'Sin ubicación definida'}\n\n💡 Te avisaremos nuevamente a la hora exacta.`;
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

async function checkBirthdays() {
    const connection = await pool.getConnection();
    try {
        const todayStr = getColombianDateString(0);
        const [, month, day] = todayStr.split('-');
        const todayMonthDay = `${month}-${day}`;

        // Get birthdays for today
        const [birthdays] = await connection.query(
            `SELECT c.id, c.nombre, c.mensaje, c.telefono, u.whatsapp 
             FROM cumpleanos c 
             JOIN usuarios u ON c.user_id = u.id 
             WHERE DATE_FORMAT(c.fecha, '%m-%d') = ? AND u.verificado = true`,
            [todayMonthDay]
        );

        for (const b of birthdays) {
            try {
                await connection.query(
                    "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES ('cumpleanos', ?, ?)",
                    [b.id, todayStr]
                );
            } catch (dbErr) {
                if (dbErr.code === 'ER_DUP_ENTRY') {
                    continue; // Already processed by another process
                }
                throw dbErr;
            }

            let msg = `🎉 *¡Hoy es un día especial!* 🎂\n\n*${b.nombre}* está de cumpleaños hoy.`;
            if (b.mensaje) {
                msg += `\n\n📝 *Mensaje personalizado guardado:*\n"${b.mensaje}"`;
            }
            if (b.telefono) {
                msg += `\n\n📞 *Teléfono de contacto:* ${b.telefono}`;
            }
            msg += `\n\n¡No olvides felicitarle en su día! 🥳`;

            const success = await sendWhatsAppMessage(b.whatsapp, msg);
            if (!success) {
                await connection.query(
                    "DELETE FROM notificaciones_enviadas WHERE tipo = 'cumpleanos' AND referencia_id = ? AND fecha_referencia = ?",
                    [b.id, todayStr]
                );
                console.log(`[Cron] Failed to send birthday message. Lock released for contact ${b.id}`);
            } else {
                console.log(`[Cron] Successfully sent and saved birthday reminder for contact ${b.id}`);
            }
        }
    } catch (error) {
        console.error('[Cron Birthdays] Error checking birthdays:', error);
    } finally {
        connection.release();
    }
}

async function checkHolidays() {
    const connection = await pool.getConnection();
    try {
        const todayStr = getColombianDateString(0);
        const year = new Date(todayStr).getFullYear();
        const holidays = await getHolidays(year);

        const currentColombian = getColombianNow();
        const dayOfWeek = currentColombian.getDay(); // 0 = Sunday, ..., 5 = Friday, 6 = Saturday

        // 1. Check if today is a Holiday
        const todayHoliday = holidays.find(h => h.date === todayStr);
        if (todayHoliday) {
            const [users] = await connection.query("SELECT id, whatsapp FROM usuarios WHERE verificado = true");
            for (const user of users) {
                try {
                    await connection.query(
                        "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES ('festivo_dia', ?, ?)",
                        [user.id, todayStr]
                    );
                } catch (dbErr) {
                    if (dbErr.code === 'ER_DUP_ENTRY') {
                        continue;
                    }
                    throw dbErr;
                }

                const msg = `🇨🇴 *¡Feliz día festivo!* 🇨🇴\n\nHoy es festivo en Colombia por: *${todayHoliday.localName}* (${todayHoliday.name}).\n\n¡Disfruta de este merecido descanso! 🏖️`;
                const success = await sendWhatsAppMessage(user.whatsapp, msg);
                if (!success) {
                    await connection.query(
                        "DELETE FROM notificaciones_enviadas WHERE tipo = 'festivo_dia' AND referencia_id = ? AND fecha_referencia = ?",
                        [user.id, todayStr]
                    );
                } else {
                    console.log(`[Cron] Successfully sent and saved holiday notification for user ${user.id}`);
                }
            }
        }

        // 2. Check for upcoming long weekend (Puente Festivo)
        // Runs on Friday (5) or Saturday (6) checking the next Monday
        if (dayOfWeek === 5 || dayOfWeek === 6) {
            const offset = dayOfWeek === 5 ? 3 : 2;
            const nextMondayStr = getColombianDateString(offset);
            const mondayYear = new Date(nextMondayStr).getFullYear();
            const mondayHolidays = await getHolidays(mondayYear);

            const mondayHoliday = mondayHolidays.find(h => h.date === nextMondayStr);
            if (mondayHoliday) {
                const [users] = await connection.query("SELECT id, whatsapp FROM usuarios WHERE verificado = true");
                for (const user of users) {
                    try {
                        await connection.query(
                            "INSERT INTO notificaciones_enviadas (tipo, referencia_id, fecha_referencia) VALUES ('festivo_puente', ?, ?)",
                            [user.id, nextMondayStr]
                        );
                    } catch (dbErr) {
                        if (dbErr.code === 'ER_DUP_ENTRY') {
                            continue;
                        }
                        throw dbErr;
                    }

                    const msg = `🏖️ *¡Se acerca un puente festivo!* 🏖️\n\nEste lunes es festivo por: *${mondayHoliday.localName}*.\n\n¡Prepárate para un fin de semana largo de descanso! ✈️`;
                    const success = await sendWhatsAppMessage(user.whatsapp, msg);
                    if (!success) {
                        await connection.query(
                            "DELETE FROM notificaciones_enviadas WHERE tipo = 'festivo_puente' AND referencia_id = ? AND fecha_referencia = ?",
                            [user.id, nextMondayStr]
                        );
                    } else {
                        console.log(`[Cron] Successfully sent and saved puente holiday notification for user ${user.id}`);
                    }
                }
            }
        }
    } catch (error) {
        console.error('[Cron Holidays] Error checking holidays:', error);
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

    const colNow = getColombianNow();
    if (colNow.getHours() >= 8) {
        await checkBirthdays();
        await checkHolidays();
    }

    // Interval checks
    const POLL_INTERVAL = 30000; // 30 seconds
    setInterval(async () => {
        try {
            console.log(`[Cron] Running polling loop... Timestamp: ${new Date().toLocaleString()}`);
            await checkEventReminders();
            await checkCDTYields();

            const now = getColombianNow();
            // General notifications (Birthdays/Holidays) run after 8:00 AM Colombia
            if (now.getHours() >= 8) {
                await checkBirthdays();
                await checkHolidays();
            }
        } catch (err) {
            console.error('[Cron] Error in polling loop:', err);
        }
    }, POLL_INTERVAL);
}

main().catch(err => {
    console.error('[Cron] Fatal error in main loop:', err);
    process.exit(1);
});
