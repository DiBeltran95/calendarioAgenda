import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../finance/finance_logic.dart';

/// Lo que cada persona registra una y otra vez, para repetirlo en un toque.
enum ClaseFrecuente { gasto, ingreso, evento }

class Frecuente {
  const Frecuente({
    required this.clase,
    required this.titulo,
    required this.veces,
    required this.categoria,
    this.monto = 0,
    this.cuentaId,
    this.cuotas = 1,
    this.hora,
    this.tipoEvento = 'ninguno',
  });

  final ClaseFrecuente clase;
  final String titulo;

  /// Cuántas veces lo registró en los últimos meses.
  final int veces;
  final String categoria;
  final double monto;
  final int? cuentaId;
  final int cuotas;

  /// HH:mm habitual de un evento; null si es de todo el día.
  final String? hora;

  /// tipo_transaccion del evento: ninguno, gasto o ingreso.
  final String tipoEvento;

  bool get esEvento => clase == ClaseFrecuente.evento;
  String get clave => '${clase.name}:${normalizarRegistro(titulo)}';

  factory Frecuente.fromJson(Map<String, dynamic> j) => Frecuente(
        clase: ClaseFrecuente.values.firstWhere((c) => c.name == j['clase'], orElse: () => ClaseFrecuente.gasto),
        titulo: asString(j['titulo']),
        veces: asInt(j['veces']),
        categoria: asString(j['categoria']),
        monto: asDouble(j['monto']),
        cuentaId: asIntOrNull(j['cuenta_id']),
        cuotas: asInt(j['cuotas'], fallback: 1),
        hora: asStringOrNull(j['hora']),
        tipoEvento: asStringOrNull(j['tipo_evento']) ?? 'ninguno',
      );

  Map<String, dynamic> toJson() => {
        'clase': clase.name,
        'titulo': titulo,
        'veces': veces,
        'categoria': categoria,
        'monto': monto,
        'cuenta_id': cuentaId,
        'cuotas': cuotas,
        'hora': hora,
        'tipo_evento': tipoEvento,
      };
}

const limiteFrecuentes = 5;

/// Solo cuenta lo reciente: lo de hace más de seis meses ya no es un hábito.
const _ventanaDias = 180;

/// Un registro de hace 45 días pesa la mitad que uno de hoy.
const _vidaMediaDias = 45.0;

/// Eventos futuros que ya se dejaron agendados.
const _diasAdelante = 90;

/// Descripciones que escribe el sistema al pagar una cuota, un evento o un ingreso planificado.
final _automatica = RegExp(r'^(abono de deuda|pago|cobro|cobro tarjeta|cuota \d+/\d+)\s*:');

/// Lo que queda cuando se dicta solo un monto: no dice qué se registró.
const _genericas = {'gasto', 'ingreso'};

