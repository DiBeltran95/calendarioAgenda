# Agendaservi (Flutter) · v2.1

Esta es la app móvil de Agendaservi, construida con **Flutter, Dart, Riverpod y Drift (SQLite)**. Tiene tres calendarios: eventos, ciclo menstrual y control financiero.

Es un cliente del **mismo backend que usa la web** (`../backend`, en `dibeltran05.alwaysdata.net`):
- Cada usuario inicia sesión con su cuenta.
- Sus datos son los mismos en agendaservi.com y en el teléfono.
- Los eventos que registra son los que el **cron** (`../cron`) envía por WhatsApp y por **push** al teléfono.

Del backend solo usa los endpoints de la web, más `POST /api/dispositivos` y `POST /api/dispositivos/baja` para registrar el teléfono en el push.

| | |
|---|---|
| Estado | Riverpod 3 (`AsyncNotifier`, familias por mes, `ref.mounted` en los saltos asíncronos) |
| Red | Dio 5, con el token JWT en `flutter_secure_storage` (Keychain / Keystore) |
| Caché | Drift 2 + SQLite: copia local por usuario para abrir al instante y consultar sin internet |
| Avisos | Push del servidor con `firebase_messaging`. Respaldo: `flutter_local_notifications` + `timezone` y `workmanager` |
| Navegación | go_router 18 con `StatefulShellRoute` y redirección según la sesión |
| UI | Material 3 con sistema de diseño propio, Inter, fl_chart, flutter_animate |

## Cuenta y sesión
- **Iniciar sesión** con correo y contraseña. El error del servidor se muestra tal cual y la tarjeta hace una animación de sacudida.
- **Crear cuenta** con indicativo de país + WhatsApp y un medidor de seguridad de la contraseña. El servidor envía un **código de 6 dígitos por WhatsApp**:
  - La pantalla de verificación rellena los dígitos y los envía sola.
  - Para reenviar el código hay una cuenta regresiva de 60 s.
- Si una cuenta sin verificar intenta entrar, se abre directamente la verificación.
- La sesión queda guardada de forma segura:
  - Si el servidor rechaza el token (401), la app vuelve al inicio de sesión con un aviso.
  - **Cerrar sesión** borra el token, la caché local y los avisos programados.

## Módulos

### 🏠 Hoy
- Muestra lo próximo con una **cuenta regresiva en vivo**, la agenda del día, los **pagos de los próximos 7 días** (con marcar como pagado), un resumen de finanzas del mes y el estado del ciclo.
- Se actualiza al deslizar hacia abajo y cada vez que la app vuelve a primer plano.

### 📅 Calendario de eventos
- **Categorías:** actividades, reuniones, aceite de la moto, SOAT, arriendo, servicios, médico, aniversario, mesiversario y más.
- **Frecuencia:** una vez, quincenal, mensual, trimestral, semestral o anual. El servidor genera la serie.
- **Editar o eliminar** "solo este" o "este y los siguientes".
- **Cómo te avisarán:** el formulario muestra por WhatsApp y en el teléfono exactamente cuándo llegará cada aviso, según la categoría y si el evento tiene hora. Sigue las mismas reglas del cron.
- **Eventos con dinero:** gasto o ingreso, pendiente o pagado. Marcar como pagado es instantáneo y se revierte si el servidor falla.
- **Calendario:**
  - Los eventos anuales se ven con el ícono de su categoría (🏍️ moto, 🏠 casa…).
  - Muestra los festivos y días especiales del servidor. Sin conexión se calculan localmente.
- **Cumpleaños:** edad, mensaje y felicitación por WhatsApp.
- **Recordatorio para WhatsApp:** vista previa del recordatorio en burbuja de chat con el enlace de confirmación (`agendaservi.com/confirmar/…`). Se puede copiar, compartir o enviar.
- **Búsqueda** de eventos.

### 💧 Calendario del ciclo
- Los periodos se guardan en el servidor (`/api/cycles`). La app valida antes de enviar y avisa si dos inicios quedan muy seguidos.
- Motor del ciclo idéntico al de la web: fases, periodo previsto, retraso, ventana fértil y ovulación. Incluye una rueda animada.
- **Registro diario** de flujo, ánimo y síntomas. Es un extra de la app: se guarda **solo en el teléfono**, separado por usuario, porque el backend no tiene ese endpoint.

