// Motor del ciclo menstrual — port fiel de `cycleUtils.ts` de la web.
//
// Modelo:
//  - Cada registro es el DÍA 1 de un ciclo.
//  - Entre dos registros consecutivos la duración es un hecho observado: se usa
//    tal cual para situar la ovulación (14 días antes del siguiente sangrado).
//  - Tras el último registro se PROYECTA con el promedio de los ciclos
//    recientes, y solo dos ciclos hacia adelante: más allá la predicción no
//    tiene valor y pintarla engaña.

import 'dart:math' as math;

import '../../core/dates.dart';

/// Solo se promedian ciclos en este rango; fuera son anomalías o errores.
const minCicloValido = 20;
const maxCicloValido = 45;

/// Ciclos recientes que entran en el promedio (ventana móvil).
const ventanaCiclos = 6;

/// Ciclos que se proyectan tras el último registro.
const maxCiclosProyectados = 2;

const cicloEstandar = 28;
const cicloMinimo = 15;

/// Rango admisible de días de sangrado.
const minSangrado = 1;
const maxSangrado = 15;

enum Fase {
  periodo('Menstruación'),
  periodoPrevisto('Periodo previsto'),
  periodoRetrasado('Periodo con retraso'),
  ovulacion('Ovulación'),
  fertil('Ventana fértil'),
  folicular('Fase folicular'),
  lutea('Fase lútea');

  const Fase(this.nombre);
  final String nombre;

  bool get esSangrado => this == periodo || this == periodoPrevisto || this == periodoRetrasado;
}

/// Registro mínimo que necesita el motor (desacoplado de la tabla Drift).
class RegistroCiclo {
  const RegistroCiclo({required this.fechaInicio, this.id, this.diasSangrado, this.observacion = ''});

  final int? id;
  final String fechaInicio;
  final int? diasSangrado;
  final String observacion;
}

class CycleStats {
  const CycleStats({
    required this.logs,
    required this.avgCycleLength,
    required this.ciclosUsados,
    required this.avgPeriodLength,
    required this.sangradosUsados,
  });

  /// De más reciente a más antiguo.
  final List<RegistroCiclo> logs;
  final int avgCycleLength;
  final int ciclosUsados;
  final int avgPeriodLength;
  final int sangradosUsados;

  bool get vacio => logs.isEmpty;
}

/// Días de sangrado registrados o null si el dato no es utilizable.
int? sangradoRegistrado(int? v) {
  if (v == null) return null;
  if (v < minSangrado || v > maxSangrado) return null;
  return v;
}

final _reFecha = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Prepara los registros y calcula los promedios UNA sola vez (el calendario
/// consulta ~42 celdas por mes; recalcular en cada una sería O(n²)).
CycleStats buildCycleStats(Iterable<RegistroCiclo> registros, {int cycleLength = cicloEstandar, int periodLength = 5}) {
  final logs = registros.where((l) => _reFecha.hasMatch(l.fechaInicio)).toList()
    ..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));

  var avgCycle = cycleLength;
  var usados = 0;
  if (logs.length >= 2) {
    final pares = math.min(logs.length - 1, ventanaCiclos);
    var total = 0;
    for (var i = 0; i < pares; i++) {
      final dias = diffDias(logs[i].fechaInicio, logs[i + 1].fechaInicio);
      if (dias >= minCicloValido && dias <= maxCicloValido) {
        total += dias;
        usados++;
      }
    }
    if (usados > 0) {
      var promedio = total / usados;
      // Con menos de 3 ciclos la muestra es pobre: se pondera con el estándar.
      if (usados < 3) promedio = (total + (3 - usados) * cicloEstandar) / 3;
      avgCycle = promedio.round();
    }
  }

  var avgPeriod = periodLength;
  var sangrados = 0;
  var totalSangrado = 0;
  for (final l in logs.take(ventanaCiclos + 1)) {
    final d = sangradoRegistrado(l.diasSangrado);
    if (d != null) {
      totalSangrado += d;
      sangrados++;
    }
  }
  if (sangrados > 0) avgPeriod = (totalSangrado / sangrados).round();

  return CycleStats(
    logs: List.unmodifiable(logs),
    avgCycleLength: math.max(avgCycle, cicloMinimo),
    ciclosUsados: usados,
    avgPeriodLength: avgPeriod,
    sangradosUsados: sangrados,
  );
}

