// Notificaciones push del servidor (Firebase Cloud Messaging).
//
// El cron del backend avisa a la hora exacta aunque la app lleve días sin
// abrirse o el evento se haya creado desde la web. Mientras el servidor no
// confirme que el push llega a este teléfono, la app mantiene sus avisos
// locales como respaldo (ver `programadorAvisosProvider`).
//
// La configuración de Firebase no se sube al repositorio: se inyecta al
// compilar con `--dart-define-from-file=firebase.json` (ver README). Sin ella
// la app funciona igual, solo con avisos locales.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'notification_service.dart';
import 'reminder_planner.dart';

/// Opciones de Firebase por plataforma, desde `--dart-define`.
class ConfigFirebase {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosBundleId = 'com.agendaservi.agendaservi';

  static FirebaseOptions? opciones() => construir(
        web: kIsWeb,
        plataforma: defaultTargetPlatform,
        projectId: projectId,
        senderId: senderId,
        androidApiKey: androidApiKey,
        androidAppId: androidAppId,
        iosApiKey: iosApiKey,
        iosAppId: iosAppId,
      );

  // Mismos formatos que exige el SDK nativo. En iOS, una clave mal formada
  // lanza una excepción de Objective-C (FIRInstallations validateAPIKey) que
  // Dart no puede atrapar y cierra la app al abrirla: por eso se valida aquí
  // y, si algo no cuadra, la app arranca sin push (con avisos locales).
  static final _apiKey = RegExp(r'^A[0-9A-Za-z_-]{38}$');
  static final _projectId = RegExp(r'^[a-z0-9-]{4,40}$');
  static final _senderId = RegExp(r'^\d{6,20}$');

  static FirebaseOptions? construir({
    required bool web,
    required TargetPlatform plataforma,
    required String projectId,
    required String senderId,
    required String androidApiKey,
    required String androidAppId,
    required String iosApiKey,
    required String iosAppId,
  }) {
    if (web || !_projectId.hasMatch(projectId) || !_senderId.hasMatch(senderId)) return null;
    bool valida(String apiKey, String appId, String so) =>
        _apiKey.hasMatch(apiKey) && RegExp('^1:$senderId:$so:[0-9a-f]+\$').hasMatch(appId);
    final opciones = switch (plataforma) {
      TargetPlatform.android when valida(androidApiKey, androidAppId, 'android') =>
        FirebaseOptions(apiKey: androidApiKey, appId: androidAppId, messagingSenderId: senderId, projectId: projectId),
      TargetPlatform.iOS when valida(iosApiKey, iosAppId, 'ios') =>
        FirebaseOptions(apiKey: iosApiKey, appId: iosAppId, messagingSenderId: senderId, projectId: projectId, iosBundleId: iosBundleId),
      _ => null,
    };
    if (opciones == null && (androidApiKey.isNotEmpty || iosApiKey.isNotEmpty)) {
      debugPrint('Configuración de Firebase inválida para $plataforma: se desactiva el push.');
    }
    return opciones;
  }
}

/// Contenido de un push del cron (ver `cron/push.js`).
class MensajePush {
  const MensajePush({required this.tipo, required this.clave, required this.titulo, required this.cuerpo, required this.canal, required this.ruta});
  final String tipo;
  final String clave;
  final String titulo;
  final String cuerpo;
  final CanalAviso canal;

  /// `dia:YYYY-MM-DD` (vacío si no abre un día concreto).
  final String ruta;

  static MensajePush? desde(Map<String, dynamic> data) {
    final titulo = data['titulo'];
    final clave = data['clave'];
    if (titulo is! String || titulo.isEmpty || clave is! String || clave.isEmpty) return null;
    return MensajePush(
      tipo: '${data['tipo'] ?? 'aviso'}',
      clave: clave,
      titulo: titulo,
      cuerpo: '${data['cuerpo'] ?? ''}',
      canal: data['canal'] == 'resumen' ? CanalAviso.resumen : CanalAviso.evento,
      ruta: '${data['ruta'] ?? ''}',
    );
  }

  /// Mismo id que el aviso local equivalente: si ambos llegan, uno reemplaza
  /// al otro en vez de duplicarse.
  int get id => idAviso(clave);

  /// Con la app abierta, las citas se anuncian con el aviso de la app.
  bool get seMuestraDentroDeLaApp => tipo == 'cita';
}

abstract class ServicioPush {
  /// 'android' o 'ios' (como lo espera `POST /api/dispositivos`).
  String get plataforma;

  /// Prepara Firebase. Devuelve false si este build o dispositivo no tiene push.
  Future<bool> iniciar({required void Function(String payload) alTocar});

  /// Token FCM del teléfono, o null si no hay push (sin configuración, sin
  /// permiso o, en iOS, sin la capacidad de notificaciones remotas).
  Future<String?> token();
  Stream<String> get tokenRenovado;

