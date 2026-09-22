import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import 'finance_logic.dart';
import 'finance_repository.dart';

final cuentasProvider = StreamProvider<List<Cuenta>>((ref) => ref.watch(financeRepoProvider).watchCuentas());

/// Transacciones de un mes (clave: (año, mes 1..12)).
final txMesProvider = StreamProvider.family<List<Transaccion>, (int, int)>((ref, k) {
  final p = prefijoMes(k.$1, k.$2);
  return ref.watch(financeRepoProvider).watchTransacciones('$p-01', '$p-31');
});

final transferenciasMesProvider = StreamProvider.family<List<Transferencia>, (int, int)>((ref, k) {
  final p = prefijoMes(k.$1, k.$2);
  return ref.watch(financeRepoProvider).watchTransferencias('$p-01', '$p-31');
});

final planesProvider = StreamProvider<List<IngresoPlanificado>>((ref) => ref.watch(financeRepoProvider).watchPlanes());
final verificacionesProvider = StreamProvider<List<Verificacion>>((ref) => ref.watch(financeRepoProvider).watchVerificaciones());
final metasProvider = StreamProvider<List<Meta>>((ref) => ref.watch(financeRepoProvider).watchMetas());
final presupuestosProvider = StreamProvider<List<Presupuesto>>((ref) => ref.watch(financeRepoProvider).watchPresupuestos());
final categoriasFinProvider = StreamProvider<List<CategoriaFinanzas>>((ref) => ref.watch(financeRepoProvider).watchCategorias());
final categoriasEnUsoProvider = StreamProvider<Set<String>>((ref) => ref.watch(financeRepoProvider).watchCategoriasEnUso());

/// Transacciones del último año (para gráficas y patrimonio histórico).
final txAnaliticaProvider = StreamProvider.family<List<Transaccion>, RangoAnalitica>((ref, r) {
  final hoy = hoyYmd();
  return ref.watch(financeRepoProvider).watchTransacciones(sumarDiasYmd(hoy, -r.dias), hoy);
});

/// Ocurrencias de ingresos planificados del mes.
final ocurrenciasMesProvider = Provider.family<List<OcurrenciaIngreso>, (int, int)>((ref, k) {
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
