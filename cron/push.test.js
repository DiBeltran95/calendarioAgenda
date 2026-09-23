// Pruebas del canal push (sin red ni base de datos): node --test
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

const push = require('./push');
const { pushExacto, pushPrevio, pushResumen, pushCdt } = require('./index');

test('idAviso coincide con el de la app (FNV-1a de 31 bits)', () => {
    // Valores calculados con `idAviso` de mobile/lib/features/notifications/reminder_planner.dart
    assert.equal(push.idAviso('ev:1:exacto'), 1138420351);
    assert.equal(push.idAviso('ev:123:30m'), 1027306224);
    assert.equal(push.idAviso('resumen:2026-09-23'), 672469992);
    assert.equal(push.idAviso('bienvenida'), 1588623656);
});

test('textoPlano quita el formato de WhatsApp', () => {
    assert.equal(push.textoPlano('Hola *Diego* _tú_'), 'Hola Diego tú');
    assert.equal(push.textoPlano('🕒 *Hora:* 2:30 PM'), '🕒 Hora: 2:30 PM');
});

test('el cuerpo se recorta por bytes para no pasar los 4 KB de FCM', () => {
    const largo = '🎂 Cumpleaños de alguien\n'.repeat(200);
    const r = push.recortar(largo);
    assert.ok(Buffer.byteLength(r, 'utf8') <= 1200);
    assert.ok(r.endsWith('…'));
    assert.equal(push.recortar('corto'), 'corto');
});

test('mensaje FCM: datos para Android y alerta con collapse-id para iOS', () => {
    const m = push.construirMensaje('tok', { clave: 'ev:1:exacto', titulo: 'T', cuerpo: 'C', fecha: '2026-09-23', ttlSeg: 3600 }).message;
    assert.equal(m.token, 'tok');
    assert.deepEqual(m.data, { tipo: 'aviso', clave: 'ev:1:exacto', titulo: 'T', cuerpo: 'C', canal: 'eventos', ruta: 'dia:2026-09-23' });
    assert.equal(m.android.priority, 'HIGH');
    assert.equal(m.android.ttl, '3600s');
    assert.equal(m.android.notification, undefined); // la app muestra la notificación
    assert.equal(m.apns.headers['apns-collapse-id'], '1138420351');
    assert.deepEqual(m.apns.payload.aps.alert, { title: 'T', body: 'C' });
    for (const v of Object.values(m.data)) assert.equal(typeof v, 'string'); // FCM exige strings
});

test('solo se descartan tokens que FCM declara inválidos', () => {
    const silencio = console.error;
    console.error = () => {};
    try {
        assert.equal(push.clasificarError(404, { error: { status: 'NOT_FOUND', details: [{ errorCode: 'UNREGISTERED' }] } }), 'invalido');
        assert.equal(push.clasificarError(400, { error: { message: 'The registration token is not a valid FCM registration token' } }), 'invalido');
        assert.equal(push.clasificarError(404, { error: { status: 'NOT_FOUND' } }), 'reintentar');
        assert.equal(push.clasificarError(401, { error: { details: [{ errorCode: 'THIRD_PARTY_AUTH_ERROR' }] } }), 'reintentar');
        assert.equal(push.clasificarError(503, {}), 'reintentar');
        assert.equal(push.clasificarError(429, { error: { details: [{ errorCode: 'QUOTA_EXCEEDED' }] } }), 'reintentar');
    } finally {
        console.error = silencio;
    }
});

test('el JWT de la cuenta de servicio se firma con RS256 y es verificable', () => {
    const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
    const sa = { client_email: 'cron@proyecto.iam.gserviceaccount.com', private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }), project_id: 'p' };
    const jwt = push.firmarJwt(sa, 1_800_000_000);
    const [h, c, f] = jwt.split('.');
    const claims = JSON.parse(Buffer.from(c, 'base64url').toString());
    assert.equal(claims.iss, sa.client_email);
    assert.equal(claims.scope, 'https://www.googleapis.com/auth/firebase.messaging');
    assert.equal(claims.exp - claims.iat, 3600);
    assert.ok(crypto.createVerify('RSA-SHA256').update(`${h}.${c}`).verify(publicKey, Buffer.from(f, 'base64url')));
});

test('la cuenta de servicio se lee como JSON o base64', () => {
    const json = JSON.stringify({ client_email: 'a@b', private_key: 'k', project_id: 'p' });
    assert.equal(push.leerCuentaServicio({ FCM_SERVICE_ACCOUNT: json }).project_id, 'p');
    assert.equal(push.leerCuentaServicio({ FCM_SERVICE_ACCOUNT: Buffer.from(json).toString('base64') }).project_id, 'p');
    assert.equal(push.leerCuentaServicio({}), null);
});

const reunion = { id: 7, titulo: 'Reunión equipo', fecha: '2026-09-23', hora: '14:30:00', categoria: 'reunion', ubicacion: 'Sala 2', tipo_transaccion: 'gasto', uuid_confirmacion: 'abc' };

