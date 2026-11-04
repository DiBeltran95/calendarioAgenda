import 'dart:math' as math;

import '../../core/dates.dart';
import '../../data/models.dart';
import 'finance_logic.dart';

/// Cómo va el gasto libre frente a lo que tocaba a estas alturas del ciclo.
enum Ritmo { bien, pocoRapido, rapido }

/// De un sueldo al siguiente: cuánto entra, cuánto se va en lo fijo, cuánto se
/// aparta y cuánto queda para el día a día.
class PlanCiclo {
  const PlanCiclo({
    required this.inicio,
    required this.fin,
    required this.hoy,
    required this.conSueldo,
    required this.sueldo,
    required this.extras,
    required this.fijosPagados,
    required this.fijosPendientes,
    required this.ahorroPct,
    required this.gastadoAntesDeHoy,
    required this.gastadoHoy,
    required this.conTarjeta,
  });

  /// Primer y último día del ciclo (yyyy-MM-dd). Con sueldo, [fin] es el día
  /// antes del próximo pago; sin sueldo, el fin del mes.
  final String inicio;
  final String fin;
  final String hoy;

  /// Hay un sueldo mensual o quincenal en el Planificador.
  final bool conSueldo;

  /// Lo que se espera de los ingresos planificados dentro del ciclo.
  final double sueldo;

  /// Ingresos registrados que no vienen del Planificador ni son ganancias.
  final double extras;
  final double fijosPagados;
  final double fijosPendientes;
  final int ahorroPct;
  final double gastadoAntesDeHoy;
  final double gastadoHoy;

  /// Compras con tarjeta de crédito: no salen hoy del bolsillo; sus cuotas
  /// cuentan como fijos en el ciclo en que se cobran.
  final double conTarjeta;

  String get proximoPago => sumarDiasYmd(fin, 1);
  int get diasTotales => diffDias(fin, inicio) + 1;
  int get diasRestantes => diffDias(fin, hoy) + 1;
  int get diasTranscurridos => diffDias(hoy, inicio) + 1;

  double get ingresos => sueldo + extras;
  double get fijos => fijosPagados + fijosPendientes;
  double get ahorro => math.max(0, ingresos) * ahorroPct / 100;

  /// Lo que queda para el día a día. Negativo: lo fijo y el ahorro no caben.
  double get libre => ingresos - fijos - ahorro;
  double get gastadoLibre => gastadoAntesDeHoy + gastadoHoy;

  /// Lo que toca por día desde hoy hasta el pago, repartiendo lo que quedaba al empezar el día.
  double get porDia => math.max(0.0, libre - gastadoAntesDeHoy) / diasRestantes;

  /// Lo que todavía se puede gastar hoy sin quedarse corto antes del pago.
  double get puedesHoy => math.max(0.0, porDia - gastadoHoy);

  /// Lo que tocará por día desde mañana, con lo de hoy ya descontado.
  double get porDiaDesdeManana => diasRestantes <= 1 ? 0 : math.max(0.0, libre - gastadoLibre) / (diasRestantes - 1);

  Ritmo get ritmo {
    // Los primeros días no se juzgan: una compra el día de pago no es ir rápido.
    final esperado = math.max(0.0, libre) * math.min(diasTotales, math.max(diasTranscurridos, 3)) / diasTotales;
    if (gastadoLibre <= esperado) return Ritmo.bien;
    // Al empezar el ciclo un gasto grande pesa mucho: el margen evita alarmar de más.
    if (esperado > 0 && gastadoLibre <= esperado * 1.3) return Ritmo.pocoRapido;
    return Ritmo.rapido;
  }
}

/// Porcentajes que se ofrecen para apartar apenas llega el sueldo.
const porcentajesAhorro = [0, 5, 10, 15, 20, 30];
const ahorroPctPorDefecto = 10;

/// El sueldo que marca el ciclo: el mensual o quincenal activo de mayor monto.
IngresoPlanificado? sueldoPrincipal(List<IngresoPlanificado> planes) {
  IngresoPlanificado? mejor;
  for (final p in planes) {
    if (!p.activo || (p.frecuencia != 'mensual' && p.frecuencia != 'quincenal')) continue;
    if (mejor == null || p.monto > mejor.monto) mejor = p;
  }
  return mejor;
}

/// Meses (año, mes) que toca el rango [inicio, fin].
List<(int, int)> mesesEntre(String inicio, String fin) {
  final a = parseYmd(inicio);
  final b = parseYmd(fin);
  return [
    for (var d = DateTime(a.year, a.month); !d.isAfter(DateTime(b.year, b.month)); d = DateTime(d.year, d.month + 1)) (d.year, d.month),
  ];
}

