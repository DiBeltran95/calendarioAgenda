import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_module.dart';
import 'dates.dart';
import 'db/database.dart';

/// Base de datos única de la app. Se sobreescribe en pruebas con una en memoria.
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

final mesEventosProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);
final diaEventosProvider = NotifierProvider<SelectedDay, String?>(SelectedDay.new);
final mesCicloProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);

/// En el ciclo el día seleccionado arranca en hoy: la rueda siempre muestra algo.
class SelectedDayHoy extends SelectedDay {
  @override
  String? build() => hoyYmd();

  @override
  void alternar(String fecha) => state = fecha;
}

final diaCicloProvider = NotifierProvider<SelectedDay, String?>(SelectedDayHoy.new);
final mesFinanzasProvider = NotifierProvider<MonthCursor, DateTime>(MonthCursor.new);
final diaFinanzasProvider = NotifierProvider<SelectedDay, String?>(SelectedDay.new);

/// Módulo activo: define el acento del tema global (barra inferior, diálogos).
class ModuloActivo extends Notifier<AppModule> {
  @override
  AppModule build() => AppModule.eventos;
  void set(AppModule m) => state = m;
}

final moduloActivoProvider = NotifierProvider<ModuloActivo, AppModule>(ModuloActivo.new);

/// Preferencias guardadas en la tabla de ajustes.
class Preferencias {
  const Preferencias({
    this.themeMode = ThemeMode.dark,
    this.reducirMovimiento = false,
    this.nombre = '',
    this.bienvenidaVista = false,
    this.onboardingFinanzasOculto = false,
  });

  final ThemeMode themeMode;
  final bool reducirMovimiento;
  final String nombre;
  final bool bienvenidaVista;
  final bool onboardingFinanzasOculto;

  static Preferencias fromMap(Map<String, String> m) => Preferencias(
        themeMode: switch (m['tema']) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        },
        reducirMovimiento: m['reducir_movimiento'] == '1',
        nombre: m['nombre'] ?? '',
        bienvenidaVista: m['bienvenida'] == '1',
        onboardingFinanzasOculto: m['onboarding_fin'] == '1',
      );
}

final preferenciasProvider = StreamProvider<Preferencias>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.ajustes).watch().map(
        (rows) => Preferencias.fromMap({for (final r in rows) r.clave: r.valor}),
      );
});

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
  Future<void> setNombre(String v) => set('nombre', v.trim());
  Future<void> marcarBienvenida() => set('bienvenida', '1');
  Future<void> setOnboardingFinanzasOculto(bool v) => set('onboarding_fin', v ? '1' : '0');
}
