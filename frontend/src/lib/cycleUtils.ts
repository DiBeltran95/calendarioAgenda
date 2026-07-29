// Cálculo del ciclo menstrual.
//
// Fuente única de verdad: `getCycleDetails`. Todo lo que el calendario pinta y
// todo lo que el panel lateral muestra sale de aquí.
//
// Modelo:
//  - Cada registro del usuario es el DÍA 1 de un ciclo.
//  - Entre dos registros consecutivos la duración es un hecho observado, no una
//    estimación: se usa tal cual para situar la ovulación (14 días antes del
//    siguiente sangrado).
//  - Después del último registro ya no hay dato, así que se PROYECTA usando el
//    promedio de los ciclos recientes. La proyección se corta a dos ciclos:
//    más allá de eso la predicción no tiene valor clínico y pintarla engaña.

import { getTodayLocal, toDateOnly } from './dateUtils';

/** Sólo se promedian ciclos dentro de este rango; fuera son anomalías o errores. */
const MIN_CICLO_VALIDO = 20;
const MAX_CICLO_VALIDO = 45;

/** Cuántos ciclos recientes entran en el promedio (ventana móvil). */
const VENTANA_CICLOS = 6;

/** Cuántos ciclos se proyectan hacia adelante tras el último registro. */
const MAX_CICLOS_PROYECTADOS = 2;

/** Duración de referencia cuando el usuario aún no tiene histórico suficiente. */
const CICLO_ESTANDAR = 28;

/** Piso defensivo: evita módulos y divisiones por valores absurdos. */
const CICLO_MINIMO = 15;

/** Rango admisible de días de sangrado (debe coincidir con el backend). */
export const MIN_SANGRADO = 1;
export const MAX_SANGRADO = 15;

export type PhaseKey =
  | 'period'
  | 'predicted-period'
  | 'late-period'
  | 'ovulation'
  | 'fertile'
  | 'follicular'
  | 'luteal';

export interface CycleLog {
  id?: number;
  fecha_inicio: string;
  observacion?: string;
  /** Días de sangrado de ESE ciclo. null = sin especificar. */
  dias_sangrado?: number | null;
}

export interface CycleStats {
  /** Registros normalizados a YYYY-MM-DD y ordenados de más reciente a más antiguo. */
  logs: Array<CycleLog & { fecha_inicio: string }>;
  /** Duración estimada del ciclo a partir de la ventana móvil. */
  avgCycleLength: number;
  /** Número de ciclos reales usados para el promedio (0 = sólo el estándar). */
  ciclosUsados: number;
  /** Días de sangrado promedio; se usa cuando un ciclo no lo tiene registrado. */
  avgPeriodLength: number;
  /** Cuántos registros aportaron días de sangrado al promedio. */
  sangradosUsados: number;
  periodLength: number;
}

const MS_DIA = 1000 * 60 * 60 * 24;

