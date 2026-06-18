# Proyecto Calendario SaaS

Este es el nuevo proyecto Calendario SaaS, que moderniza la versión original utilizando las tecnologías más avanzadas para garantizar rendimiento, escalabilidad y una experiencia de usuario fluida, manteniendo 100% de fidelidad al diseño original estilo WhatsApp Dark Theme.

## Tecnologías Implementadas
- **Frontend**: Svelte + TypeScript + Vite + TailwindCSS (y CSS Puro heredado).
- **Backend**: Node.js + Fastify + TypeScript.
- **Base de Datos**: MySQL (AlwaysData).

---

## 🚀 Cómo Iniciar el Proyecto

Para levantar el entorno de desarrollo local, debes abrir **dos terminales separadas** (una para el Backend y otra para el Frontend).

### 1. Iniciar el Backend (Fastify)

El backend se conecta a tu base de datos remota (`mysql-vapcaqueta.alwaysdata.net`) y expone la API REST.

```bash
# 1. Entra a la carpeta del backend
cd backend

# 2. Instala las dependencias (solo la primera vez)
npm install

# 3. Inicia el servidor en modo desarrollo
npm run dev
```
> [!NOTE]
> El backend se levantará en **http://localhost:3000**. Estará escuchando con Hot-Reload (gracias a `tsx watch`). Si haces cambios en `server.ts`, se reiniciará solo.

---

### 2. Iniciar el Frontend (Svelte)

El frontend contiene toda la lógica visual, los cálculos del calendario, el Filtro Femenino y las peticiones al backend.

```bash
# 1. Entra a la carpeta del frontend
cd frontend

# 2. Instala las dependencias (solo la primera vez)
npm install

# 3. Inicia el servidor en modo desarrollo
npm run dev
```
> [!NOTE]
> Vite levantará el entorno en **http://localhost:5173**. Al abrir ese enlace en tu navegador, podrás ver y probar el sistema con actualización en tiempo real (Hot-Reloading).

---

## 📌 Funcionalidades Actuales
- Registro y Login conectados a la DB real.
- Interfaz IDÉNTICA al proyecto original (Estilo WhatsApp).
- Integración de días Festivos con la API de `date.nager.at`.
- Integración con tabla `dias_importantes` del backend.
- Lógica 1:1 del ciclo menstrual con el Filtro Femenino.
