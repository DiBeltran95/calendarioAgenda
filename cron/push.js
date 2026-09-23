// Notificaciones push a la app móvil mediante Firebase Cloud Messaging (API
// HTTP v1). Sin dependencias: el token OAuth se firma con `crypto` de Node.
//
// Configuración (cualquiera de estas):
//   · Dejar el JSON de la cuenta de servicio de Firebase en esta carpeta, con
//     el nombre con que lo descarga Firebase (agendaservi-firebase-adminsdk-….json)
//     o como firebase-service-account.json. Se detecta solo.
//   · En el .env: FCM_SERVICE_ACCOUNT_FILE=/ruta/al/archivo.json
//   · En el .env: FCM_SERVICE_ACCOUNT=<el JSON tal cual o en base64>
//
// Si no hay configuración el cron sigue funcionando igual (solo WhatsApp) y la
// app mantiene sus avisos locales como respaldo.

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';

// ---------------------------------------------------------------------------
//  Credenciales y token de acceso
// ---------------------------------------------------------------------------

/** Archivo de la cuenta de servicio dejado en la carpeta del cron. */
function buscarArchivoCuenta(dir = __dirname) {
    try {
        const f = fs.readdirSync(dir).filter((n) => /(firebase-adminsdk|service-account).*\.json$/i.test(n)).sort()[0];
        return f ? path.join(dir, f) : null;
    } catch {
        return null;
    }
}

function leerCuentaServicio(env = process.env, dir = __dirname) {
    try {
        let raw = null;
        if (env.FCM_SERVICE_ACCOUNT_FILE) raw = fs.readFileSync(path.resolve(dir, env.FCM_SERVICE_ACCOUNT_FILE), 'utf8');
        else if (env.FCM_SERVICE_ACCOUNT) {
            raw = env.FCM_SERVICE_ACCOUNT.trim();
            if (!raw.startsWith('{')) raw = Buffer.from(raw, 'base64').toString('utf8');
        } else {
            const archivo = buscarArchivoCuenta(dir);
            if (archivo) raw = fs.readFileSync(archivo, 'utf8');
        }
        if (!raw) return null;
        const sa = JSON.parse(raw);
        if (!sa.client_email || !sa.private_key || !sa.project_id) {
            console.error('[Push] La cuenta de servicio no tiene client_email, private_key o project_id.');
            return null;
        }
        return sa;
    } catch (err) {
        console.error('[Push] No se pudo leer la cuenta de servicio de Firebase:', err.message);
        return null;
    }
}

const b64url = (buf) => Buffer.from(buf).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

function firmarJwt(sa, ahoraSeg = Math.floor(Date.now() / 1000)) {
    const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
    const claims = b64url(JSON.stringify({ iss: sa.client_email, scope: SCOPE, aud: TOKEN_URL, iat: ahoraSeg, exp: ahoraSeg + 3600 }));
    const firma = crypto.createSign('RSA-SHA256').update(`${header}.${claims}`).sign(sa.private_key);
    return `${header}.${claims}.${b64url(firma)}`;
}

let cuenta; // undefined = sin leer todavía; null = no configurado
let acceso = null; // { token, expira (ms) }

function configurado() {
    if (cuenta === undefined) {
        cuenta = leerCuentaServicio();
        console.log(cuenta ? `[Push] FCM activo para el proyecto ${cuenta.project_id}.` : '[Push] FCM no configurado: solo se envía WhatsApp.');
    }
    return cuenta !== null;
}

async function tokenAcceso() {
    if (acceso && acceso.expira - Date.now() > 5 * 60 * 1000) return acceso.token;
    const res = await fetch(TOKEN_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: firmarJwt(cuenta) })
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data.access_token) throw new Error(`OAuth ${res.status}: ${data.error_description || data.error || 'sin token'}`);
    acceso = { token: data.access_token, expira: Date.now() + Number(data.expires_in || 3600) * 1000 };
    return acceso.token;
}

// ---------------------------------------------------------------------------
//  Mensajes
// ---------------------------------------------------------------------------

/** Mismo hash (FNV-1a, 31 bits) que `idAviso` de la app: la notificación del
 *  servidor reemplaza a la local con la misma clave en vez de duplicarla. */
