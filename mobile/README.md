# Agendaservi (Flutter)

App móvil con **tres calendarios** — eventos, ciclo menstrual y control financiero — construida con **Flutter, Dart, Riverpod y Drift (SQLite)**. Toma como referencia funcional el frontend web (`../frontend`) y lo mejora. **Funciona 100 % sin conexión**: todos los datos viven en SQLite dentro del dispositivo; no depende del backend.

| | |
|---|---|
| Estado | Riverpod 3 (`Notifier`, `StreamProvider` sobre consultas reactivas de Drift) |
| Datos | Drift 2 + SQLite (nativo en Android/iOS, WebAssembly + IndexedDB en web) |
| Navegación | go_router 18 con `StatefulShellRoute` (cada módulo conserva su estado) |
| UI | Material 3 con sistema de diseño propio, tipografía Inter, fl_chart, flutter_animate |

## Módulos

### 📅 Calendario de eventos
- Calendario mensual deslizable, con **festivos de Colombia calculados en el dispositivo** (Ley Emiliani y Pascua) y días especiales (Día de la Madre, Amor y Amistad…).
- Eventos con categoría, hora, ubicación, notas, **repetición** (diaria, quincenal, mensual, trimestral, semestral, anual) y movimiento de dinero (gasto/ingreso, pendiente/pagado).
- **Los eventos anuales se ven en el calendario con el ícono de su categoría** (moto, casa, doctor…).
- Editar o borrar **"solo este" o "este y los siguientes"** en una serie; los ya pagados se conservan.
- Cumpleaños con edad, teléfono y felicitación por WhatsApp.
- Sin día seleccionado: **agenda ordenada de lo que queda del mes** (eventos, festivos, días especiales y cumpleaños).
- Recordatorio por WhatsApp (vista previa, copiar o enviar) y **búsqueda** de eventos.

### 💧 Calendario del ciclo
- Motor de ciclo portado 1:1 de la web: promedio con ventana móvil, días de sangrado por ciclo, fase por día, periodo previsto, **retraso**, ventana fértil y ovulación.
- **Rueda animada del ciclo** con cada fase coloreada y el marcador del día.
- Pronóstico: próximo periodo, ventana fértil, ovulación y promedios.
- Registrar / editar / eliminar periodos (sin fechas futuras ni duplicados, con aviso si dos inicios quedan muy seguidos).
- **Nuevo:** registro diario de flujo, estado de ánimo y síntomas.
- Historial con duración de cada ciclo y marca de ciclos atípicos.

### 💳 Control financiero
- Patrimonio neto, ahorros y deuda de tarjetas; calendario con el balance de cada día, pagos pendientes e ingresos esperados.
- **Cuentas:** ahorros, corriente, efectivo, tarjeta de crédito (cupo, uso, día de corte) y CDT/cajitas (rendimiento diario, total, vencimiento y proyección a futuro).
- **Movimientos:** compras con tarjeta **a cuotas** que agendan automáticamente los cobros en el calendario de eventos (con día de corte o mensual), vista previa de las fechas de cobro.
- **Transferencias** entre cuentas (pagar tarjeta, mover a ahorros) con reversión de saldos.
- **Planificador** de ingresos recurrentes: confirmar lo recibido (crea el ingreso y suma el saldo) o deshacerlo.
- **Metas** de ahorro con aportes desde una cuenta y celebración al cumplirlas.
- **Presupuesto** por categoría con alertas al 80 % y 100 %; **los límites se mantienen de un mes al siguiente**. Categorías personalizadas con ícono.
- **Resumen** con regla 50/30/20 y consejos del experto económico.
- **Gráficos:** patrimonio, ingresos vs gastos, flujo diario, gastos por categoría, top gastos y fuentes de ingreso (7 días a 1 año).

