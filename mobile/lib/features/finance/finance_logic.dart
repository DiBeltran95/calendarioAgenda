import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/money.dart';

// ─────────────────────────── Tipos de cuenta ───────────────────────────

class TipoCuenta {
  const TipoCuenta(this.value, this.label, this.icon, this.colors);
  final String value;
  final String label;
  final IconData icon;

  /// Degradado de la tarjeta visual.
  final List<Color> colors;
}

const tiposCuenta = <TipoCuenta>[
  TipoCuenta('ahorros', 'Cuenta de ahorros', Icons.savings_rounded, [Color(0xFF059669), Color(0xFF065F46)]),
  TipoCuenta('corriente', 'Cuenta corriente', Icons.account_balance_rounded, [Color(0xFF2563EB), Color(0xFF1E3A8A)]),
  TipoCuenta('tarjeta_credito', 'Tarjeta de crédito', Icons.credit_card_rounded, [Color(0xFF7C3AED), Color(0xFF3B0764)]),
  TipoCuenta('cdt', 'Inversión / CDT / Cajita', Icons.trending_up_rounded, [Color(0xFFD97706), Color(0xFF78350F)]),
  TipoCuenta('efectivo', 'Efectivo', Icons.payments_rounded, [Color(0xFF0D9488), Color(0xFF134E4A)]),
  TipoCuenta('otro', 'Otro / Ahorros especiales', Icons.work_rounded, [Color(0xFF475569), Color(0xFF1E293B)]),
];

TipoCuenta tipoCuenta(String v) => tiposCuenta.firstWhere((t) => t.value == v, orElse: () => tiposCuenta.last);

bool esCredito(String tipoCuenta) => tipoCuenta == 'tarjeta_credito';

/// Efecto de una transacción en el saldo de su cuenta. En tarjetas de crédito
/// el saldo es DEUDA: un gasto la aumenta y un ingreso (pago) la reduce.
double efectoEnSaldo({required String tipoTx, required String tipoCuenta, required double monto}) {
  final credito = esCredito(tipoCuenta);
  if (tipoTx == 'ingreso') return credito ? -monto : monto;
  return credito ? monto : -monto;
}

// ─────────────────────────── Tarjetas de crédito ───────────────────────────

/// Siguiente fecha de corte en o después de [desde] (día recortado a fin de mes).
DateTime siguienteCorte(DateTime desde, int diaCorte) {
  final corteMismoMes = math.min(diaCorte, diasDelMes(desde.year, desde.month));
  if (desde.day <= corteMismoMes) return DateTime(desde.year, desde.month, corteMismoMes);
  final sig = DateTime(desde.year, desde.month + 1);
  return DateTime(sig.year, sig.month, math.min(diaCorte, diasDelMes(sig.year, sig.month)));
}

/// Fechas y montos de los cobros de una compra con tarjeta (igual que el backend):
/// - con día de corte: primer cobro en el siguiente corte y luego uno por mes;
/// - sin día de corte: un cobro por mes el mismo día de la compra, desde el
///   mes siguiente.
List<(String fecha, double monto)> cobrosTarjeta({required String fechaCompra, required double monto, required int cuotas, int? diaCorte}) {
  final n = math.max(1, cuotas);
  final base = redondear2(monto / n);
  final montos = <double>[];
  var asignado = 0.0;
  for (var i = 1; i <= n; i++) {
    if (i == n) {
      montos.add(redondear2(monto - asignado));
    } else {
      montos.add(base);
      asignado += base;
    }
  }

  final compra = parseYmd(fechaCompra);
  final fechas = <String>[];
  if (diaCorte != null) {
    final primero = siguienteCorte(compra, diaCorte);
    for (var i = 0; i < n; i++) {
      final m = DateTime(primero.year, primero.month + i);
      fechas.add(ymd(DateTime(m.year, m.month, math.min(diaCorte, diasDelMes(m.year, m.month)))));
    }
  } else {
    for (var i = 1; i <= n; i++) {
      fechas.add(ymd(sumarMesesRecortado(compra, i)));
    }
  }
  return [for (var i = 0; i < n; i++) (fechas[i], montos[i])];
}

