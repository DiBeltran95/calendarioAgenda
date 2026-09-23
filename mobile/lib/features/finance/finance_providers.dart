import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models.dart';
import '../../data/sync.dart';
import 'finance_logic.dart';

// Vistas derivadas de las cargas del servidor (bootstrap / mes). Devuelven
// AsyncValue para que la interfaz pueda distinguir "cargando" de "vacío".

final cuentasProvider = Provider<AsyncValue<List<Cuenta>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.cuentas));

final txMesProvider = Provider.autoDispose.family<AsyncValue<List<Transaccion>>, (int, int)>(
    (ref, k) => ref.watch(monthProvider(k)).whenData((d) => d.transacciones));

final transferenciasMesProvider = Provider.autoDispose.family<AsyncValue<List<Transferencia>>, (int, int)>(
    (ref, k) => ref.watch(monthProvider(k)).whenData((d) => d.transferencias));

final planesProvider = Provider<AsyncValue<List<IngresoPlanificado>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.planes));

final verificacionesProvider = Provider<AsyncValue<List<Verificacion>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.verificaciones));

final metasProvider = Provider<AsyncValue<List<Meta>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.metas));

final categoriasFinProvider = Provider<AsyncValue<List<CategoriaFinanzas>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.categorias));

/// Categorías con transacciones o presupuestos (no se pueden borrar): lo que
/// calcula el servidor más lo del mes visible, como en la web.
final categoriasEnUsoProvider = Provider.autoDispose.family<Set<String>, (int, int)>((ref, k) {
  final usadas = {...?ref.watch(bootstrapProvider).value?.categoriasUsadas};
  final mes = ref.watch(monthProvider(k)).value;
  if (mes != null) {
    usadas.addAll(mes.transacciones.map((t) => t.categoria));
    usadas.addAll(mes.presupuestos.map((p) => p.categoria));
  }
  return usadas;
});

/// Transacciones del rango de las gráficas (endpoint de analítica).
final txAnaliticaProvider = Provider.autoDispose.family<AsyncValue<List<Transaccion>>, RangoAnalitica>(
    (ref, r) => ref.watch(analiticaProvider(r.dias)));

/// Ocurrencias de ingresos planificados del mes.
final ocurrenciasMesProvider = Provider.autoDispose.family<List<OcurrenciaIngreso>, (int, int)>((ref, k) {
  final planes = ref.watch(planesProvider).value ?? const [];
  final verifs = ref.watch(verificacionesProvider).value ?? const [];
  return ocurrenciasMes(planes, verifs, k.$1, k.$2);
});

/// Nombre legible de una categoría de finanzas.
final nombreCategoriaProvider = Provider<String Function(String)>((ref) {
  final cats = ref.watch(categoriasFinProvider).value ?? const [];
  final m = {for (final c in cats) c.valor: c.label};
  return (v) => m[v] ?? v;
});

/// Pestañas del panel de finanzas.
enum FinTab {
  resumen('Resumen'),
  cuentas('Cuentas'),
  metas('Metas'),
  presupuesto('Presupuesto'),
  planificador('Planificador'),
  historial('Historial'),
  graficos('Gráficos');

  const FinTab(this.label);
  final String label;
}

class FinTabNotifier extends Notifier<FinTab> {
  @override
  FinTab build() => FinTab.resumen;
  void set(FinTab t) => state = t;
}

final finTabProvider = NotifierProvider<FinTabNotifier, FinTab>(FinTabNotifier.new);

class RangoNotifier extends Notifier<RangoAnalitica> {
  @override
  RangoAnalitica build() => RangoAnalitica.d30;
  void set(RangoAnalitica r) => state = r;
}

final rangoAnaliticaProvider = NotifierProvider<RangoNotifier, RangoAnalitica>(RangoNotifier.new);