function idAviso(clave) {
    let h = 0x811c9dc5;
    for (let i = 0; i < clave.length; i++) {
        h ^= clave.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return h & 0x7fffffff;
}

/** Quita el formato de WhatsApp (*negrita*, _cursiva_). */
function textoPlano(s) {
    return String(s || '').replace(/\*([^*\n]+)\*/g, '$1').replace(/(^|\s)_([^_\n]+)_(?=\s|$|[.,!?])/g, '$1$2');
}

// El payload de FCM admite 4 KB y el texto va dos veces (datos + alerta de
// iOS): se recorta por bytes, no por caracteres (los emojis ocupan 4 bytes).
const MAX_BYTES_CUERPO = 1200;

function recortar(texto, maxBytes = MAX_BYTES_CUERPO) {
    if (Buffer.byteLength(texto, 'utf8') <= maxBytes) return texto;
    const chars = Array.from(texto);
    while (chars.length && Buffer.byteLength(chars.join(''), 'utf8') > maxBytes - 3) chars.pop();
    return chars.join('') + '…';
}

/**
 * Construye el mensaje FCM v1.
 * - Android: mensaje de datos de prioridad alta; la app lo muestra con su
 *   propio canal y estilo (texto expandible) aunque esté cerrada.
 * - iOS: alerta visible (APNs), con `apns-collapse-id` = id de la app.
 */
function construirMensaje(token, { clave, titulo, cuerpo, canal = 'eventos', fecha, ruta, ttlSeg = 3600, tipo = 'aviso' }) {
    const body = recortar(cuerpo);
    const ttl = Math.max(60, Math.floor(ttlSeg));
    return {
        message: {
            token,
            data: { tipo, clave, titulo, cuerpo: body, canal, ruta: ruta ?? (fecha ? `dia:${fecha}` : '') },
            android: { priority: 'HIGH', ttl: `${ttl}s` },
            apns: {
                headers: {
                    'apns-priority': '10',
                    'apns-push-type': 'alert',
                    'apns-collapse-id': String(idAviso(clave)),
                    'apns-expiration': String(Math.floor(Date.now() / 1000) + ttl)
                },
                payload: { aps: { alert: { title: titulo, body }, sound: 'default', 'thread-id': canal } }
            }
        }
    };
}

/**
 * Envía un mensaje. Resultado:
 *   'ok'        → FCM lo aceptó.
 *   'invalido'  → el token ya no existe (app desinstalada, sesión cerrada): borrarlo.
 *   'reintentar'→ fallo temporal o de configuración: se intentará en la siguiente vuelta.
 */
async function enviar(mensaje) {
    if (!configurado()) return 'reintentar';
    try {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`, {
            method: 'POST',
            headers: { Authorization: `Bearer ${await tokenAcceso()}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(mensaje)
        });
        if (res.ok) return 'ok';
        const data = await res.json().catch(() => ({}));
        return clasificarError(res.status, data);
    } catch (err) {
        console.error('[Push] Error de red enviando a FCM:', err.message);
        return 'reintentar';
    }
}

function clasificarError(status, data) {
    const err = (data && data.error) || {};
    const codigos = (err.details || []).map((d) => d.errorCode).filter(Boolean);
    if (status === 401) acceso = null; // token OAuth vencido o revocado
    // Solo se descarta el token cuando FCM dice explícitamente que ya no existe
    // o que es inválido (un 404/403 genérico puede ser un error de configuración).
    if (codigos.includes('UNREGISTERED')) return 'invalido';
    if (status === 400 && /registration token/i.test(err.message || '')) return 'invalido';
    console.error(`[Push] FCM respondió ${status}:`, codigos.join(',') || err.status || '', err.message || '');
    return 'reintentar';
}

/** Segundos que le quedan al día (hora de Bogotá): un resumen que no se pudo
 *  entregar hoy no debe aparecer mañana. */
function segundosHastaFinDelDia(fecha) {
    const fin = new Date(`${fecha}T23:59:59-05:00`).getTime();
    return Math.max(60, (fin - Date.now()) / 1000);
}

module.exports = {
    configurado,
    enviar,
    construirMensaje,
    clasificarError,
    idAviso,
    textoPlano,
    recortar,
    firmarJwt,
    leerCuentaServicio,
    segundosHastaFinDelDia
};
