import Fastify from 'fastify';
import cors from '@fastify/cors';
import jwt from '@fastify/jwt';
import dotenv from 'dotenv';
import mysql from 'mysql2/promise';
import crypto from 'crypto';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { generateExcelReport } from './lib/excelService';
import { validarFechaCiclo, validarDiasSangrado, normalizarDiasSangrado } from './lib/cycleValidation';
import { migrarAgenda, registrarAgenda } from './lib/agenda/rutas';
import { registrarTiempoReal } from './lib/tiempoReal';
import { migrarCapturas, registrarCapturas } from './lib/finanzas/capturas';
import { migrarInversiones, registrarInversiones } from './lib/finanzas/inversiones';

dotenv.config();

const server = Fastify({ logger: true });

server.register(cors, { 
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
});
server.register(jwt, { secret: process.env.JWT_SECRET || 'supersecret' });

// Database pool
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    // Evita que DATE se convierta a Date/ISO UTC (desfase de día en Colombia)
    dateStrings: ['DATE'],
    timezone: 'Z'
});

// Utility to hash passwords (SHA-256 for simplicity, but bcrypt is recommended for prod)
function hashPassword(password: string): string {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// --- Categorías de finanzas: defaults y utilidades ---
const DEFAULT_FINANCE_CATEGORIES = [
    { valor: 'comida', label: 'Comida', icono: 'restaurant' },
    { valor: 'transporte', label: 'Transporte', icono: 'directions_car' },
    { valor: 'servicios', label: 'Servicios/Facturas', icono: 'receipt_long' },
    { valor: 'entretenimiento', label: 'Entretenimiento/Ocio', icono: 'sports_esports' },
    { valor: 'salud', label: 'Salud/Bienestar', icono: 'medication' },
    { valor: 'educacion', label: 'Educación', icono: 'school' },
    { valor: 'ahorro', label: 'Ahorro/Inversión', icono: 'savings' },
    { valor: 'otros', label: 'Otros', icono: 'payments' }
];

// Convierte un nombre legible en un slug seguro y único por usuario
function slugifyCategoria(label: string): string {
    return label
        .toLowerCase()
        .normalize('NFD').replace(/[̀-ͯ]/g, '') // elimina acentos
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_+|_+$/g, '')
        .slice(0, 50);
}

// Inserta las categorías por defecto la primera vez que el usuario accede al módulo
async function ensureDefaultCategories(conn: any, userId: number): Promise<void> {
    const [rows]: any = await conn.execute('SELECT COUNT(*) as cnt FROM finanzas_categorias WHERE user_id = ?', [userId]);
    if (rows[0].cnt > 0) return;
    for (const c of DEFAULT_FINANCE_CATEGORIES) {
        await conn.execute(
            'INSERT IGNORE INTO finanzas_categorias (user_id, valor, label, icono, es_default) VALUES (?, ?, ?, ?, TRUE)',
            [userId, c.valor, c.label, c.icono]
        );
    }
}

const WHATSAPP_API_KEY = process.env.WHATSAPP_API_KEY || 'e0015f66b77a90f580860d1f3abe4dd6426f7320852416f815515a1323c515d8';

/** Envía un texto por la API de WhatsApp. Devuelve false si no se pudo. */
async function enviarWhatsApp(numero: string, texto: string): Promise<boolean> {
    try {
        const jid = String(numero).replace(/\D/g, '');
        if (!jid) return false;
        const response = await fetch('https://whatsapp.alwaysdata.net/api/messages/text', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-api-key': WHATSAPP_API_KEY },
            body: JSON.stringify({ jid, text: texto })
        });
        server.log.info({ jid, status: response.status }, 'WhatsApp enviado');
        return response.ok;
    } catch (error) {
        server.log.error(error, 'Error enviando WhatsApp');
        return false;
    }
}

async function sendWhatsAppVerificationCode(whatsapp: string, code: string): Promise<boolean> {
    try {
        const cleanedJid = whatsapp.replace(/\D/g, '');
        // El endpoint es: https://whatsapp.alwaysdata.net/api/messages/text
        const response = await fetch('https://whatsapp.alwaysdata.net/api/messages/text', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'x-api-key': WHATSAPP_API_KEY
            },
            body: JSON.stringify({
                jid: cleanedJid,
                text: `¡Hola! Tu código de verificación para Calendario es: ${code}`
            })
        });
        const data = await response.json() as any;
        server.log.info({ jid: cleanedJid, response: data }, 'WhatsApp API response');
        return response.ok;
    } catch (error) {
        server.log.error(error, 'Error sending WhatsApp verification code');
        return false;
    }
}

server.post('/api/register', async (request, reply) => {
    const { nombre, email, password, whatsapp } = request.body as any;

    if (!nombre || !email || !password || !whatsapp) {
        return reply.status(400).send({ message: 'Todos los campos son obligatorios' });
    }

    const cleanedWhatsapp = whatsapp.replace(/\D/g, '');
    if (cleanedWhatsapp.length < 10) {
        return reply.status(400).send({ message: 'El número de WhatsApp debe tener al menos 10 dígitos (incluyendo código de país)' });
    }

    try {
        // Generar código de 6 dígitos
        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

        // Verificar si el usuario ya existe
        const [existingUsers]: any = await pool.execute(
            'SELECT id, verificado FROM usuarios WHERE email = ?',
            [email]
        );

        if (existingUsers.length > 0) {
            const user = existingUsers[0];
            if (user.verificado) {
                return reply.status(400).send({ message: 'El correo ya está registrado' });
            }
            // Si existe pero no está verificado, actualizamos sus datos y le mandamos nuevo código
            const hashedPassword = hashPassword(password);
            await pool.execute(
                'UPDATE usuarios SET nombre = ?, password = ?, whatsapp = ?, codigo_verificacion = ? WHERE id = ?',
                [nombre, hashedPassword, cleanedWhatsapp, verificationCode, user.id]
            );
        } else {
            const hashedPassword = hashPassword(password);
            await pool.execute(
                'INSERT INTO usuarios (nombre, email, password, whatsapp, verificado, codigo_verificacion) VALUES (?, ?, ?, ?, false, ?)',
                [nombre, email, hashedPassword, cleanedWhatsapp, verificationCode]
            );
        }

        // Enviar código por WhatsApp
        const sent = await sendWhatsAppVerificationCode(cleanedWhatsapp, verificationCode);
        if (!sent) {
            // No bloqueamos el flujo pero advertimos en logs
            server.log.error(`No se pudo enviar el WhatsApp de verificación a ${cleanedWhatsapp}`);
        }

        return reply.send({ 
            message: 'Código de verificación enviado a tu WhatsApp', 
            verification_required: true,
            email 
        });
    } catch (err: any) {
        if (err.code === 'ER_DUP_ENTRY') {
            return reply.status(400).send({ message: 'El correo ya está registrado' });
        }
        server.log.error(err);
        return reply.status(500).send({ message: 'Error interno del servidor' });
    }
});

server.post('/api/register/verify', async (request, reply) => {
    const { email, code } = request.body as any;

    if (!email || !code) {
        return reply.status(400).send({ message: 'El correo y el código son obligatorios' });
    }

    try {
        const [rows]: any = await pool.execute(
            'SELECT id, nombre, email, whatsapp, codigo_verificacion FROM usuarios WHERE email = ?',
            [email]
        );

        if (rows.length === 0) {
            return reply.status(404).send({ message: 'Usuario no encontrado' });
        }

        const userRow = rows[0];

        if (userRow.codigo_verificacion !== code) {
            return reply.status(400).send({ message: 'Código de verificación incorrecto' });
        }

        // Marcar como verificado y borrar el código
        await pool.execute(
            'UPDATE usuarios SET verificado = true, codigo_verificacion = NULL WHERE id = ?',
            [userRow.id]
        );

        const user = { id: userRow.id, nombre: userRow.nombre, email: userRow.email, whatsapp: userRow.whatsapp };
        const token = server.jwt.sign(user);

        return reply.send({ message: 'Usuario verificado exitosamente', token, user });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error interno del servidor' });
    }
});

server.post('/api/register/resend-code', async (request, reply) => {
    const { email } = request.body as any;

    if (!email) {
        return reply.status(400).send({ message: 'El correo es obligatorio' });
    }

    try {
        const [rows]: any = await pool.execute(
            'SELECT id, nombre, whatsapp, verificado FROM usuarios WHERE email = ?',
            [email]
        );

        if (rows.length === 0) {
            return reply.status(404).send({ message: 'Usuario no encontrado' });
        }

        const userRow = rows[0];

        if (userRow.verificado) {
            return reply.status(400).send({ message: 'El usuario ya está verificado' });
        }

        const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

        await pool.execute(
            'UPDATE usuarios SET codigo_verificacion = ? WHERE id = ?',
            [verificationCode, userRow.id]
        );

        const sent = await sendWhatsAppVerificationCode(userRow.whatsapp, verificationCode);
        if (!sent) {
            return reply.status(500).send({ message: 'Error al enviar el mensaje de WhatsApp. Inténtalo de nuevo.' });
        }

        return reply.send({ message: 'Nuevo código de verificación enviado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error interno del servidor' });
    }
});

server.post('/api/login', async (request, reply) => {
    const { email, password } = request.body as any;

    if (!email || !password) {
        return reply.status(400).send({ message: 'Email y contraseña son obligatorios' });
    }

    try {
        const hashedPassword = hashPassword(password);
        const [rows]: any = await pool.execute(
            'SELECT id, nombre, email, whatsapp, verificado FROM usuarios WHERE email = ? AND password = ?',
            [email, hashedPassword]
        );

        if (rows.length === 0) {
            return reply.status(401).send({ message: 'Credenciales inválidas' });
        }

        const userRow = rows[0];

        if (!userRow.verificado) {
            // Generar nuevo código de verificación
            const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();

            await pool.execute(
                'UPDATE usuarios SET codigo_verificacion = ? WHERE id = ?',
                [verificationCode, userRow.id]
            );

            // Enviar por WhatsApp
            const sent = await sendWhatsAppVerificationCode(userRow.whatsapp, verificationCode);
            if (!sent) {
                server.log.error(`No se pudo enviar el WhatsApp de verificación al iniciar sesión a ${userRow.whatsapp}`);
            }

            return reply.status(403).send({
                message: 'Tu cuenta no está verificada. Hemos enviado un nuevo código a tu WhatsApp.',
                verification_required: true,
                email: userRow.email,
                whatsapp: userRow.whatsapp
            });
        }

        const user = { id: userRow.id, nombre: userRow.nombre, email: userRow.email, whatsapp: userRow.whatsapp };
        const token = server.jwt.sign(user);

        return reply.send({ message: 'Login exitoso', token, user });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error interno del servidor' });
    }
});

