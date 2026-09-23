// Agendamiento de citas: cada usuario publica un enlace (agendaservi.com/agenda/<slug>)
// donde cualquier persona, sin cuenta, reserva un servicio con un profesional.
//
// Modelo
//   agenda_negocios            1 por usuario: profesional independiente o empresa
//   agenda_profesionales       equipo (el dueño, empleados con cuenta o solo con WhatsApp)
//   agenda_servicios           nombre, duración y precio; qué profesionales lo prestan
//   agenda_horarios            rangos semanales por profesional (jornada partida)
//   agenda_bloqueos            días u horas no disponibles (vacaciones, diligencias)
//   agenda_citas               reservas; pendiente → (código por WhatsApp) → confirmada
//   push_cola                  notificaciones a la app que envía el cron (con respaldo por WhatsApp)
//
// Reglas
//   · Toda cita se confirma con un código de 6 dígitos que llega por WhatsApp
//     (o tocando el enlace del mensaje). Una reserva pendiente aparta el turno
//     15 minutos; si no se confirma, se libera.
//   · Nunca hay dos citas del mismo profesional a la misma hora: la reserva
//     bloquea la fila del profesional (SELECT … FOR UPDATE) y recalcula la
//     disponibilidad dentro de la transacción.
//   · Una cita confirmada crea un evento en el calendario del profesional que
//     tiene cuenta, así el cron le envía los recordatorios de siempre.

import crypto from 'crypto';
import type { FastifyInstance } from 'fastify';
import type { Pool, PoolConnection } from 'mysql2/promise';
import {
    aHora,
    aMinutos,
    ahoraBogota,
    disponibilidad,
    esFecha,
    esHora,
    slugDe,
    slugValido,
    sumarDias,
    validarHorarios,
    type AgendaProfesional,
    type DiaDisponible,
    type HorarioDia,
    type Rango
} from './disponibilidad';
import * as M from './mensajes';

export interface DepsAgenda {
    pool: Pool;
    enviarWhatsApp: (numero: string, texto: string) => Promise<boolean>;
    /** Sitio web público, p. ej. https://agendaservi.com */
    webBase: string;
}

export const MINUTOS_CODIGO = 15;
const MAX_INTENTOS = 5;
const DURACION_EVENTO_PERSONAL = 60;
const CATEGORIAS_SIN_BLOQUEO = new Set(['arriendo', 'aceite_moto', 'servicios', 'aniversario', 'mesiversario']);
const RUBROS = new Set(['psicologia', 'salud', 'odontologia', 'peluqueria', 'barberia', 'estetica', 'spa', 'unas', 'fitness', 'consultoria', 'educacion', 'mascotas', 'otro']);
const PASOS = new Set([5, 10, 15, 20, 30, 45, 60]);
const COLOR = /^#[0-9A-Fa-f]{6}$/;

// ---------------------------------------------------------------------------
//  Esquema
// ---------------------------------------------------------------------------

const DDL = [
    `CREATE TABLE IF NOT EXISTS agenda_negocios (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        slug VARCHAR(60) NOT NULL,
        tipo VARCHAR(20) NOT NULL DEFAULT 'profesional',
        nombre VARCHAR(120) NOT NULL,
        rubro VARCHAR(40) NOT NULL DEFAULT 'otro',
        descripcion VARCHAR(500) NULL,
        direccion VARCHAR(200) NULL,
        whatsapp VARCHAR(20) NULL,
        color VARCHAR(7) NOT NULL DEFAULT '#2563EB',
        anticipacion_min INT NOT NULL DEFAULT 60,
        ventana_dias INT NOT NULL DEFAULT 30,
        intervalo_min INT NOT NULL DEFAULT 15,
        usar_calendario TINYINT(1) NOT NULL DEFAULT 1,
        activo TINYINT(1) NOT NULL DEFAULT 1,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        actualizado TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uq_agenda_slug (slug),
        UNIQUE KEY uq_agenda_user (user_id),
        FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_profesionales (
        id INT AUTO_INCREMENT PRIMARY KEY,
        negocio_id INT NOT NULL,
        usuario_id INT NULL,
        nombre VARCHAR(100) NOT NULL,
        cargo VARCHAR(80) NULL,
        whatsapp VARCHAR(20) NULL,
        color VARCHAR(7) NOT NULL DEFAULT '#2563EB',
        activo TINYINT(1) NOT NULL DEFAULT 1,
        orden INT NOT NULL DEFAULT 0,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_agprof_negocio (negocio_id),
        KEY idx_agprof_usuario (usuario_id),
        FOREIGN KEY (negocio_id) REFERENCES agenda_negocios(id) ON DELETE CASCADE,
        FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE SET NULL
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_servicios (
        id INT AUTO_INCREMENT PRIMARY KEY,
        negocio_id INT NOT NULL,
        nombre VARCHAR(100) NOT NULL,
        descripcion VARCHAR(300) NULL,
        duracion_min INT NOT NULL DEFAULT 30,
        precio DECIMAL(12,2) NOT NULL DEFAULT 0,
        color VARCHAR(7) NOT NULL DEFAULT '#2563EB',
        activo TINYINT(1) NOT NULL DEFAULT 1,
        orden INT NOT NULL DEFAULT 0,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_agserv_negocio (negocio_id),
        FOREIGN KEY (negocio_id) REFERENCES agenda_negocios(id) ON DELETE CASCADE
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_servicio_profesional (
        servicio_id INT NOT NULL,
        profesional_id INT NOT NULL,
        PRIMARY KEY (servicio_id, profesional_id),
        FOREIGN KEY (servicio_id) REFERENCES agenda_servicios(id) ON DELETE CASCADE,
        FOREIGN KEY (profesional_id) REFERENCES agenda_profesionales(id) ON DELETE CASCADE
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_horarios (
        id INT AUTO_INCREMENT PRIMARY KEY,
        profesional_id INT NOT NULL,
        dia TINYINT NOT NULL,
        inicio TIME NOT NULL,
        fin TIME NOT NULL,
        KEY idx_aghor_prof (profesional_id),
        FOREIGN KEY (profesional_id) REFERENCES agenda_profesionales(id) ON DELETE CASCADE
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_bloqueos (
        id INT AUTO_INCREMENT PRIMARY KEY,
        profesional_id INT NOT NULL,
        fecha DATE NOT NULL,
        inicio TIME NULL,
        fin TIME NULL,
        motivo VARCHAR(120) NULL,
        KEY idx_agbloq (profesional_id, fecha),
        FOREIGN KEY (profesional_id) REFERENCES agenda_profesionales(id) ON DELETE CASCADE
    )`,
    `CREATE TABLE IF NOT EXISTS agenda_citas (
        id INT AUTO_INCREMENT PRIMARY KEY,
        negocio_id INT NOT NULL,
        profesional_id INT NOT NULL,
        servicio_id INT NULL,
        servicio_nombre VARCHAR(100) NOT NULL,
        duracion_min INT NOT NULL,
        precio DECIMAL(12,2) NOT NULL DEFAULT 0,
        fecha DATE NOT NULL,
        hora_inicio TIME NOT NULL,
        hora_fin TIME NOT NULL,
        cliente_nombre VARCHAR(100) NOT NULL,
        cliente_whatsapp VARCHAR(20) NULL,
        cliente_usuario_id INT NULL,
        nota VARCHAR(300) NULL,
        estado VARCHAR(15) NOT NULL DEFAULT 'pendiente',
        codigo CHAR(6) NULL,
        intentos TINYINT NOT NULL DEFAULT 0,
        token CHAR(32) NOT NULL,
        origen VARCHAR(10) NOT NULL DEFAULT 'web',
        evento_id INT NULL,
        motivo_cancelacion VARCHAR(200) NULL,
        cancelada_por VARCHAR(10) NULL,
        codigo_enviado TIMESTAMP NULL DEFAULT NULL,
        confirmada_en TIMESTAMP NULL DEFAULT NULL,
        cancelada_en TIMESTAMP NULL DEFAULT NULL,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uq_agcita_token (token),
        KEY idx_agcita_prof_fecha (profesional_id, fecha),
        KEY idx_agcita_negocio_fecha (negocio_id, fecha),
        KEY idx_agcita_cliente (cliente_usuario_id),
        KEY idx_agcita_estado (estado),
        FOREIGN KEY (negocio_id) REFERENCES agenda_negocios(id) ON DELETE CASCADE,
        FOREIGN KEY (profesional_id) REFERENCES agenda_profesionales(id) ON DELETE CASCADE,
        FOREIGN KEY (servicio_id) REFERENCES agenda_servicios(id) ON DELETE SET NULL
    )`,
    `CREATE TABLE IF NOT EXISTS push_cola (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        clave VARCHAR(80) NOT NULL,
        titulo VARCHAR(200) NOT NULL,
        cuerpo VARCHAR(1000) NOT NULL,
        canal VARCHAR(20) NOT NULL DEFAULT 'eventos',
        ruta VARCHAR(60) NOT NULL DEFAULT '',
        whatsapp_respaldo TEXT NULL,
        procesado TINYINT(1) NOT NULL DEFAULT 0,
        intentos TINYINT NOT NULL DEFAULT 0,
        creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY idx_pushcola_pend (procesado, creado),
        FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
    )`
];

