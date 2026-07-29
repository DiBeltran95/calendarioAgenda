// Pruebas de la cola de sincronización sin conexión.
//
// Se ejecuta con `npm run test:outbox`. Simula localStorage y fetch, porque lo
// que se valida aquí es el protocolo de reenvío, no el navegador.

declare const globalThis: any;
declare const process: { exit(code: number): never };

// --- Dobles de entorno, antes de importar el módulo bajo prueba ---
const almacen = new Map<string, string>();
globalThis.localStorage = {
  getItem: (k: string) => (almacen.has(k) ? almacen.get(k)! : null),
  setItem: (k: string, v: string) => void almacen.set(k, v),
  removeItem: (k: string) => void almacen.delete(k),
  clear: () => almacen.clear(),
  key: (i: number) => Array.from(almacen.keys())[i] ?? null,
  get length() {
    return almacen.size;
  }
};
globalThis.window = { addEventListener() {} };
globalThis.document = { addEventListener() {}, visibilityState: 'visible' };
// En Node 22 `navigator` ya existe y es de sólo lectura: se redefine.
Object.defineProperty(globalThis, 'navigator', {
  value: { onLine: true },
  configurable: true,
  writable: true
});

type Respuesta = { ok: boolean; status: number; body?: any } | 'red-caida';
let guion: Respuesta[] = [];
const llamadas: Array<{ metodo: string; url: string; body: any }> = [];

globalThis.fetch = async (url: string, init: any = {}) => {
  llamadas.push({
    metodo: init.method || 'GET',
    url,
    body: init.body ? JSON.parse(init.body) : undefined
  });
  const r = guion.shift() ?? { ok: true, status: 200, body: {} };
  if (r === 'red-caida') throw new TypeError('Failed to fetch');
  return {
    ok: r.ok,
    status: r.status,
    json: async () => r.body ?? {}
  };
};

const { encolar, sincronizar, pendientes, descartadas, nuevoIdTemporal, esIdTemporal } =
  await import('./outbox');
const { get } = await import('svelte/store');

let pass = 0,
  fail = 0;
function check(nombre: string, actual: any, esperado: any) {
  const ok = JSON.stringify(actual) === JSON.stringify(esperado);
  if (ok) {
    pass++;
    console.log(`  ok   ${nombre}`);
  } else {
    fail++;
    console.log(
      `  FAIL ${nombre}\n       esperado: ${JSON.stringify(esperado)}\n       real:     ${JSON.stringify(actual)}`
    );
  }
}

function reiniciar() {
  almacen.clear();
  llamadas.length = 0;
  guion = [];
  pendientes.set([]);
  descartadas.set([]);
}

console.log('\n1) Ids temporales');
{
  const id = nuevoIdTemporal();
  check('se reconocen como temporales', esIdTemporal(id), true);
  check('un id de servidor no lo es', esIdTemporal(123), false);
  check('dos ids seguidos no colisionan', nuevoIdTemporal() !== nuevoIdTemporal(), true);
}

console.log('\n2) La cola persiste y respeta el orden');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/notes', body: { c: 1 }, entidad: 'notas' });
  encolar({ metodo: 'POST', path: '/api/notes', body: { c: 2 }, entidad: 'notas' });
  check('quedan dos pendientes', get(pendientes).length, 2);
  check('se guardan en localStorage', almacen.has('outbox_v1'), true);
  check('en orden de llegada', get(pendientes).map((o: any) => o.body.c), [1, 2]);
}

console.log('\n3) Sincronización correcta');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/notes', body: { c: 1 }, entidad: 'notas' });
  encolar({ metodo: 'DELETE', path: '/api/notes/9', entidad: 'notas' });
  guion = [
    { ok: true, status: 200, body: { id: 55 } },
    { ok: true, status: 200, body: {} }
  ];
  const r = await sincronizar();
  check('se envían las dos', r.enviadas, 2);
  check('la cola queda vacía', get(pendientes).length, 0);
  check('respetó el orden', llamadas.map((l) => l.metodo), ['POST', 'DELETE']);
}

