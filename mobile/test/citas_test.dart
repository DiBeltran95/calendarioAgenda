// Agendamiento de citas: repositorio contra el backend falso y la interfaz
// completa (crear la página, agenda del negocio y reservar desde la app).

import 'package:agendaservi/app/app.dart';
import 'package:agendaservi/app/router.dart';
import 'package:agendaservi/core/dates.dart';
import 'package:agendaservi/core/session.dart';
import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/citas/citas_models.dart';
import 'package:agendaservi/features/citas/citas_repository.dart';
import 'package:agendaservi/features/citas/crear_pagina_screen.dart' show slugDe;
import 'package:agendaservi/features/citas/widgets/horario_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Próximo lunes (con horario base de oficina).
String proximoLunes() {
  var f = sumarDiasYmd(hoyYmd(), 1);
  while (parseYmd(f).weekday != DateTime.monday) {
    f = sumarDiasYmd(f, 1);
  }
  return f;
}

const sesionAna = Sesion(token: 'tok-2', usuario: Usuario(id: 2, nombre: 'Ana Cliente', email: 'ana@test.co', whatsapp: '573115556677'));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_CO');
  });

  group('utilidades', () {
    test('enlaces a partir del nombre', () {
      expect(slugDe('Peluquería Doña Ana'), 'peluqueria-dona-ana');
      expect(slugDe('  Dr. José Pérez — Psicólogo '), 'dr-jose-perez-psicologo');
    });

    test('resumen legible del horario semanal', () {
      expect(resumenHorario(horarioPlantilla('oficina')), 'L–V 8–12 y 14–18');
      expect(resumenHorario(horarioPlantilla('comercio')), 'L–S 9–19');
      expect(resumenHorario(const []), 'Sin horario');
      expect(
        resumenHorario(const [HorarioDia(dia: 1, inicio: '09:00', fin: '13:30'), HorarioDia(dia: 3, inicio: '09:00', fin: '13:30')]),
        'L 9–13:30 · X 9–13:30',
      );
    });
  });

  group('repositorio', () {
    late ProviderContainer c;
    late FakeBackend backend;

    setUp(() async {
      (c, backend) = await contenedor();
      c.listen(configAgendaProvider, (_, _) {});
      c.listen(citasAgendaProvider, (_, _) {});
      await c.read(configAgendaProvider.future);
    });
    tearDown(() => c.dispose());

    test('crear la página, un servicio y ver el enlace', () async {
      final repo = c.read(agendaRepoProvider);
      expect(c.read(configAgendaProvider).value!.tieneNegocio, isFalse);
      final libre = await repo.verificarSlug('psicologa-diego');
      expect(libre.disponible, isTrue);

      await repo.guardarNegocio({'nombre': 'Diego Psicólogo', 'slug': 'psicologa-diego', 'tipo': 'profesional', 'rubro': 'psicologia', 'color': '#7C3AED'});
      await repo.guardarServicio({'nombre': 'Consulta', 'duracion_min': 60, 'precio': 120000});
      final cfg = c.read(configAgendaProvider).value!;
      expect(cfg.negocio!.enlace, 'https://agendaservi.com/agenda/psicologa-diego');
      expect(cfg.negocio!.color, 0xFF7C3AED);
      expect(cfg.profesionales.single.esDueno, isTrue);
      expect(cfg.profesionales.single.horarios, hasLength(10));
      expect(cfg.servicios.single.precio, 120000);
      expect(cfg.servicios.single.profesionales, [cfg.profesionales.single.id]);
    });

    test('cita a mano, choque de horario y cambios de estado optimistas', () async {
      final repo = c.read(agendaRepoProvider);
      await repo.guardarNegocio({'nombre': 'Diego', 'slug': 'diego-citas', 'tipo': 'profesional', 'intervalo_min': 30});
      await repo.guardarServicio({'nombre': 'Consulta', 'duracion_min': 60, 'precio': 80000});
      final cfg = c.read(configAgendaProvider).value!;
      final lunes = proximoLunes();
      final base = {'servicio_id': cfg.servicios.single.id, 'profesional_id': cfg.profesionales.single.id, 'fecha': lunes, 'cliente_nombre': 'Carlos'};

      final cita = await repo.crearCita({...base, 'hora': '09:00'});
      expect(cita.estado, EstadoCita.confirmada);
      expect(c.read(citasAgendaProvider).value, hasLength(1));

      await expectLater(repo.crearCita({...base, 'hora': '09:30'}), throwsA(isA<AgendaError>().having((e) => e.ocupado, 'ocupado', isTrue)));
      final forzada = await repo.crearCita({...base, 'hora': '09:30', 'forzar': true});

      final cancelada = await repo.cambiarEstado(forzada, EstadoCita.cancelada, motivo: 'Agenda llena');
      expect(cancelada.estado, EstadoCita.cancelada);
      expect(backend.agenda.citas.last['motivo_cancelacion'], 'Agenda llena');

      // Si el servidor falla, la cita vuelve a su estado anterior.
      backend.caido = true;
      await expectLater(repo.cambiarEstado(cita, EstadoCita.completada), throwsA(isA<AgendaError>()));
      expect(c.read(citasAgendaProvider).value!.firstWhere((x) => x.id == cita.id).estado, EstadoCita.confirmada);
    });

    test('equipo: profesional vinculado por correo y días bloqueados', () async {
      final repo = c.read(agendaRepoProvider);
      await repo.guardarNegocio({'nombre': 'Barbería', 'slug': 'barberia-test', 'tipo': 'empresa'});
      expect(c.read(configAgendaProvider).value!.profesionales, isEmpty);
      await expectLater(repo.guardarProfesional({'nombre': 'X', 'vincular': 'nadie@test.co'}), throwsA(isA<AgendaError>()));
      await repo.guardarProfesional({'nombre': 'Luis', 'horarios': [for (final h in horarioPlantilla('comercio')) h.toJson()]});
      await repo.crearBloqueo({'fecha': proximoLunes(), 'motivo': 'Capacitación'});
      final cfg = c.read(configAgendaProvider).value!;
      expect(cfg.profesionales.single.nombre, 'Luis');
      expect(cfg.bloqueos.single.motivo, 'Capacitación');
      expect(cfg.bloqueos.single.diaCompleto, isTrue);
      await repo.eliminarBloqueo(cfg.bloqueos.single.id);
      expect(c.read(configAgendaProvider).value!.bloqueos, isEmpty);
    });

    test('reservar como cliente con código por WhatsApp', () async {
      final repo = c.read(agendaRepoProvider);
      await repo.guardarNegocio({'nombre': 'Diego', 'slug': 'diego-reservas', 'tipo': 'profesional', 'intervalo_min': 60});
      await repo.guardarServicio({'nombre': 'Consulta', 'duracion_min': 60});
      final pagina = await repo.pagina('diego-reservas');
      final lunes = proximoLunes();
      final dias = await repo.disponibilidad('diego-reservas', servicio: pagina.servicios.single.id, desde: lunes, dias: 1);
      expect(dias.single.turnos.map((t) => t.hora), ['08:00', '09:00', '10:00', '11:00', '14:00', '15:00', '16:00', '17:00']);

      final r = await repo.reservar('diego-reservas', {'servicio_id': pagina.servicios.single.id, 'profesional_id': 0, 'fecha': lunes, 'hora': '10:00', 'nombre': 'Ana', 'whatsapp': '573115556677'});
      expect(r.estado, EstadoCita.pendiente);
      expect(backend.agenda.whatsapps.last.$2, contains('123456'));
      await expectLater(repo.confirmar(r.token, '000000'), throwsA(isA<AgendaError>().having((e) => e.mensaje, 'mensaje', contains('incorrecto'))));
      final ok = await repo.confirmar(r.token, '123456');
      expect(ok.estado, EstadoCita.confirmada);

      final despues = await repo.disponibilidad('diego-reservas', servicio: pagina.servicios.single.id, desde: lunes, dias: 1);
      expect(despues.single.turnos.map((t) => t.hora), isNot(contains('10:00')));
    });

    test('resumen del módulo: próximas, semana e ingresos', () async {
      final repo = c.read(agendaRepoProvider);
      await repo.guardarNegocio({'nombre': 'Diego', 'slug': 'diego-resumen', 'tipo': 'profesional'});
      await repo.guardarServicio({'nombre': 'Consulta', 'duracion_min': 60, 'precio': 50000});
      final cfg = c.read(configAgendaProvider).value!;
      final manana = sumarDiasYmd(hoyYmd(), 1);
      final dia = parseYmd(manana).weekday;
      if (dia == DateTime.saturday || dia == DateTime.sunday) return; // sin horario el fin de semana
      await repo.crearCita({'servicio_id': cfg.servicios.single.id, 'profesional_id': cfg.profesionales.single.id, 'fecha': manana, 'hora': '09:00', 'cliente_nombre': 'Laura'});
      final r = c.read(resumenCitasProvider);
      expect(r.semana, 1);
      expect(r.ingresosSemana, 50000);
      expect(r.proxima?.clienteNombre, 'Laura');
    });
  });

  group('interfaz', () {
    Future<void> esperar(WidgetTester t, [int vueltas = 12]) async {
      for (var i = 0; i < vueltas; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> desmontar(WidgetTester t) async {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 1));
    }

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'crear la página de citas con el asistente', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final backend = FakeBackend();
      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria()), child: const AgendaApp()));
      await esperar(t, 20);

      await t.tap(find.text('Citas').last);
      await esperar(t);
      expect(find.text('Que tus clientes agenden solos'), findsOneWidget);
      await t.tap(find.text('Crear mi página de citas'));
      await esperar(t);

      // Paso 1: tipo. Paso 2: página (nombre y enlace ya propuestos).
      expect(find.text('¿Cómo trabajas?'), findsOneWidget);
      await t.tap(find.text('Continuar'));
      await esperar(t, 16);
      expect(find.text('Tu página'), findsOneWidget);
      expect(find.text('diego-beltran'), findsOneWidget);
      await t.tap(find.text('Continuar'));
      await esperar(t);
      // Paso 3: servicio sugerido por el rubro (psicología).
      expect(find.text('Consulta psicológica'), findsOneWidget);
      await t.tap(find.text('Continuar'));
      await esperar(t);
      // Paso 4: horario con plantilla.
      expect(find.text('Lunes'), findsOneWidget);
      await t.tap(find.text('Crear mi página'));
      await esperar(t, 20);
      expect(find.text('¡Tu página está lista!'), findsOneWidget);
      expect(backend.agenda.negocios[1]!['slug'], 'diego-beltran');
      expect(backend.agenda.servicios.single['nombre'], 'Consulta psicológica');

      await t.tap(find.text('Ir a mi agenda'));
      await esperar(t, 16);
      expect(find.text('Tu página para agendar'), findsOneWidget);
      expect(find.text('Día libre'), findsOneWidget);
      await desmontar(t);
    });

    testWidgets(timeout: const Timeout(Duration(minutes: 2)), 'reservar desde el enlace dentro de la app', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final backend = FakeBackend();
      backend.usuarios.add({'id': 2, 'nombre': 'Ana Cliente', 'email': 'ana@test.co', 'password': 'x', 'whatsapp': '573115556677', 'verificado': 1});
      // El negocio de Diego (usuario 1) con un servicio.
      final dueno = await contenedor();
      final repo = dueno.$1.read(agendaRepoProvider);
      await t.runAsync(() async {
        dueno.$1.listen(configAgendaProvider, (_, _) {});
        await dueno.$1.read(configAgendaProvider.future);
        await repo.guardarNegocio({'nombre': 'Consultorio Diego', 'slug': 'consultorio-diego', 'tipo': 'profesional', 'intervalo_min': 60});
        await repo.guardarServicio({'nombre': 'Consulta', 'duracion_min': 60, 'precio': 90000});
      });
      // El backend del dueño es otro FakeBackend: se copia su agenda al de Ana.
      backend.agenda.negocios.addAll(dueno.$2.agenda.negocios);
      backend.agenda.profesionales.addAll(dueno.$2.agenda.profesionales);
      backend.agenda.servicios.addAll(dueno.$2.agenda.servicios);
      dueno.$1.dispose();

      await t.pumpWidget(ProviderScope(overrides: overridesDePrueba(backend: backend, db: dbEnMemoria(), sesion: sesionAna), child: const AgendaApp()));
      await esperar(t, 16);
      final router = ProviderScope.containerOf(t.element(find.byType(MaterialApp).first)).read(routerProvider);
      router.push('/agenda/consultorio-diego');
      await esperar(t, 20);

      // Un solo servicio y un solo profesional: directo a fecha y hora.
      expect(find.text('Elige fecha y hora'), findsOneWidget);
      final chip = find.byType(ChoiceChip).first;
      await t.ensureVisible(chip);
      await t.tap(chip);
      await esperar(t);
      await t.tap(find.text('Continuar'));
      await esperar(t);
      expect(find.text('Tus datos'), findsOneWidget);
      expect(find.text('Ana Cliente'), findsOneWidget); // datos de la sesión
      await t.ensureVisible(find.text('Recibir código por WhatsApp'));
      await t.tap(find.text('Recibir código por WhatsApp'));
      await esperar(t, 16);
      expect(find.text('Revisa tu WhatsApp'), findsOneWidget);
      expect(backend.agenda.citas.single['cliente_usuario_id'], 2);

      await t.enterText(find.byType(TextField).last, '123456');
      await esperar(t, 20);
      expect(find.text('¡Cita confirmada!'), findsOneWidget);
      expect(backend.agenda.citas.single['estado'], 'confirmada');
      await desmontar(t);
    });
  });
}
