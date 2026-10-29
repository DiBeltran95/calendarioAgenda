// Prueba de extremo a extremo de las rutas de agendamiento contra MariaDB/MySQL
// real. Se ejecuta si hay una base de pruebas (en CI la levanta el workflow):
//   AGENDA_DB_HOST, AGENDA_DB_PORT, AGENDA_DB_USER, AGENDA_DB_PASS, AGENDA_DB_NAME
// ¡Borra y recrea las tablas! Nunca apuntarla a la base de producción.

import test, { after, before } from 'node:test';
import assert from 'node:assert/strict';
import Fastify, { type FastifyInstance } from 'fastify';
import jwt from '@fastify/jwt';
import mysql, { type Pool } from 'mysql2/promise';
import { migrarAgenda, registrarAgenda } from './rutas';
import { ahoraBogota, diaSemana, sumarDias } from './disponibilidad';
import { alPublicar } from '../tiempoReal';

const HOST = process.env.AGENDA_DB_HOST;
const omitir = !HOST ? 'sin base de pruebas (define AGENDA_DB_HOST)' : false;

let pool: Pool;
let app: FastifyInstance;
const whatsapps: { numero: string; texto: string }[] = [];
let tokenDueno = '';
let tokenEmpresa = '';
// Lo que la app recibiría en vivo por /api/tiempo-real.
const enVivo: { usuario: number; tipo: string; estado: string; rol: string; actor: number | null }[] = [];
alPublicar((usuario, evento, d) => {
    if (evento === 'cita') enVivo.push({ usuario, tipo: d.tipo, estado: d.cita.estado, rol: d.cita.rol, actor: d.actor });
});

/** Próximo lunes a más de 2 días (dentro de la ventana de 30 días). */
function proximoLunes(): string {
    let f = sumarDias(ahoraBogota().fecha, 3);
    while (diaSemana(f) !== 1) f = sumarDias(f, 1);
    return f;
}
const LUNES = proximoLunes();

async function api(method: string, url: string, body?: unknown, token?: string) {
    const r = await app.inject({ method: method as any, url, payload: body as any, headers: token ? { authorization: `Bearer ${token}` } : {} });
    return { status: r.statusCode, body: r.json() as any };
}

const ultimoCodigo = () => {
    const m = [...whatsapps].reverse().find((w) => /código de confirmación/.test(w.texto));
    return m?.texto.match(/\*(\d{6})\*/)?.[1] ?? '';
};

before(async () => {
    if (omitir) return;
    pool = mysql.createPool({
        host: HOST,
        port: Number(process.env.AGENDA_DB_PORT || 3306),
        user: process.env.AGENDA_DB_USER || 'root',
        password: process.env.AGENDA_DB_PASS || '',
        database: process.env.AGENDA_DB_NAME || 'agenda_test',
        dateStrings: ['DATE'],
        timezone: 'Z',
        connectionLimit: 10
    });
    await pool.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const t of ['agenda_citas', 'agenda_bloqueos', 'agenda_horarios', 'agenda_servicio_profesional', 'agenda_servicios', 'agenda_profesionales', 'agenda_negocios', 'push_cola', 'eventos', 'usuarios']) {
        await pool.query(`DROP TABLE IF EXISTS ${t}`);
    }
    await pool.query('SET FOREIGN_KEY_CHECKS = 1');
    await pool.query(`CREATE TABLE usuarios (id INT AUTO_INCREMENT PRIMARY KEY, nombre VARCHAR(255) NOT NULL, email VARCHAR(255) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL DEFAULT '', whatsapp VARCHAR(50) NULL, verificado BOOLEAN DEFAULT TRUE)`);
    await pool.query(`CREATE TABLE eventos (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT NOT NULL, titulo VARCHAR(255) NOT NULL, fecha DATE NOT NULL, hora TIME,
        categoria VARCHAR(50), ubicacion VARCHAR(255) DEFAULT '', repeticion VARCHAR(50) DEFAULT 'unica', costo DECIMAL(10,2) DEFAULT 0,
        tipo_transaccion VARCHAR(20) DEFAULT 'ninguno', estado_pago VARCHAR(20) DEFAULT 'pendiente', uuid_confirmacion VARCHAR(36) UNIQUE,
        parent_id INT NULL, frecuencia VARCHAR(50) DEFAULT 'unica', tarjeta_credito_id INT NULL, transaccion_id INT NULL,
        FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE)`);
    await pool.query(`INSERT INTO usuarios (id, nombre, email, whatsapp) VALUES
        (1, 'Laura Gómez', 'laura@test.co', '573001110000'),
        (2, 'Barbería Don Juan', 'juan@test.co', '573002220000'),
        (3, 'Luis Barbero', 'luis@test.co', '573003330000')`);
    await migrarAgenda(pool, { info: () => {}, error: (e) => console.error(e) });

    app = Fastify();
    await app.register(jwt, { secret: 'prueba' });
    app.decorate('authenticate', async (req: any, reply: any) => {
        try {
            await req.jwtVerify();
        } catch (err) {
            reply.send(err);
        }
    });
    registrarAgenda(app, {
        pool,
        webBase: 'https://agendaservi.com',
        enviarWhatsApp: async (numero, texto) => {
            whatsapps.push({ numero, texto });
            return !numero.endsWith('999'); // números que terminan en 999 simulan un envío fallido
        }
    });
    await app.ready();
    tokenDueno = app.jwt.sign({ id: 1 });
    tokenEmpresa = app.jwt.sign({ id: 2 });
});

