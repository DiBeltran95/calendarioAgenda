import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/net/json.dart';
import '../../../core/net/tiempo_real.dart';
import '../../../core/session.dart';
import '../../../data/sync.dart';
import '../../citas/citas_en_vivo.dart' show AvisoVivo, TipoAvisoVivo, avisoVivoProvider;
import '../finance_repository.dart';
import 'lector_pagos.dart';
import 'pagos_logica.dart';

/// Ruta de la bandeja (también la abre la notificación de Android y el Atajo).
const rutaPagos = '/finanzas/pagos';

class PagosPendientesNotifier extends AsyncNotifier<List<CapturaPago>> with CacheRed<List<CapturaPago>> {
  @override
  String get claveCache => 'pagos:pendientes';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/capturas');

  @override
  List<CapturaPago> parsear(Object? json) => parseList(json, CapturaPago.fromJson);

  @override
  Object? serializar(List<CapturaPago> v) => [for (final c in v) c.toJson()];

  @override
  Future<List<CapturaPago>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }

  void agregar(CapturaPago c) {
    final l = [...?state.value];
    if (l.any((x) => x.id == c.id)) return;
    fijar([c, ...l]..sort((a, b) => b.fecha.compareTo(a.fecha)));
  }

  void quitar(int id) => fijar([...?state.value].where((x) => x.id != id).toList());
}

final pagosPendientesProvider = AsyncNotifierProvider<PagosPendientesNotifier, List<CapturaPago>>(PagosPendientesNotifier.new, retry: sinReintento);

/// Lo aprendido: categoría y cuenta por comercio y tarjeta.
final preferenciasPagosProvider = FutureProvider<List<PreferenciaPago>>((ref) async {
  ref.watch(usuarioIdProvider);
  try {
    return parseList(await ref.read(apiProvider).get('/api/capturas/preferencias'), PreferenciaPago.fromJson);
  } catch (_) {
    return const [];
  }
});

/// Clave personal que usa el Atajo de iPhone.
class ClaveAtajo {
  const ClaveAtajo({required this.clave, this.usado});
  final String clave;

  /// Última vez que el Atajo envió un pago (null: aún no funciona).
  final DateTime? usado;
}

final claveAtajoProvider = FutureProvider.autoDispose<ClaveAtajo>((ref) async {
  final r = asMap(await ref.read(apiProvider).get('/api/capturas/clave'));
  return ClaveAtajo(clave: asString(r['clave']), usado: DateTime.tryParse(asString(r['usado'])));
});

/// ¿El usuario dio acceso a las notificaciones? (Android)
final accesoAvisosPagosProvider = FutureProvider.autoDispose<bool>((ref) => ref.read(lectorPagosProvider).acceso());

class PagosRepository {
  PagosRepository(this._ref);
  final Ref _ref;

  bool _sincronizando = false;

  /// Sube los avisos de bancos que el teléfono guardó (Android). Devuelve
  /// cuántos pagos nuevos quedaron por clasificar.
  Future<int> sincronizarAndroid() async {
    final lector = _ref.read(lectorPagosProvider);
    if (!lector.soportado || _sincronizando || _ref.read(usuarioIdProvider) == 0) return 0;
    _sincronizando = true;
    try {
      final crudos = await lector.pendientes();
      if (crudos.isEmpty) return 0;
      final validos = <Map<String, dynamic>>[];
      for (final a in crudos) {
        final i = interpretarAviso(app: a.app, paquete: a.paquete, titulo: a.titulo, texto: a.texto, fecha: a.fecha);
        if (i != null) validos.add(i.toBody());
      }
      var nuevas = 0;
      for (var i = 0; i < validos.length; i += 50) {
        final r = asMap(await _ref.read(apiProvider).post('/api/capturas', body: {'capturas': validos.sublist(i, i + 50 > validos.length ? validos.length : i + 50)}));
        nuevas += asInt(r['nuevas']);
      }
      // Solo se borran de la cola cuando el servidor ya los tiene.
      await lector.quitar([for (final a in crudos) a.id]);
      if (nuevas > 0) await _ref.read(pagosPendientesProvider.notifier).refrescar();
      return nuevas;
    } catch (e) {
      debugPrint('No se pudieron subir los pagos: $e');
      return 0;
    } finally {
      _sincronizando = false;
    }
  }

