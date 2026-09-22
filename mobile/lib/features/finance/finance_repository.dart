import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import 'finance_logic.dart';

class CuentaInput {
  const CuentaInput({
    required this.nombre,
    required this.tipo,
    this.saldo = 0,
    this.limite = 0,
    this.interesTasa = 0,
    this.fechaInicio,
    this.plazoDias = 0,
    this.diaCorte,
  });
  final String nombre;
  final String tipo;
  final double saldo;
  final double limite;
  final double interesTasa;
  final String? fechaInicio;
  final int plazoDias;
  final int? diaCorte;
}

class TransaccionInput {
  const TransaccionInput({
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    this.cuentaId,
    this.categoria = 'otros',
    this.cuotas = 1,
  });
  final String tipo;
  final double monto;
  final String descripcion;
  final String fecha;
  final int? cuentaId;
  final String categoria;
  final int cuotas;
}

class MetaInput {
  const MetaInput({
    required this.nombre,
    required this.montoObjetivo,
    this.descripcion = '',
    this.montoActual = 0,
    this.fechaObjetivo,
    this.icono = 'savings',
    this.color = 0xFF34E47E,
  });
  final String nombre;
  final String descripcion;
  final double montoObjetivo;
  final double montoActual;
  final String? fechaObjetivo;
  final String icono;
  final int color;
}