// Middleware de autenticación
server.decorate('authenticate', async (request: any, reply: any) => {
    try {
        await request.jwtVerify();
    } catch (err) {
        reply.send(err);
    }
});

// --- TIEMPO REAL (SSE): la app recibe los cambios al instante ---
registrarTiempoReal(server);

// --- PAGOS CAPTURADOS (Apple Pay vía Atajos, notificaciones en Android) ---
registrarCapturas(server, { pool });
registrarInversiones(server, { pool });

// --- AGENDAMIENTO DE CITAS (lib/agenda) ---
registrarAgenda(server, {
    pool,
    enviarWhatsApp,
    webBase: (process.env.WEB_BASE_URL || 'https://agendaservi.com').replace(/\/+$/, '')
});

// --- RUTAS DE EVENTOS ---
server.get('/api/events', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM eventos WHERE user_id = ? ORDER BY fecha ASC, hora ASC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener eventos' });
    }
});

// Calcula el rango [inicio, inicioSiguienteMes) de un mes dado (mes: 1-12).
function monthBounds(mes: number, anio: number) {
    const start = `${anio}-${String(mes).padStart(2, '0')}-01`;
    const ny = mes === 12 ? anio + 1 : anio;
    const nm = mes === 12 ? 1 : mes + 1;
    const nextStart = `${ny}-${String(nm).padStart(2, '0')}-01`;
    return { start, nextStart };
}

// --- BOOTSTRAP (GLOBAL): datos acotados que NO dependen del mes ---
// Se llama una sola vez por sesión. Volumen pequeño y estable por usuario.
server.get('/api/dashboard/bootstrap', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        const userId = request.user.id;

        // Asegura categorías por defecto antes de consultarlas
        await ensureDefaultCategories(conn, userId);

        const [
            [cumpleanos],
            [cycles],
            [habits],
            [cuentas],
            [ingresosPlanificados],
            [verificaciones],
            [metas],
            [categorias],
            [usadasTx],
            [usadasPres]
        ]: any = await Promise.all([
            conn.execute('SELECT * FROM cumpleanos WHERE user_id = ? ORDER BY fecha ASC', [userId]),
            conn.execute('SELECT * FROM ciclos_menstruales WHERE user_id = ? ORDER BY fecha_inicio DESC', [userId]),
            conn.execute('SELECT * FROM habitos WHERE user_id = ? AND activo = true ORDER BY created_at ASC', [userId]),
            conn.execute('SELECT * FROM finanzas_cuentas WHERE user_id = ? ORDER BY nombre ASC', [userId]),
            conn.execute('SELECT * FROM finanzas_ingresos_planificados WHERE user_id = ? ORDER BY fecha_inicio ASC', [userId]),
            conn.execute('SELECT * FROM finanzas_ingresos_verificados WHERE user_id = ?', [userId]),
            conn.execute('SELECT * FROM finanzas_metas WHERE user_id = ? ORDER BY completada ASC, created_at DESC', [userId]),
            conn.execute('SELECT id, valor, label, icono, es_default FROM finanzas_categorias WHERE user_id = ? ORDER BY es_default DESC, label ASC', [userId]),
            conn.execute('SELECT DISTINCT categoria FROM finanzas_transacciones WHERE user_id = ? AND categoria IS NOT NULL', [userId]),
            conn.execute('SELECT DISTINCT categoria FROM finanzas_presupuestos WHERE user_id = ? AND categoria IS NOT NULL', [userId])
        ]);

        // Conjunto de categorías en uso (para bloquear su borrado en la UI),
        // calculado en servidor sin traer todo el histórico de transacciones.
        const categoriasUsadas = Array.from(new Set([
            ...usadasTx.map((r: any) => r.categoria),
            ...usadasPres.map((r: any) => r.categoria)
        ]));

        return reply.send({
            cumpleanos, cycles, habits, categoriasUsadas,
            finanzas: { cuentas, ingresosPlanificados, verificaciones, metas, categorias }
        });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al cargar los datos del dashboard' });
    } finally {
        conn.release();
    }
});

// --- MONTH: datos de alto volumen, acotados a un solo mes ---
// Se llama al cargar y cada vez que el usuario cambia de mes en el calendario.
server.get('/api/dashboard/month', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        const userId = request.user.id;
        const q = request.query as any;
        const now = new Date();
        const mes = q.mes !== undefined ? Number(q.mes) : now.getMonth() + 1;
        const anio = q.anio !== undefined ? Number(q.anio) : now.getFullYear();
        const { start, nextStart } = monthBounds(mes, anio);

        const [
            [events],
            [transacciones],
            [notes],
            [habitLogs],
            [presupuestos],
            [transferencias]
        ]: any = await Promise.all([
            conn.execute('SELECT * FROM eventos WHERE user_id = ? AND fecha >= ? AND fecha < ? ORDER BY fecha ASC, hora ASC', [userId, start, nextStart]),
            conn.execute('SELECT * FROM finanzas_transacciones WHERE user_id = ? AND fecha >= ? AND fecha < ? ORDER BY fecha DESC, id DESC', [userId, start, nextStart]),
            conn.execute('SELECT * FROM notas WHERE user_id = ? AND fecha >= ? AND fecha < ? ORDER BY fecha DESC, created_at DESC', [userId, start, nextStart]),
            conn.execute('SELECT * FROM habitos_log WHERE user_id = ? AND fecha >= ? AND fecha < ? ORDER BY fecha DESC', [userId, start, nextStart]),
            conn.execute('SELECT * FROM finanzas_presupuestos WHERE user_id = ? AND mes = ? AND anio = ? ORDER BY categoria ASC', [userId, mes, anio]),
            conn.execute('SELECT * FROM finanzas_transferencias WHERE user_id = ? AND fecha >= ? AND fecha < ? ORDER BY fecha DESC, id DESC', [userId, start, nextStart])
        ]);

        return reply.send({ events, transacciones, notes, habitLogs, presupuestos, transferencias });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al cargar el mes' });
    } finally {
        conn.release();
    }
});

// --- ANALYTICS: transacciones de un rango para las gráficas (carga perezosa) ---
// Devuelve sólo los campos que usan las gráficas para minimizar el payload.
server.get('/api/finanzas/analytics', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const q = request.query as any;
        let dias = q.dias !== undefined ? Math.floor(Number(q.dias)) : 30;
        if (!Number.isFinite(dias) || dias < 1) dias = 30;
        if (dias > 366) dias = 366; // tope de 1 año (entero saneado, seguro de interpolar)

        const [rows]: any = await pool.execute(
            `SELECT DATE_FORMAT(fecha, "%Y-%m-%d") as fecha, tipo, monto, categoria FROM finanzas_transacciones WHERE user_id = ? AND fecha >= DATE_SUB(CURDATE(), INTERVAL ${dias} DAY) ORDER BY fecha ASC`,
            [userId]
        );
        return reply.send({ transacciones: rows });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al cargar analíticas' });
    }
});

// Helper to physically expand recurring events in the database
async function generateFutureOccurrences(userId: number, masterId: number, baseDateStr: string, freq: string, body: any) {
    const { titulo, hora, categoria, ubicacion, costo, tipo_transaccion } = body;
    
    let maxOccurrences = 0;
    if (freq === 'diaria') maxOccurrences = 90; // 3 meses
    else if (freq === 'quincenal') maxOccurrences = 48; // 2 años
    else if (freq === 'mensual') maxOccurrences = 24; // 2 años
    else if (freq === 'trimestral') maxOccurrences = 8; // 2 años
    else if (freq === 'semestral') maxOccurrences = 4; // 2 años
    else if (freq === 'anual') maxOccurrences = 5; // 5 años
    
    if (maxOccurrences === 0) return;
    
    const baseDate = new Date(baseDateStr + 'T00:00:00');
    
    for (let i = 1; i <= maxOccurrences; i++) {
        const occurrenceDate = new Date(baseDate);
        
        if (freq === 'diaria') {
            occurrenceDate.setDate(baseDate.getDate() + i);
        } else if (freq === 'quincenal') {
            occurrenceDate.setDate(baseDate.getDate() + 15 * i);
        } else if (freq === 'mensual' || freq === 'trimestral' || freq === 'semestral' || freq === 'anual') {
            const step = freq === 'mensual' ? i : freq === 'trimestral' ? 3 * i : freq === 'semestral' ? 6 * i : 12 * i;
            const expectedMonth = baseDate.getMonth() + step;
            const targetMonth = expectedMonth % 12;
            const targetYear = baseDate.getFullYear() + Math.floor(expectedMonth / 12);
            const lastDayOfTargetMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
            const targetDay = Math.min(baseDate.getDate(), lastDayOfTargetMonth);
            occurrenceDate.setFullYear(targetYear);
            occurrenceDate.setMonth(targetMonth);
            occurrenceDate.setDate(targetDay);
        }
        
        const y = occurrenceDate.getFullYear();
        const m = String(occurrenceDate.getMonth() + 1).padStart(2, '0');
        const d = String(occurrenceDate.getDate()).padStart(2, '0');
        const occurrenceDateStr = `${y}-${m}-${d}`;
        const uuidConfirmacion = crypto.randomUUID();
        
        await pool.execute(
            'INSERT INTO eventos (user_id, titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago, uuid_confirmacion, parent_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
                userId,
                titulo,
                occurrenceDateStr,
                hora || null,
                categoria || 'general',
                ubicacion || '',
                'unica', // Mantener repeticion como 'unica' para evitar duplicación del bot
                freq,
                costo || 0.00,
                tipo_transaccion || 'ninguno',
                'pendiente', // Ocurrencias futuras inician como pendientes
                uuidConfirmacion,
                masterId
            ]
        );
    }
}

server.post('/api/events', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago } = request.body;
        const uuidConfirmacion = crypto.randomUUID();
        const freq = frecuencia || repeticion || 'unica';
        
        const [result]: any = await pool.execute(
            'INSERT INTO eventos (user_id, titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago, uuid_confirmacion, parent_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
                userId,
                titulo,
                fecha,
                hora || null,
                categoria || 'general',
                ubicacion || '',
                'unica', // Guardar repeticion como 'unica' para no confundir al bot handler legacy
                freq,
                costo || 0.00,
                tipo_transaccion || 'ninguno',
                estado_pago || 'pendiente',
                uuidConfirmacion,
                null // Master event has parent_id = NULL
            ]
        );
        
        const masterId = result.insertId;
        
        // Generar ocurrencias futuras si aplica
        if (freq !== 'unica') {
            await generateFutureOccurrences(userId, masterId, fecha, freq, request.body);
        }
        
        return reply.send({ id: masterId, uuid_confirmacion: uuidConfirmacion, message: 'Evento creado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear evento' });
    }
});