  /// Pushes recibidos con la app abierta.
  Stream<MensajePush> get recibidos;

  /// Ruta de la notificación push que abrió la app (iOS).
  Future<String?> payloadDeInicio();
}

class ServicioPushInerte implements ServicioPush {
  @override
  String get plataforma => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Future<bool> iniciar({required void Function(String payload) alTocar}) async => false;
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRenovado => const Stream.empty();
  @override
  Stream<MensajePush> get recibidos => const Stream.empty();
  @override
  Future<String?> payloadDeInicio() async => null;
}

/// Muestra un push como notificación local (Android recibe mensajes de datos
/// para controlar el canal, el estilo expandible y el id). Se usa tanto con la
/// app abierta como desde el isolate de segundo plano.
Future<void> mostrarPush(ServicioAvisos avisos, MensajePush m) => avisos.mostrarAhora(
      AvisoProgramado(id: m.id, cuando: DateTime.now().toUtc(), titulo: m.titulo, cuerpo: m.cuerpo, payload: m.ruta, canal: m.canal),
    );

/// Llega un push con la app cerrada o en segundo plano (Android). Corre en un
/// isolate aparte: no hay Riverpod ni base de datos, solo el plugin local.
@pragma('vm:entry-point')
Future<void> manejarPushEnSegundoPlano(RemoteMessage mensaje) async {
  // En iOS la alerta la muestra el sistema (APNs); aquí no hay nada que hacer.
  if (defaultTargetPlatform != TargetPlatform.android) return;
  final m = MensajePush.desde(mensaje.data);
  if (m == null) return;
  final avisos = ServicioAvisosLocal();
  await avisos.iniciar((_) {});
  await mostrarPush(avisos, m);
  await AlmacenAvisos.seguro().marcarPushRecibido();
}

class ServicioPushFirebase implements ServicioPush {
  ServicioPushFirebase(this._avisos);
  final ServicioAvisos _avisos;
  bool _listo = false;
  String? _rutaInicial;
  final _recibidos = StreamController<MensajePush>.broadcast();

