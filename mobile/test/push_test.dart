// Push del servidor: registro del teléfono, cambio de avisos locales a avisos
// del servidor, baja al cerrar sesión y respaldo en segundo plano.

import 'dart:async';

import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/net/api_client.dart';
import 'package:agendaservi/core/providers.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/features/events/events_repository.dart';
import 'package:agendaservi/features/notifications/notification_service.dart';
import 'package:agendaservi/features/notifications/push_registro.dart';
import 'package:agendaservi/features/notifications/push_service.dart';
import 'package:agendaservi/features/notifications/refresco_fondo.dart';
import 'package:agendaservi/features/notifications/reminder_planner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Teléfono con permiso de notificaciones concedido.
class AvisosConPermiso extends ServicioAvisosInerte {
  @override
  Future<PermisoAvisos> permiso() async => PermisoAvisos.concedido;
}

class PushFalso implements ServicioPush {
  PushFalso([this.valor = 'fcm-token-de-prueba-0123456789']);
  String? valor;
  final renovado = StreamController<String>.broadcast();
  final recibido = StreamController<MensajePush>.broadcast();
  @override
  String get plataforma => 'android';
  @override
  Future<bool> iniciar({required void Function(String payload) alTocar}) async => true;
  @override
  Future<String?> token() async => valor;
  @override
  Stream<String> get tokenRenovado => renovado.stream;
  @override
  Stream<MensajePush> get recibidos => recibido.stream;
  @override
  Future<String?> payloadDeInicio() async => null;
}

