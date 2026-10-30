import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_module.dart';
import 'dates.dart';
import 'db/database.dart';

/// Base local (preferencias, caché y registro diario del ciclo).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Mes visible de un calendario (siempre el día 1).
class MonthCursor extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month);
  }

  void mover(int delta) => state = DateTime(state.year, state.month + delta);
  void ir(DateTime d) => state = DateTime(d.year, d.month);
  void hoy() => ir(DateTime.now());
}

/// Día seleccionado (YYYY-MM-DD) o null.
class SelectedDay extends Notifier<String?> {
  @override
  String? build() => null;

  void seleccionar(String? fecha) => state = fecha;

  /// Un segundo toque sobre el mismo día lo deselecciona (como en la web).
  void alternar(String fecha) => state = state == fecha ? null : fecha;
}

/// En el ciclo el día seleccionado arranca en hoy: la rueda siempre muestra algo.
class SelectedDayHoy extends SelectedDay {
  @override
  String? build() => hoyYmd();

  @override
  void alternar(String fecha) => state = fecha;
}

final mesEventosProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);
final diaEventosProvider = NotifierProvider<SelectedDay, String?>(SelectedDay.new);
final mesCicloProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);
final diaCicloProvider = NotifierProvider<SelectedDay, String?>(SelectedDayHoy.new);
final mesFinanzasProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);
final diaFinanzasProvider = NotifierProvider<SelectedDay, String?>(SelectedDay.new);

/// Módulo activo: define el acento del tema global (barra inferior, diálogos).
class ModuloActivo extends Notifier<AppModule> {
  @override
  AppModule build() => AppModule.inicio;
  void set(AppModule m) => state = m;
}

final moduloActivoProvider = NotifierProvider<ModuloActivo, AppModule>(ModuloActivo.new);

/// Preferencias del dispositivo (tabla de ajustes local).
class Preferencias {
  const Preferencias({
    this.themeMode = ThemeMode.system,
    this.reducirMovimiento = false,
    this.onboardingFinanzasOculto = false,
    this.notificaciones = true,
    this.aviso30 = true,
    this.resumenDiario = true,
    this.permisoPedido = false,
    this.modulos,
  });

  final ThemeMode themeMode;
  final bool reducirMovimiento;
  final bool onboardingFinanzasOculto;

  /// Notificaciones locales en el teléfono (además del WhatsApp del servidor).
  final bool notificaciones;

  /// Aviso 30 minutos antes de los eventos con hora (como el cron).
  final bool aviso30;

  /// Resumen de las 7:00 a. m. con lo "de todo el día" (como el cron).
  final bool resumenDiario;

  /// Ya se mostró la explicación previa al permiso del sistema.
  final bool permisoPedido;

  /// Módulos que la persona eligió ver. null: nunca eligió, se ven todos (así
  /// nadie pierde una pestaña que ya usaba al actualizar la app).
  final Set<AppModule>? modulos;

  static Preferencias fromMap(Map<String, String> m) => Preferencias(
        themeMode: switch (m['tema']) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        reducirMovimiento: m['reducir_movimiento'] == '1',
        onboardingFinanzasOculto: m['onboarding_fin'] == '1',
        notificaciones: m['notificaciones'] != '0',
        aviso30: m['aviso30'] != '0',
        resumenDiario: m['resumen'] != '0',
        permisoPedido: m['permiso_pedido'] == '1',
        modulos: m['modulos'] == null ? null : {for (final n in m['modulos']!.split(',')) ...AppModule.values.where((x) => x.name == n)},
      );
}

final preferenciasProvider = StreamProvider<Preferencias>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.ajustes).watch().map(
        (rows) => Preferencias.fromMap({for (final r in rows) r.clave: r.valor}),
      );
});

/// Módulos visibles en la navegación. "Hoy" siempre está.
final modulosActivosProvider = Provider<Set<AppModule>>((ref) {
  final elegidos = ref.watch(preferenciasProvider).value?.modulos;
  return elegidos == null ? AppModule.values.toSet() : {AppModule.inicio, ...elegidos};
});

/// La cuenta se acaba de verificar: toca la bienvenida antes de entrar.
class BienvenidaPendiente extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final bienvenidaPendienteProvider = NotifierProvider<BienvenidaPendiente, bool>(BienvenidaPendiente.new);

final ajustesRepoProvider = Provider((ref) => AjustesRepo(ref.watch(databaseProvider)));

class AjustesRepo {
  AjustesRepo(this._db);
  final AppDatabase _db;

  Future<void> set(String clave, String valor) =>
      _db.into(_db.ajustes).insertOnConflictUpdate(AjustesCompanion.insert(clave: clave, valor: valor));

  Future<void> setTema(ThemeMode m) => set('tema', switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      });
  Future<void> setReducirMovimiento(bool v) => set('reducir_movimiento', v ? '1' : '0');
  Future<void> setOnboardingFinanzasOculto(bool v) => set('onboarding_fin', v ? '1' : '0');
  Future<void> setNotificaciones(bool v) => set('notificaciones', v ? '1' : '0');
  Future<void> setAviso30(bool v) => set('aviso30', v ? '1' : '0');
  Future<void> setResumenDiario(bool v) => set('resumen', v ? '1' : '0');
  Future<void> marcarPermisoPedido() => set('permiso_pedido', '1');
  Future<void> setModulos(Set<AppModule> m) => set('modulos', m.where((x) => x != AppModule.inicio).map((x) => x.name).join(','));
}
