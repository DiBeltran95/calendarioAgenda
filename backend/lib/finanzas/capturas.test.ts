// Pagos capturados: interpretación de montos y normalización (sin base de
// datos) y, si hay base de pruebas (AGENDA_DB_*), las rutas de punta a punta.

import test, { after, before, describe } from 'node:test';
import assert from 'node:assert/strict';
import Fastify, { type FastifyInstance } from 'fastify';
import jwt from '@fastify/jwt';
import mysql, { type Pool } from 'mysql2/promise';
import { migrarCapturas, montoDesdeTexto, normalizarCaptura, registrarCapturas } from './capturas';
import { alPublicar } from '../tiempoReal';

describe('montos como los escriben iOS y los bancos', () => {
    const casos: Array<[unknown, number | null]> = [
        ['$25.000', 25000],
        ['$ 25.000,50', 25000.5],
        ['COP 1.250.000', 1250000],
        ['25,000.00', 25000],
        ['$12.5', 12.5],
        ['25000', 25000],
        [18900, 18900],
        ['$0', null],
        ['', null],
        ['gratis', null],
        [null, null]
    ];
    for (const [entrada, esperado] of casos) {
        test(`${JSON.stringify(entrada)} → ${esperado}`, () => assert.equal(montoDesdeTexto(entrada), esperado));
    }
});

describe('normalizar', () => {
    test('limpia textos, fija el origen y calcula una huella estable', () => {
        const a = normalizarCaptura({ monto: '$18.900', comercio: '  Éxito   Calle 80 ', tarjeta: 'Visa ••1234', fecha: '2026-10-20T15:04:10Z' }, 'apple_pay')!;
        const b = normalizarCaptura({ monto: 18900, comercio: 'éxito calle 80', tarjeta: 'visa ••1234', fecha: '2026-10-20T15:04:50Z' }, 'apple_pay')!;
        assert.equal(a.comercio, 'Éxito Calle 80');
        assert.equal(a.origen, 'apple_pay');
        assert.equal(a.tipo, 'gasto');
        assert.equal(a.huella, b.huella, 'misma compra en el mismo minuto');
        assert.equal(a.fecha, '2026-10-20 15:04:10');
    });

    test('rechaza lo que no es un pago y corrige fechas absurdas', () => {
        assert.equal(normalizarCaptura({ comercio: 'Sin monto' }, 'android'), null);
        assert.equal(normalizarCaptura('texto', 'android'), null);
        const c = normalizarCaptura({ monto: 1000, fecha: '1990-01-01' }, 'android')!;
        assert.ok(c.fecha.startsWith(String(new Date().getUTCFullYear())));
        assert.equal(normalizarCaptura({ monto: 1000, tipo: 'ingreso', origen: 'raro' }, 'android')!.origen, 'android');
    });
});

const HOST = process.env.AGENDA_DB_HOST;
const omitir = !HOST ? 'sin base de pruebas (define AGENDA_DB_HOST)' : false;

