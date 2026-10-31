// Prueba de extremo a extremo de la interfaz contra el backend falso: arranca
// la app completa, recorre Hoy, Eventos, Finanzas (todas las pestañas), Ciclo
// y Perfil, y los flujos de inicio de sesión y registro con código. Falla ante
// cualquier excepción o desbordamiento de layout.

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/features/citas/citas_repository.dart';
import 'package:agendaservi/features/cycle/cycle_repository.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Siembra datos en el backend falso usando los repositorios reales.
Future<void> _sembrar(FakeBackend backend) async {
  final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
  await c.read(sesionProvider.future);
  final hoy = hoyYmd();
  final ev = c.read(eventsRepoProvider);
  await ev.crear(EventoInput(titulo: 'SOAT de la moto', fecha: hoy, categoria: 'moto', frecuencia: 'anual'));
  await ev.crear(EventoInput(titulo: 'Reunión de equipo', fecha: sumarDiasYmd(hoy, 1), hora: '10:00', categoria: 'reunion'));
  await ev.crear(EventoInput(
      titulo: 'Arriendo', fecha: sumarDiasYmd(hoy, 2), categoria: 'arriendo', frecuencia: 'mensual', tipoTransaccion: 'gasto', costo: 1200000));
  await ev.crearCumple(CumpleInput(nombre: 'Mamá', fecha: sumarDiasYmd(hoy, 3), anioNacimiento: 1965));

  final ci = c.read(cycleRepoProvider);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -40), diasSangrado: 5);
  await ci.guardarPeriodo(fecha: sumarDiasYmd(hoy, -12), diasSangrado: 4);

  final fi = c.read(financeRepoProvider);
  final ah = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 3000000));
  final tc = await fi.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 4000000, diaCorte: 15));
  await fi.crearCuenta(CuentaInput(nombre: 'CDT', tipo: 'cdt', saldo: 5000000, interesTasa: 11, plazoDias: 180, fechaInicio: sumarDiasYmd(hoy, -30)));
  await fi.crearTransaccion(TransaccionInput(tipo: 'ingreso', monto: 4500000, descripcion: 'Salario', fecha: hoy, cuentaId: ah));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 350000, descripcion: 'Mercado', fecha: hoy, cuentaId: ah, categoria: 'comida'));
  await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 900000, descripcion: 'Celular', fecha: hoy, cuentaId: tc, cuotas: 3));
  await fi.crearPlan(descripcion: 'Salario', monto: 4500000, frecuencia: 'mensual', fechaInicio: sumarDiasYmd(hoy, -60), cuentaId: ah);
  await fi.crearMeta(const MetaInput(nombre: 'Viaje', montoObjetivo: 2000000, montoActual: 500000));
  final ahora = DateTime.now();
  await fi.guardarPresupuesto(categoria: 'comida', limite: 400000, mes: ahora.month, anio: ahora.year);

  // Página de citas con un servicio y una cita hoy (agendada a mano).
  c.listen(configAgendaProvider, (_, _) {});
  c.listen(citasAgendaProvider, (_, _) {});
  await c.read(configAgendaProvider.future);
  final ag = c.read(agendaRepoProvider);
  await ag.guardarNegocio({'nombre': 'Consultorio Diego Beltrán', 'slug': 'consultorio-diego', 'tipo': 'profesional'});
  await ag.guardarServicio({'nombre': 'Consulta psicológica de seguimiento', 'duracion_min': 60, 'precio': 120000});
  final cfg = c.read(configAgendaProvider).value!;
  await ag.crearCita({
    'servicio_id': cfg.servicios.single.id,
    'profesional_id': cfg.profesionales.single.id,
    'fecha': hoy,
    'hora': '07:00',
    'cliente_nombre': 'María Fernanda Rodríguez',
    'cliente_whatsapp': '573001112233',
    'forzar': true,
  });
  c.dispose();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  Future<void> esperar(WidgetTester t, [int vueltas = 12]) async {
    // La API falsa y Drift trabajan con futuros reales: se alterna tiempo real
    // y reloj simulado para que terminen las cargas y las animaciones.
    for (var i = 0; i < vueltas; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

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

  Future<void> desmontar(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  }

  for (final (nombre, size, claro, escala) in [
    ('teléfono', const Size(390, 844), false, 1.0),
    ('tablet', const Size(1280, 900), false, 1.0),
    ('teléfono claro con texto al 130%', const Size(390, 844), true, 1.3),
    ('teléfono pequeño con texto grande', const Size(360, 640), false, 1.35),
    ('teléfono en horizontal', const Size(844, 390), true, 1.0),
  ]) {
    testWidgets(timeout: const Timeout(Duration(minutes: 3)), 'recorre toda la app en $nombre', (t) async {
      await tamanio(t, size);
      t.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      final backend = FakeBackend();
      await t.runAsync(() => _sembrar(backend));
      final db = dbEnMemoria();
      if (claro) await t.runAsync(() => AjustesRepo(db).setTema(ThemeMode.light));

      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: db), child: const AgendaApp()));
      await esperar(t, 20);

      // ── Hoy ──
      expect(find.textContaining('Diego'), findsWidgets);
      expect(find.text('Hoy'), findsWidgets);
      expect(find.text('SOAT de la moto'), findsWidgets);
      expect(find.text('Registrar gasto'), findsOneWidget);

      // ── Eventos ──
      await t.tap(find.text('Eventos').last);
      await esperar(t);
      expect(find.bySemanticsLabel(RegExp('1 evento')), findsWidgets);
      await t.tap(find.text('Nuevo evento'));
      await esperar(t);
      expect(find.textContaining('7:00 a. m.'), findsOneWidget); // sin hora → resumen matutino
      await t.tap(find.byTooltip('Cerrar'));
      await esperar(t);
      await t.tap(find.text('Semana'));
      await esperar(t);
      expect(find.text('Evento'), findsOneWidget);
      await t.tap(find.text('Mes'));
      await esperar(t);

      // ── Finanzas: todas las pestañas ──
      await t.tap(find.text('Finanzas').last);
      await esperar(t);
      expect(find.text('Patrimonio neto'), findsOneWidget);
      await verEn(t, find.text('Planear'));
      for (final tab in ['Cuentas', 'Planear', 'Presupuesto', 'Planificador', 'Metas', 'Historial', 'Calendario', 'Gráficos', 'Resumen']) {
        // En pantallas bajas la lista no construye lo que está lejos: se sube y se busca.
        final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        await t.drag(lista.last, const Offset(0, 3000));
        await esperar(t, 4);
        await verEn(t, find.text(tab));
        await t.ensureVisible(find.text(tab).first);
        await esperar(t, 4);
        await t.tap(find.text(tab).first);
        await esperar(t);
      }
      await verEn(t, find.text('Regla 50 / 30 / 20'));

      // ── Ciclo ──
      await t.tap(find.text('Ciclo').last);
      await esperar(t);
      expect(find.text('DÍA'), findsOneWidget);
      await verEn(t, find.text('Historial de ciclos'));

      // ── Citas ──
      await t.tap(find.text('Citas').last);
      await esperar(t);
      expect(find.text('Tu página para agendar'), findsOneWidget);
      // Antes de las 7:00 también sale arriba como la próxima cita: se busca la de la lista.
      await verEn(t, find.text('María Fernanda Rodríguez').last);
      await t.tap(find.text('María Fernanda Rodríguez').last);
      await esperar(t);
      expect(find.text('Escribir por WhatsApp', skipOffstage: false), findsNothing); // tooltip, no texto
      expect(find.byTooltip('Escribir por WhatsApp'), findsOneWidget);
      await t.tap(find.byTooltip('Cerrar').last);
      await esperar(t);
      final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      await t.scrollUntilVisible(find.byTooltip('Ajustes de citas'), -300, scrollable: vertical.last, maxScrolls: 40);
      await esperar(t, 4);
      await t.tap(find.byTooltip('Ajustes de citas'));
      await esperar(t, 16);
      expect(find.text('Ajustes de citas'), findsOneWidget);
      await verEn(t, find.text('Tiempo bloqueado'));
      GoRouter.of(t.element(find.text('Ajustes de citas'))).pop();
      await esperar(t);

      // ── Perfil (desde el avatar) ──
      await t.tap(find.byTooltip('Perfil').last);
      await esperar(t, 16);
      expect(find.text('diego@test.co'), findsOneWidget);
      await verEn(t, find.text('Cerrar sesión'));

      await desmontar(t);
    });
  }

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'inicio de sesión con correo y contraseña', (t) async {
    await tamanio(t, const Size(390, 844));
    final backend = FakeBackend();
    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), sesion: null), child: const AgendaApp()));
    await esperar(t);
    expect(find.text('Bienvenido de nuevo'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'diego@test.co');
    await t.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'mala');
    await t.tap(find.text('Iniciar sesión'));
    await esperar(t);
    expect(find.text('Credenciales inválidas'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'secreta');
    await t.tap(find.text('Iniciar sesión'));
    await esperar(t, 20);
    expect(find.textContaining('Diego'), findsWidgets);
    expect(find.text('Bienvenido de nuevo'), findsNothing);
    await desmontar(t);
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'registro con código de WhatsApp', (t) async {
    await tamanio(t, const Size(390, 844));
    final backend = FakeBackend();
    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), sesion: null), child: const AgendaApp()));
    await esperar(t);
    await t.tap(find.text('Crear cuenta gratis'));
    await esperar(t);
    expect(find.text('Crea tu cuenta'), findsOneWidget);

    await t.enterText(find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana Pérez');
    await t.enterText(find.widgetWithText(TextFormField, 'Correo electrónico'), 'ana@test.co');
    await t.enterText(find.widgetWithText(TextFormField, 'WhatsApp'), '3115556677');
    await t.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'Clave#2026');
    await t.ensureVisible(find.text('Crear cuenta'));
    await t.tap(find.text('Crear cuenta'));
    await esperar(t);
    expect(find.text('Revisa tu WhatsApp'), findsOneWidget);
    expect(find.textContaining('311 *** 6677'), findsOneWidget);
    expect(backend.usuarios.last['whatsapp'], '573115556677');

    await t.enterText(find.byType(TextField).last, '123456');
    await esperar(t, 20);
    expect(find.text('Revisa tu WhatsApp'), findsNothing);

    // Cuenta nueva: la bienvenida pregunta para qué la usará.
    expect(find.text('¿Para qué usarás Agendaservi?'), findsOneWidget);
    expect(find.text('Elige al menos una opción para continuar.'), findsOneWidget);
    await t.tap(find.text('Mis finanzas'));
    await esperar(t, 4);
    await t.tap(find.text('Continuar'));
    await esperar(t, 8);
    expect(find.text('Que nada se te pase'), findsOneWidget);
    await t.tap(find.text('Ahora no'));
    await esperar(t, 20);

    // Solo ve lo que eligió.
    expect(find.textContaining('Ana'), findsWidgets);
    expect(find.text('Finanzas'), findsWidgets);
    expect(find.bySemanticsLabel('Citas'), findsNothing);
    expect(find.bySemanticsLabel('Ciclo'), findsNothing);
    await desmontar(t);
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'módulos: se ocultan y un enlace los vuelve a activar', (t) async {
    await tamanio(t, const Size(390, 844));
    final backend = FakeBackend();
    final db = dbEnMemoria();
    await t.runAsync(() => AjustesRepo(db).setModulos({AppModule.eventos}));
    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: db), child: const AgendaApp()));
    await esperar(t, 20);

    final semantica = t.ensureSemantics();
    expect(find.bySemanticsLabel('Eventos'), findsOneWidget);
    expect(find.bySemanticsLabel('Finanzas'), findsNothing);

    // Una notificación lleva a Finanzas, que estaba oculto.
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
    c.read(routerProvider).go('/finanzas');
    await esperar(t, 12);
    expect(find.bySemanticsLabel('Finanzas'), findsOneWidget);
    expect(c.read(modulosActivosProvider), contains(AppModule.finanzas));
    expect(find.textContaining('Activamos Finanzas'), findsOneWidget);

    // Apagarlo estando dentro devuelve a Hoy.
    await t.runAsync(() => AjustesRepo(db).setModulos({AppModule.eventos}));
    await esperar(t, 12);
    expect(c.read(routerProvider).state.uri.path, '/hoy');
    semantica.dispose();
    await desmontar(t);
  });
}