/// Primer y último día del ciclo que contiene [hoy].
(String, String) cicloDePago(List<IngresoPlanificado> planes, String hoy) {
  final h = parseYmd(hoy);
  final finDeMes = ymd(DateTime(h.year, h.month + 1, 0));
  final principal = sueldoPrincipal(planes);
  if (principal == null) return (ymd(DateTime(h.year, h.month)), finDeMes);
  final fechas = [
    for (var m = -2; m <= 2; m++)
      for (final o in ocurrenciasMes([principal], const [], DateTime(h.year, h.month + m).year, DateTime(h.year, h.month + m).month))
        o.fechaEsperada,
  ]..sort();
  final antes = fechas.lastWhere((f) => f.compareTo(hoy) <= 0, orElse: () => '');
  final despues = fechas.firstWhere((f) => f.compareTo(hoy) > 0, orElse: () => '');
  // El sueldo empieza más adelante: hasta entonces se cuenta por mes.
  if (antes.isEmpty || despues.isEmpty) return (ymd(DateTime(h.year, h.month)), despues.isEmpty ? finDeMes : sumarDiasYmd(despues, -1));
  return (antes, sumarDiasYmd(despues, -1));
}

/// Categorías de cuentas que llegan cada mes, se agenden o no.
const categoriasFijas = {'servicios', 'arriendo', 'alquiler', 'vivienda', 'administracion', 'agua', 'luz', 'energia', 'gas', 'internet', 'celular', 'seguros'};
const _categoriasAhorro = {'ahorro', 'ahorros', 'inversion', 'inversiones'};

String _clave(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// [transacciones] y [eventos] deben cubrir todos los meses del ciclo.
PlanCiclo calcularPlanCiclo({
  required List<IngresoPlanificado> planes,
  required List<Verificacion> verificaciones,
  required List<Cuenta> cuentas,
  required List<Transaccion> transacciones,
  required List<Evento> eventos,
  required String hoy,
  int ahorroPct = ahorroPctPorDefecto,
}) {
  final (inicio, fin) = cicloDePago(planes, hoy);
  bool dentro(String f) => f.compareTo(inicio) >= 0 && f.compareTo(fin) <= 0;

  // Ingresos registrados a mano: ni cobros confirmados en el Planificador ni ganancias.
  final sueltos = [
    for (final t in transacciones)
      if (t.tipo == 'ingreso' && dentro(t.fecha) && t.fecha.compareTo(hoy) <= 0 && t.ingresoPlanificadoId == null && !esGanancia(t)) t,
  ];
  var sueldo = 0.0;
  for (final (anio, mes) in mesesEntre(inicio, fin)) {
    for (final o in ocurrenciasMes(planes, verificaciones, anio, mes)) {
      if (!dentro(o.fechaEsperada)) continue;
      if (o.verificacion != null) {
        sueldo += o.verificacion!.montoReal;
        continue;
      }
      // Quien anota el sueldo a mano en vez de confirmarlo: ese ingreso es el sueldo, no uno extra.
      final i = sueltos.indexWhere((t) => _clave(t.descripcion) == _clave(o.plan.descripcion) || t.monto == o.plan.monto);
      sueldo += i >= 0 ? sueltos.removeAt(i).monto : o.plan.monto;
    }
  }
  final extras = sueltos.fold(0.0, (s, t) => s + t.monto);

  var fijosPagados = 0.0, fijosPendientes = 0.0;
  // Pagar un fijo con una cuenta crea un gasto con el mismo título y monto: ya está en lo fijo.
  final pagosDeFijos = <String, int>{};
  for (final e in eventos) {
    if (e.tipoTransaccion != 'gasto' || e.costo <= 0 || !dentro(e.fecha)) continue;
    if (e.pagado) {
      fijosPagados += e.costo;
      if (e.tarjetaCreditoId == null) pagosDeFijos.update('${_clave(e.titulo)}|${e.costo}', (n) => n + 1, ifAbsent: () => 1);
    } else {
      fijosPendientes += e.costo;
    }
  }

  final tarjetas = {for (final c in cuentas.where((c) => esCredito(c.tipo))) c.id};
  var antesDeHoy = 0.0, deHoy = 0.0, conTarjeta = 0.0;
  for (final t in transacciones) {
    if (t.tipo != 'gasto' || !dentro(t.fecha) || t.fecha.compareTo(hoy) > 0) continue;
    if (tarjetas.contains(t.cuentaId)) {
      conTarjeta += t.monto;
      continue;
    }
    final clave = '${_clave(t.descripcion)}|${t.monto}';
    final pendientes = pagosDeFijos[clave] ?? 0;
    if (pendientes > 0) {
      pagosDeFijos[clave] = pendientes - 1;
      continue;
    }
    // Lo que se manda a ahorrar no es gasto del día a día.
    if (_categoriasAhorro.contains(t.categoria)) continue;
    // Agua, luz o internet son fijos aunque no estén agendados en Eventos.
    if (categoriasFijas.contains(t.categoria)) {
      fijosPagados += t.monto;
      continue;
    }
    if (t.fecha == hoy) {
      deHoy += t.monto;
    } else {
      antesDeHoy += t.monto;
    }
  }

  return PlanCiclo(
    inicio: inicio,
    fin: fin,
    hoy: hoy,
    conSueldo: sueldoPrincipal(planes) != null,
    sueldo: sueldo,
    extras: extras,
    fijosPagados: fijosPagados,
    fijosPendientes: fijosPendientes,
    ahorroPct: ahorroPct,
    gastadoAntesDeHoy: antesDeHoy,
    gastadoHoy: deHoy,
    conTarjeta: conTarjeta,
  );
}
