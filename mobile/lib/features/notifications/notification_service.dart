import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/dates.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
import 'push_registro.dart';
import 'reminder_planner.dart';

/// Estado del permiso de notificaciones del sistema.
enum PermisoAvisos { concedido, denegado, noSoportado }

/// Contrato del servicio (en pruebas y en web se usa una versión inerte).
abstract class ServicioAvisos {
  Future<void> iniciar(void Function(String payload) alTocar);
  Future<PermisoAvisos> permiso();
  Future<PermisoAvisos> pedirPermiso();
  Future<void> reprogramar(List<AvisoProgramado> avisos);
  Future<void> cancelarTodo();
  Future<void> prueba();

  /// Muestra un aviso de inmediato (p. ej. un push del servidor en Android).
  Future<void> mostrarAhora(AvisoProgramado aviso);

  /// Payload de la notificación que abrió la app (si fue así).
  Future<String?> payloadDeInicio();
  int get programados;
}

class ServicioAvisosInerte implements ServicioAvisos {
  List<AvisoProgramado> ultimos = const [];
  final mostrados = <AvisoProgramado>[];
  @override
  Future<void> mostrarAhora(AvisoProgramado aviso) async => mostrados.add(aviso);
  @override
  Future<void> iniciar(void Function(String payload) alTocar) async {}
  @override
  Future<PermisoAvisos> permiso() async => PermisoAvisos.noSoportado;
  @override
  Future<PermisoAvisos> pedirPermiso() async => PermisoAvisos.noSoportado;
  @override
  Future<void> reprogramar(List<AvisoProgramado> avisos) async => ultimos = avisos;
  @override
  Future<void> cancelarTodo() async => ultimos = const [];
  @override
  Future<void> prueba() async {}
  @override
  Future<String?> payloadDeInicio() async => null;
  @override
  int get programados => ultimos.length;
}

class ServicioAvisosLocal implements ServicioAvisos {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;
  int _programados = 0;

  static const _canalEventos = AndroidNotificationDetails(
    'eventos',
    'Recordatorios de eventos',
    channelDescription: 'Avisos 30 minutos antes y a la hora de tus eventos',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF25D366),
    category: AndroidNotificationCategory.reminder,
    styleInformation: BigTextStyleInformation(''),
  );

  static const _canalResumen = AndroidNotificationDetails(
    'resumen',
    'Resumen del día',
    channelDescription: 'Resumen de las 7:00 a. m. con cumpleaños, pagos y festivos',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    color: Color(0xFF2DD4BF),
    styleInformation: BigTextStyleInformation(''),
  );

  static const _darwin = DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true);

  @override
  int get programados => _programados;

  @override
  Future<void> iniciar(void Function(String payload) alTocar) async {
    if (_listo) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_agenda'),
        // El permiso se pide después, con una explicación previa en la app.
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => alTocar(r.payload ?? ''),
    );
    _listo = true;
  }

  @override
  Future<PermisoAvisos> permiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return (await android.areNotificationsEnabled() ?? false) ? PermisoAvisos.concedido : PermisoAvisos.denegado;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final p = await ios.checkPermissions();
      return (p?.isEnabled ?? false) ? PermisoAvisos.concedido : PermisoAvisos.denegado;
    }
    return PermisoAvisos.noSoportado;
  }

  @override
  Future<PermisoAvisos> pedirPermiso() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final ok = await android.requestNotificationsPermission() ?? false;
      return ok ? PermisoAvisos.concedido : PermisoAvisos.denegado;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final ok = await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      return ok ? PermisoAvisos.concedido : PermisoAvisos.denegado;
    }
    return PermisoAvisos.noSoportado;
  }

  /// Hora exacta si el sistema lo permite; si no, "inexacta" (Android puede
  /// agruparla unos minutos, pero nunca se pierde).
  Future<AndroidScheduleMode> _modo() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final exacto = await android.canScheduleExactNotifications() ?? false;
    return exacto ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  NotificationDetails _detalles(CanalAviso canal) => NotificationDetails(
        android: canal == CanalAviso.evento ? _canalEventos : _canalResumen,
        iOS: _darwin,
      );

  @override
  Future<void> reprogramar(List<AvisoProgramado> avisos) async {
    if (!_listo) return;
    // Solo los pendientes: las notificaciones ya mostradas se quedan en la
    // bandeja hasta que el usuario las lea.
    await _plugin.cancelAllPendingNotifications();
    final modo = await _modo();
    var n = 0;
    for (final a in avisos) {
      try {
        await _plugin.zonedSchedule(
          id: a.id,
          title: a.titulo,
          body: a.cuerpo,
          scheduledDate: tz.TZDateTime.from(a.cuando, tz.UTC),
          notificationDetails: _detalles(a.canal),
          androidScheduleMode: modo,
          payload: a.payload,
        );
        n++;
      } catch (e) {
        debugPrint('No se pudo programar el aviso ${a.id}: $e');
      }
    }
    _programados = n;
  }

  @override
  Future<void> cancelarTodo() async {
    if (!_listo) return;
    await _plugin.cancelAllPendingNotifications();
    _programados = 0;
  }

  @override
  Future<void> mostrarAhora(AvisoProgramado a) async {
    if (!_listo) return;
    // Si había un aviso local pendiente con la misma clave, este lo sustituye.
    await _plugin.show(id: a.id, title: a.titulo, body: a.cuerpo, notificationDetails: _detalles(a.canal), payload: a.payload);
  }

  @override
  Future<void> prueba() => _plugin.show(
        id: 1,
        title: '🔔 ¡Las notificaciones funcionan!',
        body: 'Así te avisaremos de tus eventos, pagos y cumpleaños.',
        notificationDetails: const NotificationDetails(android: _canalEventos, iOS: _darwin),
        payload: 'dia:${hoyYmd()}',
      );

  @override
  Future<String?> payloadDeInicio() async {
    final d = await _plugin.getNotificationAppLaunchDetails();
    return (d?.didNotificationLaunchApp ?? false) ? d?.notificationResponse?.payload : null;
  }
}