after(async () => {
    if (omitir) return;
    await app.close();
    await pool.end();
});

test('profesional independiente: crear página, servicio y ver disponibilidad', { skip: omitir }, async () => {
    const libre = await api('GET', '/api/agenda/slug?slug=psicologa-laura', undefined, tokenDueno);
    assert.equal(libre.body.disponible, true);

    const cfg = await api('PUT', '/api/agenda/negocio', { nombre: 'Psicóloga Laura Gómez', slug: 'psicologa-laura', tipo: 'profesional', rubro: 'psicologia', intervalo_min: 30 }, tokenDueno);
    assert.equal(cfg.status, 200, JSON.stringify(cfg.body));
    assert.equal(cfg.body.negocio.enlace, 'https://agendaservi.com/agenda/psicologa-laura');
    assert.equal(cfg.body.profesionales.length, 1);
    assert.equal(cfg.body.profesionales[0].es_dueno, true);
    assert.equal(cfg.body.profesionales[0].horarios.length, 10); // L–V mañana y tarde

    const srv = await api('POST', '/api/agenda/servicios', { nombre: 'Consulta psicológica', duracion_min: 60, precio: 120000 }, tokenDueno);
    assert.equal(srv.status, 200);
    assert.deepEqual(srv.body.servicios[0].profesionales, [cfg.body.profesionales[0].id]);

    const pub = await api('GET', '/api/public/agenda/psicologa-laura');
    assert.equal(pub.body.negocio.nombre, 'Psicóloga Laura Gómez');
    assert.equal(pub.body.servicios[0].precio, 120000);
    assert.equal(pub.body.profesionales[0].whatsapp, undefined); // no expone datos privados

    const disp = await api('GET', `/api/public/agenda/psicologa-laura/disponibilidad?servicio=${srv.body.servicios[0].id}&desde=${LUNES}&dias=7`);
    const lunes = disp.body.dias.find((d: any) => d.fecha === LUNES);
    assert.deepEqual(lunes.turnos.map((t: any) => t.hora), ['08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30', '17:00']);
    const sabado = disp.body.dias.find((d: any) => diaSemana(d.fecha) === 6);
    assert.equal(sabado.turnos.length, 0);
});