  /// Registra el pago como movimiento de Finanzas y lo saca de la bandeja.
  Future<void> registrar(CapturaPago c, {required String categoria, int? cuentaId, String? descripcion, String? tipo, double? monto}) async {
    final input = TransaccionInput(
      tipo: tipo ?? c.tipo,
      monto: monto ?? c.monto,
      descripcion: (descripcion ?? c.titulo).trim().isEmpty ? c.titulo : (descripcion ?? c.titulo),
      fecha: ymd(c.fecha.toLocal()),
      cuentaId: cuentaId,
      categoria: categoria,
    );
    final id = await _ref.read(financeRepoProvider).crearTransaccion(input);
    await marcarRegistrado(c, transaccionId: id, categoria: categoria, cuentaId: cuentaId);
  }

  /// Tras crear el movimiento por otro camino (formulario completo).
  Future<void> marcarRegistrado(CapturaPago c, {required int transaccionId, required String categoria, int? cuentaId}) async {
    _ref.read(pagosPendientesProvider.notifier).quitar(c.id);
    try {
      await _ref.read(apiProvider).put('/api/capturas/${c.id}', body: {'estado': 'registrada', 'transaccion_id': transaccionId, 'categoria': categoria, 'cuenta_id': cuentaId});
      _ref.invalidate(preferenciasPagosProvider);
    } catch (e) {
      // El movimiento ya existe; si no se pudo marcar, volverá a la bandeja.
      debugPrint('No se pudo marcar el pago ${c.id}: $e');
    }
  }

  Future<void> descartar(CapturaPago c) async {
    _ref.read(pagosPendientesProvider.notifier).quitar(c.id);
    try {
      await _ref.read(apiProvider).put('/api/capturas/${c.id}', body: {'estado': 'descartada'});
    } catch (e) {
      _ref.read(pagosPendientesProvider.notifier).agregar(c);
      rethrow;
    }
  }

  Future<void> deshacerDescarte(CapturaPago c) async {
    await _ref.read(apiProvider).put('/api/capturas/${c.id}', body: {'estado': 'pendiente'});
    _ref.read(pagosPendientesProvider.notifier).agregar(c);
  }

  Future<ClaveAtajo> nuevaClave() async {
    final r = asMap(await _ref.read(apiProvider).post('/api/capturas/clave'));
    _ref.invalidate(claveAtajoProvider);
    return ClaveAtajo(clave: asString(r['clave']));
  }
}

final pagosRepoProvider = Provider(PagosRepository.new);

/// Pagos que llegan con la app abierta (Atajo de iPhone o desde otro
/// teléfono): entran a la bandeja al instante y se anuncian arriba.
final pagosEnVivoProvider = Provider<void>((ref) {
  final uid = ref.watch(usuarioIdProvider);
  if (uid == 0) return;
  final sub = ref.read(tiempoRealProvider).eventos.where((e) => e.tipo == 'captura').listen((e) {
    final c = CapturaPago.fromJson(asMap(e.datos['captura']));
    if (c.id == 0) return;
    ref.read(pagosPendientesProvider.notifier).agregar(c);
    ref.read(avisoVivoProvider.notifier).mostrar(AvisoVivo(
      clave: 'pago:${c.id}',
      tipo: TipoAvisoVivo.pago,
      titulo: 'Pago detectado: ${cop(c.monto)}',
      cuerpo: '${c.titulo} · toca para asignarle categoría',
      ruta: rutaPagos,
    ));
  });
  ref.onDispose(sub.cancel);
  // Al iniciar sesión se suben los avisos que el teléfono guardó.
  unawaited(Future<void>.delayed(const Duration(seconds: 2), () => ref.mounted ? ref.read(pagosRepoProvider).sincronizarAndroid() : 0));
});
