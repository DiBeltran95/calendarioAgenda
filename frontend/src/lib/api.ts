// Capa única de acceso al backend.
//
// Antes cada componente hacía su `fetch` con su cabecera Authorization repetida
// a mano (más de treinta veces). Centralizarlo permite que el modo sin conexión
// exista: aquí es donde se distingue "el servidor respondió que no" de "no hubo
// forma de preguntárselo", que es la diferencia entre un error real y algo que
// hay que encolar.

import { API_BASE_URL } from './config';
import { marcarOffline, marcarOnline } from './net';
import { encolar, nuevoIdTemporal, type Metodo } from './outbox';

/** El servidor respondió, pero con un error. */
export class ErrorApi extends Error {
  status: number;
  data: any;
  constructor(status: number, message: string, data?: any) {
    super(message);
    this.name = 'ErrorApi';
    this.status = status;
    this.data = data;
  }
}

/** No se pudo contactar con el servidor (sin conexión, DNS, timeout). */
export class ErrorDeRed extends Error {
  constructor(message = 'Sin conexión con el servidor') {
    super(message);
    this.name = 'ErrorDeRed';
  }
}

function cabeceras(conCuerpo: boolean): Record<string, string> {
  const h: Record<string, string> = {};
  const token = localStorage.getItem('token');
  if (token) h.Authorization = `Bearer ${token}`;
  if (conCuerpo) h['Content-Type'] = 'application/json';
  return h;
}

interface OpcionesPeticion {
  metodo?: 'GET' | Metodo;
  body?: any;
  /** Corta la espera; en móvil evita que una red "presente pero muerta" cuelgue la UI. */
  timeoutMs?: number;
}

/**
 * Petición cruda. Lanza `ErrorDeRed` si no hubo respuesta y `ErrorApi` si la
 * hubo pero fue de error. Actualiza el estado de conectividad en ambos casos.
 */
export async function peticion<T = any>(path: string, opts: OpcionesPeticion = {}): Promise<T> {
  const { metodo = 'GET', body, timeoutMs = 15000 } = opts;

  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);

  let res: Response;
  try {
    res = await fetch(`${API_BASE_URL}${path}`, {
      method: metodo,
      headers: cabeceras(body !== undefined),
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: ctrl.signal
    });
  } catch (err: any) {
    // TypeError = fallo de red del navegador; AbortError = se agotó el timeout.
    if (err instanceof TypeError || err?.name === 'AbortError') {
      marcarOffline();
      throw new ErrorDeRed();
    }
    throw err;
  } finally {
    clearTimeout(t);
  }

  marcarOnline();

  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new ErrorApi(res.status, (data as any)?.message || `Error ${res.status}`, data);
  }
  return data as T;
}

/** Lectura. Devuelve `null` si no hay conexión, para que el llamador use su caché. */
export async function leer<T = any>(path: string): Promise<T | null> {
  try {
    return await peticion<T>(path);
  } catch (err) {
    if (err instanceof ErrorDeRed) return null;
    throw err;
  }
}

export interface ResultadoMutacion<T = any> {
  /** true si el servidor confirmó el cambio; false si quedó encolado. */
  confirmado: boolean;
  /** Respuesta del servidor, o null si quedó encolado. */
  data: T | null;
  /** Id asignado: el real del servidor, o uno temporal si quedó encolado. */
  id: number | string | null;
}

interface OpcionesMutacion {
  /** Colección afectada, para describir la operación en la UI. */
  entidad: string;
  /** Sólo en creaciones: reserva un id temporal para pintarlo al instante. */
  crea?: boolean;
}

/**
 * Escritura tolerante a la falta de conexión.
 *
 * Si el servidor responde, se devuelve su respuesta. Si no hay forma de
 * llegar a él, la operación se encola y se devuelve `confirmado: false` con un
 * id temporal, para que la interfaz pueda mostrar el cambio de inmediato.
 *
 * Un error del servidor (400, 409...) NO se encola: es un rechazo real y se
 * propaga como `ErrorApi` para que el llamador lo muestre.
 */
export async function mutar<T = any>(
  metodo: Metodo,
  path: string,
  body: any,
  opts: OpcionesMutacion
): Promise<ResultadoMutacion<T>> {
  try {
    const data = await peticion<T>(path, { metodo, body });
    return { confirmado: true, data, id: (data as any)?.id ?? null };
  } catch (err) {
    if (!(err instanceof ErrorDeRed)) throw err;

    const tempId = opts.crea ? nuevoIdTemporal() : undefined;
    encolar({ metodo, path, body, entidad: opts.entidad, tempId });
    return { confirmado: false, data: null, id: tempId ?? null };
  }
}
