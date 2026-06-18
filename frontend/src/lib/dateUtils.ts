/** Fecha local YYYY-MM-DD (sin desfase UTC). */
export function getTodayLocal(date: Date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Normaliza fechas de la API a YYYY-MM-DD.
 * Acepta "2025-06-12" o ISO con hora; en el segundo caso usa componentes locales.
 */
export function toDateOnly(value: string | Date | null | undefined): string {
  if (value == null || value === '') return '';

  if (typeof value === 'string') {
    if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;

    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) {
      return getTodayLocal(date);
    }

    return value.slice(0, 10);
  }

  return getTodayLocal(value);
}