## Mejoras frente a la versión web
- Todo funciona sin internet y sin servidor; los cambios se reflejan al instante (consultas reactivas).
- Festivos calculados localmente, ya no se piden a una API externa.
- **Deshacer** al borrar eventos, cumpleaños, ciclos y movimientos.
- Registro diario de síntomas y ánimo en el ciclo.
- Aportes a metas vinculados a una cuenta; los presupuestos se mantienen de un mes al siguiente; los ingresos planificados antiguos siguen apareciendo (la web los perdía tras 100 iteraciones).
- Al editar una compra con tarjeta se recalculan sus cuotas pendientes.
- **Corrección de un error de la web:** al editar "este y los siguientes" moviendo la fecha hacia adelante, el backend borraba el propio evento editado.

## Diseño y movimiento
- **Sistema de diseño con tokens** (`lib/app/theme`): espaciado de 4/8 dp, radios, paleta semántica y un acento por módulo (verde para eventos, rosa/lavanda para el ciclo, azul y verde para finanzas). **Al cambiar de módulo todo el tema interpola sus colores.**
- Modo oscuro (por defecto, estilo OLED heredado de la web) y modo claro, ambos con contraste AA.
- Movimiento con curvas *emphasized* de Material 3 (150–420 ms):
  - transición *fade-through* entre módulos;
  - entradas escalonadas en las listas;
  - hojas inferiores que suben desde el borde;
  - cifras que cuentan hasta su valor;
  - barras y anillos que se llenan;
  - respuesta de escala y vibración al tocar.
- Accesibilidad: objetivos táctiles ≥ 44 px, etiquetas semánticas en calendario y controles, soporte de texto grande, y **"Reducir animaciones"** (del sistema o en Ajustes), que apaga todo el movimiento.
- Diseño adaptable: una columna en teléfono y dos paneles con riel lateral en tablet y web.

## Estructura

```
lib/
├── main.dart
├── app/                  # App, router, shell con navegación, temas por módulo
│   └── theme/            # tokens, paleta (ThemeExtension), ThemeData
├── core/
│   ├── db/               # Drift: tablas, base de datos (+ .g.dart generado)
│   ├── widgets/          # calendario mensual, hojas, campos, tarjetas
│   ├── dates.dart · money.dart · holidays.dart · motion.dart · providers.dart
└── features/
    ├── events/           # repositorio (series), pantalla, formulario, tiles
    ├── cycle/            # motor del ciclo, repositorio, rueda, hojas
    ├── finance/          # lógica pura, repositorio, pestañas, hojas, gráficas
    └── settings/         # bienvenida y ajustes
```

## Ejecutar

```bash
flutter pub get
```

```bash
flutter run
```

Al cambiar las tablas de `lib/core/db/tables.dart`, regenera el código de Drift:

```bash
dart run build_runner build
```

**Web:** `web/sqlite3.wasm` (sqlite3 3.5.2) y `web/drift_worker.js` (drift 2.35.0) vienen de las *releases* oficiales de [sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases) y [drift](https://github.com/simolus3/drift/releases). Si actualizas esos paquetes, reemplaza también estos archivos por los de la versión correspondiente.

## Pruebas

```bash
flutter test
```

- `cycle_engine_test` — los casos del motor de ciclo de la web.
- `holidays_test` — festivos 2026 de Colombia y días especiales móviles.
- `repositories_test` — series de eventos, cuotas de tarjeta, transferencias, verificación de ingresos, metas, presupuestos y validaciones del ciclo (SQLite en memoria).
- `app_smoke_test` — arranca la app completa y recorre los tres módulos y todas las pestañas de finanzas en teléfono, tablet y modo claro con texto al 130 %. Falla ante cualquier excepción o desbordamiento de layout.

## CI (GitHub Actions)

`.github/workflows/mobile.yml` (en la raíz del repositorio) corre en cada push a `main` que toque `mobile/`, o a mano desde Actions:
1. Analizador y pruebas.
2. APK de Android (artefacto).
3. `.ipa` de iOS **sin firmar**: queda como artefacto y como *release*. Se instala firmándolo con tu Apple ID desde Sideloadly o AltStore.

## Backend

Esta versión no usa el backend (`../backend`). El repositorio de cada módulo concentra la lógica que antes estaba en el servidor, así que una sincronización futura se puede agregar sin tocar la interfaz.