server.put('/api/events/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago } = request.body;
        const { editMode } = request.query as any;
        const mode = editMode || 'instance';
        
        // Fetch original event
        const [rows]: any = await pool.execute('SELECT * FROM eventos WHERE id = ? AND user_id = ?', [id, userId]);
        if (rows.length === 0) {
            return reply.status(404).send({ message: 'Evento no encontrado' });
        }
        const original = rows[0];
        const freq = frecuencia || repeticion || original.frecuencia || 'unica';
        
        if (mode === 'future') {
            const parentId = original.parent_id || original.id;
            
            // 1. Update this instance
            await pool.execute(
                'UPDATE eventos SET titulo = ?, fecha = ?, hora = ?, categoria = ?, ubicacion = ?, repeticion = "unica", frecuencia = ?, costo = ?, tipo_transaccion = ?, estado_pago = ? WHERE id = ? AND user_id = ?',
                [
                    titulo,
                    fecha,
                    hora || null,
                    categoria || 'general',
                    ubicacion || '',
                    freq,
                    costo || 0.00,
                    tipo_transaccion || 'ninguno',
                    estado_pago || 'pendiente',
                    id,
                    userId
                ]
            );
            
            // 2. Delete all future pending occurrences of this series
            await pool.execute(
                'DELETE FROM eventos WHERE parent_id = ? AND fecha > ? AND user_id = ? AND (estado_pago = "pendiente" OR estado_pago IS NULL)',
                [parentId, original.fecha, userId]
            );
            
            // 3. If new frequency is not single, regenerate occurrences starting from new date
            if (freq !== 'unica') {
                await generateFutureOccurrences(userId, parentId, fecha, freq, request.body);
            }
        } else {
            // Edit only this instance
            // If new frequency is 'unica', deselect parent_id
            const newParentId = freq === 'unica' ? null : original.parent_id;
            await pool.execute(
                'UPDATE eventos SET titulo = ?, fecha = ?, hora = ?, categoria = ?, ubicacion = ?, repeticion = "unica", frecuencia = ?, costo = ?, tipo_transaccion = ?, estado_pago = ?, parent_id = ? WHERE id = ? AND user_id = ?',
                [
                    titulo,
                    fecha,
                    hora || null,
                    categoria || 'general',
                    ubicacion || '',
                    freq,
                    costo || 0.00,
                    tipo_transaccion || 'ninguno',
                    estado_pago || 'pendiente',
                    newParentId,
                    id,
                    userId
                ]
            );
        }
        
        return reply.send({ message: 'Evento actualizado correctamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar evento' });
    }
});

server.delete('/api/events/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { deleteMode } = request.query as any;
        const mode = deleteMode || 'instance';
        
        // Fetch target event
        const [rows]: any = await pool.execute('SELECT * FROM eventos WHERE id = ? AND user_id = ?', [id, userId]);
        if (rows.length === 0) {
            return reply.status(404).send({ message: 'Evento no encontrado' });
        }
        const event = rows[0];
        
        if (mode === 'future') {
            const parentId = event.parent_id || event.id;
            // Delete this and future pending occurrences
            await pool.execute(
                'DELETE FROM eventos WHERE (id = ? OR parent_id = ?) AND fecha >= ? AND user_id = ? AND (estado_pago = "pendiente" OR estado_pago IS NULL)',
                [id, parentId, event.fecha, userId]
            );
        } else {
            // Delete instance only
            await pool.execute(
                'DELETE FROM eventos WHERE id = ? AND user_id = ?',
                [id, userId]
            );
        }
        
        return reply.send({ message: 'Evento eliminado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar evento' });
    }
});

// Cambiar estado de pago (autenticado)
server.put('/api/events/:id/toggle-pago', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { estado_pago } = request.body;
        const [result]: any = await pool.execute(
            'UPDATE eventos SET estado_pago = ? WHERE id = ? AND user_id = ?',
            [estado_pago, id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Evento no encontrado' });
        }
        return reply.send({ message: 'Estado de pago actualizado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar pago' });
    }
});

// --- RUTAS PÚBLICAS DE CONFIRMACIÓN ---
server.get('/api/public/events/confirmar/:uuid', async (request: any, reply: any) => {
    try {
        const { uuid } = request.params;
        const [rows]: any = await pool.execute(
            'SELECT e.id, e.user_id, e.titulo, e.fecha, e.hora, e.categoria, e.ubicacion, e.costo, e.tipo_transaccion, e.estado_pago, e.tarjeta_credito_id, u.nombre as creador FROM eventos e JOIN usuarios u ON e.user_id = u.id WHERE e.uuid_confirmacion = ?',
            [uuid]
        );
        if (rows.length === 0) {
            return reply.status(404).send({ message: 'Evento no encontrado' });
        }
        const eventData = rows[0];

        // Fetch accounts of the event's user
        const [accounts]: any = await pool.execute(
            'SELECT id, nombre, tipo, saldo FROM finanzas_cuentas WHERE user_id = ? ORDER BY nombre ASC',
            [eventData.user_id]
        );

        // Ensure default categories exist and fetch all of the user's finance categories
        const conn = await pool.getConnection();
        let categorias: any[] = [];
        try {
            await ensureDefaultCategories(conn, eventData.user_id);
            const [catRows]: any = await conn.execute(
                'SELECT id, valor, label, icono FROM finanzas_categorias WHERE user_id = ? ORDER BY es_default DESC, label ASC',
                [eventData.user_id]
            );
            categorias = catRows;
        } finally {
            conn.release();
        }

        return reply.send({
            ...eventData,
            cuentas: accounts,
            categorias
        });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener confirmación' });
    }
});

server.post('/api/public/events/confirmar/:uuid', async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const { uuid } = request.params;
        const { estado, costo, registrarTransaccion, cuentaId, categoriaTransaccion } = request.body || {};

        // 1. Get the event details first
        const [eventRows]: any = await conn.execute(
            'SELECT id, user_id, titulo, DATE_FORMAT(fecha, "%Y-%m-%d") as fecha, costo, tipo_transaccion, tarjeta_credito_id FROM eventos WHERE uuid_confirmacion = ?',
            [uuid]
        );
        if (eventRows.length === 0) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Evento no encontrado' });
        }
        const event = eventRows[0];

        const nuevoEstado = estado || 'pagado';
        const nuevoCosto = costo !== undefined ? Number(costo) : Number(event.costo);

        // 2. Update the event payment status and cost
        await conn.execute(
            'UPDATE eventos SET estado_pago = ?, costo = ? WHERE id = ?',
            [nuevoEstado, nuevoCosto, event.id]
        );

        // 3. Register transaction if requested and valid
        if (registrarTransaccion && cuentaId) {
            const descripcionTx = `Confirmación: ${event.titulo}`;
            const fechaTx = event.fecha; // Use the event's date
            const categoriaTx = categoriaTransaccion || 'otros';

            // Check if paying account is a credit card
            const [accRows]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [cuentaId, event.user_id]);
            const isCreditCard = accRows.length > 0 && accRows[0].tipo === 'tarjeta_credito';

            // Create transaction for paying account
            await conn.execute(
                'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria) VALUES (?, ?, "gasto", ?, ?, ?, ?)',
                [event.user_id, cuentaId, nuevoCosto, descripcionTx, fechaTx, categoriaTx]
            );

            // Update account balance of paying account
            if (isCreditCard) {
                await conn.execute(
                    'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                    [nuevoCosto, cuentaId, event.user_id]
                );
            } else {
                await conn.execute(
                    'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                    [nuevoCosto, cuentaId, event.user_id]
                );
            }

            // If this event is linked to a credit card payment (installments)
            if (event.tarjeta_credito_id) {
                // Register transaction for credit card (repayment)
                const descRepay = `Abono de deuda: ${event.titulo}`;
                await conn.execute(
                    'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria) VALUES (?, ?, "ingreso", ?, ?, ?, ?)',
                    [event.user_id, event.tarjeta_credito_id, nuevoCosto, descRepay, fechaTx, 'otros']
                );

                // Update credit card balance (reduce debt)
                await conn.execute(
                    'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                    [nuevoCosto, event.tarjeta_credito_id, event.user_id]
                );
            }
        }

        await conn.commit();
        return reply.send({ message: 'Evento confirmado exitosamente' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al confirmar evento' });
    } finally {
        conn.release();
    }
});

// Editar costo (público mediante UUID)
server.post('/api/public/events/confirmar/:uuid/costo', async (request: any, reply: any) => {
    try {
        const { uuid } = request.params;
        const { costo } = request.body || {};
        if (costo === undefined) {
            return reply.status(400).send({ message: 'El costo es requerido' });
        }
        const [result]: any = await pool.execute(
            'UPDATE eventos SET costo = ? WHERE uuid_confirmacion = ?',
            [costo, uuid]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Evento no encontrado o no modificado' });
        }
        return reply.send({ message: 'Costo actualizado exitosamente', costo });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar el costo' });
    }
});

// --- DISPOSITIVOS (NOTIFICACIONES PUSH DE LA APP MÓVIL) ---
// La app registra aquí su token de Firebase Cloud Messaging. El cron lo usa
// para avisar al teléfono a la misma hora que envía el WhatsApp, aunque la app
// esté cerrada. `pendiente` indica que aún no se ha enviado la notificación de
// bienvenida (la app mantiene sus avisos locales hasta que el servidor confirma).
const PLATAFORMAS_PUSH = new Set(['android', 'ios']);

function tokenPushValido(token: any): token is string {
    return typeof token === 'string' && token.length >= 20 && token.length <= 255 && !/\s/.test(token);
}