/// "Almuérzo  " y "almuerzo" son lo mismo.
String normalizarRegistro(String s) {
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  final b = StringBuffer();
  for (final c in s.trim().toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

/// El valor que más se repite; si empatan, el más reciente. [valores] va del más reciente al más antiguo.
T _moda<T>(List<T> valores) {
  final cuenta = <T, int>{};
  for (final v in valores) {
    cuenta[v] = (cuenta[v] ?? 0) + 1;
  }
  return valores.reduce((mejor, v) => cuenta[v]! > cuenta[mejor]! ? v : mejor);
}

class _Grupo<T> {
  final filas = <T>[];
  double puntaje = 0;
  String ultima = '';

  void sumar(T fila, String fecha, int edad) {
    filas.add(fila);
    puntaje += math.pow(0.5, math.max(edad, 0) / _vidaMediaDias);
    if (fecha.compareTo(ultima) > 0) ultima = fecha;
  }
}

/// Lo más registrado: al menos dos veces, y primero lo más seguido y lo más reciente.
List<Frecuente> calcularFrecuentes({
  required List<Transaccion> transacciones,
  required List<Evento> eventos,
  required String hoy,
  int limite = limiteFrecuentes,
}) {
  int? edadDe(String fecha) {
    if (fecha.length != 10) return null;
    final edad = -diffDias(fecha, hoy);
    return edad > _ventanaDias || edad < -_diasAdelante ? null : edad;
  }

  // Pagar un evento de dinero crea un movimiento con su título: ya se agenda solo.
  final pagosDeEventos = {for (final e in eventos.where((e) => e.esTransaccion)) normalizarRegistro(e.titulo)};

  final movimientos = <String, _Grupo<Transaccion>>{};
  for (final t in [...transacciones]..sort((a, b) => b.fecha.compareTo(a.fecha))) {
    final clave = normalizarRegistro(t.descripcion);
    final edad = edadDe(t.fecha);
    if (edad == null || clave.isEmpty || _genericas.contains(clave)) continue;
    if (esGanancia(t) || t.ingresoPlanificadoId != null || _automatica.hasMatch(clave) || pagosDeEventos.contains(clave)) continue;
    movimientos.putIfAbsent('${t.tipo}:$clave', _Grupo.new).sumar(t, t.fecha, edad);
  }

  final agendados = <String, _Grupo<Evento>>{};
  for (final e in [...eventos]..sort((a, b) => b.fecha.compareTo(a.fecha))) {
    final clave = normalizarRegistro(e.titulo);
    final edad = edadDe(e.fecha);
    if (edad == null || clave.isEmpty) continue;
    // Una serie ya se repite sola, y los cobros de tarjeta los agenda la compra.
    if (e.parentId != null || e.frecuencia != 'unica' || e.tarjetaCreditoId != null || e.transaccionId != null || e.categoria == 'cumpleanos') continue;
    agendados.putIfAbsent(clave, _Grupo.new).sumar(e, e.fecha, edad);
  }

  final candidatos = <(_Grupo, Frecuente)>[
    for (final g in movimientos.values)
      if (g.filas.length >= 2)
        (
          g,
          Frecuente(
            clase: g.filas.first.tipo == 'ingreso' ? ClaseFrecuente.ingreso : ClaseFrecuente.gasto,
            titulo: g.filas.first.descripcion.trim(),
            veces: g.filas.length,
            categoria: _moda([for (final t in g.filas) t.categoria]),
            monto: _moda([for (final t in g.filas) t.monto]),
            cuentaId: _moda([for (final t in g.filas) t.cuentaId]),
            cuotas: _moda([for (final t in g.filas) t.cuotas]),
          ),
        ),
    for (final g in agendados.values)
      if (g.filas.length >= 2)
        (
          g,
          Frecuente(
            clase: ClaseFrecuente.evento,
            titulo: g.filas.first.titulo.trim(),
            veces: g.filas.length,
            categoria: _moda([for (final e in g.filas) e.categoria]),
            monto: _moda([for (final e in g.filas) e.esTransaccion ? e.costo : 0.0]),
            hora: _moda([for (final e in g.filas) e.hora]),
            tipoEvento: _moda([for (final e in g.filas) e.tipoTransaccion]),
          ),
        ),
  ]..sort((a, b) {
      final porPuntaje = b.$1.puntaje.compareTo(a.$1.puntaje);
      if (porPuntaje != 0) return porPuntaje;
      final porFecha = b.$1.ultima.compareTo(a.$1.ultima);
      return porFecha != 0 ? porFecha : a.$2.titulo.compareTo(b.$2.titulo);
    });
  return [for (final (_, f) in candidatos.take(limite)) f];
}

/// Se calcula en el teléfono con lo que el servidor ya entrega, y solo el resultado queda en caché.
class FrecuentesNotifier extends AsyncNotifier<List<Frecuente>> with CacheRed<List<Frecuente>> {
  @override
  String get claveCache => 'frecuentes';

  @override
  Future<Object?> pedir() async {
    final api = ref.read(apiProvider);
    final r = await Future.wait([api.get('/api/finanzas/transacciones'), api.get('/api/events')]);
    final lista = calcularFrecuentes(
      transacciones: parseList(r[0], Transaccion.fromJson),
      eventos: parseList(r[1], Evento.fromJson),
      hoy: hoyYmd(),
    );
    return [for (final f in lista) f.toJson()];
  }

  @override
  List<Frecuente> parsear(Object? json) => parseList(json, Frecuente.fromJson);

  @override
  Object? serializar(List<Frecuente> v) => [for (final f in v) f.toJson()];

  @override
  Future<List<Frecuente>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final frecuentesProvider = AsyncNotifierProvider.autoDispose<FrecuentesNotifier, List<Frecuente>>(FrecuentesNotifier.new, retry: sinReintento);
