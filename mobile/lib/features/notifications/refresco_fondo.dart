// Respaldo para teléfonos SIN push del servidor (build sin Firebase, o iPhone
// instalado con un Apple ID gratuito, que no permite notificaciones remotas).
//
// El sistema despierta la app de vez en cuando (Android WorkManager cada ~2 h
// con internet; iOS Background App Refresh cuando lo considera oportuno), se
// descargan los eventos y se reprograman los avisos locales. Así un evento
// creado desde la web también avisa aunque no se abra la app. En cuanto el
// push del servidor queda confirmado, esta tarea se cancela.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../core/net/api_client.dart';
import '../../core/net/json.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import 'notification_service.dart';
import 'push_registro.dart';
import 'push_service.dart';
import 'reminder_planner.dart';

/// Debe coincidir con `BGTaskSchedulerPermittedIdentifiers` (Info.plist) y con
/// el registro en `AppDelegate.swift`.
const tareaRefrescoAvisos = 'com.agendaservi.refrescar-avisos';

/// Descarga los datos y reprograma los avisos locales. Devuelve cuántos
/// quedaron programados, o null si no había nada que hacer.
Future<int?> refrescarAvisosEnSegundoPlano({
  required TokenStore sesiones,
  required AlmacenAvisos almacen,
  required ServicioAvisos avisos,
  ApiClient Function(String token)? cliente,
  DateTime? ahora,
}) async {
  final sesion = await sesiones.leer();
  if (sesion == null) return null;
  final cfg = await almacen.leer();
  if (!cfg.notificaciones || cfg.servidorAvisa) return null;
  if (await avisos.permiso() != PermisoAvisos.concedido) return null;

  final api = (cliente ?? (t) => ApiClient(token: () async => t, onUnauthorized: () {}))(sesion.token);
  final t = ahora ?? DateTime.now();
  final siguiente = DateTime(t.year, t.month + 1);
  final respuestas = await Future.wait([
    api.get('/api/dashboard/bootstrap'),
    api.get('/api/dashboard/month', query: {'mes': t.month, 'anio': t.year}),
    api.get('/api/dashboard/month', query: {'mes': siguiente.month, 'anio': siguiente.year}),
  ]);
  final boot = Bootstrap.fromJson(asMap(respuestas[0]));
  final plan = planificarAvisos(
    eventos: [...MonthData.fromJson(asMap(respuestas[1])).eventos, ...MonthData.fromJson(asMap(respuestas[2])).eventos],
    cumples: boot.cumples,
    cuentas: boot.cuentas,
    ahora: t,
    aviso30: cfg.aviso30,
    resumen: cfg.resumen,
  );
  await avisos.reprogramar(plan);
  return avisos.programados;
}

/// Punto de entrada del isolate que lanza el sistema.
@pragma('vm:entry-point')
void despachadorTareasFondo() {
  Workmanager().executeTask((tarea, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      final avisos = ServicioAvisosLocal();
      await avisos.iniciar((_) {});
      await refrescarAvisosEnSegundoPlano(sesiones: SecureTokenStore(), almacen: AlmacenAvisos.seguro(), avisos: avisos);
    } catch (e) {
      // Sin internet o servidor caído: se reintenta en la próxima ventana.
      debugPrint('Refresco en segundo plano falló: $e');
    }
    return true;
  });
}

abstract class TareasFondo {
  Future<void> iniciar();
  Future<void> programar();
  Future<void> cancelar();
}

class TareasFondoInertes implements TareasFondo {
  bool activa = false;
  @override
  Future<void> iniciar() async {}
  @override
  Future<void> programar() async => activa = true;
  @override
  Future<void> cancelar() async => activa = false;
}

class TareasFondoWorkmanager implements TareasFondo {
  bool _iniciado = false;

  @override
  Future<void> iniciar() async {
    if (_iniciado) return;
    await Workmanager().initialize(despachadorTareasFondo);
    _iniciado = true;
  }

  @override
  Future<void> programar() async {
    if (!_iniciado) return;
    await Workmanager().registerPeriodicTask(
      tareaRefrescoAvisos,
      tareaRefrescoAvisos,
      frequency: const Duration(hours: 2),
      initialDelay: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  @override
  Future<void> cancelar() async {
    if (!_iniciado) return;
    await Workmanager().cancelByUniqueName(tareaRefrescoAvisos);
  }
}

final tareasFondoProvider = Provider<TareasFondo>((ref) {
  final movil = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
  return movil ? TareasFondoWorkmanager() : TareasFondoInertes();
});

/// Programa el refresco en segundo plano solo cuando hace falta: hay sesión,
/// avisos activos con permiso, y el servidor todavía no entrega push aquí.
final refrescoFondoProvider = Provider<void>((ref) {
  final tareas = ref.read(tareasFondoProvider);
  final sesion = ref.watch(sesionProvider.select((s) => s.value != null));
  final activas = ref.watch(preferenciasProvider.select((p) => p.value?.notificaciones ?? true));
  final permiso = ref.watch(permisoAvisosProvider.select((p) => p.value));
  final servidor = ref.watch(estadoPushProvider.select((e) => e.confirmado));
  final hace = sesion && activas && permiso == PermisoAvisos.concedido && !servidor;
  unawaited((hace ? tareas.programar() : tareas.cancelar()).catchError((Object e) => debugPrint('Tareas de fondo: $e')));
});