server.post('/api/dispositivos', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const userId = request.user.id;
    const { token, plataforma, avisos = true, aviso_30m = true, resumen = true } = request.body || {};
    if (!tokenPushValido(token)) return reply.status(400).send({ message: 'Token de notificaciones inválido' });
    if (!PLATAFORMAS_PUSH.has(plataforma)) return reply.status(400).send({ message: 'Plataforma no soportada' });
    try {
        // Si el token ya existía para otro usuario (cambio de cuenta en el mismo
        // teléfono) pasa al usuario actual y vuelve a esperar la bienvenida.
        await pool.execute(
            `INSERT INTO dispositivos_push (user_id, token, plataforma, avisos, aviso_30m, resumen, bienvenida_pendiente)
             VALUES (?, ?, ?, ?, ?, ?, 1)
             ON DUPLICATE KEY UPDATE
                bienvenida_pendiente = IF(user_id = VALUES(user_id), bienvenida_pendiente, 1),
                confirmado = IF(user_id = VALUES(user_id), confirmado, 0),
                user_id = VALUES(user_id),
                plataforma = VALUES(plataforma),
                avisos = VALUES(avisos),
                aviso_30m = VALUES(aviso_30m),
                resumen = VALUES(resumen),
                actualizado = CURRENT_TIMESTAMP`,
            [userId, token, plataforma, avisos ? 1 : 0, aviso_30m ? 1 : 0, resumen ? 1 : 0]
        );
        const [rows]: any = await pool.execute(
            'SELECT bienvenida_pendiente, confirmado FROM dispositivos_push WHERE token = ?',
            [token]
        );
        return reply.send({
            ok: true,
            pendiente: !!rows[0]?.bienvenida_pendiente,
            confirmado: !!rows[0]?.confirmado
        });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al registrar el dispositivo' });
    }
});

// Baja del dispositivo al cerrar sesión (POST con cuerpo para no exponer el
// token en la URL ni en los logs de acceso).
server.post('/api/dispositivos/baja', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const userId = request.user.id;
    const { token } = request.body || {};
    if (!tokenPushValido(token)) return reply.status(400).send({ message: 'Token de notificaciones inválido' });
    try {
        await pool.execute('DELETE FROM dispositivos_push WHERE token = ? AND user_id = ?', [token, userId]);
        return reply.send({ ok: true });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al dar de baja el dispositivo' });
    }
});

// --- RUTAS DE CICLOS MENSTRUALES ---
server.get('/api/cycles', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM ciclos_menstruales WHERE user_id = ? ORDER BY fecha_inicio DESC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener ciclos' });
    }
});

server.post('/api/cycles', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { fecha_inicio, observacion, dias_sangrado } = request.body || {};

        const error = validarFechaCiclo(fecha_inicio) || validarDiasSangrado(dias_sangrado);
        if (error) return reply.status(400).send({ message: error });

        const [dup]: any = await pool.execute(
            'SELECT id FROM ciclos_menstruales WHERE user_id = ? AND fecha_inicio = ?',
            [userId, fecha_inicio]
        );
        if (dup.length > 0) {
            return reply.status(409).send({ message: 'Ya tienes un ciclo registrado en esa fecha', id: dup[0].id });
        }

        const [result]: any = await pool.execute(
            'INSERT INTO ciclos_menstruales (user_id, fecha_inicio, observacion, dias_sangrado) VALUES (?, ?, ?, ?)',
            [userId, fecha_inicio, observacion || '', normalizarDiasSangrado(dias_sangrado)]
        );

        // Aviso no bloqueante: dos inicios muy seguidos suelen ser un registro
        // por error, y el usuario debería poder corregirlo antes de confiar en
        // la predicción. No impedimos guardarlo porque también puede ser real.
        const [vecino]: any = await pool.execute(
            'SELECT DATEDIFF(?, fecha_inicio) AS dias FROM ciclos_menstruales WHERE user_id = ? AND fecha_inicio < ? ORDER BY fecha_inicio DESC LIMIT 1',
            [fecha_inicio, userId, fecha_inicio]
        );
        const advertencia = vecino.length > 0 && vecino[0].dias < 10
            ? `El ciclo anterior empezó hace solo ${vecino[0].dias} día(s). Si fue un registro por error, puedes eliminarlo desde el historial.`
            : null;

        return reply.send({ id: result.insertId, message: 'Ciclo registrado', advertencia });
    } catch (err: any) {
        if (err.code === 'ER_DUP_ENTRY') {
            return reply.status(409).send({ message: 'Ya tienes un ciclo registrado en esa fecha' });
        }
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al registrar ciclo' });
    }
});

server.put('/api/cycles/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { fecha_inicio, observacion, dias_sangrado } = request.body || {};

        const error = validarFechaCiclo(fecha_inicio) || validarDiasSangrado(dias_sangrado);
        if (error) return reply.status(400).send({ message: error });

        const [dup]: any = await pool.execute(
            'SELECT id FROM ciclos_menstruales WHERE user_id = ? AND fecha_inicio = ? AND id <> ?',
            [userId, fecha_inicio, id]
        );
        if (dup.length > 0) {
            return reply.status(409).send({ message: 'Ya tienes otro ciclo registrado en esa fecha' });
        }

        const [result]: any = await pool.execute(
            'UPDATE ciclos_menstruales SET fecha_inicio = ?, observacion = ?, dias_sangrado = ? WHERE id = ? AND user_id = ?',
            [fecha_inicio, observacion || '', normalizarDiasSangrado(dias_sangrado), id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Ciclo no encontrado' });
        }
        return reply.send({ message: 'Ciclo actualizado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar el ciclo' });
    }
});

server.delete('/api/cycles/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute(
            'DELETE FROM ciclos_menstruales WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Ciclo no encontrado' });
        }
        return reply.send({ message: 'Ciclo eliminado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar el ciclo' });
    }
});

import { calculateImportantDate } from './lib/dateUtils';

// --- RUTAS DE DÍAS IMPORTANTES ---
server.get('/api/important-days', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const { year } = request.query;
        const targetYear = year ? Number(year) : new Date().getFullYear();
        
        const [rows]: any = await pool.execute('SELECT * FROM dias_importantes');
        
        const important = [];
        for (const row of rows) {
            const dateObj = calculateImportantDate(row.regla, targetYear);
            if (!dateObj) continue;

            const y = dateObj.getFullYear();
            const m = String(dateObj.getMonth() + 1).padStart(2, '0');
            const d = String(dateObj.getDate()).padStart(2, '0');

            important.push({
                ...row,
                date: `${y}-${m}-${d}`
            });
        }
        
        return reply.send(important);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener días importantes' });
    }
});

// --- RUTAS DE NOTAS ---
server.get('/api/notes', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM notas WHERE user_id = ? ORDER BY fecha DESC, created_at DESC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener notas' });
    }
});

server.post('/api/notes', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { fecha, contenido, etiqueta, color } = request.body;
        if (!fecha || !contenido) {
            return reply.status(400).send({ message: 'Fecha y contenido son obligatorios' });
        }
        const [result]: any = await pool.execute(
            'INSERT INTO notas (user_id, fecha, contenido, etiqueta, color) VALUES (?, ?, ?, ?, ?)',
            [userId, fecha, contenido, etiqueta || 'personal', color || '#4FC3F7']
        );
        return reply.send({ id: result.insertId, message: 'Nota creada' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear nota' });
    }
});

server.put('/api/notes/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { contenido, etiqueta, color } = request.body;
        if (!contenido) {
            return reply.status(400).send({ message: 'El contenido es obligatorio' });
        }
        const [result]: any = await pool.execute(
            'UPDATE notas SET contenido = ?, etiqueta = ?, color = ? WHERE id = ? AND user_id = ?',
            [contenido, etiqueta || 'personal', color || '#4FC3F7', id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Nota no encontrada' });
        }
        return reply.send({ message: 'Nota actualizada' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar nota' });
    }
});

server.delete('/api/notes/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute(
            'DELETE FROM notas WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Nota no encontrada' });
        }
        return reply.send({ message: 'Nota eliminada' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar nota' });
    }
});

// --- RUTAS DE HÁBITOS ---
server.get('/api/habits', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM habitos WHERE user_id = ? AND activo = true ORDER BY created_at ASC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener hábitos' });
    }
});

server.post('/api/habits', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { nombre, icono, color, frecuencia, meta_diaria } = request.body;
        if (!nombre) {
            return reply.status(400).send({ message: 'El nombre del hábito es obligatorio' });
        }
        const [result]: any = await pool.execute(
            'INSERT INTO habitos (user_id, nombre, icono, color, frecuencia, meta_diaria) VALUES (?, ?, ?, ?, ?, ?)',
            [userId, nombre, icono || 'check_circle', color || '#4CAF50', frecuencia || 'diario', meta_diaria || 1]
        );
        return reply.send({ id: result.insertId, message: 'Hábito creado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear hábito' });
    }
});

server.put('/api/habits/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { nombre, icono, color, frecuencia, meta_diaria, activo } = request.body;
        const [result]: any = await pool.execute(
            'UPDATE habitos SET nombre = ?, icono = ?, color = ?, frecuencia = ?, meta_diaria = ?, activo = ? WHERE id = ? AND user_id = ?',
            [nombre, icono, color, frecuencia, meta_diaria, activo !== undefined ? activo : true, id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Hábito no encontrado' });
        }
        return reply.send({ message: 'Hábito actualizado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar hábito' });
    }
});

server.delete('/api/habits/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute(
            'DELETE FROM habitos WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Hábito no encontrado' });
        }
        return reply.send({ message: 'Hábito eliminado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar hábito' });
    }
});

// Logs de hábitos
server.get('/api/habits/logs', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM habitos_log WHERE user_id = ? ORDER BY fecha DESC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener registros de hábitos' });
    }
});

server.post('/api/habits/log', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { habito_id, fecha, completado, cantidad } = request.body;
        if (!habito_id || !fecha) {
            return reply.status(400).send({ message: 'habito_id y fecha son obligatorios' });
        }

        const [result]: any = await pool.execute(
            'INSERT INTO habitos_log (habito_id, user_id, fecha, completado, cantidad) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE completado = VALUES(completado), cantidad = VALUES(cantidad)',
            [habito_id, userId, fecha, completado !== undefined ? completado : true, cantidad !== undefined ? cantidad : 1]
        );
        return reply.send({ message: 'Registro de hábito guardado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al registrar progreso de hábito' });
    }
});
// Cumpleaños
server.get('/api/cumpleanos', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM cumpleanos WHERE user_id = ? ORDER BY fecha ASC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener cumpleaños' });
    }
});

server.post('/api/cumpleanos', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { nombre, fecha, anio_nacimiento, mensaje, telefono } = request.body;
        if (!nombre || !fecha) {
            return reply.status(400).send({ message: 'Nombre y fecha son obligatorios' });
        }

        const [result]: any = await pool.execute(
            'INSERT INTO cumpleanos (user_id, nombre, fecha, anio_nacimiento, mensaje, telefono) VALUES (?, ?, ?, ?, ?, ?)',
            [userId, nombre, fecha, anio_nacimiento || null, mensaje || null, telefono || null]
        );
        return reply.status(201).send({ id: result.insertId, message: 'Cumpleaños creado exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear cumpleaños' });
    }
});

