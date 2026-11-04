// Pagos de cada mes que se proponen para agendar en Eventos.

import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/finance/fijos_sugeridos.dart';
import 'package:agendaservi/features/finance/plan_ciclo.dart';
import 'package:flutter_test/flutter_test.dart';

const hoy = '2026-11-04';
const _cuentas = [Cuenta(id: 1, nombre: 'Davivienda', tipo: 'ahorros'), Cuenta(id: 2, nombre: 'ADDI', tipo: 'tarjeta_credito')];

var _id = 0;
Transaccion tx(String desc, String fecha, double monto, {String categoria = 'otros', int cuenta = 1}) =>
    Transaccion(id: ++_id, tipo: 'gasto', monto: monto, fecha: fecha, descripcion: desc, categoria: categoria, cuentaId: cuenta);

List<FijoSugerido> sugerir(List<Transaccion> t, {List<Evento> eventos = const [], Set<String> descartados = const {}}) =>
    sugerirFijos(transacciones: t, eventos: eventos, cuentas: _cuentas, descartados: descartados, hoy: hoy);

void main() {
  test('un servicio pagado una vez ya se propone, con su día y la próxima fecha', () {
    final r = sugerir([tx('Internet Claro', '2026-11-03', 49900, categoria: 'servicios')]);
    expect(r.single.titulo, 'Internet Claro');
    expect((r.single.monto, r.single.dia, r.single.proximaFecha, r.single.categoriaEvento), (49900.0, 3, '2026-12-03', 'servicios'));
  });

  test('lo que se paga una vez al mes por un monto parecido también es fijo', () {
    final r = sugerir([tx('Netflix', '2026-09-15', 26900), tx('netflix ', '2026-10-15', 26900)]);
    expect(r.single.categoriaEvento, 'general');
    expect(r.single.proximaFecha, '2026-11-15');
  });

  test('un servicio visto una sola vez hace más de un mes no se propone (pudo cambiar de nombre)', () {
    final r = sugerir([tx('Servicios de Agua', '2026-09-30', 37613, categoria: 'servicios'), tx('Agua', '2026-11-02', 36442, categoria: 'servicios')]);
    expect(r.single.titulo, 'Agua');
  });

  test('lo del día a día no es fijo', () {
    expect(sugerir([tx('Almuerzo', '2026-10-02', 20000), tx('Almuerzo', '2026-10-09', 20000), tx('Almuerzo', '2026-11-02', 20000)]), isEmpty);
    expect(sugerir([tx('Mercado', '2026-09-02', 100000), tx('Mercado', '2026-10-02', 300000)]), isEmpty);
  });

  test('no propone lo ya agendado, lo descartado, lo de tarjeta, lo automático ni lo viejo', () {
    final r = sugerir([
      tx('Arriendo', '2026-11-01', 900000, categoria: 'arriendo'),
      tx('Agua', '2026-11-02', 36442, categoria: 'servicios'),
      tx('Energía', '2026-11-02', 6500, categoria: 'servicios', cuenta: 2),
      tx('Pago: Internet Movistar', '2026-11-03', 34900, categoria: 'servicios'),
      tx('Gas', '2026-07-01', 20000, categoria: 'servicios'),
    ], eventos: [
      const Evento(id: 1, titulo: 'Arriendo', fecha: '2026-12-01', frecuencia: 'mensual', tipoTransaccion: 'gasto', costo: 900000),
    ], descartados: {'agua'});
    expect(r, isEmpty);
  });

  test('propone los más grandes primero y como mucho tres', () {
    final r = sugerir([for (final (i, m) in [10000.0, 50000.0, 30000.0, 40000.0].indexed) tx('Servicio $i', '2026-11-0${i + 1}', m, categoria: 'servicios')]);
    expect(r.map((f) => f.monto), [50000, 40000, 30000]);
  });

  test('próxima fecha: este mes si todavía no llega, recortada en meses cortos', () {
    expect(proximoDiaDelMes(hoy, 10), '2026-11-10');
    expect(proximoDiaDelMes(hoy, 4), '2026-12-04');
    expect(proximoDiaDelMes('2026-11-30', 31), '2026-12-31');
    expect(proximoDiaDelMes('2026-12-31', 31), '2027-01-31');
    expect(proximoDiaDelMes('2027-01-31', 31), '2027-02-28');
  });

  test('un fijo agendado que se anota como gasto cuenta como pagado, no dos veces', () {
    final p = calcularPlanCiclo(
      planes: const [IngresoPlanificado(id: 1, descripcion: 'Nómina', monto: 3000000, frecuencia: 'mensual', fechaInicio: '2026-06-29')],
      verificaciones: const [],
      cuentas: _cuentas,
      transacciones: [tx('Internet Claro', '2026-11-03', 52000)],
      eventos: const [Evento(id: 2, titulo: 'Internet Claro', fecha: '2026-11-03', tipoTransaccion: 'gasto', costo: 49900)],
      hoy: hoy,
    );
    expect((p.fijosPagados, p.fijosPendientes, p.gastadoLibre), (52000.0, 0.0, 0.0));
  });
}
