// Estado de conectividad de la app.
//
// `navigator.onLine` sólo sabe si hay interfaz de red levantada: en un móvil con
// wifi conectado pero sin salida a internet devuelve `true`. Por eso el estado
// real se corrige con lo que de verdad pasa al llamar al backend: cualquier
// fallo de red marca offline, y cualquier respuesta marca online.

import { writable, derived, get } from 'svelte/store';
import { API_BASE_URL } from './config';

/** true cuando el backend es alcanzable. */
export const isOnline = writable<boolean>(
  typeof navigator === 'undefined' ? true : navigator.onLine !== false
);

/** Momento de la última respuesta correcta del backend (ms epoch), o null. */
export const lastSyncAt = writable<number | null>(null);

export const estadoConexion = derived(isOnline, ($on) => ($on ? 'online' : 'offline'));

let comprobando = false;

/** Marca offline. Lo llama la capa de API cuando un fetch falla por red. */
export function marcarOffline() {
  if (get(isOnline)) isOnline.set(false);
}

/** Marca online. Lo llama la capa de API cuando el backend responde. */
export function marcarOnline() {
  if (!get(isOnline)) isOnline.set(true);
  lastSyncAt.set(Date.now());
}

/**
 * Comprueba de verdad si el backend responde.
 *
 * Se usa al arrancar y al recibir el evento `online` del sistema, que se dispara
 * en cuanto hay wifi aunque todavía no haya salida a internet.
 */
export async function comprobarConexion(timeoutMs = 5000): Promise<boolean> {
  if (comprobando) return get(isOnline);
  comprobando = true;
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    const res = await fetch(`${API_BASE_URL}/api/health`, {
      signal: ctrl.signal,
      cache: 'no-store'
    });
    clearTimeout(t);
    if (res.ok) {
      marcarOnline();
      return true;
    }
    marcarOffline();
    return false;
  } catch {
    marcarOffline();
    return false;
  } finally {
    comprobando = false;
  }
}

let iniciado = false;

/** Engancha los eventos del sistema. Idempotente. */
export function iniciarMonitorDeRed(alRecuperarConexion?: () => void) {
  if (iniciado || typeof window === 'undefined') return;
  iniciado = true;

  window.addEventListener('online', async () => {
    // El evento sólo dice que hay interfaz; hay que confirmar salida real.
    const ok = await comprobarConexion();
    if (ok && alRecuperarConexion) alRecuperarConexion();
  });

  window.addEventListener('offline', () => marcarOffline());

  // Al volver del segundo plano (muy común en móvil) el estado puede haber
  // cambiado sin que se disparase ningún evento.
  document.addEventListener('visibilitychange', async () => {
    if (document.visibilityState === 'visible') {
      const ok = await comprobarConexion();
      if (ok && alRecuperarConexion) alRecuperarConexion();
    }
  });

  comprobarConexion().then((ok) => {
    if (ok && alRecuperarConexion) alRecuperarConexion();
  });
}
