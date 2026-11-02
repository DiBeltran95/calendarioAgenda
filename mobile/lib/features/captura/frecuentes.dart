import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import '../finance/finance_logic.dart';

/// Los gastos e ingresos que cada persona registra una y otra vez, para repetirlos en un toque.
enum ClaseFrecuente { gasto, ingreso }

class Frecuente {
  const Frecuente({
    required this.clase,
    required this.titulo,
    required this.veces,
    required this.categoria,
    this.monto = 0,
    this.cuentaId,
    this.cuotas = 1,
  });

  final ClaseFrecuente clase;
  final String titulo;

  /// Cuántas veces lo registró en los últimos meses.
  final int veces;
  final String categoria;
  final double monto;
  final int? cuentaId;
  final int cuotas;

  String get clave => '${clase.name}:${normalizarRegistro(titulo)}';

  factory Frecuente.fromJson(Map<String, dynamic> j) => Frecuente(
        clase: ClaseFrecuente.values.firstWhere((c) => c.name == j['clase'], orElse: () => ClaseFrecuente.gasto),
        titulo: asString(j['titulo']),
        veces: asInt(j['veces']),
        categoria: asString(j['categoria']),
        monto: asDouble(j['monto']),
        cuentaId: asIntOrNull(j['cuenta_id']),
        cuotas: asInt(j['cuotas'], fallback: 1),
      );

  Map<String, dynamic> toJson() => {
        'clase': clase.name,
        'titulo': titulo,
        'veces': veces,
        'categoria': categoria,
        'monto': monto,
        'cuenta_id': cuentaId,
        'cuotas': cuotas,
      };
}

const limiteFrecuentes = 5;

/// Solo cuenta lo reciente: lo de hace más de seis meses ya no es un hábito.
const _ventanaDias = 180;

/// Un registro de hace 45 días pesa la mitad que uno de hoy.
const _vidaMediaDias = 45.0;

/// Descripciones que escribe el sistema al pagar una cuota, un evento o un ingreso planificado.
final _automatica = RegExp(r'^(abono de deuda|pago|cobro|cobro tarjeta|cuota \d+/\d+)\s*:');

/// Un ingreso así lo genera la plata que ya se tiene: no es algo que se repita a mano.
final _ganancia = RegExp(r'\b(rendimientos?|ganancias?|intereses?)\b');

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

class _Grupo {
  final filas = <Transaccion>[];
  double puntaje = 0;
  String ultima = '';

  void sumar(Transaccion fila, int edad) {
    filas.add(fila);
    puntaje += math.pow(0.5, math.max(edad, 0) / _vidaMediaDias);
    if (fila.fecha.compareTo(ultima) > 0) ultima = fila.fecha;
  }
}

/// Lo más registrado: al menos dos veces, y primero lo más seguido y lo más reciente.
/// Los gastos van antes; un ingreso ocupa un solo puesto, salvo que sobre espacio.
List<Frecuente> calcularFrecuentes({
  required List<Transaccion> transacciones,
  required List<Evento> eventos,
  required String hoy,
  int limite = limiteFrecuentes,
}) {
  // Pagar un evento de dinero crea un movimiento con su título: ya se agenda solo.
  final pagosDeEventos = {for (final e in eventos.where((e) => e.esTransaccion)) normalizarRegistro(e.titulo)};

  final grupos = <String, _Grupo>{};
  for (final t in [...transacciones]..sort((a, b) => b.fecha.compareTo(a.fecha))) {
    final clave = normalizarRegistro(t.descripcion);
    if (t.fecha.length != 10 || clave.isEmpty || _genericas.contains(clave)) continue;
    final edad = -diffDias(t.fecha, hoy);
    if (edad > _ventanaDias) continue;
    if (esGanancia(t) || (t.tipo == 'ingreso' && _ganancia.hasMatch(clave))) continue;
    if (t.ingresoPlanificadoId != null || _automatica.hasMatch(clave) || pagosDeEventos.contains(clave)) continue;
    grupos.putIfAbsent('${t.tipo}:$clave', _Grupo.new).sumar(t, edad);
  }

  final ordenados = grupos.values.where((g) => g.filas.length >= 2).toList()
    ..sort((a, b) {
      final porPuntaje = b.puntaje.compareTo(a.puntaje);
      if (porPuntaje != 0) return porPuntaje;
      final porFecha = b.ultima.compareTo(a.ultima);
      return porFecha != 0 ? porFecha : a.filas.first.descripcion.compareTo(b.filas.first.descripcion);
    });
  final todos = [
    for (final g in ordenados)
      Frecuente(
        clase: g.filas.first.tipo == 'ingreso' ? ClaseFrecuente.ingreso : ClaseFrecuente.gasto,
        titulo: g.filas.first.descripcion.trim(),
        veces: g.filas.length,
        categoria: _moda([for (final t in g.filas) t.categoria]),
        monto: _moda([for (final t in g.filas) t.monto]),
        cuentaId: _moda([for (final t in g.filas) t.cuentaId]),
        cuotas: _moda([for (final t in g.filas) t.cuotas]),
      ),
  ];
  final gastos = todos.where((f) => f.clase == ClaseFrecuente.gasto).toList();
  final ingresos = todos.where((f) => f.clase == ClaseFrecuente.ingreso).take(math.max(1, limite - gastos.length)).toList();
  return [...gastos.take(limite - ingresos.length), ...ingresos];
}

/// Se calcula en el teléfono con lo que el servidor ya entrega, y solo el resultado queda en caché.
class FrecuentesNotifier extends AsyncNotifier<List<Frecuente>> with CacheRed<List<Frecuente>> {
  @override
  // Clave nueva: la anterior guardaba también eventos y ganancias.
  String get claveCache => 'frecuentes_movimientos';

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