test('reserva con código por WhatsApp: aparta el turno, confirma y crea el evento', { skip: omitir }, async () => {
    const pub = await api('GET', '/api/public/agenda/psicologa-laura');
    const servicio = pub.body.servicios[0].id;
    const r = await api('POST', '/api/public/agenda/psicologa-laura/reservas', { servicio_id: servicio, fecha: LUNES, hora: '09:00', nombre: 'Ana Pérez', whatsapp: '57 311 555 6677', nota: 'Primera vez' });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    assert.equal(r.body.estado, 'pendiente');
    assert.equal(r.body.whatsapp, '+57 311 *** 6677');
    assert.ok(r.body.segundos_restantes > 800);
    const codigo = ultimoCodigo();
    assert.match(codigo, /^\d{6}$/);
    assert.equal(whatsapps.at(-1)!.numero, '573115556677');
    assert.match(whatsapps.at(-1)!.texto, new RegExp(`/cita/${r.body.token}\\?c=${codigo}`));

    // El turno pendiente ya no se ofrece a otros.
    const disp = await api('GET', `/api/public/agenda/psicologa-laura/disponibilidad?servicio=${servicio}&desde=${LUNES}&dias=1`);
    assert.ok(!disp.body.dias[0].turnos.some((t: any) => ['08:30', '09:00', '09:30'].includes(t.hora)));

    const mal = await api('POST', `/api/public/agenda/citas/${r.body.token}/confirmar`, { codigo: '000000' === codigo ? '111111' : '000000' });
    assert.equal(mal.status, 400);
    assert.match(mal.body.message, /Te quedan 4 intentos/);

    assert.deepEqual(enVivo.at(-1), { usuario: 1, tipo: 'pendiente', estado: 'pendiente', rol: 'dueno', actor: null });

    const ok = await api('POST', `/api/public/agenda/citas/${r.body.token}/confirmar`, { codigo });
    assert.equal(ok.status, 200, JSON.stringify(ok.body));
    assert.deepEqual(enVivo.at(-1), { usuario: 1, tipo: 'confirmada', estado: 'confirmada', rol: 'dueno', actor: null });
    const antes = enVivo.length;
    assert.equal(ok.body.estado, 'confirmada');
    assert.match(whatsapps.at(-1)!.texto, /Cita confirmada/);

    // Confirmar de nuevo (el enlace del WhatsApp tocado dos veces) no duplica nada.
    const otra = await api('POST', `/api/public/agenda/citas/${r.body.token}/confirmar`, { codigo });
    assert.equal(otra.body.estado, 'confirmada');
    assert.equal(enVivo.length, antes, 'no repite el aviso en vivo');

    const [eventos]: any = await pool.query("SELECT user_id, titulo, categoria, TIME_FORMAT(hora, '%H:%i') AS hora FROM eventos WHERE cita_id IS NOT NULL");
    assert.deepEqual(eventos, [{ user_id: 1, titulo: 'Consulta psicológica · Ana Pérez', categoria: 'cita', hora: '09:00' }]);
    const [cola]: any = await pool.query('SELECT user_id, titulo FROM push_cola');
    assert.equal(cola.length, 1);
    assert.equal(cola[0].user_id, 1);
    assert.match(cola[0].titulo, /Nueva cita: Ana Pérez/);

    const citas = await api('GET', '/api/agenda/citas', undefined, tokenDueno);
    assert.equal(citas.body[0].cliente_whatsapp, '573115556677');
    assert.equal(citas.body[0].estado, 'confirmada');
});

test('nunca dos citas a la misma hora, ni con reservas simultáneas', { skip: omitir }, async () => {
    const servicio = (await api('GET', '/api/public/agenda/psicologa-laura')).body.servicios[0].id;
    const ocupado = await api('POST', '/api/public/agenda/psicologa-laura/reservas', { servicio_id: servicio, fecha: LUNES, hora: '09:00', nombre: 'Otro', whatsapp: '573120000001' });
    assert.equal(ocupado.status, 409);
    assert.equal(ocupado.body.codigo, 'ocupado');

    const intentos = await Promise.all(
        ['573120000002', '573120000003', '573120000004'].map((w) => api('POST', '/api/public/agenda/psicologa-laura/reservas', { servicio_id: servicio, fecha: LUNES, hora: '15:00', nombre: 'Cliente', whatsapp: w }))
    );
    assert.deepEqual(intentos.map((i) => i.status).sort(), [200, 409, 409]);
});

test('el cliente cancela desde su enlace y el turno se libera', { skip: omitir }, async () => {
    const [[cita]]: any = await pool.query("SELECT token FROM agenda_citas WHERE estado = 'confirmada' AND cliente_nombre = 'Ana Pérez'");
    const v = await api('GET', `/api/public/agenda/citas/${cita.token}`);
    assert.equal(v.body.puede_cancelar, true);
    const c = await api('POST', `/api/public/agenda/citas/${cita.token}/cancelar`, { motivo: 'Me surgió un viaje' });
    assert.equal(c.body.estado, 'cancelada');
    assert.deepEqual(enVivo.at(-1), { usuario: 1, tipo: 'cancelada', estado: 'cancelada', rol: 'dueno', actor: null });
    const [eventos]: any = await pool.query('SELECT id FROM eventos WHERE cita_id IS NOT NULL');
    assert.equal(eventos.length, 0);
    const servicio = (await api('GET', '/api/public/agenda/psicologa-laura')).body.servicios[0].id;
    const disp = await api('GET', `/api/public/agenda/psicologa-laura/disponibilidad?servicio=${servicio}&desde=${LUNES}&dias=1`);
    assert.ok(disp.body.dias[0].turnos.some((t: any) => t.hora === '09:00'));
    const [cola]: any = await pool.query("SELECT titulo FROM push_cola WHERE clave LIKE '%cancelada'");
    assert.equal(cola.length, 1);
});

