import { validarFechaCiclo, validarDiasSangrado, normalizarDiasSangrado } from './cycleValidation';

let pass = 0, fail = 0;
function check(name: string, actual: any, expected: any) {
    const ok = JSON.stringify(actual) === JSON.stringify(expected);
    if (ok) { pass++; console.log(`  ok   ${name}`); }
    else { fail++; console.log(`  FAIL ${name}\n       esperado: ${JSON.stringify(expected)}\n       real:     ${JSON.stringify(actual)}`); }
}

// Referencia fija: 2026-07-28 a las 10:00 UTC -> 05:00 en Colombia.
const AHORA = new Date('2026-07-28T10:00:00Z');
const v = (f: any) => validarFechaCiclo(f, AHORA);

console.log('\nFechas aceptadas');
check('hoy', v('2026-07-28'), null);
check('ayer', v('2026-07-27'), null);
check('hace años', v('2020-01-01'), null);
check('29 de febrero de año bisiesto', v('2024-02-29'), null);

console.log('\nFormato');
check('formato dd/mm/yyyy', v('28/07/2026'), 'La fecha debe tener el formato YYYY-MM-DD');
check('ISO con hora', v('2026-07-28T00:00:00Z'), 'La fecha debe tener el formato YYYY-MM-DD');
check('texto', v('ayer'), 'La fecha debe tener el formato YYYY-MM-DD');
check('undefined', v(undefined), 'La fecha debe tener el formato YYYY-MM-DD');
check('null', v(null), 'La fecha debe tener el formato YYYY-MM-DD');
check('número', v(20260728), 'La fecha debe tener el formato YYYY-MM-DD');
check('objeto', v({}), 'La fecha debe tener el formato YYYY-MM-DD');

console.log('\nFechas inexistentes');
check('30 de febrero', v('2026-02-30'), 'La fecha no existe en el calendario');
check('29 de febrero en año no bisiesto', v('2026-02-29'), 'La fecha no existe en el calendario');
check('mes 13', v('2026-13-01'), 'La fecha no existe en el calendario');
check('día 00', v('2026-07-00'), 'La fecha no existe en el calendario');
check('31 de abril', v('2026-04-31'), 'La fecha no existe en el calendario');

console.log('\nFuturo (la causa de la corrupción irreversible del calendario)');
check('mañana', v('2026-07-29'), 'No puedes registrar un periodo con fecha futura');
check('dentro de años', v('2030-01-01'), 'No puedes registrar un periodo con fecha futura');

console.log('\nZona horaria: el corte es el día en Colombia, no el del servidor');
// 2026-07-29 02:00 UTC = 2026-07-28 21:00 en Colombia: el 29 aún es futuro.
const nocheCO = new Date('2026-07-29T02:00:00Z');
check('a las 9pm en Colombia, "mañana" sigue siendo futuro',
    validarFechaCiclo('2026-07-29', nocheCO), 'No puedes registrar un periodo con fecha futura');
check('a las 9pm en Colombia, "hoy" se acepta',
    validarFechaCiclo('2026-07-28', nocheCO), null);

console.log('\nLímite inferior');
check('año 1800', v('1800-01-01'), 'La fecha es demasiado antigua');

console.log('\nDías de sangrado');
const RANGO = 'Los días de sangrado deben estar entre 1 y 15';
check('es opcional: null', validarDiasSangrado(null), null);
check('es opcional: undefined', validarDiasSangrado(undefined), null);
check('es opcional: cadena vacía', validarDiasSangrado(''), null);
check('valor típico', validarDiasSangrado(5), null);
check('acepta el mínimo', validarDiasSangrado(1), null);
check('acepta el máximo', validarDiasSangrado(15), null);
check('acepta numérico como texto', validarDiasSangrado('4'), null);
check('cero', validarDiasSangrado(0), RANGO);
check('negativo', validarDiasSangrado(-3), RANGO);
check('demasiado alto', validarDiasSangrado(40), RANGO);
check('decimal', validarDiasSangrado(3.5), 'Los días de sangrado deben ser un número entero');
check('texto', validarDiasSangrado('cinco'), 'Los días de sangrado deben ser un número entero');

console.log('\nNormalización para la BD');
check('vacío -> null', normalizarDiasSangrado(''), null);
check('null -> null', normalizarDiasSangrado(null), null);
check('texto numérico -> número', normalizarDiasSangrado('6'), 6);
check('número -> número', normalizarDiasSangrado(6), 6);

console.log(`\n${pass} pasaron, ${fail} fallaron\n`);
process.exit(fail > 0 ? 1 : 0);
