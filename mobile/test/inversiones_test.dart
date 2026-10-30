// Inversiones y patrimonio: cuentas del valor y la ganancia, efecto en los saldos
// contra el backend falso, el gráfico de patrimonio y la pantalla.

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/finance/finance_logic.dart';
import 'package:agendaservi/features/finance/finance_providers.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_logica.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/harness.dart';
import 'support/fake_backend.dart';

MovimientoInversion mov(int id, TipoMovimiento tipo, double monto, String fecha, {int? cuenta}) =>
    MovimientoInversion(id: id, tipo: tipo, monto: monto, fecha: fecha, cuentaId: cuenta);

Inversion inv(List<MovimientoInversion> movimientos) => Inversion(id: 1, nombre: 'Novillos', tipo: 'ganado', movimientos: movimientos);

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  group('valor y ganancia', () {
    test('lo invertido es el valor hasta que se actualice', () {
      final i = inv([mov(1, TipoMovimiento.aporte, 4000000, '2026-01-10'), mov(2, TipoMovimiento.aporte, 1000000, '2026-02-10')]);
      expect((i.valor, i.invertido, i.ganancia, i.vendida, i.desde), (5000000.0, 5000000.0, 0.0, false, '2026-01-10'));
    });

    test('actualizar el valor muestra la ganancia, sin contar como dinero recibido', () {
      final i = inv([mov(1, TipoMovimiento.aporte, 4000000, '2026-01-10'), mov(2, TipoMovimiento.valoracion, 6000000, '2026-06-01')]);
      expect((i.valor, i.recibido, i.ganancia, i.rentabilidad), (6000000.0, 0.0, 2000000.0, 50.0));
    });

    test('aportar después de actualizar suma sobre el valor nuevo', () {
      final i = inv([
        mov(1, TipoMovimiento.aporte, 4000000, '2026-01-10'),
        mov(2, TipoMovimiento.valoracion, 6000000, '2026-06-01'),
        mov(3, TipoMovimiento.aporte, 1000000, '2026-07-01'),
      ]);
      expect((i.valor, i.invertido, i.ganancia), (7000000.0, 5000000.0, 2000000.0));
    });

    test('vender una parte baja el valor; vender todo la cierra con su resultado', () {
      final parte = inv([mov(1, TipoMovimiento.aporte, 4000000, '2026-01-10'), mov(2, TipoMovimiento.retiro, 1500000, '2026-03-01')]);
      expect((parte.valor, parte.recibido, parte.ganancia, parte.vendida), (2500000.0, 1500000.0, 0.0, false));

      final todo = inv([mov(1, TipoMovimiento.aporte, 4000000, '2026-01-10'), mov(2, TipoMovimiento.venta, 3000000, '2026-03-01')]);
      expect((todo.valor, todo.recibido, todo.ganancia, todo.vendida), (0.0, 3000000.0, -1000000.0, true));
    });

    test('el valor no baja de cero aunque se venda por más', () {
      expect(inv([mov(1, TipoMovimiento.aporte, 100, '2026-01-10'), mov(2, TipoMovimiento.retiro, 900, '2026-03-01')]).valor, 0);
    });

    test('registrar en desorden: manda la fecha, no el orden en que se escribió', () {
      final i = inv([mov(5, TipoMovimiento.valoracion, 9000, '2026-06-01'), mov(6, TipoMovimiento.aporte, 1000, '2026-01-01')]);
      expect(i.valor, 9000);
      expect(i.valorEn('2026-03-01'), 1000);
      expect(i.valorEn('2025-12-31'), 0);
    });
  });

  group('patrimonio', () {
    const cuentas = [Cuenta(id: 1, nombre: 'Ahorros', tipo: 'ahorros', saldo: 6000000), Cuenta(id: 2, nombre: 'Visa', tipo: 'tarjeta_credito', saldo: 500000)];

    test('suma las inversiones y resta las deudas', () {
      final r = ResumenFinanciero(cuentas: cuentas, txMes: const [], inversiones: 4000000);
      expect((r.ahorros, r.patrimonio), (6000000.0, 9500000.0));
    });

    test('gráfico: invertir de una cuenta no cambia el patrimonio ese día; una valorización sí', () {
      final hoy = hoyYmd();
      final hace10 = sumarDiasYmd(hoy, -10);
      final hace5 = sumarDiasYmd(hoy, -5);
      final a = Analitica(
        cuentas: cuentas,
        transacciones: const [],
        rango: RangoAnalitica.values.last,
        inversiones: [
          inv([mov(1, TipoMovimiento.aporte, 4000000, hace10, cuenta: 1), mov(2, TipoMovimiento.valoracion, 7000000, hace5)]),
        ],
      );
      double en(String f) => a.patrimonio.firstWhere((p) => p.fecha == f).valor;
      final hoyValor = en(hoy);
      expect(hoyValor, 12500000);
      expect(en(hace5), 12500000);
      expect(en(sumarDiasYmd(hoy, -6)), 9500000, reason: 'antes de valorizarse valía lo invertido');
      expect(en(hace10), 9500000, reason: 'el dinero pasó de la cuenta a la inversión');
      expect(en(sumarDiasYmd(hoy, -11)), 9500000, reason: 'antes de invertir ya era patrimonio, en la cuenta');
    });
  });

  group('historial', () {
    const cuentas = [Cuenta(id: 1, nombre: 'Ahorros', tipo: 'ahorros'), Cuenta(id: 2, nombre: 'Addi', tipo: 'tarjeta_credito')];

    test('muestra abonos e inversiones que movieron dinero, en su mes', () {
      final lista = traspasosDelMes(
        transferencias: const [
          Transferencia(id: 1, cuentaOrigenId: 1, cuentaDestinoId: 2, monto: 200000, descripcion: 'Pago: Cuota', fecha: '2026-10-18'),
        ],
        inversiones: [
          inv([
            mov(1, TipoMovimiento.aporte, 4000000, '2026-10-05', cuenta: 1),
            mov(2, TipoMovimiento.valoracion, 5000000, '2026-10-06'),
            mov(3, TipoMovimiento.aporte, 900000, '2026-10-07'),
            mov(4, TipoMovimiento.venta, 6000000, '2026-11-01', cuenta: 1),
          ]),
        ],
        cuentas: cuentas,
        prefijoMes: '2026-10',
      );
      expect(lista.map((t) => t.titulo), ['Abono a Addi', 'Inversión: Novillos']);
      expect(lista.first.detalle, 'Desde Ahorros · Pago: Cuota');
      expect((lista.first.fecha, lista.first.monto), ('2026-10-18', 200000.0));
    });

    test('una transferencia a una cuenta normal no se llama abono', () {
      final lista = traspasosDelMes(
        transferencias: const [Transferencia(id: 1, cuentaOrigenId: 2, cuentaDestinoId: 1, monto: 5, descripcion: '', fecha: '2026-10-18T05:00:00.000Z')],
        inversiones: const [],
        cuentas: cuentas,
        prefijoMes: '2026-10',
      );
      expect((lista.single.titulo, lista.single.fecha), ('Transferencia a Ahorros', '2026-10-18'));
    });
  });

  group('contra el servidor', () {
    late ProviderContainer c;
    late FakeBackend backend;
    late int ahorros;
    late int visa;

    setUp(() async {
      final (cc, b) = await contenedor();
      c = cc;
      backend = b;
      addTearDown(c.dispose);
      c.listen(inversionesProvider, (_, _) {});
      c.listen(cuentasProvider, (_, _) {});
      await c.read(inversionesProvider.future);
      final fi = c.read(financeRepoProvider);
      ahorros = await fi.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 10000000));
      visa = await fi.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 5000000));
    });

    double saldo(int id) => c.read(cuentasProvider).value!.firstWhere((x) => x.id == id).saldo;

    test('invertir guarda fecha y monto y descuenta de la cuenta, sin crear un gasto', () async {
      await c.read(inversionesRepoProvider).crear(nombre: 'Novillos', tipo: 'ganado', monto: 4000000, fecha: '2026-03-15', cuentaId: ahorros);
      final i = c.read(inversionesProvider).value!.single;
      expect((i.nombre, i.invertido, i.desde), ('Novillos', 4000000.0, '2026-03-15'));
      expect(i.movimientos.single.cuentaNombre, 'Ahorros');
      expect(saldo(ahorros), 6000000);
      expect(backend.transacciones, isEmpty, reason: 'no cuenta como gasto del mes');
      expect(c.read(valorInversionesProvider), 4000000);
    });

    test('si ya la tenía no toca ninguna cuenta', () async {
      await c.read(inversionesRepoProvider).crear(nombre: 'Casa', tipo: 'inmueble', monto: 200000000, fecha: '2020-01-10');
      expect(saldo(ahorros), 10000000);
      expect(c.read(valorInversionesProvider), 200000000);
    });

    test('con tarjeta de crédito aumenta la deuda', () async {
      await c.read(inversionesRepoProvider).crear(nombre: 'Moto', tipo: 'vehiculo', monto: 1000000, fecha: '2026-01-10', cuentaId: visa);
      expect(saldo(visa), 1000000);
    });

    test('vender devuelve el dinero; borrar y corregir dejan las cuentas cuadradas', () async {
      final repo = c.read(inversionesRepoProvider);
      final id = await repo.crear(nombre: 'Novillos', tipo: 'ganado', monto: 4000000, fecha: '2026-01-10', cuentaId: ahorros);
      await repo.agregarMovimiento(id, tipo: TipoMovimiento.venta, monto: 5000000, fecha: '2026-06-01', cuentaId: ahorros);
      expect(saldo(ahorros), 11000000);
      var i = c.read(inversionesProvider).value!.single;
      expect((i.vendida, i.ganancia), (true, 1000000.0));

      await repo.actualizarMovimiento(i.movimientos.last.id, tipo: TipoMovimiento.venta, monto: 4500000, fecha: '2026-06-02', cuentaId: ahorros);
      expect(saldo(ahorros), 10500000);

      i = c.read(inversionesProvider).value!.single;
      await repo.eliminarMovimiento(i.movimientos.last.id);
      expect(saldo(ahorros), 6000000);
      expect(c.read(inversionesProvider).value!.single.vendida, isFalse);

      await repo.eliminar(id);
      expect(saldo(ahorros), 10000000, reason: 'borrarla devuelve lo que se sacó');
      expect(c.read(inversionesProvider).value, isEmpty);
    });

    test('monto inválido no llega al servidor', () {
      expect(() => c.read(inversionesRepoProvider).crear(nombre: 'X', tipo: 'otro', monto: 0, fecha: '2026-01-10'), throwsA(isA<FinanzasError>()));
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

    for (final (nombre, tam, escala) in [('teléfono', const Size(390, 844), 1.0), ('pequeño con texto grande', const Size(360, 640), 1.35)]) {
      testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'registrar y actualizar una inversión en $nombre', (t) async {
        t.view.physicalSize = tam;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        t.platformDispatcher.textScaleFactorTestValue = escala;
        addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
        final backend = FakeBackend();
        await t.runAsync(() async {
          final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
          c.listen(cuentasProvider, (_, _) {});
          await c.read(financeRepoProvider).crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 10000000));
          c.dispose();
        });

        await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
        await esperar(t, 20);
        final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));

        // Desde Finanzas se llega con un toque.
        await t.tap(find.text('Finanzas').last);
        await esperar(t);
        await t.ensureVisible(find.text('Inversiones'));
        await esperar(t, 4);
        await t.tap(find.text('Inversiones'));
        await esperar(t, 16);
        expect(find.text('Registra tu primera inversión'), findsOneWidget);
        expect(c.read(routerProvider).state.uri.path, rutaInversiones);

        // Nueva: ganado, 4 millones, sale de Ahorros.
        await t.tap(find.text('Nueva inversión').last);
        await esperar(t);
        await t.tap(find.text('Registrar inversión'));
        await esperar(t, 4);
        expect(find.text('Escribe un nombre para la inversión'), findsOneWidget);
        expect(find.text('Escribe el monto invertido'), findsOneWidget);

        await t.enterText(find.byType(TextFormField).at(0), 'Novillos');
        await t.enterText(find.byType(TextFormField).at(1), '4000000');
        await esperar(t, 2);
        final selector = find.byType(DropdownButtonFormField<int?>);
        await t.ensureVisible(selector);
        await esperar(t, 4);
        await t.tap(selector);
        await esperar(t, 6);
        await t.tap(find.textContaining('Ahorros ·').last);
        await esperar(t, 6);
        await t.ensureVisible(find.text('Registrar inversión'));
        await t.tap(find.text('Registrar inversión'));
        await esperar(t);

        expect(find.text('Novillos'), findsOneWidget);
        expect(find.text('Registrar inversión'), findsNothing);
        final m = (backend.inversiones.single['movimientos'] as List).single as Map;
        expect((m['tipo'], m['monto'], m['fecha']), ('aporte', 4000000.0, hoyYmd()));
        expect(backend.transacciones, isEmpty);
        expect(backend.cuentas.single['saldo'].toString(), startsWith('6000000'));

        // Abre el detalle y actualiza lo que vale hoy.
        await t.ensureVisible(find.text('Novillos'));
        await esperar(t, 4);
        await t.tap(find.text('Novillos'));
        await esperar(t);
        await t.ensureVisible(find.text('Actualizar valor'));
        await t.tap(find.text('Actualizar valor'));
        await esperar(t);
        await t.enterText(find.byType(TextFormField).first, '5000000');
        await esperar(t, 2);
        await t.tap(find.text('Registrar'));
        await esperar(t);
        expect(c.read(inversionesProvider).value!.single.ganancia, 1000000);
        expect(find.text('Valor actualizado', skipOffstage: false), findsOneWidget);
        expect(backend.cuentas.single['saldo'].toString(), startsWith('6000000'), reason: 'no mueve dinero');
        await salir(t);
      });
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'si el servidor aún no la tiene: Finanzas sigue bien y la pantalla ofrece reintentar', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final backend = FakeBackend()..sinInversiones = true;
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
      await esperar(t, 20);
      await t.tap(find.text('Finanzas').last);
      await esperar(t);
      expect(find.text('Patrimonio neto'), findsOneWidget);
      final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
      c.read(routerProvider).push(rutaInversiones);
      await esperar(t, 16);
      expect(find.text('Reintentar'), findsOneWidget);
      await salir(t);
    });
  });
}