### 🗓️ Citas (agendamiento)
- **Tu página de citas:** un asistente de 4 pasos:
  1. independiente o con equipo;
  2. nombre, enlace verificado al instante, rubro y color;
  3. primer servicio sugerido por el rubro;
  4. horario con plantillas.
- **Compartir:** la tarjeta del enlace permite compartir (WhatsApp, Instagram…), copiar o mostrar un **código QR** con el color de la marca.
- **Agenda:**
  - resumen de hoy, la semana e ingresos estimados;
  - próxima cita;
  - tira de 3 semanas con un punto por cita;
  - línea de tiempo del día con el color de cada profesional.
- **En cada cita:** escribir al cliente por WhatsApp, marcar **Asistió / No asistió** (con deshacer) o **cancelar** (se le avisa por WhatsApp).
- **Nueva cita** a mano, para quien llama o llega: sugiere las horas libres, permite otra hora y avisa si hay choque.
- **Ajustes de citas:**
  - datos y reglas de la página: anticipación, ventana, intervalo, respetar tu calendario, pausar;
  - servicios;
  - equipo, con cuenta vinculada o solo WhatsApp, y el horario de cada uno;
  - tiempo bloqueado.
- **Reservar desde la app:** los enlaces `agendaservi.com/agenda/<slug>` y `agendaservi://app/agenda/<slug>` abren la reserva en la app, con tu nombre y WhatsApp ya llenos. La reserva queda en **Mis reservas**.
- Las citas confirmadas también aparecen en el calendario de eventos, con sus recordatorios.
- **En vivo:** con la app abierta, las reservas y cancelaciones llegan solas por el canal SSE `GET /api/tiempo-real` (`lib/core/net/tiempo_real.dart` y `lib/features/citas/citas_en_vivo.dart`):
  - la cita entra a la lista al instante, con la etiqueta **Nueva** durante 2 minutos;
  - un aviso flotante arriba (sobre cualquier pantalla) lleva al detalle al tocarlo, se descarta deslizando hacia arriba y se oculta solo a los 6 s;
  - si el detalle de esa cita está abierto, se actualiza solo;
  - las reservas sin confirmar pasan a "Sin confirmar" a los 15 minutos, sin consultar al servidor;
  - robustez: reconexión con espera creciente, vigía de 60 s sin datos y sincronización al reconectar, al volver a la app y al entrar a Citas;
  - si el canal no funciona en esa red, consulta cada 20 s;
  - en segundo plano se desconecta y avisa el push; con la app abierta, un push de cita se convierte en el mismo aviso, sin duplicarse.

### 💳 Control financiero
- **Cuentas y tarjetas:**
  - Ahorros y corriente (tarjeta débito) y efectivo.
  - **Tarjetas de crédito** con cupo, uso y día de corte.
  - CDT/cajitas con rendimiento y vencimiento.
- **Movimientos:**
  - Gastos e ingresos por categoría.
  - **Compras a cuotas** con tarjeta de crédito: el servidor agenda cada cuota como evento, y el cron la avisa el día del cobro.
- **Transferencias** entre cuentas, por ejemplo para pagar la tarjeta.
- **Planificador** de ingresos recurrentes, para confirmar o deshacer lo recibido.
- **Metas** de ahorro con aportes desde una cuenta.
- **Presupuestos** por categoría con alertas al 80 % y 100 %. Hay categorías personalizadas.
- **Resumen** con la regla 50/30/20 y **gráficos**: patrimonio, flujo, gastos por categoría, top de gastos e ingresos por categoría (de 7 días a 1 año).

## Notificaciones en el teléfono

### Push del servidor (principal)
El cron envía cada aviso por WhatsApp **y por push** a la misma hora. El teléfono avisa aunque la app esté cerrada, lleve días sin abrirse o el evento se haya creado en la web. La app no consulta al servidor en segundo plano para esto.

**Registro del teléfono:**
- Al iniciar sesión, la app envía su token de Firebase y sus preferencias a `POST /api/dispositivos`: avisos activos, 30 min antes y resumen.
- Vuelve a enviarlos cada vez que cambian, cuando se renueva el token y, como máximo, cada 12 h al abrir la app.
- Al cerrar sesión, lo da de baja.

**Bienvenida:** el cron envía un primer push ("🔔 Notificaciones activadas"). Cuando FCM lo acepta, o cuando llega uno con la app abierta, la app apaga sus avisos locales para no duplicar. Perfil muestra por qué vía llegan los avisos.