server.put('/api/cumpleanos/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { nombre, fecha, anio_nacimiento, mensaje, telefono } = request.body;
        
        const [result]: any = await pool.execute(
            'UPDATE cumpleanos SET nombre = ?, fecha = ?, anio_nacimiento = ?, mensaje = ?, telefono = ? WHERE id = ? AND user_id = ?',
            [nombre, fecha, anio_nacimiento || null, mensaje || null, telefono || null, id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Cumpleaños no encontrado' });
        }
        return reply.send({ message: 'Cumpleaños actualizado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar cumpleaños' });
    }
});

server.delete('/api/cumpleanos/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute(
            'DELETE FROM cumpleanos WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Cumpleaños no encontrado' });
        }
        return reply.send({ message: 'Cumpleaños eliminado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar cumpleaños' });
    }
});

// --- RUTAS DE FINANZAS ---

// 1. Cuentas / Tarjetas
server.get('/api/finanzas/cuentas', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM finanzas_cuentas WHERE user_id = ? ORDER BY nombre ASC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener cuentas' });
    }
});

server.post('/api/finanzas/cuentas', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { nombre, tipo, saldo, limite, interes_tasa, fecha_inicio, plazo_dias, dia_corte } = request.body;
        if (!nombre || !tipo) {
            return reply.status(400).send({ message: 'Nombre y tipo son obligatorios' });
        }
        const diaCorteVal = (tipo === 'tarjeta_credito' && dia_corte) ? Number(dia_corte) : null;
        const [result]: any = await pool.execute(
            'INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo, limite, interes_tasa, fecha_inicio, plazo_dias, dia_corte) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
                userId,
                nombre,
                tipo,
                saldo || 0.00,
                limite || 0.00,
                interes_tasa !== undefined ? Number(interes_tasa) : 0.00,
                fecha_inicio || null,
                plazo_dias !== undefined ? Number(plazo_dias) : 0,
                diaCorteVal
            ]
        );
        return reply.status(201).send({ id: result.insertId, message: 'Cuenta creada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear cuenta' });
    }
});

server.put('/api/finanzas/cuentas/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { nombre, tipo, saldo, limite, interes_tasa, fecha_inicio, plazo_dias, dia_corte } = request.body;
        if (!nombre || !tipo) {
            return reply.status(400).send({ message: 'Nombre y tipo son obligatorios' });
        }
        const diaCorteVal = (tipo === 'tarjeta_credito' && dia_corte) ? Number(dia_corte) : null;
        const [result]: any = await pool.execute(
            'UPDATE finanzas_cuentas SET nombre = ?, tipo = ?, saldo = ?, limite = ?, interes_tasa = ?, fecha_inicio = ?, plazo_dias = ?, dia_corte = ? WHERE id = ? AND user_id = ?',
            [
                nombre,
                tipo,
                saldo || 0.00,
                limite || 0.00,
                interes_tasa !== undefined ? Number(interes_tasa) : 0.00,
                fecha_inicio || null,
                plazo_dias !== undefined ? Number(plazo_dias) : 0,
                diaCorteVal,
                id,
                userId
            ]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Cuenta no encontrada' });
        }
        return reply.send({ message: 'Cuenta actualizada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar cuenta' });
    }
});

server.delete('/api/finanzas/cuentas/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute('DELETE FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [id, userId]);
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Cuenta no encontrada' });
        }
        return reply.send({ message: 'Cuenta eliminada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar cuenta' });
    }
});

// 2. Ingresos Planificados
server.get('/api/finanzas/ingresos-planificados', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM finanzas_ingresos_planificados WHERE user_id = ? ORDER BY fecha_inicio ASC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener ingresos planificados' });
    }
});

server.post('/api/finanzas/ingresos-planificados', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { cuenta_id, descripcion, monto, frecuencia, fecha_inicio } = request.body;
        if (!descripcion || !monto || !frecuencia || !fecha_inicio) {
            return reply.status(400).send({ message: 'Campos requeridos faltantes' });
        }
        const [result]: any = await pool.execute(
            'INSERT INTO finanzas_ingresos_planificados (user_id, cuenta_id, descripcion, monto, frecuencia, fecha_inicio) VALUES (?, ?, ?, ?, ?, ?)',
            [userId, cuenta_id || null, descripcion, monto, frecuencia, fecha_inicio]
        );
        return reply.status(201).send({ id: result.insertId, message: 'Ingreso planificado creado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear ingreso planificado' });
    }
});

server.delete('/api/finanzas/ingresos-planificados/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute('DELETE FROM finanzas_ingresos_planificados WHERE id = ? AND user_id = ?', [id, userId]);
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Planificación no encontrada' });
        }
        return reply.send({ message: 'Ingreso planificado eliminado' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar ingreso planificado' });
    }
});

// 3. Transacciones reales
server.get('/api/finanzas/transacciones', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM finanzas_transacciones WHERE user_id = ? ORDER BY fecha DESC, id DESC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener transacciones' });
    }
});

server.post('/api/finanzas/transacciones', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { cuenta_id, tipo, monto, descripcion, fecha, categoria, cuotas } = request.body;
        if (!tipo || !monto || !descripcion || !fecha) {
            await conn.rollback();
            return reply.status(400).send({ message: 'Campos requeridos faltantes' });
        }

        const numCuotas = cuotas ? Number(cuotas) : 1;

        const [txResult]: any = await conn.execute(
            'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, categoria, cuotas) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [userId, cuenta_id || null, tipo, monto, descripcion, fecha, categoria || 'otros', numCuotas]
        );

        const txId = txResult.insertId;

        if (cuenta_id) {
            // Check account type and billing cut-off day
            const [accRows]: any = await conn.execute('SELECT tipo, dia_corte FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [cuenta_id, userId]);
            const isCreditCard = accRows.length > 0 && accRows[0].tipo === 'tarjeta_credito';
            const diaCorte: number | null = accRows.length > 0 ? accRows[0].dia_corte : null;

            if (tipo === 'ingreso') {
                if (isCreditCard) {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                        [monto, cuenta_id, userId]
                    );
                } else {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                        [monto, cuenta_id, userId]
                    );
                }
            } else if (tipo === 'gasto') {
                if (isCreditCard) {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                        [monto, cuenta_id, userId]
                    );
                } else {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                        [monto, cuenta_id, userId]
                    );
                }
            }

            // Helper: calculates the next cut-off date on or after a given date
            function getNextCutoffDate(fromDate: Date, diaCorteDia: number): Date {
                const y = fromDate.getFullYear();
                const m = fromDate.getMonth();
                const d = fromDate.getDate();
                // Clamp dia_corte to last day of the month
                const lastDaySameMonth = new Date(y, m + 1, 0).getDate();
                const cutoffSameMonth = Math.min(diaCorteDia, lastDaySameMonth);
                if (d <= cutoffSameMonth) {
                    return new Date(y, m, cutoffSameMonth);
                }
                // Purchase day is past the cut-off; go to next month
                const nextMonth = m + 1;
                const nextYear = y + Math.floor(nextMonth / 12);
                const nm = nextMonth % 12;
                const lastDayNextMonth = new Date(nextYear, nm + 1, 0).getDate();
                return new Date(nextYear, nm, Math.min(diaCorteDia, lastDayNextMonth));
            }

            function dateToStr(dt: Date): string {
                const y = dt.getFullYear();
                const m = String(dt.getMonth() + 1).padStart(2, '0');
                const d = String(dt.getDate()).padStart(2, '0');
                return `${y}-${m}-${d}`;
            }

            // Generate calendar events for credit card gastos
            if (isCreditCard && tipo === 'gasto') {
                const baseDate = new Date(fecha + 'T00:00:00');

                // Calculate installment amounts
                const installmentBase = Number((Number(monto) / numCuotas).toFixed(2));
                const installments: number[] = [];
                let totalAllocated = 0;
                for (let i = 1; i <= numCuotas; i++) {
                    let instAmount = installmentBase;
                    if (i === numCuotas) {
                        instAmount = Number((Number(monto) - totalAllocated).toFixed(2));
                    } else {
                        totalAllocated += instAmount;
                    }
                    installments.push(instAmount);
                }

                for (let i = 1; i <= numCuotas; i++) {
                    let occurrenceDateStr: string;

                    if (diaCorte) {
                        // With cut-off day: first event goes to next cut-off, subsequent ones to following months' cut-offs
                        const firstCutoff = getNextCutoffDate(baseDate, diaCorte);
                        if (i === 1) {
                            occurrenceDateStr = dateToStr(firstCutoff);
                        } else {
                            const targetMonth = firstCutoff.getMonth() + (i - 1);
                            const targetYear = firstCutoff.getFullYear() + Math.floor(targetMonth / 12);
                            const nm = targetMonth % 12;
                            const lastDay = new Date(targetYear, nm + 1, 0).getDate();
                            occurrenceDateStr = dateToStr(new Date(targetYear, nm, Math.min(diaCorte, lastDay)));
                        }
                    } else {
                        // Without cut-off day: event at purchase-day of the following month(s).
                        // 1 cuota → 1 evento el mes siguiente; N cuotas → un evento por mes.
                        const expectedMonth = baseDate.getMonth() + i;
                        const targetMonth = expectedMonth % 12;
                        const targetYear = baseDate.getFullYear() + Math.floor(expectedMonth / 12);
                        const lastDay = new Date(targetYear, targetMonth + 1, 0).getDate();
                        const targetDay = Math.min(baseDate.getDate(), lastDay);
                        occurrenceDateStr = dateToStr(new Date(targetYear, targetMonth, targetDay));
                    }

                    const labelCuota = numCuotas > 1 ? `Cuota ${i}/${numCuotas}: ` : 'Cobro tarjeta: ';
                    const uuidConfirmacion = crypto.randomUUID();
                    await conn.execute(
                        'INSERT INTO eventos (user_id, titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago, uuid_confirmacion, parent_id, tarjeta_credito_id, transaccion_id) VALUES (?, ?, ?, "08:00:00", ?, "", "unica", "unica", ?, "gasto", "pendiente", ?, NULL, ?, ?)',
                        [
                            userId,
                            `${labelCuota}${descripcion}`,
                            occurrenceDateStr,
                            categoria || 'servicios',
                            installments[i - 1],
                            uuidConfirmacion,
                            cuenta_id,
                            txId
                        ]
                    );
                }
            }
        }

        await conn.commit();
        return reply.send({ id: txId, message: 'Transacción registrada' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al registrar transacción' });
    } finally {
        conn.release();
    }
});

