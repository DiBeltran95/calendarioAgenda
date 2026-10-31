// Préstamos, dólares y ganancias diarias: las cuentas, el efecto en los saldos
// contra el backend falso, el patrimonio y las tarjetas de Cuentas.

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/money.dart';
import 'package:agendaservi/core/widgets/fields.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/finance/finance_logic.dart';
import 'package:agendaservi/features/finance/finance_providers.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_logica.dart';
import 'package:agendaservi/features/finance/inversiones/inversiones_repository.dart';
import 'package:agendaservi/features/finance/prestamos/prestamos_logica.dart';
import 'package:agendaservi/features/finance/prestamos/prestamos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

MovimientoPrestamo mov(int id, String tipo, double capital, String fecha, {double interes = 0, int? cuenta}) =>
    MovimientoPrestamo(id: id, tipo: tipo, capital: capital, interes: interes, fecha: fecha, cuentaId: cuenta);

MovimientoInversion compra(int id, double pesos, double dolares, String fecha, {TipoMovimiento tipo = TipoMovimiento.aporte}) =>
    MovimientoInversion(id: id, tipo: tipo, monto: pesos, montoUsd: dolares, fecha: fecha);

void main() {
  setUpAll(() async => initializeDateFormatting('es_CO'));

  group('préstamo', () {
    test('sin intereses: lo que debe es lo que falta de capital', () {
      final p = Prestamo(id: 1, persona: 'Ana', movimientos: [mov(1, 'desembolso', 1000000, '2026-10-01'), mov(2, 'abono', 400000, '2026-10-20')]);
      expect((p.prestado, p.cobrado, p.capitalPendiente, p.pendiente, p.pagado, p.activo, p.gananciaDiaria), (1000000.0, 400000.0, 600000.0, 600000.0, false, true, 0.0));
      expect(p.progreso, closeTo(0.4, 0.001));
    });

    test('con intereses: lo ganado suma a lo que debe; cobrarlo lo baja', () {
      final p = Prestamo(id: 1, persona: 'Ana', tasaMensual: 3, interesDesde: '2026-10-01', interesCausado: 30000, movimientos: [
        mov(1, 'desembolso', 1000000, '2026-10-01'),
        mov(2, 'abono', 100000, '2026-10-20', interes: 20000),
      ]);
      expect((p.capitalPendiente, p.interesPendiente, p.pendiente), (900000.0, 10000.0, 910000.0));
      expect(p.gananciaDiaria, closeTo(900, 0.01));
    });

    test('pagado todo deja de contar; lo mismo si se deja de cobrar', () {
      final movs = [mov(1, 'desembolso', 100000, '2026-10-01'), mov(2, 'abono', 100000, '2026-10-20')];
      expect(Prestamo(id: 1, persona: 'Ana', movimientos: movs).pagado, isTrue);
      expect(Prestamo(id: 1, persona: 'Ana', movimientos: movs).pendiente, 0);
      final cerrado = Prestamo(id: 2, persona: 'Ana', cerradoEn: '2026-10-25', movimientos: [mov(1, 'desembolso', 100000, '2026-10-01')]);
      expect((cerrado.activo, cerrado.pendiente), (false, 0.0));
      expect(porCobrarTotal([cerrado, Prestamo(id: 3, persona: 'B', movimientos: [mov(2, 'desembolso', 5000, '2026-10-01')])]), 5000);
    });

    test('los centavos de los redondeos de cada día no lo dejan abierto', () {
      final p = Prestamo(id: 1, persona: 'Ana', tasaMensual: 2, interesCausado: 100.4, movimientos: [mov(1, 'desembolso', 1000, '2026-10-01'), mov(2, 'abono', 1000, '2026-10-20', interes: 100)]);
      expect(p.pagado, isTrue);
    });

    test('la fecha de pago y las iniciales', () {
      final p = Prestamo(id: 1, persona: 'Ana María Gómez', vencimiento: '2026-10-20', movimientos: const []);
      expect(p.diasParaVencer(hoy: '2026-10-18'), 2);
      expect(p.diasParaVencer(hoy: '2026-10-25'), -5);
      expect((iniciales('Ana María Gómez'), iniciales('carlos'), iniciales('  ')), ('AM', 'C', '?'));
    });
  });

  group('dólares', () {
    Inversion arq(List<MovimientoInversion> m) => Inversion(id: 1, nombre: 'ARQ', tipo: 'dolares', movimientos: m);

    test('se cuentan los dólares y el valor sale del dólar más reciente', () {
      final i = arq([compra(1, 400000, 100, '2026-01-10'), compra(2, 420000, 100, '2026-02-10')]);
      expect((i.usd, i.usdComprados, i.invertido, i.tasaActual, i.dolarPromedio), (200.0, 200.0, 820000.0, 4200.0, 4100.0));
      expect((i.valor, i.ganancia), (840000.0, 20000.0));
      expect((i.usdEn('2026-01-31'), i.valorEn('2026-01-31')), (100.0, 400000.0));
    });

    test('actualizar el saldo cambia los dólares y el valor, no lo pagado', () {
      final i = arq([compra(1, 400000, 100, '2026-01-10'), compra(2, 450000, 105, '2026-06-01', tipo: TipoMovimiento.valoracion)]);
      expect((i.usd, i.usdComprados, i.invertido), (105.0, 100.0, 400000.0));
      expect(i.valor, closeTo(450000, 0.01));
      expect(i.ganancia, closeTo(50000, 0.01));
    });

    test('vender una parte o todo', () {
      final parte = arq([compra(1, 400000, 100, '2026-01-10'), compra(2, 210000, 50, '2026-03-01', tipo: TipoMovimiento.retiro)]);
      expect((parte.usd, parte.recibido), (50.0, 210000.0));
      expect(parte.valor, closeTo(210000, 0.01));
      final todo = arq([compra(1, 400000, 100, '2026-01-10'), compra(2, 430000, 100, '2026-03-01', tipo: TipoMovimiento.venta)]);
      expect((todo.usd, todo.valor, todo.vendida, todo.ganancia), (0.0, 0.0, true, 30000.0));
    });

    test('no se vuelve dólares lo que no lo es', () {
      final i = Inversion(id: 1, nombre: 'Novillos', tipo: 'ganado', movimientos: [compra(1, 400000, 100, '2026-01-10')]);
      expect((i.esDolares, i.valor), (false, 400000.0));
    });

    test('formato y campo con centavos', () {
      expect(usd(1250.5), r'US$ 1.250,50');
      expect(usd(0), r'US$ 0,00');
      expect(parseDecimal('1.250,5'), 1250.5);
      expect(decimalInicial(1250.5), '1.250,50');
      expect(decimalInicial(100), '100');
      expect(decimalInicial(0), '');
    });
  });

  group('patrimonio', () {
    test('lo que le deben suma', () {
      final r = ResumenFinanciero(cuentas: const [Cuenta(id: 1, nombre: 'A', tipo: 'ahorros', saldo: 1000)], txMes: const [], porCobrar: 500);
      expect(r.patrimonio, 1500);
    });

    test('la serie: prestar no cambia el patrimonio; los intereses lo suben cada día', () {
      const hoy = '2026-10-30';
      // Prestó 1.000 de la cuenta (tenía 5.000) el 25; gana 10 al día desde entonces.
      final a = Analitica(
        cuentas: const [Cuenta(id: 1, nombre: 'A', tipo: 'ahorros', saldo: 4000)],
        transacciones: [
          for (final d in ['2026-10-26', '2026-10-27', '2026-10-28', '2026-10-29', '2026-10-30'])
            Transaccion(id: d.hashCode, tipo: 'ingreso', monto: 10, descripcion: 'Intereses: Ana', fecha: d, categoria: categoriaIntereses),
        ],
        rango: RangoAnalitica.d7,
        prestamos: [
          Prestamo(id: 1, persona: 'Ana', tasaMensual: 30, interesDesde: '2026-10-25', interesCausado: 50, movimientos: [mov(1, 'desembolso', 1000, '2026-10-25', cuenta: 1)]),
        ],
        hoy: hoy,
      );
      final serie = {for (final p in a.patrimonio) p.fecha: p.valor};
      expect(serie['2026-10-24'], 5000, reason: 'antes de prestar');
      expect(serie['2026-10-25'], 5000, reason: 'prestar solo mueve el dinero');
      expect(serie['2026-10-26'], 5010);
      expect(serie[hoy], 5050);
    });

    test('la serie: al darlo por perdido baja ese día', () {
      final a = Analitica(
        cuentas: const [Cuenta(id: 1, nombre: 'A', tipo: 'ahorros', saldo: 4000)],
        transacciones: const [],
        rango: RangoAnalitica.d7,
        prestamos: [
          Prestamo(id: 1, persona: 'Ana', cerradoEn: '2026-10-28', movimientos: [mov(1, 'desembolso', 1000, '2026-10-01', cuenta: 1)]),
        ],
        hoy: '2026-10-30',
      );
      final serie = {for (final p in a.patrimonio) p.fecha: p.valor};
      expect(serie['2026-10-27'], 5000);
      expect(serie['2026-10-28'], 4000);
    });
  });

  group('marcas e historial', () {
    final p = Prestamo(id: 7, persona: 'Ana', movimientos: [mov(1, 'desembolso', 1000, '2026-10-05', cuenta: 1), mov(2, 'abono', 200, '2026-10-20', cuenta: 1, interes: 50)]);
    const cuentas = [Cuenta(id: 1, nombre: 'Ahorros', tipo: 'ahorros')];

    test('el calendario distingue los préstamos', () {
      final m = marcasDelMes(transacciones: const [], transferencias: const [], inversiones: const [], prestamos: [p], cuentas: cuentas, prefijoMes: '2026-10');
      expect(m['2026-10-05'], {MarcaDia.prestamo});
      expect(m['2026-10-20'], {MarcaDia.prestamo});
    });

    test('el historial muestra prestar y cobrar, con su detalle', () {
      final t = traspasosDelMes(transferencias: const [], inversiones: const [], prestamos: [p], cuentas: cuentas, prefijoMes: '2026-10');
      expect(t.map((x) => (x.titulo, x.monto, x.prestamoId)), [('Préstamo a Ana', 1000.0, 7), ('Abono de Ana', 250.0, 7)]);
      expect(t.last.detalle, contains('incluye'));
    });

    test('la compra de dólares dice cuántos', () {
      final i = Inversion(id: 3, nombre: 'ARQ', tipo: 'dolares', movimientos: [MovimientoInversion(id: 1, tipo: TipoMovimiento.aporte, monto: 400000, montoUsd: 100, fecha: '2026-10-05', cuentaId: 1)]);
      final t = traspasosDelMes(transferencias: const [], inversiones: [i], cuentas: cuentas, prefijoMes: '2026-10').single;
      expect(t.titulo, 'Compra de dólares: ARQ');
      expect(t.detalle, startsWith(r'US$ 100,00'));
    });
  });

  group('repositorio', () {
    late ProviderContainer c;
    late FakeBackend backend;
    late int ahorros;
    final hoy = hoyYmd();
    double saldo(int id) => double.parse('${backend.cuentas.firstWhere((x) => x['id'] == id)['saldo']}');
    Prestamo prestamo(int id) => c.read(prestamosProvider).value!.firstWhere((p) => p.id == id);

    setUp(() async {
      final (cc, b) = await contenedor();
      c = cc;
      backend = b;
      addTearDown(c.dispose);
      c.listen(cuentasProvider, (_, _) {});
      c.listen(prestamosProvider, (_, _) {});
      await c.read(prestamosProvider.future);
      ahorros = await c.read(financeRepoProvider).crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 1000000));
    });

    test('prestar sale de la cuenta; los intereses corren desde la fecha elegida', () async {
      final id = await c.read(prestamosRepoProvider).crear(persona: 'Ana', monto: 300000, fecha: sumarDiasYmd(hoy, -10), cuentaId: ahorros, tasaMensual: 3, interesDesde: sumarDiasYmd(hoy, -4));
      expect(saldo(ahorros), 700000);
      expect(prestamo(id).interesCausado, 1200);
      expect(prestamo(id).pendiente, 301200);
      expect(c.read(porCobrarProvider), 301200);
      expect(backend.transacciones.where((t) => t['categoria'] == categoriaIntereses).length, 4);
    });

    test('cobrar los intereses los pasa a la cuenta sin sumar otro ingreso', () async {
      final repo = c.read(prestamosRepoProvider);
      final id = await repo.crear(persona: 'Ana', monto: 300000, fecha: sumarDiasYmd(hoy, -4), cuentaId: ahorros, tasaMensual: 3, interesDesde: sumarDiasYmd(hoy, -4));
      final ingresos = backend.transacciones.length;
      await repo.agregarMovimiento(id, tipo: 'abono', capital: 100000, interes: 1200, fecha: hoy, cuentaId: ahorros);
      expect(saldo(ahorros), 801200);
      expect(backend.transacciones.length, ingresos);
      expect(prestamo(id).pendiente, 200000);
    });

    test('si fue un error y se elimina, se va todo', () async {
      final repo = c.read(prestamosRepoProvider);
      final id = await repo.crear(persona: 'Ana', monto: 300000, fecha: sumarDiasYmd(hoy, -4), cuentaId: ahorros, tasaMensual: 3, interesDesde: sumarDiasYmd(hoy, -4));
      await repo.eliminar(id);
      expect(saldo(ahorros), 1000000);
      expect(backend.transacciones.where((t) => t['categoria'] == categoriaIntereses), isEmpty);
      expect(c.read(prestamosProvider).value, isEmpty);
    });

    test('corregir la tasa rehace los intereses', () async {
      final repo = c.read(prestamosRepoProvider);
      final id = await repo.crear(persona: 'Ana', monto: 300000, fecha: sumarDiasYmd(hoy, -4), tasaMensual: 3, interesDesde: sumarDiasYmd(hoy, -4));
      await repo.actualizar(id, persona: 'Ana', tasaMensual: 6, interesDesde: sumarDiasYmd(hoy, -2));
      expect(prestamo(id).interesCausado, 1200);
    });

    test('dejar de cobrar lo saca del patrimonio; reabrir lo devuelve', () async {
      final repo = c.read(prestamosRepoProvider);
      final id = await repo.crear(persona: 'Ana', monto: 300000, fecha: hoy);
      await repo.cerrar(id, fecha: hoy);
      expect(c.read(porCobrarProvider), 0);
      await repo.reabrir(id);
      expect(c.read(porCobrarProvider), 300000);
    });

    test('si el servidor aún no lo tiene, no muestra el mensaje técnico', () async {
      backend.sinPrestamos = true;
      await expectLater(
        c.read(prestamosRepoProvider).crear(persona: 'Ana', monto: 1000, fecha: hoy),
        throwsA(isA<FinanzasError>().having((e) => e.mensaje, 'mensaje', contains('aún no están activos'))),
      );
    });

    test('ganancias de una cuenta: suben el saldo; apagarlas puede quitar lo sumado', () async {
      final fi = c.read(financeRepoProvider);
      await fi.activarGanancias(ahorros, tasa: 9, desde: sumarDiasYmd(hoy, -3));
      final cuenta = c.read(cuentasProvider).value!.firstWhere((x) => x.id == ahorros);
      expect((cuenta.generaGanancias, cuenta.gananciasTasa, cuenta.gananciasDesde), (true, 9.0, sumarDiasYmd(hoy, -3)));
      expect(saldo(ahorros), greaterThan(1000000));
      expect(backend.transacciones.where((t) => t['categoria'] == categoriaRendimientos).length, 3);
      await fi.apagarGanancias(ahorros, quitar: true);
      expect(saldo(ahorros), closeTo(1000000, 0.001));
      expect(backend.transacciones.where((t) => t['categoria'] == categoriaRendimientos), isEmpty);
    });

    test('compra de dólares: guarda los dólares y saca los pesos de la cuenta', () async {
      c.listen(inversionesProvider, (_, _) {});
      await c.read(inversionesProvider.future);
      final repo = c.read(inversionesRepoProvider);
      final id = await repo.crear(nombre: 'ARQ', tipo: 'dolares', monto: 410000, montoUsd: 100, fecha: hoy, cuentaId: ahorros);
      expect(saldo(ahorros), 590000);
      final i = c.read(inversionesProvider).value!.firstWhere((x) => x.id == id);
      expect((i.usd, i.valor, i.esDolares), (100.0, 410000.0, true));
    });
  });

  group('pantalla', () {
    Future<void> esperar(WidgetTester t, [int vueltas = 14]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<FakeBackend> sembrar(WidgetTester t) async {
      final backend = FakeBackend();
      final hoy = hoyYmd();
      await t.runAsync(() async {
        final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
        c.listen(cuentasProvider, (_, _) {});
        c.listen(inversionesProvider, (_, _) {});
        c.listen(prestamosProvider, (_, _) {});
        await c.read(inversionesProvider.future);
        await c.read(prestamosProvider.future);
        final fi = c.read(financeRepoProvider);
        final ah = await fi.crearCuenta(const CuentaInput(nombre: 'Nu', tipo: 'ahorros', saldo: 3000000));
        await fi.activarGanancias(ah, tasa: 9, desde: sumarDiasYmd(hoy, -3));
        await fi.crearCuenta(const CuentaInput(nombre: 'Efectivo de la casa', tipo: 'efectivo', saldo: 120000));
        await fi.crearCuenta(const CuentaInput(nombre: 'Visa platino del banco', tipo: 'tarjeta_credito', limite: 4000000, diaCorte: 15));
        await fi.crearCuenta(CuentaInput(nombre: 'CDT', tipo: 'cdt', saldo: 900000000, interesTasa: 10, fechaInicio: sumarDiasYmd(hoy, -30), plazoDias: 90));
        await c.read(inversionesRepoProvider).crear(nombre: 'ARQ', tipo: 'dolares', monto: 2050000, montoUsd: 500, fecha: sumarDiasYmd(hoy, -5), cuentaId: ah);
        await c.read(inversionesRepoProvider).crear(nombre: 'Novillos', tipo: 'ganado', monto: 1000000, fecha: hoy);
        await c.read(prestamosRepoProvider).crear(persona: 'Ana María Gómez Restrepo', monto: 1000000, fecha: sumarDiasYmd(hoy, -5), tasaMensual: 3, interesDesde: sumarDiasYmd(hoy, -5), vencimiento: sumarDiasYmd(hoy, -1));
        await c.read(prestamosRepoProvider).crear(persona: 'Carlos', monto: 100000, fecha: hoy);
        c.dispose();
      });
      return backend;
    }

    Future<void> abrirCuentas(WidgetTester t, FakeBackend backend, {required Size tamano, double texto = 1}) async {
      t.view.physicalSize = tamano;
      t.view.devicePixelRatio = 1;
      t.platformDispatcher.textScaleFactorTestValue = texto;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
      await esperar(t, 20);
      await t.tap(find.text('Finanzas').last);
      await esperar(t);
      final c = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first));
      c.read(finTabProvider.notifier).set(FinTab.cuentas);
      await esperar(t);
    }

    Future<void> recorrer(WidgetTester t) async {
      final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last;
      for (final ancla in ['Efectivo y bancos', 'Tarjetas y créditos', 'Inversiones', 'Préstamos que hiciste', 'Transferencias']) {
        await t.scrollUntilVisible(find.text(ancla), 200, scrollable: lista, maxScrolls: 60);
        await esperar(t, 4);
        expect(t.takeException(), isNull, reason: ancla);
      }
    }

    Future<void> salir(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 3)), 'muestra cada cosa en su grupo, sin el selector de mes arriba', (t) async {
      final backend = await sembrar(t);
      await abrirCuentas(t, backend, tamano: const Size(390, 844));
      expect(find.text('Mes anterior'), findsNothing);
      await recorrer(t);
      expect(find.text('Transferencias'), findsOneWidget);
      expect(find.byTooltip('Mes anterior'), findsOneWidget, reason: 'el mes solo aplica a las transferencias');
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 3)), 'teléfono pequeño con texto grande: nada se desborda', (t) async {
      final backend = await sembrar(t);
      await abrirCuentas(t, backend, tamano: const Size(320, 640), texto: 1.35);
      await recorrer(t);
      await salir(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 3)), 'crear un préstamo con intereses desde la pantalla', (t) async {
      final backend = FakeBackend();
      await abrirCuentas(t, backend, tamano: const Size(390, 844));
      final accion = find.text('Préstamo');
      await t.ensureVisible(accion);
      await esperar(t, 4);
      await t.tap(accion);
      await esperar(t);
      expect(find.text('Nuevo préstamo'), findsOneWidget);

      // Sin datos no se guarda.
      await t.ensureVisible(find.text('Registrar préstamo'));
      await t.tap(find.text('Registrar préstamo'));
      await esperar(t, 6);
      expect(find.text('Escribe el nombre de la persona'), findsOneWidget);
      expect(backend.prestamos, isEmpty);

      final campos = find.byType(TextFormField);
      await t.enterText(campos.at(0), 'Ana');
      await t.enterText(campos.at(1), '1000000');
      await esperar(t, 2);
      await t.ensureVisible(find.text('Con intereses'));
      await esperar(t, 2);
      await t.tap(find.text('Con intereses'));
      await esperar(t);
      final tasa = find.widgetWithText(TextFormField, 'Ej.: 2');
      await t.ensureVisible(tasa);
      await t.enterText(tasa, '3');
      await esperar(t, 4);
      expect(find.textContaining('al día'), findsWidgets);

      await t.ensureVisible(find.text('Registrar préstamo'));
      await t.tap(find.text('Registrar préstamo'));
      await esperar(t);
      expect(backend.prestamos.single['persona'], 'Ana');
      expect(backend.prestamos.single['tasa_mensual'], 3);
      expect(backend.prestamos.single['interes_desde'], hoyYmd());
      await salir(t);
    });
  });
}
