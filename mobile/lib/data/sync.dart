import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators, StringExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dates.dart';
import '../core/holidays.dart';
import '../core/net/api_exception.dart';
import '../core/net/json.dart';
import '../core/providers.dart';
import '../core/session.dart';
import 'models.dart';

// Estrategia de datos: "caché primero, luego red".
//
// Cada carga muestra al instante lo último guardado en el teléfono (si existe)
// y en paralelo pide la versión fresca al servidor. Si no hay conexión, la app
// sigue siendo consultable con lo cacheado y se muestra un aviso discreto.

/// Estado de la conexión con el servidor según la última petición.
enum EstadoRed { enLinea, sinConexion }

class RedNotifier extends Notifier<EstadoRed> {
  @override
  EstadoRed build() => EstadoRed.enLinea;
  void reportar(Object? error) {
    final offline = error is ApiException && error.isNetwork;
    final nuevo = offline ? EstadoRed.sinConexion : EstadoRed.enLinea;
    if (nuevo != state) state = nuevo;
  }
}

final redProvider = NotifierProvider<RedNotifier, EstadoRed>(RedNotifier.new);

/// Sin reintentos automáticos de Riverpod: la caché cubre los fallos y el
/// usuario puede reintentar (arrastrar para refrescar o el aviso sin conexión).
Duration? sinReintento(int _, Object _) => null;