server.delete('/api/finanzas/transacciones/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { id } = request.params;

        const [txRows]: any = await conn.execute('SELECT * FROM finanzas_transacciones WHERE id = ? AND user_id = ?', [id, userId]);
        if (txRows.length === 0) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Transacción no encontrada' });
        }
        const tx = txRows[0];

        await conn.execute('DELETE FROM finanzas_transacciones WHERE id = ?', [id]);

        if (tx.cuenta_id) {
            // Check account type
            const [accRows]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [tx.cuenta_id, userId]);
            const isCreditCard = accRows.length > 0 && accRows[0].tipo === 'tarjeta_credito';

            if (tx.tipo === 'ingreso') {
                if (isCreditCard) {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                        [tx.monto, tx.cuenta_id, userId]
                    );
                } else {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                        [tx.monto, tx.cuenta_id, userId]
                    );
                }
            } else if (tx.tipo === 'gasto') {
                if (isCreditCard) {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                        [tx.monto, tx.cuenta_id, userId]
                    );
                } else {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                        [tx.monto, tx.cuenta_id, userId]
                    );
                }
            }
        }

        // Delete associated installment events if any, but ONLY those that are pending payment
        await conn.execute(
            'DELETE FROM eventos WHERE transaccion_id = ? AND user_id = ? AND (estado_pago = "pendiente" OR estado_pago IS NULL)',
            [id, userId]
        );

        await conn.commit();
        return reply.send({ message: 'Transacción de tarjeta o cuenta eliminada' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar transacción' });
    } finally {
        conn.release();
    }
});

server.put('/api/finanzas/transacciones/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { id } = request.params;
        const { tipo, monto, descripcion, fecha, categoria, cuenta_id } = request.body as any;

        const [txRows]: any = await conn.execute(
            'SELECT * FROM finanzas_transacciones WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (txRows.length === 0) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Transacción no encontrada' });
        }
        const old = txRows[0];

        // Revert old effect on old account
        if (old.cuenta_id) {
            const [oldAccRows]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [old.cuenta_id, userId]);
            const oldIsCC = oldAccRows.length > 0 && oldAccRows[0].tipo === 'tarjeta_credito';
            if (old.tipo === 'ingreso') {
                if (oldIsCC) {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [old.monto, old.cuenta_id, userId]);
                } else {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?', [old.monto, old.cuenta_id, userId]);
                }
            } else {
                if (oldIsCC) {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?', [old.monto, old.cuenta_id, userId]);
                } else {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [old.monto, old.cuenta_id, userId]);
                }
            }
        }

        // Update transaction record
        await conn.execute(
            'UPDATE finanzas_transacciones SET tipo = ?, monto = ?, descripcion = ?, fecha = ?, categoria = ?, cuenta_id = ? WHERE id = ? AND user_id = ?',
            [tipo, monto, descripcion, fecha, categoria || 'otros', cuenta_id || null, id, userId]
        );

        // Apply new effect on new account
        if (cuenta_id) {
            const [newAccRows]: any = await conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [cuenta_id, userId]);
            const newIsCC = newAccRows.length > 0 && newAccRows[0].tipo === 'tarjeta_credito';
            if (tipo === 'ingreso') {
                if (newIsCC) {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?', [monto, cuenta_id, userId]);
                } else {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [monto, cuenta_id, userId]);
                }
            } else {
                if (newIsCC) {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [monto, cuenta_id, userId]);
                } else {
                    await conn.execute('UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?', [monto, cuenta_id, userId]);
                }
            }
        }

        await conn.commit();
        return reply.send({ message: 'Transacción actualizada' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar transacción' });
    } finally {
        conn.release();
    }
});

// --- TRANSFERENCIAS ENTRE CUENTAS ---
server.post('/api/finanzas/transferencias', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { cuenta_origen_id, cuenta_destino_id, monto, descripcion, fecha } = request.body as any;

        if (!cuenta_origen_id || !cuenta_destino_id || !monto || !fecha) {
            await conn.rollback();
            return reply.status(400).send({ message: 'Campos requeridos: origen, destino, monto, fecha' });
        }
        if (cuenta_origen_id === cuenta_destino_id) {
            await conn.rollback();
            return reply.status(400).send({ message: 'Las cuentas de origen y destino deben ser diferentes' });
        }

        const montoNum = Number(monto);
        if (isNaN(montoNum) || montoNum <= 0) {
            await conn.rollback();
            return reply.status(400).send({ message: 'El monto debe ser mayor a 0' });
        }

        // Obtener tipo de ambas cuentas para ajustar saldos correctamente
        const [[origenRows], [destinoRows]]: any = await Promise.all([
            conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [cuenta_origen_id, userId]),
            conn.execute('SELECT tipo FROM finanzas_cuentas WHERE id = ? AND user_id = ?', [cuenta_destino_id, userId])
        ]);
        if (!origenRows.length || !destinoRows.length) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Cuenta no encontrada' });
        }

        const tipoOrigen = origenRows[0].tipo;
        const tipoDestino = destinoRows[0].tipo;

        // Cuenta de crédito: saldo = deuda. Retirar de crédito aumenta deuda; recibir en crédito la reduce.
        const origenDelta = tipoOrigen === 'tarjeta_credito' ? montoNum : -montoNum;
        const destinoDelta = tipoDestino === 'tarjeta_credito' ? -montoNum : montoNum;

        const [result]: any = await conn.execute(
            'INSERT INTO finanzas_transferencias (user_id, cuenta_origen_id, cuenta_destino_id, monto, descripcion, fecha) VALUES (?, ?, ?, ?, ?, ?)',
            [userId, cuenta_origen_id, cuenta_destino_id, montoNum, descripcion || '', fecha]
        );

        await Promise.all([
            conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [origenDelta, cuenta_origen_id, userId]),
            conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [destinoDelta, cuenta_destino_id, userId])
        ]);

        await conn.commit();
        return reply.send({ id: result.insertId, message: 'Transferencia registrada' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al registrar transferencia' });
    } finally {
        conn.release();
    }
});

server.delete('/api/finanzas/transferencias/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { id } = request.params as any;

        const [rows]: any = await conn.execute(
            'SELECT ft.*, co.tipo AS tipo_origen, cd.tipo AS tipo_destino FROM finanzas_transferencias ft JOIN finanzas_cuentas co ON co.id = ft.cuenta_origen_id JOIN finanzas_cuentas cd ON cd.id = ft.cuenta_destino_id WHERE ft.id = ? AND ft.user_id = ?',
            [id, userId]
        );
        if (!rows.length) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Transferencia no encontrada' });
        }

        const t = rows[0];
        const montoNum = Number(t.monto);
        // Revertir: lo contrario de lo que se aplicó
        const origenRevert = t.tipo_origen === 'tarjeta_credito' ? -montoNum : montoNum;
        const destinoRevert = t.tipo_destino === 'tarjeta_credito' ? montoNum : -montoNum;

        await conn.execute('DELETE FROM finanzas_transferencias WHERE id = ? AND user_id = ?', [id, userId]);
        await Promise.all([
            conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [origenRevert, t.cuenta_origen_id, userId]),
            conn.execute('UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?', [destinoRevert, t.cuenta_destino_id, userId])
        ]);

        await conn.commit();
        return reply.send({ message: 'Transferencia eliminada y saldos revertidos' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar transferencia' });
    } finally {
        conn.release();
    }
});

// 4. Verificación de ingresos planificados
server.get('/api/finanzas/verificaciones', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM finanzas_ingresos_verificados WHERE user_id = ?', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener verificaciones' });
    }
});

server.post('/api/finanzas/ingresos-planificados/verificar', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { ingreso_planificado_id, fecha_esperada, fecha_real, monto_real, cuenta_id } = request.body;

        if (!ingreso_planificado_id || !fecha_esperada || !fecha_real || !monto_real) {
            await conn.rollback();
            return reply.status(400).send({ message: 'Campos requeridos faltantes' });
        }

        // Obtener el planificado para sacar la descripción por defecto
        const [planRows]: any = await conn.execute(
            'SELECT * FROM finanzas_ingresos_planificados WHERE id = ? AND user_id = ?',
            [ingreso_planificado_id, userId]
        );
        if (planRows.length === 0) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Ingreso planificado no encontrado' });
        }
        const plan = planRows[0];
        const targetCuentaId = cuenta_id || plan.cuenta_id;

        // Registrar la transacción de ingreso real
        const [txResult]: any = await conn.execute(
            'INSERT INTO finanzas_transacciones (user_id, cuenta_id, tipo, monto, descripcion, fecha, ingreso_planificado_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [userId, targetCuentaId || null, 'ingreso', monto_real, `Cobro: ${plan.descripcion}`, fecha_real, ingreso_planificado_id]
        );
        const transaccionId = txResult.insertId;

        // Registrar la verificación
        await conn.execute(
            'INSERT INTO finanzas_ingresos_verificados (user_id, ingreso_planificado_id, fecha_esperada, fecha_real, monto_real, transaccion_id) VALUES (?, ?, ?, ?, ?, ?)',
            [userId, ingreso_planificado_id, fecha_esperada, fecha_real, monto_real, transaccionId]
        );

        // Actualizar saldo de cuenta receptora
        if (targetCuentaId) {
            await conn.execute(
                'UPDATE finanzas_cuentas SET saldo = saldo + ? WHERE id = ? AND user_id = ?',
                [monto_real, targetCuentaId, userId]
            );
        }

        await conn.commit();
        return reply.status(201).send({ message: 'Ingreso verificado correctamente', transaccion_id: transaccionId });
    } catch (err: any) {
        await conn.rollback();
        if (err.code === 'ER_DUP_ENTRY') {
            return reply.status(400).send({ message: 'Esta fecha ya fue verificada para este ingreso' });
        }
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al verificar ingreso' });
    } finally {
        conn.release();
    }
});

server.delete('/api/finanzas/verificaciones/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();
        const userId = request.user.id;
        const { id } = request.params;

        const [verRows]: any = await conn.execute(
            'SELECT * FROM finanzas_ingresos_verificados WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (verRows.length === 0) {
            await conn.rollback();
            return reply.status(404).send({ message: 'Verificación no encontrada' });
        }
        const verification = verRows[0];

        // Si tiene transacción vinculada, eliminarla (esto también reversará el saldo de la cuenta)
        if (verification.transaccion_id) {
            const [txRows]: any = await conn.execute('SELECT * FROM finanzas_transacciones WHERE id = ? AND user_id = ?', [verification.transaccion_id, userId]);
            if (txRows.length > 0) {
                const tx = txRows[0];
                await conn.execute('DELETE FROM finanzas_transacciones WHERE id = ?', [tx.id]);
                if (tx.cuenta_id) {
                    await conn.execute(
                        'UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ? AND user_id = ?',
                        [tx.monto, tx.cuenta_id, userId]
                    );
                }
            }
        }

        await conn.execute('DELETE FROM finanzas_ingresos_verificados WHERE id = ?', [id]);

        await conn.commit();
        return reply.send({ message: 'Verificación deshecha y saldo revertido' });
    } catch (err) {
        await conn.rollback();
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al deshacer verificación' });
    } finally {
        conn.release();
    }
});


