import 'package:agendaservi/core/db/database.dart';
import 'package:agendaservi/features/cycle/cycle_repository.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/finance/finance_logic.dart';
import 'package:agendaservi/features/finance/finance_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late EventsRepository eventos;
  late FinanceRepository finanzas;
  late CycleRepository ciclo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    eventos = EventsRepository(db);
    finanzas = FinanceRepository(db);
    ciclo = CycleRepository(db);
  });
  tearDown(() => db.close());

  Future<Cuenta> cuenta(int id) => (db.select(db.cuentas)..where((c) => c.id.equals(id))).getSingle();

  group('eventos', () {
    test('un evento anual genera 5 ocurrencias futuras', () async {
      final id = await eventos.crear(const EventoInput(titulo: 'SOAT moto', fecha: '2026-01-31', categoria: 'moto', frecuencia: 'anual'));
      final todos = await db.select(db.eventos).get();
      expect(todos, hasLength(6));
      expect(todos.where((e) => e.parentId == id).map((e) => e.fecha), contains('2031-01-31'));
    });

    test('mensual recorta al último día del mes', () async {
      await eventos.crear(const EventoInput(titulo: 'Arriendo', fecha: '2026-01-31', frecuencia: 'mensual'));
      final fechas = (await db.select(db.eventos).get()).map((e) => e.fecha).toList();
      expect(fechas, contains('2026-02-28'));
      expect(fechas, contains('2026-04-30'));
    });

    test('borrar "este y futuros" conserva los pagados y los anteriores', () async {
      await eventos.crear(const EventoInput(titulo: 'Gym', fecha: '2026-01-10', frecuencia: 'mensual', tipoTransaccion: 'gasto', costo: 90000));
      final lista = await (db.select(db.eventos)..orderBy([(e) => OrderingTerm(expression: e.fecha)])).get();
      await eventos.alternarPago(lista[5]); // junio pagado
      await eventos.eliminar(lista[3], AlcanceSerie.esteYFuturos); // desde abril
      final quedan = (await db.select(db.eventos).get()).map((e) => e.fecha).toSet();
      expect(quedan, containsAll(['2026-01-10', '2026-02-10', '2026-03-10', '2026-06-10']));
      expect(quedan, isNot(contains('2026-04-10')));
      expect(quedan, isNot(contains('2026-07-10')));
    });

    test('editar "este y futuros" regenera la serie desde la nueva fecha', () async {
      await eventos.crear(const EventoInput(titulo: 'Clase', fecha: '2026-01-05', frecuencia: 'trimestral'));
      final lista = await (db.select(db.eventos)..orderBy([(e) => OrderingTerm(expression: e.fecha)])).get();
      final abril = lista[1];
      await eventos.actualizar(abril, EventoInput.desde(abril).copyTitulo('Clase nueva', fecha: '2026-04-20'), AlcanceSerie.esteYFuturos);
      final fechas = (await db.select(db.eventos).get()).map((e) => e.fecha).toList()..sort();
      expect(fechas.first, '2026-01-05');
      expect(fechas, contains('2026-04-20'));
      expect(fechas, contains('2026-07-20'));
      expect(fechas, isNot(contains('2026-07-05')));
    });
  });

  group('finanzas', () {
    test('compra a 3 cuotas con tarjeta: deuda + 3 cobros en el calendario', () async {
      final tc = await finanzas.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', limite: 5000000, diaCorte: 15));
      final tx = await finanzas.crearTransaccion(TransaccionInput(
          tipo: 'gasto', monto: 100000, descripcion: 'Zapatos', fecha: '2026-09-20', cuentaId: tc, categoria: 'otros', cuotas: 3));
      expect((await cuenta(tc)).saldo, 100000);
      final cobros = await (db.select(db.eventos)..orderBy([(e) => OrderingTerm(expression: e.fecha)])).get();
      expect(cobros.map((e) => e.fecha), ['2026-10-15', '2026-11-15', '2026-12-15']);
      expect(cobros.map((e) => e.costo), [33333.33, 33333.33, 33333.34]);
      expect(cobros.first.titulo, 'Cuota 1/3: Zapatos');

      final t = await (db.select(db.transacciones)..where((x) => x.id.equals(tx))).getSingle();
      await finanzas.eliminarTransaccion(t);
      expect((await cuenta(tc)).saldo, 0);
      expect(await db.select(db.eventos).get(), isEmpty);
    });

    test('transferencia de ahorros a tarjeta reduce ambos saldos y se revierte', () async {
      final ah = await finanzas.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 1000000));
      final tc = await finanzas.crearCuenta(const CuentaInput(nombre: 'Visa', tipo: 'tarjeta_credito', saldo: 300000, limite: 2000000));
      await finanzas.transferir(origenId: ah, destinoId: tc, monto: 200000, fecha: '2026-09-01');
      expect((await cuenta(ah)).saldo, 800000);
      expect((await cuenta(tc)).saldo, 100000);
      final t = await db.select(db.transferencias).getSingle();
      await finanzas.eliminarTransferencia(t);
      expect((await cuenta(ah)).saldo, 1000000);
      expect((await cuenta(tc)).saldo, 300000);
    });

    test('verificar un ingreso planificado y deshacerlo', () async {
      final ah = await finanzas.crearCuenta(const CuentaInput(nombre: 'Nómina', tipo: 'ahorros'));
      final planId = await finanzas.crearPlan(descripcion: 'Salario', monto: 3000000, frecuencia: 'quincenal', fechaInicio: '2026-01-15', cuentaId: ah);
      final plan = await (db.select(db.ingresosPlanificados)..where((p) => p.id.equals(planId))).getSingle();

      final occ = ocurrenciasMes([plan], const [], 2026, 9);
      expect(occ.map((o) => o.fechaEsperada), ['2026-09-12', '2026-09-27']);

      await finanzas.verificarIngreso(plan: plan, fechaEsperada: '2026-09-12', fechaReal: '2026-09-11', montoReal: 2950000);
      expect((await cuenta(ah)).saldo, 2950000);
      expect(() => finanzas.verificarIngreso(plan: plan, fechaEsperada: '2026-09-12', fechaReal: '2026-09-12', montoReal: 1),
          throwsA(isA<FinanzasError>()));

      final v = await db.select(db.verificaciones).getSingle();
      await finanzas.deshacerVerificacion(v);
      expect((await cuenta(ah)).saldo, 0);
      expect(await db.select(db.transacciones).get(), isEmpty);
    });

    test('aportar a una meta desde una cuenta y completarla', () async {
      final ah = await finanzas.crearCuenta(const CuentaInput(nombre: 'Ahorros', tipo: 'ahorros', saldo: 500000));
      final metaId = await finanzas.crearMeta(const MetaInput(nombre: 'Viaje', montoObjetivo: 400000, montoActual: 100000));
      final meta = await (db.select(db.metas)..where((m) => m.id.equals(metaId))).getSingle();
      final cumplida = await finanzas.aportarAMeta(meta, 300000, cuentaId: ah, fecha: '2026-09-22');
      expect(cumplida, isTrue);
      final m2 = await (db.select(db.metas)..where((m) => m.id.equals(metaId))).getSingle();
      expect(m2.montoActual, 400000);
      expect(m2.completada, isTrue);
      expect((await cuenta(ah)).saldo, 200000);
    });

    test('los presupuestos se arrastran a los meses siguientes', () async {
      await finanzas.guardarPresupuesto(categoria: 'comida', limite: 800000, mes: 7, anio: 2026);
      final todos = await db.select(db.presupuestos).get();
      final v = presupuestosVigentes(todos, 2026, 9);
      expect(v['comida']!.$1.montoLimite, 800000);
      expect(v['comida']!.$2, isTrue);
      expect(presupuestosVigentes(todos, 2026, 6), isEmpty);
    });

    test('no se puede borrar una categoría en uso', () async {
      await finanzas.crearCategoria('Mascotas', 'pets');
      await finanzas.crearTransaccion(const TransaccionInput(tipo: 'gasto', monto: 20000, descripcion: 'Concentrado', fecha: '2026-09-01', categoria: 'mascotas'));
      final cat = await (db.select(db.categoriasFinanzas)..where((c) => c.valor.equals('mascotas'))).getSingle();
      expect(() => finanzas.eliminarCategoria(cat), throwsA(isA<FinanzasError>()));
    });
  });

  group('ciclo', () {
    test('rechaza duplicados y avisa de inicios muy seguidos', () async {
      await ciclo.guardarPeriodo(fecha: '2026-08-01', diasSangrado: 5);
      expect(() => ciclo.guardarPeriodo(fecha: '2026-08-01'), throwsA(isA<CicloError>()));
      final r = await ciclo.guardarPeriodo(fecha: '2026-08-06');
      expect(r.advertencia, contains('5 día(s)'));
    });
  });

  test('cobros sin día de corte caen el mismo día de los meses siguientes', () {
    final c = cobrosTarjeta(fechaCompra: '2026-01-31', monto: 200000, cuotas: 2);
    expect(c.map((x) => x.$1), ['2026-02-28', '2026-03-31']);
  });
}

extension on EventoInput {
  EventoInput copyTitulo(String titulo, {required String fecha}) => EventoInput(
        titulo: titulo,
        fecha: fecha,
        hora: hora,
        categoria: categoria,
        ubicacion: ubicacion,
        notas: notas,
        frecuencia: frecuencia,
        costo: costo,
        tipoTransaccion: tipoTransaccion,
        estadoPago: estadoPago,
      );
}
