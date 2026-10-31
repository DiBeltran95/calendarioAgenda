import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/api_client.dart';
import '../../core/net/api_exception.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
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

  /// Mismo saneamiento que `saveAccount` de la web.
  Map<String, dynamic> toBody() => {
        'nombre': nombre.trim(),
        'tipo': tipo,
        'saldo': saldo,
        'limite': esCredito(tipo) ? limite : 0,
        'interes_tasa': tipo == 'cdt' ? interesTasa : 0,
        'plazo_dias': tipo == 'cdt' ? plazoDias : 0,
        'fecha_inicio': tipo == 'cdt' ? (fechaInicio ?? hoyYmd()) : null,
        'dia_corte': esCredito(tipo) ? diaCorte : null,
      };
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

  factory TransaccionInput.desde(Transaccion t) => TransaccionInput(
        tipo: t.tipo,
        monto: t.monto,
        descripcion: t.descripcion,
        fecha: t.fecha,
        cuentaId: t.cuentaId,
        categoria: t.categoria,
        cuotas: t.cuotas,
      );

  Map<String, dynamic> toBody() => {
        'cuenta_id': cuentaId,
        'tipo': tipo,
        'monto': monto,
        'descripcion': descripcion.trim(),
        'fecha': fecha,
        'categoria': categoria,
        'cuotas': cuotas < 1 ? 1 : cuotas,
      };
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
    this.completada = false,
  });
  final String nombre;
  final String descripcion;
  final double montoObjetivo;
  final double montoActual;
  final String? fechaObjetivo;
  final String icono;
  final int color;
  final bool completada;

  factory MetaInput.desde(Meta m) => MetaInput(
        nombre: m.nombre,
        montoObjetivo: m.montoObjetivo,
        descripcion: m.descripcion,
        montoActual: m.montoActual,
        fechaObjetivo: m.fechaObjetivo,
        icono: m.icono,
        color: m.color,
        completada: m.completada,
      );

  Map<String, dynamic> toBody() => {
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'monto_objetivo': montoObjetivo,
        'monto_actual': montoActual,
        'fecha_objetivo': fechaObjetivo,
        'icono': icono,
        'color': colorAHex(color),
        'completada': completada || (montoObjetivo > 0 && montoActual >= montoObjetivo),
      };
}

/// Error de negocio con el mensaje del servidor (o de validación local).
class FinanzasError implements Exception {
  const FinanzasError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Finanzas contra `/api/finanzas/...`. El servidor aplica los saldos, las
/// cuotas de tarjeta (que llegan al calendario de eventos y al WhatsApp) y las
/// transferencias en transacciones atómicas; la app solo sincroniza.
class FinanceRepository {
  FinanceRepository(this._api, this._sync, this._ref);
  final ApiClient _api;
  final Sincronizador _sync;
  final Ref _ref;

  Future<T> _op<T>(Future<T> Function() f, {bool meses = true, bool presupuestos = false}) async {
    try {
      final r = await f();
      await _sync.despuesDeCambio(meses: meses, presupuestos: presupuestos);
      return r;
    } on ApiException catch (e) {
      throw FinanzasError(e.message);
    }
  }

  // ─────────────── Cuentas ───────────────

  Future<int> crearCuenta(CuentaInput i) =>
      _op(() async => asInt(asMap(await _api.post('/api/finanzas/cuentas', body: i.toBody()))['id']), meses: false);

  Future<void> actualizarCuenta(int id, CuentaInput i) => _op(() => _api.put('/api/finanzas/cuentas/$id', body: i.toBody()), meses: false);

  Future<void> eliminarCuenta(int id) => _op(() => _api.delete('/api/finanzas/cuentas/$id'));

  /// Activa o cambia las ganancias automáticas de una cuenta. Con [recalcular] rehace
  /// lo ya sumado; sin él, la tasa nueva aplica de aquí en adelante.
  Future<void> activarGanancias(int id, {required double tasa, required String desde, bool recalcular = false}) =>
      _op(() => _api.put('/api/finanzas/cuentas/$id/ganancias', body: {'tasa': tasa, 'desde': desde, 'recalcular': recalcular}));

  /// Las apaga. Con [quitar], también borra lo que ya se había sumado al saldo.
  Future<void> apagarGanancias(int id, {bool quitar = false}) => _op(() => _api.put('/api/finanzas/cuentas/$id/ganancias', body: {'desde': null, 'quitar': quitar}));

  // ─────────────── Transacciones ───────────────

  Future<int> crearTransaccion(TransaccionInput i) {
    if (i.monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() async => asInt(asMap(await _api.post('/api/finanzas/transacciones', body: i.toBody()))['id']));
  }

  Future<void> actualizarTransaccion(Transaccion old, TransaccionInput i) {
    if (i.monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() => _api.put('/api/finanzas/transacciones/${old.id}', body: i.toBody()));
  }

  /// El servidor revierte el saldo y borra las cuotas pendientes asociadas.
  Future<void> eliminarTransaccion(Transaccion t) => _op(() => _api.delete('/api/finanzas/transacciones/${t.id}'));

  // ─────────────── Transferencias ───────────────

  Future<void> transferir({required int origenId, required int destinoId, required double monto, required String fecha, String descripcion = ''}) {
    if (origenId == destinoId) throw const FinanzasError('La cuenta de origen y destino deben ser diferentes');
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() => _api.post('/api/finanzas/transferencias', body: {
          'cuenta_origen_id': origenId,
          'cuenta_destino_id': destinoId,
          'monto': monto,
          'descripcion': descripcion.trim(),
          'fecha': fecha,
        }));
  }