// ─────────────────────────── CDT / inversiones ───────────────────────────

double rendimientoDiarioCdt(double saldo, double tasaEA) {
  if (tasaEA <= 0 || saldo <= 0) return 0;
  return saldo * (math.pow(1 + tasaEA / 100, 1 / 365) - 1);
}

double rendimientoTotalCdt(double saldo, double tasaEA, int plazoDias) {
  if (tasaEA <= 0 || saldo <= 0 || plazoDias <= 0) return 0;
  return saldo * (math.pow(1 + tasaEA / 100, plazoDias / 365) - 1);
}

String? fechaVencimiento(Cuenta c) {
  if (c.fechaInicio == null || c.plazoDias <= 0) return null;
  return sumarDiasYmd(c.fechaInicio!, c.plazoDias);
}

int diasRestantesCdt(Cuenta c, {String? hoy}) {
  final v = fechaVencimiento(c);
  if (v == null) return 0;
  return math.max(0, diffDias(v, hoy ?? hoyYmd()));
}

double progresoCdt(Cuenta c, {String? hoy}) {
  if (c.fechaInicio == null || c.plazoDias <= 0) return 0;
  final transcurrido = diffDias(hoy ?? hoyYmd(), c.fechaInicio!);
  return (transcurrido / c.plazoDias).clamp(0, 1).toDouble();
}

/// Saldo proyectado de un CDT en una fecha futura (interés compuesto diario,
/// detenido en el vencimiento si lo hay).
double saldoProyectado(Cuenta c, String fecha, {String? hoy}) {
  final today = hoy ?? hoyYmd();
  if (c.tipo != 'cdt' || fecha.compareTo(today) <= 0) return c.saldo;
  var dias = diffDias(fecha, today);
  final v = fechaVencimiento(c);
  if (v != null) dias = math.min(dias, math.max(0, diffDias(v, today)));
  if (dias <= 0) return c.saldo;
  return c.saldo * math.pow(1 + c.interesTasa / 100, dias / 365);
}

// ─────────────────────────── Ingresos planificados ───────────────────────────

const frecuenciasIngreso = <(String, String)>[
  ('diario', 'Diario'),
  ('semanal', 'Semanal'),
  ('quincenal', 'Quincenal (cada 15 días)'),
  ('mensual', 'Mensual'),
  ('unica', 'Única vez'),
];

String frecuenciaIngresoLabel(String v) =>
    frecuenciasIngreso.firstWhere((f) => f.$1 == v, orElse: () => ('', v)).$2;

class OcurrenciaIngreso {
  const OcurrenciaIngreso({required this.plan, required this.fechaEsperada, this.verificacion});
  final IngresoPlanificado plan;
  final String fechaEsperada;
  final Verificacion? verificacion;
  bool get verificado => verificacion != null;
}