describe('rutas', () => {
    let pool: Pool;
    let app: FastifyInstance;
    let token = '';
    const enVivo: any[] = [];

    before(async () => {
        if (omitir) return;
        pool = mysql.createPool({
            host: HOST,
            port: Number(process.env.AGENDA_DB_PORT || 3306),
            user: process.env.AGENDA_DB_USER || 'root',
            password: process.env.AGENDA_DB_PASS || '',
            database: process.env.AGENDA_DB_NAME || 'agenda_test',
            timezone: 'Z',
            connectionLimit: 5
        } as any);
        for (const t of ['finanzas_capturas', 'finanzas_capturas_claves']) await pool.query(`DROP TABLE IF EXISTS ${t}`);
        await migrarCapturas(pool, { info: () => {}, error: () => {} });
        app = Fastify();
        await app.register(jwt, { secret: 'prueba' });
        app.decorate('authenticate', async (req: any, reply: any) => {
            try {
                await req.jwtVerify();
            } catch (err) {
                reply.send(err);
            }
        });
        registrarCapturas(app, { pool });
        await app.ready();
        token = app.jwt.sign({ id: 7 });
        alPublicar((u, e, d) => e === 'captura' && enVivo.push({ u, d }));
    });

    after(async () => {
        if (omitir) return;
        await app.close();
        await pool.end();
    });

    const api = async (method: string, url: string, body?: unknown, headers: Record<string, string> = { authorization: `Bearer ${token}` }) => {
        const r = await app.inject({ method: method as any, url, payload: body as any, headers });
        return { status: r.statusCode, body: r.json() as any };
    };

    test('Atajo de iPhone con clave personal: guarda una vez y avisa en vivo', { skip: omitir }, async () => {
        const sinClave = await api('POST', '/api/capturas/atajo', { monto: '$18.900' }, {});
        assert.equal(sinClave.status, 401);

        const { body: k } = await api('GET', '/api/capturas/clave');
        assert.match(k.clave, /^[a-f0-9]{40}$/);
        assert.equal((await api('GET', '/api/capturas/clave')).body.clave, k.clave, 'la clave se conserva');

        const pago = { monto: '$ 18.900', comercio: 'Éxito Calle 80', tarjeta: 'Visa Bancolombia', nombre: 'Apple Pay' };
        const r1 = await api('POST', '/api/capturas/atajo', pago, { 'x-clave': k.clave });
        assert.equal(r1.status, 200, JSON.stringify(r1.body));
        assert.equal(r1.body.nueva, true);
        const r2 = await api('POST', '/api/capturas/atajo', pago, { 'x-clave': k.clave });
        assert.equal(r2.body.nueva, false, 'el Atajo repetido no duplica');
        assert.equal(enVivo.length, 1);
        assert.equal(enVivo[0].u, 7);
        assert.equal(enVivo[0].d.captura.monto, 18900);

        const pendientes = await api('GET', '/api/capturas');
        assert.equal(pendientes.body.length, 1);
        assert.equal(pendientes.body[0].origen, 'apple_pay');

        // Clave nueva: la anterior deja de servir.
        const nueva = await api('POST', '/api/capturas/clave');
        assert.notEqual(nueva.body.clave, k.clave);
        assert.equal((await api('POST', '/api/capturas/atajo', pago, { 'x-clave': k.clave })).status, 401);
    });

    test('Android sube un lote; registrar y descartar; preferencias aprendidas', { skip: omitir }, async () => {
        const lote = await api('POST', '/api/capturas', {
            capturas: [
                { monto: '$45.000', comercio: 'Terpel', tarjeta: '*4321', app: 'Bancolombia', fecha: new Date().toISOString() },
                { monto: '$45.000', comercio: 'Terpel', tarjeta: '*4321', app: 'Bancolombia', fecha: new Date().toISOString() },
                { monto: 'nada' }
            ]
        });
        assert.deepEqual(lote.body, { recibidas: 3, nuevas: 1 });
        const [terpel] = (await api('GET', '/api/capturas')).body.filter((c: any) => c.comercio === 'Terpel');
        const reg = await api('PUT', `/api/capturas/${terpel.id}`, { estado: 'registrada', transaccion_id: 99, categoria: 'transporte', cuenta_id: 3 });
        assert.equal(reg.body.estado, 'registrada');
        const pref = await api('GET', '/api/capturas/preferencias');
        assert.deepEqual(pref.body, [{ comercio: 'Terpel', tarjeta: '*4321', categoria: 'transporte', cuenta_id: 3 }]);

        const otro = (await api('GET', '/api/capturas')).body[0];
        assert.equal((await api('PUT', `/api/capturas/${otro.id}`, { estado: 'descartada' })).body.estado, 'descartada');
        assert.equal((await api('GET', '/api/capturas')).body.length, 0);

        const ajeno = await api('PUT', `/api/capturas/${otro.id}`, { estado: 'pendiente' }, { authorization: `Bearer ${app.jwt.sign({ id: 8 })}` });
        assert.equal(ajeno.status, 404, 'no se tocan pagos de otro usuario');
    });
});
