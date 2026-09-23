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
# Opcional: notificaciones push a la app móvil (ver "Notificaciones push")
FCM_SERVICE_ACCOUNT_FILE=/home/<cuenta>/firebase-service-account.json
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
   2. Subirla al servidor del cron, fuera de la carpeta del repositorio.
   3. Añadir `FCM_SERVICE_ACCOUNT_FILE` a `cron/.env`.
   4. Reiniciar con `npx pm2 restart ecosystem.config.cjs`. El log dirá `[Push] FCM activo para el proyecto …`.
3. **App:** copiar `mobile/firebase.example.json` y llenarlo con los valores de las apps de Firebase (`apiKey`, `appId`, `messagingSenderId`, `projectId`).
   - En GitHub, pegar ese JSON en el secreto `FIREBASE_DART_DEFINES` (*Settings → Secrets and variables → Actions*).
   - En local: `flutter run --dart-define-from-file=firebase.json`.
4. **iPhone:** Apple solo permite push con una cuenta del **Apple Developer Program** (de pago).
   1. Crear una llave APNs (.p8) y subirla en Firebase → *Cloud Messaging → Apple app configuration*.
   2. Firmar la app con esa cuenta.
   - Con un Apple ID gratuito (Sideloadly/AltStore) iOS no entrega push. La app lo detecta y usa sus avisos locales más el refresco en segundo plano, y el WhatsApp llega siempre.

El backend crea la tabla `dispositivos_push` al arrancar (el cron también, si arranca primero). No hace falta ninguna migración manual.

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