/// Ocurrencias de los ingresos planificados dentro de un mes.
///
/// A diferencia de la web (que avanzaba paso a paso con un tope de 100
/// iteraciones y dejaba de mostrar planes diarios antiguos), aquí se salta
/// directamente al mes pedido.
List<OcurrenciaIngreso> ocurrenciasMes(
  List<IngresoPlanificado> planes,
  List<Verificacion> verificaciones,
  int anio,
  int mes,
) {
  final inicioMes = DateTime(anio, mes, 1);
  final finMes = DateTime(anio, mes + 1, 0);
  final out = <OcurrenciaIngreso>[];

  Verificacion? verif(int planId, String f) {
    for (final v in verificaciones) {
      if (v.ingresoPlanificadoId == planId && v.fechaEsperada == f) return v;
    }
    return null;
  }

  for (final p in planes) {
    if (!p.activo) continue;
    final inicio = parseYmd(p.fechaInicio);
    if (inicio.isAfter(finMes)) continue;
    final fechas = <DateTime>[];
    switch (p.frecuencia) {
      case 'unica':
        if (!inicio.isBefore(inicioMes)) fechas.add(inicio);
      case 'mensual':
        final k0 = math.max(0, (anio - inicio.year) * 12 + (mes - inicio.month));
        final d = sumarMesesRecortado(inicio, k0);
        if (!d.isBefore(inicioMes) && !d.isAfter(finMes)) fechas.add(d);
      default:
        final paso = switch (p.frecuencia) { 'diario' => 1, 'semanal' => 7, _ => 15 };
        final desde = DateTime.utc(inicioMes.year, inicioMes.month, inicioMes.day);
        final ini = DateTime.utc(inicio.year, inicio.month, inicio.day);
        var k = math.max(0, (desde.difference(ini).inDays / paso).ceil());
        while (true) {
          final d = DateTime(inicio.year, inicio.month, inicio.day + k * paso);
          if (d.isAfter(finMes)) break;
          if (!d.isBefore(inicioMes)) fechas.add(d);
          k++;
        }
    }
    for (final d in fechas) {
      final f = ymd(d);
      out.add(OcurrenciaIngreso(plan: p, fechaEsperada: f, verificacion: verif(p.id, f)));
    }
  }
  out.sort((a, b) => a.fechaEsperada.compareTo(b.fechaEsperada));
  return out;
}

// ─────────────────────────── Presupuesto ───────────────────────────

enum EstadoPresupuesto { sinLimite, ok, alerta, excedido }

class EstadoCategoria {
  const EstadoCategoria({required this.gastado, required this.limite, required this.estado, this.presupuesto, this.heredado = false});
  final double gastado;
  final double limite;
  final EstadoPresupuesto estado;
  final Presupuesto? presupuesto;

  /// true si el límite viene de un mes anterior (se arrastra hasta cambiarlo).
  final bool heredado;
  double get pct => limite > 0 ? gastado / limite : 0;
}

/// Límite vigente de cada categoría para un mes: el del propio mes o, si no
/// hay, el más reciente anterior (mejora: no hay que re-crearlos cada mes).
Map<String, (Presupuesto, bool heredado)> presupuestosVigentes(List<Presupuesto> todos, int anio, int mes) {
  final clave = anio * 12 + mes;
  final out = <String, (Presupuesto, bool)>{};
  final ordenados = [...todos]..sort((a, b) => (a.anio * 12 + a.mes).compareTo(b.anio * 12 + b.mes));
  for (final p in ordenados) {
    final k = p.anio * 12 + p.mes;
    if (k <= clave) out[p.categoria] = (p, k != clave);
  }
  return out;
}

EstadoCategoria estadoCategoria(String categoria, Map<String, (Presupuesto, bool)> vigentes, List<Transaccion> txMes) {
  final gastado = txMes.where((t) => t.tipo == 'gasto' && t.categoria == categoria).fold<double>(0, (s, t) => s + t.monto);
  final v = vigentes[categoria];
  if (v == null) return EstadoCategoria(gastado: gastado, limite: 0, estado: EstadoPresupuesto.sinLimite);
  final limite = v.$1.montoLimite;
  final pct = limite > 0 ? gastado / limite : 0;
  final estado = pct >= 1
      ? EstadoPresupuesto.excedido
      : pct >= 0.8
          ? EstadoPresupuesto.alerta
          : EstadoPresupuesto.ok;
  return EstadoCategoria(gastado: gastado, limite: limite, estado: estado, presupuesto: v.$1, heredado: v.$2);
}

// ─────────────────────────── Regla 50/30/20 ───────────────────────────

const _necesidades = {
  'comida', 'mercado', 'transporte', 'servicios', 'salud', 'medicina', 'medicamentos',
  'educacion', 'arriendo', 'alquiler', 'vivienda', 'hogar', 'home', 'agua', 'luz',
  'gas', 'internet', 'electricidad', 'transporte_publico', 'gasolina',
};
const _ahorro = {'ahorro', 'ahorros', 'inversion', 'inversiones'};

