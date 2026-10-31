// Préstamos y ganancias diarias: reglas de saldo y validación (sin base de datos)
// y, si hay base de pruebas (AGENDA_DB_*), las rutas de punta a punta.

import test, { after, before, beforeEach, describe } from 'node:test';
import assert from 'node:assert/strict';
import Fastify, { type FastifyInstance } from 'fastify';
import jwt from '@fastify/jwt';
import mysql, { type Pool } from 'mysql2/promise';
import { activarCuentaNu, hoyColombia, interesDiario, migrarGanancias, olvidarRevision, ponerUsuarioAlDia, quitarGananciasDeCuenta, registrarGanancias, rendimientoDiario, sumarDias } from './ganancias';
import { efectoPrestamo, migrarPrestamos, normalizarMovimientoPrestamo, normalizarPrestamo, registrarPrestamos } from './prestamos';

describe('cuentas', () => {
    test('prestar saca de la cuenta; desde una tarjeta aumenta la deuda', () => {
        assert.equal(efectoPrestamo('desembolso', 'ahorros', 100), -100);
        assert.equal(efectoPrestamo('desembolso', 'tarjeta_credito', 100), 100);
    });
    test('un abono entra a la cuenta; en una tarjeta reduce la deuda', () => {
        assert.equal(efectoPrestamo('abono', 'efectivo', 100), 100);
        assert.equal(efectoPrestamo('abono', 'tarjeta_credito', 100), -100);
    });
});

describe('ganancia de un día', () => {
    test('una cuenta: un año de días da la tasa efectiva anual', () => {
        let saldo = 1000000;
        for (let i = 0; i < 365; i++) saldo += rendimientoDiario(saldo, 10);
        assert.ok(Math.abs(saldo - 1100000) < 50, String(saldo));
    });
    test('un préstamo: 30 días dan el interés mensual', () => {
        assert.ok(Math.abs(interesDiario(1000000, 2) * 30 - 20000) < 1);
    });
    test('sin saldo o sin tasa no hay ganancia', () => {
        assert.equal(rendimientoDiario(0, 10), 0);
        assert.equal(rendimientoDiario(-500, 10), 0);
        assert.equal(interesDiario(1000, 0), 0);
    });
    test('las fechas cruzan meses y años, y hoy es el de Colombia', () => {
        assert.equal(sumarDias('2026-12-31', 1), '2027-01-01');
        assert.equal(hoyColombia(new Date('2026-10-31T03:00:00Z')), '2026-10-30');
    });
});

describe('validación', () => {
    test('un préstamo necesita a quién y un interés razonable', () => {
        assert.equal(typeof normalizarPrestamo({ persona: ' ' }), 'string');
        assert.equal(typeof normalizarPrestamo({ persona: 'Ana', tasa_mensual: 101, interes_desde: '2026-10-30' }), 'string');
        assert.equal(typeof normalizarPrestamo({ persona: 'Ana', tasa_mensual: -1 }), 'string');
        assert.equal(typeof normalizarPrestamo({ persona: 'Ana', vencimiento: '2026-02-30' }), 'string');
    });
    test('con interés hay que decir desde cuándo corre', () => {
        assert.equal(typeof normalizarPrestamo({ persona: 'Ana', tasa_mensual: 2 }), 'string');
        assert.equal(typeof normalizarPrestamo({ persona: 'Ana', tasa_mensual: 2, interes_desde: 'ayer' }), 'string');
        assert.notEqual(typeof normalizarPrestamo({ persona: 'Ana', tasa_mensual: 2, interes_desde: '2026-10-30' }), 'string');
    });
    test('sin interés y sin fecha de pago también es válido', () => {
        assert.deepEqual(normalizarPrestamo({ persona: ' Ana ', interes_desde: '2026-10-30' }), { persona: 'Ana', tasa_mensual: 0, interes_desde: null, vencimiento: null, nota: '' });
    });
    test('un desembolso necesita capital y no lleva intereses', () => {
        const base = { tipo: 'desembolso', fecha: '2026-10-30' };
        assert.equal(typeof normalizarMovimientoPrestamo({ ...base, capital: 0 }), 'string');
        assert.equal(typeof normalizarMovimientoPrestamo({ ...base, capital: 100, interes: 5 }), 'string');
        assert.notEqual(typeof normalizarMovimientoPrestamo({ ...base, capital: 100 }), 'string');
    });
    test('un abono puede ser solo de intereses, pero no vacío', () => {
        const base = { tipo: 'abono', fecha: '2026-10-30' };
        assert.equal(typeof normalizarMovimientoPrestamo({ ...base, capital: 0, interes: 0 }), 'string');
        assert.equal(typeof normalizarMovimientoPrestamo({ ...base, capital: -1, interes: 5 }), 'string');
        assert.equal(typeof normalizarMovimientoPrestamo({ ...base, capital: 1, fecha: 'ayer' }), 'string');
        assert.notEqual(typeof normalizarMovimientoPrestamo({ ...base, interes: 5 }), 'string');
    });
});

