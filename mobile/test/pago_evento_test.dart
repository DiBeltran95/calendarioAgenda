// Confirmar el pago de un evento: se elige de dónde salió el dinero, la deuda de
// una compra a crédito baja y todo se puede deshacer.

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_providers.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  Map<String, dynamic> cuentaDe(FakeBackend b, int id) => b.cuentas.firstWhere((c) => c['id'] == id);
  double saldo(FakeBackend b, int id) => double.parse('${cuentaDe(b, id)['saldo']}');

  group('repositorio', () {
    late ProviderContainer c;
    late FakeBackend backend;
    late int ahorros;
    late int addi;
    late Evento cuota;

    setUp(() async {
      final (cc, b) = await contenedor();
      c = cc;
      backend = b;
      addTearDown(c.dispose);
      c.listen(cuentasProvider, (_, _) {});
      final fi = c.read(financeRepoProvider);
      ahorros = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 1000000));
      addi = await fi.crearCuenta(const CuentaInput(nombre: 'Addi', tipo: 'tarjeta_credito', limite: 2000000));
      await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 600000, descripcion: 'Celular', fecha: hoyYmd(), cuentaId: addi, cuotas: 3));
      final e = backend.eventos.firstWhere((x) => x['tarjeta_credito_id'] == addi);
      cuota = Evento.fromJson(e);
    });

    test('pagar una cuota baja la deuda y sale de la cuenta, sin sumar un gasto', () async {
      final deuda = saldo(backend, addi);
      final gastos = backend.transacciones.length;
      await c.read(eventsRepoProvider).pagar(cuota, cuentaId: ahorros, monto: 200000, fecha: '2026-10-18');
      expect(saldo(backend, addi), deuda - 200000);
      expect(saldo(backend, ahorros), 800000);
      expect(backend.transacciones.length, gastos, reason: 'la compra ya se contó como gasto');
      expect(backend.transferencias.single['fecha'], '2026-10-18');
    });

    test('deshacer devuelve los saldos y avisa que devolvió', () async {
      final deuda = saldo(backend, addi);
      await c.read(eventsRepoProvider).pagar(cuota, cuentaId: ahorros, monto: 200000);
      expect(await c.read(eventsRepoProvider).quitarPago(cuota), isTrue);
      expect(saldo(backend, addi), deuda);
      expect(saldo(backend, ahorros), 1000000);
      expect(backend.transferencias, isEmpty);
    });

    test('un pago marcado antes de esta función se reabre sin tocar saldos y se paga bien', () async {
      final deuda = saldo(backend, addi);
      await c.read(eventsRepoProvider).alternarPago(cuota);
      expect(await c.read(eventsRepoProvider).quitarPago(cuota.copyWith(estadoPago: 'pagado')), isFalse);
      expect(saldo(backend, addi), deuda);
      await c.read(eventsRepoProvider).pagar(cuota, cuentaId: ahorros, monto: 200000);
      expect(saldo(backend, addi), deuda - 200000);
    });
  });

  group('pantalla', () {
    Future<void> esperar(WidgetTester t, [int vueltas = 14]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> salir(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    }

    /// Un evento de gasto para hoy: aparece en "Pagos de la semana" de Hoy.
    Future<(FakeBackend, int, int?)> preparar(WidgetTester t, {bool conCuenta = true, bool cuota = false}) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final backend = FakeBackend();
      var ahorros = 0;
      int? addi;
      await t.runAsync(() async {
        final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
        c.listen(cuentasProvider, (_, _) {});
        final fi = c.read(financeRepoProvider);
        if (conCuenta) ahorros = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 1000000));
        if (cuota) {
          addi = await fi.crearCuenta(const CuentaInput(nombre: 'Addi', tipo: 'tarjeta_credito', limite: 2000000));
          await fi.crearTransaccion(TransaccionInput(tipo: 'gasto', monto: 600000, descripcion: 'Celular', fecha: hoyYmd(), cuentaId: addi, cuotas: 3));
          final e = backend.eventos.firstWhere((x) => x['tarjeta_credito_id'] == addi);
          e['fecha'] = hoyYmd();
          e['titulo'] = 'Cuota Addi';
        } else {
          await c.read(eventsRepoProvider).crear(EventoInput(titulo: 'Arriendo', fecha: hoyYmd(), categoria: 'arriendo', tipoTransaccion: 'gasto', costo: 300000));
        }
        c.dispose();
      });
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
      await esperar(t, 20);
      return (backend, ahorros, addi);
    }

    Future<void> tocarPago(WidgetTester t) async {
      final boton = find.byTooltip('Marcar como pagado');
      await t.ensureVisible(boton.first);
      await esperar(t, 4);
      await t.tap(boton.first);
      await esperar(t);
    }

    Future<void> elegirCuenta(WidgetTester t, String nombre) async {
      final selector = find.byType(DropdownButtonFormField<int?>);
      await t.ensureVisible(selector);
      await esperar(t, 4);
      await t.tap(selector);
      await esperar(t, 6);
      await t.tap(find.textContaining('$nombre ·').last);
      await esperar(t, 6);
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'cuota de crédito: pide la cuenta, explica y baja la deuda', (t) async {
      final (backend, ahorros, addi) = await preparar(t, cuota: true);
      final deuda = saldo(backend, addi!);
      await tocarPago(t);

      expect(find.text('Confirmar pago'), findsOneWidget);
      expect(find.textContaining('La deuda de Addi baja'), findsOneWidget);

      // Sin elegir cuenta no se guarda.
      await t.ensureVisible(find.text('Registrar pago'));
      await t.tap(find.text('Registrar pago'));
      await esperar(t, 4);
      expect(find.text('Elige de qué cuenta salió'), findsOneWidget);
      expect(saldo(backend, addi), deuda);

      await elegirCuenta(t, 'Ahorros');
      await t.ensureVisible(find.text('Registrar pago'));
      await t.tap(find.text('Registrar pago'));
      await esperar(t);
      expect(find.text('Confirmar pago'), findsNothing);
      expect(saldo(backend, addi), deuda - 200000);
      expect(saldo(backend, ahorros), 800000);

      // El abono se ve en el historial, sin contar como gasto.
      await t.tap(find.text('Finanzas').last);
      await esperar(t);
      // Deja lo buscado en la parte alta: abajo lo tapan los botones flotantes.
      Future<void> mostrar(Finder f) async {
        final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
        await t.scrollUntilVisible(f, 200, scrollable: lista.last, maxScrolls: 40);
        await esperar(t, 2);
        Scrollable.ensureVisible(t.element(f), alignment: 0.25);
        await esperar(t, 4);
      }

      await mostrar(find.text('Historial'));
      await t.tap(find.text('Historial'));
      await esperar(t);
      await mostrar(find.text('Abono a Addi'));
      expect(find.text('Abono a Addi'), findsOneWidget);
      expect(find.textContaining('Desde Ahorros'), findsOneWidget);
      expect(find.textContaining('Pago: Cuota Addi'), findsOneWidget);

      // Filtrar por gastos lo oculta; por abonos, solo queda él.
      await mostrar(find.text('Gastos'));
      await t.tap(find.text('Gastos'));
      await esperar(t, 6);
      expect(find.text('Abono a Addi'), findsNothing);
      await t.tap(find.text('Abonos y traspasos'));
      await esperar(t, 6);
      expect(find.text('Abono a Addi'), findsOneWidget);
      expect(find.text('Celular'), findsNothing);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'gasto normal: se registra en la cuenta elegida', (t) async {
      final (backend, ahorros, _) = await preparar(t);
      await tocarPago(t);
      expect(find.textContaining('La deuda de'), findsNothing);
      await elegirCuenta(t, 'Ahorros');
      await t.ensureVisible(find.text('Registrar pago'));
      await t.tap(find.text('Registrar pago'));
      await esperar(t);
      expect(saldo(backend, ahorros), 700000);
      expect(backend.transacciones.single['descripcion'], 'Arriendo');
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'solo marcar no mueve dinero', (t) async {
      final (backend, ahorros, _) = await preparar(t);
      await tocarPago(t);
      final solo = find.textContaining('Solo marcar como pagado');
      await t.ensureVisible(solo);
      await esperar(t, 4);
      await t.tap(solo);
      await esperar(t);
      expect(backend.eventos.single['estado_pago'], 'pagado');
      expect(saldo(backend, ahorros), 1000000);
      expect(backend.transacciones, isEmpty);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'sin cuentas (solo usa la agenda): se marca de una vez', (t) async {
      final (backend, _, _) = await preparar(t, conCuenta: false);
      await tocarPago(t);
      expect(find.text('Confirmar pago'), findsNothing);
      expect(backend.eventos.single['estado_pago'], 'pagado');
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'si el servidor aún no se actualiza, avisa y no marca nada', (t) async {
      final (backend, ahorros, _) = await preparar(t);
      backend.sinPagoEventos = true;
      await tocarPago(t);
      await elegirCuenta(t, 'Ahorros');
      await t.ensureVisible(find.text('Registrar pago'));
      await t.tap(find.text('Registrar pago'));
      await esperar(t);
      expect(find.text('Confirmar pago'), findsOneWidget, reason: 'la hoja sigue abierta');
      expect(backend.eventos.single['estado_pago'], 'pendiente');
      expect(saldo(backend, ahorros), 1000000);
      await salir(t);
    });
  });
}