/** Convierte YYYY-MM-DD a medianoche local (evita el desfase UTC). */
function parseLocal(dateStr: string): Date {
  const [y, m, d] = dateStr.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function diffDias(a: Date, b: Date): number {
  return Math.round((a.getTime() - b.getTime()) / MS_DIA);
}

function sumarDias(dateStr: string, dias: number): string {
  const d = parseLocal(dateStr);
  d.setDate(d.getDate() + dias);
  return getTodayLocal(d);
}

/**
 * Prepara los registros y calcula la duración media UNA sola vez.
 *
 * El calendario pinta ~42 celdas por mes; recalcular el promedio en cada celda
 * era O(n²) sobre el histórico completo. Ahora se calcula aquí y se reutiliza.
 */
export function buildCycleStats(
  cycleLogs: CycleLog[] | null | undefined,
  cycleLength = CICLO_ESTANDAR,
  periodLength = 5
): CycleStats {
  const logs = (cycleLogs || [])
    .filter((l) => l && l.fecha_inicio)
    .map((l) => ({ ...l, fecha_inicio: toDateOnly(l.fecha_inicio) }))
    .filter((l) => /^\d{4}-\d{2}-\d{2}$/.test(l.fecha_inicio))
    .sort((a, b) => (a.fecha_inicio < b.fecha_inicio ? 1 : a.fecha_inicio > b.fecha_inicio ? -1 : 0));

  let avgCycleLength = cycleLength;
  let ciclosUsados = 0;

  if (logs.length >= 2) {
    // Ventana móvil: sólo los ciclos más recientes. Un ciclo anómalo de hace
    // dos años no debe seguir arrastrando la predicción de este mes.
    const pares = Math.min(logs.length - 1, VENTANA_CICLOS);
    let totalDays = 0;
    for (let i = 0; i < pares; i++) {
      const dias = diffDias(parseLocal(logs[i].fecha_inicio), parseLocal(logs[i + 1].fecha_inicio));
      if (dias >= MIN_CICLO_VALIDO && dias <= MAX_CICLO_VALIDO) {
        totalDays += dias;
        ciclosUsados++;
      }
    }
    if (ciclosUsados > 0) {
      let average = totalDays / ciclosUsados;
      // Con menos de 3 ciclos observados la muestra es pobre: se completa con
      // el estándar de 28 días para que la predicción no dé bandazos.
      if (ciclosUsados < 3) {
        average = (totalDays + (3 - ciclosUsados) * CICLO_ESTANDAR) / 3;
      }
      avgCycleLength = Math.round(average);
    }
  }

  // Días de sangrado promedio, sobre la misma ventana de ciclos recientes.
  // Sirve de valor por defecto para los ciclos que no lo tengan registrado.
  let avgPeriodLength = periodLength;
  let sangradosUsados = 0;
  {
    let total = 0;
    for (const log of logs.slice(0, VENTANA_CICLOS + 1)) {
      const d = sangradoRegistrado(log.dias_sangrado);
      if (d !== null) {
        total += d;
        sangradosUsados++;
      }
    }
    if (sangradosUsados > 0) avgPeriodLength = Math.round(total / sangradosUsados);
  }

  return {
    logs,
    avgCycleLength: Math.max(avgCycleLength, CICLO_MINIMO),
    ciclosUsados,
    avgPeriodLength,
    sangradosUsados,
    periodLength
  };
}

/**
 * Días de sangrado registrados en un ciclo, o null si no hay dato utilizable.
 *
 * Ojo con `Number(null)`, que devuelve 0 (finito): hay que descartar null y
 * cadena vacía ANTES de convertir, o un ciclo sin dato pasaría por registrado.
 */
export function sangradoRegistrado(valor: unknown): number | null {
  if (valor === null || valor === undefined || valor === '') return null;
  const d = Number(valor);
  if (!Number.isFinite(d) || d < MIN_SANGRADO || d > MAX_SANGRADO) return null;
  return d;
}

/** Días de sangrado efectivos de un ciclo: el registrado, o el promedio. */
function sangradoDe(log: CycleLog | null, stats: CycleStats): number {
  return sangradoRegistrado(log?.dias_sangrado) ?? stats.avgPeriodLength;
}

function esStats(v: any): v is CycleStats {
  return v && !Array.isArray(v) && Array.isArray(v.logs) && typeof v.avgCycleLength === 'number';
}

// --- Consejos por fase ---

const tipsMenstruation = [
  'Día 1: Tu cuerpo está trabajando intensamente hoy. Si experimentas cólicos, no te exijas al 100%. Date el permiso de ir a tu propio ritmo, tomar algo caliente y priorizar lo más urgente en tu día.',
  'Día 2: Es normal sentir un bajón de energía hoy. Trata de incluir en tus comidas hierro extra (como espinacas, lentejas o carne) para compensar la pérdida y evitar el cansancio extremo.',
  'Día 3: La pesadez suele empezar a disminuir. Hoy puede ser un buen momento para una caminata corta y respirar profundo. Tu intuición está muy conectada, escúchala.',
  'Día 4: Vas recuperando la energía poco a poco. Puedes retomar algunas tareas que habías pospuesto. Recuerda mantenerte muy bien hidratada.',
  'Día 5: Tu mente comienza a sentirse más despejada y ligera. Si haces ejercicio, puedes subir levemente la intensidad. ¡Celebra este nuevo aire!',
  'Día 6+: Tu periodo está terminando o ha terminado. Empiezas a sentirte lista para la acción. Aprovecha para organizar tus metas para las próximas semanas.'
];

const tipsFollicular = [
  'A medida que sube tu estrógeno, notarás un impulso en tu estado de ánimo. Hoy es un día ideal para planificar proyectos nuevos y ser creativa.',
  'Te sientes más resiliente y social. Si tienes una reunión importante, una presentación o quieres salir, tu carisma natural jugará a tu favor.',
  'Estás en una fase de alta productividad. Aprovecha tu concentración para sacar adelante tareas complejas o aprender algo nuevo.',
  'Tu piel luce mejor y tienes más resistencia física. Es un gran día para entrenamientos de fuerza o actividades que te reten un poco más.'
];

const tipsFertile = [
  'Inicia tu ventana fértil. Tu libido puede empezar a subir naturalmente y tus sentidos se agudizan. Disfruta de esta conexión con tu cuerpo.',
  'Estás brillando. Biológicamente tu cuerpo te prepara para la ovulación, dándote un magnetismo especial. Si no deseas embarazo, maximiza tus precauciones.',
  'Tienes gran fluidez verbal y facilidad para conectar con otras personas. Hoy eres un imán natural, excelente para el trabajo en equipo o ventas.',
  'Tu nivel de energía está cerca del máximo. Físicamente te sientes fuerte, por lo que puedes disfrutar de actividades intensas o aventureras.',
  'Pico estrogénico a la vista. Confía en tu intuición y agilidad mental hoy; tu cerebro está trabajando a toda velocidad.',
  'Estás a un paso de la ovulación. Es normal notar mayor flujo cervical. Te sientes plena, segura y capaz de cualquier cosa.'
];

const tipOvulation =
  '¡Día de ovulación! Estás en la cima de tu ciclo. Tu confianza, energía vital y sociabilidad están al máximo. Aprovecha para brillar en cualquier ámbito, pero cuídate si tu objetivo no es concebir.';

const tipsLuteal = [
  'La ovulación ha pasado y empiezas una transición. Es momento de enfocar tu energía hacia adentro. Ideal para trabajos detallados y de escritorio.',
  'Tu metabolismo está ligeramente acelerado, pero también pueden surgir antojos. Mantén snacks saludables a la mano, como nueces o fruta oscura.',
  'Si empiezas a sentir que tu paciencia disminuye, recuerda que es normal por el aumento de progesterona. Respira y no te tomes todo personal.',
  'Es un buen momento para ordenar tu espacio, organizar tu casa o tu oficina. El cuerpo busca el "nido" y el orden te dará paz mental.',
  'Si notas tensión emocional o sensibilidad (SPM), reduce la cafeína y la sal. Un baño caliente y un libro pueden ser tu mejor medicina hoy.'
];

function pick(arr: string[], index: number): string {
  if (arr.length === 0) return '';
  const i = ((Math.floor(index) % arr.length) + arr.length) % arr.length;
  return arr[i];
}

export interface CycleDetails {
  phaseKey: PhaseKey;
  phase: string;
  description: string;
  fertilityChance: string;
  fertilityColor: string;
  dayInCurrentCycle: number;
  nextPeriodIn: number;
  /** Días de retraso respecto a la fecha esperada (0 si no hay retraso). */
  diasRetraso: number;
  progressPercent: number;
  dateTitle: string;
  actualCycleLength: number;
  /** true si la duración del ciclo viene de un registro real; false si es estimación. */
  esCicloObservado: boolean;
  /** Días de sangrado aplicados a este ciclo. */
  diasSangrado: number;
  /** true si esos días son el promedio y no un dato que la usuaria registró. */
  sangradoEstimado: boolean;
  /** Id del registro cuando el día consultado es exactamente un día 1. */
  logId: number | null;
}

/**
 * Datos del ciclo para un día concreto.
 *
 * Acepta el array de registros o —preferible en bucles— un `CycleStats` ya
 * construido con `buildCycleStats`.
 *
 * Devuelve `null` si el día es anterior al primer registro o si cae más allá
 * del horizonte de proyección: en ambos casos no hay nada honesto que mostrar.
 */
export function getCycleDetails(
  dateStr: string,
  source: CycleLog[] | CycleStats | null | undefined,
  cycleLength = CICLO_ESTANDAR,
  periodLength = 5
): CycleDetails | null {
  const stats = esStats(source) ? source : buildCycleStats(source as CycleLog[], cycleLength, periodLength);
  const { logs, avgCycleLength } = stats;

  if (logs.length === 0) return null;

  // Registro vigente para la fecha consultada y el inmediatamente posterior.
  let currentIndex = -1;
  for (let i = 0; i < logs.length; i++) {
    if (logs[i].fecha_inicio <= dateStr) {
      currentIndex = i;
      break;
    }
  }
  if (currentIndex === -1) return null; // anterior al primer registro

  const currentLog = logs[currentIndex];
  const nextLog = currentIndex > 0 ? logs[currentIndex - 1] : null;

  const startDate = parseLocal(currentLog.fecha_inicio);
  const dayOfCycle = diffDias(parseLocal(dateStr), startDate) + 1;

  const hoy = getTodayLocal();
  const logId = currentLog.fecha_inicio === dateStr ? currentLog.id ?? null : null;

  // Días de sangrado de ESTE ciclo (los registrados, o el promedio si no los hay).
  const periodo = sangradoDe(currentLog, stats);
  const periodoEstimado = sangradoRegistrado(currentLog.dias_sangrado) === null;

  let phaseKey: PhaseKey;
  let dayInCurrentCycle: number;
  let cicloRef: number;
  let esCicloObservado: boolean;
  let diasRetraso = 0;
  let inicioEsperado = currentLog.fecha_inicio;

  if (nextLog) {
    // --- Ciclo cerrado: la duración es un hecho, no una predicción ---
    esCicloObservado = true;
    cicloRef = Math.max(diffDias(parseLocal(nextLog.fecha_inicio), startDate), 1);
    dayInCurrentCycle = dayOfCycle;

    const periodoEfectivo = Math.min(periodo, cicloRef);
    const ovulationDay = cicloRef - 14;

    if (dayInCurrentCycle <= periodoEfectivo) phaseKey = 'period';
    else if (dayInCurrentCycle === ovulationDay) phaseKey = 'ovulation';
    else if (dayInCurrentCycle >= ovulationDay - 5 && dayInCurrentCycle <= ovulationDay + 1) phaseKey = 'fertile';
    else if (dayInCurrentCycle < ovulationDay - 5) phaseKey = 'follicular';
    else phaseKey = 'luteal';
  } else {
    // --- Último registro: ciclo en curso y proyecciones ---
    cicloRef = avgCycleLength;
    // Ciclo 0 = el real en curso. 1 y 2 = proyecciones.
    const cicloIndex = Math.floor((dayOfCycle - 1) / cicloRef);
    if (cicloIndex > MAX_CICLOS_PROYECTADOS) return null; // horizonte agotado

    esCicloObservado = cicloIndex === 0;
    dayInCurrentCycle = ((dayOfCycle - 1) % cicloRef) + 1;
    inicioEsperado = sumarDias(currentLog.fecha_inicio, cicloIndex * cicloRef);

    const ovulationDay = cicloRef - 14;

    // En una proyección no hay ciclo registrado: se usa el sangrado promedio.
    const periodoAqui = cicloIndex === 0 ? periodo : stats.avgPeriodLength;

    if (dayInCurrentCycle <= periodoAqui) {
      if (cicloIndex === 0) {
        // Sangrado real del ciclo registrado.
        phaseKey = 'period';
      } else if (inicioEsperado <= hoy) {
        // El periodo se esperaba en una fecha que ya pasó y no se registró:
        // eso es un retraso, no una predicción.
        phaseKey = 'late-period';
        diasRetraso = diffDias(parseLocal(hoy), parseLocal(inicioEsperado));
      } else {
        phaseKey = 'predicted-period';
      }
    } else if (dayInCurrentCycle === ovulationDay) phaseKey = 'ovulation';
    else if (dayInCurrentCycle >= ovulationDay - 5 && dayInCurrentCycle <= ovulationDay + 1) phaseKey = 'fertile';
    else if (dayInCurrentCycle < ovulationDay - 5) phaseKey = 'follicular';
    else phaseKey = 'luteal';
  }

  const ovulationDay = cicloRef - 14;

  let phase: string;
  let fertilityChance: string;
  let fertilityColor: string;
  let description: string;

  switch (phaseKey) {
    case 'period':
      phase = 'Menstruación';
      fertilityChance = 'Baja';
      fertilityColor = '#03a9f4';
      description = tipsMenstruation[Math.min(dayInCurrentCycle - 1, tipsMenstruation.length - 1)];
      if (periodoEstimado) {
        description += ` (Duración estimada en ${periodo} días: edita este ciclo para indicar cuántos días te duró realmente.)`;
      }
      break;
    case 'predicted-period':
      phase = 'Periodo Previsto';
      fertilityChance = 'Baja';
      fertilityColor = '#03a9f4';
      description = `Estimación basada en tus ${stats.ciclosUsados > 0 ? `${stats.ciclosUsados} ciclo(s) más recientes` : 'datos por defecto'} (${cicloRef} días). Es una predicción: al registrar tu próximo periodo el calendario se recalcula solo.`;
      break;
    case 'late-period':
      phase = 'Periodo con Retraso';
      fertilityChance = 'Baja';
      fertilityColor = '#ff5252';
      description = `Tu periodo se esperaba el ${inicioEsperado} y aún no lo has registrado (${diasRetraso} día(s) de retraso). El estrés, los cambios de rutina o las alteraciones hormonales son causas comunes. Si ya empezó, regístralo con doble click para recalcular el ciclo.`;
      break;
    case 'ovulation':
      phase = 'Ovulación';
      fertilityChance = 'Máxima';
      fertilityColor = '#e91e63';
      description = tipOvulation;
      break;
    case 'fertile':
      phase = 'Ventana Fértil';
      fertilityChance = 'Alta';
      fertilityColor = '#ff9800';
      description = pick(tipsFertile, dayInCurrentCycle - (ovulationDay - 5));
      break;
    case 'follicular':
      phase = 'Fase Folicular';
      fertilityChance = 'Media-Baja';
      fertilityColor = '#29b6f6';
      description = pick(tipsFollicular, dayInCurrentCycle - periodo - 1);
      break;
    default:
      phase = 'Fase Lútea';
      fertilityChance = 'Baja';
      fertilityColor = '#03a9f4';
      description = pick(tipsLuteal, dayInCurrentCycle - ovulationDay - 1);
      break;
  }

  const nextPeriodIn = Math.max(0, cicloRef - dayInCurrentCycle + 1);
  const progressPercent = Math.min((dayInCurrentCycle / cicloRef) * 100, 100);
  const dateTitle =
    dateStr === hoy
      ? `Hoy es el Día ${dayInCurrentCycle} del Ciclo`
      : `El ${dateStr} (Día ${dayInCurrentCycle} del Ciclo)`;

  return {
    phaseKey,
    phase,
    description,
    fertilityChance,
    fertilityColor,
    dayInCurrentCycle,
    nextPeriodIn,
    diasRetraso,
    progressPercent,
    dateTitle,
    actualCycleLength: cicloRef,
    esCicloObservado,
    diasSangrado: periodo,
    sangradoEstimado: periodoEstimado,
    logId
  };
}

/**
 * Resumen del histórico para el panel de gestión: duración de cada ciclo
 * cerrado y estado del que está en curso.
 */
export function getCycleHistory(
  cycleLogs: CycleLog[] | null | undefined,
  cycleLength = CICLO_ESTANDAR
): Array<CycleLog & { fecha_inicio: string; duracion: number | null; enCurso: boolean; anomalo: boolean; diasSangrado: number | null }> {
  const { logs } = buildCycleStats(cycleLogs, cycleLength);
  return logs.map((log, i) => {
    const anterior = i > 0 ? logs[i - 1] : null; // logs va de reciente a antiguo
    const duracion = anterior
      ? diffDias(parseLocal(anterior.fecha_inicio), parseLocal(log.fecha_inicio))
      : null;
    return {
      ...log,
      duracion,
      diasSangrado: sangradoRegistrado(log.dias_sangrado),
      enCurso: i === 0,
      anomalo: duracion !== null && (duracion < MIN_CICLO_VALIDO || duracion > MAX_CICLO_VALIDO)
    };
  });
}
