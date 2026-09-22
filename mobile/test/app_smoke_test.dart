// Prueba de extremo a extremo de la interfaz: arranca la app completa sobre
// una base en memoria con datos sembrados y recorre los tres calendarios y
// todas las pestañas de finanzas. Falla ante cualquier excepción o
// desbordamiento de layout (RenderFlex overflow).

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/theme/app_theme.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/db/database.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/features/cycle/cycle_repository.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<AppDatabase> _sembrar({bool claro = false}) async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final hoy = hoyYmd();
  final ajustes = AjustesRepo(db);
  await ajustes.marcarBienvenida();
  if (claro) await ajustes.setTema(ThemeMode.light);
  await ajustes.setNombre('Diego');

  final ev = EventsRepository(db);
  await ev.crear(EventoInput(titulo: 'SOAT de la moto', fecha: hoy, categoria: 'moto', frecuencia: 'anual'));
  await ev.crear(EventoInput(
      titulo: 'Arriendo', fecha: sumarDiasYmd(hoy, 2), categoria: 'arriendo', frecuencia: 'mensual', tipoTransaccion: 'gasto', costo: 1200000));
  await ev.crearCumple(CumpleInput(nombre: 'Mamá', fecha: sumarDiasYmd(hoy, 3), anioNacimiento: 1965));

  final ci = CycleRepository(db);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -40), diasSangrado: 5);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -12), diasSangrado: 4);
  await ci.guardarRegistroDia(fecha: hoy, flujo: 0, animo: 'feliz', sintomas: {'cansancio'});

  final fi = FinanceRepository(db);
  final ah = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 3000000));
  final tc = await fi.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 4000000, diaCorte: 15));
  await fi.crearCuenta(CuentaInput(nombre: 'CDT', tipo: 'cdt', saldo: 5000000, interesTasa: 11, plazoDias: 180, fechaInicio: sumarDiasYmd(hoy, -30)));
  await fi.crearTransaccion(TransaccionInput(tipo: 'ingreso', monto: 4500000, descripcion: 'Salario', fecha: hoy, cuentaId: ah));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 350000, descripcion: 'Mercado', fecha: hoy, cuentaId: ah, categoria: 'comida'));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 900000, descripcion: 'Celular', fecha: hoy, cuentaId: tc, categoria: 'otros', cuotas: 3));
  await fi.crearPlan(descripcion: 'Salario', monto: 4500000, frecuencia: 'mensual', fechaInicio: sumarDiasYmd(hoy, -60), cuentaId: ah);
  await fi.crearMeta(const MetaInput(nombre: 'Viaje', montoObjetivo: 2000000, montoActual: 500000));
  final ahora = DateTime.now();
  await fi.guardarPresupuesto(categoria: 'comida', limite: 400000, mes: ahora.month, anio: ahora.year);
  return db;
}

void main() {
  setUpAll(() async {
    usarGoogleFonts = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await initializeDateFormatting('es_CO');
  });

  Future<void> esperar(WidgetTester t) async {
    // Las consultas de Drift y las animaciones de entrada necesitan tiempo real.
    for (var i = 0; i < 12; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  /// Desplaza la lista vertical principal hasta que [f] sea visible.
  Future<void> verEn(WidgetTester t, Finder f) async {
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await t.scrollUntilVisible(f, 300, scrollable: vertical.last, maxScrolls: 40);
    await esperar(t);
  }

  Future<void> tamanio(WidgetTester t, Size s) async {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  for (final (nombre, size, claro, escala) in [
    ('teléfono', const Size(390, 844), false, 1.0),
    ('tablet', const Size(1280, 900), false, 1.0),
    ('teléfono claro con texto al 130%', const Size(390, 844), true, 1.3),
  ]) {
    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'recorre los tres calendarios en $nombre', (t) async {
      await tamanio(t, size);
      t.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final db = await t.runAsync(() => _sembrar(claro: claro));
      await t.pumpWidget(ProviderScope(overrides: [databaseProvider.overrideWithValue(db!)], child: const AgendaApp()));
      await esperar(t);

      // ── Eventos ──
      expect(find.text('Eventos'), findsWidgets);
      expect(find.textContaining('Diego'), findsWidgets);
      expect(find.byIcon(Icons.two_wheeler_rounded), findsWidgets); // evento anual de moto
      await t.tap(find.text(DateTime.now().day.toString()).first);
      await esperar(t);
      expect(find.text('SOAT de la moto'), findsWidgets);

      // Formulario de evento.
      await t.tap(find.text('Nuevo evento'));
      await esperar(t);
      expect(find.text('Categoría'), findsOneWidget);
      await t.tap(find.byTooltip('Cerrar'));
      await esperar(t);

      // ── Ciclo ──
      await t.tap(find.text('Ciclo').last);
      await esperar(t);
      expect(find.text('DÍA'), findsOneWidget);
      await verEn(t, find.text('Pronóstico'));
      await verEn(t, find.text('Historial de ciclos'));

      // ── Finanzas: todas las pestañas ──
      await t.tap(find.text('Finanzas').last);
      await esperar(t);
      expect(find.text('PATRIMONIO NETO'), findsOneWidget);
      await verEn(t, find.text('Planificador'));
      for (final tab in ['Cuentas', 'Metas', 'Presupuesto', 'Planificador', 'Historial', 'Gráficos', 'Resumen']) {
        await t.ensureVisible(find.text(tab).first);
        await esperar(t);
        await t.tap(find.text(tab).first);
        await esperar(t);
      }
      await verEn(t, find.text('Regla 50 / 30 / 20'));

      // ── Ajustes ──
      await t.tap(find.text('Ajustes').last);
      await esperar(t);
      expect(find.text('Reducir animaciones'), findsOneWidget);

      // Se desmonta la app y se dejan correr los temporizadores de limpieza de
      // Drift. (Cerrar la base bajo el reloj simulado de la prueba se bloquea;
      // la base en memoria se descarta sola.)
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