test('si el WhatsApp no sale, la reserva no queda apartando el turno', { skip: omitir }, async () => {
    const servicio = (await api('GET', '/api/public/agenda/psicologa-laura')).body.servicios[0].id;
    const r = await api('POST', '/api/public/agenda/psicologa-laura/reservas', { servicio_id: servicio, fecha: LUNES, hora: '16:00', nombre: 'Sin WhatsApp', whatsapp: '573120000999' });
    assert.equal(r.status, 502);
    const [filas]: any = await pool.query("SELECT id FROM agenda_citas WHERE cliente_nombre = 'Sin WhatsApp'");
    assert.equal(filas.length, 0);
});

test('empresa con equipo: "cualquier profesional" reparte y respeta bloqueos', { skip: omitir }, async () => {
    const neg = await api('PUT', '/api/agenda/negocio', { nombre: 'Barbería Don Juan', slug: 'barberia-don-juan', tipo: 'empresa', rubro: 'barberia', intervalo_min: 15 }, tokenEmpresa);
    assert.equal(neg.status, 200, JSON.stringify(neg.body));
    assert.equal(neg.body.profesionales.length, 0);
    const horario = [1, 2, 3, 4, 5, 6].map((dia) => ({ dia, inicio: '09:00', fin: '19:00' }));
    const luis = await api('POST', '/api/agenda/profesionales', { nombre: 'Luis', cargo: 'Barbero', horarios: horario, vincular: 'luis@test.co' }, tokenEmpresa);
    assert.equal(luis.status, 200, JSON.stringify(luis.body));
    assert.equal(luis.body.profesionales[0].usuario_id, 3);
    const pedro = await api('POST', '/api/agenda/profesionales', { nombre: 'Pedro', whatsapp: '573004440000', horarios: horario }, tokenEmpresa);
    const [idLuis, idPedro] = pedro.body.profesionales.map((p: any) => p.id);
    const srv = await api('POST', '/api/agenda/servicios', { nombre: 'Corte clásico', duracion_min: 30, precio: 35000 }, tokenEmpresa);
    const servicio = srv.body.servicios[0].id;
    assert.deepEqual(srv.body.servicios[0].profesionales.sort(), [idLuis, idPedro].sort());

    const vincularMal = await api('POST', '/api/agenda/profesionales', { nombre: 'Xavier', vincular: 'nadie@test.co' }, tokenEmpresa);
    assert.equal(vincularMal.status, 404);

    const reservar = (w: string) => api('POST', '/api/public/agenda/barberia-don-juan/reservas', { servicio_id: servicio, profesional_id: 0, fecha: LUNES, hora: '10:00', nombre: 'Cliente ' + w, whatsapp: w });
    const a = await reservar('573130000001');
    const b = await reservar('573130000002');
    const c = await reservar('573130000003');
    assert.equal(a.status, 200);
    assert.equal(b.status, 200);
    assert.equal(c.status, 409);
    assert.notEqual(a.body.profesional.nombre, b.body.profesional.nombre);

    // Luis no ve reservas sin confirmar; el dueño sí, en vivo.
    assert.ok(!enVivo.some((e) => e.usuario === 3));
    assert.equal(enVivo.filter((e) => e.usuario === 2 && e.tipo === 'pendiente').length, 2);

    // Confirmar la de Pedro (sin cuenta) le avisa por WhatsApp; la de Luis va a su app.
    for (const r of [a, b]) {
        const [[fila]]: any = await pool.query('SELECT codigo FROM agenda_citas WHERE token = ?', [r.body.token]);
        const ok = await api('POST', `/api/public/agenda/citas/${r.body.token}/confirmar`, { codigo: fila.codigo });
        assert.equal(ok.body.estado, 'confirmada');
    }
    assert.ok(whatsapps.some((w) => w.numero === '573004440000' && /Nueva cita en Barbería Don Juan/.test(w.texto)));
    const [colaLuis]: any = await pool.query('SELECT id FROM push_cola WHERE user_id = 3');
    assert.equal(colaLuis.length, 1);
    const [eventoLuis]: any = await pool.query('SELECT id FROM eventos WHERE user_id = 3 AND cita_id IS NOT NULL');
    assert.equal(eventoLuis.length, 1);
    assert.deepEqual(enVivo.filter((e) => e.usuario === 3).map((e) => [e.tipo, e.rol]), [['confirmada', 'equipo']]);

    // Luis ve la cita como profesional del equipo.
    const deLuis = await api('GET', '/api/agenda/citas', undefined, app.jwt.sign({ id: 3 }));
    assert.equal(deLuis.body.length, 1);
    assert.equal(deLuis.body[0].rol, 'equipo');

    // Bloqueo de todo el equipo ese día: no queda ningún turno.
    await api('POST', '/api/agenda/bloqueos', { fecha: LUNES, motivo: 'Capacitación' }, tokenEmpresa);
    const disp = await api('GET', `/api/public/agenda/barberia-don-juan/disponibilidad?servicio=${servicio}&desde=${LUNES}&dias=1`);
    assert.equal(disp.body.dias[0].turnos.length, 0);

    // No se puede borrar a un profesional con citas próximas.
    const borrar = await api('DELETE', `/api/agenda/profesionales/${idLuis}`, undefined, tokenEmpresa);
    assert.equal(borrar.status, 409);
});

