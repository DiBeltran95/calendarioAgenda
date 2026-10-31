// Capturas de las pantallas con la fuente real y el backend falso, para revisar
// el diseño sin tocar la API real. No es una prueba: no corre con `flutter test`.
//
//   flutter test test/support/vitrina.dart --dart-define=VITRINA_DIR=<carpeta>

import 'dart:io';
import 'dart:ui' as ui;

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/features/citas/citas_repository.dart';
import 'package:agendaservi/features/cycle/cycle_repository.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_providers.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:agendaservi/features/finance/finance_screen.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_logica.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_repository.dart';
import 'package:agendaservi/features/finance/prestamos/prestamos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'fake_backend.dart';
import 'harness.dart';

const _carpeta = String.fromEnvironment('VITRINA_DIR', defaultValue: 'build/vitrina');

Future<void> _fuente(String familia, List<String> archivos) async {
  final l = FontLoader(familia);
  for (final a in archivos) {
    final b = File(a).readAsBytesSync();
    l.addFont(Future.value(ByteData.view(b.buffer)));
  }
  await l.load();
}

Future<void> _sembrar(FakeBackend backend) async {
  final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
  await c.read(sesionProvider.future);
  final hoy = hoyYmd();
  final ev = c.read(eventsRepoProvider);
  await ev.crear(EventoInput(titulo: 'Reunión con el contador', fecha: hoy, hora: '23:30', categoria: 'reunion'));
  await ev.crear(EventoInput(titulo: 'SOAT de la moto', fecha: hoy, categoria: 'moto', frecuencia: 'anual'));
  await ev.crear(EventoInput(titulo: 'Cita con el dentista', fecha: sumarDiasYmd(hoy, 1), hora: '10:00', categoria: 'dentista'));
  await ev.crear(EventoInput(titulo: 'Arriendo', fecha: sumarDiasYmd(hoy, 2), categoria: 'arriendo', frecuencia: 'mensual', tipoTransaccion: 'gasto', costo: 1200000));
  await ev.crearCumple(CumpleInput(nombre: 'Mamá', fecha: sumarDiasYmd(hoy, 3), anioNacimiento: 1965));

  final ci = c.read(cycleRepoProvider);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -40), diasSangrado: 5);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -12), diasSangrado: 4);

  final fi = c.read(financeRepoProvider);
  final ah = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 3000000));
  final tc = await fi.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 4000000, diaCorte: 15));
  await fi.crearTransaccion(TransaccionInput(tipo: 'ingreso', monto: 4500000, descripcion: 'Salario', fecha: hoy, cuentaId: ah));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 350000, descripcion: 'Mercado', fecha: hoy, cuentaId: ah, categoria: 'comida'));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 900000, descripcion: 'Celular', fecha: hoy, cuentaId: tc, cuotas: 3));
  await fi.crearMeta(const MetaInput(nombre: 'Viaje', montoObjetivo: 2000000, montoActual: 500000));
  final inv = c.read(inversionesRepoProvider);
  c.listen(inversionesProvider, (_, _) {});
  await c.read(inversionesProvider.future);
  await inv.crear(nombre: '10 novillos de levante', tipo: 'ganado', monto: 2000000, fecha: sumarDiasYmd(hoy, -90), cuentaId: ah);
  final casa = await inv.crear(nombre: 'Casa en Villeta', tipo: 'inmueble', monto: 180000000, fecha: '2021-03-15');
  await inv.agregarMovimiento(casa, tipo: TipoMovimiento.valoracion, monto: 215000000, fecha: hoy);
  // Un día con cada cosa, para ver cómo se distinguen en el calendario.
  await fi.transferir(origenId: ah, destinoId: tc, monto: 300000, fecha: sumarDiasYmd(hoy, -1), descripcion: 'Pago: Cuota');
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 80000, descripcion: 'Zapatos', fecha: sumarDiasYmd(hoy, -2), cuentaId: ah, categoria: 'otros'));
  await inv.crear(nombre: 'Terneros', tipo: 'ganado', monto: 500000, fecha: sumarDiasYmd(hoy, -2), cuentaId: ah);
  // Cuentas de todo tipo, dólares y préstamos.
  final nu = await fi.crearCuenta(const CuentaInput(nombre: 'Nu', tipo: 'ahorros', saldo: 6200000));
  await fi.activarGanancias(nu, tasa: 9, desde: sumarDiasYmd(hoy, -6));
  await fi.crearCuenta(const CuentaInput(nombre: 'Billetera', tipo: 'efectivo', saldo: 180000));
  await fi.crearCuenta(CuentaInput(nombre: 'CDT Bancolombia', tipo: 'cdt', saldo: 5000000, interesTasa: 10.5, fechaInicio: sumarDiasYmd(hoy, -60), plazoDias: 180));
  final arq = await inv.crear(nombre: 'ARQ', tipo: 'dolares', monto: 2050000, montoUsd: 500, fecha: sumarDiasYmd(hoy, -45), cuentaId: ah);
  await inv.agregarMovimiento(arq, tipo: TipoMovimiento.aporte, monto: 1260000, montoUsd: 300, fecha: sumarDiasYmd(hoy, -5), cuentaId: ah);
  final pr = c.read(prestamosRepoProvider);
  c.listen(prestamosProvider, (_, _) {});
  await c.read(prestamosProvider.future);
  final ana = await pr.crear(persona: 'Ana María Gómez', monto: 2000000, fecha: sumarDiasYmd(hoy, -40), cuentaId: ah, tasaMensual: 2, interesDesde: sumarDiasYmd(hoy, -40), vencimiento: sumarDiasYmd(hoy, 20));
  await pr.agregarMovimiento(ana, tipo: 'abono', capital: 500000, interes: 30000, fecha: sumarDiasYmd(hoy, -5), cuentaId: ah);
  await pr.crear(persona: 'Carlos Ruiz', monto: 300000, fecha: sumarDiasYmd(hoy, -30), vencimiento: sumarDiasYmd(hoy, -3));
  final ahora = DateTime.now();
  await fi.guardarPresupuesto(categoria: 'comida', limite: 400000, mes: ahora.month, anio: ahora.year);

  c.listen(configAgendaProvider, (_, _) {});
  c.listen(citasAgendaProvider, (_, _) {});
  await c.read(configAgendaProvider.future);
  final ag = c.read(agendaRepoProvider);
  await ag.guardarNegocio({'nombre': 'Consultorio Diego Beltrán', 'slug': 'consultorio-diego', 'tipo': 'profesional'});
  await ag.guardarServicio({'nombre': 'Consulta de seguimiento', 'duracion_min': 60, 'precio': 120000});
  final cfg = c.read(configAgendaProvider).value!;
  for (final (hora, nombre) in const [('09:00', 'María Fernanda Rodríguez'), ('15:00', 'Andrés Gómez')]) {
    await ag.crearCita({
      'servicio_id': cfg.servicios.single.id,
      'profesional_id': cfg.profesionales.single.id,
      'fecha': hoy,
      'hora': hora,
      'cliente_nombre': nombre,
      'cliente_whatsapp': '573001112233',
      'forzar': true,
    });
  }
  c.dispose();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    await _fuente('PlusJakartaSans', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) 'assets/fonts/PlusJakartaSans-$w.ttf',
    ]);
    final flutter = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['USERPROFILE']}/flutter';
    await _fuente('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
    Directory(_carpeta).createSync(recursive: true);
  });

  for (final (modo, tema) in const [('claro', ThemeMode.light), ('oscuro', ThemeMode.dark)]) {
    testWidgets(timeout: const Timeout(Duration(minutes: 4)), 'vitrina $modo', (t) async {
      debugDisableShadows = false;
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      t.view.padding = const FakeViewPadding(top: 141, bottom: 102);
      t.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
      addTearDown(t.view.reset);

      final llave = GlobalKey();
      final backend = FakeBackend();
      await t.runAsync(() => _sembrar(backend));
      final db = dbEnMemoria();
      await t.runAsync(() => AjustesRepo(db).setTema(tema));

      Future<void> esperar([int vueltas = 14]) async {
        for (var i = 0; i < vueltas; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await t.pump(const Duration(milliseconds: 120));
        }
      }

      Future<void> foto(String nombre) async {
        await t.pump(const Duration(seconds: 4));
        await t.runAsync(() async {
          final caja = llave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await caja.toImage(pixelRatio: 1.5);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$_carpeta/${nombre}_$modo.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }

      await t.pumpWidget(RepaintBoundary(
        key: llave,
        child: ProviderScope(overrides: overridesDePrueba(backend: backend, db: db), child: const AgendaApp()),
      ));
      await esperar(24);

      final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
      final router = c.read(routerProvider);
      for (final (nombre, ruta) in const [
        ('hoy', '/hoy'),
        ('eventos', '/eventos'),
        ('citas', '/citas'),
        ('finanzas', '/finanzas'),
        ('ciclo', '/ciclo'),
        ('perfil', '/perfil'),
        ('pagos', '/finanzas/pagos'),
        ('inversiones', '/finanzas/inversiones'),
        ('bienvenida', '/bienvenida'),
      ]) {
        router.go(ruta);
        await esperar();
        await foto(nombre);
      }

      // Cuentas por secciones: la pantalla es larga.
      c.read(finTabProvider.notifier).set(FinTab.cuentas);
      router.go('/finanzas');
      await esperar();
      final desplazable = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      for (final (k, ancla) in const ['Efectivo y bancos', 'Tarjetas y créditos', 'Inversiones', 'Préstamos que hiciste', 'Transferencias'].indexed) {
        await t.scrollUntilVisible(find.text(ancla), 200, scrollable: desplazable.last, maxScrolls: 40);
        await esperar(2);
        Scrollable.ensureVisible(t.element(find.text(ancla)), alignment: 0.1);
        await esperar(6);
        await foto('cuentas_$k');
      }
      await t.drag(desplazable.last, const Offset(0, 6000));
      await esperar(6);

      c.read(finTabProvider.notifier).set(FinTab.historial);
      c.read(finCalendarioProvider.notifier).set(true);
      router.go('/finanzas');
      await esperar();
      final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      await t.scrollUntilVisible(find.text('Pago de crédito'), 300, scrollable: lista.last, maxScrolls: 30);
      await esperar(6);
      await t.drag(lista.last, const Offset(0, 460));
      await esperar(6);
      await foto('calendario_finanzas');

      router.go('/capturar');
      await esperar();
      await t.enterText(find.byType(TextField).last, 'almuerzo 25 mil');
      await esperar(6);
      await foto('captura');

      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
      debugDisableShadows = true;
    });
  }
}
