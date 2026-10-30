// Pagar eventos: efecto en los saldos (sin base de datos) y, si hay base de
// pruebas (AGENDA_DB_*), las rutas de punta a punta en una base propia, para no
// chocar con las otras pruebas que crean la tabla eventos a su manera.

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import Fastify, { type FastifyInstance } from 'fastify';
import jwt from '@fastify/jwt';
import mysql, { type Pool } from 'mysql2/promise';
import { deltaSaldo, migrarPagosEventos, registrarPagosEventos } from './pagosEventos';

describe('saldos', () => {
    test('sale dinero: baja la cuenta, sube la deuda de una tarjeta', () => {
        assert.equal(deltaSaldo(false, 'ahorros', 100), -100);
        assert.equal(deltaSaldo(false, 'tarjeta_credito', 100), 100);
    });
    test('entra dinero: sube la cuenta, baja la deuda de una tarjeta', () => {
        assert.equal(deltaSaldo(true, 'efectivo', 100), 100);
        assert.equal(deltaSaldo(true, 'tarjeta_credito', 100), -100);
    });
});

const HOST = process.env.AGENDA_DB_HOST;
const BASE = 'agenda_test_pagos';

describe('rutas', { skip: !HOST ? 'sin base de pruebas (define AGENDA_DB_HOST)' : false }, () => {
    let pool: Pool;
    let app: FastifyInstance;
    let token = '';
    let otro = '';
    let ahorros = 0;
    let addi = 0;
    let nequi = 0;

    before(async () => {
        const opciones = {
            host: HOST,
            port: Number(process.env.AGENDA_DB_PORT || 3306),
            user: process.env.AGENDA_DB_USER || 'root',
            password: process.env.AGENDA_DB_PASS || ''
        };
        const admin = await mysql.createConnection(opciones as any);
        await admin.query(`DROP DATABASE IF EXISTS ${BASE}`);
        await admin.query(`CREATE DATABASE ${BASE}`);
        await admin.end();
        pool = mysql.createPool({ ...opciones, database: BASE, timezone: 'Z', connectionLimit: 5 } as any);
        await pool.query(`CREATE TABLE finanzas_cuentas (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, nombre VARCHAR(255) NOT NULL, tipo VARCHAR(50) NOT NULL, saldo DECIMAL(12,2) DEFAULT 0)`);
        await pool.query(`CREATE TABLE finanzas_transacciones (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, cuenta_id INT NULL, tipo VARCHAR(20) NOT NULL, monto DECIMAL(12,2) NOT NULL, descripcion VARCHAR(255) NOT NULL, fecha DATE NOT NULL, categoria VARCHAR(50) DEFAULT 'otros')`);
        await pool.query(`CREATE TABLE finanzas_transferencias (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, cuenta_origen_id INT NOT NULL, cuenta_destino_id INT NOT NULL, monto DECIMAL(12,2) NOT NULL, descripcion VARCHAR(255), fecha DATE NOT NULL)`);
        await pool.query(`CREATE TABLE eventos (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, titulo VARCHAR(255) NOT NULL, fecha DATE NOT NULL, costo DECIMAL(12,2) DEFAULT 0, tipo_transaccion VARCHAR(20) DEFAULT 'ninguno', estado_pago VARCHAR(20) DEFAULT 'pendiente', tarjeta_credito_id INT NULL)`);
        await migrarPagosEventos(pool, { info: () => {}, error: () => {} });
        const cuenta = async (nombre: string, tipo: string, saldo: number) => ((await pool.query('INSERT INTO finanzas_cuentas (user_id, nombre, tipo, saldo) VALUES (1, ?, ?, ?)', [nombre, tipo, saldo])) as any)[0].insertId as number;
        ahorros = await cuenta('Ahorros', 'ahorros', 1000000);
        nequi = await cuenta('Nequi', 'efectivo', 500000);
        addi = await cuenta('Addi', 'tarjeta_credito', 600000);

        app = Fastify();
        await app.register(jwt, { secret: 'prueba' });
        app.decorate('authenticate', async (req: any, reply: any) => {
            try {
                await req.jwtVerify();
            } catch (err) {
                reply.send(err);
            }
        });
        registrarPagosEventos(app, { pool });
        await app.ready();
        token = app.jwt.sign({ id: 1 });
        otro = app.jwt.sign({ id: 2 });
    });

    after(async () => {
        await app?.close();
        await pool?.end();
    });

    const api = async (method: string, url: string, body?: unknown, t = token) => {
        const r = await app.inject({ method: method as any, url, payload: body as any, headers: { authorization: `Bearer ${t}` } });
        return { status: r.statusCode, body: r.json() as any };
    };
    const saldo = async (id: number) => Number(((await pool.query('SELECT saldo FROM finanzas_cuentas WHERE id = ?', [id])) as any)[0][0].saldo);
    const filas = async (t: string) => ((await pool.query(`SELECT COUNT(*) n FROM ${t}`)) as any)[0][0].n as number;
    const evento = async (titulo: string, tipo: string, costo: number, tarjeta: number | null = null) =>
        ((await pool.query("INSERT INTO eventos (user_id, titulo, fecha, costo, tipo_transaccion, tarjeta_credito_id) VALUES (1, ?, '2026-10-18', ?, ?, ?)", [titulo, costo, tipo, tarjeta])) as any)[0].insertId as number;
    const estado = async (id: number) => ((await pool.query('SELECT estado_pago FROM eventos WHERE id = ?', [id])) as any)[0][0].estado_pago as string;

    test('cuota de Addi: baja la deuda y sale de la cuenta, sin contar como gasto nuevo', async () => {
        const id = await evento('Cuota 1 Addi', 'gasto', 200000, addi);
        const gastosAntes = await filas('finanzas_transacciones');
        const r = await api('POST', `/api/events/${id}/pagar`, { cuenta_id: ahorros, fecha: '2026-10-18' });
        assert.equal(r.status, 200, JSON.stringify(r.body));
        assert.equal(await saldo(addi), 400000, 'la deuda baja');
        assert.equal(await saldo(ahorros), 800000, 'el dinero sale de la cuenta elegida');
        assert.equal(await estado(id), 'pagado');
        assert.equal(await filas('finanzas_transacciones'), gastosAntes, 'la compra ya se contó como gasto');

        // Pagar dos veces no descuenta dos veces.
        assert.equal((await api('POST', `/api/events/${id}/pagar`, { cuenta_id: ahorros })).status, 409);
        assert.equal(await saldo(ahorros), 800000);

        // Deshacer deja todo como estaba.
        const d = await api('DELETE', `/api/events/${id}/pago`);
        assert.equal(d.body.devolvio, true);
        assert.equal(await saldo(addi), 600000);
        assert.equal(await saldo(ahorros), 1000000);
        assert.equal(await estado(id), 'pendiente');
    });

    test('una deuda no se paga con ella misma', async () => {
        const id = await evento('Cuota 2 Addi', 'gasto', 100000, addi);
        const r = await api('POST', `/api/events/${id}/pagar`, { cuenta_id: addi });
        assert.equal(r.status, 400);
        assert.equal(await estado(id), 'pendiente');
        assert.equal(await saldo(addi), 600000);
    });

    test('un gasto normal se registra como gasto de la cuenta elegida, con su monto real', async () => {
        const id = await evento('Arriendo', 'gasto', 900000);
        const r = await api('POST', `/api/events/${id}/pagar`, { cuenta_id: nequi, monto: 400000, categoria: 'arriendo' });
        assert.equal(r.status, 200);
        assert.equal(await saldo(nequi), 100000);
        const [[t]]: any = await pool.query('SELECT tipo, monto, categoria, descripcion FROM finanzas_transacciones ORDER BY id DESC LIMIT 1');
        assert.deepEqual([t.tipo, Number(t.monto), t.categoria, t.descripcion], ['gasto', 400000, 'arriendo', 'Arriendo']);
        await api('DELETE', `/api/events/${id}/pago`);
        assert.equal(await saldo(nequi), 500000);
    });

    test('un ingreso esperado entra a la cuenta elegida', async () => {
        const id = await evento('Pago cliente', 'ingreso', 300000);
        await api('POST', `/api/events/${id}/pagar`, { cuenta_id: ahorros });
        assert.equal(await saldo(ahorros), 1300000);
        await api('DELETE', `/api/events/${id}/pago`);
        assert.equal(await saldo(ahorros), 1000000);
    });

    test('solo marcar no mueve dinero', async () => {
        const id = await evento('Ya lo pagué', 'gasto', 50000, addi);
        const r = await api('POST', `/api/events/${id}/pagar`, {});
        assert.equal(r.body.movio_dinero, false);
        assert.equal(await estado(id), 'pagado');
        assert.equal(await saldo(addi), 600000);
        assert.equal((await api('DELETE', `/api/events/${id}/pago`)).body.devolvio, false);
    });

    test('un evento marcado antes de esta función se puede reabrir y pagar bien', async () => {
        const id = await evento('Cuota de octubre', 'gasto', 150000, addi);
        await pool.query("UPDATE eventos SET estado_pago = 'pagado' WHERE id = ?", [id]);
        assert.equal((await api('DELETE', `/api/events/${id}/pago`)).body.devolvio, false);
        assert.equal(await saldo(addi), 600000, 'nada que devolver');
        assert.equal((await api('POST', `/api/events/${id}/pagar`, { cuenta_id: nequi, fecha: '2026-10-18' })).status, 200);
        assert.equal(await saldo(addi), 450000);
        assert.equal(await saldo(nequi), 350000);
        await api('DELETE', `/api/events/${id}/pago`);
    });

    test('nadie paga eventos ajenos ni usa cuentas ajenas', async () => {
        const id = await evento('Privado', 'gasto', 1000);
        assert.equal((await api('POST', `/api/events/${id}/pagar`, { cuenta_id: ahorros }, otro)).status, 404);
        assert.equal((await api('DELETE', `/api/events/${id}/pago`, undefined, otro)).status, 404);
        assert.equal(await estado(id), 'pendiente');
        const [r]: any = await pool.query("INSERT INTO eventos (user_id, titulo, fecha, costo, tipo_transaccion) VALUES (2, 'De otro', '2026-10-18', 10, 'gasto')");
        assert.equal((await api('POST', `/api/events/${r.insertId}/pagar`, { cuenta_id: ahorros }, otro)).status, 404);
        assert.equal(await saldo(ahorros), 1000000);
    });
});
