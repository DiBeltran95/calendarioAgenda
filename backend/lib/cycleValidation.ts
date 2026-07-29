/**
 * Validación de la fecha de inicio de un ciclo menstrual.
 *
 * Vive fuera de server.ts para poder probarse sin levantar el servidor.
 *
 * Importa porque un registro inválido no afecta sólo a su propio día: el motor
 * del calendario deriva las fases y el promedio de las DISTANCIAS entre
 * registros, así que una fecha futura o duplicada corrompe el histórico entero.
 */

/** Devuelve el mensaje de error, o null si la fecha es aceptable. */
export function validarFechaCiclo(fecha_inicio: any, ahora: Date = new Date()): string | null {
    if (typeof fecha_inicio !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(fecha_inicio)) {
        return 'La fecha debe tener el formato YYYY-MM-DD';
    }

    const y = Number(fecha_inicio.slice(0, 4));
    const m = Number(fecha_inicio.slice(5, 7));
    const d = Number(fecha_inicio.slice(8, 10));
    const parsed = new Date(Date.UTC(y, m - 1, d));

    // Descarta fechas sintácticamente válidas pero inexistentes (p. ej. 2026-02-30).
    if (parsed.getUTCFullYear() !== y || parsed.getUTCMonth() !== m - 1 || parsed.getUTCDate() !== d) {
        return 'La fecha no existe en el calendario';
    }

    if (y < 1900) {
        return 'La fecha es demasiado antigua';
    }

    // "Hoy" en Colombia (UTC-5), no en la zona horaria del servidor.
    const hoyCO = new Date(ahora.getTime() - 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
    if (fecha_inicio > hoyCO) {
        return 'No puedes registrar un periodo con fecha futura';
    }

    return null;
}

/** Rango admisible para los días de sangrado de un ciclo. */
export const MIN_DIAS_SANGRADO = 1;
export const MAX_DIAS_SANGRADO = 15;

/**
 * Valida los días de sangrado. Es opcional: null/undefined significa "sin
 * especificar", y el cálculo cae al promedio de la usuaria.
 */
export function validarDiasSangrado(dias: any): string | null {
    if (dias === null || dias === undefined || dias === '') return null;

    const n = Number(dias);
    if (!Number.isInteger(n)) {
        return 'Los días de sangrado deben ser un número entero';
    }
    if (n < MIN_DIAS_SANGRADO || n > MAX_DIAS_SANGRADO) {
        return `Los días de sangrado deben estar entre ${MIN_DIAS_SANGRADO} y ${MAX_DIAS_SANGRADO}`;
    }
    return null;
}

/** Normaliza el valor recibido a un entero o null, para guardarlo en la BD. */
export function normalizarDiasSangrado(dias: any): number | null {
    if (dias === null || dias === undefined || dias === '') return null;
    return Number(dias);
}