enum Bloque { necesidades, deseos, ahorro }

Bloque clasificar503020(String categoria) {
  final s = categoria.toLowerCase();
  if (_ahorro.contains(s)) return Bloque.ahorro;
  if (_necesidades.contains(s)) return Bloque.necesidades;
  return Bloque.deseos;
}

enum Semaforo { ok, alerta, mal }

class Regla503020 {
  const Regla503020({
    required this.ingresos,
    required this.necesidades,
    required this.deseos,
    required this.ahorro,
  });

  final double ingresos;
  final double necesidades;
  final double deseos;

  /// Lo que no se gasta en necesidades ni deseos (incluye aportes a ahorro).
  final double ahorro;

  bool get hayDatos => ingresos > 0;
  double _pct(double v) => ingresos > 0 ? v / ingresos * 100 : 0;
  double get pctNecesidades => _pct(necesidades);
  double get pctDeseos => _pct(deseos);
  double get pctAhorro => _pct(ahorro);

  Semaforo get estadoNecesidades => pctNecesidades <= 50 ? Semaforo.ok : pctNecesidades <= 60 ? Semaforo.alerta : Semaforo.mal;
  Semaforo get estadoDeseos => pctDeseos <= 30 ? Semaforo.ok : pctDeseos <= 40 ? Semaforo.alerta : Semaforo.mal;
  Semaforo get estadoAhorro => pctAhorro >= 20 ? Semaforo.ok : pctAhorro >= 10 ? Semaforo.alerta : Semaforo.mal;

  String get diagnostico {
    if (ahorro < 0) {
      return 'Tus gastos superan tus ingresos este mes. Prioriza reducir los "deseos" y revisa si alguna "necesidad" se puede optimizar.';
    }
    if (estadoAhorro == Semaforo.ok && estadoNecesidades == Semaforo.ok) {
      return '¡Excelente equilibrio! Estás cumpliendo la regla 50/30/20. Mantén este ritmo y considera invertir tu ahorro.';
    }
    if (estadoAhorro == Semaforo.mal) {
      return 'Tu ahorro está por debajo del 20% recomendado. Intenta recortar gastos en "deseos" para fortalecer tu colchón financiero.';
    }
    if (estadoNecesidades == Semaforo.mal) {
      return 'Tus necesidades consumen más del 60% de tus ingresos. Esto deja poco margen; evalúa gastos fijos como vivienda o servicios.';
    }
    return 'Vas por buen camino. Pequeños ajustes en "deseos" te acercarán al ahorro ideal del 20%.';
  }
}

Regla503020 calcular503020(List<Transaccion> txMes) {
  var ingresos = 0.0, necesidades = 0.0, deseos = 0.0;
  for (final t in txMes) {
    if (t.tipo == 'ingreso') {
      ingresos += t.monto;
      continue;
    }
    switch (clasificar503020(t.categoria)) {
      case Bloque.necesidades:
        necesidades += t.monto;
      case Bloque.deseos:
        deseos += t.monto;
      case Bloque.ahorro:
        break; // el aporte a ahorro queda dentro del bloque de ahorro
    }
  }
  return Regla503020(ingresos: ingresos, necesidades: necesidades, deseos: deseos, ahorro: ingresos - necesidades - deseos);
}

// ─────────────────────────── Experto económico ───────────────────────────

enum TipoConsejo { exito, info, alerta, peligro }

class Consejo {
  const Consejo(this.tipo, this.icon, this.titulo, this.texto);
  final TipoConsejo tipo;
  final IconData icon;
  final String titulo;
  final String texto;
}

class ResumenFinanciero {
  ResumenFinanciero({required this.cuentas, required this.txMes});
  final List<Cuenta> cuentas;
  final List<Transaccion> txMes;