const HOST = process.env.AGENDA_DB_HOST;
const omitir = !HOST ? 'sin base de pruebas (define AGENDA_DB_HOST)' : false;

describe('rutas', { skip: omitir }, () => {
    let pool: Pool;
    let app: FastifyInstance;
    let token: string;
    let otro: string;
    let ahorros: number;
    let tarjeta: number;
    const hoy = hoyColombia();
    const haceDias = (n: number) => sumarDias(hoy, -n);
    const log = { info: () => {}, error: () => {} };

    before(async () => {
        const opciones = { host: HOST, port: Number(process.env.AGENDA_DB_PORT || 3306), user: process.env.AGENDA_DB_USER || 'root', password: process.env.AGENDA_DB_PASS || '' };
        const admin = await mysql.createConnection(opciones as any);
        await admin.query('DROP DATABASE IF EXISTS agenda_test_prestamos');
        await admin.query('CREATE DATABASE agenda_test_prestamos');
        await admin.end();
        pool = mysql.createPool({ ...opciones, database: 'agenda_test_prestamos', timezone: 'Z', connectionLimit: 5 } as any);
        await pool.query(`CREATE TABLE usuarios (id INT PRIMARY KEY, email VARCHAR(255) NOT NULL)`);
        await pool.query(`CREATE TABLE finanzas_cuentas (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, nombre VARCHAR(255) NOT NULL, tipo VARCHAR(50) NOT NULL, saldo DECIMAL(12,2) DEFAULT 0.00, interes_tasa DECIMAL(5,2) DEFAULT 0, fecha_inicio DATE NULL, plazo_dias INT DEFAULT 0)`);
        await pool.query(`CREATE TABLE finanzas_transacciones (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, cuenta_id INT NULL, tipo VARCHAR(20) NOT NULL, monto DECIMAL(12,2) NOT NULL, descripcion VARCHAR(255) NOT NULL, fecha DATE NOT NULL, categoria VARCHAR(50) DEFAULT 'otros')`);
        await migrarPrestamos(pool, log);
        await migrarGanancias(pool, log);
        const cuenta = async (nombre: string, tipo: string, saldo: number) =>
            ((await pool.query('INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo) VALUES (1, ?, ?, ?)', [nombre, tipo, saldo])) as any)[0].insertId as number;
        ahorros = await cuenta('Ahorros', 'ahorros', 1000000);
        tarjeta = await cuenta('Visa', 'tarjeta_credito', 0);

        app = Fastify();
        await app.register(jwt, { secret: 'prueba' });
        app.decorate('authenticate', async (req: any, reply: any) => {
            try {
                await req.jwtVerify();
            } catch (err) {
                reply.send(err);
            }
        });
        registrarPrestamos(app, { pool });
        registrarGanancias(app, { pool });
        await app.ready();
        token = app.jwt.sign({ id: 1 });
        otro = app.jwt.sign({ id: 2 });
    });

    beforeEach(() => olvidarRevision());

    after(async () => {
        await app?.close();
        await pool?.end();
    });

    const api = async (method: string, url: string, body?: unknown, t = token) => {
        const r = await app.inject({ method: method as any, url, payload: body as any, headers: { authorization: `Bearer ${t}` } });
        return { status: r.statusCode, body: r.json() as any };
    };
    const saldo = async (id: number) => Number(((await pool.query('SELECT saldo FROM finanzas_cuentas WHERE id = ?', [id])) as any)[0][0].saldo);
    const ingresos = async (categoria?: string) =>
        ((await pool.query("SELECT * FROM finanzas_transacciones WHERE tipo = 'ingreso' AND (? IS NULL OR categoria = ?) ORDER BY fecha", [categoria ?? null, categoria ?? null])) as any)[0] as any[];
    const lista = async () => (await api('GET', '/api/finanzas/prestamos')).body as any[];
    const de = async (id: number) => (await lista()).find((p) => p.id === id);
    const prestar = async (extra: object = {}) => {
        const r = await api('POST', '/api/finanzas/prestamos', { persona: 'Ana', capital: 300000, fecha: haceDias(10), cuenta_id: ahorros, ...extra });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        return r.body.id as number;
    };

    test('sin intereses: sale de la cuenta, un abono la devuelve y nunca hay ingreso', async () => {
        const id = await prestar();
        assert.equal(await saldo(ahorros), 700000);
        const a = await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 100000, fecha: haceDias(5), cuenta_id: ahorros });
        assert.equal(a.status, 200, JSON.stringify(a.body));
        assert.equal(await saldo(ahorros), 800000);
        assert.equal((await ingresos()).length, 0, 'devolver lo prestado no es una ganancia');
        const p = await de(id);
        assert.equal(p.interes_causado, 0);
        assert.deepEqual(p.movimientos.map((m: any) => [m.tipo, m.capital, m.interes, m.cuenta_nombre]), [
            ['desembolso', 300000, 0, 'Ahorros'],
            ['abono', 100000, 0, 'Ahorros']
        ]);
        assert.equal((await api('DELETE', `/api/finanzas/prestamos/${id}`)).status, 200);
        assert.equal(await saldo(ahorros), 1000000);
        assert.equal(await de(id), undefined);
    });

    test('con interés: cada día desde la fecha elegida es un ingreso, sin tocar la cuenta', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        const filas = await ingresos('intereses_prestamo');
        assert.equal(filas.length, 4, 'cuatro días corridos, no los diez desde que se prestó');
        assert.ok(filas.every((f) => f.cuenta_id === null && Number(f.monto) === 300 && f.descripcion === 'Intereses: Ana'));
        assert.equal((await de(id)).interes_causado, 1200);
        assert.equal(await saldo(ahorros), 700000, 'los intereses aún no han llegado a la cuenta');

        // Repetirlo no los cuenta dos veces.
        olvidarRevision();
        assert.equal(await ponerUsuarioAlDia(pool, 1), 0);
        assert.equal((await ingresos('intereses_prestamo')).length, 4);

        // Si fue un error y se elimina, se va todo.
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
        assert.equal((await ingresos()).length, 0);
        assert.equal(await saldo(ahorros), 1000000);
    });

    test('cobrar intereses los pasa a la cuenta sin contarlos otra vez como ingreso', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        const r = await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 0, interes: 1200, fecha: hoy, cuenta_id: ahorros });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        assert.equal(await saldo(ahorros), 701200);
        assert.equal((await ingresos()).length, 4);
        // No se puede cobrar más de lo acumulado, y el saldo no se toca.
        const m = await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', interes: 5000, fecha: hoy, cuenta_id: ahorros });
        assert.equal(m.status, 400);
        assert.equal(await saldo(ahorros), 701200);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
        assert.equal(await saldo(ahorros), 1000000);
    });

    test('un abono atrasado baja los intereses desde ese día en adelante', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 150000, fecha: haceDias(2), cuenta_id: ahorros });
        const montos = (await ingresos('intereses_prestamo')).map((f) => Number(f.monto));
        assert.deepEqual(montos, [300, 300, 150, 150]);
        const p = await de(id);
        const r = await api('DELETE', `/api/finanzas/prestamo-movimientos/${p.movimientos[1].id}`);
        assert.equal(r.status, 200, JSON.stringify(r.body));
        assert.deepEqual((await ingresos('intereses_prestamo')).map((f) => Number(f.monto)), [300, 300, 300, 300]);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    test('corregir la tasa o la fecha rehace los intereses; quitar la tasa los borra', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        await api('PUT', `/api/finanzas/prestamos/${id}`, { persona: 'Ana', tasa_mensual: 6, interes_desde: haceDias(2) });
        assert.deepEqual((await ingresos('intereses_prestamo')).map((f) => Number(f.monto)), [600, 600]);
        await api('PUT', `/api/finanzas/prestamos/${id}`, { persona: 'Ana', tasa_mensual: 0 });
        assert.equal((await ingresos()).length, 0);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    test('al cerrarlo deja de sumar; al reabrirlo se pone al día', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        await api('POST', `/api/finanzas/prestamos/${id}/cerrar`, { cerrado: true, fecha: haceDias(2) });
        assert.equal((await de(id)).cerrado_en, haceDias(2));
        assert.equal((await ingresos('intereses_prestamo')).length, 2);
        assert.equal((await api('POST', `/api/finanzas/prestamos/${id}/cerrar`, { cerrado: true })).status, 400, 'pide la fecha');
        await api('POST', `/api/finanzas/prestamos/${id}/cerrar`, { cerrado: false });
        assert.equal((await de(id)).cerrado_en, null);
        assert.equal((await ingresos('intereses_prestamo')).length, 4);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    test('pagado el capital deja de causar intereses', async () => {
        const id = await prestar({ tasa_mensual: 3, interes_desde: haceDias(4) });
        await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 300000, fecha: haceDias(3), cuenta_id: ahorros });
        assert.deepEqual((await ingresos('intereses_prestamo')).map((f) => Number(f.monto)), [300]);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    test('no se puede abonar más capital del que falta, ni quedarse sin desembolso', async () => {
        const id = await prestar();
        const r = await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 300001, fecha: hoy, cuenta_id: ahorros });
        assert.equal(r.status, 400);
        assert.equal(await saldo(ahorros), 700000, 'el saldo no se tocó');
        const p = await de(id);
        const d = await api('DELETE', `/api/finanzas/prestamo-movimientos/${p.movimientos[0].id}`);
        assert.equal(d.status, 400);
        assert.equal(await saldo(ahorros), 700000);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    test('prestar más suma; con tarjeta aumenta la deuda; sin cuenta no mueve dinero', async () => {
        const id = await prestar({ cuenta_id: null });
        assert.equal(await saldo(ahorros), 1000000);
        await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'desembolso', capital: 100000, fecha: hoy, cuenta_id: tarjeta });
        assert.equal(await saldo(tarjeta), 100000);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
        assert.equal(await saldo(tarjeta), 0);
    });

    test('cada quien ve y toca solo lo suyo', async () => {
        const id = await prestar({ cuenta_id: null });
        assert.equal((await api('GET', '/api/finanzas/prestamos', undefined, otro)).body.length, 0);
        assert.equal((await api('PUT', `/api/finanzas/prestamos/${id}`, { persona: 'Otro' }, otro)).status, 404);
        assert.equal((await api('DELETE', `/api/finanzas/prestamos/${id}`, undefined, otro)).status, 404);
        assert.equal((await api('POST', `/api/finanzas/prestamos/${id}/movimientos`, { tipo: 'abono', capital: 1, fecha: hoy }, otro)).status, 404);
        assert.equal((await api('PUT', `/api/finanzas/cuentas/${ahorros}/ganancias`, { tasa: 9, desde: hoy }, otro)).status, 404);
        // Tampoco puede usar la cuenta de otra persona.
        const r = await api('POST', '/api/finanzas/prestamos', { persona: 'Ana', capital: 10, fecha: hoy, cuenta_id: ahorros }, otro);
        assert.equal(r.status, 404);
        assert.equal(await saldo(ahorros), 1000000);
        await api('DELETE', `/api/finanzas/prestamos/${id}`);
    });

    describe('cuentas que generan ganancias', () => {
        const nueva = async (nombre: string, saldoInicial: number, usuario = 1, extra = '') =>
            ((await pool.query(`INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo) VALUES (?, ?, 'ahorros', ?) ${extra}`, [usuario, nombre, saldoInicial])) as any)[0].insertId as number;
        const ganancias = (id: number) => pool.query("SELECT * FROM finanzas_transacciones WHERE cuenta_id = ? AND categoria = 'rendimientos' ORDER BY fecha", [id]).then((r: any) => r[0] as any[]);

        test('lo activado hoy empieza a sumar mañana, y con fecha pasada se pone al día', async () => {
            const nu = await nueva('Nu', 1000000);
            await api('PUT', `/api/finanzas/cuentas/${nu}/ganancias`, { tasa: 9, desde: hoy });
            assert.equal((await ganancias(nu)).length, 0);
            assert.equal(await saldo(nu), 1000000);

            const r = await api('PUT', `/api/finanzas/cuentas/${nu}/ganancias`, { tasa: 9, desde: haceDias(3) });
            assert.equal(r.status, 200, JSON.stringify(r.body));
            const filas = await ganancias(nu);
            assert.deepEqual(filas.map((f) => f.fecha.toISOString().slice(0, 10)), [haceDias(2), haceDias(1), hoy]);
            const suma = filas.reduce((s, f) => s + Number(f.monto), 0);
            assert.ok(suma > 0);
            assert.ok(Number(filas[2].monto) >= Number(filas[0].monto), 'compone');
            assert.equal(await saldo(nu), Math.round((1000000 + suma) * 100) / 100, 'sube el saldo');

            // Repetirlo no suma de nuevo.
            olvidarRevision();
            assert.equal(await ponerUsuarioAlDia(pool, 1), 0);
            assert.equal((await ganancias(nu)).length, 3);
        });

        test('un día sin revisar se recupera solo', async () => {
            const c = await nueva('Cajita', 2000000);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 9, desde: haceDias(2) });
            const antes = await ganancias(c);
            await pool.query('DELETE FROM finanzas_ganancias WHERE origen_id = ? AND origen = ? AND fecha = ?', [c, 'cuenta', hoy]);
            await pool.query('DELETE FROM finanzas_transacciones WHERE id = ?', [antes[1].id]);
            await pool.query('UPDATE finanzas_cuentas SET saldo = saldo - ? WHERE id = ?', [antes[1].monto, c]);
            olvidarRevision();
            assert.equal(await ponerUsuarioAlDia(pool, 1), 1);
            assert.equal((await ganancias(c)).length, 2);
        });

        test('cambiar la tasa sin recalcular deja lo anterior; recalculando lo rehace', async () => {
            const c = await nueva('Rinde', 1000000);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 9, desde: haceDias(2) });
            const antes = await ganancias(c);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 18, desde: haceDias(2) });
            assert.deepEqual((await ganancias(c)).map((f) => f.id), antes.map((f) => f.id));
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 18, desde: haceDias(2), recalcular: true });
            const despues = await ganancias(c);
            assert.equal(despues.length, 2);
            assert.ok(Number(despues[0].monto) > Number(antes[0].monto));
        });

        test('apagarlas: lo sumado se queda, salvo que se pida quitarlo', async () => {
            const c = await nueva('Apagar', 1000000);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 9, desde: haceDias(2) });
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { desde: null });
            assert.equal((await ganancias(c)).length, 2);
            assert.ok((await saldo(c)) > 1000000);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 9, desde: haceDias(2) });
            const q = await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { desde: null, quitar: true });
            assert.ok(q.body.quitado > 0);
            assert.equal((await ganancias(c)).length, 0);
            assert.equal(await saldo(c), 1000000);
        });

        test('eliminar la cuenta se lleva sus ganancias', async () => {
            const c = await nueva('Borrar', 1000000);
            await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 9, desde: haceDias(2) });
            await quitarGananciasDeCuenta(pool, 1, c);
            assert.equal((await ganancias(c)).length, 0);
            assert.equal(await saldo(c), 1000000);
        });

        test('una tarjeta no genera ganancias y hace falta tasa', async () => {
            assert.equal((await api('PUT', `/api/finanzas/cuentas/${tarjeta}/ganancias`, { tasa: 9, desde: hoy })).status, 400);
            const c = await nueva('Sin tasa', 1000);
            assert.equal((await api('PUT', `/api/finanzas/cuentas/${c}/ganancias`, { tasa: 0, desde: hoy })).status, 400);
        });

        test('un CDT deja de sumar al vencer', async () => {
            const [r]: any = await pool.query("INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo, fecha_inicio, plazo_dias) VALUES (1, 'CDT', 'cdt', 1000000, ?, 2)", [haceDias(5)]);
            await api('PUT', `/api/finanzas/cuentas/${r.insertId}/ganancias`, { tasa: 9, desde: haceDias(5) });
            assert.equal((await ganancias(r.insertId)).length, 2);
        });

        test('la cuenta Nu pedida se activa solo para esa persona', async () => {
            await pool.query("INSERT INTO usuarios (id, email) VALUES (50, 'di.beltran@udla.edu.co'), (51, 'otra@correo.co')");
            const mia = await nueva('Nu', 500, 50);
            const conEspacio = await nueva(' NU ahorro', 500, 50);
            const parecida = await nueva('Nuevo fondo', 500, 50);
            const ajena = await nueva('Nu', 500, 51);
            await activarCuentaNu(pool);
            const desde = async (id: number) => ((await pool.query("SELECT DATE_FORMAT(ganancias_desde, '%Y-%m-%d') AS d FROM finanzas_cuentas WHERE id = ?", [id])) as any)[0][0].d;
            assert.equal(await desde(mia), '2026-10-30');
            assert.equal(await desde(conEspacio), '2026-10-30');
            assert.equal(await desde(parecida), null);
            assert.equal(await desde(ajena), null);
        });
    });
});
