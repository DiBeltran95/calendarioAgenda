// Las notificaciones del teléfono deben seguir las mismas reglas del cron.

import 'package:agendaservi/data/models.dart';
import 'package:agendaservi/features/events/mensajes.dart';
import 'package:agendaservi/features/notifications/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

Evento ev(int id, String fecha, {String? hora, String categoria = 'reunion', int? tarjeta, double costo = 0, String titulo = 'Evento'}) =>
    Evento(id: id, titulo: titulo, fecha: fecha, hora: hora, categoria: categoria, tarjetaCreditoId: tarjeta, costo: costo);

void main() {
  // 23 sep 2026, 06:00 en Bogotá (11:00 UTC).
  final ahora = DateTime.utc(2026, 9, 23, 11);

  test('hora de Bogotá igual que el cron (UTC−5 fijo)', () {
    expect(instanteBogota('2026-09-23', '14:30'), DateTime.utc(2026, 9, 23, 19, 30));
    expect(fechaBogota(DateTime.utc(2026, 9, 24, 3)), '2026-09-23'); // 10 p. m. del 23 en Colombia
  });

  test('evento con hora: aviso 30 min antes y a la hora', () {
    final plan = planificarAvisos(eventos: [ev(1, '2026-09-23', hora: '10:00', titulo: 'Reunión equipo')], cumples: const [], cuentas: const [], ahora: ahora);
    expect(plan.map((a) => a.cuando), [DateTime.utc(2026, 9, 23, 14, 30), DateTime.utc(2026, 9, 23, 15)]);
    expect(plan.first.titulo, contains('En 30 minutos'));
    expect(plan.last.cuerpo, contains('Reunión equipo'));
    expect(plan.last.payload, 'dia:2026-09-23');
  });

  test('sin aviso de 30 min si el usuario lo desactiva', () {
    final plan = planificarAvisos(eventos: [ev(1, '2026-09-23', hora: '10:00')], cumples: const [], cuentas: const [], ahora: ahora, aviso30: false);
    expect(plan, hasLength(1));
  });

  test('arriendo, aceite, servicios, sin hora y cobros de tarjeta van al resumen de las 7', () {
    final plan = planificarAvisos(
      eventos: [
        ev(1, '2026-09-23', hora: '09:00', categoria: 'arriendo', costo: 900000, titulo: 'Arriendo'),
        ev(2, '2026-09-23', categoria: 'moto', titulo: 'SOAT'),
        ev(3, '2026-09-23', hora: '08:00', categoria: 'servicios', tarjeta: 5, titulo: 'Cuota 1/3: Celular'),
      ],
      cumples: const [],
      cuentas: const [],
      ahora: ahora,
    );
    expect(plan, hasLength(1));
    final r = plan.single;
    expect(r.cuando, DateTime.utc(2026, 9, 23, 12)); // 7:00 a. m. en Bogotá
    expect(r.titulo, contains('3 pendientes'));
    expect(r.cuerpo, contains('Arriendo'));
    expect(r.cuerpo, contains('💳 Cuota 1/3: Celular'));
  });

  test('cumpleaños, festivos y puente festivo en el resumen', () {
    // Viernes 13 nov 2026: el lunes 16 es festivo (Independencia de Cartagena).
    final plan = planificarAvisos(
      eventos: const [],
      cumples: const [Cumple(id: 1, nombre: 'Mamá', fecha: '1965-11-13')],
      cuentas: const [],
      ahora: DateTime.utc(2026, 11, 13, 5),
      dias: 1,
    );
    expect(plan.single.cuerpo, contains('Cumpleaños de Mamá'));
    expect(plan.single.cuerpo, contains('Puente festivo'));
  });

  test('el resumen de hoy no se programa si ya pasaron las 7:00', () {
    final plan = planificarAvisos(
      eventos: [ev(1, '2026-09-23', categoria: 'aceite_moto')],
      cumples: const [],
      cuentas: const [],
      ahora: DateTime.utc(2026, 9, 23, 13), // 8:00 a. m.
    );
    expect(plan, isEmpty);
  });

  test('CDT que vence entra en el resumen de ese día', () {
    final plan = planificarAvisos(
      eventos: const [],
      cumples: const [],
      cuentas: const [Cuenta(id: 1, nombre: 'CDT Bancolombia', tipo: 'cdt', saldo: 5000000, interesTasa: 11, fechaInicio: '2026-06-27', plazoDias: 90)],
      ahora: ahora,
    );
    expect(plan.single.cuerpo, contains('Vence tu CDT CDT Bancolombia'));
    expect(fechaBogota(plan.single.cuando), '2026-09-25');
  });

  test('máximo 60 avisos (iOS conserva 64) y siempre los más próximos', () {
    final muchos = [for (var i = 0; i < 80; i++) ev(i, '2026-09-${(24 + i ~/ 20).toString().padLeft(2, '0')}', hora: '${(i % 20 + 3).toString().padLeft(2, '0')}:00')];
    final plan = planificarAvisos(eventos: muchos, cumples: const [], cuentas: const [], ahora: ahora);
    expect(plan, hasLength(60));
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i].cuando.isBefore(plan[i - 1].cuando), isFalse);
    }
  });

  test('ids estables: reprogramar no duplica', () {
    expect(idAviso('ev:1:exacto'), idAviso('ev:1:exacto'));
    expect(idAviso('ev:1:exacto'), isNot(idAviso('ev:1:30m')));
  });

  test('los mensajes replican los del cron', () {
    final e = ev(1, '2026-09-23', hora: '14:30', categoria: 'doctor', titulo: 'Control');
    expect(mensajeExacto(e), contains('🩺 *Cita médica — ¡Es la hora!*'));
    expect(mensajeExacto(e), contains('*Hora:* 2:30 PM'));
    expect(mensajePrevio(e), startsWith('⏰ *Faltan 30 minutos* 🩺'));
    expect(textoPlano('Hola *Diego* _tú_'), 'Hola Diego tú');
  });
}
