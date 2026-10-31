import '../../../core/dates.dart';
import '../../../core/net/json.dart';

/// Por debajo de esto ya no hay nada que cobrar (redondeos de cada día).
const _casiCero = 1.0;

class MovimientoPrestamo {
  const MovimientoPrestamo({required this.id, required this.tipo, required this.capital, this.interes = 0, required this.fecha, this.cuentaId, this.cuentaNombre, this.nota = ''});

  factory MovimientoPrestamo.fromJson(Map<String, dynamic> m) => MovimientoPrestamo(
        id: asInt(m['id']),
        tipo: asString(m['tipo']),
        capital: asDouble(m['capital']),
        interes: asDouble(m['interes']),
        fecha: asString(m['fecha']),
        cuentaId: asIntOrNull(m['cuenta_id']),
        cuentaNombre: m['cuenta_nombre'] == null ? null : asString(m['cuenta_nombre']),
        nota: asString(m['nota']),
      );

  final int id;

  /// desembolso · abono
  final String tipo;
  final double capital;
  final double interes;
  final String fecha;
  final int? cuentaId;
  final String? cuentaNombre;
  final String nota;

  bool get esDesembolso => tipo == 'desembolso';
  double get total => capital + interes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo,
        'capital': capital,
        'interes': interes,
        'fecha': fecha,
        'cuenta_id': cuentaId,
        'cuenta_nombre': cuentaNombre,
        'nota': nota,
      };
}

class Prestamo {
  Prestamo({
    required this.id,
    required this.persona,
    this.tasaMensual = 0,
    this.interesDesde,
    this.vencimiento,
    this.cerradoEn,
    this.nota = '',
    this.interesCausado = 0,
    required List<MovimientoPrestamo> movimientos,
  }) : movimientos = [...movimientos]..sort((a, b) {
            final f = a.fecha.compareTo(b.fecha);
            return f != 0 ? f : a.id.compareTo(b.id);
          });

  factory Prestamo.fromJson(Map<String, dynamic> m) => Prestamo(
        id: asInt(m['id']),
        persona: asString(m['persona']),
        tasaMensual: asDouble(m['tasa_mensual']),
        interesDesde: asFechaOrNull(m['interes_desde']),
        vencimiento: asFechaOrNull(m['vencimiento']),
        cerradoEn: asFechaOrNull(m['cerrado_en']),
        nota: asString(m['nota']),
        interesCausado: asDouble(m['interes_causado']),
        movimientos: parseList(m['movimientos'], MovimientoPrestamo.fromJson),
      );

  final int id;
  final String persona;

  /// Interés simple al mes, en %. 0 = sin intereses.
  final double tasaMensual;

  /// Desde cuándo corren los intereses.
  final String? interesDesde;

  /// Fecha acordada para que le paguen. Opcional.
  final String? vencimiento;

  /// Se dejó de cobrar en esta fecha (se saldó de otra forma o se dio por perdido).
  final String? cerradoEn;
  final String nota;

  /// Intereses ganados hasta hoy. Los suma el servidor día a día.
  final double interesCausado;

  /// Del más antiguo al más reciente.
  final List<MovimientoPrestamo> movimientos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'persona': persona,
        'tasa_mensual': tasaMensual,
        'interes_desde': interesDesde,
        'vencimiento': vencimiento,
        'cerrado_en': cerradoEn,
        'nota': nota,
        'interes_causado': interesCausado,
        'movimientos': [for (final m in movimientos) m.toJson()],
      };

  bool get conInteres => tasaMensual > 0;
  bool get cerrado => cerradoEn != null;

  double get prestado => movimientos.where((m) => m.esDesembolso).fold(0, (s, m) => s + m.capital);
  double get capitalCobrado => movimientos.where((m) => !m.esDesembolso).fold(0, (s, m) => s + m.capital);
  double get interesCobrado => movimientos.where((m) => !m.esDesembolso).fold(0, (s, m) => s + m.interes);
  double get cobrado => capitalCobrado + interesCobrado;

  double get capitalPendiente => prestado > capitalCobrado ? prestado - capitalCobrado : 0;
  double get interesPendiente => interesCausado > interesCobrado ? interesCausado - interesCobrado : 0;

  /// Lo que le deben hoy. Si se cerró, ya no se cuenta con ello.
  double get pendiente => cerrado || pagado ? 0 : capitalPendiente + interesPendiente;

  bool get pagado => capitalPendiente < _casiCero && interesPendiente < _casiCero;
  bool get activo => !cerrado && !pagado;

  /// De todo lo que tenían que devolverle, cuánto ya llegó (0..1).
  double get progreso {
    final total = prestado + interesCausado;
    return total > 0 ? (cobrado / total).clamp(0, 1).toDouble() : 0;
  }

  /// Cuánto gana al día con lo que le deben hoy (interés simple, mes de 30 días).
  double get gananciaDiaria => !activo || !conInteres ? 0 : capitalPendiente * tasaMensual / 100 / 30;

  /// Días que faltan para la fecha acordada; negativo si ya pasó. null si no hay.
  int? diasParaVencer({String? hoy}) => vencimiento == null ? null : diffDias(vencimiento!, hoy ?? hoyYmd());

  /// Primera fecha prestada.
  String? get desde => movimientos.where((m) => m.esDesembolso).firstOrNull?.fecha;
}

/// Lo que le deben en total: suma al patrimonio.
double porCobrarTotal(Iterable<Prestamo> lista) => lista.fold(0, (s, p) => s + p.pendiente);

/// Iniciales para el avatar: "Ana María Gómez" → "AM".
String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (partes.isEmpty) return '?';
  return partes.take(2).map((p) => p.characters0.toUpperCase()).join();
}

extension on String {
  String get characters0 => isEmpty ? '' : String.fromCharCode(runes.first);
}