**Android:**
- Llegan mensajes de datos de prioridad alta, que la app muestra con sus propios canales, texto expandible y el **mismo id** que el aviso local equivalente (`idAviso`, igual en `cron/push.js`).
- Si coinciden, uno reemplaza al otro en vez de duplicarse.

**iOS:**
- Llega una alerta de APNs con `apns-collapse-id`.
- Requiere firmar la app con una cuenta del Apple Developer Program. Con un Apple ID gratuito, iOS no entrega push y la app sigue con el respaldo.

**Configuración:** no se sube al repositorio. Se inyecta al compilar con `--dart-define-from-file=firebase.json` (plantilla en `firebase.example.json`; en CI viene del secreto `FIREBASE_DART_DEFINES`). Sin ella la app compila y funciona solo con el respaldo. Los pasos completos están en el README principal, en *Notificaciones push*.

### Respaldo en el teléfono (sin push)
Mientras el push no esté confirmado, la app programa avisos locales y se refresca en segundo plano:
- En Android con WorkManager, cada ~2 h y solo con internet.
- En iOS con Background App Refresh, cuando el sistema lo decide.

En cada refresco descarga los eventos y reprograma los avisos. Así un evento creado en la web también avisa sin abrir la app, aunque con menos garantía de hora que el push.

Los avisos locales siguen las **mismas reglas y los mismos textos** del cron (`lib/features/notifications/reminder_planner.dart` y `lib/features/events/mensajes.dart`):

| Qué | Cuándo |
|---|---|
| Evento con hora | 30 min antes (opcional) y a la hora exacta |
| Evento sin hora, cobros de tarjeta, arriendo, aceite de la moto, servicios, aniversario, mesiversario | En el **resumen de las 7:00 a. m.** de ese día |
| Cumpleaños, festivos, puente festivo, vencimiento de CDT | En el resumen de las 7:00 a. m. |

- Todo se calcula con la hora de Bogotá (UTC−5), igual que el cron, así que no importa la zona horaria del teléfono.
- Se programan los próximos 14 días, con un máximo de 60 avisos, porque iOS solo conserva 64. Los ids son estables, así que reprogramar nunca duplica.
- Los avisos se reprograman solos después de cada cambio, al iniciar sesión y al volver a la app.
- Al tocar una notificación se abre el calendario en ese día, incluso si la app estaba cerrada.
- Desde Perfil se puede:
  - activar o desactivar los avisos;
  - activar o desactivar el aviso de 30 min;
  - activar o desactivar el resumen diario;
  - pedir permiso;
  - enviar una notificación de prueba.
- En Android se usan alarmas exactas cuando el sistema lo permite, y los avisos sobreviven al reinicio del teléfono.

## Navegación
- **Barra inferior** con 5 módulos: Hoy, Eventos, Citas, Finanzas y Ciclo (el máximo recomendado).
- **Perfil y ajustes** se abren desde el avatar en la esquina de cada módulo, como una pantalla que se desliza.
- **Botones flotantes** (Nuevo evento, Movimiento, Registrar periodo, Nueva cita): al entrar al módulo muestran su texto con un destello y luego se recogen al ícono. Si los mantienes presionados, se vuelven a desplegar.

## Sin conexión y sincronización
- **Primero la caché:** cada pantalla muestra al instante la última copia guardada y la actualiza desde el servidor en segundo plano.
- Una **banda "Sin conexión"** aparece cuando el servidor no responde y desaparece sola al reconectar.
- Después de crear, editar o borrar algo, la app refresca los meses visibles y la información general. Así los saldos, las cuotas y las series siempre coinciden con el servidor.

## Diseño y movimiento
- **Tokens de diseño** (`lib/app/theme`): espaciado de 4/8 dp, radios y paleta semántica.
- **Acento por módulo**: turquesa en Hoy, verde en eventos, rosa/lavanda en el ciclo, azul/verde en finanzas. **Al cambiar de módulo, el tema interpola sus colores.**
- Modo oscuro (OLED) y modo claro, ambos con contraste AA.
- **Animaciones:**
  - fondo "aurora" en el acceso;
  - logo compartido (Hero) entre las pantallas de acceso;
  - transiciones *shared axis* y *fade-through*;
  - listas escalonadas;
  - cifras que cuentan hasta su valor;
  - respuesta háptica.
- **Accesibilidad:**
  - objetivos táctiles de al menos 44 px;
  - etiquetas semánticas;
  - texto grande: se prueba al 130 %;
  - **Reducir animaciones**.
