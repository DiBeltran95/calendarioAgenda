// Textos de WhatsApp y notificaciones del agendamiento de citas.

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

/** 'YYYY-MM-DD' → 'jueves 24 de septiembre'. */
export function fechaLegible(fecha: string): string {
    const d = new Date(`${fecha}T12:00:00Z`);
    return `${DIAS[d.getUTCDay()]} ${d.getUTCDate()} de ${MESES[d.getUTCMonth()]}`;
}

/** 'HH:MM' → '3:30 p. m.' */
export function hora12(hora: string): string {
    const [h = 0, m = 0] = hora.split(":").map(Number);
    const sufijo = h >= 12 ? 'p. m.' : 'a. m.';
    return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${sufijo}`;
}

export function pesos(valor: number | string): string {
    const n = Number(valor || 0);
    return '$' + Math.round(n).toLocaleString('es-CO').replace(/,/g, '.');
}

/** '573001234567' → '+57 300 *** 4567' */
export function whatsappOculto(numero: string): string {
    const d = String(numero).replace(/\D/g, '');
    if (d.length < 8) return d;
    const local = d.length > 10 ? d.slice(-10) : d;
    const pais = d.length > 10 ? `+${d.slice(0, d.length - 10)} ` : '';
    return `${pais}${local.slice(0, 3)} *** ${local.slice(-4)}`;
}

export function primerNombre(nombre: string): string {
    return String(nombre).trim().split(/\s+/)[0] || '';
}

export interface DatosCita {
    negocio: string;
    servicio: string;
    profesional: string;
    fecha: string;
    hora: string;
    duracion: number;
    precio: number;
    cliente: string;
    direccion?: string | null;
    /** Enlace para gestionar esta cita (…/cita/<token>). */
    enlace: string;
    /** Página pública del negocio para agendar de nuevo (…/agenda/<slug>). */
    pagina: string;
}

function detalle(c: DatosCita): string {
    const l = [`📅 *${fechaLegible(c.fecha)}* · 🕒 *${hora12(c.hora)}*`, `✨ ${c.servicio} (${c.duracion} min)`, `👤 Con ${c.profesional}`];
    if (c.precio > 0) l.push(`💵 ${pesos(c.precio)}`);
    if (c.direccion) l.push(`📍 ${c.direccion}`);
    return l.join('\n');
}

export function mensajeCodigo(c: DatosCita, codigo: string, minutos: number): string {
    return (
        `🗓️ *${c.negocio}*\n\n` +
        `Hola ${primerNombre(c.cliente)}, estás a un paso de agendar tu cita:\n\n` +
        `${detalle(c)}\n\n` +
        `Tu código de confirmación es:\n*${codigo}*\n\n` +
        `O confirma con un toque aquí:\n${c.enlace}?c=${codigo}\n\n` +
        `⏳ Vence en ${minutos} minutos. Si no fuiste tú, ignora este mensaje.`
    );
}

export function mensajeConfirmada(c: DatosCita): string {
    return (
        `✅ *¡Cita confirmada!*\n\n` +
        `${primerNombre(c.cliente)}, te esperamos en *${c.negocio}*.\n\n` +
        `${detalle(c)}\n\n` +
        `Te recordaremos antes de la cita. ¿Necesitas cancelar? Hazlo aquí:\n${c.enlace}`
    );
}

export function mensajeRecordatorio(c: DatosCita): string {
    return (
        `⏰ *Recordatorio de tu cita*\n\n` +
        `${primerNombre(c.cliente)}, hoy tienes cita en *${c.negocio}*:\n\n` +
        `${detalle(c)}\n\n` +
        `Si no puedes asistir, cancela aquí para liberar el espacio:\n${c.enlace}`
    );
}

export function mensajeCanceladaCliente(c: DatosCita, porNegocio: boolean, motivo?: string | null): string {
    const quien = porNegocio ? `*${c.negocio}* canceló tu cita` : 'Cancelaste tu cita';
    return (
        `❌ ${quien} del ${fechaLegible(c.fecha)} a las ${hora12(c.hora)} (${c.servicio}).` +
        (motivo ? `\n\nMotivo: ${motivo}` : '') +
        `\n\nPuedes agendar una nueva cuando quieras:\n${c.pagina}`
    );
}

/** Aviso al profesional que no usa la app (solo tiene WhatsApp). */
export function mensajeNuevaCitaProfesional(c: DatosCita, clienteWhatsapp: string): string {
    return (
        `🗓️ *Nueva cita en ${c.negocio}*\n\n` +
        `${detalle(c)}\n` +
        `🙋 Cliente: ${c.cliente} (+${clienteWhatsapp})`
    );
}

export function mensajeCanceladaProfesional(c: DatosCita): string {
    return `❌ *Cita cancelada*\n\n${c.cliente} canceló su cita del ${fechaLegible(c.fecha)} a las ${hora12(c.hora)} (${c.servicio}). El espacio quedó libre.`;
}

/** Título y cuerpo del push al dueño o al profesional con la app. */
export function pushNuevaCita(c: DatosCita): { titulo: string; cuerpo: string } {
    return {
        titulo: `🗓️ Nueva cita: ${c.cliente}`,
        cuerpo: `${c.servicio} · ${fechaLegible(c.fecha)}, ${hora12(c.hora)} con ${c.profesional}`
    };
}

export function pushCancelada(c: DatosCita): { titulo: string; cuerpo: string } {
    return {
        titulo: `❌ Cita cancelada: ${c.cliente}`,
        cuerpo: `${c.servicio} · ${fechaLegible(c.fecha)}, ${hora12(c.hora)}. El espacio quedó libre.`
    };
}