  late final double ahorros = cuentas
      .where((c) => c.tipo == 'ahorros' || c.tipo == 'efectivo' || c.tipo == 'cdt' || c.tipo == 'corriente' || c.tipo == 'otro')
      .fold(0.0, (s, c) => s + c.saldo);
  late final double deudaTarjetas = cuentas.where((c) => esCredito(c.tipo)).fold(0.0, (s, c) => s + c.saldo);
  late final double cupoTarjetas = cuentas.where((c) => esCredito(c.tipo)).fold(0.0, (s, c) => s + c.limite);
  late final double usoCredito = cupoTarjetas > 0 ? deudaTarjetas / cupoTarjetas * 100 : 0;
  late final double patrimonio = ahorros - deudaTarjetas;
  late final double ingresosMes = txMes.where((t) => t.tipo == 'ingreso').fold(0.0, (s, t) => s + t.monto);
  late final double gastosMes = txMes.where((t) => t.tipo == 'gasto').fold(0.0, (s, t) => s + t.monto);
  late final double balanceMes = ingresosMes - gastosMes;
  late final double tasaAhorro = ingresosMes > 0 ? (ingresosMes - gastosMes) / ingresosMes * 100 : 0;

  late final Map<String, double> gastosPorCategoria = () {
    final m = <String, double>{};
    for (final t in txMes.where((t) => t.tipo == 'gasto')) {
      m[t.categoria] = (m[t.categoria] ?? 0) + t.monto;
    }
    return m;
  }();

  List<Consejo> consejos(String Function(String categoria) nombreCategoria) {
    final out = <Consejo>[];
    if (ingresosMes > 0) {
      final r = tasaAhorro.toStringAsFixed(1);
      if (tasaAhorro < 0) {
        out.add(Consejo(TipoConsejo.peligro, Icons.trending_down_rounded, 'Presupuesto deficitario',
            '¡Cuidado! Este mes tus gastos superan tus ingresos por ${cop(balanceMes.abs())}. Estás en una tasa de ahorro de $r%. Revisa tus gastos de inmediato.'));
      } else if (tasaAhorro < 10) {
        out.add(Consejo(TipoConsejo.alerta, Icons.warning_amber_rounded, 'Ahorro insuficiente',
            'Estás ahorrando solo el $r% de tus ingresos. Los expertos recomiendan destinar al menos el 20% al ahorro/inversión (regla 50/30/20). Intenta recortar deseos.'));
      } else if (tasaAhorro < 20) {
        out.add(Consejo(TipoConsejo.info, Icons.trending_up_rounded, 'Buen ritmo de ahorro',
            'Tu tasa de ahorro mensual es de $r%. ¡Sigue así! Intenta automatizar este dinero apenas llegue a tu cuenta para no tentarte a gastarlo.'));
      } else {
        out.add(Consejo(TipoConsejo.exito, Icons.stars_rounded, 'Excelente nivel de ahorro',
            '¡Felicidades! Estás ahorrando el $r% de tus ingresos. Esto es excelente para construir riqueza. Considera poner una parte a rentar en un CDT o fondos de inversión.'));
      }
    } else {
      out.add(const Consejo(TipoConsejo.info, Icons.info_outline_rounded, 'Registra tus transacciones',
          'Registra tus ingresos y gastos para que el experto económico analice tu tasa de ahorro y te brinde recomendaciones inteligentes.'));
    }

    if (cupoTarjetas > 0) {
      final u = usoCredito.toStringAsFixed(1);
      if (usoCredito > 50) {
        out.add(Consejo(TipoConsejo.peligro, Icons.credit_card_off_rounded, 'Alto endeudamiento en tarjetas',
            'Estás usando el $u% de tu cupo disponible en tarjetas de crédito. Esto puede afectar tu score financiero. Paga la totalidad a una cuota.'));
      } else if (usoCredito > 30) {
        out.add(Consejo(TipoConsejo.alerta, Icons.credit_card_rounded, 'Uso de tarjeta medio',
            'Has ocupado el $u% de tu límite en tarjetas. Trata de mantenerlo por debajo del 30% para optimizar tu historial de crédito.'));
      } else {
        out.add(Consejo(TipoConsejo.exito, Icons.credit_score_rounded, 'Uso de tarjeta ideal',
            'Uso de tarjetas óptimo ($u%). Estás utilizando el crédito de manera responsable y sin comprometer tus finanzas.'));
      }
    }

    if (gastosPorCategoria.isNotEmpty) {
      final top = gastosPorCategoria.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final nombre = nombreCategoria(top.key);
      out.add(Consejo(TipoConsejo.info, Icons.pie_chart_outline_rounded, 'Mayor gasto: $nombre',
          'Tu mayor egreso del mes es en "$nombre" por un valor de ${cop(top.value)}. ¿Se puede optimizar?'));
    }

    final tieneCdt = cuentas.any((c) => c.tipo == 'cdt');
    if (ahorros > 1000000 && !tieneCdt) {
      out.add(Consejo(TipoConsejo.info, Icons.account_balance_rounded, 'Haz crecer tu dinero',
          'Tienes ahorros por ${cop(ahorros)}. Puedes rentabilizar una parte abriendo un CDT de 90 o 180 días con bajo riesgo.'));
    }
    return out;
  }
}