  @override
  String get plataforma => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<bool> iniciar({required void Function(String payload) alTocar}) async {
    if (_listo) return true;
    final opciones = ConfigFirebase.opciones();
    if (opciones == null) return false;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: opciones);
      FirebaseMessaging.onBackgroundMessage(manejarPushEnSegundoPlano);
      final fm = FirebaseMessaging.instance;
      // Con la app abierta la app decide cómo mostrar cada push (en iOS el
      // sistema no muestra la alerta por su cuenta): las citas llegan como
      // aviso dentro de la app (ver `citasEnVivoProvider`) y lo demás como
      // notificación local, con el mismo id (sin duplicados).
      await fm.setForegroundNotificationPresentationOptions(alert: false, sound: false);
      FirebaseMessaging.onMessage.listen((r) async {
        final m = MensajePush.desde(r.data);
        if (m == null) return;
        if (!m.seMuestraDentroDeLaApp) await mostrarPush(_avisos, m);
        _recibidos.add(m);
      });
      // Toques en alertas de iOS (en Android las muestra el plugin local, que
      // ya entrega el toque a `alTocar`).
      FirebaseMessaging.onMessageOpenedApp.listen((r) {
        final ruta = r.data['ruta'];
        if (ruta is String && ruta.isNotEmpty) alTocar(ruta);
      });
      final inicial = await fm.getInitialMessage();
      final ruta = inicial?.data['ruta'];
      if (ruta is String && ruta.isNotEmpty) _rutaInicial = ruta;
      _listo = true;
      return true;
    } catch (e) {
      debugPrint('Push no disponible: $e');
      return false;
    }
  }

  @override
  Future<String?> token() async {
    if (!_listo) return null;
    final fm = FirebaseMessaging.instance;
    try {
      if (plataforma == 'ios') {
        // No muestra diálogo si el permiso ya se concedió desde la app; y
        // registra el teléfono en APNs. Sin la capacidad de push (p. ej. app
        // firmada con un Apple ID gratuito) nunca llega un token de APNs.
        await fm.requestPermission(alert: true, sound: true, badge: false);
        String? apns;
        for (var i = 0; i < 10 && apns == null; i++) {
          apns = await fm.getAPNSToken();
          if (apns == null) await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (apns == null) return null;
      }
      return await fm.getToken();
    } catch (e) {
      debugPrint('Sin token de push: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRenovado => _listo ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  @override
  Stream<MensajePush> get recibidos => _recibidos.stream;

  @override
  Future<String?> payloadDeInicio() async => _rutaInicial;
}

final servicioPushProvider = Provider<ServicioPush>((ref) {
  if (kIsWeb || ConfigFirebase.opciones() == null) return ServicioPushInerte();
  return ServicioPushFirebase(ref.read(servicioAvisosProvider));
});

// ---------------------------------------------------------------------------
//  Estado persistido (lo leen también las tareas de segundo plano)
// ---------------------------------------------------------------------------

/// Lo mínimo que necesitan los procesos de segundo plano, que no tienen
/// acceso a Riverpod ni a la base de datos de la app.
class ConfigAvisos {
  const ConfigAvisos({this.notificaciones = true, this.aviso30 = true, this.resumen = true, this.tokenPush, this.pushConfirmado = false, this.pushRecibido = false});
  final bool notificaciones;
  final bool aviso30;
  final bool resumen;

  /// Token FCM registrado en el servidor y si el servidor ya entregó un push.
  final String? tokenPush;
  final bool pushConfirmado;

  /// Llegó un push con la app cerrada (lo marca el isolate de segundo plano).
  final bool pushRecibido;

  bool get servidorAvisa => tokenPush != null && (pushConfirmado || pushRecibido);

  ConfigAvisos copyWith({bool? notificaciones, bool? aviso30, bool? resumen, String? tokenPush, bool? pushConfirmado, bool? pushRecibido, bool sinToken = false}) => ConfigAvisos(
        notificaciones: notificaciones ?? this.notificaciones,
        aviso30: aviso30 ?? this.aviso30,
        resumen: resumen ?? this.resumen,
        tokenPush: sinToken ? null : (tokenPush ?? this.tokenPush),
        pushConfirmado: pushConfirmado ?? this.pushConfirmado,
        pushRecibido: pushRecibido ?? this.pushRecibido,
      );

  Map<String, Object?> toJson() => {
        'notificaciones': notificaciones,
        'aviso30': aviso30,
        'resumen': resumen,
        'token': tokenPush,
        'confirmado': pushConfirmado,
        'recibido': pushRecibido,
      };

  static ConfigAvisos fromJson(Map<String, dynamic> j) => ConfigAvisos(
        notificaciones: j['notificaciones'] != false,
        aviso30: j['aviso30'] != false,
        resumen: j['resumen'] != false,
        tokenPush: j['token'] as String?,
        pushConfirmado: j['confirmado'] == true,
        pushRecibido: j['recibido'] == true,
      );
}

abstract class AlmacenAvisos {
  factory AlmacenAvisos.seguro() = _AlmacenSeguro;
  factory AlmacenAvisos.memoria() = _AlmacenMemoria;
  Future<ConfigAvisos> leer();
  Future<void> guardar(ConfigAvisos c);
  Future<void> marcarPushRecibido();

  /// Estado de cada cita la última vez que el usuario las vio (o que se
  /// revisaron en segundo plano): así se sabe qué cambió desde entonces.
  Future<Map<int, String>?> leerFotoCitas();
  Future<void> guardarFotoCitas(Map<int, String> foto);
}

class _AlmacenSeguro implements AlmacenAvisos {
  static const _k = 'avisos_cfg';
  final _s = const FlutterSecureStorage();

  @override
  Future<ConfigAvisos> leer() async {
    try {
      final v = await _s.read(key: _k);
      return v == null ? const ConfigAvisos() : ConfigAvisos.fromJson(jsonDecode(v) as Map<String, dynamic>);
    } catch (_) {
      return const ConfigAvisos();
    }
  }

  @override
  Future<void> guardar(ConfigAvisos c) async {
    try {
      await _s.write(key: _k, value: jsonEncode(c.toJson()));
    } catch (_) {}
  }

  @override
  Future<void> marcarPushRecibido() async => guardar((await leer()).copyWith(pushRecibido: true));

  static const _kCitas = 'citas_foto';

  @override
  Future<Map<int, String>?> leerFotoCitas() async {
    try {
      final v = await _s.read(key: _kCitas);
      if (v == null) return null;
      return {for (final e in (jsonDecode(v) as Map<String, dynamic>).entries) int.parse(e.key): '${e.value}'};
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardarFotoCitas(Map<int, String> foto) async {
    try {
      await _s.write(key: _kCitas, value: jsonEncode({for (final e in foto.entries) '${e.key}': e.value}));
    } catch (_) {}
  }
}

class _AlmacenMemoria implements AlmacenAvisos {
  ConfigAvisos _c = const ConfigAvisos();
  @override
  Future<ConfigAvisos> leer() async => _c;
  @override
  Future<void> guardar(ConfigAvisos c) async => _c = c;
  @override
  Future<void> marcarPushRecibido() async => _c = _c.copyWith(pushRecibido: true);
  Map<int, String>? _foto;
  @override
  Future<Map<int, String>?> leerFotoCitas() async => _foto;
  @override
  Future<void> guardarFotoCitas(Map<int, String> foto) async => _foto = foto;
}

final almacenAvisosProvider = Provider<AlmacenAvisos>((ref) => AlmacenAvisos.seguro());
