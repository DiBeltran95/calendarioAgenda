import 'package:agendaservi/core/holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Pascua', () {
    expect(domingoDePascua(2026), DateTime(2026, 4, 5));
    expect(domingoDePascua(2027), DateTime(2027, 3, 28));
  });

  test('festivos de Colombia 2026 (18 días, Ley Emiliani)', () {
    final fechas = festivosColombia(2026).map((f) => f.fecha).toList();
    expect(fechas, [
      '2026-01-01', // Año Nuevo
      '2026-01-12', // Reyes (6 → lunes 12)
      '2026-03-23', // San José (19 → lunes 23)
      '2026-04-02', // Jueves Santo
      '2026-04-03', // Viernes Santo
      '2026-05-01', // Trabajo
      '2026-05-18', // Ascensión
      '2026-06-08', // Corpus Christi
      '2026-06-15', // Sagrado Corazón
      '2026-06-29', // San Pedro y San Pablo (ya es lunes)
      '2026-07-20', // Independencia
      '2026-08-07', // Boyacá
      '2026-08-17', // Asunción (15 → lunes 17)
      '2026-10-12', // Día de la Raza (ya es lunes)
      '2026-11-02', // Todos los Santos (1 → lunes 2)
      '2026-11-16', // Cartagena (11 → lunes 16)
      '2026-12-08', // Inmaculada
      '2026-12-25', // Navidad
    ]);
  });

  test('días especiales móviles', () {
    final e = {for (final d in diasEspeciales(2026)) d.nombre: d.fecha};
    expect(e['Día de la Madre'], '2026-05-10');
    expect(e['Día del Padre'], '2026-06-21');
    expect(e['Amor y Amistad'], '2026-09-19');
  });
}
