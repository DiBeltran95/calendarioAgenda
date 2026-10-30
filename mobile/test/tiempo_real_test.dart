// Cambios en vivo (SSE): el canal contra el backend falso y la agenda que se
// actualiza sola cuando un cliente reserva o cancela, con su aviso en la app.

import 'dart:math';

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/core/net/api_client.dart';
import 'package:agendaservi/core/net/tiempo_real.dart';
import 'package:agendaservi/core/session.dart' show apiProvider;
import 'package:agendaservi/features/citas/citas_en_vivo.dart';
import 'package:agendaservi/features/citas/citas_models.dart';
import 'package:agendaservi/features/citas/citas_repository.dart';
import 'package:agendaservi/features/notifications/push_service.dart';
import 'package:agendaservi/features/notifications/reminder_planner.dart' show CanalAviso;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'citas_test.dart' show proximoLunes;
import 'push_test.dart' show PushFalso;
import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Espera (en tiempo real) a que se cumpla una condición.
Future<void> hasta(bool Function() cond, {Duration max = const Duration(seconds: 6), String? motivo}) async {
  final limite = DateTime.now().add(max);
  while (!cond()) {
    if (DateTime.now().isAfter(limite)) fail('No se cumplió a tiempo: ${motivo ?? ''}');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  group('lector SSE', () {
    test('eventos con nombre, datos en varias líneas y latidos', () {
      final l = LectorSse();
      final salida = <({String evento, String datos})>[];
      for (final linea in ['retry: 5000', '', ': latido 123', '', 'id: 7', 'event: cita', 'data: {"a":1,', 'data:"b":2}', '', 'data: suelto', '']) {
        final e = l.linea(linea);
        if (e != null) salida.add(e);
      }
      expect(salida, hasLength(2));
      expect(salida[0].evento, 'cita');
      expect(salida[0].datos, '{"a":1,\n"b":2}');
      expect(salida[1].evento, 'message');
      expect(salida[1].datos, 'suelto');
    });

    test('reintentos con espera creciente, tope de 60 s y variación aleatoria', () {
      final azar = Random(1);
      final esperas = [for (var f = 0; f < 10; f++) TiempoReal.esperaReintento(f, azar)];
      expect(esperas.first.inMilliseconds, inInclusiveRange(1000, 1999));
      expect(esperas[3].inMilliseconds, inInclusiveRange(8000, 8999));
      for (final e in esperas) {
        expect(e.inMilliseconds, lessThan(61000));
      }
    });
  });

  group('canal', () {
    test('conecta, entrega eventos, y si se cae la red reconecta y resincroniza', () async {
      final (c, backend) = await contenedor();
      addTearDown(c.dispose);
      final vivo = c.read(tiempoRealProvider);
      final sincronizaciones = <void>[];
      final eventos = <EventoVivo>[];
      vivo.sincronizar.listen(sincronizaciones.add);
      vivo.eventos.listen(eventos.add);

      c.listen(canalVivoProvider, (_, _) {});
      await hasta(() => vivo.estado.value == EstadoVivo.enVivo, motivo: 'en vivo');
      expect(backend.conexionesVivas(1), 1);
      expect(sincronizaciones, hasLength(1));

      backend.latido();
      backend.emitir(1, 'cita', {'tipo': 'nueva', 'cita': {'id': 5}});
      backend.emitir(2, 'cita', {'tipo': 'otra persona'});
      await hasta(() => eventos.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(eventos.single.tipo, 'cita');
      expect(eventos.single.datos['tipo'], 'nueva');

      await backend.cortarVivos();
      await hasta(() => vivo.estado.value != EstadoVivo.enVivo || backend.conexionesVivas(1) == 1, motivo: 'detecta el corte');
      await hasta(() => backend.conexionesVivas(1) == 1 && vivo.estado.value == EstadoVivo.enVivo && sincronizaciones.length == 2, motivo: 'reconecta');

      vivo.detener();
      await hasta(() => backend.conexionesVivas() == 0, motivo: 'cierra al detener');
      expect(vivo.estado.value, EstadoVivo.apagado);
    });

    test('sin la ruta en el servidor pasa a modo respaldo (consulta periódica)', () async {
      final (c, backend) = await contenedor();
      addTearDown(c.dispose);
      backend.sinTiempoReal = true;
      final vivo = c.read(tiempoRealProvider);
      var sincronizaciones = 0;
      vivo.sincronizar.listen((_) => sincronizaciones++);
      c.listen(canalVivoProvider, (_, _) {});
      await hasta(() => vivo.estado.value == EstadoVivo.respaldo);
      expect(sincronizaciones, 1);
      // No insiste con el canal.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(backend.log.where((l) => l == 'GET /api/tiempo-real'), hasLength(1));
    });

    test('se cierra al cerrar la sesión', () async {
      final (c, backend) = await contenedor();
      addTearDown(c.dispose);
      c.listen(canalVivoProvider, (_, _) {});
      await hasta(() => backend.conexionesVivas(1) == 1);
      c.dispose();
      await hasta(() => backend.conexionesVivas() == 0);
    });
  });

  group('agenda en vivo', () {
    late ProviderContainer c;
    late FakeBackend backend;
    late PushFalso push;
    late AgendaRepository repo;
    final lunes = proximoLunes();

    setUp(() async {
      push = PushFalso();
      backend = FakeBackend();
      c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), push: push));
      addTearDown(c.dispose);
      repo = c.read(agendaRepoProvider);
      c.listen(configAgendaProvider, (_, _) {});
      c.listen(citasAgendaProvider, (_, _) {});
      c.listen(misReservasProvider, (_, _) {});
      await c.read(configAgendaProvider.future);
      await repo.guardarNegocio({'nombre': 'Barbería Diego', 'slug': 'barberia-diego', 'tipo': 'profesional', 'intervalo_min': 30});
      await repo.guardarServicio({'nombre': 'Corte', 'duracion_min': 30, 'precio': 30000});
      await c.read(citasAgendaProvider.future);
      c.listen(canalVivoProvider, (_, _) {});
      c.listen(citasEnVivoProvider, (_, _) {});
      await hasta(() => c.read(tiempoRealProvider).conectado);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    List<CitaAgenda> citas() => c.read(citasAgendaProvider).value ?? const [];

    /// Un cliente reserva desde la página web (sin sesión); devuelve el token.
    Future<String> reservarWeb(String hora, String nombre, String whatsapp) async {
      final pagina = await repo.pagina('barberia-diego');
      final r = await c.read(apiProvider).post('/api/public/agenda/barberia-diego/reservas',
          body: {'servicio_id': pagina.servicios.single.id, 'profesional_id': 0, 'fecha': lunes, 'hora': hora, 'nombre': nombre, 'whatsapp': whatsapp}, publico: true);
      return (r as Map)['token'] as String;
    }
    int pedidosDeCitas() => backend.log.where((l) => l == 'GET /api/agenda/citas').length;

    test('una reserva aparece al instante, se anuncia al confirmarse y la cancelación también', () async {
      final pedidos = pedidosDeCitas();
      // Un cliente reserva desde la web (sin sesión).
      final token = await reservarWeb('10:00', 'Andrés', '573120000000');
      await hasta(() => citas().any((x) => x.token == token), motivo: 'reserva pendiente en la lista');
      expect(citas().single.estado, EstadoCita.pendiente);
      expect(citas().single.vence, isNotNull);
      // Pendiente: se ve en la lista, pero aún no interrumpe con un aviso.
      expect(c.read(avisoVivoProvider), isNull);

      await repo.confirmar(token, '123456');
      await hasta(() => citas().single.estado == EstadoCita.confirmada, motivo: 'confirmada en vivo');
      final aviso = c.read(avisoVivoProvider);
      expect(aviso?.titulo, 'Nueva cita: Andrés');
      expect(aviso?.tipo, TipoAvisoVivo.nueva);
      expect(aviso?.fecha, lunes);
      expect(c.read(citasRecientesProvider), contains(citas().single.id));
      // Llegó por el canal en vivo: no hizo falta volver a pedir la agenda.
      expect(pedidosDeCitas(), pedidos);

      // El push de la misma cita llega segundos después: no repite el aviso.
      c.read(avisoVivoProvider.notifier).cerrar();
      push.recibido.add(MensajePush(tipo: 'cita', clave: 'cita:${citas().single.id}:nueva', titulo: '🗓️ Nueva cita: Andrés', cuerpo: 'Corte', canal: CanalAviso.evento, ruta: 'citas'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(c.read(avisoVivoProvider), isNull);

      // El cliente cancela desde su enlace.
      await c.read(apiProvider).post('/api/public/agenda/citas/$token/cancelar', publico: true);
      await hasta(() => citas().single.estado == EstadoCita.cancelada, motivo: 'cancelada en vivo');
      expect(c.read(avisoVivoProvider)?.titulo, 'Cita cancelada: Andrés');
      expect(c.read(avisoVivoProvider)?.tipo, TipoAvisoVivo.cancelada);
    });

    test('lo que hace el propio usuario no se le anuncia', () async {
      final cfg = c.read(configAgendaProvider).value!;
      final cita = await repo.crearCita({'servicio_id': cfg.servicios.single.id, 'profesional_id': cfg.profesionales.single.id, 'fecha': lunes, 'hora': '11:00', 'cliente_nombre': 'Laura'});
      await repo.cambiarEstado(cita, EstadoCita.cancelada);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(citas().single.estado, EstadoCita.cancelada);
      expect(c.read(avisoVivoProvider), isNull);
    });

    test('sin canal en vivo, al sincronizar se detectan y anuncian los cambios', () async {
      c.read(tiempoRealProvider).detener();
      final token = await reservarWeb('15:00', 'Marta', '573120000001');
      await repo.confirmar(token, '123456');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(citas(), isEmpty, reason: 'sin canal no se entera solo');

      await c.read(citasEnVivoProvider).refrescar(forzar: true);
      expect(citas().single.clienteNombre, 'Marta');
      expect(c.read(avisoVivoProvider)?.titulo, 'Nueva cita: Marta');
    });

    test('un push de una cita que el canal no trajo refresca y avisa', () async {
      c.read(tiempoRealProvider).detener();
      final token = await reservarWeb('16:00', 'Pedro', '573120000002');
      await repo.confirmar(token, '123456');
      final id = backend.agenda.citas.single['id'];
      push.recibido.add(MensajePush(tipo: 'cita', clave: 'cita:$id:nueva', titulo: '🗓️ Nueva cita: Pedro', cuerpo: 'Corte · lunes', canal: CanalAviso.evento, ruta: 'citas'));
      await hasta(() => citas().isNotEmpty, motivo: 'refresca con el push');
      expect(c.read(avisoVivoProvider)?.titulo, 'Nueva cita: Pedro');
      expect(c.read(avisoVivoProvider)?.citaId, id);
    });
  });

  group('cambios entre versiones', () {
    CitaAgenda cita(int id, EstadoCita e, {String fecha = '2099-01-05', String origen = 'web'}) => CitaAgenda(
          id: id,
          token: 't$id',
          fecha: fecha,
          horaInicio: '10:00',
          horaFin: '10:30',
          servicioNombre: 'Corte',
          duracionMin: 30,
          precio: 0,
          clienteNombre: 'C$id',
          origen: origen,
          estado: e,
          profesionalId: 1,
          profesionalNombre: 'P',
          profesionalColor: 0,
          negocioNombre: 'N',
          slug: 'n',
          negocioColor: 0,
          rol: 'dueno',
        );

    test('solo lo nuevo confirmado y lo recién cancelado, desde hoy', () {
      final antes = [cita(1, EstadoCita.pendiente), cita(2, EstadoCita.confirmada), cita(3, EstadoCita.cancelada)];
      final despues = [
        cita(1, EstadoCita.confirmada),
        cita(2, EstadoCita.cancelada),
        cita(3, EstadoCita.cancelada),
        cita(4, EstadoCita.confirmada),
        cita(5, EstadoCita.confirmada, origen: 'negocio'),
        cita(6, EstadoCita.confirmada, fecha: '2000-01-01'),
        cita(7, EstadoCita.pendiente),
      ];
      final avisos = cambiosEntre(antes, despues, hoy: '2099-01-01');
      expect(avisos.map((a) => a.clave), ['cita:1:nueva', 'cita:2:cancelada', 'cita:4:nueva']);
    });

    test('una reserva pendiente vencida pasa a "Sin confirmar"', () {
      final creado = DateTime.utc(2099, 1, 1, 10);
      final c = CitaAgenda.fromJson({...cita(1, EstadoCita.pendiente).toJson(), 'creado': creado.toIso8601String()});
      expect(c.vence, creado.add(const Duration(minutes: 15)));
      expect(c.vigente(creado.add(const Duration(minutes: 14))).estado, EstadoCita.pendiente);
      expect(c.vigente(creado.add(const Duration(minutes: 15))).estado, EstadoCita.expirada);
    });
  });

  testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'interfaz: la cita llega sola, con aviso, y el detalle abierto se actualiza', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final backend = FakeBackend();
    final lunes = proximoLunes();
    // Página de citas de Diego (usuario 1) con un servicio.
    await t.runAsync(() async {
      final c = ProviderContainer(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()));
      final repo = c.read(agendaRepoProvider);
      c.listen(configAgendaProvider, (_, _) {});
      await c.read(configAgendaProvider.future);
      await repo.guardarNegocio({'nombre': 'Barbería Diego', 'slug': 'barberia-diego', 'tipo': 'profesional', 'intervalo_min': 30});
      await repo.guardarServicio({'nombre': 'Corte', 'duracion_min': 30, 'precio': 30000});
      c.dispose();
    });
    final web = ApiClient(token: () async => null, onUnauthorized: () {}, adapter: backend);

    Future<void> esperar([int vueltas = 12]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
    await esperar(20);
    await t.tap(find.text('Citas').last);
    await esperar();
    expect(backend.conexionesVivas(1), 1, reason: 'canal en vivo abierto');

    // Un cliente reserva y confirma desde la web: sin tocar nada, aparece.
    final token = await t.runAsync(() async {
      final servicio = backend.agenda.servicios.single['id'];
      final r = await web.post('/api/public/agenda/barberia-diego/reservas',
          body: {'servicio_id': servicio, 'profesional_id': 0, 'fecha': lunes, 'hora': '10:00', 'nombre': 'Andrés Gómez', 'whatsapp': '573120000000'}, publico: true);
      final token = (r as Map)['token'] as String;
      await web.post('/api/public/agenda/citas/$token/confirmar', body: {'codigo': '123456'}, publico: true);
      return token;
    });
    await esperar();
    expect(find.text('Nueva cita: Andrés Gómez'), findsOneWidget);

    // Tocar el aviso lleva al día de la cita y abre su detalle.
    await t.tap(find.text('Nueva cita: Andrés Gómez'));
    await esperar(16);
    expect(find.text('Nueva cita: Andrés Gómez'), findsNothing);
    expect(find.text('Reservada desde el enlace web'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);

    // El cliente cancela con el detalle abierto: se actualiza y avisa.
    await t.runAsync(() => web.post('/api/public/agenda/citas/${token!}/cancelar', publico: true));
    await esperar();
    expect(find.text('Cita cancelada: Andrés Gómez'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsNothing);

    // Se oculta solo.
    await t.pump(const Duration(seconds: 7));
    await esperar(4);
    expect(find.text('Cita cancelada: Andrés Gómez'), findsNothing);

    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 1));
    expect(backend.conexionesVivas(), 0, reason: 'se cierra al salir');
  });
}
