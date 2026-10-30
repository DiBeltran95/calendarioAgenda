// Pagos automáticos: intérprete de avisos de bancos (Android), sugerencias de
// categoría y cuenta, la bandeja contra el backend falso, el aviso en vivo de
// un pago con Apple Pay y la pantalla "Pagos por clasificar".

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/core/net/tiempo_real.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/citas/citas_en_vivo.dart';
import 'package:agendaservi/features/finance/pagos/lector_pagos.dart';
import 'package:agendaservi/features/finance/pagos/pagos_logica.dart';
import 'package:agendaservi/features/finance/pagos/pagos_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';
import 'tiempo_real_test.dart' show hasta;

/// Cola de avisos como la que deja PagosListener.kt.
class LectorFalso implements LectorPagos {
  LectorFalso(this.cola);
  final List<AvisoCrudo> cola;
  @override
  bool get soportado => true;
  @override
  Future<bool> acceso() async => true;
  @override
  Future<void> abrirAjustes() async {}
  @override
  Future<List<AvisoCrudo>> pendientes() async => [...cola];
  @override
  Future<void> quitar(List<String> ids) async => cola.removeWhere((a) => ids.contains(a.id));
  @override
  Future<void> avisar(bool valor) async {}
  @override
  Future<List<String>> apps() async => const ['Bancolombia'];
}

