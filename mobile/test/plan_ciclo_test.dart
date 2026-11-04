// Plan del sueldo: de un pago al siguiente, cuánto se puede gastar cada día.

import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/finance/plan_ciclo.dart';
import 'package:flutter_test/flutter_test.dart';

const _sueldo = IngresoPlanificado(id: 1, descripcion: 'Salario', monto: 3000000, frecuencia: 'mensual', fechaInicio: '2026-01-30');
const _nequi = Cuenta(id: 1, nombre: 'Nequi', tipo: 'ahorros');
const _visa = Cuenta(id: 2, nombre: 'Visa', tipo: 'tarjeta_credito');

var _id = 0;
Transaccion gasto(String fecha, double monto, {String desc = 'Mercado', int? cuenta = 1}) =>
    Transaccion(id: ++_id, tipo: 'gasto', monto: monto, fecha: fecha, descripcion: desc, cuentaId: cuenta);
Transaccion ingreso(String fecha, double monto, {String desc = 'Venta', String categoria = 'otros', int? plan}) =>
    Transaccion(id: ++_id, tipo: 'ingreso', monto: monto, fecha: fecha, descripcion: desc, categoria: categoria, cuentaId: 1, ingresoPlanificadoId: plan);
Evento fijo(String titulo, String fecha, double costo, {bool pagado = false, int? tarjeta}) =>
    Evento(id: ++_id, titulo: titulo, fecha: fecha, costo: costo, tipoTransaccion: 'gasto', estadoPago: pagado ? 'pagado' : 'pendiente', tarjetaCreditoId: tarjeta);

PlanCiclo plan({
  List<IngresoPlanificado> planes = const [_sueldo],
  List<Verificacion> verificaciones = const [],
  List<Transaccion> tx = const [],
  List<Evento> eventos = const [],
  String hoy = '2026-11-04',
  int ahorroPct = 10,
}) =>
    calcularPlanCiclo(planes: planes, verificaciones: verificaciones, cuentas: const [_nequi, _visa], transacciones: tx, eventos: eventos, hoy: hoy, ahorroPct: ahorroPct);