console.log('\n4) Id temporal reemplazado por el real');
{
  reiniciar();
  const tmp = 'tmp_abc';
  encolar({ metodo: 'POST', path: '/api/events', body: { t: 'x' }, entidad: 'eventos', tempId: tmp });
  // Borrar el evento recién creado, todavía sin id de servidor.
  encolar({ metodo: 'DELETE', path: `/api/events/${tmp}`, entidad: 'eventos' });
  // Y una transacción que lo referencia en el cuerpo.
  encolar({ metodo: 'POST', path: '/api/tx', body: { evento_id: tmp }, entidad: 'tx' });

  guion = [
    { ok: true, status: 200, body: { id: 77 } },
    { ok: true, status: 200, body: {} },
    { ok: true, status: 200, body: { id: 78 } }
  ];
  await sincronizar();

  check('la ruta del DELETE usa el id real', llamadas[1].url.endsWith('/api/events/77'), true);
  check('el cuerpo referencia el id real', llamadas[2].body.evento_id, 77);
}

console.log('\n5) Si se cae la red, la cola se conserva en orden');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/a', body: {}, entidad: 'a' });
  encolar({ metodo: 'POST', path: '/api/b', body: {}, entidad: 'b' });
  guion = [{ ok: true, status: 200, body: {} }, 'red-caida'];
  const r = await sincronizar();
  check('sólo se envió la primera', r.enviadas, 1);
  check('la segunda sigue pendiente', get(pendientes).length, 1);
  check('marcada como interrumpida', r.interrumpida, true);
  check('la que queda es la correcta', get(pendientes)[0].path, '/api/b');
}

console.log('\n6) Un rechazo del servidor no bloquea la cola para siempre');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/malo', body: {}, entidad: 'x' });
  encolar({ metodo: 'POST', path: '/api/bueno', body: {}, entidad: 'x' });
  guion = [
    { ok: false, status: 400, body: { message: 'Fecha inválida' } },
    { ok: true, status: 200, body: {} }
  ];
  const r = await sincronizar();
  check('la inválida se descarta', r.descartadas, 1);
  check('la siguiente sí se envía', r.enviadas, 1);
  check('la cola queda vacía', get(pendientes).length, 0);
  check('se informa el motivo', get(descartadas)[0].motivo, 'Fecha inválida');
}

console.log('\n7) Un 401 detiene la sincronización sin descartar nada');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/a', body: {}, entidad: 'a' });
  guion = [{ ok: false, status: 401, body: {} }];
  const r = await sincronizar();
  check('no se descarta el cambio', r.descartadas, 0);
  check('sigue pendiente', get(pendientes).length, 1);
  check('se detiene', r.interrumpida, true);
}

console.log('\n8) Un 500 se reintenta más tarde');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/a', body: {}, entidad: 'a' });
  guion = [{ ok: false, status: 500, body: {} }];
  await sincronizar();
  check('sigue en cola', get(pendientes).length, 1);
  check('cuenta el intento', get(pendientes)[0].intentos, 1);

  guion = [{ ok: true, status: 200, body: {} }];
  const r2 = await sincronizar();
  check('al reintentar se envía', r2.enviadas, 1);
  check('y la cola se vacía', get(pendientes).length, 0);
}

console.log('\n9) La cola sobrevive a un reinicio de la app');
{
  reiniciar();
  encolar({ metodo: 'POST', path: '/api/a', body: { v: 1 }, entidad: 'a' });
  const crudo = almacen.get('outbox_v1')!;
  pendientes.set([]); // simula recarga: el store en memoria se pierde
  const recuperada = JSON.parse(crudo);
  check('lo persistido conserva la operación', recuperada.length, 1);
  check('con su cuerpo intacto', recuperada[0].body.v, 1);
}

console.log(`\n${pass} pasaron, ${fail} fallaron\n`);
process.exit(fail > 0 ? 1 : 0);