/// Consejo corto para el resumen de un día concreto.
String consejoDelDia(double ingresos, double gastos) {
  if (gastos == 0 && ingresos == 0) {
    return 'No hay movimientos este día. Mantener días libres de gastos es ideal para tu salud financiera.';
  }
  if (gastos > ingresos) {
    return 'Este día tus egresos superan tus ingresos. Limita las compras de impulso y compensa en los próximos días con cero gastos.';
  }
  return '¡Fantástico! Recibiste un ingreso. Es el momento perfecto para destinar una parte directamente al ahorro o a tus metas.';
}

// ─────────────────────────── Categorías ───────────────────────────

/// "Comida Rápida" → "comida_rapida" (igual que el slug del backend).
String slugCategoria(String label) {
  const acentos = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  var s = label.trim().toLowerCase();
  acentos.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return s.length > 50 ? s.substring(0, 50) : s;
}

/// Colores por categoría para las gráficas (base + paleta para personalizadas).
const coloresCategoriaBase = <String, Color>{
  'comida': Color(0xFFFF7043),
  'transporte': Color(0xFF29B6F6),
  'servicios': Color(0xFFAB47BC),
  'entretenimiento': Color(0xFFFFCA28),
  'salud': Color(0xFF26A69A),
  'educacion': Color(0xFFEC407A),
  'ahorro': Color(0xFF66BB6A),
  'arriendo': Color(0xFF8D6E63),
  'otros': Color(0xFF78909C),
};

const _coloresExtra = [
  Color(0xFFF06292), Color(0xFF4DD0E1), Color(0xFFAED581), Color(0xFFFFB74D),
  Color(0xFFCE93D8), Color(0xFF80DEEA), Color(0xFFFFCC02), Color(0xFFA5D6A7),
];

Color colorCategoria(String valor) {
  final base = coloresCategoriaBase[valor];
  if (base != null) return base;
  final h = valor.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
  return _coloresExtra[h % _coloresExtra.length];
}

// ─────────────────────────── Analítica ───────────────────────────

enum RangoAnalitica {
  d7('7D', 7),
  d30('30D', 30),
  m3('3M', 90),
  m6('6M', 180),
  a1('1A', 365);

  const RangoAnalitica(this.label, this.dias);
  final String label;
  final int dias;
}

class PuntoSerie {
  const PuntoSerie(this.fecha, this.valor);
  final String fecha;
  final double valor;
}

class BarraMes {
  const BarraMes(this.mes, this.ingresos, this.gastos);
  final String mes; // YYYY-MM
  final double ingresos;
  final double gastos;
}

