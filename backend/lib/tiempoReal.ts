// Cambios en tiempo real con Server-Sent Events (SSE).
//
// La app abre GET /api/tiempo-real mientras está en pantalla y el servidor le
// envía cada cambio que le interesa (una cita nueva, una cancelación…) en el
// mismo instante en que ocurre. Es HTTP normal (sin WebSockets ni servicios
// externos): una conexión liviana por usuario con un latido cada 25 s para
// que proxies y operadores móviles no la corten. Si se cae, la app reconecta
// y vuelve a sincronizar lo que se haya perdido.

import type { FastifyInstance } from 'fastify';
import type { ServerResponse } from 'http';

const LATIDO_MS = 25_000;
const MAX_CONEXIONES_POR_USUARIO = 6;

interface Conexion {
    res: ServerResponse;
    latido: NodeJS.Timeout;
}

const conexiones = new Map<number, Set<Conexion>>();
const oyentes = new Set<(userId: number, evento: string, datos: unknown) => void>();
let secuencia = 0;

function escribir(res: ServerResponse, evento: string, datos: unknown, id?: number) {
    // Cada campo en su línea; los saltos de línea del JSON no pueden ir sueltos.
    const lineas = [id !== undefined ? `id: ${id}` : null, `event: ${evento}`, `data: ${JSON.stringify(datos)}`].filter(Boolean);
    res.write(`${lineas.join('\n')}\n\n`);
}

/** Envía un evento a todas las conexiones abiertas de un usuario. */
export function publicar(userId: number | null | undefined, evento: string, datos: unknown): number {
    if (!userId) return 0;
    for (const o of oyentes) o(userId, evento, datos);
    const set = conexiones.get(userId);
    if (!set || set.size === 0) return 0;
    const id = ++secuencia;
    for (const c of set) {
        try {
            escribir(c.res, evento, datos, id);
        } catch {
            cerrar(userId, c);
        }
    }
    return set.size;
}

/** Envía el mismo evento a varios usuarios (sin repetir). */
export function publicarA(usuarios: Array<number | null | undefined>, evento: string, datos: unknown) {
    for (const u of new Set(usuarios.filter((x): x is number => !!x))) publicar(u, evento, datos);
}

/** Observa todo lo que se publica (pruebas y métricas). Devuelve cómo dejar de observar. */
export function alPublicar(fn: (userId: number, evento: string, datos: any) => void): () => void {
    oyentes.add(fn);
    return () => oyentes.delete(fn);
}

export function conexionesAbiertas(userId?: number): number {
    if (userId !== undefined) return conexiones.get(userId)?.size ?? 0;
    let n = 0;
    for (const s of conexiones.values()) n += s.size;
    return n;
}

function cerrar(userId: number, c: Conexion) {
    clearInterval(c.latido);
    const set = conexiones.get(userId);
    set?.delete(c);
    if (set && set.size === 0) conexiones.delete(userId);
    try {
        c.res.end();
    } catch {
        /* ya cerrada */
    }
}

export function registrarTiempoReal(server: FastifyInstance) {
    server.get('/api/tiempo-real', { preValidation: [(server as any).authenticate] }, async (request: any, reply: any) => {
        const userId: number = request.user.id;
        const set = conexiones.get(userId) ?? new Set<Conexion>();
        // Límite por usuario: si abre demasiadas, se cierra la más vieja.
        if (set.size >= MAX_CONEXIONES_POR_USUARIO) {
            const vieja = set.values().next().value;
            if (vieja) cerrar(userId, vieja);
        }

        reply.hijack();
        const res: ServerResponse = reply.raw;
        res.writeHead(200, {
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-cache, no-transform',
            Connection: 'keep-alive',
            // Evita que nginx / proxies acumulen los eventos antes de enviarlos.
            'X-Accel-Buffering': 'no',
            'Access-Control-Allow-Origin': '*'
        });
        res.socket?.setKeepAlive?.(true);
        res.socket?.setNoDelay?.(true);
        // Relleno de 2 KB: algunos proxies no reenvían nada hasta juntar un
        // mínimo de bytes. Luego el reintento sugerido y el saludo, que le
        // confirma a la app que el canal funciona de punta a punta.
        res.write(`:${' '.repeat(2048)}\n\n`);
        res.write(`retry: 5000\n\n`);
        escribir(res, 'hola', { latido: LATIDO_MS });

        const c: Conexion = {
            res,
            latido: setInterval(() => {
                try {
                    res.write(`: latido ${Date.now()}\n\n`);
                } catch {
                    cerrar(userId, c);
                }
            }, LATIDO_MS)
        };
        set.add(c);
        conexiones.set(userId, set);
        request.raw.on('close', () => cerrar(userId, c));
    });
}