class CycleDetails {
  const CycleDetails({
    required this.fase,
    required this.descripcion,
    required this.probabilidad,
    required this.diaDelCiclo,
    required this.proximoPeriodoEn,
    required this.diasRetraso,
    required this.progreso,
    required this.duracionCiclo,
    required this.esCicloObservado,
    required this.diasSangrado,
    required this.sangradoEstimado,
    required this.inicioCiclo,
    required this.diaOvulacion,
    required this.logId,
  });

  final Fase fase;
  final String descripcion;

  /// Probabilidad de embarazo: Baja · Media-Baja · Alta · Máxima.
  final String probabilidad;
  final int diaDelCiclo;
  final int proximoPeriodoEn;
  final int diasRetraso;

  /// 0..1
  final double progreso;
  final int duracionCiclo;
  final bool esCicloObservado;
  final int diasSangrado;
  final bool sangradoEstimado;

  /// Inicio (real o proyectado) del ciclo al que pertenece el día.
  final String inicioCiclo;
  final int diaOvulacion;

  /// Id del registro si el día consultado es exactamente un día 1.
  final int? logId;
}

// ─────────────── Consejos por fase (idénticos a la web) ───────────────

const _tipsMenstruacion = [
  'Día 1: Tu cuerpo está trabajando intensamente hoy. Si experimentas cólicos, no te exijas al 100%. Date el permiso de ir a tu propio ritmo, tomar algo caliente y priorizar lo más urgente en tu día.',
  'Día 2: Es normal sentir un bajón de energía hoy. Trata de incluir en tus comidas hierro extra (como espinacas, lentejas o carne) para compensar la pérdida y evitar el cansancio extremo.',
  'Día 3: La pesadez suele empezar a disminuir. Hoy puede ser un buen momento para una caminata corta y respirar profundo. Tu intuición está muy conectada, escúchala.',
  'Día 4: Vas recuperando la energía poco a poco. Puedes retomar algunas tareas que habías pospuesto. Recuerda mantenerte muy bien hidratada.',
  'Día 5: Tu mente comienza a sentirse más despejada y ligera. Si haces ejercicio, puedes subir levemente la intensidad. ¡Celebra este nuevo aire!',
  'Día 6+: Tu periodo está terminando o ha terminado. Empiezas a sentirte lista para la acción. Aprovecha para organizar tus metas para las próximas semanas.',
];

const _tipsFolicular = [
  'A medida que sube tu estrógeno, notarás un impulso en tu estado de ánimo. Hoy es un día ideal para planificar proyectos nuevos y ser creativa.',
  'Te sientes más resiliente y social. Si tienes una reunión importante, una presentación o quieres salir, tu carisma natural jugará a tu favor.',
  'Estás en una fase de alta productividad. Aprovecha tu concentración para sacar adelante tareas complejas o aprender algo nuevo.',
  'Tu piel luce mejor y tienes más resistencia física. Es un gran día para entrenamientos de fuerza o actividades que te reten un poco más.',
];

const _tipsFertil = [
  'Inicia tu ventana fértil. Tu libido puede empezar a subir naturalmente y tus sentidos se agudizan. Disfruta de esta conexión con tu cuerpo.',
  'Estás brillando. Biológicamente tu cuerpo te prepara para la ovulación, dándote un magnetismo especial. Si no deseas embarazo, maximiza tus precauciones.',
  'Tienes gran fluidez verbal y facilidad para conectar con otras personas. Hoy eres un imán natural, excelente para el trabajo en equipo o ventas.',
  'Tu nivel de energía está cerca del máximo. Físicamente te sientes fuerte, por lo que puedes disfrutar de actividades intensas o aventureras.',
  'Pico estrogénico a la vista. Confía en tu intuición y agilidad mental hoy; tu cerebro está trabajando a toda velocidad.',
  'Estás a un paso de la ovulación. Es normal notar mayor flujo cervical. Te sientes plena, segura y capaz de cualquier cosa.',
];

const _tipOvulacion =
    '¡Día de ovulación! Estás en la cima de tu ciclo. Tu confianza, energía vital y sociabilidad están al máximo. Aprovecha para brillar en cualquier ámbito, pero cuídate si tu objetivo no es concebir.';

