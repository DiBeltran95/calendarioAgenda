import 'package:agendaservi/features/cycle/cycle_engine.dart';
import 'package:flutter_test/flutter_test.dart';

RegistroCiclo L(String f, [int id = 0, int? sangrado]) => RegistroCiclo(fechaInicio: f, id: id, diasSangrado: sangrado);

Fase? fase(String d, List<RegistroCiclo> logs, {String hoy = '2026-09-22'}) =>
    getCycleDetails(d, buildCycleStats(logs), hoy: hoy)?.fase;

void main() {
  test('promedia solo los 6 ciclos recientes (ventana móvil)', () {
    final s = buildCycleStats([
      L('2026-01-01'), L('2026-02-15'), // 45 días (antiguo, fuera de la ventana)
      L('2026-03-17'), L('2026-04-16'), L('2026-05-16'),
      L('2026-06-15'), L('2026-07-15'), L('2026-08-14'),
    ]);
    expect(s.avgCycleLength, 30);
    expect(s.ciclosUsados, 6);
  });

  test('con menos de 3 ciclos se pondera con el estándar de 28', () {
    expect(buildCycleStats([L('2026-07-01'), L('2026-06-01')]).avgCycleLength, 29);
  });

  test('los ciclos anómalos no entran al promedio', () {
    expect(buildCycleStats([L('2026-07-03'), L('2026-07-01'), L('2026-06-01')]).ciclosUsados, 1);
  });

  test('fases dentro de un ciclo cerrado de 28 días', () {
    final logs = [L('2026-06-01'), L('2026-06-29')];
    expect(fase('2026-06-01', logs), Fase.periodo);
    expect(fase('2026-06-05', logs), Fase.periodo);
    expect(fase('2026-06-06', logs), Fase.folicular);
    expect(fase('2026-06-14', logs), Fase.ovulacion);
    expect(fase('2026-06-10', logs), Fase.fertil);
    expect(fase('2026-06-20', logs), Fase.lutea);
    expect(fase('2026-06-29', logs), Fase.periodo);
  });

  test('la ovulación se recoloca al registrar un ciclo real más largo', () {
    expect(fase('2026-06-14', [L('2026-06-01')]), Fase.ovulacion);
    final despues = [L('2026-06-01'), L('2026-07-06')];
    expect(fase('2026-06-14', despues), Fase.folicular);
    expect(fase('2026-06-21', despues), Fase.ovulacion);
  });

  test('sin el registro siguiente, el inicio proyectado vencido es retraso', () {
    final sin = [L('2026-06-01', 1)];
    expect(fase('2026-06-29', sin, hoy: '2026-07-10'), Fase.periodoRetrasado);
    expect(fase('2026-07-06', sin, hoy: '2026-07-10'), Fase.folicular);
  });

  test('periodo previsto a futuro y horizonte acotado', () {
    final logs = [L('2026-06-01')];
    expect(fase('2026-06-29', logs, hoy: '2026-06-10'), Fase.periodoPrevisto);
    expect(fase('2027-06-01', logs), isNull);
    expect(fase('2026-05-31', logs), isNull);
  });

  test('los días de sangrado registrados cambian la duración del periodo', () {
    final logs = [L('2026-06-01', 1, 3), L('2026-06-29', 2, 3)];
    expect(fase('2026-06-03', logs), Fase.periodo);
    expect(fase('2026-06-04', logs), Fase.folicular);
    expect(buildCycleStats(logs).avgPeriodLength, 3);
  });

  test('historial marca en curso y anómalos', () {
    final h = getCycleHistory(buildCycleStats([L('2026-07-03'), L('2026-07-01'), L('2026-06-01')]));
    expect(h.first.enCurso, isTrue);
    expect(h[1].duracion, 2);
    expect(h[1].anomalo, isTrue);
    expect(h[2].duracion, 30);
  });

  test('validación de fechas', () {
    expect(validarFechaCiclo('2026-02-30', hoy: '2026-09-22'), isNotNull);
    expect(validarFechaCiclo('2026-09-23', hoy: '2026-09-22'), contains('futura'));
    expect(validarFechaCiclo('2026-09-22', hoy: '2026-09-22'), isNull);
  });

  test('pronóstico del próximo periodo y ventana fértil', () {
    final p = pronostico(buildCycleStats([L('2026-09-01')]), hoy: '2026-09-10');
    expect(p.proximoPeriodo, '2026-09-29');
    expect(p.ovulacion, '2026-09-14');
    expect(p.fertilDesde, '2026-09-09');
    expect(p.fertilHasta, '2026-09-15');
  });
}
