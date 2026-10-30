import 'package:agendaservi/core/db/database.dart';
import 'package:agendaservi/core/net/api_client.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/captura/voz.dart';
import 'package:agendaservi/features/finance/pagos/lector_pagos.dart';
import 'package:agendaservi/features/notifications/notification_service.dart';
import 'package:agendaservi/features/notifications/push_service.dart';
import 'package:agendaservi/features/notifications/refresco_fondo.dart';
import 'package:agendaservi/features/seguridad/bloqueo.dart';
import 'package:agendaservi/features/widgets_inicio/publicador.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'fake_backend.dart';

/// Sesión del usuario de ejemplo del backend falso.
const sesionDiego = Sesion(
  token: 'tok-1',
  usuario: Usuario(id: 1, nombre: 'Diego Beltrán', email: 'diego@test.co', whatsapp: '573001234567'),
);

/// Overrides que conectan la app real con el backend falso y una base local
/// en memoria. Sin red, sin notificaciones del sistema.
List<Override> overridesDePrueba({
  required FakeBackend backend,
  required AppDatabase db,
  Sesion? sesion = sesionDiego,
  ServicioAvisos? avisos,
  ServicioPush? push,
  AlmacenAvisos? almacen,
  TareasFondo? fondo,
  LectorPagos? lector,
  ServicioBiometria? biometria,
  ReconocedorVoz? voz,
  PublicadorWidgets? publicador,
}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return [
    databaseProvider.overrideWithValue(db),
    tokenStoreProvider.overrideWithValue(MemoryTokenStore(sesion)),
    servicioAvisosProvider.overrideWithValue(avisos ?? ServicioAvisosInerte()),
    servicioPushProvider.overrideWithValue(push ?? ServicioPushInerte()),
    almacenAvisosProvider.overrideWithValue(almacen ?? AlmacenAvisos.memoria()),
    tareasFondoProvider.overrideWithValue(fondo ?? TareasFondoInertes()),
    lectorPagosProvider.overrideWithValue(lector ?? LectorPagosInerte()),
    servicioBiometriaProvider.overrideWithValue(biometria ?? BiometriaInerte()),
    reconocedorVozProvider.overrideWithValue(voz ?? VozInerte()),
    publicadorWidgetsProvider.overrideWithValue(publicador ?? PublicadorInerte()),
    apiProvider.overrideWith((ref) => ApiClient(
          token: () async => ref.read(sesionProvider).value?.token,
          onUnauthorized: () => ref.read(sesionProvider.notifier).cerrar(motivo: 'Tu sesión expiró. Vuelve a iniciar sesión.'),
          adapter: backend,
        )),
  ];
}

AppDatabase dbEnMemoria() => AppDatabase.forTesting(NativeDatabase.memory());

/// Contenedor listo para pruebas de lógica (sin widgets).
Future<(ProviderContainer, FakeBackend)> contenedor({Sesion? sesion = sesionDiego}) async {
  final backend = FakeBackend();
  final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), sesion: sesion));
  await c.read(sesionProvider.future);
  return (c, backend);
}