const _tipsLutea = [
  'La ovulación ha pasado y empiezas una transición. Es momento de enfocar tu energía hacia adentro. Ideal para trabajos detallados y de escritorio.',
  'Tu metabolismo está ligeramente acelerado, pero también pueden surgir antojos. Mantén snacks saludables a la mano, como nueces o fruta oscura.',
  'Si empiezas a sentir que tu paciencia disminuye, recuerda que es normal por el aumento de progesterona. Respira y no te tomes todo personal.',
  'Es un buen momento para ordenar tu espacio, organizar tu casa o tu oficina. El cuerpo busca el "nido" y el orden te dará paz mental.',
  'Si notas tensión emocional o sensibilidad (SPM), reduce la cafeína y la sal. Un baño caliente y un libro pueden ser tu mejor medicina hoy.',
];

String _pick(List<String> arr, int index) {
  if (arr.isEmpty) return '';
  final i = ((index % arr.length) + arr.length) % arr.length;
  return arr[i];
}

/// Datos del ciclo para un día. null si el día es anterior al primer registro
/// o cae más allá del horizonte de proyección.
CycleDetails? getCycleDetails(String fecha, CycleStats stats, {String? hoy}) {
  final logs = stats.logs;
  if (logs.isEmpty) return null;
  final today = hoy ?? hoyYmd();

  var currentIndex = -1;
  for (var i = 0; i < logs.length; i++) {
    if (logs[i].fechaInicio.compareTo(fecha) <= 0) {
      currentIndex = i;
      break;
    }
  }
  if (currentIndex == -1) return null;

  final current = logs[currentIndex];
  final next = currentIndex > 0 ? logs[currentIndex - 1] : null;
  final dayOfCycle = diffDias(fecha, current.fechaInicio) + 1;
  final logId = current.fechaInicio == fecha ? current.id : null;

  final periodo = sangradoRegistrado(current.diasSangrado) ?? stats.avgPeriodLength;
  final periodoEstimado = sangradoRegistrado(current.diasSangrado) == null;

  Fase fase;
  int dia;
  int cicloRef;
  bool observado;
  var retraso = 0;
  var inicioEsperado = current.fechaInicio;

  Fase clasificar(int d, int ovu, int sangrado) {
    if (d <= sangrado) return Fase.periodo;
    if (d == ovu) return Fase.ovulacion;
    if (d >= ovu - 5 && d <= ovu + 1) return Fase.fertil;
    if (d < ovu - 5) return Fase.folicular;
    return Fase.lutea;
  }

  if (next != null) {
    // Ciclo cerrado: su duración es un hecho.
    observado = true;
    cicloRef = math.max(diffDias(next.fechaInicio, current.fechaInicio), 1);
    dia = dayOfCycle;
    fase = clasificar(dia, cicloRef - 14, math.min(periodo, cicloRef));
  } else {
    // Último registro: ciclo en curso + proyecciones.
    cicloRef = stats.avgCycleLength;
    final cicloIndex = (dayOfCycle - 1) ~/ cicloRef;
    if (cicloIndex > maxCiclosProyectados) return null;

    observado = cicloIndex == 0;
    dia = ((dayOfCycle - 1) % cicloRef) + 1;
    inicioEsperado = sumarDiasYmd(current.fechaInicio, cicloIndex * cicloRef);
    final sangradoAqui = cicloIndex == 0 ? periodo : stats.avgPeriodLength;

    fase = clasificar(dia, cicloRef - 14, sangradoAqui);
    if (fase == Fase.periodo && cicloIndex > 0) {
      if (inicioEsperado.compareTo(today) <= 0) {
        // Se esperaba en una fecha que ya pasó y no se registró: retraso.
        fase = Fase.periodoRetrasado;
        retraso = diffDias(today, inicioEsperado);
      } else {
        fase = Fase.periodoPrevisto;
      }
    }
  }

  final ovu = cicloRef - 14;
  String descripcion;
  String probabilidad;
  switch (fase) {
    case Fase.periodo:
      probabilidad = 'Baja';
      descripcion = _tipsMenstruacion[math.min(dia - 1, _tipsMenstruacion.length - 1)];
      if (periodoEstimado) {
        descripcion += ' (Duración estimada en $periodo días: edita este ciclo para indicar cuántos días te duró realmente.)';
      }
    case Fase.periodoPrevisto:
      probabilidad = 'Baja';
      final base = stats.ciclosUsados > 0 ? 'tus ${stats.ciclosUsados} ciclo(s) más recientes' : 'datos por defecto';
      descripcion =
          'Estimación basada en $base ($cicloRef días). Es una predicción: al registrar tu próximo periodo el calendario se recalcula solo.';
    case Fase.periodoRetrasado:
      probabilidad = 'Baja';
      descripcion =
          'Tu periodo se esperaba el ${fechaLarga(inicioEsperado)} y aún no lo has registrado ($retraso día(s) de retraso). El estrés, los cambios de rutina o las alteraciones hormonales son causas comunes. Si ya empezó, regístralo para recalcular el ciclo.';
    case Fase.ovulacion:
      probabilidad = 'Máxima';
      descripcion = _tipOvulacion;
    case Fase.fertil:
      probabilidad = 'Alta';
      descripcion = _pick(_tipsFertil, dia - (ovu - 5));
    case Fase.folicular:
      probabilidad = 'Media-Baja';
      descripcion = _pick(_tipsFolicular, dia - periodo - 1);
    case Fase.lutea:
      probabilidad = 'Baja';
      descripcion = _pick(_tipsLutea, dia - ovu - 1);
  }

  return CycleDetails(
    fase: fase,
    descripcion: descripcion,
    probabilidad: probabilidad,
    diaDelCiclo: dia,
    proximoPeriodoEn: math.max(0, cicloRef - dia + 1),
    diasRetraso: retraso,
    progreso: math.min(dia / cicloRef, 1.0),
    duracionCiclo: cicloRef,
    esCicloObservado: observado,
    diasSangrado: periodo,
    sangradoEstimado: periodoEstimado,
    inicioCiclo: inicioEsperado,
    diaOvulacion: ovu,
    logId: logId,
  );
}

