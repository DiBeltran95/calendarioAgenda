import 'package:flutter_test/flutter_test.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/captura/frecuentes.dart';

const hoy = '2026-10-31';

Transaccion tx(String desc, String fecha, {double monto = 25000, String tipo = 'gasto', String categoria = 'comida', int? cuenta, int? plan, int cuotas = 1}) =>
    Transaccion(id: 1, tipo: tipo, monto: monto, fecha: fecha, descripcion: desc, categoria: categoria, cuentaId: cuenta, ingresoPlanificadoId: plan, cuotas: cuotas);

Evento ev(String titulo, String fecha, {String? hora, String frecuencia = 'unica', int? padre, int? tarjeta, int? transaccion, String categoria = 'reunion', String tipo = 'ninguno', double costo = 0}) =>
    Evento(id: 1, titulo: titulo, fecha: fecha, hora: hora, frecuencia: frecuencia, parentId: padre, tarjetaCreditoId: tarjeta, transaccionId: transaccion, categoria: categoria, tipoTransaccion: tipo, costo: costo);

List<Frecuente> calcular({List<Transaccion> t = const [], List<Evento> e = const [], int limite = limiteFrecuentes}) =>
    calcularFrecuentes(transacciones: t, eventos: e, hoy: hoy, limite: limite);

void main() {
  test('ordena por lo más repetido y exige al menos dos veces', () {
    final r = calcular(t: [
      tx('Tinto', '2026-10-30'),
      tx('Almuerzo', '2026-10-30'),
      tx('Almuerzo', '2026-10-29'),
      tx('Almuerzo', '2026-10-28'),
      tx('Tinto', '2026-10-29'),
      tx('Zapatos', '2026-10-30'),
    ]);
    expect(r.map((f) => (f.titulo, f.veces)), [('Almuerzo', 3), ('Tinto', 2)]);
  });

  test('lo reciente pesa más que lo viejo, y lo de hace más de seis meses no cuenta', () {
    final r = calcular(t: [
      for (final f in ['2026-06-01', '2026-06-02', '2026-06-03']) tx('Gimnasio', f),
      for (final f in ['2026-10-29', '2026-10-30']) tx('Tinto', f),
      for (final f in ['2026-01-01', '2026-01-02', '2026-01-03']) tx('Viejo', f),
    ]);
    expect(r.map((f) => f.titulo), ['Tinto', 'Gimnasio']);
  });

  test('une tildes, mayúsculas y espacios; muestra como se escribió la última vez', () {
    final r = calcular(t: [tx('almuerzo', '2026-10-01'), tx(' ALMUÉRZO  ', '2026-10-02'), tx('Almuerzo  corriente', '2026-10-03'), tx('Almuerzo', '2026-10-30')]);
    expect(r.single.titulo, 'Almuerzo');
    expect(r.single.veces, 3);
  });

  test('un gasto y un ingreso con el mismo nombre son cosas distintas', () {
    final r = calcular(t: [
      for (final f in ['2026-10-29', '2026-10-30']) tx('Domicilios', f),
      for (final f in ['2026-10-29', '2026-10-30']) tx('Domicilios', f, tipo: 'ingreso'),
    ]);
    expect(r.map((f) => f.clase).toSet(), {ClaseFrecuente.gasto, ClaseFrecuente.ingreso});
  });

  test('toma el monto, la cuenta y la categoría más usados; sin repetidos, el monto más reciente', () {
    final r = calcular(t: [
      tx('Almuerzo', '2026-10-30', monto: 30000, cuenta: 2, categoria: 'otros'),
      tx('Almuerzo', '2026-10-29', monto: 25000, cuenta: 1),
      tx('Almuerzo', '2026-10-28', monto: 25000, cuenta: 1),
      tx('Taxi', '2026-10-30', monto: 18000),
      tx('Taxi', '2026-10-29', monto: 12000),
    ]);
    final almuerzo = r.firstWhere((f) => f.titulo == 'Almuerzo');
    expect((almuerzo.monto, almuerzo.cuentaId, almuerzo.categoria), (25000.0, 1, 'comida'));
    expect(r.firstWhere((f) => f.titulo == 'Taxi').monto, 18000);
  });

  test('no sugiere lo que la app registra sola', () {
    final fechas = ['2026-10-29', '2026-10-30'];
    final r = calcular(t: [
      for (final f in fechas) ...[
        tx('Rendimientos Nu', f, categoria: 'rendimientos', tipo: 'ingreso'),
        tx('Intereses de Ana', f, categoria: 'intereses_prestamo', tipo: 'ingreso'),
        tx('Cobro: Salario', f, tipo: 'ingreso'),
        tx('Abono de deuda: Cuota 1/3: Celular', f, tipo: 'ingreso'),
        tx('Sueldo', f, tipo: 'ingreso', plan: 4),
        tx('Gasto', f),
        tx('Arriendo', f),
      ],
    ], e: [
      ev('Arriendo', '2026-11-05', frecuencia: 'mensual', tipo: 'gasto', costo: 1200000),
    ]);
    expect(r, isEmpty);
  });

  test('en eventos no cuenta las series ni los cobros de tarjeta', () {
    final fechas = ['2026-10-29', '2026-10-30'];
    final r = calcular(e: [
      for (final f in fechas) ...[
        ev('Pastilla', f, frecuencia: 'diaria'),
        ev('Hija de serie', f, padre: 9),
        ev('Cobro tarjeta: Celular', f, tarjeta: 3, transaccion: 8),
        ev('Cumpleaños de Ana', f, categoria: 'cumpleanos'),
        ev('Clase de inglés', f, hora: '18:30'),
      ],
    ]);
    expect(r.single.titulo, 'Clase de inglés');
    expect((r.single.esEvento, r.single.hora), (true, '18:30'));
  });

  test('respeta el límite', () {
    final r = calcular(t: [
      for (var i = 0; i < 9; i++)
        for (final f in ['2026-10-29', '2026-10-30']) tx('Cosa $i', f),
    ]);
    expect(r, hasLength(limiteFrecuentes));
    expect(limiteFrecuentes, 5);
  });

  test('se guarda y se recupera igual', () {
    const f = Frecuente(clase: ClaseFrecuente.evento, titulo: 'Clase', veces: 3, categoria: 'reunion', monto: 5000, hora: '18:30', tipoEvento: 'gasto');
    final g = Frecuente.fromJson(f.toJson());
    expect((g.clase, g.titulo, g.veces, g.categoria, g.monto, g.hora, g.tipoEvento), (f.clase, f.titulo, f.veces, f.categoria, f.monto, f.hora, f.tipoEvento));
  });
}