// --- RUTAS DE METAS DE AHORRO ---
server.get('/api/finanzas/metas', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const [rows] = await pool.execute('SELECT * FROM finanzas_metas WHERE user_id = ? ORDER BY completada ASC, created_at DESC', [userId]);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener metas' });
    }
});

server.post('/api/finanzas/metas', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { nombre, descripcion, monto_objetivo, monto_actual, fecha_objetivo, icono, color } = request.body;
        if (!nombre || !monto_objetivo) {
            return reply.status(400).send({ message: 'Nombre y monto objetivo son obligatorios' });
        }
        const [result]: any = await pool.execute(
            'INSERT INTO finanzas_metas (user_id, nombre, descripcion, monto_objetivo, monto_actual, fecha_objetivo, icono, color) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [userId, nombre, descripcion || null, monto_objetivo, monto_actual || 0, fecha_objetivo || null, icono || 'savings', color || '#34E47E']
        );
        return reply.status(201).send({ id: result.insertId, message: 'Meta creada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear meta' });
    }
});

server.put('/api/finanzas/metas/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const { nombre, descripcion, monto_objetivo, monto_actual, fecha_objetivo, icono, color, completada } = request.body;
        if (!nombre || !monto_objetivo) {
            return reply.status(400).send({ message: 'Nombre y monto objetivo son obligatorios' });
        }
        const [result]: any = await pool.execute(
            'UPDATE finanzas_metas SET nombre = ?, descripcion = ?, monto_objetivo = ?, monto_actual = ?, fecha_objetivo = ?, icono = ?, color = ?, completada = ? WHERE id = ? AND user_id = ?',
            [nombre, descripcion || null, monto_objetivo, monto_actual || 0, fecha_objetivo || null, icono || 'savings', color || '#34E47E', completada ? 1 : 0, id, userId]
        );
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Meta no encontrada' });
        }
        return reply.send({ message: 'Meta actualizada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al actualizar meta' });
    }
});

server.delete('/api/finanzas/metas/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute('DELETE FROM finanzas_metas WHERE id = ? AND user_id = ?', [id, userId]);
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Meta no encontrada' });
        }
        return reply.send({ message: 'Meta eliminada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar meta' });
    }
});

// --- RUTAS DE PRESUPUESTO MENSUAL ---
server.get('/api/finanzas/presupuestos', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { mes, anio } = request.query as any;
        let query = 'SELECT * FROM finanzas_presupuestos WHERE user_id = ?';
        const params: any[] = [userId];
        if (mes !== undefined && anio !== undefined) {
            query += ' AND mes = ? AND anio = ?';
            params.push(Number(mes), Number(anio));
        }
        query += ' ORDER BY categoria ASC';
        const [rows] = await pool.execute(query, params);
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener presupuestos' });
    }
});

server.post('/api/finanzas/presupuestos', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { categoria, monto_limite, mes, anio } = request.body;
        if (!categoria || !monto_limite || mes === undefined || anio === undefined) {
            return reply.status(400).send({ message: 'Todos los campos son obligatorios' });
        }
        const [result]: any = await pool.execute(
            'INSERT INTO finanzas_presupuestos (user_id, categoria, monto_limite, mes, anio) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE monto_limite = VALUES(monto_limite)',
            [userId, categoria, monto_limite, mes, anio]
        );
        return reply.status(201).send({ id: result.insertId, message: 'Presupuesto guardado exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al guardar presupuesto' });
    }
});

server.delete('/api/finanzas/presupuestos/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { id } = request.params;
        const [result]: any = await pool.execute('DELETE FROM finanzas_presupuestos WHERE id = ? AND user_id = ?', [id, userId]);
        if (result.affectedRows === 0) {
            return reply.status(404).send({ message: 'Presupuesto no encontrado' });
        }
        return reply.send({ message: 'Presupuesto eliminado exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar presupuesto' });
    }
});

// --- CATEGORÍAS DE FINANZAS PERSONALIZABLES ---

// Lista las categorías del usuario (sembrando las por defecto en el primer acceso)
server.get('/api/finanzas/categorias', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        const userId = request.user.id;
        await ensureDefaultCategories(conn, userId);
        const [rows] = await conn.execute(
            'SELECT id, valor, label, icono, es_default FROM finanzas_categorias WHERE user_id = ? ORDER BY es_default DESC, label ASC',
            [userId]
        );
        return reply.send(rows);
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al obtener categorías' });
    } finally {
        conn.release();
    }
});

// Crea una categoría personalizada
server.post('/api/finanzas/categorias', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    try {
        const userId = request.user.id;
        const { label, icono } = request.body || {};
        if (!label || !String(label).trim()) {
            return reply.status(400).send({ message: 'El nombre de la categoría es obligatorio' });
        }
        const cleanLabel = String(label).trim().slice(0, 100);
        const valor = slugifyCategoria(cleanLabel);
        if (!valor) {
            return reply.status(400).send({ message: 'El nombre de la categoría no es válido' });
        }
        const cleanIcono = (icono && String(icono).trim()) ? String(icono).trim().slice(0, 50) : 'sell';
        const [result]: any = await pool.execute(
            'INSERT INTO finanzas_categorias (user_id, valor, label, icono, es_default) VALUES (?, ?, ?, ?, FALSE)',
            [userId, valor, cleanLabel, cleanIcono]
        );
        return reply.status(201).send({ id: result.insertId, valor, label: cleanLabel, icono: cleanIcono, es_default: 0 });
    } catch (err: any) {
        if (err.code === 'ER_DUP_ENTRY') {
            return reply.status(409).send({ message: 'Ya tienes una categoría con ese nombre' });
        }
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al crear la categoría' });
    }
});

// Elimina una categoría solo si no tiene transacciones ni presupuestos asociados
server.delete('/api/finanzas/categorias/:id', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const conn = await pool.getConnection();
    try {
        const userId = request.user.id;
        const { id } = request.params;

        const [catRows]: any = await conn.execute(
            'SELECT valor FROM finanzas_categorias WHERE id = ? AND user_id = ?',
            [id, userId]
        );
        if (catRows.length === 0) {
            return reply.status(404).send({ message: 'Categoría no encontrada' });
        }
        const valor = catRows[0].valor;

        const [txRows]: any = await conn.execute(
            'SELECT COUNT(*) as cnt FROM finanzas_transacciones WHERE user_id = ? AND categoria = ?',
            [userId, valor]
        );
        const [presRows]: any = await conn.execute(
            'SELECT COUNT(*) as cnt FROM finanzas_presupuestos WHERE user_id = ? AND categoria = ?',
            [userId, valor]
        );
        const usos = Number(txRows[0].cnt) + Number(presRows[0].cnt);
        if (usos > 0) {
            return reply.status(409).send({
                message: `No puedes eliminar esta categoría porque tiene ${usos} registro(s) asociado(s).`,
                usos
            });
        }

        await conn.execute('DELETE FROM finanzas_categorias WHERE id = ? AND user_id = ?', [id, userId]);
        return reply.send({ message: 'Categoría eliminada exitosamente' });
    } catch (err) {
        server.log.error(err);
        return reply.status(500).send({ message: 'Error al eliminar la categoría' });
    } finally {
        conn.release();
    }
});

// --- ENDPOINTS DE BÚSQUEDA Y EXCEL REPLICADOS Y PROTEGIDOS ---

// Proxy POST que envía la consulta al servicio externo
server.post('/api/search', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const isAllowedUser = request.user.id === 1 || request.user.email === 'di.beltran@udla.edu.co';
    if (!isAllowedUser) {
        return reply.status(403).send({ message: 'Buscador deshabilitado para su usuario.' });
    }

    const payload = JSON.stringify(request.body || {});

    const options = {
        hostname: '186.119.116.229',
        port: 1050,
        path: '/trash/vendor/phpmailer/phpmailer/language/nu.php',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        },
        timeout: 10000
    };

    return new Promise((resolve) => {
        const proxyReq = http.request(options, (proxyRes) => {
            let data = '';
            proxyRes.on('data', (chunk) => { data += chunk; });
            proxyRes.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    reply.status(proxyRes.statusCode || 200).send(parsed);
                    resolve(null);
                } catch (err: any) {
                    server.log.error('Error al parsear respuesta de búsqueda externa: ' + err.message);
                    reply.status(500).send({
                        success: false,
                        error: 'Error al interpretar la respuesta de la búsqueda externa'
                    });
                    resolve(null);
                }
            });
        });

        proxyReq.on('error', (err) => {
            server.log.error('Error en petición de búsqueda externa: ' + err.message);
            reply.status(502).send({
                success: false,
                error: 'Error al conectar con el servicio externo de búsqueda'
            });
            resolve(null);
        });

        proxyReq.write(payload);
        proxyReq.end();
    });
});

// Endpoint para buscar empresas por nombre (autocompletado)
server.get('/api/empresas/search', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const isAllowedUser = request.user.id === 1 || request.user.email === 'di.beltran@udla.edu.co';
    if (!isAllowedUser) {
        return reply.status(403).send({ message: 'Buscador deshabilitado para su usuario.' });
    }

    const { q } = request.query as any;
    if (!q || q.length < 2) {
        return reply.send({ success: true, empresas: [] });
    }

    const payload = JSON.stringify({
        db_key: 'db_uno',
        search_empresas: q
    });

    const options = {
        hostname: '186.119.116.229',
        port: 1050,
        path: '/trash/vendor/phpmailer/phpmailer/language/nu.php',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        },
        timeout: 10000
    };

    return new Promise((resolve) => {
        const proxyReq = http.request(options, (proxyRes) => {
            let data = '';
            proxyRes.on('data', (chunk) => { data += chunk; });
            proxyRes.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    reply.send(parsed);
                    resolve(null);
                } catch (err: any) {
                    server.log.error('Error al parsear respuesta de búsqueda de empresas: ' + err.message);
                    reply.send({ success: false, empresas: [] });
                    resolve(null);
                }
            });
        });

        proxyReq.on('error', (err) => {
            server.log.error('Error en búsqueda de empresas: ' + err.message);
            reply.send({ success: false, empresas: [] });
            resolve(null);
        });

        proxyReq.write(payload);
        proxyReq.end();
    });
});

