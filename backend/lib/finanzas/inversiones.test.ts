// Inversiones: reglas de saldo y validación (sin base de datos) y, si hay base
// de pruebas (AGENDA_DB_*), las rutas de punta a punta.

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import Fastify, { type FastifyInstance } from 'fastify';
import jwt from '@fastify/jwt';
import mysql, { type Pool } from 'mysql2/promise';
import { ajustarDolares, efectoEnCuenta, fechaValida, migrarInversiones, normalizarMovimiento, registrarInversiones, type MovimientoEntrada } from './inversiones';

describe('efecto en la cuenta', () => {
    test('invertir saca de la cuenta; en tarjeta de crédito aumenta la deuda', () => {
        assert.equal(efectoEnCuenta('aporte', 'ahorros', 100), -100);
        assert.equal(efectoEnCuenta('aporte', 'efectivo', 100), -100);
        assert.equal(efectoEnCuenta('aporte', 'tarjeta_credito', 100), 100);
    });
    test('vender mete en la cuenta; en tarjeta de crédito reduce la deuda', () => {
        for (const tipo of ['retiro', 'venta']) {
            assert.equal(efectoEnCuenta(tipo, 'ahorros', 100), 100);
            assert.equal(efectoEnCuenta(tipo, 'tarjeta_credito', 100), -100);
        }
    });
    test('actualizar el valor no mueve dinero', () => {
        assert.equal(efectoEnCuenta('valoracion', 'ahorros', 100), 0);
    });
});

describe('validación', () => {
    test('fechas', () => {
        assert.ok(fechaValida('2026-10-30'));
        for (const f of ['2026-02-30', '30/10/2026', '2026-13-01', '', null, 20261030]) assert.ok(!fechaValida(f), String(f));
    });
    test('un aporte necesita monto positivo y fecha real', () => {
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', monto: 0, fecha: '2026-10-30' }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', monto: -5, fecha: '2026-10-30' }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', monto: 'mucho', fecha: '2026-10-30' }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', monto: 5, fecha: 'ayer' }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'regalo', monto: 5, fecha: '2026-10-30' }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', monto: 1e13, fecha: '2026-10-30' }), 'string');
    });
    test('una valoración acepta 0 e ignora la cuenta', () => {
        const m = normalizarMovimiento({ tipo: 'valoracion', monto: 0, fecha: '2026-10-30', cuenta_id: 9 });
        assert.notEqual(typeof m, 'string');
        assert.equal((m as any).cuenta_id, null);
    });
});

describe('dólares', () => {
    const mov = (b: object) => normalizarMovimiento({ fecha: '2026-10-30', monto: 400000, ...b }) as MovimientoEntrada;
    test('una compra en dólares necesita los dólares', () => {
        assert.equal(typeof ajustarDolares('dolares', mov({ tipo: 'aporte' })), 'string');
        assert.equal(typeof ajustarDolares('dolares', mov({ tipo: 'aporte', monto_usd: 0 })), 'string');
        assert.equal((ajustarDolares('dolares', mov({ tipo: 'aporte', monto_usd: 100.5 })) as MovimientoEntrada).monto_usd, 100.5);
    });
    test('actualizar el saldo los necesita, aunque sean 0; vender todo no', () => {
        assert.equal(typeof ajustarDolares('dolares', mov({ tipo: 'valoracion' })), 'string');
        assert.notEqual(typeof ajustarDolares('dolares', mov({ tipo: 'valoracion', monto_usd: 0 })), 'string');
        assert.notEqual(typeof ajustarDolares('dolares', mov({ tipo: 'venta' })), 'string');
    });
    test('en otra inversión se ignoran', () => {
        assert.equal((ajustarDolares('ganado', mov({ tipo: 'aporte', monto_usd: 100 })) as MovimientoEntrada).monto_usd, null);
    });
    test('dólares inválidos', () => {
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', fecha: '2026-10-30', monto: 5, monto_usd: -1 }), 'string');
        assert.equal(typeof normalizarMovimiento({ tipo: 'aporte', fecha: '2026-10-30', monto: 5, monto_usd: 'mucho' }), 'string');
    });
});

const HOST = process.env.AGENDA_DB_HOST;
const omitir = !HOST ? 'sin base de pruebas (define AGENDA_DB_HOST)' : false;