- **Diseño adaptable:** una columna en teléfono; dos paneles con riel lateral en tablet y web.

## Estructura

```
lib/
├── main.dart               # arranque, notificaciones y apertura desde un aviso
├── app/                    # App, router (redirección por sesión), shell, temas
├── core/
│   ├── net/                # ApiClient (Dio), ApiException, parseo tolerante de JSON
│   ├── db/                 # Drift: ajustes, caché y registro diario del ciclo
│   ├── session.dart        # sesión, token seguro, cierre ante 401
│   └── widgets/ …          # calendario mensual, hojas, campos, tarjetas
├── data/
│   ├── models.dart         # modelos con fromJson/toJson del backend
│   └── sync.dart           # caché + red, estado de conexión, Sincronizador
└── features/
    ├── auth/               # login, registro, verificación por WhatsApp
    ├── home/               # pantalla Hoy
    ├── events/             # repositorio, pantalla, formulario, mensajes del cron
    ├── cycle/              # motor, repositorio, rueda
    ├── finance/            # repositorio, providers, lógica, pestañas, hojas
    ├── notifications/      # push (FCM), registro del teléfono, respaldo local y de fondo
    └── settings/           # perfil, avisos, apariencia, sesión
```

## Ejecutar

```bash
flutter pub get
```

```bash
flutter run
```

Con push (necesita `firebase.json`, ver `firebase.example.json`):

```bash
flutter run --dart-define-from-file=firebase.json
```

Por defecto la app apunta a `https://dibeltran05.alwaysdata.net` (`ApiClient` en `lib/core/net/api_client.dart`).

Si cambias las tablas de `lib/core/db/tables.dart`, regenera Drift:

```bash
dart run build_runner build
```

## Pruebas

```bash
flutter test
```

Las pruebas **nunca tocan el servidor real**, así que no crean cuentas ni envían WhatsApp. `test/support/fake_backend.dart` es un backend falso en memoria que reproduce las respuestas de `../backend/src/server.ts`:
- los tipos de MySQL (decimales como texto, booleanos 0/1);
- los errores `{message}`;
- el 401 de JWT;
- la verificación por código;
- las series de eventos, las cuotas y los saldos.

| Archivo | Qué cubre |
|---|---|
| `api_test` | Sesión, 401, verificación, caché sin conexión, series, pagos, cuotas, transferencias, metas, presupuestos y ciclos |
| `push_test` | Registro del teléfono y preferencias, paso de avisos locales a push del servidor, token renovado, baja al cerrar sesión, refresco en segundo plano |
| `citas_test` | Página de citas, servicios, equipo, bloqueos, citas a mano y estados; reserva con código; asistente completo y reserva desde la app (interfaz) |
| `tiempo_real_test` | Canal SSE: lector, reconexión y resincronización, modo respaldo, cierre. Agenda en vivo: la reserva aparece sola, avisos sin duplicados ni por acciones propias, detección de cambios sin canal, push de cita. Interfaz: aviso, tocarlo abre el detalle, que se actualiza al cancelar |
| `fab_animado_test` | Botón flotante que se despliega y se recoge |
| `planner_test` | Avisos del teléfono con las reglas del cron: 30 min, resumen de las 7:00, puentes festivos, CDT, límite de iOS |
| `app_smoke_test` | Recorre la app completa en teléfono, tablet y modo claro con texto al 130 %, más los flujos de login y registro con código. Falla ante cualquier excepción o desbordamiento |
| `cycle_engine_test`, `holidays_test` | Motor del ciclo y festivos de Colombia |

## CI (GitHub Actions)

`.github/workflows/mobile.yml`, en la raíz del repositorio, corre en cada push a `main` que toque `mobile/`, o a mano desde Actions:
1. Analizador y pruebas.
2. APK de Android (artefacto).
3. `.ipa` de iOS **sin firmar**, como artefacto y como *release* `mobile-build-N`. Se instala firmándolo con tu Apple ID desde Sideloadly o AltStore.

Si existe el secreto `FIREBASE_DART_DEFINES`, ambos builds salen con push.

## Límites conocidos
- Los **ingresos planificados** se pueden crear, confirmar y borrar, pero no editar: no existe ese endpoint.
- Los eventos no tienen **notas**: la tabla del backend no tiene ese campo.
- **Aportar a una meta desde una cuenta** hace dos llamadas (movimiento + meta), así que no es atómico.
- El **registro diario** del ciclo (flujo, ánimo, síntomas) solo vive en el teléfono.