void main() {
  group('ciclo de pago', () {
    test('mensual: del día de pago al día antes del siguiente, aunque cruce de mes', () {
      expect(cicloDePago(const [_sueldo], '2026-11-04'), ('2026-10-30', '2026-11-29'));
      expect(cicloDePago(const [_sueldo], '2026-10-30'), ('2026-10-30', '2026-11-29'));
      expect(cicloDePago(const [_sueldo], '2026-10-29'), ('2026-09-30', '2026-10-29'));
    });

    test('quincenal: unos 15 días', () {
      const q = IngresoPlanificado(id: 2, descripcion: 'Quincena', monto: 1500000, frecuencia: 'quincenal', fechaInicio: '2026-10-01');
      expect(cicloDePago(const [q], '2026-11-04'), ('2026-10-31', '2026-11-14'));
    });

    test('marca el ciclo el sueldo más grande; sin sueldo es el mes calendario', () {
      const pequeno = IngresoPlanificado(id: 3, descripcion: 'Arriendo del local', monto: 400000, frecuencia: 'mensual', fechaInicio: '2026-01-10');
      expect(cicloDePago(const [pequeno, _sueldo], '2026-11-04'), ('2026-10-30', '2026-11-29'));
      expect(cicloDePago(const [], '2026-11-04'), ('2026-11-01', '2026-11-30'));
      const diario = IngresoPlanificado(id: 4, descripcion: 'Ventas', monto: 50000, frecuencia: 'diario', fechaInicio: '2026-01-01');
      expect(cicloDePago(const [diario], '2026-11-04'), ('2026-11-01', '2026-11-30'));
    });

    test('un sueldo que empieza más adelante cuenta por mes hasta entonces', () {
      const nuevo = IngresoPlanificado(id: 5, descripcion: 'Nuevo trabajo', monto: 2000000, frecuencia: 'mensual', fechaInicio: '2026-11-20');
      expect(cicloDePago(const [nuevo], '2026-11-04'), ('2026-11-01', '2026-11-19'));
    });
  });

  test('reparte lo libre entre los días que faltan', () {
    final p = plan(eventos: [fijo('Arriendo', '2026-11-05', 1200000)], tx: [gasto('2026-11-01', 300000)]);
    expect((p.sueldo, p.fijos, p.ahorro), (3000000.0, 1200000.0, 300000.0));
    expect(p.libre, 1500000);
    expect(p.diasRestantes, 26);
    expect(p.puedesHoy, closeTo((1500000 - 300000) / 26, 0.01));
    expect(p.conSueldo, isTrue);
    expect(p.proximoPago, '2026-11-30');
  });

  test('lo gastado hoy se descuenta de lo de hoy, no de los días que siguen', () {
    final p = plan(tx: [gasto('2026-11-04', 20000)], ahorroPct: 0);
    expect(p.porDia, closeTo(3000000 / 26, 0.01));
    expect(p.puedesHoy, closeTo(3000000 / 26 - 20000, 0.01));
  });

  test('el sueldo confirmado usa lo que de verdad llegó, y su cobro no se suma otra vez', () {
    final p = plan(
      verificaciones: const [Verificacion(id: 1, ingresoPlanificadoId: 1, fechaEsperada: '2026-10-30', fechaReal: '2026-10-30', montoReal: 3100000)],
      tx: [ingreso('2026-10-30', 3100000, desc: 'Cobro: Salario', plan: 1)],
    );
    expect((p.sueldo, p.extras), (3100000.0, 0.0));
  });

  test('el sueldo anotado a mano en vez de confirmado no se cuenta dos veces', () {
    final p = plan(tx: [ingreso('2026-10-30', 2950000, desc: 'salario'), ingreso('2026-11-02', 80000)]);
    expect((p.sueldo, p.extras), (2950000.0, 80000.0));
    expect(plan(tx: [ingreso('2026-10-31', 3000000, desc: 'Pago empresa')]).ingresos, 3000000);
  });

  test('si hoy se pasó de lo del día, dice cuánto queda desde mañana', () {
    final p = plan(tx: [gasto('2026-11-04', 200000)], ahorroPct: 0);
    expect(p.puedesHoy, 0);
    expect(p.porDiaDesdeManana, closeTo((3000000 - 200000) / 25, 0.01));
  });

  test('las ganancias de NU no cuentan como ingreso; una venta sí', () {
    final p = plan(tx: [
      ingreso('2026-11-01', 1244, desc: 'Ganancia: NU', categoria: 'rendimientos'),
      ingreso('2026-11-02', 1244, desc: 'Rendimiento diario CDT: NU (ID: 5)', categoria: 'ahorro'),
      ingreso('2026-11-03', 80000),
    ]);
    expect(p.extras, 80000);
  });

  test('pagar un fijo no lo cuenta dos veces', () {
    final p = plan(
      eventos: [fijo('Arriendo', '2026-11-01', 1200000, pagado: true), fijo('Internet', '2026-11-10', 90000)],
      tx: [gasto('2026-11-01', 1200000, desc: 'Arriendo'), gasto('2026-11-02', 50000)],
    );
    expect((p.fijosPagados, p.fijosPendientes, p.gastadoLibre), (1200000.0, 90000.0, 50000.0));
  });

  test('una compra con tarjeta no sale de lo libre; su cuota entra como fijo', () {
    final p = plan(
      eventos: [fijo('Cobro tarjeta: Celular', '2026-11-15', 300000, tarjeta: 2)],
      tx: [gasto('2026-11-02', 900000, desc: 'Celular', cuenta: 2)],
    );
    expect((p.conTarjeta, p.gastadoLibre, p.fijos), (900000.0, 0.0, 300000.0));
  });

  test('lo de fuera del ciclo no cuenta', () {
    final p = plan(eventos: [fijo('Arriendo', '2026-11-30', 1200000)], tx: [gasto('2026-10-29', 500000), gasto('2026-11-05', 40000)]);
    expect((p.fijos, p.gastadoLibre), (0.0, 0.0));
  });

  test('si los fijos y el ahorro no caben, hoy no hay nada para gastar', () {
    final p = plan(eventos: [fijo('Arriendo', '2026-11-05', 3000000)]);
    expect(p.libre, lessThan(0));
    expect(p.puedesHoy, 0);
    expect(plan(eventos: [fijo('Arriendo', '2026-11-05', 3000000)], tx: [gasto('2026-11-01', 1000)]).ritmo, Ritmo.rapido);
  });

  test('ritmo: compara lo gastado con lo que tocaba a estas alturas', () {
    // Día 6 de 31: con 2.700.000 libres tocaba llevar unos 522.580.
    expect(plan(tx: [gasto('2026-11-01', 500000)]).ritmo, Ritmo.bien);
    expect(plan(tx: [gasto('2026-11-01', 580000)]).ritmo, Ritmo.pocoRapido);
    expect(plan(tx: [gasto('2026-11-01', 700000)]).ritmo, Ritmo.rapido);
  });

  test('sin sueldo planificado cuenta los ingresos registrados del mes', () {
    final p = plan(planes: const [], tx: [ingreso('2026-11-02', 900000), gasto('2026-11-03', 100000)]);
    expect((p.conSueldo, p.inicio, p.fin, p.ingresos, p.gastadoLibre), (false, '2026-11-01', '2026-11-30', 900000.0, 100000.0));
  });
}