describe('rutas', { skip: omitir }, () => {
    let pool: Pool;
    let app: FastifyInstance;
    let token: string;
    let otro: string;
    const uid = 91;
    let ahorros: number;
    let tarjeta: number;

    before(async () => {
        pool = mysql.createPool({
            host: HOST,
            port: Number(process.env.AGENDA_DB_PORT || 3306),
            user: process.env.AGENDA_DB_USER || 'root',
            password: process.env.AGENDA_DB_PASS || '',
            database: process.env.AGENDA_DB_NAME || 'agenda_test',
            timezone: 'Z',
            connectionLimit: 5
        } as any);
        await pool.query(`CREATE TABLE IF NOT EXISTS finanzas_cuentas (
            id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, nombre VARCHAR(255) NOT NULL, tipo VARCHAR(50) NOT NULL, saldo DECIMAL(12,2) DEFAULT 0.00
        )`);
        await migrarInversiones(pool, { info: () => {}, error: () => {} });
        for (const t of ['finanzas_inversiones', 'finanzas_cuentas']) await pool.query(`DELETE FROM ${t} WHERE user_id IN (91, 92)`);
        const [a]: any = await pool.query("INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo) VALUES (91, 'Ahorros', 'ahorros', 10000000)");
        const [b]: any = await pool.query("INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo) VALUES (91, 'Visa', 'tarjeta_credito', 0)");
        ahorros = a.insertId;
        tarjeta = b.insertId;
        app = Fastify();
        await app.register(jwt, { secret: 'prueba' });
        app.decorate('authenticate', async (req: any, reply: any) => {
            try {
                await req.jwtVerify();
            } catch (err) {
                reply.send(err);
            }
        });
        registrarInversiones(app, { pool });
        await app.ready();
        token = app.jwt.sign({ id: uid });
        otro = app.jwt.sign({ id: 92 });
    });

    after(async () => {
        await app.close();
        await pool.end();
    });

    const api = async (method: string, url: string, body?: unknown, t = token) => {
        const r = await app.inject({ method: method as any, url, payload: body as any, headers: { authorization: `Bearer ${t}` } });
        return { status: r.statusCode, body: r.json() as any };
    };
    const saldo = async (id: number) => {
        const [[f]]: any = await pool.query('SELECT saldo FROM finanzas_cuentas WHERE id = ?', [id]);
        return Number(f.saldo);
    };

    test('invertir queda con fecha y monto, y sale de la cuenta', async () => {
        const r = await api('POST', '/api/finanzas/inversiones', { nombre: 'Novillos', tipo: 'ganado', monto: 4000000, fecha: '2026-03-15', cuenta_id: ahorros });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        assert.equal(await saldo(ahorros), 6000000);

        const lista = (await api('GET', '/api/finanzas/inversiones')).body;
        assert.equal(lista.length, 1);
        assert.equal(lista[0].nombre, 'Novillos');
        const m = lista[0].movimientos[0];
        assert.deepEqual([m.tipo, m.monto, m.fecha, m.cuenta_nombre], ['aporte', 4000000, '2026-03-15', 'Ahorros']);
    });

    test('sin cuenta: ya la tenía, no toca ningún saldo', async () => {
        const antes = await saldo(ahorros);
        const r = await api('POST', '/api/finanzas/inversiones', { nombre: 'Casa', tipo: 'inmueble', monto: 200000000, fecha: '2020-01-10' });
        assert.equal(r.status, 200);
        assert.equal(await saldo(ahorros), antes);
    });

    test('venta, corrección y borrado dejan las cuentas cuadradas', async () => {
        const { body: inv } = await api('POST', '/api/finanzas/inversiones', { nombre: 'Moto', tipo: 'vehiculo', monto: 1000000, fecha: '2026-01-01', cuenta_id: ahorros });
        const base = await saldo(ahorros);

        const venta = await api('POST', `/api/finanzas/inversiones/${inv.id}/movimientos`, { tipo: 'venta', monto: 1500000, fecha: '2026-06-01', cuenta_id: ahorros });
        assert.equal(venta.status, 200);
        assert.equal(await saldo(ahorros), base + 1500000);

        // Se equivocó de monto y de cuenta.
        const fix = await api('PUT', `/api/finanzas/inversion-movimientos/${venta.body.id}`, { tipo: 'venta', monto: 1200000, fecha: '2026-06-02', cuenta_id: tarjeta });
        assert.equal(fix.status, 200);
        assert.equal(await saldo(ahorros), base);
        assert.equal(await saldo(tarjeta), -1200000);

        assert.equal((await api('DELETE', `/api/finanzas/inversion-movimientos/${venta.body.id}`)).status, 200);
        assert.equal(await saldo(tarjeta), 0);

        // Borrar la inversión devuelve el aporte a la cuenta.
        assert.equal((await api('DELETE', `/api/finanzas/inversiones/${inv.id}`)).status, 200);
        assert.equal(await saldo(ahorros), base + 1000000);
        const [q]: any = await pool.query('SELECT id FROM finanzas_inversion_movimientos WHERE inversion_id = ?', [inv.id]);
        assert.equal(q.length, 0, 'sus movimientos se van con ella');
    });

    test('una valoración no mueve dinero', async () => {
        const { body: inv } = await api('POST', '/api/finanzas/inversiones', { nombre: 'Lote', tipo: 'inmueble', monto: 500000, fecha: '2026-01-01', cuenta_id: ahorros });
        const base = await saldo(ahorros);
        const r = await api('POST', `/api/finanzas/inversiones/${inv.id}/movimientos`, { tipo: 'valoracion', monto: 900000, fecha: '2026-06-01', cuenta_id: ahorros });
        assert.equal(r.status, 200);
        assert.equal(await saldo(ahorros), base);
    });

    test('una cuenta que no existe no deja nada a medias', async () => {
        const [[{ n: antes }]]: any = await pool.query('SELECT COUNT(*) n FROM finanzas_inversiones WHERE user_id = ?', [uid]);
        const r = await api('POST', '/api/finanzas/inversiones', { nombre: 'Fantasma', tipo: 'otro', monto: 1000, fecha: '2026-01-01', cuenta_id: 999999 });
        assert.equal(r.status, 404);
        const [[{ n }]]: any = await pool.query('SELECT COUNT(*) n FROM finanzas_inversiones WHERE user_id = ?', [uid]);
        assert.equal(n, antes);
    });

    test('nadie ve ni toca las inversiones de otro, ni usa sus cuentas', async () => {
        const { body: inv } = await api('POST', '/api/finanzas/inversiones', { nombre: 'Privada', tipo: 'otro', monto: 1000, fecha: '2026-01-01' });
        assert.ok(!(await api('GET', '/api/finanzas/inversiones', undefined, otro)).body.some((i: any) => i.id === inv.id));
        assert.equal((await api('PUT', `/api/finanzas/inversiones/${inv.id}`, { nombre: 'Robada', tipo: 'otro' }, otro)).status, 404);
        assert.equal((await api('DELETE', `/api/finanzas/inversiones/${inv.id}`, undefined, otro)).status, 404);
        assert.equal((await api('POST', `/api/finanzas/inversiones/${inv.id}/movimientos`, { tipo: 'aporte', monto: 5, fecha: '2026-01-01' }, otro)).status, 404);
        const base = await saldo(ahorros);
        assert.equal((await api('POST', '/api/finanzas/inversiones', { nombre: 'Abuso', tipo: 'otro', monto: 5, fecha: '2026-01-01', cuenta_id: ahorros }, otro)).status, 404);
        assert.equal(await saldo(ahorros), base);
    });

    test('dólares: quedan los comprados y se recuerdan al corregir', async () => {
        const c = await app.inject({
            method: 'POST',
            url: '/api/finanzas/inversiones',
            payload: { nombre: 'ARQ', tipo: 'dolares', monto: 400000, monto_usd: 100, fecha: '2026-10-01', cuenta_id: ahorros },
            headers: { authorization: `Bearer ${token}` }
        });
        assert.equal(c.statusCode, 200, c.body);
        const id = c.json().id;
        const sinDolares = await app.inject({
            method: 'POST',
            url: `/api/finanzas/inversiones/${id}/movimientos`,
            payload: { tipo: 'aporte', monto: 100, fecha: '2026-10-02' },
            headers: { authorization: `Bearer ${token}` }
        });
        assert.equal(sinDolares.statusCode, 400);
        const lista = await app.inject({ method: 'GET', url: '/api/finanzas/inversiones', headers: { authorization: `Bearer ${token}` } });
        const arq = lista.json().find((i: any) => i.id === id);
        assert.equal(arq.tipo, 'dolares');
        assert.equal(arq.movimientos[0].monto_usd, 100);
        const corrige = await app.inject({
            method: 'PUT',
            url: `/api/finanzas/inversion-movimientos/${arq.movimientos[0].id}`,
            payload: { tipo: 'aporte', monto: 410000, monto_usd: 102.5, fecha: '2026-10-01', cuenta_id: ahorros },
            headers: { authorization: `Bearer ${token}` }
        });
        assert.equal(corrige.statusCode, 200, corrige.body);
        const otra = await app.inject({ method: 'GET', url: '/api/finanzas/inversiones', headers: { authorization: `Bearer ${token}` } });
        assert.equal(otra.json().find((i: any) => i.id === id).movimientos[0].monto_usd, 102.5);
        const aOtro = await app.inject({ method: 'PUT', url: `/api/finanzas/inversiones/${id}`, payload: { nombre: 'ARQ', tipo: 'ganado' }, headers: { authorization: `Bearer ${token}` } });
        assert.equal(aOtro.statusCode, 400, 'no se puede convertir en otro tipo');
        await app.inject({ method: 'DELETE', url: `/api/finanzas/inversiones/${id}`, headers: { authorization: `Bearer ${token}` } });
    });
});