test('push de la hora exacta: sin formato ni enlace de confirmación', () => {
    const a = pushExacto(reunion);
    assert.equal(a.clave, 'ev:7:exacto');
    assert.equal(a.titulo, '📅 Reunión equipo');
    assert.match(a.cuerpo, /^Es momento de tu reunión Reunión equipo/);
    assert.match(a.cuerpo, /🕒 Hora: 2:30 PM/);
    assert.match(a.cuerpo, /📍 Lugar: Sala 2/);
    assert.doesNotMatch(a.cuerpo, /confirmar|\*/);
    assert.equal(a.fecha, '2026-09-23');
});

test('push de 30 minutos antes', () => {
    const a = pushPrevio(reunion);
    assert.equal(a.clave, 'ev:7:30m');
    assert.equal(a.titulo, '⏰ En 30 minutos: Reunión equipo');
    assert.equal(a.cuerpo, 'Tu reunión comienza a las 2:30 PM · Sala 2.');
});

test('push del resumen de las 7:00', () => {
    const a = pushResumen({
        todayStr: '2026-11-13',
        bdays: [{ nombre: 'Mamá' }],
        recordatorios: [{ titulo: 'Arriendo', categoria: 'arriendo', costo: '1200000.00' }],
        creditos: [{ titulo: 'Cuota 1/3: Celular', costo: '300000.00' }],
        todayHoliday: null,
        puente: { holiday: { localName: 'Independencia de Cartagena' } }
    });
    assert.equal(a.clave, 'resumen:2026-11-13');
    assert.equal(a.canal, 'resumen');
    assert.equal(a.titulo, '☀️ Buenos días · 3 pendientes hoy');
    assert.deepEqual(a.cuerpo.split('\n'), [
        '🎂 Cumpleaños de Mamá',
        '🏠 Arriendo · $1.200.000',
        '💳 Cuota 1/3: Celular · $300.000',
        '🏖️ Puente festivo: el lunes es Independencia de Cartagena'
    ]);
});

test('push de CDT que vence', () => {
    const a = pushCdt({ id: 3, nombre: 'Bancolombia', saldo: '5000000', interes_tasa: '11.00', plazo_dias: 90 }, '2026-09-25');
    assert.equal(a.clave, 'cdt:3:2026-09-25');
    assert.match(a.titulo, /Bancolombia vence hoy/);
});

test('un candado por teléfono: reintenta solo el que falló y borra tokens inválidos', async () => {
    const { enviarPushUsuario } = require('./index');
    const candados = new Set();
    const borrados = [];
    const confirmados = [];
    const conn = {
        async query(sql, params = []) {
            if (sql.startsWith('SELECT id, token FROM dispositivos_push')) {
                assert.match(sql, /AND aviso_30m = 1/);
                return [[{ id: 1, token: 'ok' }, { id: 2, token: 'caido' }, { id: 3, token: 'viejo' }]];
            }
            if (sql.startsWith('INSERT INTO notificaciones_enviadas')) {
                const k = params.join('|');
                if (candados.has(k)) throw Object.assign(new Error('dup'), { code: 'ER_DUP_ENTRY' });
                candados.add(k);
                return [{}];
            }
            if (sql.startsWith('DELETE FROM notificaciones_enviadas')) { candados.delete(params.join('|')); return [{}]; }
            if (sql.startsWith('UPDATE dispositivos_push')) { confirmados.push(params[0]); return [{}]; }
            if (sql.startsWith('DELETE FROM dispositivos_push')) { borrados.push(params[0]); return [{}]; }
            throw new Error('SQL inesperado: ' + sql);
        }
    };
    const original = { configurado: push.configurado, enviar: push.enviar };
    const enviados = [];
    push.configurado = () => true;
    push.enviar = async (m) => {
        enviados.push(m.message.token);
        return { ok: 'ok', caido: 'reintentar', viejo: 'invalido' }[m.message.token];
    };
    const log = console.log;
    console.log = () => {};
    try {
        const args = { userId: 9, tipo: 'push_evento_30m', refId: 7, fechaRef: '2026-09-23T19:00:00.000Z', aviso: pushPrevio(reunion), filtro: 'AND aviso_30m = 1' };
        assert.equal(await enviarPushUsuario(conn, args), false); // queda uno por reintentar
        assert.deepEqual(confirmados, [1]);
        assert.deepEqual(borrados, [3]);
        assert.deepEqual([...candados], ['push_evento_30m|7|2026-09-23T19:00:00.000Z#1']);

        // Siguiente vuelta: el teléfono 1 no recibe un duplicado.
        enviados.length = 0;
        await enviarPushUsuario(conn, args);
        assert.deepEqual(enviados, ['caido', 'viejo']);
    } finally {
        Object.assign(push, original);
        console.log = log;
    }
});