/// Base común: lee la caché, pide al servidor y guarda la respuesta.
mixin CacheRed<T> on AsyncNotifier<T> {
  String get claveCache;
  Future<Object?> pedir();
  T parsear(Object? json);
  Object? serializar(T valor);

  String get _clave => 'u${ref.read(usuarioIdProvider)}:$claveCache';

  Future<T> cargar() async {
    if (ref.read(usuarioIdProvider) == 0) return parsear(null);
    final db = ref.read(databaseProvider);
    final c = await db.leerCache(_clave);
    if (c != null) {
      // Se muestra la caché y se refresca en segundo plano.
      scheduleMicrotask(refrescar);
      return parsear(jsonDecode(c['json']! as String));
    }
    return _deRed();
  }

  Future<T> _deRed() async {
    try {
      final json = await pedir();
      ref.read(redProvider.notifier).reportar(null);
      final valor = parsear(json);
      await ref.read(databaseProvider).escribirCache(_clave, jsonEncode(serializar(valor)));
      return valor;
    } catch (e) {
      ref.read(redProvider.notifier).reportar(e);
      rethrow;
    }
  }

  /// Muestra un valor ya conocido (p. ej. llegado en vivo) y lo guarda en caché.
  void fijar(T valor) {
    if (!ref.mounted) return;
    state = AsyncData(valor);
    final uid = ref.read(usuarioIdProvider);
    if (uid == 0) return;
    unawaited(ref.read(databaseProvider).escribirCache(_clave, jsonEncode(serializar(valor))).catchError((Object _) {}));
  }

  /// Pide la versión fresca; si falla se conserva lo que ya se mostraba.
  Future<void> refrescar() async {
    if (!ref.mounted || ref.read(usuarioIdProvider) == 0) return;
    try {
      final v = await _deRed();
      if (ref.mounted) state = AsyncData(v);
    } catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────── Bootstrap ───────────────────────────

class BootstrapNotifier extends AsyncNotifier<Bootstrap> with CacheRed<Bootstrap> {
  @override
  String get claveCache => 'bootstrap';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/dashboard/bootstrap');

  @override
  Bootstrap parsear(Object? json) => json == null ? Bootstrap.vacio : Bootstrap.fromJson(asMap(json));

  @override
  Object? serializar(Bootstrap v) => v.toJson();

  @override
  Future<Bootstrap> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final bootstrapProvider = AsyncNotifierProvider<BootstrapNotifier, Bootstrap>(BootstrapNotifier.new, retry: sinReintento);

// ─────────────────────────── Mes ───────────────────────────

class MonthNotifier extends AsyncNotifier<MonthData> with CacheRed<MonthData> {
  MonthNotifier(this.clave);
  final (int, int) clave;

  /// Meses montados ahora mismo (para refrescarlos tras un cambio).
  static final activos = <(int, int)>{};

  @override
  String get claveCache => 'mes:${prefijoMes(clave.$1, clave.$2)}';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/dashboard/month', query: {'mes': clave.$2, 'anio': clave.$1});

  @override
  MonthData parsear(Object? json) => json == null ? MonthData.vacio : MonthData.fromJson(asMap(json));

  @override
  Object? serializar(MonthData v) => v.toJson();

  @override
  Future<MonthData> build() {
    ref.watch(usuarioIdProvider);
    activos.add(clave);
    ref.onDispose(() => activos.remove(clave));
    return cargar();
  }

  /// Cambio optimista de un evento (p. ej. marcar pagado) antes de la respuesta.
  void reemplazarEvento(Evento e) {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(actual.conEventos([for (final x in actual.eventos) x.id == e.id ? e : x]));
  }
}

final monthProvider =
    AsyncNotifierProvider.autoDispose.family<MonthNotifier, MonthData, (int, int)>(MonthNotifier.new, retry: sinReintento);

// ─────────────────────────── Presupuestos (todos) ───────────────────────────

/// Todos los presupuestos: permiten "arrastrar" el límite de un mes al siguiente.
class PresupuestosNotifier extends AsyncNotifier<List<Presupuesto>> with CacheRed<List<Presupuesto>> {
  @override
  String get claveCache => 'presupuestos';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/finanzas/presupuestos');

  @override
  List<Presupuesto> parsear(Object? json) => parseList(json, Presupuesto.fromJson);

  @override
  Object? serializar(List<Presupuesto> v) => [for (final p in v) p.toJson()];

  @override
  Future<List<Presupuesto>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final presupuestosProvider =
    AsyncNotifierProvider<PresupuestosNotifier, List<Presupuesto>>(PresupuestosNotifier.new, retry: sinReintento);

// ─────────────────────────── Analítica ───────────────────────────

class AnaliticaNotifier extends AsyncNotifier<List<Transaccion>> with CacheRed<List<Transaccion>> {
  AnaliticaNotifier(this.dias);
  final int dias;

  @override
  String get claveCache => 'analitica:$dias';

  @override
  Future<Object?> pedir() async => asMap(await ref.read(apiProvider).get('/api/finanzas/analytics', query: {'dias': dias}))['transacciones'];

  @override
  List<Transaccion> parsear(Object? json) => [
        for (final (i, m) in asMapList(json).indexed) Transaccion.fromJson({...m, 'id': m['id'] ?? -(i + 1)}),
      ];

  @override
  Object? serializar(List<Transaccion> v) => [for (final t in v) t.toJson()];

  @override
  Future<List<Transaccion>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final analiticaProvider =
    AsyncNotifierProvider.autoDispose.family<AnaliticaNotifier, List<Transaccion>, int>(AnaliticaNotifier.new, retry: sinReintento);

// ─────────────────────────── Días importantes ───────────────────────────

class DiasImportantesNotifier extends AsyncNotifier<List<DiaImportante>> with CacheRed<List<DiaImportante>> {
  DiasImportantesNotifier(this.anio);
  final int anio;

  @override
  String get claveCache => 'dias:$anio';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/important-days', query: {'year': anio});

  @override
  List<DiaImportante> parsear(Object? json) => parseList(json, DiaImportante.fromJson);

  @override
  Object? serializar(List<DiaImportante> v) => [for (final d in v) d.toJson()];

  @override
  Future<List<DiaImportante>> build() async {
    ref.watch(usuarioIdProvider);
    try {
      return await cargar();
    } catch (_) {
      // Sin red ni caché: se usa la lista local de celebraciones de Colombia.
      return [for (final d in diasEspeciales(anio)) DiaImportante(fecha: d.fecha, nombre: d.nombre, categoria: d.categoria, descripcion: d.descripcion)];
    }
  }
}

final diasImportantesProvider =
    AsyncNotifierProvider.family<DiasImportantesNotifier, List<DiaImportante>, int>(DiasImportantesNotifier.new, retry: sinReintento);

/// Día importante en una fecha (con los datos del servidor del año).
DiaImportante? diaImportanteEn(List<DiaImportante> lista, String fecha) {
  for (final d in lista) {
    if (d.fecha == fecha) return d;
  }
  return null;
}

// ─────────────────────────── Coordinación ───────────────────────────

/// Tras cualquier cambio se descarta la caché de meses (una serie puede tocar
/// muchos) y se recargan del servidor los datos que están en pantalla.
class Sincronizador {
  Sincronizador(this._ref);
  final Ref _ref;

  Future<void> despuesDeCambio({bool bootstrap = true, bool meses = true, bool presupuestos = false}) async {
    final db = _ref.read(databaseProvider);
    final uid = _ref.read(usuarioIdProvider);
    final tareas = <Future<void>>[];
    if (meses) {
      await (db.delete(db.cacheEntries)..where((c) => c.clave.like('u$uid:mes:%') | c.clave.like('u$uid:analitica:%'))).go();
      if (!_ref.mounted) return;
      for (final k in MonthNotifier.activos.toList()) {
        tareas.add(_ref.read(monthProvider(k).notifier).refrescar());
      }
      _ref.invalidate(analiticaProvider);
    }
    if (bootstrap) tareas.add(_ref.read(bootstrapProvider.notifier).refrescar());
    if (presupuestos) tareas.add(_ref.read(presupuestosProvider.notifier).refrescar());
    await Future.wait(tareas);
  }

  /// Arrastrar para refrescar: todo lo visible.
  Future<void> refrescarTodo() => despuesDeCambio(presupuestos: true);
}

final sincronizadorProvider = Provider((ref) => Sincronizador(ref));
