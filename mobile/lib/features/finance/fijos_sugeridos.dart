import 'dart:math' as math;

import '../../core/dates.dart';
import '../../data/models.dart';
import 'finance_logic.dart';
import 'plan_ciclo.dart';

/// Un pago que llega cada mes y todavía no está agendado en Eventos.
class FijoSugerido {
  const FijoSugerido({required this.titulo, required this.monto, required this.dia, required this.categoriaEvento, required this.proximaFecha});
  final String titulo;
  final double monto;

  /// Día del mes en que se pagó la última vez.
  final int dia;
  final String categoriaEvento;
  final String proximaFecha;

  String get clave => claveTexto(titulo);
}

/// Cuántos se proponen a la vez.
const limiteFijosSugeridos = 3;

/// Lo que se mira hacia atrás para encontrarlos.
const _ventanaDias = 95;

/// Descripciones que escribe el sistema al pagar un evento, una cuota o un ingreso planificado.
final _automatica = RegExp(r'^(abono de deuda|pago|cobro|cobro tarjeta|cuota \d+/\d+)\s*:');

/// Pagos que parecen fijos: los de categorías de cuentas mensuales (servicios,
/// arriendo…) o los que se repiten una vez al mes por un monto parecido.
/// No propone lo ya agendado (mismo título en un evento de gasto) ni lo descartado.
List<FijoSugerido> sugerirFijos({
  required List<Transaccion> transacciones,
  required List<Evento> eventos,
  required List<Cuenta> cuentas,
  required Set<String> descartados,
  required String hoy,
  int limite = limiteFijosSugeridos,
}) {
  final agendados = {for (final e in eventos.where((e) => e.tipoTransaccion == 'gasto')) claveTexto(e.titulo)};
  final tarjetas = {for (final c in cuentas.where((c) => esCredito(c.tipo))) c.id};

  final grupos = <String, List<Transaccion>>{};
  for (final t in transacciones) {
    if (t.tipo != 'gasto' || t.fecha.length != 10 || t.fecha.compareTo(hoy) > 0) continue;
    if (diffDias(hoy, t.fecha) > _ventanaDias || tarjetas.contains(t.cuentaId)) continue;
    final clave = claveTexto(t.descripcion);
    if (clave.isEmpty || _automatica.hasMatch(clave) || agendados.contains(clave) || descartados.contains(clave)) continue;
    (grupos[clave] ??= []).add(t);
  }

  final out = <FijoSugerido>[];
  for (final filas in grupos.values) {
    filas.sort((a, b) => b.fecha.compareTo(a.fecha));
    final ultima = filas.first;
    final porMes = <String, int>{};
    for (final t in filas) {
      porMes.update(t.fecha.substring(0, 7), (n) => n + 1, ifAbsent: () => 1);
    }
    final deCuenta = categoriasFijas.contains(ultima.categoria);
    final mensual = porMes.length >= 2 && porMes.values.every((n) => n == 1) && filas.every((t) => (t.monto - ultima.monto).abs() <= ultima.monto * 0.3);
    if (!deCuenta && !mensual) continue;
    // Una cuenta vista una sola vez hace más de un mes quizá cambió de nombre o ya no llega.
    if (!mensual && diffDias(hoy, ultima.fecha) > 31) continue;
    final dia = int.parse(ultima.fecha.substring(8, 10));
    out.add(FijoSugerido(
      titulo: ultima.descripcion.trim(),
      monto: ultima.monto,
      dia: dia,
      categoriaEvento: switch (ultima.categoria) {
        'arriendo' || 'alquiler' || 'vivienda' || 'administracion' => 'arriendo',
        _ when deCuenta => 'servicios',
        _ => 'general',
      },
      proximaFecha: proximoDiaDelMes(hoy, dia),
    ));
  }
  out.sort((a, b) => b.monto.compareTo(a.monto));
  return out.take(limite).toList();
}

/// La próxima fecha después de [hoy] con ese día del mes (recortado en meses cortos).
String proximoDiaDelMes(String hoy, int dia) {
  final h = parseYmd(hoy);
  DateTime en(int mes) => DateTime(h.year, mes, math.min(dia, diasDelMes(DateTime(h.year, mes).year, DateTime(h.year, mes).month)));
  final esteMes = en(h.month);
  return ymd(esteMes.isAfter(h) ? esteMes : en(h.month + 1));
}