class Analitica {
  Analitica({required this.cuentas, required this.transacciones, required this.rango, String? hoy}) {
    final today = hoy ?? hoyYmd();
    fin = today;
    inicio = sumarDiasYmd(today, -(rango.dias - 1));
    enRango = transacciones.where((t) => t.fecha.compareTo(inicio) >= 0 && t.fecha.compareTo(fin) <= 0).toList();
  }

  final List<Cuenta> cuentas;

  /// Todas las transacciones desde (hoy - rango) — también se usan para
  /// reconstruir el patrimonio hacia atrás.
  final List<Transaccion> transacciones;
  final RangoAnalitica rango;
  late final String inicio;
  late final String fin;
  late final List<Transaccion> enRango;

  late final double ingresos = enRango.where((t) => t.tipo == 'ingreso').fold(0.0, (s, t) => s + t.monto);
  late final double gastos = enRango.where((t) => t.tipo == 'gasto').fold(0.0, (s, t) => s + t.monto);
  double get neto => ingresos - gastos;
  double get tasaAhorro => ingresos > 0 ? (ingresos - gastos) / ingresos * 100 : 0;
  double get gastoDiario => gastos / rango.dias;

  /// Patrimonio neto día a día, reconstruido hacia atrás desde los saldos actuales.
  late final List<PuntoSerie> patrimonio = () {
    var bal = cuentas.fold<double>(0, (s, c) => s + (esCredito(c.tipo) ? -c.saldo : c.saldo));
    final porDia = <String, List<Transaccion>>{};
    for (final t in transacciones) {
      (porDia[t.fecha] ??= []).add(t);
    }
    final puntos = <PuntoSerie>[];
    for (var i = 0; i < rango.dias; i++) {
      final f = sumarDiasYmd(fin, -i);
      puntos.add(PuntoSerie(f, bal));
      for (final t in porDia[f] ?? const <Transaccion>[]) {
        if (t.tipo == 'ingreso') {
          bal -= t.monto;
        } else {
          bal += t.monto;
        }
      }
    }
    return puntos.reversed.toList();
  }();

  late final List<BarraMes> porMes = () {
    final m = <String, (double, double)>{};
    for (final t in enRango) {
      final k = t.fecha.substring(0, 7);
      final (i, g) = m[k] ?? (0.0, 0.0);
      m[k] = t.tipo == 'ingreso' ? (i + t.monto, g) : (i, g + t.monto);
    }
    final keys = m.keys.toList()..sort();
    return [for (final k in keys) BarraMes(k, m[k]!.$1, m[k]!.$2)];
  }();

  /// Flujo diario de los últimos (máx.) 30 días.
  late final List<(String, double, double)> flujoDiario = () {
    final n = math.min(rango.dias, 30);
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final f = sumarDiasYmd(fin, -i);
          var inc = 0.0, exp = 0.0;
          for (final t in enRango) {
            if (t.fecha != f) continue;
            if (t.tipo == 'ingreso') {
              inc += t.monto;
            } else {
              exp += t.monto;
            }
          }
          return (f, inc, exp);
        }(),
    ];
  }();

  late final List<MapEntry<String, double>> gastosPorCategoria = () {
    final m = <String, double>{};
    for (final t in enRango.where((t) => t.tipo == 'gasto')) {
      m[t.categoria] = (m[t.categoria] ?? 0) + t.monto;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }();

  late final List<Transaccion> topGastos =
      (enRango.where((t) => t.tipo == 'gasto').toList()..sort((a, b) => b.monto.compareTo(a.monto))).take(8).toList();

  late final List<MapEntry<String, double>> ingresosPorCuenta = () {
    final m = <String, double>{};
    for (final t in enRango.where((t) => t.tipo == 'ingreso')) {
      final nombre = cuentas.where((c) => c.id == t.cuentaId).map((c) => c.nombre).firstOrNull ?? 'Sin cuenta';
      m[nombre] = (m[nombre] ?? 0) + t.monto;
    }
    return m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }();
}