/// En web el plugin no programa notificaciones: se usa la versión inerte.
final servicioAvisosProvider = Provider<ServicioAvisos>((ref) => kIsWeb ? ServicioAvisosInerte() : ServicioAvisosLocal());

/// Permiso actual (se reevalúa al volver a la app o tras pedirlo).
class PermisoNotifier extends AsyncNotifier<PermisoAvisos> {
  @override
  Future<PermisoAvisos> build() => ref.read(servicioAvisosProvider).permiso();

  Future<PermisoAvisos> pedir() async {
    await ref.read(ajustesRepoProvider).marcarPermisoPedido();
    final p = await ref.read(servicioAvisosProvider).pedirPermiso();
    state = AsyncData(p);
    return p;
  }

  Future<void> revisar() async => state = AsyncData(await ref.read(servicioAvisosProvider).permiso());
}

final permisoAvisosProvider = AsyncNotifierProvider<PermisoNotifier, PermisoAvisos>(PermisoNotifier.new);

/// Cuántas notificaciones hay programadas (para mostrarlo en Ajustes).
class ProgramadosNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void set(int n) => state = n;
}

final avisosProgramadosProvider = NotifierProvider<ProgramadosNotifier, int>(ProgramadosNotifier.new);

/// Mantiene las notificaciones locales sincronizadas con los datos: cada vez
/// que cambian los eventos, cumpleaños, cuentas o las preferencias se
/// recalcula el plan de los próximos 14 días (con un pequeño retardo para
/// agrupar).
///
/// Cuando el servidor ya entrega push a este teléfono los avisos locales se
/// apagan: el cron avisa a la misma hora aunque el evento venga de la web.
final programadorAvisosProvider = Provider<void>((ref) {
  final servicio = ref.watch(servicioAvisosProvider);
  final sesion = ref.watch(sesionProvider).value;
  final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
  final permiso = ref.watch(permisoAvisosProvider).value;
  final servidor = ref.watch(estadoPushProvider.select((e) => e.confirmado));

  if (sesion == null || !prefs.notificaciones || permiso != PermisoAvisos.concedido || servidor) {
    unawaited(servicio.cancelarTodo().then((_) => ref.read(avisosProgramadosProvider.notifier).set(0)));
    return;
  }

  final ahora = DateTime.now();
  final siguiente = DateTime(ahora.year, ahora.month + 1);
  final boot = ref.watch(bootstrapProvider).value;
  final mes1 = ref.watch(monthProvider((ahora.year, ahora.month))).value;
  final mes2 = ref.watch(monthProvider((siguiente.year, siguiente.month))).value;
  if (boot == null || mes1 == null) return;

  final plan = planificarAvisos(
    eventos: [...mes1.eventos, ...?mes2?.eventos],
    cumples: boot.cumples,
    cuentas: boot.cuentas,
    ahora: ahora,
    aviso30: prefs.aviso30,
    resumen: prefs.resumenDiario,
  );

  final timer = Timer(const Duration(milliseconds: 600), () async {
    await servicio.reprogramar(plan);
    ref.read(avisosProgramadosProvider.notifier).set(servicio.programados);
  });
  ref.onDispose(timer.cancel);
});

/// Evento de la notificación tocada (para abrir el día correspondiente).
typedef AlTocarAviso = void Function(String fecha);

/// Extrae la fecha de un payload `dia:YYYY-MM-DD`.
String? fechaDePayload(String? payload) {
  if (payload == null || !payload.startsWith('dia:')) return null;
  final f = payload.substring(4);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(f) ? f : null;
}

/// Útil para mostrar en Ajustes los próximos avisos del plan.
List<AvisoProgramado> planActual(Ref ref) {
  final boot = ref.read(bootstrapProvider).value ?? Bootstrap.vacio;
  final ahora = DateTime.now();
  final mes = ref.read(monthProvider((ahora.year, ahora.month))).value ?? MonthData.vacio;
  final prefs = ref.read(preferenciasProvider).value ?? const Preferencias();
  return planificarAvisos(eventos: mes.eventos, cumples: boot.cumples, cuentas: boot.cuentas, ahora: ahora, aviso30: prefs.aviso30, resumen: prefs.resumenDiario);
}