export async function migrarAgenda(pool: Pool, log: { info: (m: string) => void; error: (e: unknown, m?: string) => void }) {
    for (const sql of DDL) {
        try {
            await pool.query(sql);
        } catch (err) {
            log.error(err, '[Agenda] Error creando tabla');
        }
    }
    // Enlace del evento del calendario con la cita que lo originó.
    try {
        await pool.query('ALTER TABLE eventos ADD COLUMN cita_id INT NULL');
        log.info('[Agenda] Añadida columna eventos.cita_id');
    } catch (err: any) {
        if (err?.code !== 'ER_DUP_FIELDNAME') log.error(err, '[Agenda] Error añadiendo eventos.cita_id');
    }
    log.info('[Agenda] Tablas de agendamiento listas');
}

// ---------------------------------------------------------------------------
//  Utilidades
// ---------------------------------------------------------------------------

class Falla extends Error {
    constructor(public status: number, message: string, public extra: Record<string, unknown> = {}) {
        super(message);
    }
}

const soloDigitos = (v: unknown) => String(v ?? '').replace(/\D/g, '');
const texto = (v: unknown, max: number) => String(v ?? '').trim().slice(0, max);
const bool = (v: unknown, def: boolean) => (v === undefined || v === null ? def : v === true || v === 1 || v === '1' || v === 'true');

/** Limitador en memoria por clave (IP, número…): máximo `max` en `ventanaMs`. */
const golpes = new Map<string, number[]>();
function permitido(clave: string, max: number, ventanaMs: number): boolean {
    const ahora = Date.now();
    const l = (golpes.get(clave) ?? []).filter((t) => ahora - t < ventanaMs);
    if (l.length >= max) {
        golpes.set(clave, l);
        return false;
    }
    l.push(ahora);
    golpes.set(clave, l);
    if (golpes.size > 5000) for (const [k, v] of golpes) if (!v.some((t) => ahora - t < ventanaMs)) golpes.delete(k);
    return true;
}

function iniciales(nombre: string): string {
    return String(nombre).trim().split(/\s+/).slice(0, 2).map((p) => p[0]?.toUpperCase() ?? '').join('');
}

/** Fecha/minuto desde el que se puede reservar (ahora + anticipación). */
function limiteReserva(anticipacionMin: number, ahora = new Date()) {
    const { fecha, minuto } = ahoraBogota(ahora);
    const total = minuto + Math.max(0, anticipacionMin);
    return { fecha: sumarDias(fecha, Math.floor(total / 1440)), minuto: total % 1440, hoy: fecha };
}

const SQL_CITA_VIGENTE = `(c.estado = 'confirmada' OR (c.estado = 'pendiente' AND c.creado > NOW() - INTERVAL ${MINUTOS_CODIGO} MINUTE))`;

// ---------------------------------------------------------------------------
//  Registro de rutas
// ---------------------------------------------------------------------------

