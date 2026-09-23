// Utilidades de formato y calendario para las páginas de agendamiento.
// Todo en hora de Colombia (UTC−5 fijo), igual que el backend.

const DIAS = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const DIAS_CORTOS = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

export const RUBROS: Record<string, string> = {
  psicologia: 'Psicología',
  salud: 'Salud',
  odontologia: 'Odontología',
  peluqueria: 'Peluquería',
  barberia: 'Barbería',
  estetica: 'Estética',
  spa: 'Spa y bienestar',
  unas: 'Uñas',
  fitness: 'Entrenamiento',
  consultoria: 'Consultoría',
  educacion: 'Clases y tutorías',
  mascotas: 'Mascotas',
  otro: 'Servicios',
};

const fechaUTC = (f: string) => new Date(`${f}T12:00:00Z`);

export function hoyBogota(): string {
  return new Date(Date.now() - 5 * 3600 * 1000).toISOString().slice(0, 10);
}

export function sumarDias(f: string, n: number): string {
  const d = fechaUTC(f);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

/** 'jueves, 24 de septiembre' */
export function fechaLarga(f: string): string {
  const d = fechaUTC(f);
  return `${DIAS[d.getUTCDay()]}, ${d.getUTCDate()} de ${MESES[d.getUTCMonth()]}`;
}

/** 'jue 24 sep' */
export function fechaCorta(f: string): string {
  const d = fechaUTC(f);
  return `${DIAS_CORTOS[d.getUTCDay()]} ${d.getUTCDate()} ${MESES[d.getUTCMonth()]!.slice(0, 3)}`;
}

export function nombreMes(f: string): string {
  const d = fechaUTC(f);
  const m = MESES[d.getUTCMonth()]!;
  return `${m[0]!.toUpperCase()}${m.slice(1)} ${d.getUTCFullYear()}`;
}

/** '15:30' → '3:30 p. m.' */
export function hora12(h: string): string {
  const [hh = 0, mm = 0] = h.split(':').map(Number);
  return `${hh % 12 || 12}:${String(mm).padStart(2, '0')} ${hh >= 12 ? 'p. m.' : 'a. m.'}`;
}

export function pesos(n: number): string {
  return '$' + Math.round(n).toLocaleString('es-CO').replace(/,/g, '.');
}

/** 90 → '1 h 30 min' */
export function duracion(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  if (!h) return `${m} min`;
  return m ? `${h} h ${m} min` : `${h} h`;
}

export function franja(hora: string): 'manana' | 'tarde' | 'noche' {
  const h = Number(hora.slice(0, 2));
  return h < 12 ? 'manana' : h < 18 ? 'tarde' : 'noche';
}

/** Celdas de un mes (semanas de lunes a domingo); null = relleno. */
export function celdasMes(primero: string): (string | null)[] {
  const d = fechaUTC(primero);
  const inicio = (d.getUTCDay() + 6) % 7; // lunes = 0
  const diasMes = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  const out: (string | null)[] = Array(inicio).fill(null);
  for (let i = 0; i < diasMes; i++) out.push(sumarDias(primero, i));
  while (out.length % 7) out.push(null);
  return out;
}

export function primeroDelMes(f: string): string {
  return `${f.slice(0, 7)}-01`;
}

export function mesSiguiente(primero: string, delta: number): string {
  const d = fechaUTC(primero);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + delta, 1, 12)).toISOString().slice(0, 10);
}

/** Texto legible sobre un color de fondo (negro o blanco según luminancia). */
export function textoSobre(hex: string): string {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex);
  if (!m) return '#ffffff';
  const n = parseInt(m[1]!, 16);
  const canal = (c: number) => {
    const v = c / 255;
    return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
  };
  const l = 0.2126 * canal((n >> 16) & 255) + 0.7152 * canal((n >> 8) & 255) + 0.0722 * canal(n & 255);
  return l > 0.45 ? '#0f172a' : '#ffffff';
}

/** Instante UTC 'YYYYMMDDTHHMMSSZ' de una fecha y hora de Bogotá. */
function utcCompacto(fecha: string, hora: string): string {
  const d = new Date(`${fecha}T${hora}:00-05:00`);
  return d.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
}

export interface DatosCalendario {
  titulo: string;
  fecha: string;
  inicio: string;
  fin: string;
  detalle: string;
  lugar?: string | null;
}

export function enlaceGoogleCalendar(c: DatosCalendario): string {
  const p = new URLSearchParams({
    action: 'TEMPLATE',
    text: c.titulo,
    dates: `${utcCompacto(c.fecha, c.inicio)}/${utcCompacto(c.fecha, c.fin)}`,
    details: c.detalle,
    ctz: 'America/Bogota',
  });
  if (c.lugar) p.set('location', c.lugar);
  return `https://calendar.google.com/calendar/render?${p.toString()}`;
}

export function enlaceOutlook(c: DatosCalendario): string {
  const iso = (h: string) => new Date(`${c.fecha}T${h}:00-05:00`).toISOString();
  const p = new URLSearchParams({ path: '/calendar/action/compose', rru: 'addevent', subject: c.titulo, startdt: iso(c.inicio), enddt: iso(c.fin), body: c.detalle });
  if (c.lugar) p.set('location', c.lugar);
  return `https://outlook.live.com/calendar/0/deeplink/compose?${p.toString()}`;
}

/** Archivo .ics (Apple Calendar y cualquier otro). */
export function descargarIcs(c: DatosCalendario, nombreArchivo = 'cita.ics'): void {
  const esc = (t: string) => t.replace(/[\\,;]/g, (m) => '\\' + m).replace(/\n/g, '\\n');
  const ahora = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const ics = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Agendaservi//Citas//ES',
    'BEGIN:VEVENT',
    `UID:${ahora}-${Math.random().toString(36).slice(2)}@agendaservi.com`,
    `DTSTAMP:${ahora}`,
    `DTSTART:${utcCompacto(c.fecha, c.inicio)}`,
    `DTEND:${utcCompacto(c.fecha, c.fin)}`,
    `SUMMARY:${esc(c.titulo)}`,
    `DESCRIPTION:${esc(c.detalle)}`,
    c.lugar ? `LOCATION:${esc(c.lugar)}` : '',
    'BEGIN:VALARM',
    'TRIGGER:-PT1H',
    'ACTION:DISPLAY',
    `DESCRIPTION:${esc(c.titulo)}`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
  ]
    .filter(Boolean)
    .join('\r\n');
  const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar;charset=utf-8' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = nombreArchivo;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function reduceMovimiento(): boolean {
  return typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
}

/** Enlace a WhatsApp con un mensaje prellenado. */
export function enlaceWhatsApp(numero: string, texto = ''): string {
  return `https://wa.me/${numero.replace(/\D/g, '')}${texto ? `?text=${encodeURIComponent(texto)}` : ''}`;
}

export function esMovil(): boolean {
  return typeof navigator !== 'undefined' && /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
}

/** Recordar nombre y WhatsApp para la próxima reserva (solo en este navegador). */
export const memoria = {
  leer(): { nombre: string; indicativo: string; numero: string } | null {
    try {
      const v = localStorage.getItem('agendaservi:cliente');
      return v ? JSON.parse(v) : null;
    } catch {
      return null;
    }
  },
  guardar(v: { nombre: string; indicativo: string; numero: string }) {
    try {
      localStorage.setItem('agendaservi:cliente', JSON.stringify(v));
    } catch {
      /* navegación privada o almacenamiento bloqueado */
    }
  },
};
