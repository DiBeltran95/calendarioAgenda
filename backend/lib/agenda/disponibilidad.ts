// Cálculo de horarios disponibles para el agendamiento de citas.
//
// Funciones puras (sin base de datos) para poder probarlas: todo se trabaja
// en minutos del día y con la hora de Colombia (UTC−5 fijo, sin horario de
// verano), igual que el resto del sistema.

export interface Rango {
    /** Minuto del día en que empieza (inclusive). */
    inicio: number;
    /** Minuto del día en que termina (exclusivo). */
    fin: number;
}

const OFFSET_BOGOTA_MS = -5 * 60 * 60 * 1000;

/** 'HH:MM' o 'HH:MM:SS' → minutos del día. */
export function aMinutos(hora: string): number {
    const [h = 0, m = 0] = String(hora).split(":").map(Number);
    return h * 60 + (m || 0);
}

/** Minutos del día → 'HH:MM'. */
export function aHora(min: number): string {
    return `${String(Math.floor(min / 60)).padStart(2, '0')}:${String(min % 60).padStart(2, '0')}`;
}

/** Fecha y minuto actuales en Bogotá. */
export function ahoraBogota(ahora: Date = new Date()): { fecha: string; minuto: number } {
    const b = new Date(ahora.getTime() + OFFSET_BOGOTA_MS);
    return { fecha: b.toISOString().slice(0, 10), minuto: b.getUTCHours() * 60 + b.getUTCMinutes() };
}

/** Suma días a 'YYYY-MM-DD'. */
export function sumarDias(fecha: string, dias: number): string {
    const d = new Date(`${fecha}T12:00:00Z`);
    d.setUTCDate(d.getUTCDate() + dias);
    return d.toISOString().slice(0, 10);
}

/** 0 = domingo … 6 = sábado. */
export function diaSemana(fecha: string): number {
    return new Date(`${fecha}T12:00:00Z`).getUTCDay();
}

export function esFecha(v: unknown): v is string {
    if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
    const d = new Date(`${v}T12:00:00Z`);
    return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
}

export function esHora(v: unknown): v is string {
    return typeof v === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(v);
}

/** true si [a.inicio, a.fin) y [b.inicio, b.fin) se cruzan. */
export function seCruzan(a: Rango, b: Rango): boolean {
    return a.inicio < b.fin && a.fin > b.inicio;
}

/**
 * Minutos de inicio posibles para un servicio de `duracion` minutos.
 *
 * - Los turnos se alinean al inicio de cada rango laboral cada `paso` minutos
 *   (8:00, 8:15, 8:30…), así la agenda se ve ordenada.
 * - El servicio completo debe caber dentro del rango y no cruzarse con nada
 *   ocupado (citas, bloqueos, eventos del calendario personal).
 * - `desde` descarta lo que ya pasó (o lo que no cumple la anticipación
 *   mínima) cuando la fecha es hoy.
 */
export function turnosLibres(opts: { rangos: Rango[]; ocupados: Rango[]; duracion: number; paso: number; desde?: number }): number[] {
    const { rangos, ocupados, duracion, paso } = opts;
    const desde = opts.desde ?? 0;
    if (duracion <= 0 || paso <= 0) return [];
    const libres = new Set<number>();
    for (const r of rangos) {
        const primero = Math.max(r.inicio, desde);
        let t = r.inicio + Math.ceil((primero - r.inicio) / paso) * paso;
        for (; t + duracion <= r.fin; t += paso) {
            const turno = { inicio: t, fin: t + duracion };
            if (!ocupados.some((o) => seCruzan(turno, o))) libres.add(t);
        }
    }
    return [...libres].sort((a, b) => a - b);
}

/** Une rangos solapados o contiguos y descarta los vacíos. */
export function normalizarRangos(rangos: Rango[]): Rango[] {
    const orden = rangos.filter((r) => r.fin > r.inicio).sort((a, b) => a.inicio - b.inicio);
    const out: Rango[] = [];
    for (const r of orden) {
        const ultimo = out[out.length - 1];
        if (ultimo && r.inicio <= ultimo.fin) ultimo.fin = Math.max(ultimo.fin, r.fin);
        else out.push({ ...r });
    }
    return out;
}

export interface HorarioDia {
    dia: number;
    inicio: string;
    fin: string;
}