export function registrarAgenda(server: FastifyInstance, deps: DepsAgenda) {
    const { pool, enviarWhatsApp, webBase } = deps;
    const auth = { preValidation: [(server as any).authenticate] };
    const enlaceCita = (token: string) => `${webBase}/cita/${token}`;
    const paginaNegocio = (slug: string) => `${webBase}/agenda/${slug}`;

    /** Envuelve un manejador: errores `Falla` → respuesta; el resto → 500. */
    const manejar =
        (fn: (req: any, reply: any) => Promise<unknown>) =>
        async (req: any, reply: any) => {
            try {
                return await fn(req, reply);
            } catch (err: any) {
                if (err instanceof Falla) return reply.status(err.status).send({ message: err.message, ...err.extra });
                server.log.error(err);
                return reply.status(500).send({ message: 'Error interno del servidor' });
            }
        };

    async function conConexion<T>(fn: (c: PoolConnection) => Promise<T>): Promise<T> {
        const c = await pool.getConnection();
        try {
            return await fn(c);
        } finally {
            c.release();
        }
    }

    /**
     * Transacción. Las que reservan turnos usan READ COMMITTED: tras bloquear al
     * profesional (FOR UPDATE) deben ver las citas que otra reserva acaba de
     * confirmar; con REPEATABLE READ leerían una foto anterior al bloqueo y dos
     * clientes simultáneos podrían quedarse con el mismo turno.
     */
    async function transaccion<T>(fn: (c: PoolConnection) => Promise<T>, opts: { leidoConfirmado?: boolean } = {}): Promise<T> {
        return conConexion(async (c) => {
            if (opts.leidoConfirmado) await c.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED');
            await c.beginTransaction();
            try {
                const r = await fn(c);
                await c.commit();
                return r;
            } catch (e) {
                await c.rollback();
                throw e;
            }
        });
    }

    async function encolarPush(c: PoolConnection | Pool, userId: number, p: { clave: string; titulo: string; cuerpo: string; ruta?: string; whatsapp?: string | null }) {
        await c.query('INSERT INTO push_cola (user_id, clave, titulo, cuerpo, canal, ruta, whatsapp_respaldo) VALUES (?, ?, ?, ?, ?, ?, ?)', [
            userId,
            p.clave.slice(0, 80),
            p.titulo.slice(0, 200),
            p.cuerpo.slice(0, 1000),
            'eventos',
            p.ruta ?? 'citas',
            p.whatsapp ?? null
        ]);
    }

    // ---------------- Disponibilidad ----------------

    /** Carga horarios, bloqueos, citas y eventos y calcula los turnos libres. */
    async function calcular(
        c: PoolConnection,
        negocio: any,
        duracion: number,
        profIds: number[],
        desde: string,
        dias: number,
        opts: { ignorarLimite?: boolean } = {}
    ): Promise<DiaDisponible[]> {
        if (profIds.length === 0) return [];
        const hasta = sumarDias(desde, dias - 1);
        const [profs]: any = await c.query('SELECT id, usuario_id FROM agenda_profesionales WHERE id IN (?) AND activo = 1', [profIds]);
        if (profs.length === 0) return [];
        const ids = profs.map((p: any) => p.id);
        const [horarios]: any = await c.query(
            "SELECT profesional_id, dia, TIME_FORMAT(inicio, '%H:%i') AS inicio, TIME_FORMAT(fin, '%H:%i') AS fin FROM agenda_horarios WHERE profesional_id IN (?)",
            [ids]
        );
        const [bloqueos]: any = await c.query(
            "SELECT profesional_id, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(inicio, '%H:%i') AS inicio, TIME_FORMAT(fin, '%H:%i') AS fin FROM agenda_bloqueos WHERE profesional_id IN (?) AND fecha BETWEEN ? AND ?",
            [ids, desde, hasta]
        );
        const [citas]: any = await c.query(
            `SELECT c.profesional_id, DATE_FORMAT(c.fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(c.hora_inicio, '%H:%i') AS hi, TIME_FORMAT(c.hora_fin, '%H:%i') AS hf
             FROM agenda_citas c WHERE c.profesional_id IN (?) AND c.fecha BETWEEN ? AND ? AND ${SQL_CITA_VIGENTE}`,
            [ids, desde, hasta]
        );
        let eventos: any[] = [];
        const usuarios = profs.filter((p: any) => p.usuario_id).map((p: any) => p.usuario_id);
        if (negocio.usar_calendario && usuarios.length) {
            const [rows]: any = await c.query(
                `SELECT user_id, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(hora, '%H:%i') AS hora, categoria
                 FROM eventos WHERE user_id IN (?) AND fecha BETWEEN ? AND ? AND hora IS NOT NULL AND cita_id IS NULL AND tarjeta_credito_id IS NULL`,
                [usuarios, desde, hasta]
            );
            eventos = rows.filter((e: any) => !CATEGORIAS_SIN_BLOQUEO.has(e.categoria));
        }

        const agenda: AgendaProfesional[] = profs.map((p: any) => {
            const ocupados = new Map<string, Rango[]>();
            const agregar = (fecha: string, r: Rango) => ocupados.set(fecha, [...(ocupados.get(fecha) ?? []), r]);
            const diasBloqueados = new Set<string>();
            for (const b of bloqueos.filter((b: any) => b.profesional_id === p.id)) {
                if (!b.inicio || !b.fin) diasBloqueados.add(b.fecha);
                else agregar(b.fecha, { inicio: aMinutos(b.inicio), fin: aMinutos(b.fin) });
            }
            for (const ci of citas.filter((x: any) => x.profesional_id === p.id)) agregar(ci.fecha, { inicio: aMinutos(ci.hi), fin: aMinutos(ci.hf) });
            for (const e of eventos.filter((x: any) => x.user_id === p.usuario_id)) {
                const i = aMinutos(e.hora);
                agregar(e.fecha, { inicio: i, fin: i + DURACION_EVENTO_PERSONAL });
            }
            const hs: HorarioDia[] = horarios.filter((h: any) => h.profesional_id === p.id).map((h: any) => ({ dia: h.dia, inicio: h.inicio, fin: h.fin }));
            return { id: p.id, horarios: hs, ocupados, diasBloqueados };
        });

        const lim = limiteReserva(opts.ignorarLimite ? 0 : negocio.anticipacion_min);
        return disponibilidad({
            profesionales: agenda,
            desde,
            dias,
            duracion,
            paso: negocio.intervalo_min,
            limite: opts.ignorarLimite ? { fecha: lim.hoy, minuto: 0 } : lim,
            hasta: opts.ignorarLimite ? sumarDias(lim.hoy, 366) : sumarDias(lim.hoy, negocio.ventana_dias)
        });
    }

    /** Profesionales activos que prestan un servicio. */
    async function prestadores(c: PoolConnection, servicioId: number): Promise<number[]> {
        const [rows]: any = await c.query(
            'SELECT p.id FROM agenda_servicio_profesional sp JOIN agenda_profesionales p ON p.id = sp.profesional_id WHERE sp.servicio_id = ? AND p.activo = 1 ORDER BY p.orden, p.id',
            [servicioId]
        );
        return rows.map((r: any) => r.id);
    }

    /** Datos completos de una cita para mensajes y respuestas. */
    async function cargarCita(c: PoolConnection | Pool, where: string, params: unknown[]) {
        const [rows]: any = await c.query(
            `SELECT c.*, DATE_FORMAT(c.fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(c.hora_inicio, '%H:%i') AS hora_inicio, TIME_FORMAT(c.hora_fin, '%H:%i') AS hora_fin,
                    c.creado > NOW() - INTERVAL ${MINUTOS_CODIGO} MINUTE AS vigente,
                    GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), c.creado + INTERVAL ${MINUTOS_CODIGO} MINUTE)) AS segundos_restantes,
                    n.user_id AS dueno_id, n.nombre AS negocio_nombre, n.slug, n.color AS negocio_color, n.direccion, n.whatsapp AS negocio_whatsapp, n.rubro,
                    p.nombre AS profesional_nombre, p.usuario_id AS profesional_usuario_id, p.whatsapp AS profesional_whatsapp, p.color AS profesional_color
             FROM agenda_citas c JOIN agenda_negocios n ON n.id = c.negocio_id JOIN agenda_profesionales p ON p.id = c.profesional_id
             WHERE ${where} LIMIT 1`,
            params
        );
        return rows[0] ?? null;
    }

    const datos = (r: any): M.DatosCita => ({
        negocio: r.negocio_nombre,
        servicio: r.servicio_nombre,
        profesional: r.profesional_nombre,
        fecha: r.fecha,
        hora: r.hora_inicio,
        duracion: r.duracion_min,
        precio: Number(r.precio),
        cliente: r.cliente_nombre,
        direccion: r.direccion,
        enlace: enlaceCita(r.token),
        pagina: paginaNegocio(r.slug)
    });

    /** Vista pública de una cita (página /cita/<token> y app). */
    function vistaPublica(r: any) {
        const { fecha, minuto } = ahoraBogota();
        const empieza = r.fecha > fecha || (r.fecha === fecha && aMinutos(r.hora_inicio) > minuto);
        let estado = r.estado;
        if (estado === 'pendiente' && !r.vigente) estado = 'expirada';
        return {
            token: r.token,
            estado,
            fecha: r.fecha,
            hora_inicio: r.hora_inicio,
            hora_fin: r.hora_fin,
            servicio: r.servicio_nombre,
            duracion_min: r.duracion_min,
            precio: Number(r.precio),
            profesional: { nombre: r.profesional_nombre, iniciales: iniciales(r.profesional_nombre), color: r.profesional_color },
            cliente_nombre: M.primerNombre(r.cliente_nombre),
            whatsapp: r.cliente_whatsapp ? M.whatsappOculto(r.cliente_whatsapp) : null,
            nota: r.nota,
            segundos_restantes: estado === 'pendiente' ? Number(r.segundos_restantes) : 0,
            puede_cancelar: (estado === 'confirmada' || estado === 'pendiente') && empieza,
            motivo_cancelacion: r.motivo_cancelacion,
            negocio: { nombre: r.negocio_nombre, slug: r.slug, color: r.negocio_color, direccion: r.direccion, whatsapp: r.negocio_whatsapp, rubro: r.rubro }
        };
    }

    /** Evento en el calendario del profesional con cuenta (recordatorios del cron). */
    async function crearEvento(c: PoolConnection, r: any): Promise<number | null> {
        if (!r.profesional_usuario_id) return null;
        const [res]: any = await c.query(
            `INSERT INTO eventos (user_id, titulo, fecha, hora, categoria, ubicacion, repeticion, frecuencia, costo, tipo_transaccion, estado_pago, uuid_confirmacion, parent_id, cita_id)
             VALUES (?, ?, ?, ?, 'cita', ?, 'unica', 'unica', 0, 'ninguno', 'pendiente', ?, NULL, ?)`,
            [r.profesional_usuario_id, `${r.servicio_nombre} · ${r.cliente_nombre}`.slice(0, 255), r.fecha, r.hora_inicio, (r.direccion ?? '').slice(0, 255), crypto.randomUUID(), r.id]
        );
        return res.insertId;
    }

    async function borrarEvento(c: PoolConnection, r: any) {
        await c.query('DELETE FROM eventos WHERE cita_id = ?', [r.id]);
    }

    /** Avisos al confirmarse una cita: cliente (WhatsApp), dueño y profesional (app o WhatsApp). */
    async function avisarConfirmada(r: any) {
        const d = datos(r);
        if (r.cliente_whatsapp) await enviarWhatsApp(r.cliente_whatsapp, M.mensajeConfirmada(d));
        const push = M.pushNuevaCita(d);
        const respaldo = M.mensajeNuevaCitaProfesional(d, r.cliente_whatsapp ?? '');
        await encolarPush(pool, r.dueno_id, { clave: `cita:${r.id}:nueva`, ...push, whatsapp: respaldo });
        if (r.profesional_usuario_id && r.profesional_usuario_id !== r.dueno_id) {
            await encolarPush(pool, r.profesional_usuario_id, { clave: `cita:${r.id}:nueva`, ...push, whatsapp: respaldo });
        } else if (!r.profesional_usuario_id && r.profesional_whatsapp) {
            await enviarWhatsApp(r.profesional_whatsapp, respaldo);
        }
        if (r.cliente_usuario_id) {
            await encolarPush(pool, r.cliente_usuario_id, {
                clave: `cita:${r.id}:cliente`,
                titulo: `✅ Cita confirmada en ${r.negocio_nombre}`,
                cuerpo: `${r.servicio_nombre} · ${M.fechaLegible(r.fecha)}, ${M.hora12(r.hora_inicio)}`
            });
        }
    }

    async function avisarCancelada(r: any, porNegocio: boolean, motivo?: string | null) {
        const d = datos(r);
        if (r.cliente_whatsapp && (porNegocio || r.estado === 'confirmada')) {
            await enviarWhatsApp(r.cliente_whatsapp, M.mensajeCanceladaCliente(d, porNegocio, motivo));
        }
        if (!porNegocio && r.estado === 'confirmada') {
            const push = M.pushCancelada(d);
            const respaldo = M.mensajeCanceladaProfesional(d);
            await encolarPush(pool, r.dueno_id, { clave: `cita:${r.id}:cancelada`, ...push, whatsapp: respaldo });
            if (r.profesional_usuario_id && r.profesional_usuario_id !== r.dueno_id) {
                await encolarPush(pool, r.profesional_usuario_id, { clave: `cita:${r.id}:cancelada`, ...push, whatsapp: respaldo });
            } else if (!r.profesional_usuario_id && r.profesional_whatsapp) {
                await enviarWhatsApp(r.profesional_whatsapp, respaldo);
            }
        }
    }

    // =======================================================================
    //  RUTAS PÚBLICAS (sin sesión)
    // =======================================================================

    async function negocioPublico(c: PoolConnection | Pool, slug: string) {
        const [rows]: any = await c.query('SELECT * FROM agenda_negocios WHERE slug = ? AND activo = 1', [String(slug).toLowerCase()]);
        if (!rows[0]) throw new Falla(404, 'Esta página de citas no existe o está pausada');
        return rows[0];
    }

    server.get(
        '/api/public/agenda/:slug',
        manejar(async (req) => {
            const n = await negocioPublico(pool, req.params.slug);
            const [servicios]: any = await pool.query(
                'SELECT id, nombre, descripcion, duracion_min, precio, color FROM agenda_servicios WHERE negocio_id = ? AND activo = 1 ORDER BY orden, id',
                [n.id]
            );
            const [profs]: any = await pool.query(
                'SELECT id, nombre, cargo, color FROM agenda_profesionales WHERE negocio_id = ? AND activo = 1 ORDER BY orden, id',
                [n.id]
            );
            const [rel]: any = await pool.query(
                'SELECT sp.servicio_id, sp.profesional_id FROM agenda_servicio_profesional sp JOIN agenda_servicios s ON s.id = sp.servicio_id WHERE s.negocio_id = ?',
                [n.id]
            );
            const activos = new Set(profs.map((p: any) => p.id));
            return {
                negocio: {
                    slug: n.slug,
                    tipo: n.tipo,
                    nombre: n.nombre,
                    rubro: n.rubro,
                    descripcion: n.descripcion,
                    direccion: n.direccion,
                    whatsapp: n.whatsapp,
                    color: n.color,
                    ventana_dias: n.ventana_dias,
                    iniciales: iniciales(n.nombre)
                },
                servicios: servicios
                    .map((s: any) => ({
                        ...s,
                        precio: Number(s.precio),
                        profesionales: rel.filter((x: any) => x.servicio_id === s.id && activos.has(x.profesional_id)).map((x: any) => x.profesional_id)
                    }))
                    .filter((s: any) => s.profesionales.length > 0),
                profesionales: profs.map((p: any) => ({ id: p.id, nombre: p.nombre, cargo: p.cargo, color: p.color, iniciales: iniciales(p.nombre) }))
            };
        })
    );

    server.get(
        '/api/public/agenda/:slug/disponibilidad',
        manejar(async (req) => {
            if (!permitido(`disp:${req.ip}`, 120, 60_000)) throw new Falla(429, 'Demasiadas consultas. Espera un momento.');
            const n = await negocioPublico(pool, req.params.slug);
            const servicioId = Number(req.query.servicio);
            const profId = Number(req.query.profesional || 0);
            const hoy = ahoraBogota().fecha;
            const desde = esFecha(req.query.desde) && req.query.desde > hoy ? req.query.desde : hoy;
            const dias = Math.min(42, Math.max(1, Number(req.query.dias) || 14));
            const [srv]: any = await pool.query('SELECT id, duracion_min FROM agenda_servicios WHERE id = ? AND negocio_id = ? AND activo = 1', [servicioId, n.id]);
            if (!srv[0]) throw new Falla(404, 'Servicio no encontrado');
            return conConexion(async (c) => {
                let ids = await prestadores(c, servicioId);
                if (profId) ids = ids.filter((i) => i === profId);
                const resultado = await calcular(c, n, srv[0].duracion_min, ids, desde, dias);
                return { desde, hasta: sumarDias(hoy, n.ventana_dias), dias: resultado };
            });
        })
    );

    server.post(
        '/api/public/agenda/:slug/reservas',
        manejar(async (req) => {
            if (!permitido(`reserva:${req.ip}`, 10, 3_600_000)) throw new Falla(429, 'Has intentado agendar muchas veces. Intenta de nuevo en un rato.');
            const b = req.body ?? {};
            const nombre = texto(b.nombre, 100);
            const whatsapp = soloDigitos(b.whatsapp);
            const nota = texto(b.nota, 300) || null;
            const servicioId = Number(b.servicio_id);
            const profPedido = Number(b.profesional_id || 0);
            if (nombre.length < 2) throw new Falla(400, 'Escribe tu nombre');
            if (whatsapp.length < 10 || whatsapp.length > 15) throw new Falla(400, 'Escribe un número de WhatsApp válido con el indicativo del país');
            if (!esFecha(b.fecha) || !esHora(b.hora)) throw new Falla(400, 'Elige la fecha y la hora');
            if (!permitido(`reserva-wa:${whatsapp}`, 5, 3_600_000)) throw new Falla(429, 'Ese número ya tiene varias solicitudes recientes. Revisa tu WhatsApp.');

            // Si viene de la app con sesión, la cita queda en "Mis reservas".
            let clienteUsuarioId: number | null = null;
            try {
                if (req.headers.authorization) {
                    await req.jwtVerify();
                    clienteUsuarioId = req.user?.id ?? null;
                }
            } catch {
                clienteUsuarioId = null;
            }

            const n = await negocioPublico(pool, req.params.slug);
            const [srvRows]: any = await pool.query('SELECT * FROM agenda_servicios WHERE id = ? AND negocio_id = ? AND activo = 1', [servicioId, n.id]);
            const srv = srvRows[0];
            if (!srv) throw new Falla(404, 'Ese servicio ya no está disponible');
            const hora = aHora(aMinutos(b.hora));

            const codigo = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
            const token = crypto.randomBytes(16).toString('hex');

            const citaId = await transaccion(async (c) => {
                const [pendientes]: any = await c.query(
                    `SELECT COUNT(*) AS n FROM agenda_citas c WHERE c.negocio_id = ? AND c.cliente_whatsapp = ? AND c.estado = 'pendiente' AND c.creado > NOW() - INTERVAL ${MINUTOS_CODIGO} MINUTE`,
                    [n.id, whatsapp]
                );
                if (pendientes[0].n >= 2) throw new Falla(429, 'Ya tienes una reserva esperando confirmación. Revisa tu WhatsApp.');

                let ids = await prestadores(c, servicioId);
                if (profPedido) ids = ids.filter((i) => i === profPedido);
                if (ids.length === 0) throw new Falla(409, 'Ese profesional no presta este servicio');
                // Bloquea a los candidatos: dos reservas simultáneas no pueden tomar el mismo turno.
                await c.query('SELECT id FROM agenda_profesionales WHERE id IN (?) FOR UPDATE', [ids]);
                const [dia] = await calcular(c, n, srv.duracion_min, ids, b.fecha, 1);
                const turno = dia?.turnos.find((t) => t.hora === hora);
                if (!turno) throw new Falla(409, 'Ese horario acaba de ocuparse. Elige otro, por favor.', { codigo: 'ocupado' });

                // Con "cualquier profesional" se reparte: el que menos citas tenga ese día.
                let elegido = turno.profesionales[0];
                if (turno.profesionales.length > 1) {
                    const [carga]: any = await c.query(
                        `SELECT c.profesional_id, COUNT(*) AS n FROM agenda_citas c WHERE c.profesional_id IN (?) AND c.fecha = ? AND ${SQL_CITA_VIGENTE} GROUP BY c.profesional_id`,
                        [turno.profesionales, b.fecha]
                    );
                    const cuenta = new Map(carga.map((x: any) => [x.profesional_id, Number(x.n)]));
                    elegido = [...turno.profesionales].sort((a, z) => ((cuenta.get(a) as number) ?? 0) - ((cuenta.get(z) as number) ?? 0))[0];
                }
                const [res]: any = await c.query(
                    `INSERT INTO agenda_citas (negocio_id, profesional_id, servicio_id, servicio_nombre, duracion_min, precio, fecha, hora_inicio, hora_fin,
                        cliente_nombre, cliente_whatsapp, cliente_usuario_id, nota, estado, codigo, token, origen, codigo_enviado)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pendiente', ?, ?, ?, NOW())`,
                    [
                        n.id,
                        elegido,
                        srv.id,
                        srv.nombre,
                        srv.duracion_min,
                        srv.precio,
                        b.fecha,
                        hora,
                        aHora(aMinutos(hora) + srv.duracion_min),
                        nombre,
                        whatsapp,
                        clienteUsuarioId,
                        nota,
                        codigo,
                        token,
                        clienteUsuarioId ? 'app' : 'web'
                    ]
                );
                return res.insertId as number;
            }, { leidoConfirmado: true });

            const r = await cargarCita(pool, 'c.id = ?', [citaId]);
            const enviado = await enviarWhatsApp(whatsapp, M.mensajeCodigo(datos(r), codigo, MINUTOS_CODIGO));
            if (!enviado) {
                await pool.query('DELETE FROM agenda_citas WHERE id = ?', [citaId]);
                throw new Falla(502, 'No pudimos enviarte el WhatsApp. Revisa el número e inténtalo de nuevo.');
            }
            return { ...vistaPublica(r), minutos_codigo: MINUTOS_CODIGO };
        })
    );

    async function citaPorToken(c: PoolConnection | Pool, token: unknown) {
        if (typeof token !== 'string' || !/^[a-f0-9]{32}$/.test(token)) throw new Falla(404, 'Cita no encontrada');
        const r = await cargarCita(c, 'c.token = ?', [token]);
        if (!r) throw new Falla(404, 'Cita no encontrada');
        return r;
    }

    server.get(
        '/api/public/agenda/citas/:token',
        manejar(async (req) => vistaPublica(await citaPorToken(pool, req.params.token)))
    );

    server.post(
        '/api/public/agenda/citas/:token/confirmar',
        manejar(async (req) => {
            if (!permitido(`confirmar:${req.ip}`, 30, 600_000)) throw new Falla(429, 'Demasiados intentos. Espera unos minutos.');
            const codigo = soloDigitos(req.body?.codigo);
            const confirmada = await transaccion(async (c) => {
                const r0 = await citaPorToken(c, req.params.token);
                await c.query('SELECT id FROM agenda_citas WHERE id = ? FOR UPDATE', [r0.id]);
                const r = await cargarCita(c, 'c.id = ?', [r0.id]);
                if (r.estado === 'confirmada') return { r, nueva: false };
                if (r.estado !== 'pendiente') throw new Falla(409, 'Esta reserva ya no está activa', { estado: r.estado });
                if (!r.vigente) {
                    await c.query("UPDATE agenda_citas SET estado = 'expirada' WHERE id = ?", [r.id]);
                    return { r: { ...r, estado: 'expirada' }, nueva: false, expirada: true };
                }
                if (r.intentos >= MAX_INTENTOS) throw new Falla(429, 'Superaste los intentos. Vuelve a elegir tu horario.');
                const a = Buffer.from(codigo.padEnd(6, 'x'));
                const bb = Buffer.from(String(r.codigo));
                if (a.length !== bb.length || !crypto.timingSafeEqual(a, bb)) {
                    await c.query('UPDATE agenda_citas SET intentos = intentos + 1 WHERE id = ?', [r.id]);
                    const quedan = MAX_INTENTOS - r.intentos - 1;
                    return { r, nueva: false, error: quedan > 0 ? `Código incorrecto. Te quedan ${quedan} intento${quedan === 1 ? '' : 's'}.` : 'Código incorrecto. Vuelve a elegir tu horario.' };
                }
                await c.query("UPDATE agenda_citas SET estado = 'confirmada', confirmada_en = NOW(), codigo = NULL WHERE id = ?", [r.id]);
                const eventoId = await crearEvento(c, r);
                if (eventoId) await c.query('UPDATE agenda_citas SET evento_id = ? WHERE id = ?', [eventoId, r.id]);
                return { r: { ...r, estado: 'confirmada' }, nueva: true };
            }, { leidoConfirmado: true });
            if ((confirmada as any).expirada) throw new Falla(410, 'El código venció. Vuelve a elegir tu horario.', { estado: 'expirada' });
            if ((confirmada as any).error) throw new Falla(400, (confirmada as any).error);
            if (confirmada.nueva) await avisarConfirmada(confirmada.r);
            return vistaPublica(await cargarCita(pool, 'c.id = ?', [confirmada.r.id]));
        })
    );

    server.post(
        '/api/public/agenda/citas/:token/reenviar',
        manejar(async (req) => {
            const r = await citaPorToken(pool, req.params.token);
            if (r.estado !== 'pendiente' || !r.vigente) throw new Falla(409, 'Esta reserva ya no espera confirmación');
            const [ok]: any = await pool.query(
                'UPDATE agenda_citas SET codigo_enviado = NOW() WHERE id = ? AND (codigo_enviado IS NULL OR codigo_enviado < NOW() - INTERVAL 60 SECOND)',
                [r.id]
            );
            if (!ok.affectedRows) throw new Falla(429, 'Espera un minuto para pedir otro mensaje');
            const enviado = await enviarWhatsApp(r.cliente_whatsapp, M.mensajeCodigo(datos(r), r.codigo, Math.max(1, Math.round(Number(r.segundos_restantes) / 60))));
            if (!enviado) throw new Falla(502, 'No pudimos reenviar el WhatsApp');
            return { ok: true };
        })
    );

    server.post(
        '/api/public/agenda/citas/:token/cancelar',
        manejar(async (req) => {
            const motivo = texto(req.body?.motivo, 200) || null;
            const r = await transaccion(async (c) => {
                const r = await citaPorToken(c, req.params.token);
                const v = vistaPublica(r);
                if (!v.puede_cancelar) throw new Falla(409, 'Esta cita ya no se puede cancelar');
                await c.query("UPDATE agenda_citas SET estado = 'cancelada', cancelada_en = NOW(), cancelada_por = 'cliente', motivo_cancelacion = ?, codigo = NULL WHERE id = ?", [motivo, r.id]);
                await borrarEvento(c, r);
                return r;
            });
            await avisarCancelada(r, false, motivo);
            return vistaPublica(await cargarCita(pool, 'c.id = ?', [r.id]));
        })
    );

    // =======================================================================
    //  RUTAS DEL DUEÑO (con sesión)
    // =======================================================================

    async function negocioDe(c: PoolConnection | Pool, userId: number) {
        const [rows]: any = await c.query('SELECT * FROM agenda_negocios WHERE user_id = ?', [userId]);
        return rows[0] ?? null;
    }

    async function negocioObligatorio(c: PoolConnection | Pool, userId: number) {
        const n = await negocioDe(c, userId);
        if (!n) throw new Falla(404, 'Primero crea tu página de citas');
        return n;
    }

    /** Configuración completa para la app. */
    async function configuracion(userId: number) {
        const n = await negocioDe(pool, userId);
        if (!n) return { negocio: null };
        const [profs]: any = await pool.query(
            `SELECT p.id, p.nombre, p.cargo, p.whatsapp, p.color, p.activo, p.orden, p.usuario_id, u.nombre AS usuario_nombre, u.email AS usuario_email
             FROM agenda_profesionales p LEFT JOIN usuarios u ON u.id = p.usuario_id WHERE p.negocio_id = ? ORDER BY p.orden, p.id`,
            [n.id]
        );
        const [servicios]: any = await pool.query('SELECT * FROM agenda_servicios WHERE negocio_id = ? ORDER BY orden, id', [n.id]);
        const ids = profs.map((p: any) => p.id);
        const [horarios]: any = ids.length
            ? await pool.query("SELECT profesional_id, dia, TIME_FORMAT(inicio, '%H:%i') AS inicio, TIME_FORMAT(fin, '%H:%i') AS fin FROM agenda_horarios WHERE profesional_id IN (?) ORDER BY dia, inicio", [ids])
            : [[]];
        const [rel]: any = ids.length ? await pool.query('SELECT servicio_id, profesional_id FROM agenda_servicio_profesional WHERE profesional_id IN (?)', [ids]) : [[]];
        const [bloqueos]: any = ids.length
            ? await pool.query(
                  "SELECT id, profesional_id, DATE_FORMAT(fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(inicio, '%H:%i') AS inicio, TIME_FORMAT(fin, '%H:%i') AS fin, motivo FROM agenda_bloqueos WHERE profesional_id IN (?) AND fecha >= ? ORDER BY fecha, inicio",
                  [ids, ahoraBogota().fecha]
              )
            : [[]];
        return {
            negocio: { ...n, usar_calendario: !!n.usar_calendario, activo: !!n.activo, enlace: paginaNegocio(n.slug) },
            profesionales: profs.map((p: any) => ({
                ...p,
                activo: !!p.activo,
                es_dueno: p.usuario_id === userId,
                horarios: horarios.filter((h: any) => h.profesional_id === p.id).map(({ dia, inicio, fin }: any) => ({ dia, inicio, fin })),
                servicios: rel.filter((x: any) => x.profesional_id === p.id).map((x: any) => x.servicio_id)
            })),
            servicios: servicios.map((s: any) => ({
                ...s,
                precio: Number(s.precio),
                activo: !!s.activo,
                profesionales: rel.filter((x: any) => x.servicio_id === s.id).map((x: any) => x.profesional_id)
            })),
            bloqueos
        };
    }

    server.get('/api/agenda', auth, manejar(async (req) => configuracion(req.user.id)));

    server.get(
        '/api/agenda/slug',
        auth,
        manejar(async (req) => {
            const pedido = String(req.query.slug ?? '').toLowerCase();
            const base = slugDe(pedido) || 'mi-agenda';
            const libre = async (s: string) => {
                if (!slugValido(s)) return false;
                const [rows]: any = await pool.query('SELECT user_id FROM agenda_negocios WHERE slug = ?', [s]);
                return !rows[0] || rows[0].user_id === req.user.id;
            };
            const disponible = await libre(pedido);
            let sugerido = base.length >= 3 ? base : `${base}-agenda`;
            for (let i = 2; !(await libre(sugerido)) && i < 50; i++) sugerido = `${base.slice(0, 45)}-${i}`;
            return { slug: pedido, disponible, valido: slugValido(pedido), sugerido };
        })
    );

    server.put(
        '/api/agenda/negocio',
        auth,
        manejar(async (req) => {
            const userId = req.user.id;
            const b = req.body ?? {};
            const actual = await negocioDe(pool, userId);
            const nombre = texto(b.nombre ?? actual?.nombre, 120);
            const slug = String(b.slug ?? actual?.slug ?? '').toLowerCase();
            const tipo = b.tipo ?? actual?.tipo ?? 'profesional';
            if (nombre.length < 2) throw new Falla(400, 'Escribe el nombre que verán tus clientes');
            if (!slugValido(slug)) throw new Falla(400, 'El enlace solo puede tener letras minúsculas, números y guiones (3 a 50 caracteres)');
            if (tipo !== 'profesional' && tipo !== 'empresa') throw new Falla(400, 'Tipo inválido');
            const rubro = RUBROS.has(b.rubro) ? b.rubro : actual?.rubro ?? 'otro';
            const color = COLOR.test(b.color ?? '') ? b.color : actual?.color ?? '#2563EB';
            const whatsapp = b.whatsapp !== undefined ? soloDigitos(b.whatsapp) || null : actual?.whatsapp ?? null;
            if (whatsapp && (whatsapp.length < 10 || whatsapp.length > 15)) throw new Falla(400, 'El WhatsApp de contacto no es válido');
            const anticipacion = Math.min(10080, Math.max(0, Number(b.anticipacion_min ?? actual?.anticipacion_min ?? 60) | 0));
            const ventana = Math.min(180, Math.max(1, Number(b.ventana_dias ?? actual?.ventana_dias ?? 30) | 0));
            const intervalo = PASOS.has(Number(b.intervalo_min)) ? Number(b.intervalo_min) : actual?.intervalo_min ?? 15;
            const valores = [
                slug,
                tipo,
                nombre,
                rubro,
                b.descripcion !== undefined ? texto(b.descripcion, 500) || null : actual?.descripcion ?? null,
                b.direccion !== undefined ? texto(b.direccion, 200) || null : actual?.direccion ?? null,
                whatsapp,
                color,
                anticipacion,
                ventana,
                intervalo,
                bool(b.usar_calendario, actual ? !!actual.usar_calendario : true) ? 1 : 0,
                bool(b.activo, actual ? !!actual.activo : true) ? 1 : 0
            ];
            try {
                if (actual) {
                    await pool.query(
                        'UPDATE agenda_negocios SET slug=?, tipo=?, nombre=?, rubro=?, descripcion=?, direccion=?, whatsapp=?, color=?, anticipacion_min=?, ventana_dias=?, intervalo_min=?, usar_calendario=?, activo=? WHERE id = ?',
                        [...valores, actual.id]
                    );
                } else {
                    await transaccion(async (c) => {
                        const [res]: any = await c.query(
                            'INSERT INTO agenda_negocios (slug, tipo, nombre, rubro, descripcion, direccion, whatsapp, color, anticipacion_min, ventana_dias, intervalo_min, usar_calendario, activo, user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                            [...valores, userId]
                        );
                        // El dueño atiende: queda como primer profesional con un horario base
                        // (lunes a viernes 8–12 y 14–18) que puede cambiar después.
                        if (tipo === 'profesional' || b.dueno_atiende) {
                            const [u]: any = await c.query('SELECT nombre, whatsapp FROM usuarios WHERE id = ?', [userId]);
                            const [p]: any = await c.query('INSERT INTO agenda_profesionales (negocio_id, usuario_id, nombre, whatsapp, color) VALUES (?, ?, ?, ?, ?)', [
                                res.insertId,
                                userId,
                                u[0]?.nombre ?? nombre,
                                soloDigitos(u[0]?.whatsapp) || null,
                                color
                            ]);
                            const base = validarHorarios(
                                Array.isArray(b.horarios) ? b.horarios : [1, 2, 3, 4, 5].flatMap((dia) => [{ dia, inicio: '08:00', fin: '12:00' }, { dia, inicio: '14:00', fin: '18:00' }])
                            );
                            if (base.ok) {
                                for (const h of base.horarios) await c.query('INSERT INTO agenda_horarios (profesional_id, dia, inicio, fin) VALUES (?, ?, ?, ?)', [p.insertId, h.dia, h.inicio, h.fin]);
                            }
                        }
                    });
                }
            } catch (err: any) {
                if (err?.code === 'ER_DUP_ENTRY') throw new Falla(409, 'Ese enlace ya está en uso. Prueba con otro.');
                throw err;
            }
            return configuracion(userId);
        })
    );

    // ---------------- Profesionales ----------------

    async function guardarProfesional(req: any, id: number | null) {
        const userId = req.user.id;
        const b = req.body ?? {};
        const n = await negocioObligatorio(pool, userId);
        const nombre = texto(b.nombre, 100);
        if (nombre.length < 2) throw new Falla(400, 'Escribe el nombre del profesional');
        const whatsapp = soloDigitos(b.whatsapp) || null;
        if (whatsapp && (whatsapp.length < 10 || whatsapp.length > 15)) throw new Falla(400, 'El WhatsApp no es válido (incluye el indicativo del país)');
        const horarios = b.horarios !== undefined ? validarHorarios(b.horarios) : null;
        if (horarios && !horarios.ok) throw new Falla(400, horarios.error);
        const color = COLOR.test(b.color ?? '') ? b.color : n.color;

        // Vincular con una cuenta existente (correo o WhatsApp): sus citas le
        // llegan a la app y se cruzan con su calendario personal.
        let usuarioId: number | null | undefined;
        if (b.vincular !== undefined) {
            const v = String(b.vincular ?? '').trim().toLowerCase();
            if (!v) usuarioId = null;
            else {
                const [u]: any = await pool.query('SELECT id FROM usuarios WHERE LOWER(email) = ? OR (whatsapp <> \'\' AND REPLACE(REPLACE(whatsapp, \'+\', \'\'), \' \', \'\') = ?) LIMIT 1', [
                    v,
                    soloDigitos(v) || '-'
                ]);
                if (!u[0]) throw new Falla(404, 'No encontramos una cuenta de Agendaservi con ese correo o WhatsApp');
                usuarioId = u[0].id;
            }
        }

        return transaccion(async (c) => {
            let profId = id;
            if (id) {
                const [prev]: any = await c.query('SELECT id FROM agenda_profesionales WHERE id = ? AND negocio_id = ?', [id, n.id]);
                if (!prev[0]) throw new Falla(404, 'Profesional no encontrado');
                await c.query(
                    `UPDATE agenda_profesionales SET nombre = ?, cargo = ?, whatsapp = ?, color = ?, activo = ?${usuarioId !== undefined ? ', usuario_id = ?' : ''} WHERE id = ?`,
                    [nombre, texto(b.cargo, 80) || null, whatsapp, color, bool(b.activo, true) ? 1 : 0, ...(usuarioId !== undefined ? [usuarioId] : []), id]
                );
            } else {
                const [ord]: any = await c.query('SELECT COALESCE(MAX(orden), 0) + 1 AS o FROM agenda_profesionales WHERE negocio_id = ?', [n.id]);
                const [res]: any = await c.query(
                    'INSERT INTO agenda_profesionales (negocio_id, usuario_id, nombre, cargo, whatsapp, color, activo, orden) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [n.id, usuarioId ?? null, nombre, texto(b.cargo, 80) || null, whatsapp, color, bool(b.activo, true) ? 1 : 0, ord[0].o]
                );
                profId = res.insertId;
            }
            if (horarios?.ok) {
                await c.query('DELETE FROM agenda_horarios WHERE profesional_id = ?', [profId]);
                for (const h of horarios.horarios) await c.query('INSERT INTO agenda_horarios (profesional_id, dia, inicio, fin) VALUES (?, ?, ?, ?)', [profId, h.dia, h.inicio, h.fin]);
            }
            if (Array.isArray(b.servicios)) {
                const [validos]: any = b.servicios.length
                    ? await c.query('SELECT id FROM agenda_servicios WHERE negocio_id = ? AND id IN (?)', [n.id, b.servicios.map(Number)])
                    : [[]];
                await c.query('DELETE FROM agenda_servicio_profesional WHERE profesional_id = ?', [profId]);
                for (const s of validos) await c.query('INSERT INTO agenda_servicio_profesional (servicio_id, profesional_id) VALUES (?, ?)', [s.id, profId]);
            }
            return profId;
        }).then(() => configuracion(userId));
    }

    server.post('/api/agenda/profesionales', auth, manejar((req) => guardarProfesional(req, null)));
    server.put('/api/agenda/profesionales/:id', auth, manejar((req) => guardarProfesional(req, Number(req.params.id))));
    server.delete(
        '/api/agenda/profesionales/:id',
        auth,
        manejar(async (req) => {
            const n = await negocioObligatorio(pool, req.user.id);
            const id = Number(req.params.id);
            const [futuras]: any = await pool.query(
                "SELECT COUNT(*) AS n FROM agenda_citas WHERE profesional_id = ? AND negocio_id = ? AND estado IN ('confirmada', 'pendiente') AND fecha >= ?",
                [id, n.id, ahoraBogota().fecha]
            );
            if (futuras[0].n > 0) throw new Falla(409, `Tiene ${futuras[0].n} cita(s) próximas. Cancélalas o reasígnalas antes de eliminarlo.`);
            const [hist]: any = await pool.query('SELECT COUNT(*) AS n FROM agenda_citas WHERE profesional_id = ?', [id]);
            // Con historial se desactiva (las citas pasadas conservan su nombre).
            if (hist[0].n > 0) await pool.query('UPDATE agenda_profesionales SET activo = 0 WHERE id = ? AND negocio_id = ?', [id, n.id]);
            else await pool.query('DELETE FROM agenda_profesionales WHERE id = ? AND negocio_id = ?', [id, n.id]);
            return configuracion(req.user.id);
        })
    );

    // ---------------- Servicios ----------------

    async function guardarServicio(req: any, id: number | null) {
        const userId = req.user.id;
        const b = req.body ?? {};
        const n = await negocioObligatorio(pool, userId);
        const nombre = texto(b.nombre, 100);
        const duracion = Number(b.duracion_min);
        const precio = Number(b.precio ?? 0);
        if (nombre.length < 2) throw new Falla(400, 'Escribe el nombre del servicio');
        if (!Number.isInteger(duracion) || duracion < 5 || duracion > 600) throw new Falla(400, 'La duración debe estar entre 5 minutos y 10 horas');
        if (!Number.isFinite(precio) || precio < 0 || precio > 100_000_000) throw new Falla(400, 'Precio inválido');
        const color = COLOR.test(b.color ?? '') ? b.color : n.color;
        return transaccion(async (c) => {
            let srvId = id;
            if (id) {
                const [r]: any = await c.query(
                    'UPDATE agenda_servicios SET nombre = ?, descripcion = ?, duracion_min = ?, precio = ?, color = ?, activo = ? WHERE id = ? AND negocio_id = ?',
                    [nombre, texto(b.descripcion, 300) || null, duracion, precio, color, bool(b.activo, true) ? 1 : 0, id, n.id]
                );
                if (!r.affectedRows) throw new Falla(404, 'Servicio no encontrado');
            } else {
                const [ord]: any = await c.query('SELECT COALESCE(MAX(orden), 0) + 1 AS o FROM agenda_servicios WHERE negocio_id = ?', [n.id]);
                const [res]: any = await c.query(
                    'INSERT INTO agenda_servicios (negocio_id, nombre, descripcion, duracion_min, precio, color, activo, orden) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                    [n.id, nombre, texto(b.descripcion, 300) || null, duracion, precio, color, bool(b.activo, true) ? 1 : 0, ord[0].o]
                );
                srvId = res.insertId;
            }
            // Sin lista explícita (o negocio de una sola persona): lo prestan todos.
            const [profs]: any = await c.query('SELECT id FROM agenda_profesionales WHERE negocio_id = ?', [n.id]);
            const todos = profs.map((p: any) => p.id);
            const pedidos: number[] = Array.isArray(b.profesionales) ? b.profesionales.map(Number).filter((x: number) => todos.includes(x)) : todos;
            await c.query('DELETE FROM agenda_servicio_profesional WHERE servicio_id = ?', [srvId]);
            for (const p of pedidos) await c.query('INSERT INTO agenda_servicio_profesional (servicio_id, profesional_id) VALUES (?, ?)', [srvId, p]);
            return srvId;
        }).then(() => configuracion(userId));
    }

    server.post('/api/agenda/servicios', auth, manejar((req) => guardarServicio(req, null)));
    server.put('/api/agenda/servicios/:id', auth, manejar((req) => guardarServicio(req, Number(req.params.id))));
    server.delete(
        '/api/agenda/servicios/:id',
        auth,
        manejar(async (req) => {
            const n = await negocioObligatorio(pool, req.user.id);
            await pool.query('DELETE FROM agenda_servicios WHERE id = ? AND negocio_id = ?', [Number(req.params.id), n.id]);
            return configuracion(req.user.id);
        })
    );

    // ---------------- Bloqueos ----------------

    server.post(
        '/api/agenda/bloqueos',
        auth,
        manejar(async (req) => {
            const n = await negocioObligatorio(pool, req.user.id);
            const b = req.body ?? {};
            if (!esFecha(b.fecha)) throw new Falla(400, 'Fecha inválida');
            const parcial = b.inicio || b.fin;
            if (parcial && (!esHora(b.inicio) || !esHora(b.fin) || aMinutos(b.fin) <= aMinutos(b.inicio))) throw new Falla(400, 'Rango de horas inválido');
            const [profs]: any = await pool.query('SELECT id FROM agenda_profesionales WHERE negocio_id = ?', [n.id]);
            const todos = profs.map((p: any) => p.id);
            // Sin profesional: bloquea a todo el equipo (p. ej. un festivo del negocio).
            const destino: number[] = b.profesional_id ? [Number(b.profesional_id)].filter((x) => todos.includes(x)) : todos;
            if (destino.length === 0) throw new Falla(404, 'Profesional no encontrado');
            for (const p of destino) {
                await pool.query('INSERT INTO agenda_bloqueos (profesional_id, fecha, inicio, fin, motivo) VALUES (?, ?, ?, ?, ?)', [
                    p,
                    b.fecha,
                    parcial ? b.inicio : null,
                    parcial ? b.fin : null,
                    texto(b.motivo, 120) || null
                ]);
            }
            return configuracion(req.user.id);
        })
    );

    server.delete(
        '/api/agenda/bloqueos/:id',
        auth,
        manejar(async (req) => {
            const n = await negocioObligatorio(pool, req.user.id);
            await pool.query('DELETE b FROM agenda_bloqueos b JOIN agenda_profesionales p ON p.id = b.profesional_id WHERE b.id = ? AND p.negocio_id = ?', [Number(req.params.id), n.id]);
            return configuracion(req.user.id);
        })
    );

    // ---------------- Citas del negocio ----------------

    const SELECT_CITAS = `SELECT c.id, c.token, DATE_FORMAT(c.fecha, '%Y-%m-%d') AS fecha, TIME_FORMAT(c.hora_inicio, '%H:%i') AS hora_inicio, TIME_FORMAT(c.hora_fin, '%H:%i') AS hora_fin,
            c.servicio_id, c.servicio_nombre, c.duracion_min, c.precio, c.cliente_nombre, c.cliente_whatsapp, c.nota, c.origen, c.motivo_cancelacion, c.cancelada_por,
            CASE WHEN c.estado = 'pendiente' AND c.creado <= NOW() - INTERVAL ${MINUTOS_CODIGO} MINUTE THEN 'expirada' ELSE c.estado END AS estado,
            c.profesional_id, p.nombre AS profesional_nombre, p.color AS profesional_color, n.nombre AS negocio_nombre, n.slug, n.color AS negocio_color,
            DATE_FORMAT(c.creado, '%Y-%m-%dT%H:%i:%sZ') AS creado
        FROM agenda_citas c JOIN agenda_profesionales p ON p.id = c.profesional_id JOIN agenda_negocios n ON n.id = c.negocio_id`;

    const filaCita = (r: any, rol: string) => ({ ...r, precio: Number(r.precio), rol });

    server.get(
        '/api/agenda/citas',
        auth,
        manejar(async (req) => {
            const userId = req.user.id;
            const hoy = ahoraBogota().fecha;
            const desde = esFecha(req.query.desde) ? req.query.desde : sumarDias(hoy, -30);
            const hasta = esFecha(req.query.hasta) ? req.query.hasta : sumarDias(hoy, 90);
            // Citas de mi negocio + las que me asignan como profesional en otro negocio.
            const [propias]: any = await pool.query(`${SELECT_CITAS} WHERE n.user_id = ? AND c.fecha BETWEEN ? AND ? ORDER BY c.fecha, c.hora_inicio`, [userId, desde, hasta]);
            const [equipo]: any = await pool.query(
                `${SELECT_CITAS} WHERE p.usuario_id = ? AND n.user_id <> ? AND c.estado IN ('confirmada', 'completada', 'no_asistio', 'cancelada') AND c.fecha BETWEEN ? AND ? ORDER BY c.fecha, c.hora_inicio`,
                [userId, userId, desde, hasta]
            );
            return [...propias.map((r: any) => filaCita(r, 'dueno')), ...equipo.map((r: any) => filaCita(r, 'equipo'))];
        })
    );

    server.get(
        '/api/agenda/mis-reservas',
        auth,
        manejar(async (req) => {
            const [rows]: any = await pool.query(`${SELECT_CITAS} WHERE c.cliente_usuario_id = ? ORDER BY c.fecha DESC, c.hora_inicio DESC LIMIT 100`, [req.user.id]);
            return rows.map((r: any) => filaCita(r, 'cliente'));
        })
    );

    /** Cita que el usuario puede gestionar (dueño del negocio o profesional asignado). */
    async function citaGestionable(c: PoolConnection | Pool, userId: number, id: number) {
        const r = await cargarCita(c, 'c.id = ? AND (n.user_id = ? OR p.usuario_id = ?)', [id, userId, userId]);
        if (!r) throw new Falla(404, 'Cita no encontrada');
        return r;
    }

    // Cita creada por el negocio (cliente que llama o llega): queda confirmada.
    server.post(
        '/api/agenda/citas',
        auth,
        manejar(async (req) => {
            const userId = req.user.id;
            const b = req.body ?? {};
            const n = await negocioObligatorio(pool, userId);
            const nombre = texto(b.cliente_nombre, 100);
            const whatsapp = soloDigitos(b.cliente_whatsapp) || null;
            if (nombre.length < 2) throw new Falla(400, 'Escribe el nombre del cliente');
            if (whatsapp && (whatsapp.length < 10 || whatsapp.length > 15)) throw new Falla(400, 'El WhatsApp del cliente no es válido');
            if (!esFecha(b.fecha) || !esHora(b.hora)) throw new Falla(400, 'Elige la fecha y la hora');
            const [srvRows]: any = await pool.query('SELECT * FROM agenda_servicios WHERE id = ? AND negocio_id = ?', [Number(b.servicio_id), n.id]);
            const srv = srvRows[0];
            if (!srv) throw new Falla(404, 'Servicio no encontrado');
            const profId = Number(b.profesional_id);
            const hora = aHora(aMinutos(b.hora));
            const token = crypto.randomBytes(16).toString('hex');
            const id = await transaccion(async (c) => {
                const [pr]: any = await c.query('SELECT id FROM agenda_profesionales WHERE id = ? AND negocio_id = ? FOR UPDATE', [profId, n.id]);
                if (!pr[0]) throw new Falla(404, 'Profesional no encontrado');
                if (!b.forzar) {
                    const [dia] = await calcular(c, n, srv.duracion_min, [profId], b.fecha, 1, { ignorarLimite: true });
                    if (!dia?.turnos.some((t) => t.hora === hora)) {
                        throw new Falla(409, 'Ese horario no está libre para este profesional. ¿Agendar de todas formas?', { codigo: 'ocupado' });
                    }
                }
                const [res]: any = await c.query(
                    `INSERT INTO agenda_citas (negocio_id, profesional_id, servicio_id, servicio_nombre, duracion_min, precio, fecha, hora_inicio, hora_fin,
                        cliente_nombre, cliente_whatsapp, nota, estado, token, origen, confirmada_en)
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmada', ?, 'negocio', NOW())`,
                    [n.id, profId, srv.id, srv.nombre, srv.duracion_min, b.precio !== undefined ? Number(b.precio) || 0 : srv.precio, b.fecha, hora, aHora(aMinutos(hora) + srv.duracion_min), nombre, whatsapp, texto(b.nota, 300) || null, token]
                );
                const r = await cargarCita(c, 'c.id = ?', [res.insertId]);
                const eventoId = await crearEvento(c, r);
                if (eventoId) await c.query('UPDATE agenda_citas SET evento_id = ? WHERE id = ?', [eventoId, r.id]);
                return res.insertId as number;
            }, { leidoConfirmado: true });
            const r = await cargarCita(pool, 'c.id = ?', [id]);
            if (whatsapp && bool(b.notificar, true)) await enviarWhatsApp(whatsapp, M.mensajeConfirmada(datos(r)));
            if (r.profesional_usuario_id && r.profesional_usuario_id !== userId) {
                await encolarPush(pool, r.profesional_usuario_id, { clave: `cita:${id}:nueva`, ...M.pushNuevaCita(datos(r)) });
            } else if (!r.profesional_usuario_id && r.profesional_whatsapp) {
                await enviarWhatsApp(r.profesional_whatsapp, M.mensajeNuevaCitaProfesional(datos(r), whatsapp ?? ''));
            }
            const [fila]: any = await pool.query(`${SELECT_CITAS} WHERE c.id = ?`, [id]);
            return filaCita(fila[0], 'dueno');
        })
    );

    server.put(
        '/api/agenda/citas/:id',
        auth,
        manejar(async (req) => {
            const userId = req.user.id;
            const estado = req.body?.estado;
            const motivo = texto(req.body?.motivo, 200) || null;
            if (!['cancelada', 'completada', 'no_asistio', 'confirmada'].includes(estado)) throw new Falla(400, 'Estado inválido');
            const r = await transaccion(async (c) => {
                const r = await citaGestionable(c, userId, Number(req.params.id));
                const permitidos: Record<string, string[]> = {
                    pendiente: ['cancelada'],
                    confirmada: ['cancelada', 'completada', 'no_asistio'],
                    completada: ['confirmada', 'no_asistio'],
                    no_asistio: ['confirmada', 'completada']
                };
                if (!(permitidos[r.estado] ?? []).includes(estado)) throw new Falla(409, 'No se puede cambiar la cita a ese estado');
                if (estado === 'cancelada') {
                    await c.query("UPDATE agenda_citas SET estado = 'cancelada', cancelada_en = NOW(), cancelada_por = 'negocio', motivo_cancelacion = ?, codigo = NULL WHERE id = ?", [motivo, r.id]);
                    await borrarEvento(c, r);
                } else {
                    await c.query('UPDATE agenda_citas SET estado = ? WHERE id = ?', [estado, r.id]);
                }
                return r;
            });
            if (estado === 'cancelada') await avisarCancelada(r, true, motivo);
            const [fila]: any = await pool.query(`${SELECT_CITAS} WHERE c.id = ?`, [r.id]);
            return filaCita(fila[0], r.dueno_id === userId ? 'dueno' : 'equipo');
        })
    );
}
