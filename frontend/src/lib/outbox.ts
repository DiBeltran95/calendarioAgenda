// Cola de operaciones pendientes de enviar al servidor.
//
// Cuando no hay conexión, las escrituras no se pierden: se guardan aquí en
// orden y se reenvían al recuperar la señal. El orden importa — si creas un
// evento y luego lo borras estando offline, hay que enviar primero la creación.
//
// Ids temporales: un registro creado sin conexión no tiene id de servidor, así
// que recibe uno local (`tmp_...`). Al sincronizar, el servidor devuelve el id
// real y se reescriben las operaciones posteriores que apuntaban al temporal.

import { writable, get } from 'svelte/store';
import { API_BASE_URL } from './config';
import { marcarOffline, marcarOnline } from './net';

export type Metodo = 'POST' | 'PUT' | 'DELETE';

export interface Operacion {
  id: string;
  metodo: Metodo;
  path: string;
  body?: any;
  /** Colección afectada, para poder describirla en la UI. */
  entidad: string;
  /** Id temporal asignado al crear sin conexión. */
  tempId?: string;
  creadoEn: number;
  intentos: number;
  ultimoError?: string;
}

const CLAVE = 'outbox_v1';

/** Operaciones pendientes, en orden de llegada. */
export const pendientes = writable<Operacion[]>(leer());

/** Operaciones descartadas por ser inválidas; la UI las muestra al usuario. */
export const descartadas = writable<Array<{ op: Operacion; motivo: string }>>([]);

export const sincronizando = writable(false);

function leer(): Operacion[] {
  try {
    const raw = localStorage.getItem(CLAVE);
    const arr = raw ? JSON.parse(raw) : [];
    return Array.isArray(arr) ? arr : [];
  } catch {
    return [];
  }
}

function guardar(ops: Operacion[]) {
  try {
    localStorage.setItem(CLAVE, JSON.stringify(ops));
  } catch {
    // Si no cabe la cola es preferible saberlo que perder datos en silencio.
    console.error('No se pudo guardar la cola de sincronización (cuota llena)');
  }
  pendientes.set(ops);
}

export function nuevoIdTemporal(): string {
  return `tmp_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}

export function esIdTemporal(id: unknown): boolean {
  return typeof id === 'string' && id.startsWith('tmp_');
}

/** Añade una operación al final de la cola. */
export function encolar(op: Omit<Operacion, 'id' | 'creadoEn' | 'intentos'>): Operacion {
  const completa: Operacion = {
    ...op,
    id: nuevoIdTemporal(),
    creadoEn: Date.now(),
    intentos: 0
  };
  guardar([...leer(), completa]);
  return completa;
}

/** Descarta una operación pendiente (el usuario decide no reintentarla). */
export function descartar(opId: string) {
  guardar(leer().filter((o) => o.id !== opId));
}

export function limpiarDescartadas() {
  descartadas.set([]);
}

/** Sustituye un id temporal por el real en las operaciones aún encoladas. */
function reescribirReferencias(ops: Operacion[], tempId: string, realId: number): Operacion[] {
  return ops.map((op) => {
    const path = op.path.includes(tempId) ? op.path.replace(tempId, String(realId)) : op.path;
    let body = op.body;
    if (body && typeof body === 'object') {
      let tocado = false;
      const copia: any = Array.isArray(body) ? [...body] : { ...body };
      for (const k of Object.keys(copia)) {
        if (copia[k] === tempId) {
          copia[k] = realId;
          tocado = true;
        }
      }
      if (tocado) body = copia;
    }
    return path === op.path && body === op.body ? op : { ...op, path, body };
  });
}

function esErrorDeRed(err: any): boolean {
  return err instanceof TypeError || err?.name === 'AbortError';
}

export interface ResultadoSync {
  enviadas: number;
  pendientes: number;
  descartadas: number;
  /** true si se detuvo porque volvió a caerse la red. */
  interrumpida: boolean;
}

/**
 * Reenvía la cola en orden.
 *
 * Se detiene al primer fallo de red para no romper el orden. Un 4xx, en cambio,
 * significa que la operación nunca va a funcionar (el registro ya no existe, o
 * el dato es inválido): se descarta y se informa, en vez de bloquear la cola
 * para siempre.
 */
export async function sincronizar(): Promise<ResultadoSync> {
  if (get(sincronizando)) {
    return { enviadas: 0, pendientes: leer().length, descartadas: 0, interrumpida: false };
  }
  sincronizando.set(true);

  let ops = leer();
  let enviadas = 0;
  let nDescartadas = 0;
  let interrumpida = false;

  try {
    while (ops.length > 0) {
      const op = ops[0];
      const token = localStorage.getItem('token');

      let res: Response;
      try {
        res = await fetch(`${API_BASE_URL}${op.path}`, {
          method: op.metodo,
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`
          },
          body: op.body !== undefined ? JSON.stringify(op.body) : undefined
        });
      } catch (err) {
        if (esErrorDeRed(err)) {
          marcarOffline();
          interrumpida = true;
          break;
        }
        throw err;
      }

      marcarOnline();

      if (res.ok) {
        const data = await res.json().catch(() => ({}));
        ops = ops.slice(1);
        // Si creó un registro, propagamos el id real a lo que venga después.
        if (op.tempId && data && typeof data.id === 'number') {
          ops = reescribirReferencias(ops, op.tempId, data.id);
        }
        enviadas++;
        guardar(ops);
        continue;
      }

      if (res.status === 401) {
        // Sesión caducada: no tiene sentido seguir, y menos descartar datos.
        interrumpida = true;
        break;
      }

      if (res.status >= 400 && res.status < 500) {
        const data = await res.json().catch(() => ({}));
        const motivo = data.message || `El servidor rechazó la operación (${res.status})`;
        descartadas.update((d) => [...d, { op, motivo }]);
        nDescartadas++;
        ops = ops.slice(1);
        guardar(ops);
        continue;
      }

      // 5xx: puede ser transitorio. Se deja encolada para el próximo intento.
      ops[0] = { ...op, intentos: op.intentos + 1, ultimoError: `HTTP ${res.status}` };
      guardar(ops);
      interrumpida = true;
      break;
    }
  } finally {
    sincronizando.set(false);
  }

  return { enviadas, pendientes: ops.length, descartadas: nDescartadas, interrumpida };
}