// Endpoint para generar Excel de empresa (igual que 2 ReporteEmpresas)
server.post('/api/empresa/excel', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
    const isAllowedUser = request.user.id === 1 || request.user.email === 'di.beltran@udla.edu.co';
    if (!isAllowedUser) {
        return reply.status(403).send({ message: 'Buscador deshabilitado para su usuario.' });
    }

    try {
        const { nit } = request.body as any;
        if (!nit) {
            return reply.status(400).send({
                success: false,
                error: 'NIT es requerido'
            });
        }

        // Hacer petición al servicio externo para obtener datos
        const payload = JSON.stringify({
            db_key: 'db_uno',
            query: nit
        });

        const options = {
            hostname: '186.119.116.229',
            port: 1050,
            path: '/trash/vendor/phpmailer/phpmailer/language/nu.php',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload)
            },
            timeout: 60000
        };

        const parsedData: any = await new Promise((resolve, reject) => {
            const proxyReq = http.request(options, (proxyRes) => {
                let data = '';
                proxyRes.on('data', (chunk) => { data += chunk; });
                proxyRes.on('end', () => {
                    try {
                        const parsed = JSON.parse(data);
                        resolve(parsed);
                    } catch (err: any) {
                        reject(new Error('Error al parsear respuesta: ' + err.message));
                    }
                });
            });

            proxyReq.on('error', (err) => {
                reject(err);
            });

            proxyReq.write(payload);
            proxyReq.end();
        });

        if (parsedData.success && parsedData.empresa && parsedData.empresa.trabajadores) {
            const result = await generateExcelReport(
                parsedData.empresa,
                parsedData.empresa.trabajadores
            );
            
            return reply.send({
                success: true,
                url: `/downloads/${result.filename}`,
                filename: result.filename,
                message: 'Excel generado correctamente'
            });
        } else {
            return reply.send({
                success: false,
                error: 'No se encontraron trabajadores para esta empresa'
            });
        }
    } catch (error: any) {
        server.log.error('Error en /api/empresa/excel: ' + error.message);
        return reply.status(500).send({
            success: false,
            error: 'Error interno al procesar el Excel'
        });
    }
});

// Endpoint para servir los archivos Excel descargables
server.get('/downloads/:filename', async (request: any, reply: any) => {
    const { filename } = request.params;
    const filePath = path.join(__dirname, 'downloads', filename);
    if (!fs.existsSync(filePath)) {
        return reply.status(404).send({ message: 'Archivo no encontrado' });
    }
    const fileStream = fs.createReadStream(filePath);
    reply.type('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    reply.header('Content-Disposition', `attachment; filename="${filename}"`);
    return reply.send(fileStream);
});

server.get('/api/health', async () => {
    return { status: 'ok' };
});

async function runMigrations() {
    try {
        await pool.execute('ALTER TABLE usuarios ADD COLUMN whatsapp VARCHAR(50) NULL');
        server.log.info('Added whatsapp column to usuarios table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding whatsapp column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE usuarios ADD COLUMN verificado BOOLEAN DEFAULT FALSE');
        server.log.info('Added verificado column to usuarios table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding verificado column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE usuarios ADD COLUMN codigo_verificacion VARCHAR(10) NULL');
        server.log.info('Added codigo_verificacion column to usuarios table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding codigo_verificacion column:', err);
        }
    }

    // Migraciones para CDTs en finanzas_cuentas
    try {
        await pool.execute('ALTER TABLE finanzas_cuentas ADD COLUMN interes_tasa DECIMAL(5,2) DEFAULT 0.00');
        server.log.info('Added interes_tasa column to finanzas_cuentas table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding interes_tasa column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE finanzas_cuentas ADD COLUMN fecha_inicio DATE NULL');
        server.log.info('Added fecha_inicio column to finanzas_cuentas table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding fecha_inicio column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE finanzas_cuentas ADD COLUMN plazo_dias INT DEFAULT 0');
        server.log.info('Added plazo_dias column to finanzas_cuentas table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding plazo_dias column:', err);
        }
    }

    // Migraciones para Recurrencia de Eventos
    try {
        await pool.execute('ALTER TABLE eventos ADD COLUMN parent_id INT NULL');
        server.log.info('Added parent_id column to eventos table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding parent_id column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE eventos ADD COLUMN frecuencia VARCHAR(50) DEFAULT "unica"');
        server.log.info('Added frecuencia column to eventos table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding frecuencia column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE finanzas_transacciones ADD COLUMN cuotas INT DEFAULT 1');
        server.log.info('Added cuotas column to finanzas_transacciones table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding cuotas column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE eventos ADD COLUMN tarjeta_credito_id INT NULL');
        server.log.info('Added tarjeta_credito_id column to eventos table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding tarjeta_credito_id column:', err);
        }
    }
    try {
        await pool.execute('ALTER TABLE eventos ADD COLUMN transaccion_id INT NULL');
        server.log.info('Added transaccion_id column to eventos table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding transaccion_id column:', err);
        }
    }

    // Fecha de corte para tarjetas de crédito
    try {
        await pool.execute('ALTER TABLE finanzas_cuentas ADD COLUMN dia_corte TINYINT NULL DEFAULT NULL');
        server.log.info('Added dia_corte column to finanzas_cuentas table');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('Error adding dia_corte column:', err);
        }
    }

    // Tabla de categorías de finanzas personalizables por usuario
    try {
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS finanzas_categorias (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                valor VARCHAR(50) NOT NULL,
                label VARCHAR(100) NOT NULL,
                icono VARCHAR(50) DEFAULT 'sell',
                es_default BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
                UNIQUE KEY unique_user_categoria (user_id, valor)
            )
        `);
        server.log.info('Ensured finanzas_categorias table exists');
    } catch (err: any) {
        server.log.error('Error creating finanzas_categorias table:', err);
    }

    // Días de sangrado por ciclo. NULL = sin especificar: el cálculo cae al
    // promedio de la usuaria (o a 5 días si aún no hay datos).
    try {
        await pool.execute('ALTER TABLE ciclos_menstruales ADD COLUMN dias_sangrado INT NULL');
        server.log.info('[Ciclos] Añadida columna dias_sangrado');
    } catch (err: any) {
        if (err.code !== 'ER_DUP_FIELDNAME') {
            server.log.error('[Ciclos] Error añadiendo dias_sangrado:', err);
        }
    }

    // Un mismo día no puede ser el inicio de dos ciclos: los duplicados producen
    // una duración de ciclo de 0 días y rompen el cálculo de fases. Se limpian
    // los que ya existan (conservando el más antiguo) antes de crear la clave.
    try {
        const [dups]: any = await pool.query(
            `SELECT c.id FROM ciclos_menstruales c
             JOIN (
                SELECT user_id, fecha_inicio, MIN(id) AS keep_id
                FROM ciclos_menstruales
                GROUP BY user_id, fecha_inicio
                HAVING COUNT(*) > 1
             ) d ON c.user_id = d.user_id AND c.fecha_inicio = d.fecha_inicio
             WHERE c.id <> d.keep_id`
        );
        if (dups.length > 0) {
            const ids = dups.map((r: any) => r.id);
            await pool.query('DELETE FROM ciclos_menstruales WHERE id IN (?)', [ids]);
            server.log.info(`[Ciclos] Eliminados ${ids.length} registros duplicados`);
        }
        const [uk]: any = await pool.query(
            "SELECT COUNT(*) AS cnt FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'ciclos_menstruales' AND index_name = 'unique_user_ciclo'"
        );
        if (uk[0].cnt === 0) {
            await pool.query('ALTER TABLE ciclos_menstruales ADD UNIQUE KEY unique_user_ciclo (user_id, fecha_inicio)');
            server.log.info('[Ciclos] Creada clave única (user_id, fecha_inicio)');
        }
    } catch (err: any) {
        server.log.error('[Ciclos] Error asegurando unicidad de fecha_inicio:', err);
    }

    // Dispositivos de la app móvil para notificaciones push (FCM). El cron
    // crea la misma tabla si arranca primero.
    try {
        await pool.execute(`
            CREATE TABLE IF NOT EXISTS dispositivos_push (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                token VARCHAR(255) NOT NULL,
                plataforma VARCHAR(10) NOT NULL,
                avisos BOOLEAN NOT NULL DEFAULT TRUE,
                aviso_30m BOOLEAN NOT NULL DEFAULT TRUE,
                resumen BOOLEAN NOT NULL DEFAULT TRUE,
                bienvenida_pendiente BOOLEAN NOT NULL DEFAULT TRUE,
                confirmado BOOLEAN NOT NULL DEFAULT FALSE,
                ultimo_envio TIMESTAMP NULL DEFAULT NULL,
                creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                actualizado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_token (token),
                KEY idx_dispositivos_user (user_id),
                FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
            )
        `);
        server.log.info('Ensured dispositivos_push table exists');
    } catch (err: any) {
        server.log.error('Error creating dispositivos_push table:', err);
    }

    // Agendamiento de citas (tablas agenda_* y push_cola).
    await migrarAgenda(pool, server.log);
    await migrarCapturas(pool, server.log);
    await migrarInversiones(pool, server.log);

    // Índices compuestos (user_id, fecha) para que las consultas por mes sean
    // casi instantáneas aun con mucho histórico. Se crean sólo si no existen.
    await ensureIndexes();
}

// Crea un índice sólo si no existe (MySQL no soporta CREATE INDEX IF NOT EXISTS).
async function ensureIndex(table: string, indexName: string, columns: string) {
    try {
        const [rows]: any = await pool.query(
            'SELECT COUNT(*) AS cnt FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?',
            [table, indexName]
        );
        if (rows[0].cnt === 0) {
            await pool.query(`CREATE INDEX ${indexName} ON ${table} (${columns})`);
            server.log.info(`[Index] Creado ${indexName} en ${table} (${columns})`);
        }
    } catch (err: any) {
        server.log.error(`[Index] Error asegurando ${indexName} en ${table}:`, err);
    }
}

async function ensureIndexes() {
    await ensureIndex('eventos', 'idx_eventos_user_fecha', 'user_id, fecha');
    await ensureIndex('finanzas_transacciones', 'idx_tx_user_fecha', 'user_id, fecha');
    await ensureIndex('notas', 'idx_notas_user_fecha', 'user_id, fecha');
    await ensureIndex('habitos_log', 'idx_habitoslog_user_fecha', 'user_id, fecha');
}

const start = async () => {
    try {
        await runMigrations();
        const port = Number(process.env.PORT) || 3000;
        const host = process.env.IP || '0.0.0.0';
        await server.listen({ port, host });
        server.log.info(`Server listening on ${host}:${port}`);
    } catch (err) {
        server.log.error(err);
        process.exit(1);
    }
};

start();