class FinanzasError implements Exception {
  const FinanzasError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Toda la lógica que antes vivía en el backend (saldos, cuotas de tarjeta,
/// transferencias, verificaciones) ahora corre aquí, en transacciones SQLite
/// atómicas: o se aplica todo o nada.
class FinanceRepository {
  FinanceRepository(this._db);
  final AppDatabase _db;

  // ─────────────── Lecturas reactivas ───────────────

  Stream<List<Cuenta>> watchCuentas() =>
      (_db.select(_db.cuentas)..orderBy([(c) => OrderingTerm(expression: c.nombre)])).watch();

  Stream<List<Transaccion>> watchTransacciones(String desde, String hasta) => (_db.select(_db.transacciones)
        ..where((t) => t.fecha.isBetweenValues(desde, hasta))
        ..orderBy([
          (t) => OrderingTerm(expression: t.fecha, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
        ]))
      .watch();

  Stream<List<Transferencia>> watchTransferencias(String desde, String hasta) => (_db.select(_db.transferencias)
        ..where((t) => t.fecha.isBetweenValues(desde, hasta))
        ..orderBy([(t) => OrderingTerm(expression: t.fecha, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<IngresoPlanificado>> watchPlanes() =>
      (_db.select(_db.ingresosPlanificados)..orderBy([(p) => OrderingTerm(expression: p.fechaInicio)])).watch();

  Stream<List<Verificacion>> watchVerificaciones() => _db.select(_db.verificaciones).watch();

  Stream<List<Meta>> watchMetas() => (_db.select(_db.metas)
        ..orderBy([
          (m) => OrderingTerm(expression: m.completada),
          (m) => OrderingTerm(expression: m.creadoEn, mode: OrderingMode.desc),
        ]))
      .watch();

  Stream<List<Presupuesto>> watchPresupuestos() => _db.select(_db.presupuestos).watch();

  Stream<List<CategoriaFinanzas>> watchCategorias() => (_db.select(_db.categoriasFinanzas)
        ..orderBy([
          (c) => OrderingTerm(expression: c.esDefault, mode: OrderingMode.desc),
          (c) => OrderingTerm(expression: c.label),
        ]))
      .watch();

  /// Categorías con transacciones o presupuestos (no se pueden borrar).
  Stream<Set<String>> watchCategoriasEnUso() {
    final q = _db.customSelect(
      'SELECT categoria FROM transacciones UNION SELECT categoria FROM presupuestos',
      readsFrom: {_db.transacciones, _db.presupuestos},
    );
    return q.watch().map((rows) => {for (final r in rows) r.read<String>('categoria')});
  }

  // ─────────────── Cuentas ───────────────

  CuentasCompanion _cuenta(CuentaInput i) => CuentasCompanion(
        nombre: Value(i.nombre.trim()),
        tipo: Value(i.tipo),
        saldo: Value(i.saldo),
        limite: Value(esCredito(i.tipo) ? i.limite : 0),
        interesTasa: Value(i.tipo == 'cdt' ? i.interesTasa : 0),
        fechaInicio: Value(i.tipo == 'cdt' ? (i.fechaInicio ?? hoyYmd()) : null),
        plazoDias: Value(i.tipo == 'cdt' ? i.plazoDias : 0),
        diaCorte: Value(esCredito(i.tipo) ? i.diaCorte : null),
      );

  Future<int> crearCuenta(CuentaInput i) => _db.into(_db.cuentas).insert(_cuenta(i));

  Future<void> actualizarCuenta(int id, CuentaInput i) =>
      (_db.update(_db.cuentas)..where((c) => c.id.equals(id))).write(_cuenta(i));

  /// Borra la cuenta. Sus movimientos se conservan en el historial (sin cuenta)
  /// y las transferencias que la involucran se eliminan.
  Future<void> eliminarCuenta(int id) => _db.transaction(() async {
        await (_db.update(_db.transacciones)..where((t) => t.cuentaId.equals(id)))
            .write(const TransaccionesCompanion(cuentaId: Value(null)));
        await (_db.update(_db.ingresosPlanificados)..where((p) => p.cuentaId.equals(id)))
            .write(const IngresosPlanificadosCompanion(cuentaId: Value(null)));
        await (_db.delete(_db.transferencias)
              ..where((t) => t.cuentaOrigenId.equals(id) | t.cuentaDestinoId.equals(id)))
            .go();
        await (_db.delete(_db.cuentas)..where((c) => c.id.equals(id))).go();
      });

  Future<Cuenta?> _cuentaPorId(int? id) async {
    if (id == null) return null;
    return (_db.select(_db.cuentas)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> _ajustarSaldo(int cuentaId, double delta) async {
    if (delta == 0) return;
    await _db.customUpdate(
      'UPDATE cuentas SET saldo = saldo + ? WHERE id = ?',
      variables: [Variable.withReal(delta), Variable.withInt(cuentaId)],
      updates: {_db.cuentas},
    );
  }

  Future<void> _aplicar(int? cuentaId, String tipoTx, double monto, {bool revertir = false}) async {
    final c = await _cuentaPorId(cuentaId);
    if (c == null) return;
    final delta = efectoEnSaldo(tipoTx: tipoTx, tipoCuenta: c.tipo, monto: monto);
    await _ajustarSaldo(c.id, revertir ? -delta : delta);
  }

  // ─────────────── Transacciones ───────────────

  /// Registra un movimiento, ajusta el saldo y, si es una compra con tarjeta de
  /// crédito, crea en el calendario de eventos los cobros de cada cuota.
  Future<int> crearTransaccion(TransaccionInput i, {int? metaId, int? ingresoPlanificadoId}) {
    if (i.monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _db.transaction(() async {
      final id = await _db.into(_db.transacciones).insert(TransaccionesCompanion.insert(
            tipo: i.tipo,
            monto: i.monto,
            descripcion: i.descripcion.trim(),
            fecha: i.fecha,
            cuentaId: Value(i.cuentaId),
            categoria: Value(i.categoria),
            cuotas: Value(i.cuotas < 1 ? 1 : i.cuotas),
            metaId: Value(metaId),
            ingresoPlanificadoId: Value(ingresoPlanificadoId),
          ));
      await _aplicar(i.cuentaId, i.tipo, i.monto);
      await _generarCobrosTarjeta(id, i);
      return id;
    });
  }

  Future<void> _generarCobrosTarjeta(int txId, TransaccionInput i) async {
    final c = await _cuentaPorId(i.cuentaId);
    if (c == null || !esCredito(c.tipo) || i.tipo != 'gasto') return;
    final cobros = cobrosTarjeta(fechaCompra: i.fecha, monto: i.monto, cuotas: i.cuotas, diaCorte: c.diaCorte);
    final n = cobros.length;
    await _db.batch((b) {
      b.insertAll(_db.eventos, [
        for (var k = 0; k < n; k++)
          EventosCompanion.insert(
            titulo: '${n > 1 ? 'Cuota ${k + 1}/$n: ' : 'Cobro tarjeta: '}${i.descripcion.trim()}',
            fecha: cobros[k].$1,
            hora: const Value('08:00'),
            categoria: const Value('servicios'),
            costo: Value(cobros[k].$2),
            tipoTransaccion: const Value('gasto'),
            estadoPago: const Value('pendiente'),
            tarjetaCreditoId: Value(c.id),
            transaccionId: Value(txId),
          ),
      ]);
    });
  }

  Future<void> _borrarCobrosPendientes(int txId) => (_db.delete(_db.eventos)
        ..where((e) => e.transaccionId.equals(txId) & e.estadoPago.equals('pendiente')))
      .go();

  Future<void> actualizarTransaccion(Transaccion old, TransaccionInput i) {
    if (i.monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _db.transaction(() async {
      await _aplicar(old.cuentaId, old.tipo, old.monto, revertir: true);
      await (_db.update(_db.transacciones)..where((t) => t.id.equals(old.id))).write(TransaccionesCompanion(
        tipo: Value(i.tipo),
        monto: Value(i.monto),
        descripcion: Value(i.descripcion.trim()),
        fecha: Value(i.fecha),
        categoria: Value(i.categoria),
        cuentaId: Value(i.cuentaId),
        cuotas: Value(i.cuotas < 1 ? 1 : i.cuotas),
      ));
      await _aplicar(i.cuentaId, i.tipo, i.monto);
      // Mejora sobre la web: los cobros pendientes de la tarjeta se recalculan.
      await _borrarCobrosPendientes(old.id);
      await _generarCobrosTarjeta(old.id, i);
      if (old.metaId != null && old.monto != i.monto) {
        await _sumarAMeta(old.metaId!, i.monto - old.monto);
      }
    });
  }

  /// Borra un movimiento revirtiendo su efecto (saldo, cuotas pendientes,
  /// aporte a meta y verificación de ingreso asociada).
  Future<void> eliminarTransaccion(Transaccion t) => _db.transaction(() async {
        await (_db.delete(_db.transacciones)..where((x) => x.id.equals(t.id))).go();
        await _aplicar(t.cuentaId, t.tipo, t.monto, revertir: true);
        await _borrarCobrosPendientes(t.id);
        if (t.metaId != null) await _sumarAMeta(t.metaId!, -t.monto);
        await (_db.delete(_db.verificaciones)..where((v) => v.transaccionId.equals(t.id))).go();
      });

  // ─────────────── Transferencias ───────────────

  Future<void> transferir({required int origenId, required int destinoId, required double monto, required String fecha, String descripcion = ''}) {
    if (origenId == destinoId) throw const FinanzasError('La cuenta de origen y destino deben ser diferentes');
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _db.transaction(() async {
      final o = await _cuentaPorId(origenId);
      final d = await _cuentaPorId(destinoId);
      if (o == null || d == null) throw const FinanzasError('Cuenta no encontrada');
      await _db.into(_db.transferencias).insert(TransferenciasCompanion.insert(
            cuentaOrigenId: origenId,
            cuentaDestinoId: destinoId,
            monto: monto,
            fecha: fecha,
            descripcion: Value(descripcion.trim()),
          ));
      // Crédito: retirar de la tarjeta aumenta la deuda; abonarle la reduce.
      await _ajustarSaldo(origenId, esCredito(o.tipo) ? monto : -monto);
      await _ajustarSaldo(destinoId, esCredito(d.tipo) ? -monto : monto);
    });
  }

  Future<void> eliminarTransferencia(Transferencia t) => _db.transaction(() async {
        final o = await _cuentaPorId(t.cuentaOrigenId);
        final d = await _cuentaPorId(t.cuentaDestinoId);
        await (_db.delete(_db.transferencias)..where((x) => x.id.equals(t.id))).go();
        if (o != null) await _ajustarSaldo(o.id, esCredito(o.tipo) ? -t.monto : t.monto);
        if (d != null) await _ajustarSaldo(d.id, esCredito(d.tipo) ? t.monto : -t.monto);
      });

  // ─────────────── Ingresos planificados ───────────────

  Future<int> crearPlan({required String descripcion, required double monto, required String frecuencia, required String fechaInicio, int? cuentaId}) {
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _db.into(_db.ingresosPlanificados).insert(IngresosPlanificadosCompanion.insert(
          descripcion: descripcion.trim(),
          monto: monto,
          frecuencia: frecuencia,
          fechaInicio: fechaInicio,
          cuentaId: Value(cuentaId),
        ));
  }

  Future<void> actualizarPlan(int id, {required String descripcion, required double monto, required String frecuencia, required String fechaInicio, int? cuentaId, bool activo = true}) =>
      (_db.update(_db.ingresosPlanificados)..where((p) => p.id.equals(id))).write(IngresosPlanificadosCompanion(
        descripcion: Value(descripcion.trim()),
        monto: Value(monto),
        frecuencia: Value(frecuencia),
        fechaInicio: Value(fechaInicio),
        cuentaId: Value(cuentaId),
        activo: Value(activo),
      ));

  Future<void> eliminarPlan(int id) => _db.transaction(() async {
        await (_db.delete(_db.verificaciones)..where((v) => v.ingresoPlanificadoId.equals(id))).go();
        await (_db.delete(_db.ingresosPlanificados)..where((p) => p.id.equals(id))).go();
      });

  /// Confirma que un ingreso esperado llegó: registra la transacción real y la
  /// verificación en una sola operación.
  Future<void> verificarIngreso({
    required IngresoPlanificado plan,
    required String fechaEsperada,
    required String fechaReal,
    required double montoReal,
    int? cuentaId,
  }) {
    if (montoReal <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _db.transaction(() async {
      final existe = await (_db.select(_db.verificaciones)
            ..where((v) => v.ingresoPlanificadoId.equals(plan.id) & v.fechaEsperada.equals(fechaEsperada)))
          .getSingleOrNull();
      if (existe != null) throw const FinanzasError('Esta fecha ya fue verificada para este ingreso');
      final cuenta = cuentaId ?? plan.cuentaId;
      final txId = await crearTransaccion(
        TransaccionInput(
          tipo: 'ingreso',
          monto: montoReal,
          descripcion: 'Cobro: ${plan.descripcion}',
          fecha: fechaReal,
          cuentaId: cuenta,
          categoria: 'otros',
        ),
        ingresoPlanificadoId: plan.id,
      );
      await _db.into(_db.verificaciones).insert(VerificacionesCompanion.insert(
            ingresoPlanificadoId: plan.id,
            fechaEsperada: fechaEsperada,
            fechaReal: fechaReal,
            montoReal: montoReal,
            transaccionId: Value(txId),
          ));
    });
  }

  Future<void> deshacerVerificacion(Verificacion v) => _db.transaction(() async {
        if (v.transaccionId != null) {
          final t = await (_db.select(_db.transacciones)..where((x) => x.id.equals(v.transaccionId!))).getSingleOrNull();
          if (t != null) await eliminarTransaccion(t);
        }
        await (_db.delete(_db.verificaciones)..where((x) => x.id.equals(v.id))).go();
      });

  // ─────────────── Metas ───────────────

  MetasCompanion _meta(MetaInput i) => MetasCompanion(
        nombre: Value(i.nombre.trim()),
        descripcion: Value(i.descripcion.trim()),
        montoObjetivo: Value(i.montoObjetivo),
        montoActual: Value(i.montoActual),
        fechaObjetivo: Value(i.fechaObjetivo),
        icono: Value(i.icono),
        color: Value(i.color),
        completada: Value(i.montoObjetivo > 0 && i.montoActual >= i.montoObjetivo),
      );

  Future<int> crearMeta(MetaInput i) {
    if (i.nombre.trim().isEmpty || i.montoObjetivo <= 0) {
      throw const FinanzasError('Nombre y monto objetivo son obligatorios');
    }
    return _db.into(_db.metas).insert(_meta(i));
  }

  Future<void> actualizarMeta(int id, MetaInput i) =>
      (_db.update(_db.metas)..where((m) => m.id.equals(id))).write(_meta(i));

  Future<void> eliminarMeta(int id) => _db.transaction(() async {
        await (_db.update(_db.transacciones)..where((t) => t.metaId.equals(id)))
            .write(const TransaccionesCompanion(metaId: Value(null)));
        await (_db.delete(_db.metas)..where((m) => m.id.equals(id))).go();
      });

  Future<void> _sumarAMeta(int metaId, double delta) async {
    await _db.customUpdate(
      'UPDATE metas SET monto_actual = MAX(0, monto_actual + ?), '
      'completada = CASE WHEN monto_actual + ? >= monto_objetivo THEN 1 ELSE 0 END WHERE id = ?',
      variables: [Variable.withReal(delta), Variable.withReal(delta), Variable.withInt(metaId)],
      updates: {_db.metas},
    );
  }

  /// Aporta a una meta. Si se elige cuenta, también se registra el movimiento
  /// (categoría ahorro) y se descuenta de esa cuenta. Devuelve true si con este
  /// aporte la meta quedó cumplida.
  Future<bool> aportarAMeta(Meta meta, double monto, {int? cuentaId, String? fecha}) {
    if (monto <= 0) throw const FinanzasError('El aporte debe ser mayor a 0');
    return _db.transaction(() async {
      if (cuentaId != null) {
        await crearTransaccion(
          TransaccionInput(
            tipo: 'gasto',
            monto: monto,
            descripcion: 'Aporte a meta: ${meta.nombre}',
            fecha: fecha ?? hoyYmd(),
            cuentaId: cuentaId,
            categoria: 'ahorro',
          ),
          metaId: meta.id,
        );
      }
      await _sumarAMeta(meta.id, monto);
      return !meta.completada && meta.montoActual + monto >= meta.montoObjetivo;
    });
  }

  // ─────────────── Presupuestos ───────────────

  Future<void> guardarPresupuesto({required String categoria, required double limite, required int mes, required int anio}) {
    if (limite <= 0) throw const FinanzasError('El límite debe ser mayor a 0');
    return _db.into(_db.presupuestos).insert(
          PresupuestosCompanion.insert(categoria: categoria, montoLimite: limite, mes: mes, anio: anio),
          onConflict: DoUpdate(
            (_) => PresupuestosCompanion(montoLimite: Value(limite)),
            target: [_db.presupuestos.categoria, _db.presupuestos.mes, _db.presupuestos.anio],
          ),
        );
  }

  /// Quita el límite de una categoría. Como los límites se arrastran de un mes
  /// al siguiente, se borran todos los de esa categoría.
  Future<void> quitarPresupuesto(String categoria) =>
      (_db.delete(_db.presupuestos)..where((p) => p.categoria.equals(categoria))).go();

  // ─────────────── Categorías ───────────────

  Future<void> crearCategoria(String label, String icono) async {
    final valor = slugCategoria(label);
    if (valor.isEmpty) throw const FinanzasError('El nombre de la categoría no es válido');
    final existe = await (_db.select(_db.categoriasFinanzas)..where((c) => c.valor.equals(valor))).getSingleOrNull();
    if (existe != null) throw const FinanzasError('Ya tienes una categoría con ese nombre');
    await _db.into(_db.categoriasFinanzas).insert(CategoriasFinanzasCompanion.insert(
          valor: valor,
          label: label.trim(),
          icono: Value(icono),
        ));
  }

  Future<void> eliminarCategoria(CategoriaFinanzas c) async {
    final usos = await _db.customSelect(
      'SELECT (SELECT COUNT(*) FROM transacciones WHERE categoria = ?1) + '
      '(SELECT COUNT(*) FROM presupuestos WHERE categoria = ?1) AS n',
      variables: [Variable.withString(c.valor)],
    ).getSingle();
    final n = usos.read<int>('n');
    if (n > 0) throw FinanzasError('No puedes eliminar esta categoría porque tiene $n registro(s) asociado(s).');
    await (_db.delete(_db.categoriasFinanzas)..where((x) => x.id.equals(c.id))).go();
  }
}

final financeRepoProvider = Provider((ref) => FinanceRepository(ref.watch(databaseProvider)));
