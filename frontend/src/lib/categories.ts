/**
 * Categorías de evento compartidas por el Dashboard (selector del modal) y el
 * Calendar (icono que se pinta en la casilla del día). Al estar en un solo
 * sitio, agregar una categoría nueva la habilita en los dos lados a la vez.
 */
export interface EventCategory {
  value: string;
  label: string;
  icon: string;
}

export const EVENT_CATEGORIES: EventCategory[] = [
  { value: 'reunion', label: 'Reunión', icon: 'groups' },
  { value: 'cumpleanos', label: 'Cumpleaños', icon: 'cake' },
  { value: 'moto', label: 'Moto', icon: 'two_wheeler' },
  { value: 'carro', label: 'Carro', icon: 'directions_car' },
  { value: 'casa', label: 'Casa', icon: 'home' },
  { value: 'arriendo', label: 'Arriendo', icon: 'real_estate_agent' },
  { value: 'aceite_moto', label: 'Aceite (Moto)', icon: 'water_drop' },
  { value: 'mecanica', label: 'Mecánica', icon: 'handyman' },
  { value: 'servicios', label: 'Servicios', icon: 'receipt_long' },
  { value: 'doctor', label: 'Doctor', icon: 'local_hospital' },
  { value: 'medicamentos', label: 'Medicamentos', icon: 'medication' },
  { value: 'dentista', label: 'Dentista', icon: 'health_and_safety' },
  { value: 'cita_amor', label: 'Cita amor', icon: 'favorite' },
  { value: 'aniversario', label: 'Aniversario', icon: 'celebration' },
  { value: 'matrimonio', label: 'Matrimonio', icon: 'diversity_1' },
  { value: 'mesiversario', label: 'Mesiversario', icon: 'favorite_border' }
];

/** Icono Material de una categoría ('event' si no está en la lista). */
export function categoryIcon(value: string | null | undefined): string {
  return EVENT_CATEGORIES.find(c => c.value === value)?.icon || 'event';
}

/** Etiqueta legible de una categoría (el propio valor si no está en la lista). */
export function categoryLabel(value: string | null | undefined): string {
  return EVENT_CATEGORIES.find(c => c.value === value)?.label || (value || 'General');
}

/** Frecuencias que hacen que un evento se repita todos los años. */
export function esAnual(frecuencia: string | null | undefined): boolean {
  return frecuencia === 'anual';
}

/** Texto legible de la frecuencia de repetición. */
const FRECUENCIAS: Record<string, string> = {
  unica: 'Única',
  diaria: 'Diaria',
  quincenal: 'Quincenal',
  mensual: 'Mensual',
  trimestral: 'Trimestral',
  semestral: 'Semestral',
  anual: 'Anual'
};

export function frecuenciaLabel(value: string | null | undefined): string {
  return FRECUENCIAS[value || 'unica'] || 'Única';
}