class CicloHistorial {
  const CicloHistorial({
    required this.registro,
    required this.duracion,
    required this.enCurso,
    required this.anomalo,
    required this.diasSangrado,
  });

  final RegistroCiclo registro;

  /// null en el ciclo en curso.
  final int? duracion;
  final bool enCurso;
  final bool anomalo;
  final int? diasSangrado;
}

/// Histórico con la duración de cada ciclo cerrado.
List<CicloHistorial> getCycleHistory(CycleStats stats) {
  final logs = stats.logs;
  return [
    for (var i = 0; i < logs.length; i++)
      () {
        final duracion = i > 0 ? diffDias(logs[i - 1].fechaInicio, logs[i].fechaInicio) : null;
        return CicloHistorial(
          registro: logs[i],
          duracion: duracion,
          enCurso: i == 0,
          anomalo: duracion != null && (duracion < minCicloValido || duracion > maxCicloValido),
          diasSangrado: sangradoRegistrado(logs[i].diasSangrado),
        );
      }(),
  ];
}

/// Validación de la fecha de un nuevo periodo (igual que el backend).
String? validarFechaCiclo(String fecha, {String? hoy}) {
  if (!_reFecha.hasMatch(fecha)) return 'La fecha debe tener el formato AAAA-MM-DD';
  final d = parseYmd(fecha);
  if (ymd(d) != fecha) return 'La fecha no existe en el calendario';
  if (d.year < 1900) return 'La fecha es demasiado antigua';
  if (fecha.compareTo(hoy ?? hoyYmd()) > 0) return 'No puedes registrar un periodo con fecha futura';
  return null;
}

/// Próximas fechas clave a partir de hoy: siguiente periodo, ventana fértil y
/// ovulación del ciclo en curso o del siguiente proyectado.
class Pronostico {
  const Pronostico({this.proximoPeriodo, this.ovulacion, this.fertilDesde, this.fertilHasta});
  final String? proximoPeriodo;
  final String? ovulacion;
  final String? fertilDesde;
  final String? fertilHasta;
}

Pronostico pronostico(CycleStats stats, {String? hoy}) {
  if (stats.logs.isEmpty) return const Pronostico();
  final today = hoy ?? hoyYmd();
  final ultimo = stats.logs.first.fechaInicio;
  final ciclo = stats.avgCycleLength;
  // Inicio del ciclo proyectado que contiene "hoy" (o el último si es futuro).
  var inicio = ultimo;
  while (sumarDiasYmd(inicio, ciclo).compareTo(today) <= 0) {
    inicio = sumarDiasYmd(inicio, ciclo);
    if (diffDias(inicio, ultimo) > ciclo * (maxCiclosProyectados + 1)) break;
  }
  var ovu = sumarDiasYmd(inicio, ciclo - 14 - 1);
  if (ovu.compareTo(today) < 0) ovu = sumarDiasYmd(ovu, ciclo);
  return Pronostico(
    proximoPeriodo: sumarDiasYmd(inicio, ciclo),
    ovulacion: ovu,
    fertilDesde: sumarDiasYmd(ovu, -5),
    fertilHasta: sumarDiasYmd(ovu, 1),
  );
}
