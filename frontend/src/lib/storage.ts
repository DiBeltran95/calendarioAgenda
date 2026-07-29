// Caché local de los datos del servidor.
//
// Es lo que permite que la app muestre el calendario, las finanzas, las notas,
// los hábitos y el ciclo sin conexión. Se escribe cada vez que el backend
// responde y se lee al arrancar, antes (y en lugar) de la red.
//
// Se usa localStorage y no IndexedDB a propósito: el volumen es pequeño (una
// agenda personal), el acceso síncrono simplifica el pintado inicial, y ya era
// el mecanismo que usaba el Dashboard. Lo que sí se añade es control de cuota:
// cuando se llena, se van descartando los meses más antiguos en vez de fallar.

const PREFIJO = 'cache_';
const VERSION = 'v2';

function clave(nombre: string): string {
  return `${PREFIJO}${VERSION}_${nombre}`;
}

/** El usuario puede no estar resuelto todavía; el caché se aísla igual. */
type IdUsuario = number | string | null | undefined;

function norm(userId: IdUsuario): string {
  return userId === null || userId === undefined ? 'anon' : String(userId);
}

export function claveGlobal(userId: IdUsuario): string {
  return clave(`global_${norm(userId)}`);
}

export function claveMes(userId: IdUsuario, anio: number, mes: number): string {
  return clave(`month_${norm(userId)}_${anio}-${mes}`);
}

export function claveAnio(userId: IdUsuario, recurso: string, anio: number): string {
  return clave(`${recurso}_${norm(userId)}_${anio}`);
}

export function leerCache<T = any>(key: string): T | null {
  try {
    const raw = localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

export function escribirCache(key: string, data: any): void {
  try {
    localStorage.setItem(key, JSON.stringify(data));
  } catch {
    // Cuota llena: liberamos los meses más antiguos y reintentamos una vez.
    // Nunca se descarta la clave que se está escribiendo ni los datos globales.
    if (liberarEspacio(key)) {
      try {
        localStorage.setItem(key, JSON.stringify(data));
      } catch {
        /* sigue sin caber: se pierde el caché de esa clave, no la app */
      }
    }
  }
}

export function borrarCache(key: string): void {
  try {
    localStorage.removeItem(key);
  } catch {
    /* ignorar */
  }
}

/**
 * Descarta la mitad más antigua de los meses cacheados.
 *
 * Los meses llevan la fecha en la propia clave (`..._2026-7`), así que se puede
 * ordenar sin leer el contenido. Devuelve true si liberó algo.
 */
function liberarEspacio(claveProtegida: string): boolean {
  const meses: string[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (!k || k === claveProtegida) continue;
    if (k.startsWith(`${PREFIJO}${VERSION}_month_`)) meses.push(k);
  }
  if (meses.length === 0) return false;

  const orden = (k: string) => {
    const m = k.match(/_(\d{4})-(\d{1,2})$/);
    return m ? Number(m[1]) * 12 + Number(m[2]) : 0;
  };
  meses.sort((a, b) => orden(a) - orden(b));

  const aBorrar = Math.max(1, Math.floor(meses.length / 2));
  for (let i = 0; i < aBorrar; i++) borrarCache(meses[i]);
  return true;
}

/** Limpia todo el caché del usuario. Se usa al cerrar sesión. */
export function limpiarCache(userId?: IdUsuario): void {
  const aBorrar: string[] = [];
  for (let i = 0; i < localStorage.length; i++) {
    const k = localStorage.key(i);
    if (!k || !k.startsWith(PREFIJO)) continue;
    if (userId === undefined || k.includes(`_${norm(userId)}`)) aBorrar.push(k);
  }
  aBorrar.forEach(borrarCache);
}

/** true si hay datos cacheados suficientes para arrancar sin red. */
export function hayCacheUtilizable(userId: IdUsuario): boolean {
  return leerCache(claveGlobal(userId)) !== null;
}
