import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'core/dates.dart';
import 'core/providers.dart';
import 'features/notifications/notification_service.dart';
import 'features/notifications/push_service.dart';
import 'features/notifications/refresco_fondo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO');
  // Barras del sistema transparentes: el contenido va de borde a borde.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  final container = ProviderContainer();

  /// Al tocar una notificación se abre el calendario en ese día.
  void abrirDia(String payload) {
    final fecha = fechaDePayload(payload);
    if (fecha == null) return;
    container.read(mesEventosProvider.notifier).ir(parseYmd(fecha));
    container.read(diaEventosProvider.notifier).seleccionar(fecha);
    // Si la sesión aún carga, el router lo aplicará al terminar.
    container.read(rutaPendienteProvider.notifier).set('/eventos');
    container.read(routerProvider).go('/eventos');
  }

  final avisos = container.read(servicioAvisosProvider);
  try {
    await avisos.iniciar(abrirDia);
  } catch (e) {
    debugPrint('Notificaciones no disponibles: $e');
  }
  // Push del servidor (si este build trae la configuración de Firebase) y
  // refresco en segundo plano como respaldo cuando no hay push.
  final push = container.read(servicioPushProvider);
  await push.iniciar(alTocar: abrirDia);
  try {
    await container.read(tareasFondoProvider).iniciar();
  } catch (e) {
    debugPrint('Tareas en segundo plano no disponibles: $e');
  }

  runApp(UncontrolledProviderScope(container: container, child: const AgendaApp()));

  // Si la app se abrió desde una notificación, se navega tras el primer frame.
  final inicial = await avisos.payloadDeInicio() ?? await push.payloadDeInicio();
  if (inicial != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => abrirDia(inicial));
  }
}
