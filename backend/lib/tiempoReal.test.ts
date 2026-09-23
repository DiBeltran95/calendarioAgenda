// Prueba del canal SSE: conexión autenticada, saludo, eventos por usuario,
// aislamiento entre usuarios y limpieza al desconectar.
import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import Fastify from 'fastify';
import { registrarTiempoReal, publicar, publicarA, conexionesAbiertas } from './tiempoReal';

const server = Fastify();
server.decorate('authenticate', async (request: any, reply: any) => {
    const id = Number(request.headers['x-usuario']);
    if (!id) return reply.code(401).send({ error: 'No autorizado' });
    request.user = { id };
});
registrarTiempoReal(server);

let puerto = 0;
const listo = server.listen({ port: 0, host: '127.0.0.1' }).then(() => {
    puerto = (server.server.address() as any).port;
});
after(() => server.close());

interface Flujo {
    status: number;
    headers: http.IncomingHttpHeaders;
    eventos: Array<{ evento: string; datos: any; id?: string }>;
    esperar: (n: number) => Promise<void>;
    cerrar: () => void;
}

/** Abre el flujo SSE y va interpretando los eventos que llegan. */
async function abrir(usuario?: number): Promise<Flujo> {
    await listo;
    return new Promise((resolve, reject) => {
        const req = http.get(
            { host: '127.0.0.1', port: puerto, path: '/api/tiempo-real', headers: usuario ? { 'x-usuario': String(usuario) } : {} },
            (res) => {
                const eventos: Flujo['eventos'] = [];
                const esperas: Array<() => void> = [];
                let buffer = '';
                res.setEncoding('utf8');
                res.on('data', (t: string) => {
                    buffer += t;
                    let corte;
                    while ((corte = buffer.indexOf('\n\n')) >= 0) {
                        const bloque = buffer.slice(0, corte);
                        buffer = buffer.slice(corte + 2);
                        const campos: Record<string, string> = {};
                        for (const l of bloque.split('\n')) {
                            if (!l || l.startsWith(':')) continue;
                            const i = l.indexOf(':');
                            campos[l.slice(0, i)] = l.slice(i + 1).trimStart();
                        }
                        if (campos.event) eventos.push({ evento: campos.event, datos: JSON.parse(campos.data), id: campos.id });
                    }
                    esperas.splice(0).forEach((f) => f());
                });
                resolve({
                    status: res.statusCode ?? 0,
                    headers: res.headers,
                    eventos,
                    esperar: async (n) => {
                        const limite = Date.now() + 2000;
                        while (eventos.length < n) {
                            if (Date.now() > limite) throw new Error(`Solo llegaron ${eventos.length} eventos de ${n}`);
                            await new Promise<void>((r) => {
                                esperas.push(r);
                                setTimeout(r, 50);
                            });
                        }
                    },
                    cerrar: () => req.destroy()
                });
            }
        );
        req.on('error', reject);
    });
}

const pausa = (ms: number) => new Promise((r) => setTimeout(r, ms));

test('sin sesión responde 401', async () => {
    const f = await abrir();
    assert.equal(f.status, 401);
    f.cerrar();
});

test('saluda con cabeceras SSE y entrega solo los eventos del usuario', async () => {
    const a = await abrir(7);
    const b = await abrir(8);
    assert.equal(a.status, 200);
    assert.match(String(a.headers['content-type']), /text\/event-stream/);
    assert.equal(a.headers['x-accel-buffering'], 'no');
    await a.esperar(1);
    await b.esperar(1);
    assert.equal(a.eventos[0].evento, 'hola');
    assert.equal(conexionesAbiertas(7), 1);

    assert.equal(publicar(7, 'cita', { tipo: 'nueva', cita: { id: 1, nota: 'línea 1\nlínea 2' } }), 1);
    await a.esperar(2);
    assert.deepEqual(a.eventos[1].datos, { tipo: 'nueva', cita: { id: 1, nota: 'línea 1\nlínea 2' } });
    assert.ok(a.eventos[1].id);
    await pausa(80);
    assert.equal(b.eventos.length, 1, 'el usuario 8 no recibe lo del 7');

    publicarA([7, 8, 8, null], 'cita', { tipo: 'cancelada' });
    await a.esperar(3);
    await b.esperar(2);
    await pausa(80);
    assert.equal(b.eventos.length, 2, 'sin duplicados');

    a.cerrar();
    b.cerrar();
    await pausa(120);
    assert.equal(conexionesAbiertas(7), 0);
    assert.equal(publicar(7, 'cita', {}), 0);
});

test('varias pantallas del mismo usuario reciben el evento', async () => {
    const x = await abrir(9);
    const y = await abrir(9);
    await x.esperar(1);
    await y.esperar(1);
    assert.equal(publicar(9, 'cita', { tipo: 'nueva' }), 2);
    await x.esperar(2);
    await y.esperar(2);
    x.cerrar();
    y.cerrar();
    await pausa(120);
    assert.equal(conexionesAbiertas(), 0);
});
