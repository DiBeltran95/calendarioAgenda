import { buildCycleStats, getCycleDetails, getCycleHistory } from './cycleUtils';

let pass = 0, fail = 0;
function check(name: string, actual: any, expected: any) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (ok) { pass++; console.log(`  ok   ${name}`); }
  else { fail++; console.log(`  FAIL ${name}\n       esperado: ${JSON.stringify(expected)}\n       real:     ${JSON.stringify(actual)}`); }
}
const L = (f: string, id = 0) => ({ id, fecha_inicio: f });
const phase = (d: string, logs: any[]) => getCycleDetails(d, logs)?.phaseKey ?? null;

// Fecha local de hoy, para construir escenarios relativos
function hoyMas(dias: number) {
  const d = new Date();
  d.setDate(d.getDate() + dias);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

console.log('\n1) Promedio con ventana móvil');
{
  // 6 ciclos de 30 días + uno antiguo anómalo de 45 -> el antiguo queda fuera de la ventana
  const logs = [
    L('2026-01-01'), L('2026-02-15'), // 45 días (antiguo)
    L('2026-03-17'), L('2026-04-16'), L('2026-05-16'),
    L('2026-06-15'), L('2026-07-15'), L('2026-08-14')
  ];
  const s = buildCycleStats(logs);
  check('promedia sólo los 6 ciclos recientes (30 días)', s.avgCycleLength, 30);
  check('cuenta 6 ciclos usados', s.ciclosUsados, 6);
}

console.log('\n2) Menos de 3 ciclos: se pondera con el estándar de 28');
{
  const s = buildCycleStats([L('2026-07-01'), L('2026-06-01')]); // 30 días
  check('un solo ciclo de 30 -> (30 + 2*28)/3 = 29', s.avgCycleLength, 29);
}

console.log('\n3) Ciclos anómalos excluidos del promedio');
{
  const s = buildCycleStats([L('2026-07-03'), L('2026-07-01'), L('2026-06-01')]); // 2 días y 30 días
  check('el ciclo de 2 días no entra', s.ciclosUsados, 1);
}

console.log('\n4) Fases dentro de un ciclo cerrado de 28 días');
{
  const logs = [L('2026-06-01'), L('2026-06-29')];
  check('día 1  -> period', phase('2026-06-01', logs), 'period');
  check('día 5  -> period', phase('2026-06-05', logs), 'period');
  check('día 6  -> follicular', phase('2026-06-06', logs), 'follicular');
  check('día 14 -> ovulation (28-14)', phase('2026-06-14', logs), 'ovulation');
  check('día 10 -> fertile', phase('2026-06-10', logs), 'fertile');
  check('día 20 -> luteal', phase('2026-06-20', logs), 'luteal');
  check('día 29 -> period del ciclo siguiente', phase('2026-06-29', logs), 'period');
}

console.log('\n5) La ovulación se recoloca al registrar un ciclo nuevo (recálculo)');
{
  const antes = [L('2026-06-01')];                    // sin cierre: proyecta con 28
  const despues = [L('2026-06-01'), L('2026-07-06')]; // ciclo real de 35 días
  check('antes: día 14 es ovulación', phase('2026-06-14', antes), 'ovulation');
  check('después: día 14 ya no lo es', phase('2026-06-14', despues), 'follicular');
  check('después: la ovulación pasa al día 21', phase('2026-06-21', despues), 'ovulation');
}

console.log('\n6) Al eliminar un registro se recalcula hacia atrás');
{
  const con = [L('2026-06-01', 1), L('2026-07-06', 2)];
  const sin = [L('2026-06-01', 1)];
  check('con el registro: 2026-07-06 es period', phase('2026-07-06', con), 'period');
  check('sin él: el inicio proyectado (28 días) se marca como retraso',
    phase('2026-06-29', sin), 'late-period');
  check('sin él: el 07-06 ya no es día 1 de nada', phase('2026-07-06', sin), 'follicular');
}

console.log('\n7) Horizonte de proyección acotado');
{
  const logs = [L('2026-06-01')];
  check('a 1 ciclo vista sí predice', phase('2026-06-30', logs) !== null, true);
  check('a 3+ ciclos ya no pinta nada', phase('2027-06-01', logs), null);
  check('antes del primer registro: null', phase('2026-05-31', logs), null);
}

console.log('\n8) Retraso vs predicción');
{
  const logs = [L(hoyMas(-40))]; // periodo esperado hace ~12 días
  const d = getCycleDetails(hoyMas(-11), logs);
  check('un periodo esperado ya pasado es "late-period"', d?.phaseKey, 'late-period');
  check('reporta días de retraso > 0', (d?.diasRetraso ?? 0) > 0, true);
  const futuro = getCycleDetails(hoyMas(20), [L(hoyMas(-8))]);
  check('un periodo futuro es "predicted-period"', futuro?.phaseKey, 'predicted-period');
}

console.log('\n9) Sin desfase UTC en "hoy"');
{
  const hoy = hoyMas(0);
  const d = getCycleDetails(hoy, [L(hoy)]);
  check('el día de hoy se titula "Hoy"', d?.dateTitle.startsWith('Hoy es el Día 1'), true);
  check('marca el ciclo como observado', d?.esCicloObservado, true);
}

console.log('\n10) Robustez ante datos sucios');
{
  check('lista vacía', getCycleDetails('2026-06-01', []), null);
  check('null', getCycleDetails('2026-06-01', null), null);
  check('registros inválidos se descartan', buildCycleStats([{ fecha_inicio: 'basura' } as any]).logs.length, 0);
  // Duplicado exacto (dato heredado antes de la clave única)
  const dup = getCycleDetails('2026-06-03', [L('2026-06-01', 1), L('2026-06-01', 2)]);
  check('duplicado no produce NaN/Infinity', Number.isFinite(dup?.progressPercent ?? NaN), true);
  check('duplicado no produce progreso absurdo', (dup?.progressPercent ?? 0) <= 100, true);
  // Fecha futura heredada (antes de la validación del backend)
  const fut = getCycleDetails('2026-08-01', [L('2026-07-01'), L('2030-01-01')]);
  check('un registro futuro heredado no rompe el cálculo', fut !== null && Number.isFinite(fut.dayInCurrentCycle), true);
}

console.log('\n11) Historial');
{
  const h = getCycleHistory([L('2026-06-01', 1), L('2026-07-06', 2), L('2026-07-08', 3)]);
  check('ordena del más reciente al más antiguo', h.map(x => x.fecha_inicio), ['2026-07-08', '2026-07-06', '2026-06-01']);
  check('el más reciente está en curso', h[0].enCurso, true);
  check('el más reciente no tiene duración aún', h[0].duracion, null);
  check('duración del ciclo del 06-01 = 35 días', h[2].duracion, 35);
  check('marca el ciclo de 2 días como atípico', h[1].anomalo, true);
}

console.log('\n12) Días de sangrado por ciclo');
{
  const S = (f: string, dias: number | null, id = 0) => ({ id, fecha_inicio: f, dias_sangrado: dias });

  // Un ciclo con 3 días registrados: el día 4 ya no es menstruación.
  const corto = [S('2026-06-01', 3), S('2026-06-29', null)];
  check('día 3 con sangrado de 3 -> period', phase('2026-06-03', corto), 'period');
  check('día 4 con sangrado de 3 -> follicular', phase('2026-06-04', corto), 'follicular');

  // El mismo ciclo con 7 días registrados sí llega al día 7.
  const largo = [S('2026-06-01', 7), S('2026-06-29', null)];
  check('día 7 con sangrado de 7 -> period', phase('2026-06-07', largo), 'period');

  // Sin registrar, cae al promedio de la usuaria.
  const mixto = [S('2026-08-03', null), S('2026-07-06', 7), S('2026-06-01', 7)];
  const st = buildCycleStats(mixto);
  check('promedio de sangrado = 7', st.avgPeriodLength, 7);
  check('cuenta 2 registros con sangrado', st.sangradosUsados, 2);
  check('el ciclo sin dato usa el promedio (día 7 sigue siendo period)',
    phase('2026-08-09', mixto), 'period');

  const d = getCycleDetails('2026-08-09', mixto);
  check('marca el sangrado como estimado', d?.sangradoEstimado, true);
  check('expone los días aplicados', d?.diasSangrado, 7);

  const dReal = getCycleDetails('2026-07-06', mixto);
  check('un ciclo con dato propio no se marca estimado', dReal?.sangradoEstimado, false);

  // Sin ningún dato, el valor de referencia sigue siendo 5.
  check('sin datos -> 5 días por defecto', buildCycleStats([L('2026-06-01')]).avgPeriodLength, 5);

  // Valores corruptos se ignoran.
  const sucio = buildCycleStats([S('2026-06-01', 99), S('2026-05-01', -2)]);
  check('descarta valores fuera de rango', sucio.sangradosUsados, 0);
  check('y cae al valor por defecto', sucio.avgPeriodLength, 5);

  // El historial reporta el dato o su ausencia.
  const h = getCycleHistory(mixto);
  check('historial expone los días de sangrado', h.map(x => x.diasSangrado), [null, 7, 7]);
}

console.log(`\n${pass} pasaron, ${fail} fallaron\n`);
// tsconfig.app.json no incluye los tipos de Node; este archivo se ejecuta con tsx.
declare const process: { exit(code: number): never };
process.exit(fail > 0 ? 1 : 0);