  Future<void> eliminarTransferencia(Transferencia t) => _op(() => _api.delete('/api/finanzas/transferencias/${t.id}'));

  // ─────────────── Ingresos planificados ───────────────

  Future<void> crearPlan({required String descripcion, required double monto, required String frecuencia, required String fechaInicio, int? cuentaId}) {
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(
      () => _api.post('/api/finanzas/ingresos-planificados', body: {
        'cuenta_id': cuentaId,
        'descripcion': descripcion.trim(),
        'monto': monto,
        'frecuencia': frecuencia,
        'fecha_inicio': fechaInicio,
      }),
      meses: false,
    );
  }

  Future<void> eliminarPlan(int id) => _op(() => _api.delete('/api/finanzas/ingresos-planificados/$id'), meses: false);

  /// Confirma que un ingreso esperado llegó: el servidor registra la
  /// transacción y la verificación, y suma el saldo.
  Future<void> verificarIngreso({required IngresoPlanificado plan, required String fechaEsperada, required String fechaReal, required double montoReal, int? cuentaId}) {
    if (montoReal <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() => _api.post('/api/finanzas/ingresos-planificados/verificar', body: {
          'ingreso_planificado_id': plan.id,
          'fecha_esperada': fechaEsperada,
          'fecha_real': fechaReal,
          'monto_real': montoReal,
          'cuenta_id': cuentaId ?? plan.cuentaId,
        }));
  }

  Future<void> deshacerVerificacion(Verificacion v) => _op(() => _api.delete('/api/finanzas/verificaciones/${v.id}'));

  // ─────────────── Metas ───────────────

  Future<void> crearMeta(MetaInput i) {
    if (i.nombre.trim().isEmpty || i.montoObjetivo <= 0) throw const FinanzasError('Nombre y monto objetivo son obligatorios');
    return _op(() => _api.post('/api/finanzas/metas', body: i.toBody()), meses: false);
  }

  Future<void> actualizarMeta(int id, MetaInput i) => _op(() => _api.put('/api/finanzas/metas/$id', body: i.toBody()), meses: false);

  Future<void> eliminarMeta(int id) => _op(() => _api.delete('/api/finanzas/metas/$id'), meses: false);

  /// Aporta a una meta. Si se elige cuenta, primero se registra el gasto de
  /// ahorro (como "Aportar" en la web) y luego se suma a la meta. Devuelve
  /// true si con este aporte la meta quedó cumplida.
  Future<bool> aportarAMeta(Meta meta, double monto, {int? cuentaId, String? fecha}) async {
    if (monto <= 0) throw const FinanzasError('El aporte debe ser mayor a 0');
    final nuevo = meta.montoActual + monto;
    final cumplida = !meta.completada && nuevo >= meta.montoObjetivo;
    await _op(() async {
      if (cuentaId != null) {
        await _api.post('/api/finanzas/transacciones', body: TransaccionInput(
          tipo: 'gasto',
          monto: monto,
          descripcion: 'Aporte a meta: ${meta.nombre}',
          fecha: fecha ?? hoyYmd(),
          cuentaId: cuentaId,
          categoria: 'ahorro',
        ).toBody());
      }
      final m = MetaInput.desde(meta);
      await _api.put('/api/finanzas/metas/${meta.id}', body: MetaInput(
        nombre: m.nombre,
        montoObjetivo: m.montoObjetivo,
        descripcion: m.descripcion,
        montoActual: nuevo,
        fechaObjetivo: m.fechaObjetivo,
        icono: m.icono,
        color: m.color,
        completada: nuevo >= m.montoObjetivo,
      ).toBody());
    }, meses: cuentaId != null);
    return cumplida;
  }

  // ─────────────── Presupuestos ───────────────

  Future<void> guardarPresupuesto({required String categoria, required double limite, required int mes, required int anio}) {
    if (limite <= 0) throw const FinanzasError('El límite debe ser mayor a 0');
    return _op(
      () => _api.post('/api/finanzas/presupuestos', body: {'categoria': categoria, 'monto_limite': limite, 'mes': mes, 'anio': anio}),
      presupuestos: true,
    );
  }

  /// Quita el límite de una categoría. Como la app arrastra los límites de un
  /// mes al siguiente, se borran todos los de esa categoría.
  Future<void> quitarPresupuesto(String categoria) async {
    final todos = _ref.read(presupuestosProvider).value ?? const <Presupuesto>[];
    await _op(() async {
      for (final p in todos.where((p) => p.categoria == categoria)) {
        await _api.delete('/api/finanzas/presupuestos/${p.id}');
      }
    }, presupuestos: true);
  }

  // ─────────────── Categorías ───────────────

  Future<void> crearCategoria(String label, String icono) {
    if (label.trim().isEmpty) throw const FinanzasError('Escribe un nombre para la categoría.');
    return _op(() => _api.post('/api/finanzas/categorias', body: {'label': label.trim(), 'icono': icono}), meses: false);
  }

  Future<void> eliminarCategoria(CategoriaFinanzas c) => _op(() => _api.delete('/api/finanzas/categorias/${c.id}'), meses: false);
}

final financeRepoProvider = Provider((ref) => FinanceRepository(ref.watch(apiProvider), ref.watch(sincronizadorProvider), ref));