test('el negocio agenda a mano, completa y cancela avisando al cliente', { skip: omitir }, async () => {
    const cfg = await api('GET', '/api/agenda', undefined, tokenDueno);
    const servicio = cfg.body.servicios[0].id;
    const prof = cfg.body.profesionales[0].id;
    const martes = sumarDias(LUNES, 1);
    const nueva = await api('POST', '/api/agenda/citas', { servicio_id: servicio, profesional_id: prof, fecha: martes, hora: '10:00', cliente_nombre: 'Carlos Ruiz', cliente_whatsapp: '573149990000' }, tokenDueno);
    assert.equal(nueva.status, 200, JSON.stringify(nueva.body));
    assert.equal(nueva.body.estado, 'confirmada');
    assert.equal(nueva.body.origen, 'negocio');
    assert.deepEqual(enVivo.at(-1), { usuario: 1, tipo: 'nueva', estado: 'confirmada', rol: 'dueno', actor: 1 });

    const choque = await api('POST', '/api/agenda/citas', { servicio_id: servicio, profesional_id: prof, fecha: martes, hora: '10:30', cliente_nombre: 'Otro' }, tokenDueno);
    assert.equal(choque.status, 409);
    const forzada = await api('POST', '/api/agenda/citas', { servicio_id: servicio, profesional_id: prof, fecha: martes, hora: '10:30', cliente_nombre: 'Otro', forzar: true }, tokenDueno);
    assert.equal(forzada.status, 200);

    const hecha = await api('PUT', `/api/agenda/citas/${nueva.body.id}`, { estado: 'completada' }, tokenDueno);
    assert.equal(hecha.body.estado, 'completada');
    const cancel = await api('PUT', `/api/agenda/citas/${forzada.body.id}`, { estado: 'cancelada', motivo: 'Agenda llena' }, tokenDueno);
    assert.equal(cancel.body.estado, 'cancelada');
    assert.deepEqual(enVivo.at(-1), { usuario: 1, tipo: 'cancelada', estado: 'cancelada', rol: 'dueno', actor: 1 });

    // Otro usuario no puede tocar citas ajenas.
    const ajena = await api('PUT', `/api/agenda/citas/${nueva.body.id}`, { estado: 'cancelada' }, tokenEmpresa);
    assert.equal(ajena.status, 404);
});

test('enlaces únicos y validaciones', { skip: omitir }, async () => {
    const dup = await api('PUT', '/api/agenda/negocio', { nombre: 'Otra', slug: 'psicologa-laura', tipo: 'profesional' }, app.jwt.sign({ id: 3 }));
    assert.equal(dup.status, 409);
    const sugerido = await api('GET', '/api/agenda/slug?slug=psicologa-laura', undefined, app.jwt.sign({ id: 3 }));
    assert.equal(sugerido.body.disponible, false);
    assert.equal(sugerido.body.sugerido, 'psicologa-laura-2');
    const malo = await api('PUT', '/api/agenda/negocio', { nombre: 'X', slug: 'Con Espacios' }, app.jwt.sign({ id: 3 }));
    assert.equal(malo.status, 400);
    const noExiste = await api('GET', '/api/public/agenda/no-existe-esta');
    assert.equal(noExiste.status, 404);
    const sinSesion = await api('GET', '/api/agenda');
    assert.equal(sinSesion.status, 401);
});
