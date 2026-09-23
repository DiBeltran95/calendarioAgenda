// Cliente de las rutas públicas de agendamiento (sin sesión).
import { API_BASE_URL } from '../lib/config';

export interface Negocio {
  slug: string;
  tipo: 'profesional' | 'empresa';
  nombre: string;
  rubro: string;
  descripcion: string | null;
  direccion: string | null;
  whatsapp: string | null;
  color: string;
  ventana_dias: number;
  iniciales: string;
}

export interface Servicio {
  id: number;
  nombre: string;
  descripcion: string | null;
  duracion_min: number;
  precio: number;
  color: string;
  profesionales: number[];
}

export interface Profesional {
  id: number;
  nombre: string;
  cargo: string | null;
  color: string;
  iniciales: string;
}

export interface Pagina {
  negocio: Negocio;
  servicios: Servicio[];
  profesionales: Profesional[];
}

export interface Turno {
  hora: string;
  profesionales: number[];
}

export interface Disponibilidad {
  desde: string;
  hasta: string;
  dias: { fecha: string; turnos: Turno[] }[];
}

export type EstadoCita = 'pendiente' | 'confirmada' | 'cancelada' | 'completada' | 'no_asistio' | 'expirada';

export interface CitaPublica {
  token: string;
  estado: EstadoCita;
  fecha: string;
  hora_inicio: string;
  hora_fin: string;
  servicio: string;
  duracion_min: number;
  precio: number;
  profesional: { nombre: string; iniciales: string; color: string };
  cliente_nombre: string;
  whatsapp: string | null;
  nota: string | null;
  segundos_restantes: number;
  puede_cancelar: boolean;
  motivo_cancelacion: string | null;
  negocio: { nombre: string; slug: string; color: string; direccion: string | null; whatsapp: string | null; rubro: string };
  minutos_codigo?: number;
}

export class ErrorApi extends Error {
  constructor(public status: number, message: string, public datos: Record<string, unknown> = {}) {
    super(message);
  }
}

async function pedir<T>(ruta: string, init: { method?: string; body?: unknown } = {}): Promise<T> {
  let r: Response;
  try {
    r = await fetch(API_BASE_URL + ruta, {
      method: init.method ?? 'GET',
      headers: init.body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
      body: init.body !== undefined ? JSON.stringify(init.body) : undefined,
    });
  } catch {
    throw new ErrorApi(0, 'No hay conexión. Revisa tu internet e inténtalo de nuevo.');
  }
  let datos: any = {};
  try {
    datos = await r.json();
  } catch {
    datos = {};
  }
  if (!r.ok) throw new ErrorApi(r.status, datos?.message || 'Algo salió mal. Inténtalo de nuevo.', datos);
  return datos as T;
}

const s = (v: string) => encodeURIComponent(v);

export const agendaApi = {
  pagina: (slug: string) => pedir<Pagina>(`/api/public/agenda/${s(slug)}`),
  disponibilidad: (slug: string, servicio: number, profesional: number, desde: string, dias: number) =>
    pedir<Disponibilidad>(`/api/public/agenda/${s(slug)}/disponibilidad?servicio=${servicio}&profesional=${profesional}&desde=${desde}&dias=${dias}`),
  reservar: (slug: string, body: { servicio_id: number; profesional_id: number; fecha: string; hora: string; nombre: string; whatsapp: string; nota?: string }) =>
    pedir<CitaPublica>(`/api/public/agenda/${s(slug)}/reservas`, { method: 'POST', body }),
  cita: (token: string) => pedir<CitaPublica>(`/api/public/agenda/citas/${s(token)}`),
  confirmar: (token: string, codigo: string) => pedir<CitaPublica>(`/api/public/agenda/citas/${s(token)}/confirmar`, { method: 'POST', body: { codigo } }),
  reenviar: (token: string) => pedir<{ ok: true }>(`/api/public/agenda/citas/${s(token)}/reenviar`, { method: 'POST', body: {} }),
  cancelar: (token: string, motivo?: string) => pedir<CitaPublica>(`/api/public/agenda/citas/${s(token)}/cancelar`, { method: 'POST', body: { motivo } }),
};