void main() {
  late FakeBackend backend;
  late AvisosConPermiso avisos;
  late PushFalso push;
  late AlmacenAvisos almacen;
  late TareasFondoInertes fondo;
  late ProviderContainer c;

  Future<void> esperar([int ms = 800]) => Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() async {
    backend = FakeBackend();
    avisos = AvisosConPermiso();
    push = PushFalso();
    almacen = AlmacenAvisos.memoria();
    fondo = TareasFondoInertes();
    c = ProviderContainer(
      overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), avisos: avisos, push: push, almacen: almacen, fondo: fondo),
    );
    await c.read(sesionProvider.future);
    // Un evento con hora mañana: genera avisos locales (30 min y exacto).
    await c.read(eventsRepoProvider).crear(EventoInput(titulo: 'Reunión', fecha: sumarDiasYmd(hoyYmd(), 1), hora: '10:00', categoria: 'reunion'));
    for (final p in [programadorAvisosProvider, sincronizadorPushProvider, refrescoFondoProvider]) {
      c.listen(p, (_, _) {});
    }
    await esperar();
  });

  tearDown(() => c.dispose());

  test('registra el teléfono con sus preferencias y conserva los avisos locales hasta la confirmación', () async {
    expect(backend.dispositivos, hasLength(1));
    final d = backend.dispositivos.single;
    expect(d['user_id'], 1);
    expect(d['token'], 'fcm-token-de-prueba-0123456789');
    expect(d['plataforma'], 'android');
    expect(d['avisos'], 1);
    expect(d['aviso_30m'], 1);

    final e = c.read(estadoPushProvider);
    expect(e.registrado, isTrue);
    expect(e.confirmado, isFalse);
    expect(avisos.ultimos, isNotEmpty, reason: 'sin confirmación, el teléfono sigue avisando por su cuenta');
    expect(fondo.activa, isTrue, reason: 'y refresca en segundo plano por si el evento viene de la web');
  });

  test('cuando el servidor confirma el push, se apagan los avisos locales y el refresco de fondo', () async {
    backend.confirmarBienvenidas();
    await c.read(registroPushProvider).sincronizar(forzar: true);
    await esperar();

    expect(c.read(estadoPushProvider).confirmado, isTrue);
    expect(avisos.ultimos, isEmpty);
    expect(fondo.activa, isFalse);
    expect((await almacen.leer()).servidorAvisa, isTrue);
  });

  test('un push recibido con la app abierta confirma el canal sin esperar al servidor', () async {
    push.recibido.add(MensajePush.desde({'titulo': '🔔 Notificaciones activadas', 'clave': 'bienvenida', 'tipo': 'bienvenida'})!);
    await esperar();
    expect(c.read(estadoPushProvider).confirmado, isTrue);
    expect(avisos.ultimos, isEmpty);
  });

  test('las preferencias viajan al servidor (30 min, resumen y apagar avisos)', () async {
    await c.read(ajustesRepoProvider).setAviso30(false);
    await esperar();
    expect(backend.dispositivos.single['aviso_30m'], 0);

    await c.read(ajustesRepoProvider).setNotificaciones(false);
    await esperar();
    expect(backend.dispositivos.single['avisos'], 0);
    expect((await almacen.leer()).notificaciones, isFalse);
  });

  test('token renovado: se vuelve a registrar y se espera una nueva confirmación', () async {
    backend.confirmarBienvenidas();
    await c.read(registroPushProvider).sincronizar(forzar: true);
    push.valor = 'fcm-token-renovado-9876543210';
    push.renovado.add(push.valor!);
    await esperar();
    expect(backend.dispositivos.map((d) => d['token']), contains('fcm-token-renovado-9876543210'));
    expect(c.read(estadoPushProvider).confirmado, isFalse);
    expect(avisos.ultimos, isNotEmpty);
  });

  test('cerrar sesión da de baja el teléfono en el servidor', () async {
    await c.read(registroPushProvider).darDeBaja();
    await c.read(sesionProvider.notifier).cerrar();
    await esperar();
    expect(backend.dispositivos, isEmpty);
    expect((await almacen.leer()).tokenPush, isNull);
    expect(c.read(estadoPushProvider).registrado, isFalse);
    expect(fondo.activa, isFalse);
  });

  test('sin push (build sin Firebase o iPhone sin notificaciones remotas) quedan los avisos locales', () async {
    final b = FakeBackend();
    final a = AvisosConPermiso();
    final f = TareasFondoInertes();
    final c2 = ProviderContainer(overrides: overridesDePrueba(backend: b, db: dbEnMemoria(), avisos: a, fondo: f));
    addTearDown(c2.dispose);
    await c2.read(sesionProvider.future);
    await c2.read(eventsRepoProvider).crear(EventoInput(titulo: 'Médico', fecha: sumarDiasYmd(hoyYmd(), 2), hora: '08:00', categoria: 'doctor'));
    for (final p in [programadorAvisosProvider, sincronizadorPushProvider, refrescoFondoProvider]) {
      c2.listen(p, (_, _) {});
    }
    await esperar();
    expect(b.dispositivos, isEmpty);
    expect(c2.read(estadoPushProvider).disponible, isFalse);
    expect(a.ultimos, isNotEmpty);
    expect(f.activa, isTrue);
  });

  group('refresco en segundo plano', () {
    ApiClient cliente(String t) => ApiClient(token: () async => t, onUnauthorized: () {}, adapter: backend);

    test('descarga los eventos creados en otro lado y reprograma los avisos', () async {
      // Evento creado "desde la web" (directo en el servidor).
      backend.eventos.add({
        'id': 999,
        'user_id': 1,
        'titulo': 'Cita desde la web',
        'fecha': sumarDiasYmd(hoyYmd(), 3),
        'hora': '15:00:00',
        'categoria': 'doctor',
        'costo': '0.00',
        'tipo_transaccion': 'ninguno',
        'estado_pago': 'pendiente',
        'frecuencia': 'unica',
      });
      final a = AvisosConPermiso();
      final n = await refrescarAvisosEnSegundoPlano(
        sesiones: MemoryTokenStore(sesionDiego),
        almacen: AlmacenAvisos.memoria(),
        avisos: a,
        cliente: cliente,
      );
      expect(n, greaterThan(0));
      expect(a.ultimos.map((x) => x.id), contains(idAviso('ev:999:exacto')));
    });

    test('sin push: una cita nueva o cancelada con la app cerrada se avisa con una notificación local', () async {
      // Página de citas con una cita confirmada que el usuario ya vio.
      backend.agenda.negocios[1] = {'id': 50, 'user_id': 1, 'nombre': 'Barbería', 'slug': 'barberia', 'color': '#2563EB', 'activo': 1, 'intervalo_min': 30};
      backend.agenda.profesionales.add({'id': 60, 'negocio': 50, 'nombre': 'Diego', 'color': '#2563EB', 'usuario_id': 1, 'activo': 1});
      final dia = sumarDiasYmd(hoyYmd(), 2);
      Map<String, dynamic> cita(int id, String nombre, String estado) => {
            'id': id, 'token': 't$id', 'negocio': 50, 'profesional_id': 60, 'servicio_id': 1, 'servicio_nombre': 'Corte', 'duracion_min': 30,
            'precio': '0.00', 'fecha': dia, 'hora_inicio': '10:00', 'hora_fin': '10:30', 'cliente_nombre': nombre, 'estado': estado, 'origen': 'web',
          };
      backend.agenda.citas.add(cita(1, 'Ana', 'confirmada'));
      final almacen = AlmacenAvisos.memoria();
      final a = AvisosConPermiso();
      final api = cliente(sesionDiego.token);
      // Primera revisión: solo guarda lo que hay (no anuncia toda la agenda).
      expect(await avisarCambiosDeCitas(api: api, almacen: almacen, avisos: a), 0);

      // Con la app cerrada: Ana cancela y Luis reserva.
      backend.agenda.citas.first['estado'] = 'cancelada';
      backend.agenda.citas.add(cita(2, 'Luis', 'confirmada'));
      expect(await avisarCambiosDeCitas(api: api, almacen: almacen, avisos: a), 2);
      expect(a.mostrados.map((x) => x.titulo), ['Cita cancelada: Ana', 'Nueva cita: Luis']);
      expect(a.mostrados.first.id, idAviso('cita:1:cancelada'));

      // La siguiente revisión no repite nada.
      expect(await avisarCambiosDeCitas(api: api, almacen: almacen, avisos: a), 0);
    });

    test('no hace nada sin sesión, con avisos apagados o si el servidor ya avisa', () async {
      final a = AvisosConPermiso();
      expect(await refrescarAvisosEnSegundoPlano(sesiones: MemoryTokenStore(), almacen: AlmacenAvisos.memoria(), avisos: a, cliente: cliente), isNull);
      final apagados = AlmacenAvisos.memoria()..guardar(const ConfigAvisos(notificaciones: false));
      expect(await refrescarAvisosEnSegundoPlano(sesiones: MemoryTokenStore(sesionDiego), almacen: apagados, avisos: a, cliente: cliente), isNull);
      final servidor = AlmacenAvisos.memoria()..guardar(const ConfigAvisos(tokenPush: 'x', pushConfirmado: true));
      expect(await refrescarAvisosEnSegundoPlano(sesiones: MemoryTokenStore(sesionDiego), almacen: servidor, avisos: a, cliente: cliente), isNull);
      expect(a.ultimos, isEmpty);
    });
  });

  test('un push del cron se muestra con el mismo id que el aviso local equivalente', () async {
    final m = MensajePush.desde({
      'tipo': 'aviso',
      'clave': 'ev:1:exacto',
      'titulo': '📅 Reunión',
      'cuerpo': 'Es momento de tu reunión',
      'canal': 'eventos',
      'ruta': 'dia:2026-09-23',
    })!;
    expect(m.id, 1138420351); // mismo valor que calcula cron/push.js
    final a = ServicioAvisosInerte();
    await mostrarPush(a, m);
    expect(a.mostrados.single.id, idAviso('ev:1:exacto'));
    expect(a.mostrados.single.payload, 'dia:2026-09-23');
    expect(MensajePush.desde({'clave': 'x'}), isNull);
    expect(MensajePush.desde({'titulo': 'x', 'clave': 'r', 'canal': 'resumen'})!.canal, CanalAviso.resumen);
  });
}
