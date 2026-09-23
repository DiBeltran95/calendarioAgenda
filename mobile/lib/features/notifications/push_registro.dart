import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/json.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import 'notification_service.dart';
import 'push_service.dart';

/// Cómo le llegan los avisos a este teléfono.
class EstadoPush {
  const EstadoPush({this.disponible = false, this.registrado = false, this.confirmado = false});

  /// El teléfono obtuvo un token de push (hay Firebase y permiso).
  final bool disponible;

  /// El servidor tiene el token de este teléfono.
  final bool registrado;

  /// El servidor ya entregó al menos un push aquí: desde ahora los avisos
  /// llegan del servidor y los locales se apagan para no duplicarlos.
  final bool confirmado;
}

class EstadoPushNotifier extends Notifier<EstadoPush> {
  @override
  EstadoPush build() => const EstadoPush();
  void set(EstadoPush e) => state = e;
}

final estadoPushProvider = NotifierProvider<EstadoPushNotifier, EstadoPush>(EstadoPushNotifier.new);

/// Registra el teléfono en `POST /api/dispositivos` con sus preferencias de
/// avisos y lo da de baja al cerrar sesión.
class RegistroPush {
  RegistroPush(this._ref);
  final Ref _ref;

  String? _firma;
  DateTime? _ultimo;
  Future<void>? _enCurso;

  /// Cada cuánto se renueva el registro aunque nada cambie (mantiene vivo el
  /// dispositivo en el servidor, que borra los inactivos tras 120 días).
  static const renovar = Duration(hours: 12);

  AlmacenAvisos get _almacen => _ref.read(almacenAvisosProvider);

  void _estado(EstadoPush e) {
    if (_ref.mounted) _ref.read(estadoPushProvider.notifier).set(e);
  }

  /// Último estado conocido (sirve sin conexión y evita reprogramar los avisos
  /// locales en cada arranque).
  Future<void> cargarGuardado() async {
    final c = await _almacen.leer();
    if (c.tokenPush != null) _estado(EstadoPush(disponible: true, registrado: true, confirmado: c.servidorAvisa));
  }

  Future<void> sincronizar({bool forzar = false}) => _enCurso ??= _sincronizar(forzar).whenComplete(() => _enCurso = null);

  Future<void> _sincronizar(bool forzar) async {
    final sesion = _ref.read(sesionProvider).value;
    if (sesion == null) return;
    final prefs = _ref.read(preferenciasProvider).value ?? const Preferencias();
    final permiso = _ref.read(permisoAvisosProvider).value;
    final activo = prefs.notificaciones && permiso == PermisoAvisos.concedido;

    // Las tareas de segundo plano leen de aquí las preferencias.
    var cfg = await _almacen.leer();
    cfg = cfg.copyWith(notificaciones: prefs.notificaciones, aviso30: prefs.aviso30, resumen: prefs.resumenDiario);
    await _almacen.guardar(cfg);

    if (permiso != PermisoAvisos.concedido) return; // sin permiso no hay token útil
    final token = await _ref.read(servicioPushProvider).token();
    if (!_ref.mounted) return;
    if (token == null) {
      if (cfg.tokenPush != null) await _almacen.guardar(cfg.copyWith(sinToken: true, pushConfirmado: false, pushRecibido: false));
      _estado(const EstadoPush());
      return;
    }

    final firma = '${sesion.usuario.id}|$token|$activo|${prefs.aviso30}|${prefs.resumenDiario}';
    final reciente = _ultimo != null && DateTime.now().difference(_ultimo!) < renovar;
    if (!forzar && firma == _firma && reciente && _ref.read(estadoPushProvider).confirmado) return;

    final mismoToken = cfg.tokenPush == token;
    try {
      final r = asMap(await _ref.read(apiProvider).post('/api/dispositivos', body: {
        'token': token,
        'plataforma': _ref.read(servicioPushProvider).plataforma,
        'avisos': activo,
        'aviso_30m': prefs.aviso30,
        'resumen': prefs.resumenDiario,
      }));
      if (!_ref.mounted) return;
      final pendiente = asBool(r['pendiente']);
      // Un registro nuevo (otro usuario, token renovado o borrado por el
      // servidor) invalida lo que se supiera del token anterior.
      cfg = cfg.copyWith(
        tokenPush: token,
        pushConfirmado: asBool(r['confirmado']) && !pendiente,
        pushRecibido: mismoToken && !pendiente && cfg.pushRecibido,
      );
      await _almacen.guardar(cfg);
      _firma = firma;
      _ultimo = DateTime.now();
      _estado(EstadoPush(disponible: true, registrado: true, confirmado: cfg.servidorAvisa));
    } catch (_) {
      // Sin conexión: se conserva lo último conocido para este token.
      _estado(EstadoPush(disponible: true, registrado: mismoToken, confirmado: mismoToken && cfg.servidorAvisa));
    }
  }

  /// Llegó un push con la app abierta: el canal funciona de extremo a extremo.
  Future<void> marcarRecibido() async {
    final cfg = await _almacen.leer();
    if (cfg.tokenPush == null) return;
    await _almacen.guardar(cfg.copyWith(pushRecibido: true));
    _estado(const EstadoPush(disponible: true, registrado: true, confirmado: true));
  }

  /// Al cerrar sesión: el servidor deja de enviar avisos de esta cuenta aquí.
  Future<void> darDeBaja() async {
    final cfg = await _almacen.leer();
    final token = cfg.tokenPush;
    if (token != null) {
      try {
        await _ref.read(apiProvider).post('/api/dispositivos/baja', body: {'token': token}).timeout(const Duration(seconds: 6));
      } catch (_) {
        // Sin conexión: el servidor lo reasignará en el próximo inicio de
        // sesión o lo borrará cuando FCM lo dé por inválido.
      }
    }
    await _almacen.guardar(const ConfigAvisos());
    _firma = null;
    _ultimo = null;
    _estado(const EstadoPush());
  }
}

final registroPushProvider = Provider<RegistroPush>(RegistroPush.new);

/// Mantiene el registro al día: al iniciar sesión, al cambiar las
/// preferencias o el permiso, al renovarse el token y al llegar un push.
final sincronizadorPushProvider = Provider<void>((ref) {
  final registro = ref.read(registroPushProvider);
  final push = ref.read(servicioPushProvider);
  final sesion = ref.watch(sesionProvider).value;
  ref.watch(preferenciasProvider.select((p) => (p.value?.notificaciones, p.value?.aviso30, p.value?.resumenDiario)));
  ref.watch(permisoAvisosProvider.select((p) => p.value));
  if (sesion == null) return;

  final subs = [
    push.tokenRenovado.listen((_) => registro.sincronizar(forzar: true)),
    push.recibidos.listen((_) => registro.marcarRecibido()),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
  });
  unawaited(registro.cargarGuardado().then((_) => registro.sincronizar()));
});
