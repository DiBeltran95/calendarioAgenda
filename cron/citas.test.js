// Tareas de agendamiento del cron (sin red ni base de datos).
const test = require('node:test');
const assert = require('node:assert/strict');

const push = require('./push');
const { procesarColaPush, recordarCitas, mensajeRecordatorio, minutosHasta } = require('./citas');

function poolFalso(respuestas) {
    const consultas = [];
    return {
        consultas,
        async query(sql, params = []) {
            consultas.push({ sql, params });
            for (const [prefijo, r] of respuestas) if (sql.trim().startsWith(prefijo)) return typeof r === 'function' ? r(sql, params) : r;
            return [{ affectedRows: 1 }];
        }
    };
}

const silencio = () => {
    const log = console.log;
    console.log = () => {};
    return () => (console.log = log);
};

test('minutos que faltan en hora de Colombia', () => {
    // 10:00 en Bogotá = 15:00 UTC.
    assert.equal(minutosHasta('2026-09-24', '12:00', Date.parse('2026-09-24T15:00:00Z')), 120);
});

test('recordatorio al cliente con enlace para cancelar', () => {
    const m = mensajeRecordatorio({
        fecha: '2026-09-24',
        hora_inicio: '15:30',
        servicio_nombre: 'Corte clásico',
        duracion_min: 45,
        precio: '35000.00',
        cliente_nombre: 'Ana Pérez',
        negocio: 'Barbería Don Juan',
        direccion: 'Cra 7 # 12-30',
        profesional: 'Luis',
        token: 'abc'
    });
    assert.match(m, /Ana, en un rato tienes cita en \*Barbería Don Juan\*/);
    assert.match(m, /jueves 24 de septiembre/);
    assert.match(m, /3:30 p\. m\./);
    assert.match(m, /\$35\.000/);
    assert.match(m, /\/cita\/abc$/);
});

test('cola de avisos: push si hay teléfono, WhatsApp de respaldo si no', async () => {
    const restaurar = silencio();
    const original = { configurado: push.configurado, enviar: push.enviar };
    push.configurado = () => true;
    push.enviar = async () => 'ok';
    const whatsapps = [];
    try {
        const pool = poolFalso([
            ['SELECT q.*', [[
                { id: 1, user_id: 7, clave: 'cita:9:nueva', titulo: 'T', cuerpo: 'C', canal: 'eventos', ruta: 'citas', whatsapp_respaldo: 'respaldo', whatsapp: '573001112233', intentos: 0 },
                { id: 2, user_id: 8, clave: 'cita:10:nueva', titulo: 'T', cuerpo: 'C', canal: 'eventos', ruta: 'citas', whatsapp_respaldo: 'respaldo 2', whatsapp: '573004445566', intentos: 0 }
            ]]],
            ['SELECT id, token FROM dispositivos_push', (_sql, [uid]) => [uid === 7 ? [{ id: 1, token: 'tok' }] : []]]
        ]);
        await procesarColaPush(pool, async (n, t) => { whatsapps.push([n, t]); return true; });
        assert.deepEqual(whatsapps, [['573004445566', 'respaldo 2']]); // solo el que no tiene app
        const procesados = pool.consultas.filter((q) => q.sql.startsWith('UPDATE push_cola SET procesado = 1')).map((q) => q.params[0]);
        assert.deepEqual(procesados, [1, 2]);
    } finally {
        Object.assign(push, original);
        restaurar();
    }
});

test('cola de avisos: un fallo temporal se reintenta sin mandar WhatsApp todavía', async () => {
    const restaurar = silencio();
    const original = { configurado: push.configurado, enviar: push.enviar };
    push.configurado = () => true;
    push.enviar = async () => 'reintentar';
    try {
        const pool = poolFalso([
            ['SELECT q.*', [[{ id: 3, user_id: 7, clave: 'k', titulo: 'T', cuerpo: 'C', canal: 'eventos', ruta: 'citas', whatsapp_respaldo: 'r', whatsapp: '57300', intentos: 0 }]]],
            ['SELECT id, token FROM dispositivos_push', [[{ id: 1, token: 'tok' }]]]
        ]);
        let enviados = 0;
        await procesarColaPush(pool, async () => { enviados++; return true; });
        assert.equal(enviados, 0);
        assert.ok(pool.consultas.some((q) => q.sql.startsWith('UPDATE push_cola SET intentos = intentos + 1')));
    } finally {
        Object.assign(push, original);
        restaurar();
    }
});

test('recordatorio solo entre 2 h y 20 min antes, una sola vez', async () => {
    const restaurar = silencio();
    try {
        const ahora = Date.parse('2026-09-24T15:00:00Z'); // 10:00 en Bogotá
        const cita = (id, hora) => ({ id, token: 't' + id, fecha: '2026-09-24', hora_inicio: hora, servicio_nombre: 'S', duracion_min: 30, precio: 0, cliente_nombre: 'Ana', cliente_whatsapp: '573001112233', negocio: 'N', direccion: null, profesional: 'P' });
        const enviados = [];
        const candados = new Set();
        const pool = poolFalso([
            ['SELECT c.id', [[cita(1, '11:30'), cita(2, '13:00'), cita(3, '10:10')]]],
            ['INSERT INTO notificaciones_enviadas', (_s, [id]) => {
                if (candados.has(id)) throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
                candados.add(id);
                return [{}];
            }]
        ]);
        const wa = async (_n, t) => { enviados.push(t); return true; };
        await recordarCitas(pool, wa, ahora);
        await recordarCitas(pool, wa, ahora);
        assert.equal(enviados.length, 1); // 11:30 (en 90 min); 13:00 aún lejos; 10:10 muy cerca
        assert.match(enviados[0], /t1$/);
    } finally {
        restaurar();
    }
});
