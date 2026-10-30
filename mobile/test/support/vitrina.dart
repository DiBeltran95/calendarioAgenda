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
import 'package:agendaservi/features/finance/finance_repository.dart';
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
        ('bienvenida', '/bienvenida'),
      ]) {
        router.go(ruta);
        await esperar();
        await foto(nombre);
      }

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