/** Valida y normaliza los horarios semanales que envía la app. */
export function validarHorarios(entrada: unknown): { ok: true; horarios: HorarioDia[] } | { ok: false; error: string } {
    if (!Array.isArray(entrada)) return { ok: false, error: 'El horario debe ser una lista' };
    if (entrada.length > 70) return { ok: false, error: 'Demasiados rangos de horario' };
    const out: HorarioDia[] = [];
    for (const h of entrada) {
        const dia = Number((h as any)?.dia);
        const inicio = (h as any)?.inicio;
        const fin = (h as any)?.fin;
        if (!Number.isInteger(dia) || dia < 0 || dia > 6) return { ok: false, error: 'Día de la semana inválido' };
        if (!esHora(inicio) || !esHora(fin)) return { ok: false, error: 'Hora inválida en el horario' };
        if (aMinutos(fin) <= aMinutos(inicio)) return { ok: false, error: 'La hora final debe ser posterior a la inicial' };
        out.push({ dia, inicio: aHora(aMinutos(inicio)), fin: aHora(aMinutos(fin)) });
    }
    // Rangos solapados del mismo día se fusionan.
    const porDia = new Map<number, Rango[]>();
    for (const h of out) {
        const l = porDia.get(h.dia) ?? [];
        l.push({ inicio: aMinutos(h.inicio), fin: aMinutos(h.fin) });
        porDia.set(h.dia, l);
    }
    const horarios: HorarioDia[] = [];
    for (const [dia, rangos] of [...porDia.entries()].sort((a, b) => a[0] - b[0])) {
        for (const r of normalizarRangos(rangos)) horarios.push({ dia, inicio: aHora(r.inicio), fin: aHora(r.fin) });
    }
    return { ok: true, horarios };
}

/** Datos de un profesional para calcular un día. */
export interface AgendaProfesional {
    id: number;
    horarios: HorarioDia[];
    /** Rangos ocupados por fecha ('YYYY-MM-DD'). */
    ocupados: Map<string, Rango[]>;
    /** Fechas completas bloqueadas (vacaciones, festivo propio…). */
    diasBloqueados: Set<string>;
}

export interface DiaDisponible {
    fecha: string;
    turnos: { hora: string; profesionales: number[] }[];
}

/**
 * Disponibilidad de varios días para uno o varios profesionales. Un turno
 * aparece si al menos uno de ellos está libre, con la lista de quiénes lo
 * están (para "cualquier profesional").
 */
export function disponibilidad(opts: {
    profesionales: AgendaProfesional[];
    desde: string;
    dias: number;
    duracion: number;
    paso: number;
    /** Fecha y minuto a partir de los cuales se puede reservar (ahora + anticipación). */
    limite: { fecha: string; minuto: number };
    /** Última fecha reservable (hoy + ventana). */
    hasta: string;
}): DiaDisponible[] {
    const out: DiaDisponible[] = [];
    for (let i = 0; i < opts.dias; i++) {
        const fecha = sumarDias(opts.desde, i);
        if (fecha > opts.hasta) break;
        if (fecha < opts.limite.fecha) {
            out.push({ fecha, turnos: [] });
            continue;
        }
        const desdeMin = fecha === opts.limite.fecha ? opts.limite.minuto : 0;
        const dia = diaSemana(fecha);
        const porHora = new Map<number, number[]>();
        for (const p of opts.profesionales) {
            if (p.diasBloqueados.has(fecha)) continue;
            const rangos = normalizarRangos(
                p.horarios.filter((h) => h.dia === dia).map((h) => ({ inicio: aMinutos(h.inicio), fin: aMinutos(h.fin) }))
            );
            const libres = turnosLibres({ rangos, ocupados: p.ocupados.get(fecha) ?? [], duracion: opts.duracion, paso: opts.paso, desde: desdeMin });
            for (const t of libres) {
                const l = porHora.get(t) ?? [];
                l.push(p.id);
                porHora.set(t, l);
            }
        }
        out.push({
            fecha,
            turnos: [...porHora.entries()].sort((a, b) => a[0] - b[0]).map(([t, profesionales]) => ({ hora: aHora(t), profesionales }))
        });
    }
    return out;
}

/** Slug de URL a partir de un nombre: "Peluquería Doña Ana" → "peluqueria-dona-ana". */
export function slugDe(texto: string): string {
    return String(texto)
        .normalize('NFD')
        .replace(/[̀-ͯ]/g, '')
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 50)
        .replace(/-+$/g, '');
}

const SLUGS_RESERVADOS = new Set(['admin', 'api', 'app', 'login', 'registro', 'register', 'dashboard', 'select', 'confirmar', 'cita', 'citas', 'agenda', 'soporte', 'ayuda', 'nuevo', 'editar']);

export function slugValido(slug: unknown): slug is string {
    return typeof slug === 'string' && /^[a-z0-9](?:[a-z0-9-]{1,48}[a-z0-9])$/.test(slug) && !slug.includes('--') && !SLUGS_RESERVADOS.has(slug);
}
