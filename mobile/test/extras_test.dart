// Bloqueo con Face ID / huella, captura rápida por texto y voz, y lo que se
// publica para los widgets de la pantalla de inicio.

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/features/captura/voz.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:agendaservi/features/seguridad/bloqueo.dart';
import 'package:agendaservi/features/widgets_inicio/publicador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

class BiometriaFalsa implements ServicioBiometria {
  bool responde = true;
  int pedidos = 0;
  @override
  Future<bool> disponible() async => true;
  @override
  Future<bool> autenticar(String motivo) async {
    pedidos++;
    return responde;
  }
}

class VozFalsa implements ReconocedorVoz {
  void Function(String)? alTexto;
  void Function()? alTerminar;
  @override
  Future<bool> preparar() async => true;
  @override
  Future<void> escuchar({required void Function(String texto) alTexto, required void Function() alTerminar}) async {
    this.alTexto = alTexto;
    this.alTerminar = alTerminar;
  }

  @override
  Future<void> detener() async => alTerminar?.call();
}

class PublicadorFalso implements PublicadorWidgets {
  ResumenWidget? ultimo;
  @override
  Future<void> publicar(ResumenWidget r) async => ultimo = r;
}

/// La captura se pidió antes de que existiera la pantalla principal.
class CapturaYaPedida extends CapturaPendiente {
  @override
  bool build() => true;
}

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  Future<void> esperar(WidgetTester t, [int vueltas = 14]) async {
    for (var i = 0; i < vueltas; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void pantalla(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Future<void> salir(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  }

  void irAFondo(WidgetTester t) {
    for (final e in const [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      t.binding.handleAppLifecycleStateChanged(e);
    }
  }

  void volver(WidgetTester t) {
    for (final e in const [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      t.binding.handleAppLifecycleStateChanged(e);
    }
  }

  group('bloqueo', () {
    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'al abrir pide identificarse; si falla sigue tapada', (t) async {
      pantalla(t);
      final bio = BiometriaFalsa()..responde = false;
      final db = dbEnMemoria();
      await t.runAsync(() => AjustesRepo(db).setBloqueo(true));
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: FakeBackend(), db: db, biometria: bio), child: const AgendaApp()));
      await esperar(t, 20);

      expect(find.text('Agendaservi está bloqueada'), findsOneWidget);
      expect(find.text('No pudimos identificarte. Inténtalo de nuevo.'), findsOneWidget);
      expect(bio.pedidos, 1);

      bio.responde = true;
      await t.tap(find.text('Desbloquear'));
      await esperar(t);
      expect(find.text('Agendaservi está bloqueada'), findsNothing);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'al volver: solo vuelve a pedirlo pasados 2 minutos', (t) async {
      pantalla(t);
      final bio = BiometriaFalsa();
      final db = dbEnMemoria();
      await t.runAsync(() => AjustesRepo(db).setBloqueo(true));
      var ahora = DateTime(2026, 10, 30, 9);
      await t.pumpWidget(ProviderScope(
        overrides: [
          ...overridesDePrueba(backend: FakeBackend(), db: db, biometria: bio),
          relojBloqueoProvider.overrideWithValue(() => ahora),
        ],
        child: const AgendaApp(),
      ));
      await esperar(t, 20);
      expect(find.text('Agendaservi está bloqueada'), findsNothing);
      expect(bio.pedidos, 1);

      // Un minuto fuera: no molesta.
      irAFondo(t);
      ahora = ahora.add(const Duration(minutes: 1));
      volver(t);
      await esperar(t, 6);
      expect(bio.pedidos, 1);

      // Tres minutos fuera: lo pide otra vez.
      irAFondo(t);
      ahora = ahora.add(const Duration(minutes: 3));
      volver(t);
      await esperar(t, 6);
      expect(bio.pedidos, 2);
      expect(find.text('Agendaservi está bloqueada'), findsNothing, reason: 'respondió bien');
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'desactivado no pide nada', (t) async {
      pantalla(t);
      final bio = BiometriaFalsa();
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: FakeBackend(), db: dbEnMemoria(), biometria: bio), child: const AgendaApp()));
      await esperar(t, 20);
      expect(find.text('Agendaservi está bloqueada'), findsNothing);
      expect(bio.pedidos, 0);
      await salir(t);
    });
  });

  group('captura rápida', () {
    Future<(FakeBackend, ProviderContainer)> abrir(WidgetTester t, {ReconocedorVoz? voz}) async {
      pantalla(t);
      final backend = FakeBackend();
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), voz: voz), child: const AgendaApp()));
      await esperar(t, 20);
      return (backend, ProviderScope.containerOf(t.element(find.byType(MaterialApp).first)));
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'escribir un gasto: vista previa y guardar', (t) async {
      final (backend, _) = await abrir(t);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t);
      expect(find.text('Registrar rápido'), findsOneWidget);

      await t.enterText(find.byType(TextField).last, 'almuerzo 25 mil');
      await esperar(t, 4);
      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('\$ 25.000'), findsOneWidget);
      expect(find.textContaining('Almuerzo'), findsOneWidget);

      await t.tap(find.text('Guardar'));
      await esperar(t);
      expect(find.text('Registrar rápido'), findsNothing);
      final tx = backend.transacciones.single;
      expect((tx['descripcion'], tx['tipo'], double.parse('${tx['monto']}'), tx['categoria']), ('Almuerzo', 'gasto', 25000.0, 'comida'));
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'un evento dicho en voz alta queda en el calendario', (t) async {
      final voz = VozFalsa();
      final (backend, _) = await abrir(t, voz: voz);
      await t.tap(find.byTooltip('Dictar'));
      await esperar(t);
      voz.alTexto!('cita con Ana mañana 3pm');
      await esperar(t, 4);
      expect(find.text('Evento'), findsOneWidget);
      expect(find.text('Cita con Ana'), findsOneWidget);
      voz.alTerminar!();
      await esperar(t, 2);

      await t.tap(find.text('Guardar'));
      await esperar(t);
      final e = backend.eventos.single;
      expect((e['titulo'], e['fecha'], '${e['hora']}'.substring(0, 5)), ('Cita con Ana', sumarDiasYmd(hoyYmd(), 1), '15:00'));
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), '"Editar" pasa lo entendido al formulario completo', (t) async {
      await abrir(t);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t);
      await t.enterText(find.byType(TextField).last, 'dentista mañana a las 10');
      await esperar(t, 4);
      await t.tap(find.text('Editar'));
      await esperar(t);
      expect(find.text('Registrar rápido'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Dentista'), findsOneWidget);
      await salir(t);
    });

    Future<(FakeBackend, ProviderContainer)> conHistorial(WidgetTester t) async {
      pantalla(t);
      final backend = FakeBackend();
      final hoy = hoyYmd();
      final c0 = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
      await t.runAsync(() async {
        await c0.read(sesionProvider.future);
        final fi = c0.read(financeRepoProvider);
        final ah = await fi.crearCuenta(const CuentaInput(nombre: 'Nequi', tipo: 'ahorros', saldo: 500000));
        for (var i = 1; i <= 4; i++) {
          await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 25000, descripcion: 'Almuerzo', fecha: sumarDiasYmd(hoy, -i), cuentaId: ah, categoria: 'comida'));
        }
        for (final i in [7, 14]) {
          await c0.read(eventsRepoProvider).crear(EventoInput(titulo: 'Clase de inglés', fecha: sumarDiasYmd(hoy, -i), hora: '18:30'));
        }
      });
      c0.dispose();
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
      await esperar(t, 20);
      return (backend, ProviderScope.containerOf(t.element(find.byType(MaterialApp).first)));
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'lo más registrado sale abajo y se repite con su cuenta, categoría y monto', (t) async {
      final (backend, _) = await conHistorial(t);
      final antes = backend.transacciones.length;
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      expect(find.text('Lo que más registras'), findsOneWidget);
      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('Clase de inglés'), findsOneWidget);
      expect(find.text('almuerzo 25 mil'), findsNothing);
      // Sin teclado encima, para que la lista se vea.
      expect(t.testTextInput.isVisible, isFalse);

      await t.tap(find.text('Almuerzo'));
      await esperar(t, 6);
      expect(find.text('Lo que más registras'), findsNothing);
      expect(find.textContaining('Nequi'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextFormField, 'Monto'), '30000');
      await t.tap(find.text('Ayer'));
      await esperar(t, 2);
      await t.tap(find.text('Guardar'));
      await esperar(t);
      expect(find.text('Registrar rápido'), findsNothing);
      expect(backend.transacciones.length, antes + 1);
      final tx = backend.transacciones.last;
      expect((tx['descripcion'], tx['tipo'], double.parse('${tx['monto']}'), tx['categoria'], tx['fecha']), ('Almuerzo', 'gasto', 30000.0, 'comida', sumarDiasYmd(hoyYmd(), -1)));
      expect(tx['cuenta_id'], isNotNull);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'un evento frecuente conserva su hora y se puede agendar para mañana', (t) async {
      final (backend, _) = await conHistorial(t);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      await t.tap(find.text('Clase de inglés'));
      await esperar(t, 6);
      expect(find.widgetWithText(TextFormField, 'Monto'), findsNothing);
      await t.tap(find.text('Mañana'));
      await esperar(t, 2);
      await t.tap(find.text('Guardar'));
      await esperar(t);
      final e = backend.eventos.last;
      expect((e['titulo'], e['fecha'], '${e['hora']}'.substring(0, 5)), ('Clase de inglés', sumarDiasYmd(hoyYmd(), 1), '18:30'));
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'al escribir propone lo que coincide, y se puede volver a la lista', (t) async {
      await conHistorial(t);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      await t.enterText(find.byType(TextField).last, 'alm');
      await esperar(t, 4);
      expect(find.text('¿Es uno de estos?'), findsOneWidget);
      expect(find.text('Clase de inglés'), findsNothing);
      await t.tap(find.text('Almuerzo'));
      await esperar(t, 6);
      expect(find.text('Revisa y guarda'), findsOneWidget);
      await t.tap(find.text('Cambiar'));
      await esperar(t, 6);
      expect(find.text('Lo que más registras'), findsOneWidget);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'sin historial muestra los ejemplos y abre el teclado', (t) async {
      await abrir(t);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      expect(find.text('Lo que más registras'), findsNothing);
      expect(find.text('almuerzo 25 mil'), findsOneWidget);
      expect(t.testTextInput.isVisible, isTrue);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'sin el módulo de Finanzas no sugiere sus movimientos', (t) async {
      final (_, c) = await conHistorial(t);
      await t.runAsync(() => c.read(ajustesRepoProvider).setModulos({AppModule.eventos}));
      await esperar(t, 6);
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      expect(find.text('Almuerzo'), findsNothing);
      expect(find.text('Clase de inglés'), findsOneWidget);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'si el servidor no responde, la captura sigue funcionando', (t) async {
      final (backend, _) = await conHistorial(t);
      backend.caido = true;
      await t.tap(find.text('Escribe o di lo que quieras registrar…'));
      await esperar(t, 8);
      expect(find.text('Registrar rápido'), findsOneWidget);
      expect(find.text('almuerzo 25 mil'), findsOneWidget);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'si la app arranca desde el widget, también abre la captura', (t) async {
      pantalla(t);
      await t.pumpWidget(ProviderScope(
        overrides: [
          ...overridesDePrueba(backend: FakeBackend(), db: dbEnMemoria()),
          capturaPendienteProvider.overrideWith(CapturaYaPedida.new),
        ],
        child: const AgendaApp(),
      ));
      await esperar(t, 24);
      expect(find.text('Registrar rápido'), findsOneWidget);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'el enlace del widget abre la captura', (t) async {
      final (_, c) = await abrir(t);
      c.read(routerProvider).go('/capturar');
      await esperar(t);
      expect(find.text('Registrar rápido'), findsOneWidget);
      expect(c.read(routerProvider).state.uri.path, '/hoy');
      await salir(t);
    });
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'widgets: publica el resumen y lo vacía al cerrar sesión', (t) async {
    pantalla(t);
    final backend = FakeBackend();
    final pub = PublicadorFalso();
    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), publicador: pub), child: const AgendaApp()));
    await esperar(t, 20);
    final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
    expect(pub.ultimo, isNotNull);
    expect(pub.ultimo!.gastoMes, '\$ 0');

    await t.runAsync(() => c.read(ajustesRepoProvider).setModulos(const {}));
    await esperar(t, 6);
    expect(pub.ultimo!.gastoMes, '', reason: 'sin Finanzas no muestra gastos');
    await salir(t);
  });
}
