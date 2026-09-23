import test from 'node:test';
import assert from 'node:assert/strict';
import {
    aHora,
    aMinutos,
    ahoraBogota,
    disponibilidad,
    diaSemana,
    esFecha,
    normalizarRangos,
    slugDe,
    slugValido,
    sumarDias,
    turnosLibres,
    validarHorarios,
    type AgendaProfesional
} from './disponibilidad';

const r = (a: string, b: string) => ({ inicio: aMinutos(a), fin: aMinutos(b) });
const horas = (l: number[]) => l.map(aHora);

test('conversión de horas y fechas en hora de Colombia', () => {
    assert.equal(aMinutos('08:30'), 510);
    assert.equal(aMinutos('14:05:00'), 845);
    assert.equal(aHora(845), '14:05');
    // 03:00 UTC del 24 = 22:00 del 23 en Bogotá.
    assert.deepEqual(ahoraBogota(new Date('2026-09-24T03:00:00Z')), { fecha: '2026-09-23', minuto: 22 * 60 });
    assert.equal(sumarDias('2026-12-31', 1), '2027-01-01');
    assert.equal(diaSemana('2026-09-23'), 3); // miércoles
    assert.ok(esFecha('2028-02-29'));
    assert.ok(!esFecha('2026-02-30'));
});

test('turnos cada 15 min que caben completos en el horario', () => {
    const t = turnosLibres({ rangos: [r('08:00', '09:00')], ocupados: [], duracion: 30, paso: 15 });
    assert.deepEqual(horas(t), ['08:00', '08:15', '08:30']);
});

test('las citas y bloqueos ocupan su tiempo completo', () => {
    const t = turnosLibres({ rangos: [r('08:00', '10:00')], ocupados: [r('08:30', '09:15')], duracion: 30, paso: 15 });
    assert.deepEqual(horas(t), ['08:00', '09:15', '09:30']);
    // Un turno que termina justo cuando empieza otra cita sí es válido.
    assert.ok(horas(t).includes('09:15'));
    const pegado = turnosLibres({ rangos: [r('08:00', '10:00')], ocupados: [r('09:00', '10:00')], duracion: 60, paso: 30 });
    assert.deepEqual(horas(pegado), ['08:00']);
});

test('hoy solo se ofrece desde la anticipación mínima, alineado al paso', () => {
    const t = turnosLibres({ rangos: [r('08:00', '12:00')], ocupados: [], duracion: 60, paso: 30, desde: aMinutos('10:07') });
    assert.deepEqual(horas(t), ['10:30', '11:00']);
});

test('jornada partida (mañana y tarde) y rangos solapados', () => {
    const t = turnosLibres({ rangos: [r('08:00', '09:00'), r('14:00', '15:00')], ocupados: [], duracion: 60, paso: 30 });
    assert.deepEqual(horas(t), ['08:00', '14:00']);
    assert.deepEqual(normalizarRangos([r('08:00', '10:00'), r('09:00', '11:00'), r('11:00', '12:00'), r('13:00', '13:00')]), [r('08:00', '12:00')]);
});

test('un servicio más largo que el horario no ofrece turnos', () => {
    assert.deepEqual(turnosLibres({ rangos: [r('08:00', '09:00')], ocupados: [], duracion: 90, paso: 15 }), []);
});

test('validación de horarios semanales', () => {
    const ok = validarHorarios([
        { dia: 1, inicio: '08:00', fin: '12:00' },
        { dia: 1, inicio: '11:00', fin: '13:00' },
        { dia: 3, inicio: '14:00:00', fin: '18:00:00' }
    ]);
    assert.deepEqual(ok, { ok: true, horarios: [{ dia: 1, inicio: '08:00', fin: '13:00' }, { dia: 3, inicio: '14:00', fin: '18:00' }] });
    assert.equal(validarHorarios([{ dia: 7, inicio: '08:00', fin: '09:00' }]).ok, false);
    assert.equal(validarHorarios([{ dia: 1, inicio: '10:00', fin: '09:00' }]).ok, false);
    assert.equal(validarHorarios('x').ok, false);
});

const semana = [1, 2, 3, 4, 5].flatMap((dia) => [
    { dia, inicio: '08:00', fin: '12:00' },
    { dia, inicio: '14:00', fin: '18:00' }
]);

function prof(id: number, extra: Partial<AgendaProfesional> = {}): AgendaProfesional {
    return { id, horarios: semana, ocupados: new Map(), diasBloqueados: new Set(), ...extra };
}

test('"cualquier profesional": un turno aparece si alguno está libre', () => {
    const ana = prof(1, { ocupados: new Map([['2026-09-24', [r('08:00', '12:00')]]]) });
    const luis = prof(2, { diasBloqueados: new Set(['2026-09-24']) });
    const [jueves] = disponibilidad({
        profesionales: [ana, luis],
        desde: '2026-09-24',
        dias: 1,
        duracion: 60,
        paso: 60,
        limite: { fecha: '2026-09-23', minuto: 0 },
        hasta: '2026-10-23'
    });
    assert.deepEqual(jueves!.turnos.map((t) => t.hora), ['14:00', '15:00', '16:00', '17:00']);
    assert.deepEqual(jueves!.turnos[0]!.profesionales, [1]);

    const [viernes] = disponibilidad({ profesionales: [ana, prof(2)], desde: '2026-09-25', dias: 1, duracion: 60, paso: 60, limite: { fecha: '2026-09-23', minuto: 0 }, hasta: '2026-10-23' });
    assert.deepEqual(viernes!.turnos[0], { hora: '08:00', profesionales: [1, 2] });
});

test('fines de semana sin horario, días pasados vacíos y ventana máxima', () => {
    const dias = disponibilidad({
        profesionales: [prof(1)],
        desde: '2026-09-22',
        dias: 7,
        duracion: 30,
        paso: 30,
        limite: { fecha: '2026-09-23', minuto: aMinutos('17:00') },
        hasta: '2026-09-26'
    });
    assert.deepEqual(dias.map((d) => d.fecha), ['2026-09-22', '2026-09-23', '2026-09-24', '2026-09-25', '2026-09-26']);
    assert.equal(dias[0]!.turnos.length, 0); // ayer
    assert.deepEqual(dias[1]!.turnos.map((t) => t.hora), ['17:00', '17:30']); // hoy desde las 17:00
    assert.equal(dias[4]!.turnos.length, 0); // sábado
});

test('slugs de enlace', () => {
    assert.equal(slugDe('Peluquería Doña Ana  & Co.'), 'peluqueria-dona-ana-co');
    assert.equal(slugDe('Dr. José Pérez — Psicólogo'), 'dr-jose-perez-psicologo');
    assert.ok(slugValido('psicologa-laura'));
    assert.ok(!slugValido('ab-'));
    assert.ok(!slugValido('a'));
    assert.ok(!slugValido('login'));
    assert.ok(!slugValido('Mayus'));
    assert.ok(!slugValido('doble--guion'));
});