AvisoInterpretado? leer(String texto, {String titulo = '', String app = 'SMS', String paquete = 'com.google.android.apps.messaging'}) =>
    interpretarAviso(app: app, paquete: paquete, titulo: titulo, texto: texto, fecha: DateTime.utc(2026, 10, 20, 15));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  group('avisos de bancos', () {
    test('SMS de Bancolombia', () {
      final a = leer('Bancolombia le informa Compra por \$25.000,00 en EXITO CALLE 80 20:15. 20/10/2026 T.Cred *1234. Inquietudes al 018000931987')!;
      expect(a.tipo, 'gasto');
      expect(a.monto, 25000);
      expect(a.comercio, 'Exito Calle 80');
      expect(a.tarjeta, '•• 1234');
    });

    test('Nequi: pago y dinero recibido', () {
      final pago = leer('Pagaste \$18.900 en D1 SAS desde tu Nequi.', titulo: 'Nequi', app: 'Nequi', paquete: 'com.nequi.MobileApp')!;
      expect((pago.tipo, pago.monto, pago.comercio), ('gasto', 18900.0, 'D1 Sas'));
      final recibido = leer('Recibiste \$50.000 de JUAN PEREZ.', titulo: 'Nequi', app: 'Nequi', paquete: 'com.nequi.MobileApp')!;
      expect((recibido.tipo, recibido.monto, recibido.comercio), ('ingreso', 50000.0, 'Juan Perez'));
    });

    test('Davivienda con tarjeta terminada en', () {
      final a = leer('Davivienda: Realizaste una compra por \$120.000 en FALABELLA el 20/10/2026 con tu tarjeta terminada en 9876')!;
      expect((a.monto, a.comercio, a.tarjeta), (120000.0, 'Falabella', '•• 9876'));
    });

    test('Google Wallet: el título es el comercio', () {
      final a = leer('\$25.000,00 con Visa •••• 4321', titulo: 'Éxito', app: 'Google Wallet', paquete: 'com.google.android.apps.walletnfcrel')!;
      expect((a.monto, a.comercio, a.tarjeta), (25000.0, 'Éxito', '•• 4321'));
    });

    test('códigos, rechazos y mensajes sin monto no son pagos', () {
      expect(leer('Tu código de verificación es 123456 para la compra de \$25.000'), isNull);
      expect(leer('Transacción rechazada por \$80.000 en AMAZON'), isNull);
      expect(leer('Bancolombia te invita a conocer tu nuevo crédito'), isNull);
    });

    test('montos como los escriben los bancos', () {
      expect(montoDesdeTexto('25.000,50'), 25000.5);
      expect(montoDesdeTexto('1.250.000'), 1250000);
      expect(montoDesdeTexto('25,000.00'), 25000);
      expect(montoDesdeTexto('0'), isNull);
    });
  });

  group('sugerencias', () {
    CapturaPago pago(String comercio, {String tarjeta = ''}) =>
        CapturaPago(id: 1, origen: 'apple_pay', tipo: 'gasto', monto: 1000, comercio: comercio, tarjeta: tarjeta, app: '', fecha: DateTime.utc(2026));
    const cats = [
      CategoriaFinanzas(id: 1, valor: 'comida', label: 'Comida'),
      CategoriaFinanzas(id: 2, valor: 'transporte', label: 'Transporte'),
      CategoriaFinanzas(id: 3, valor: 'servicios', label: 'Servicios'),
      CategoriaFinanzas(id: 4, valor: 'mascotas', label: 'Mascotas'),
      CategoriaFinanzas(id: 5, valor: 'otros', label: 'Otros'),
    ];
    const cuentas = [Cuenta(id: 10, nombre: 'Visa Bancolombia', tipo: 'tarjeta_credito'), Cuenta(id: 11, nombre: 'Ahorros', tipo: 'ahorros')];

    test('lo aprendido gana; luego palabras clave; si no, "otros"', () {
      const prefs = [PreferenciaPago(comercio: 'Éxito Calle 80', tarjeta: '•• 1234', categoria: 'mascotas', cuentaId: 10)];
      expect(sugerirCategoria(pago('EXITO calle 100'), prefs, cats), 'mascotas', reason: 'mismo comercio, otra sucursal');
      expect(sugerirCategoria(pago('Terpel La Calera'), const [], cats), 'transporte');
      expect(sugerirCategoria(pago('NETFLIX.COM'), const [], cats), 'servicios');
      expect(sugerirCategoria(pago('Para Ti Boutique'), const [], cats), 'otros', reason: '"ara" no es Ara dentro de otra palabra');
      expect(sugerirCuenta(pago('Otro', tarjeta: '•• 1234'), prefs, cuentas), 10);
      expect(sugerirCuenta(pago('Otro'), prefs, cuentas), isNull);
    });
  });

  group('bandeja', () {
    late ProviderContainer c;
    late FakeBackend backend;
    late LectorFalso lector;

    setUp(() async {
      backend = FakeBackend();
      lector = LectorFalso([
        AvisoCrudo(id: 'a', paquete: 'com.google.android.apps.messaging', app: 'SMS', titulo: '890123', texto: 'Bancolombia le informa Compra por \$45.000 en TERPEL 08:10. T.Deb *5555', fecha: DateTime.now().toUtc()),
        AvisoCrudo(id: 'b', paquete: 'com.google.android.apps.messaging', app: 'SMS', titulo: '890123', texto: 'Su clave dinámica es 445566', fecha: DateTime.now().toUtc()),
      ]);
      c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), lector: lector));
      addTearDown(c.dispose);
      c.listen(pagosPendientesProvider, (_, _) {});
      await c.read(pagosPendientesProvider.future);
    });

    test('Android: sube los avisos, vacía la cola y registra el pago como gasto', () async {
      final nuevas = await c.read(pagosRepoProvider).sincronizarAndroid();
      expect(nuevas, 1);
      expect(lector.cola, isEmpty, reason: 'el código también sale de la cola');
      final p = c.read(pagosPendientesProvider).value!.single;
      expect((p.monto, p.comercio, p.tarjeta), (45000.0, 'Terpel', '•• 5555'));

      await c.read(pagosRepoProvider).registrar(p, categoria: 'transporte');
      expect(c.read(pagosPendientesProvider).value, isEmpty);
      final t = backend.transacciones.single;
      expect((t['descripcion'], t['categoria'], t['tipo'], double.parse('${t['monto']}')), ('Terpel', 'transporte', 'gasto', 45000.0));
      expect(backend.capturas.single['estado'], 'registrada');
      expect(backend.capturas.single['transaccion_id'], t['id']);
      // La próxima vez sugiere lo mismo para ese comercio.
      expect((await c.read(preferenciasPagosProvider.future)).single.categoria, 'transporte');
    });

    test('descartar y deshacer', () async {
      await c.read(pagosRepoProvider).sincronizarAndroid();
      final p = c.read(pagosPendientesProvider).value!.single;
      await c.read(pagosRepoProvider).descartar(p);
      expect(c.read(pagosPendientesProvider).value, isEmpty);
      expect(backend.capturas.single['estado'], 'descartada');
      await c.read(pagosRepoProvider).deshacerDescarte(p);
      expect(c.read(pagosPendientesProvider).value, hasLength(1));
    });

    test('Apple Pay con la app abierta: entra a la bandeja y se anuncia', () async {
      c.listen(canalVivoProvider, (_, _) {});
      c.listen(pagosEnVivoProvider, (_, _) {});
      await hasta(() => c.read(tiempoRealProvider).conectado);
      backend.pagoApplePay(1, monto: 18900, comercio: 'Juan Valdez', tarjeta: 'Visa');
      await hasta(() => (c.read(pagosPendientesProvider).value ?? const []).isNotEmpty);
      final aviso = c.read(avisoVivoProvider)!;
      expect(aviso.tipo, TipoAvisoVivo.pago);
      expect(aviso.titulo, 'Pago detectado: \$ 18.900');
      expect(aviso.ruta, rutaPagos);
    });
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'interfaz: deslizar guarda o descarta el pago', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final backend = FakeBackend();
    backend.pagoApplePay(1, monto: 32000, comercio: 'Terpel Autopista', tarjeta: 'Visa');
    backend.pagoApplePay(1, monto: 9000, comercio: 'Tienda Don Pepe', tarjeta: 'Visa');

    Future<void> esperar([int vueltas = 14]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
    await esperar(20);
    ProviderScope.containerOf(t.element(find.byType(MaterialApp).first)).read(routerProvider).push(rutaPagos);
    await esperar(16);

    await t.drag(find.text('Terpel Autopista'), const Offset(380, 0));
    await esperar();
    expect(find.text('Terpel Autopista'), findsNothing);
    expect(backend.transacciones.single['categoria'], 'transporte');

    await t.drag(find.text('Tienda Don Pepe'), const Offset(-380, 0));
    await esperar();
    expect(find.text('Tienda Don Pepe'), findsNothing);
    expect(backend.transacciones, hasLength(1), reason: 'descartar no crea movimiento');
    expect(find.text('Pago descartado'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'interfaz: clasificar un pago con un toque', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final backend = FakeBackend();
    backend.pagoApplePay(1, monto: 32000, comercio: 'Terpel Autopista', tarjeta: 'Visa Bancolombia');

    Future<void> esperar([int vueltas = 12]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
    await esperar(20);
    await t.tap(find.text('Finanzas').last);
    await esperar();
    expect(find.byTooltip('1 pagos por clasificar'), findsOneWidget);
    ProviderScope.containerOf(t.element(find.byType(MaterialApp).first)).read(routerProvider).push(rutaPagos);
    await esperar(16);

    expect(find.text('Terpel Autopista'), findsOneWidget);
    expect(find.text('Transporte · sugerida'), findsOneWidget);
    await t.tap(find.text('Guardar'));
    await esperar(16);
    expect(find.text('Todo clasificado'), findsOneWidget);
    expect(backend.transacciones.single['categoria'], 'transporte');

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
  });
}
