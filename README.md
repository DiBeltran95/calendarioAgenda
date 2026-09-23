# Calendario SaaS (Calendario Agenda)

Aplicación web (y APK Android) de agenda personal: calendario con festivos de Colombia, eventos con recordatorios por WhatsApp, ciclo menstrual, notas, hábitos, cumpleaños y un módulo completo de finanzas personales. Moderniza la versión original manteniendo el estilo visual tipo WhatsApp Dark Theme.

El proyecto está dividido en **tres partes independientes**, cada una alojada en una cuenta distinta de [AlwaysData](https://www.alwaysdata.com/).

---

## ☁️ Alojamiento en AlwaysData

| Parte | Carpeta | Cuenta AlwaysData (usuario) | URL / dominio |
|---|---|---|---|
| **Frontend** | [`frontend/`](frontend/) | `di.beltran@udla.edu.co` | [dibeltran.alwaysdata.net](http://dibeltran.alwaysdata.net/) |
| **Backend (API)** | [`backend/`](backend/) | `dibeltran05@gmail.com` | [dibeltran05.alwaysdata.net](http://dibeltran05.alwaysdata.net/) |
| **Cron (recordatorios WhatsApp)** | [`cron/`](cron/) | `soportediego.comfaca@gmail.com` | [comfaca.alwaysdata.net](http://comfaca.alwaysdata.net/) |

```
 Navegador / APK
       │
       ▼
 FRONTEND  ── dibeltran.alwaysdata.net      (Svelte build estático + .htaccess SPA)
       │  fetch  VITE_API_BASE_URL
       ▼
 BACKEND   ── dibeltran05.alwaysdata.net    (Fastify API REST + JWT)
       │
       ▼
 MySQL (AlwaysData)  ◄──  CRON ── comfaca.alwaysdata.net  (Node + PM2)
                               │
                               ▼
                         API WhatsApp (envío de recordatorios)
```

---

## 🧱 Tecnologías

- **Frontend**: Svelte 5 + TypeScript + Vite + TailwindCSS. Capacitor para generar el APK Android. Soporte offline (outbox de peticiones pendientes).
- **Backend**: Node.js + Fastify 5 + TypeScript (`tsx`), autenticación JWT, MySQL (`mysql2`), reportes Excel (`exceljs`).
- **Cron**: Node.js (CommonJS) gestionado con PM2 (`ecosystem.config.cjs`). Lee eventos de MySQL y envía recordatorios por WhatsApp (hora exacta y aviso previo, zona horaria Colombia).
- **Base de datos**: MySQL en AlwaysData.

---

## 📁 Estructura

```
calendario-saas/
├── frontend/   # SPA Svelte (web + APK)
│   ├── src/            # App, Dashboard, Landing, Login, Register, componentes y lib/
│   ├── public/.htaccess# Reescritura SPA para Apache (AlwaysData)
│   └── capacitor.config.ts
├── backend/    # API REST Fastify
│   ├── server.ts       # Rutas /api/* (auth, eventos, ciclos, notas, hábitos, cumpleaños, finanzas…)
│   ├── setupDB.ts      # Crea las tablas en MySQL
│   └── lib/            # Utilidades de fechas, validación de ciclo, Excel
├── cron/       # Servicio de recordatorios
│   ├── index.js
│   └── ecosystem.config.cjs
└── mobile/     # App Flutter (iOS / Android / web) — cliente del backend con caché SQLite y avisos locales
```

---

## ⚙️ Variables de entorno

Los archivos `.env` **no se suben al repositorio** (ver `.gitignore`). Crea uno en cada carpeta:

**`backend/.env`**
```env
DB_HOST=
DB_USER=
DB_PASS=
DB_NAME=
JWT_SECRET=
PORT=3000
```

**`cron/.env`**
```env
DB_HOST=
DB_USER=
DB_PASS=
DB_NAME=
WHATSAPP_API_KEY=
# Opcional: notificaciones push. Si el JSON de Firebase está en la carpeta
# cron/ no hace falta esta línea (ver "Notificaciones push").
# FCM_SERVICE_ACCOUNT_FILE=/home/<cuenta>/firebase-service-account.json
```

**`frontend/.env`** / **`frontend/.env.production`** (ver `frontend/.env.example`)
```env
VITE_API_BASE_URL=https://dibeltran05.alwaysdata.net
```
`frontend/.env.apk` se usa para el build del APK (`VITE_APK=true`).

---

## 🚀 Desarrollo local

### Backend
```bash
cd backend
npm install
npm run dev        # http://localhost:3000 (hot-reload con tsx watch)
```
Crear tablas (primera vez): `npx tsx setupDB.ts`

### Frontend
```bash
cd frontend
npm install
npm run dev        # http://localhost:5173
```

### Cron
```bash
cd cron
npm install
npm start
```

### Tests
```bash
cd backend && npm test      # validación de ciclos
cd frontend && npm test     # ciclo menstrual + outbox offline
cd cron && npm test         # mensajes push y candados por teléfono
cd mobile && flutter test   # app móvil contra un backend falso
```

---

## 📦 Despliegue en AlwaysData

### Frontend → `dibeltran.alwaysdata.net` (cuenta `di.beltran@udla.edu.co`)
1. `cd frontend && npm run build` (usa `.env.production`).
2. Subir el contenido de `frontend/dist/` (incluye `.htaccess`) a la raíz del sitio estático.

**APK Android:** `npm run apk` y luego `npm run cap:open` para compilar en Android Studio.

### Backend → `dibeltran05.alwaysdata.net` (cuenta `dibeltran05@gmail.com`)
1. Subir la carpeta `backend/` (sin `node_modules`) y crear `backend/.env`.
2. `npm install` en el servidor.
3. Configurar el sitio como **Node.js** con comando `npm start` (o `npx tsx server.ts`) escuchando en el puerto/host que asigna AlwaysData.
4. Verificar: `https://dibeltran05.alwaysdata.net/api/health`.

### Cron → `comfaca.alwaysdata.net` (cuenta `soportediego.comfaca@gmail.com`)
1. Subir la carpeta `cron/` y crear `cron/.env`.
2. `npm install`.
3. Ejecutar como servicio: `npx pm2 start ecosystem.config.cjs` (logs en `cron/logs/`).

---

## 📱 App móvil (`mobile/`)

App Flutter con los calendarios de **eventos**, **ciclo menstrual** y **control financiero**, construida con **Flutter + Riverpod + Drift (SQLite)**. Detalles en [`mobile/README.md`](mobile/README.md).

- Usa el **mismo backend** que la web (`dibeltran05.alwaysdata.net`) sin modificarlo.
- Cada usuario inicia sesión y ve los mismos datos que en agendaservi.com.
- Los eventos que registra los avisa el **cron** por WhatsApp **y por push al teléfono**, aunque la app esté cerrada o el evento se haya creado en la web (ver abajo).
- Guarda una caché en SQLite para abrir al instante y funcionar sin conexión.

**Generar el `.ipa` (GitHub Actions):** el workflow [`.github/workflows/mobile.yml`](.github/workflows/mobile.yml) corre en cada push a `main` que modifique `mobile/`, o a mano desde **Actions → "Mobile (Flutter) · IPA y APK" → Run workflow**. Hace tres cosas:

1. Corre el analizador y las pruebas.
2. Compila el **APK de Android** y lo deja como artefacto.
3. Compila el **`.ipa` de iOS sin firmar** y lo deja como artefacto y en una *release* `mobile-build-N`. Para instalarlo en el iPhone hay que firmarlo con tu Apple ID desde Sideloadly o AltStore.

Desarrollo local:
```bash
cd mobile && flutter pub get && flutter run
```

---

## 🔔 Notificaciones push (app móvil)

El **cron** envía cada aviso por dos canales independientes, a la misma hora:
- por **WhatsApp**, como siempre;
- por **push** a cada teléfono con la app (Firebase Cloud Messaging).

Por eso el teléfono avisa aunque el evento se haya creado desde la web y la app lleve días sin abrirse. La app no consulta el servidor constantemente.

```
app ── POST /api/dispositivos (token FCM + preferencias) ──► backend ──► tabla dispositivos_push
                                                                               │
cron (cada 30 s, timers exactos) ── WhatsApp ──► usuario                       │
                                 └─ FCM v1 ────► teléfono(s) ◄─────────────────┘
```

**Qué se envía y cuándo:**
- Eventos con hora: 30 minutos antes (si el usuario lo tiene activo) y a la hora exacta.
- Resumen de las 7:00 a. m.
- Vencimiento de CDT.

**Cómo se mantiene fiable:**
- Cada teléfono tiene su propio candado en `notificaciones_enviadas`: un fallo temporal se reintenta sin duplicar el aviso en los demás.
- Los tokens que FCM declara inválidos se borran solos.
- Los teléfonos que no abren la app en 120 días se eliminan.
- Al registrarse un teléfono, el cron le envía una notificación de **bienvenida**. Solo cuando FCM la acepta, la app apaga sus avisos locales. Mientras tanto, o si no hay push, la app programa avisos locales y se refresca en segundo plano (WorkManager en Android, Background App Refresh en iOS).
- Sin la configuración de Firebase todo sigue funcionando como antes: WhatsApp más avisos locales.

### Activar el push (una sola vez)
1. Crear un proyecto en [Firebase](https://console.firebase.google.com) y dentro de él:
   - una app **Android** con el paquete `com.agendaservi.agendaservi`;
   - una app **iOS** con el bundle `com.agendaservi.agendaservi`.
2. **Cron:**
   1. En *Configuración del proyecto → Cuentas de servicio*, generar una clave privada (JSON).
   2. Dejar ese archivo, con el nombre que trae (`agendaservi-firebase-adminsdk-….json`), dentro de la carpeta `cron/` del servidor. Se detecta solo; `.gitignore` evita que se suba al repositorio. También se puede indicar la ruta con `FCM_SERVICE_ACCOUNT_FILE` en `cron/.env`.
   3. Reiniciar con `npx pm2 restart ecosystem.config.cjs`. El log dirá `[Push] FCM activo para el proyecto …`.
3. **App:** copiar `mobile/firebase.example.json` y llenarlo con los valores de las apps de Firebase (`apiKey`, `appId`, `messagingSenderId`, `projectId`).
   - En GitHub, pegar ese JSON en el secreto `FIREBASE_DART_DEFINES` (*Settings → Secrets and variables → Actions*).
   - En local: `flutter run --dart-define-from-file=firebase.json`.
4. **iPhone:** Apple solo permite push con una cuenta del **Apple Developer Program** (de pago).
   1. Crear una llave APNs (.p8) y subirla en Firebase → *Cloud Messaging → Apple app configuration*.
   2. Firmar la app con esa cuenta.
   - Con un Apple ID gratuito (Sideloadly/AltStore) iOS no entrega push. La app lo detecta y usa sus avisos locales más el refresco en segundo plano, y el WhatsApp llega siempre.

El backend crea la tabla `dispositivos_push` al arrancar (el cron también, si arranca primero). No hace falta ninguna migración manual.

---

## 📅 Agendamiento de citas

Cada usuario puede publicar su **página de citas**: `agendaservi.com/agenda/<enlace>`. Cualquier persona agenda ahí sin crear cuenta. Si tiene la app instalada, el enlace abre la reserva dentro de la app.

**Referencias de diseño:** Cal.com y Calendly (enlace, QR, "añadir a calendario") y Fresha / Booksy (servicios, profesionales, horas por franja, barra inferior fija).

**Tipos de página:**
- **Profesional independiente** (psicólogos, entrenadores, consultores…): el dueño atiende con su propio horario.
- **Negocio con equipo** (peluquerías, spas, clínicas…): cada profesional tiene su horario y sus servicios. Puede ser:
  - una **cuenta de Agendaservi vinculada por correo**: recibe sus citas en la app y se cruzan con su calendario;
  - **solo un número de WhatsApp**: le avisamos por WhatsApp.

**Servicios:** cada uno tiene nombre, duración y precio. Esa duración es la que se marca como ocupada en el calendario público.

**Flujo del cliente:** servicio → profesional ("cualquiera" primero) → fecha y hora → nombre y WhatsApp → **código de 6 dígitos por WhatsApp** (o tocar el enlace del mensaje) → confirmada. Después puede añadirla a Google Calendar, Outlook o Apple (.ics), o cancelarla desde su enlace.

**Reglas:**
- **Nunca hay dobles reservas.** La reserva bloquea al profesional (`SELECT … FOR UPDATE` con `READ COMMITTED`) y recalcula la disponibilidad dentro de la transacción.
- **Qué ocupa el horario:** citas confirmadas, reservas pendientes (15 min), bloqueos (vacaciones, horas libres) y, si el negocio lo activa, los eventos con hora del calendario personal del profesional (1 h cada uno).
- **Qué define el negocio:** anticipación mínima, hasta cuántos días adelante se puede agendar, intervalo de los turnos (10–60 min) y pausar la página.

**Avisos:**
- **Cliente:** código y confirmación por WhatsApp, recordatorio **2 h antes** y aviso si el negocio cancela.
- **Dueño y profesionales con la app:** notificación en la app al instante por cada cita nueva o cancelada (`push_cola` → cron → FCM). Si no tienen push, les llega por WhatsApp.
- **Calendario del profesional:** la cita confirmada aparece como **evento**, así le llegan los recordatorios de siempre.

**En vivo (sin refrescar):** con la app abierta, cada cita nueva, confirmada o cancelada aparece **al instante** en la pestaña Citas, con un aviso dentro de la app.
- **Cómo:** `GET /api/tiempo-real` es un canal **SSE** (Server-Sent Events, HTTP normal). No usa servicios externos ni tiene costo. El servidor manda un latido de pocos bytes cada 25 s (`backend/lib/tiempoReal.ts`).
- **Quién recibe cada cambio:** el dueño, el profesional del equipo con cuenta (solo citas confirmadas) y el cliente que reservó desde la app.
- **Si se cae la red:** la app reconecta con espera creciente y vuelve a pedir la agenda.
- **Si el hosting bloquea conexiones largas:** la app pasa sola a consultar cada 20 s.
- **En segundo plano:** la app suelta la conexión y avisan las notificaciones push.
- **Sin avisos repetidos:** un push de una cita que ya se anunció en vivo no se repite. Lo que hace uno mismo no se le anuncia.
- **Límite:** el canal vive en la memoria del proceso de Node. Si algún día el backend corre en varios procesos, hará falta un bus compartido (por ejemplo Redis pub/sub).

**Rutas nuevas:**

| Pública (sin sesión) | Con sesión |
|---|---|
| `GET /api/public/agenda/:slug` | `GET /api/agenda` (configuración) · `GET /api/agenda/slug` |
| `GET /api/public/agenda/:slug/disponibilidad` | `PUT /api/agenda/negocio` |
| `POST /api/public/agenda/:slug/reservas` | `POST/PUT/DELETE /api/agenda/servicios[/:id]` |
| `GET /api/public/agenda/citas/:token` | `POST/PUT/DELETE /api/agenda/profesionales[/:id]` |
| `POST /api/public/agenda/citas/:token/confirmar` | `POST/DELETE /api/agenda/bloqueos[/:id]` |
| `POST /api/public/agenda/citas/:token/reenviar` | `GET/POST /api/agenda/citas` · `PUT /api/agenda/citas/:id` |
| `POST /api/public/agenda/citas/:token/cancelar` | `GET /api/agenda/mis-reservas` |

**Tablas:** `agenda_negocios`, `agenda_profesionales`, `agenda_servicios`, `agenda_servicio_profesional`, `agenda_horarios`, `agenda_bloqueos`, `agenda_citas`, `push_cola` y la columna `eventos.cita_id`. **El backend las crea solo al arrancar.**

**Dónde está cada parte:**
- **Web:** `frontend/src/reservas/`, rutas `/agenda/<slug>` y `/cita/<token>`.
- **App:** pestaña **Citas** y `/agenda/<slug>`.
- **Backend:** `backend/lib/agenda/` y `backend/lib/tiempoReal.ts`.
- **Cron:** `cron/citas.js`.

**Pruebas:**
- `backend/lib/agenda/*.test.ts`: disponibilidad y rutas de extremo a extremo contra **MariaDB real** en Actions, incluidos los eventos en vivo que genera cada cambio.
- `backend/lib/tiempoReal.test.ts`: canal SSE real (sesión, eventos por usuario, cierre).
- `cron/citas.test.js`.
- `mobile/test/citas_test.dart` y `mobile/test/tiempo_real_test.dart`.

**Para publicarlo:** despliega `backend/` (y define `WEB_BASE_URL=https://agendaservi.com` si el dominio es otro), `cron/` y el build de `frontend/`.

---

## 📌 Funcionalidades

- Registro con verificación por código de WhatsApp y login con JWT.
- Calendario con festivos de Colombia (`date.nager.at`) y días importantes.
- Eventos con recordatorios automáticos por WhatsApp y confirmación pública por enlace.
- Ciclo menstrual: registro, edición, eliminación, duración y predicciones.
- Notas, hábitos (con registro diario) y cumpleaños.
- Finanzas: cuentas y tarjetas de crédito (día de corte), transacciones, transferencias, ingresos planificados y verificados, metas, presupuestos, categorías personalizadas, analítica avanzada y regla 50/30/20.
- Búsqueda de empresas y exportación a Excel.
- Landing de marketing (web) y modo APK sin landing.
