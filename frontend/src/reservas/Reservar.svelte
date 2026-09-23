<script lang="ts">
  // Página pública para agendar una cita: agendaservi.com/agenda/<slug>.
  //
  // Flujo (inspirado en Cal.com y Fresha): servicio → profesional (si hay
  // equipo) → fecha y hora → datos → código por WhatsApp → ¡listo!
  // En escritorio: panel del negocio a la izquierda y calendario + horas lado
  // a lado. En el teléfono: pasos con barra inferior fija para continuar.
  import '@fontsource/inter/400.css';
  import '@fontsource/inter/500.css';
  import '@fontsource/inter/600.css';
  import '@fontsource/inter/700.css';
  import './tema.css';
  import { onMount, tick } from 'svelte';
  import { fly, fade, scale } from 'svelte/transition';
  import { agendaApi, ErrorApi, type CitaPublica, type Pagina, type Profesional, type Servicio, type Turno } from './api';
  import CodigoInput from './CodigoInput.svelte';
  import AgregarCalendario from './AgregarCalendario.svelte';
  import {
    RUBROS,
    celdasMes,
    duracion,
    enlaceWhatsApp,
    esMovil,
    fechaCorta,
    fechaLarga,
    franja,
    hora12,
    hoyBogota,
    memoria,
    mesSiguiente,
    nombreMes,
    pesos,
    primeroDelMes,
    reduceMovimiento,
    sumarDias,
    textoSobre,
  } from './util';

  let { slug }: { slug: string } = $props();

  type Paso = 'servicio' | 'profesional' | 'horario' | 'datos' | 'codigo' | 'listo';

  const quieto = reduceMovimiento();
  const t = (ms: number) => (quieto ? 0 : ms);

  let pagina = $state<Pagina | null>(null);
  let errorPagina = $state<string | null>(null);
  let paso = $state<Paso>('servicio');
  let direccion = $state<1 | -1>(1);

  let servicio = $state<Servicio | null>(null);
  let profesionalId = $state(0); // 0 = cualquiera
  let mes = $state(primeroDelMes(hoyBogota()));
  let fecha = $state<string | null>(null);
  let hora = $state<string | null>(null);
  let hasta = $state<string | null>(null);
  let turnosPorDia = $state<Record<string, Turno[]>>({});
  let cargandoMes = $state(false);
  let errorMes = $state<string | null>(null);
  let avisoHorario = $state<string | null>(null);
  let saltosAuto = 0;

  const recordado = memoria.leer();
  let nombre = $state(recordado?.nombre ?? '');
  let indicativo = $state(recordado?.indicativo ?? '57');
  let numero = $state(recordado?.numero ?? '');
  let nota = $state('');
  let tocado = $state({ nombre: false, numero: false });
  let enviando = $state(false);
  let errorForm = $state<string | null>(null);

  let cita = $state<CitaPublica | null>(null);
  let codigo = $state('');
  let errorCodigo = $state<string | null>(null);
  let confirmando = $state(false);
  let segundos = $state(0);
  let esperaReenvio = $state(0);
  let codigoInput: ReturnType<typeof CodigoInput> | undefined = $state();

  const INDICATIVOS = [
    ['57', '+57 CO'],
    ['52', '+52 MX'],
    ['58', '+58 VE'],
    ['593', '+593 EC'],
    ['51', '+51 PE'],
    ['56', '+56 CL'],
    ['54', '+54 AR'],
    ['507', '+507 PA'],
    ['1', '+1 US'],
    ['34', '+34 ES'],
  ];

  // ---------- Derivados ----------
  const negocio = $derived(pagina?.negocio);
  const colorMarca = $derived(negocio?.color ?? '#2563eb');
  const profesionalesServicio = $derived<Profesional[]>(
    servicio && pagina ? pagina.profesionales.filter((p) => servicio!.profesionales.includes(p.id)) : []
  );
  const conEquipo = $derived(profesionalesServicio.length > 1);
  const pasos = $derived<Paso[]>(conEquipo ? ['servicio', 'profesional', 'horario', 'datos'] : ['servicio', 'horario', 'datos']);
  const indicePaso = $derived(pasos.indexOf(paso));
  const profesionalElegido = $derived(pagina?.profesionales.find((p) => p.id === profesionalId) ?? null);
  const turnosDia = $derived(fecha ? (turnosPorDia[fecha] ?? []) : []);
  const grupos = $derived(
    (['manana', 'tarde', 'noche'] as const)
      .map((f) => ({ franja: f, turnos: turnosDia.filter((x) => franja(x.hora) === f) }))
      .filter((g) => g.turnos.length > 0)
  );
  const hoy = hoyBogota();
  const celdas = $derived(celdasMes(mes));
  const hayAntes = $derived(mes > primeroDelMes(hoy));
  const hayDespues = $derived(!hasta || mesSiguiente(mes, 1) <= hasta);
  const diasConTurnos = $derived(Object.entries(turnosPorDia).filter(([f, l]) => f.startsWith(mes.slice(0, 7)) && l.length > 0).length);
  const numeroLimpio = $derived(numero.replace(/\D/g, ''));
  const errorNombre = $derived(nombre.trim().length < 2 ? 'Escribe tu nombre' : null);
  const errorNumero = $derived(numeroLimpio.length < 7 || numeroLimpio.length > 12 ? 'Escribe tu número de WhatsApp' : null);
  const profesionalAsignado = $derived(cita?.profesional.nombre ?? profesionalElegido?.nombre ?? null);

  // ---------- Carga ----------
  onMount(() => {
    agendaApi
      .pagina(slug)
      .then((p) => {
        pagina = p;
        document.title = `Agenda tu cita · ${p.negocio.nombre}`;
        // Con un solo servicio se salta directo a elegir horario.
        if (p.servicios.length === 1) elegirServicio(p.servicios[0]!, false);
      })
      .catch((e) => (errorPagina = e instanceof ErrorApi && e.status === 404 ? 'no-existe' : (e as Error).message));
    const reloj = setInterval(() => {
      if (segundos > 0) segundos--;
      if (esperaReenvio > 0) esperaReenvio--;
    }, 1000);
    return () => clearInterval(reloj);
  });

  let cacheMes = new Map<string, Promise<void>>();
  async function cargarMes(forzar = false) {
    if (!servicio) return;
    const clave = `${servicio.id}:${profesionalId}:${mes}`;
    if (!forzar && cacheMes.has(clave)) return cacheMes.get(clave);
    const desde = mes <= hoy ? hoy : mes;
    const fin = sumarDias(mesSiguiente(mes, 1), -1);
    const dias = Math.round((Date.parse(fin) - Date.parse(desde)) / 86400000) + 1;
    if (dias <= 0) return;
    cargandoMes = true;
    errorMes = null;
    const promesa = agendaApi
      .disponibilidad(slug, servicio.id, profesionalId, desde, dias)
      .then((r) => {
        hasta = r.hasta;
        const nuevos = { ...turnosPorDia };
        for (const d of r.dias) nuevos[d.fecha] = d.turnos;
        turnosPorDia = nuevos;
      })
      .catch((e) => {
        cacheMes.delete(clave);
        errorMes = (e as Error).message;
      })
      .finally(() => (cargandoMes = false));
    cacheMes.set(clave, promesa);
    await promesa;
    // Se abre en el primer día con horarios (como Fresha / Cal.com).
    const primero = Object.keys(turnosPorDia)
      .filter((f) => f.startsWith(mes.slice(0, 7)) && (turnosPorDia[f]?.length ?? 0) > 0)
      .sort()[0];
    if (!fecha || !fecha.startsWith(mes.slice(0, 7)) || !(turnosPorDia[fecha]?.length)) fecha = primero ?? null;
    if (!primero && saltosAuto < 2 && hayDespues) {
      saltosAuto++;
      mes = mesSiguiente(mes, 1);
      await cargarMes();
    }
  }

  function reiniciarDisponibilidad() {
    cacheMes = new Map();
    turnosPorDia = {};
    fecha = null;
    hora = null;
    saltosAuto = 0;
    mes = primeroDelMes(hoy);
  }

  // ---------- Navegación ----------
  function irA(p: Paso) {
    direccion = pasos.indexOf(p) >= indicePaso || p === 'codigo' || p === 'listo' ? 1 : -1;
    paso = p;
    tick().then(() => document.getElementById('paso-titulo')?.focus({ preventScroll: true }));
    if (window.innerWidth < 900) window.scrollTo({ top: 0, behavior: quieto ? 'auto' : 'smooth' });
  }

  function atras() {
    if (paso === 'codigo') return irA('datos');
    const i = indicePaso;
    if (i > 0) irA(pasos[i - 1]!);
  }

  function elegirServicio(s: Servicio, avanzar = true) {
    if (servicio?.id !== s.id) {
      servicio = s;
      profesionalId = 0;
      reiniciarDisponibilidad();
    }
    const equipo = pagina!.profesionales.filter((p) => s.profesionales.includes(p.id));
    if (equipo.length <= 1) {
      profesionalId = equipo[0]?.id ?? 0;
      if (avanzar || pagina!.servicios.length === 1) {
        irA('horario');
        cargarMes();
      }
    } else if (avanzar) irA('profesional');
  }

  function elegirProfesional(id: number) {
    if (profesionalId !== id) {
      profesionalId = id;
      reiniciarDisponibilidad();
    }
    irA('horario');
    cargarMes();
  }

  function cambiarMes(delta: number) {
    mes = mesSiguiente(mes, delta);
    hora = null;
    saltosAuto = 2; // navegación manual: no saltar solo
    cargarMes();
  }

  function elegirFecha(f: string) {
    fecha = f;
    hora = null;
  }

  function continuarHorario() {
    if (fecha && hora) irA('datos');
  }

  // ---------- Reserva ----------
  async function reservar(e: SubmitEvent) {
    e.preventDefault();
    tocado = { nombre: true, numero: true };
    if (errorNombre || errorNumero || !servicio || !fecha || !hora) return;
    enviando = true;
    errorForm = null;
    try {
      cita = await agendaApi.reservar(slug, {
        servicio_id: servicio.id,
        profesional_id: profesionalId,
        fecha,
        hora,
        nombre: nombre.trim(),
        whatsapp: indicativo + numeroLimpio,
        nota: nota.trim() || undefined,
      });
      memoria.guardar({ nombre: nombre.trim(), indicativo, numero: numeroLimpio });
      segundos = cita.segundos_restantes;
      esperaReenvio = 60;
      codigo = '';
      errorCodigo = null;
      irA('codigo');
      tick().then(() => codigoInput?.enfocar());
    } catch (err) {
      const ex = err as ErrorApi;
      if (ex.status === 409 && ex.datos?.codigo === 'ocupado') {
        avisoHorario = 'Ese horario se acaba de ocupar. Elige otro, por favor.';
        hora = null;
        irA('horario');
        await cargarMes(true);
      } else {
        errorForm = ex.message;
      }
    } finally {
      enviando = false;
    }
  }

  async function confirmar(c: string) {
    if (!cita || confirmando) return;
    confirmando = true;
    errorCodigo = null;
    try {
      cita = await agendaApi.confirmar(cita.token, c);
      irA('listo');
    } catch (err) {
      const ex = err as ErrorApi;
      errorCodigo = ex.message;
      if (ex.status === 410 || ex.status === 409) segundos = 0;
    } finally {
      confirmando = false;
    }
    // Tras un error se limpia y se vuelve a la primera casilla (ya habilitada).
    if (errorCodigo && segundos > 0) tick().then(() => codigoInput?.limpiar());
  }

  async function reenviar() {
    if (!cita || esperaReenvio > 0) return;
    esperaReenvio = 60;
    try {
      await agendaApi.reenviar(cita.token);
      errorCodigo = null;
    } catch (err) {
      errorCodigo = (err as Error).message;
    }
  }

  function empezarDeNuevo() {
    cita = null;
    hora = null;
    codigo = '';
    cacheMes = new Map();
    turnosPorDia = {};
    if (pagina && pagina.servicios.length === 1) {
      irA('horario');
      cargarMes(true);
    } else {
      servicio = null;
      irA('servicio');
    }
  }

  const mmss = (s: number) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
  const nombreFranja = { manana: 'Mañana', tarde: 'Tarde', noche: 'Noche' } as const;
  const iconoFranja = { manana: 'wb_twilight', tarde: 'light_mode', noche: 'dark_mode' } as const;
  const etiquetaPaso: Record<Paso, string> = {
    servicio: 'Servicio',
    profesional: 'Profesional',
    horario: 'Fecha y hora',
    datos: 'Tus datos',
    codigo: 'Confirmar',
    listo: 'Listo',
  };
</script>

<div class="ag-root" style="--marca:{colorMarca}; --marca-texto:{textoSobre(colorMarca)}">
  {#if errorPagina === 'no-existe'}
    <main class="vacio" in:fade={{ duration: t(200) }}>
      <span class="material-icons icono-vacio" aria-hidden="true">event_busy</span>
      <h1 class="ag-titulo">Esta página de citas no existe</h1>
      <p class="ag-subtitulo">Revisa el enlace o pídele al negocio que te lo comparta de nuevo.</p>
    </main>
  {:else if errorPagina}
    <main class="vacio">
      <span class="material-icons icono-vacio" aria-hidden="true">wifi_off</span>
      <h1 class="ag-titulo">No pudimos cargar la página</h1>
      <p class="ag-subtitulo">{errorPagina}</p>
      <button class="ag-btn ag-btn-primario" onclick={() => location.reload()}>Reintentar</button>
    </main>
  {:else if !pagina || !negocio}
    <main class="contenedor" aria-busy="true" aria-label="Cargando">
      <aside class="panel-negocio ag-card esqueleto-panel">
        <div class="ag-esqueleto" style="width:64px;height:64px;border-radius:999px"></div>
        <div class="ag-esqueleto" style="width:70%;height:24px;margin-top:16px"></div>
        <div class="ag-esqueleto" style="width:40%;height:16px;margin-top:10px"></div>
      </aside>
      <section class="panel-paso ag-card">
        {#each Array(4) as _}
          <div class="ag-esqueleto" style="height:76px;margin-bottom:12px"></div>
        {/each}
      </section>
    </main>
  {:else}
    {#if esMovil()}
      <a class="abrir-app" href={`agendaservi://app/agenda/${negocio.slug}`}>
        <span class="material-icons" aria-hidden="true">install_mobile</span>
        ¿Tienes la app Agendaservi? Ábrela aquí
      </a>
    {/if}

    <main class="contenedor" class:compacto={paso === 'listo'}>
      <!-- ================= Panel del negocio + resumen ================= -->
      <aside class="panel-negocio ag-card" aria-label="Información del negocio">
        <div class="negocio">
          <span class="ag-avatar avatar-negocio" style="background:{colorMarca}; color:{textoSobre(colorMarca)}">{negocio.iniciales}</span>
          <div class="negocio-texto">
            <h1 class="nombre-negocio">{negocio.nombre}</h1>
            <p class="rubro">{RUBROS[negocio.rubro] ?? 'Servicios'}</p>
          </div>
        </div>
        {#if negocio.descripcion}
          <p class="descripcion">{negocio.descripcion}</p>
        {/if}
        <ul class="datos-negocio">
          {#if negocio.direccion}
            <li><span class="material-icons" aria-hidden="true">location_on</span>{negocio.direccion}</li>
          {/if}
          <li><span class="material-icons" aria-hidden="true">verified</span>Confirmación por WhatsApp</li>
        </ul>

        {#if servicio && paso !== 'servicio'}
          <div class="resumen" class:ocultar-movil={paso === 'datos' || paso === 'codigo'} in:fly={{ y: 8, duration: t(260) }}>
            <p class="resumen-titulo">Tu cita</p>
            <div class="resumen-fila">
              <span class="material-icons" aria-hidden="true">spa</span>
              <div>
                <strong>{servicio.nombre}</strong>
                <span class="tenue">{duracion(servicio.duracion_min)}{servicio.precio > 0 ? ` · ${pesos(servicio.precio)}` : ''}</span>
              </div>
            </div>
            {#if conEquipo || cita}
              <div class="resumen-fila" in:fly={{ y: 8, duration: t(260) }}>
                <span class="material-icons" aria-hidden="true">person</span>
                <div><strong>{profesionalAsignado ?? 'Cualquier profesional'}</strong></div>
              </div>
            {/if}
            {#if fecha && hora && (paso === 'datos' || paso === 'codigo' || paso === 'listo')}
              <div class="resumen-fila" in:fly={{ y: 8, duration: t(260) }}>
                <span class="material-icons" aria-hidden="true">event</span>
                <div>
                  <strong class="capital">{fechaLarga(fecha)}</strong>
                  <span class="tenue ag-num">{hora12(hora)}</span>
                </div>
              </div>
            {/if}
          </div>
        {/if}

        {#if negocio.whatsapp}
          <a class="contacto" href={enlaceWhatsApp(negocio.whatsapp, `Hola ${negocio.nombre}, tengo una pregunta sobre las citas.`)} target="_blank" rel="noopener">
            <span class="material-icons" aria-hidden="true">chat</span> ¿Dudas? Escríbenos
          </a>
        {/if}
      </aside>

      <!-- ================= Paso actual ================= -->
      <section class="panel-paso ag-card" aria-labelledby="paso-titulo">
        {#if paso !== 'listo'}
          <header class="cabecera-paso">
            {#if (indicePaso > 0 && !(paso === 'horario' && pagina.servicios.length === 1 && !conEquipo)) || paso === 'codigo'}
              <button class="ag-btn ag-btn-texto atras" onclick={atras} aria-label="Volver al paso anterior">
                <span class="material-icons" aria-hidden="true">arrow_back</span>
              </button>
            {/if}
            {#if paso !== 'codigo'}
              <ol class="progreso" aria-label="Progreso">
                {#each pasos as p, i}
                  <li class:hecho={i < indicePaso} class:actual={i === indicePaso} aria-current={i === indicePaso ? 'step' : undefined}>
                    <span class="punto"></span><span class="texto-paso">{etiquetaPaso[p]}</span>
                  </li>
                {/each}
              </ol>
            {/if}
          </header>
        {/if}

        {#key paso}
          <div class="contenido-paso" in:fly={{ x: 24 * direccion, duration: t(300) }}>
            <!-- ---------- 1. Servicio ---------- -->
            {#if paso === 'servicio'}
              <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">¿Qué servicio necesitas?</h2>
              <p class="ag-subtitulo">Elige uno para ver los horarios disponibles.</p>
              {#if pagina.servicios.length === 0}
                <p class="nota-vacia">Este negocio aún no tiene servicios disponibles para agendar.</p>
              {/if}
              <ul class="lista-servicios">
                {#each pagina.servicios as s, i}
                  <li style="--i:{i}">
                    <button class="servicio" class:elegido={servicio?.id === s.id} onclick={() => elegirServicio(s)}>
                      <span class="barra-color" style="background:{s.color}"></span>
                      <span class="servicio-texto">
                        <span class="servicio-nombre">{s.nombre}</span>
                        {#if s.descripcion}<span class="servicio-desc">{s.descripcion}</span>{/if}
                        <span class="servicio-meta">
                          <span class="chip"><span class="material-icons" aria-hidden="true">schedule</span>{duracion(s.duracion_min)}</span>
                          {#if s.precio > 0}<span class="precio ag-num">{pesos(s.precio)}</span>{/if}
                        </span>
                      </span>
                      <span class="material-icons chevron" aria-hidden="true">chevron_right</span>
                    </button>
                  </li>
                {/each}
              </ul>

              <!-- ---------- 2. Profesional ---------- -->
            {:else if paso === 'profesional'}
              <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">¿Con quién?</h2>
              <p class="ag-subtitulo">Elige a alguien de confianza o deja que te asignemos el primero libre.</p>
              <div class="grilla-profesionales">
                <button class="profesional" class:elegido={profesionalId === 0} onclick={() => elegirProfesional(0)} style="--i:0">
                  <span class="apilados" aria-hidden="true">
                    {#each profesionalesServicio.slice(0, 3) as p}
                      <span class="ag-avatar mini" style="background:{p.color}">{p.iniciales}</span>
                    {/each}
                  </span>
                  <span class="prof-nombre">Cualquier profesional</span>
                  <span class="prof-cargo destacado"><span class="material-icons" aria-hidden="true">bolt</span>Más disponibilidad</span>
                </button>
                {#each profesionalesServicio as p, i}
                  <button class="profesional" class:elegido={profesionalId === p.id} onclick={() => elegirProfesional(p.id)} style="--i:{i + 1}">
                    <span class="ag-avatar grande" style="background:{p.color}; color:{textoSobre(p.color)}">{p.iniciales}</span>
                    <span class="prof-nombre">{p.nombre}</span>
                    {#if p.cargo}<span class="prof-cargo">{p.cargo}</span>{/if}
                  </button>
                {/each}
              </div>

              <!-- ---------- 3. Fecha y hora ---------- -->
            {:else if paso === 'horario'}
              <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">Elige fecha y hora</h2>
              <p class="ag-subtitulo">Hora de Colombia · {servicio ? duracion(servicio.duracion_min) : ''}</p>
              {#if avisoHorario}
                <div class="aviso" role="alert" transition:fly={{ y: -6, duration: t(200) }}>
                  <span class="material-icons" aria-hidden="true">info</span>{avisoHorario}
                  <button class="cerrar-aviso" aria-label="Cerrar aviso" onclick={() => (avisoHorario = null)}><span class="material-icons">close</span></button>
                </div>
              {/if}
              <div class="horario">
                <div class="calendario" aria-busy={cargandoMes}>
                  <div class="mes-cabecera">
                    <button class="ag-btn ag-btn-texto nav-mes" disabled={!hayAntes || cargandoMes} onclick={() => cambiarMes(-1)} aria-label="Mes anterior">
                      <span class="material-icons">chevron_left</span>
                    </button>
                    <strong class="mes-nombre" aria-live="polite">{nombreMes(mes)}</strong>
                    <button class="ag-btn ag-btn-texto nav-mes" disabled={!hayDespues || cargandoMes} onclick={() => cambiarMes(1)} aria-label="Mes siguiente">
                      <span class="material-icons">chevron_right</span>
                    </button>
                  </div>
                  <div class="semana" aria-hidden="true">
                    {#each ['L', 'M', 'M', 'J', 'V', 'S', 'D'] as d}<span>{d}</span>{/each}
                  </div>
                  <div class="dias" class:cargando={cargandoMes} role="grid" aria-label={`Días de ${nombreMes(mes)}`}>
                    {#each celdas as c}
                      {#if c === null}
                        <span></span>
                      {:else}
                        {@const libres = turnosPorDia[c]?.length ?? 0}
                        <button
                          class="dia ag-num"
                          class:libre={libres > 0}
                          class:hoy={c === hoy}
                          class:elegido={c === fecha}
                          disabled={libres === 0}
                          aria-pressed={c === fecha}
                          aria-label={`${fechaLarga(c)}${libres ? `, ${libres} horarios` : ', sin horarios'}`}
                          onclick={() => elegirFecha(c)}
                        >
                          {Number(c.slice(8))}
                        </button>
                      {/if}
                    {/each}
                  </div>
                  {#if !cargandoMes && !errorMes && diasConTurnos === 0}
                    <p class="nota-vacia">
                      Sin horarios en {nombreMes(mes).toLowerCase()}.
                      {#if hayDespues}<button class="enlace" onclick={() => cambiarMes(1)}>Ver el mes siguiente</button>{/if}
                    </p>
                  {/if}
                  {#if errorMes}
                    <p class="ag-error" role="alert"><span class="material-icons">error</span>{errorMes} <button class="enlace" onclick={() => cargarMes(true)}>Reintentar</button></p>
                  {/if}
                </div>

                <div class="turnos" aria-live="polite">
                  {#if cargandoMes && !fecha}
                    {#each Array(6) as _}<div class="ag-esqueleto" style="height:44px;margin-bottom:8px"></div>{/each}
                  {:else if fecha}
                    <p class="dia-elegido capital">{fechaLarga(fecha)}</p>
                    {#each grupos as g (g.franja)}
                      <div class="franja">
                        <p class="franja-titulo"><span class="material-icons" aria-hidden="true">{iconoFranja[g.franja]}</span>{nombreFranja[g.franja]}</p>
                        <div class="grilla-turnos">
                          {#each g.turnos as x, i (x.hora)}
                            <button
                              class="turno ag-num"
                              class:elegido={hora === x.hora}
                              style="--i:{i}"
                              aria-pressed={hora === x.hora}
                              onclick={() => {
                                hora = x.hora;
                                avisoHorario = null;
                              }}>{hora12(x.hora)}</button
                            >
                          {/each}
                        </div>
                      </div>
                    {/each}
                    <div class="continuar-escritorio">
                      <button class="ag-btn ag-btn-primario ag-btn-bloque" disabled={!hora} onclick={continuarHorario}>
                        {hora ? `Continuar con ${hora12(hora)}` : 'Elige una hora'}
                        <span class="material-icons" aria-hidden="true">arrow_forward</span>
                      </button>
                    </div>
                  {:else if !cargandoMes}
                    <p class="nota-vacia">Elige un día con horarios disponibles.</p>
                  {/if}
                </div>
              </div>

              <!-- ---------- 4. Datos ---------- -->
            {:else if paso === 'datos' && servicio && fecha && hora}
              <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">Tus datos</h2>
              <p class="ag-subtitulo">Solo lo necesario para confirmar tu cita.</p>
              <div class="tarjeta-cita">
                <div class="fecha-grande">
                  <span class="mes-corto">{fechaCorta(fecha).split(' ')[2]}</span>
                  <span class="dia-num ag-num">{Number(fecha.slice(8))}</span>
                </div>
                <div>
                  <strong>{servicio.nombre}</strong>
                  <p class="tenue capital">{fechaLarga(fecha)} · <span class="ag-num">{hora12(hora)}</span></p>
                  {#if profesionalElegido}<p class="tenue">Con {profesionalElegido.nombre}</p>{/if}
                </div>
                <button class="enlace cambiar" onclick={() => irA('horario')}>Cambiar</button>
              </div>

              <form class="formulario" onsubmit={reservar} novalidate>
                <div>
                  <label class="ag-etiqueta" for="nombre">Nombre completo</label>
                  <input
                    id="nombre"
                    class="ag-campo"
                    bind:value={nombre}
                    autocomplete="name"
                    maxlength="100"
                    aria-invalid={tocado.nombre && !!errorNombre}
                    aria-describedby={tocado.nombre && errorNombre ? 'error-nombre' : undefined}
                    onblur={() => (tocado.nombre = true)}
                  />
                  {#if tocado.nombre && errorNombre}<p class="ag-error" id="error-nombre"><span class="material-icons">error</span>{errorNombre}</p>{/if}
                </div>
                <div>
                  <label class="ag-etiqueta" for="numero">WhatsApp</label>
                  <div class="telefono">
                    <select class="ag-campo indicativo" bind:value={indicativo} aria-label="Indicativo del país">
                      {#each INDICATIVOS as [v, l]}<option value={v}>{l}</option>{/each}
                    </select>
                    <input
                      id="numero"
                      class="ag-campo"
                      type="tel"
                      inputmode="tel"
                      bind:value={numero}
                      autocomplete="tel-national"
                      placeholder="300 123 4567"
                      aria-invalid={tocado.numero && !!errorNumero}
                      aria-describedby="ayuda-numero"
                      onblur={() => (tocado.numero = true)}
                    />
                  </div>
                  {#if tocado.numero && errorNumero}
                    <p class="ag-error"><span class="material-icons">error</span>{errorNumero}</p>
                  {:else}
                    <p class="ag-ayuda" id="ayuda-numero">Te enviaremos un código a este WhatsApp para confirmar.</p>
                  {/if}
                </div>
                <div>
                  <label class="ag-etiqueta" for="nota">Nota para el negocio <span class="opcional">(opcional)</span></label>
                  <textarea id="nota" class="ag-campo" rows="2" maxlength="300" bind:value={nota} placeholder="¿Algo que debamos saber?"></textarea>
                </div>
                {#if errorForm}
                  <p class="ag-error" role="alert"><span class="material-icons">error</span>{errorForm}</p>
                {/if}
                <button class="ag-btn ag-btn-primario ag-btn-bloque whatsapp" type="submit" disabled={enviando}>
                  {#if enviando}
                    <span class="girando" aria-hidden="true"></span> Enviando…
                  {:else}
                    <span class="material-icons" aria-hidden="true">send</span> Recibir código por WhatsApp
                  {/if}
                </button>
              </form>

              <!-- ---------- 5. Código ---------- -->
            {:else if paso === 'codigo' && cita}
              <div class="centrado">
                <span class="burbuja-wa" aria-hidden="true"><span class="material-icons">chat</span></span>
                <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">Revisa tu WhatsApp</h2>
                <p class="ag-subtitulo">
                  Enviamos un código de 6 dígitos al <strong class="ag-num">{cita.whatsapp}</strong>. Escríbelo aquí o toca el enlace del mensaje.
                </p>
                <div class="zona-codigo">
                  <CodigoInput bind:this={codigoInput} bind:valor={codigo} deshabilitado={confirmando || segundos === 0} error={!!errorCodigo} alCompletar={confirmar} />
                </div>
                {#if errorCodigo}
                  <p class="ag-error centro" role="alert"><span class="material-icons">error</span>{errorCodigo}</p>
                {/if}
                {#if segundos > 0}
                  <p class="tenue ag-num">El código vence en {mmss(segundos)}</p>
                  <button class="ag-btn ag-btn-primario ag-btn-bloque" disabled={codigo.length < 6 || confirmando} onclick={() => confirmar(codigo)}>
                    {#if confirmando}<span class="girando" aria-hidden="true"></span> Confirmando…{:else}Confirmar cita{/if}
                  </button>
                  <div class="acciones-codigo">
                    <button class="ag-btn ag-btn-texto" disabled={esperaReenvio > 0} onclick={reenviar}>
                      <span class="material-icons" aria-hidden="true">refresh</span>
                      {esperaReenvio > 0 ? `Reenviar en ${esperaReenvio} s` : 'Reenviar código'}
                    </button>
                    <button class="ag-btn ag-btn-texto" onclick={() => irA('datos')}>Cambiar número</button>
                  </div>
                {:else}
                  <p class="aviso"><span class="material-icons">timer_off</span>El código venció y el horario se liberó.</p>
                  <button class="ag-btn ag-btn-primario ag-btn-bloque" onclick={empezarDeNuevo}>Elegir horario de nuevo</button>
                {/if}
              </div>

              <!-- ---------- 6. Listo ---------- -->
            {:else if paso === 'listo' && cita}
              <div class="centrado exito">
                <svg class="check" viewBox="0 0 64 64" aria-hidden="true">
                  <circle cx="32" cy="32" r="29" />
                  <path d="M20 33 l8 8 l16 -18" />
                </svg>
                <h2 id="paso-titulo" class="ag-titulo" tabindex="-1">¡Cita confirmada!</h2>
                <p class="ag-subtitulo">{cita.cliente_nombre}, te enviamos los detalles por WhatsApp. Te recordaremos antes de la cita.</p>
              </div>
              <div class="tarjeta-final" in:scale={{ start: 0.96, duration: t(320), delay: t(250) }}>
                <div class="fecha-grande">
                  <span class="mes-corto">{fechaCorta(cita.fecha).split(' ')[2]}</span>
                  <span class="dia-num ag-num">{Number(cita.fecha.slice(8))}</span>
                </div>
                <div class="final-detalle">
                  <strong class="capital">{fechaLarga(cita.fecha)}</strong>
                  <p class="ag-num">{hora12(cita.hora_inicio)} – {hora12(cita.hora_fin)}</p>
                  <p>{cita.servicio}{cita.precio > 0 ? ` · ${pesos(cita.precio)}` : ''}</p>
                  <p class="tenue">Con {cita.profesional.nombre}</p>
                  {#if cita.negocio.direccion}<p class="tenue"><span class="material-icons" aria-hidden="true">location_on</span> {cita.negocio.direccion}</p>{/if}
                </div>
              </div>
              <div class="acciones-final">
                <AgregarCalendario
                  datos={{
                    titulo: `${cita.servicio} · ${cita.negocio.nombre}`,
                    fecha: cita.fecha,
                    inicio: cita.hora_inicio,
                    fin: cita.hora_fin,
                    detalle: `Con ${cita.profesional.nombre}. Gestiona tu cita: ${location.origin}/cita/${cita.token}`,
                    lugar: cita.negocio.direccion,
                  }}
                />
                <a class="ag-btn ag-btn-secundario ag-btn-bloque" href={`/cita/${cita.token}`}>
                  <span class="material-icons" aria-hidden="true">manage_history</span> Ver o cancelar mi cita
                </a>
                <button class="ag-btn ag-btn-texto ag-btn-bloque" onclick={empezarDeNuevo}>Agendar otra cita</button>
              </div>
            {/if}
          </div>
        {/key}
      </section>
    </main>

    <!-- Barra inferior fija en el teléfono (patrón Fresha / Booksy) -->
    {#if paso === 'horario' && hora && fecha}
      <div class="barra-inferior" transition:fly={{ y: 80, duration: t(260) }}>
        <div class="barra-texto">
          <strong class="ag-num">{fechaCorta(fecha)} · {hora12(hora)}</strong>
          <span class="tenue">{servicio?.nombre}</span>
        </div>
        <button class="ag-btn ag-btn-primario" onclick={continuarHorario}>Continuar</button>
      </div>
    {/if}

    <footer class="pie">
      Agenda en línea con <a href="/" target="_blank" rel="noopener"><strong>Agendaservi</strong></a>
    </footer>
  {/if}
</div>

<style>
  .contenedor {
    display: grid;
    grid-template-columns: 320px minmax(0, 1fr);
    gap: 20px;
    max-width: 1120px;
    margin: 0 auto;
    padding: 32px 20px 24px;
    align-items: start;
  }
  .panel-negocio {
    padding: 24px;
    position: sticky;
    top: 24px;
  }
  .panel-paso {
    padding: 24px 28px 28px;
    min-height: 520px;
    overflow: hidden;
  }
  .negocio {
    display: flex;
    gap: 14px;
    align-items: center;
  }
  .avatar-negocio {
    width: 64px;
    height: 64px;
    font-size: 22px;
    box-shadow: 0 10px 24px -12px var(--marca);
  }
  .nombre-negocio {
    font-size: 20px;
    font-weight: 700;
    letter-spacing: -0.02em;
    line-height: 1.25;
    margin: 0;
  }
  .rubro {
    display: inline-block;
    margin: 4px 0 0;
    font-size: 13px;
    font-weight: 600;
    color: var(--marca-tinta);
  }
  .descripcion {
    margin: 16px 0 0;
    color: var(--text-2);
    font-size: 14px;
  }
  .datos-negocio {
    list-style: none;
    padding: 0;
    margin: 16px 0 0;
    display: grid;
    gap: 8px;
    font-size: 14px;
    color: var(--text-2);
  }
  .datos-negocio li {
    display: flex;
    gap: 8px;
    align-items: flex-start;
  }
  .datos-negocio .material-icons {
    color: var(--text-3);
    font-size: 18px;
  }
  .resumen {
    margin-top: 20px;
    padding-top: 20px;
    border-top: 1px dashed var(--border);
    display: grid;
    gap: 12px;
  }
  .resumen-titulo {
    margin: 0;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--text-3);
  }
  .resumen-fila {
    display: flex;
    gap: 12px;
    align-items: flex-start;
    font-size: 14px;
  }
  .resumen-fila > .material-icons {
    display: grid;
    place-items: center;
    width: 32px;
    height: 32px;
    border-radius: 10px;
    background: var(--marca-suave);
    color: var(--marca-tinta);
    font-size: 18px;
    flex: none;
  }
  .resumen-fila div {
    display: grid;
  }
  .tenue {
    color: var(--text-3);
    font-size: 14px;
    margin: 0;
  }
  .capital {
    display: inline-block;
  }
  .capital::first-letter {
    text-transform: uppercase;
  }
  .contacto {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 20px;
    font-size: 14px;
    font-weight: 600;
    color: var(--text-2);
    text-decoration: none;
  }
  .contacto:hover {
    color: var(--marca-tinta);
  }

  /* ---- Cabecera y progreso ---- */
  .cabecera-paso {
    display: flex;
    align-items: center;
    gap: 8px;
    min-height: 44px;
    margin: -6px -8px 12px;
  }
  .atras {
    width: 44px;
    padding: 0;
  }
  .progreso {
    display: flex;
    gap: 6px;
    list-style: none;
    padding: 0;
    margin: 0 0 0 auto;
  }
  .progreso li {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-weight: 600;
    color: var(--text-3);
    padding: 6px 10px;
    border-radius: 999px;
    transition: background-color 260ms var(--ease), color 260ms;
  }
  .progreso .punto {
    width: 8px;
    height: 8px;
    border-radius: 999px;
    background: var(--border);
    transition: background-color 260ms, transform 260ms var(--ease-out);
  }
  .progreso .hecho .punto {
    background: var(--marca);
  }
  .progreso .actual {
    background: var(--marca-suave);
    color: var(--text);
  }
  .progreso .actual .punto {
    background: var(--marca);
    transform: scale(1.25);
  }
  .contenido-paso h2:focus {
    outline: none;
  }

  /* ---- Servicios ---- */
  .lista-servicios {
    list-style: none;
    padding: 0;
    margin: 20px 0 0;
    display: grid;
    gap: 10px;
  }
  .lista-servicios li {
    animation: entrar 360ms var(--ease-out) both;
    animation-delay: calc(var(--i) * 40ms);
  }
  .servicio {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 16px 16px 16px 0;
    text-align: left;
    font: inherit;
    color: inherit;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 14px;
    cursor: pointer;
    overflow: hidden;
    transition: border-color 200ms, box-shadow 200ms, transform 160ms var(--ease);
  }
  .servicio:hover {
    border-color: var(--marca-borde);
    box-shadow: 0 8px 24px -16px var(--marca);
  }
  .servicio:active {
    transform: scale(0.99);
  }
  .servicio.elegido {
    border-color: var(--marca-tinta);
    box-shadow: 0 0 0 3px var(--marca-suave);
  }
  .barra-color {
    width: 4px;
    align-self: stretch;
    border-radius: 0 4px 4px 0;
    flex: none;
  }
  .servicio-texto {
    display: grid;
    gap: 4px;
    flex: 1;
    min-width: 0;
  }
  .servicio-nombre {
    font-weight: 600;
    font-size: 16px;
  }
  .servicio-desc {
    color: var(--text-2);
    font-size: 14px;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .servicio-meta {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 4px;
  }
  .chip {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-2);
    background: var(--surface-2);
    padding: 3px 8px;
    border-radius: 999px;
  }
  .chip .material-icons {
    font-size: 15px;
  }
  .precio {
    font-weight: 700;
    font-size: 15px;
  }
  .chevron {
    color: var(--text-3);
    transition: transform 200ms var(--ease);
  }
  .servicio:hover .chevron {
    transform: translateX(3px);
    color: var(--marca-tinta);
  }

  /* ---- Profesionales ---- */
  .grilla-profesionales {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
    gap: 12px;
    margin-top: 20px;
  }
  .profesional {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 8px;
    padding: 20px 12px;
    min-height: 168px;
    justify-content: center;
    text-align: center;
    font: inherit;
    color: inherit;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    cursor: pointer;
    animation: entrar 360ms var(--ease-out) both;
    animation-delay: calc(var(--i) * 40ms);
    transition: border-color 200ms, box-shadow 200ms, transform 160ms var(--ease);
  }
  .profesional:hover {
    border-color: var(--marca-borde);
    transform: translateY(-2px);
  }
  .profesional.elegido {
    border-color: var(--marca-tinta);
    box-shadow: 0 0 0 3px var(--marca-suave);
  }
  .grande {
    width: 64px;
    height: 64px;
    font-size: 20px;
  }
  .apilados {
    display: flex;
    height: 64px;
    align-items: center;
  }
  .mini {
    width: 40px;
    height: 40px;
    font-size: 13px;
    border: 3px solid var(--surface);
    margin-left: -12px;
  }
  .mini:first-child {
    margin-left: 0;
  }
  .prof-nombre {
    font-weight: 600;
  }
  .prof-cargo {
    font-size: 13px;
    color: var(--text-3);
  }
  .prof-cargo.destacado {
    display: inline-flex;
    align-items: center;
    gap: 2px;
    color: var(--marca-tinta);
    font-weight: 600;
  }
  .prof-cargo .material-icons {
    font-size: 16px;
  }

  /* ---- Calendario y horas ---- */
  .horario {
    display: grid;
    grid-template-columns: minmax(0, 1.15fr) minmax(0, 1fr);
    gap: 28px;
    margin-top: 20px;
  }
  .mes-cabecera {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .mes-nombre {
    font-size: 16px;
  }
  .nav-mes {
    width: 44px;
    padding: 0;
  }
  .semana,
  .dias {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 4px;
    text-align: center;
  }
  .semana span {
    font-size: 12px;
    font-weight: 600;
    color: var(--text-3);
    padding: 6px 0;
  }
  .dias.cargando {
    opacity: 0.55;
    transition: opacity 200ms;
  }
  .dia {
    position: relative;
    aspect-ratio: 1;
    min-height: 40px;
    border: none;
    border-radius: 12px;
    font: inherit;
    font-size: 15px;
    color: var(--text-3);
    background: transparent;
    cursor: default;
    transition: background-color 180ms, color 180ms, transform 160ms var(--ease);
  }
  .dia.libre {
    color: var(--text);
    font-weight: 600;
    background: var(--marca-suave);
    cursor: pointer;
  }
  .dia.libre::after {
    content: '';
    position: absolute;
    left: 50%;
    bottom: 6px;
    width: 4px;
    height: 4px;
    margin-left: -2px;
    border-radius: 999px;
    background: var(--marca);
  }
  .dia.libre:hover {
    transform: scale(1.06);
  }
  .dia.hoy {
    box-shadow: inset 0 0 0 1.5px var(--text-3);
  }
  .dia.elegido {
    background: var(--marca);
    color: var(--marca-texto);
    box-shadow: 0 8px 18px -10px var(--marca);
  }
  .dia.elegido::after {
    background: var(--marca-texto);
  }
  .dia:disabled {
    text-decoration: none;
  }
  .dia-elegido {
    margin: 4px 0 12px;
    font-weight: 700;
  }
  .franja + .franja {
    margin-top: 16px;
  }
  .franja-titulo {
    display: flex;
    align-items: center;
    gap: 6px;
    margin: 0 0 8px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--text-3);
  }
  .franja-titulo .material-icons {
    font-size: 16px;
  }
  .grilla-turnos {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(96px, 1fr));
    gap: 8px;
  }
  .turno {
    min-height: 44px;
    font: inherit;
    font-size: 14px;
    font-weight: 600;
    color: var(--marca-tinta);
    background: var(--surface);
    border: 1.5px solid var(--marca-borde);
    border-radius: 12px;
    cursor: pointer;
    animation: entrar 300ms var(--ease-out) both;
    animation-delay: calc(var(--i) * 18ms);
    transition: background-color 160ms, color 160ms, transform 160ms var(--ease);
  }
  .turno:hover {
    background: var(--marca-suave);
  }
  .turno:active {
    transform: scale(0.96);
  }
  .turno.elegido {
    background: var(--marca);
    color: var(--marca-texto);
    border-color: var(--marca-tinta);
  }
  .continuar-escritorio {
    margin-top: 20px;
    position: sticky;
    bottom: 0;
  }
  .aviso {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 12px 14px;
    margin: 16px 0 0;
    border-radius: 12px;
    font-size: 14px;
    background: color-mix(in srgb, var(--warn) 12%, transparent);
    color: var(--text);
  }
  .aviso .material-icons {
    color: var(--warn);
  }
  .cerrar-aviso {
    margin-left: auto;
    border: none;
    background: none;
    color: var(--text-3);
    cursor: pointer;
    min-width: 32px;
    min-height: 32px;
  }
  .nota-vacia {
    color: var(--text-3);
    font-size: 14px;
    margin: 16px 0 0;
  }
  .enlace {
    border: none;
    background: none;
    padding: 0;
    font: inherit;
    font-weight: 600;
    color: var(--marca-tinta);
    cursor: pointer;
    text-decoration: underline;
    text-underline-offset: 3px;
  }

  /* ---- Datos ---- */
  .tarjeta-cita {
    display: flex;
    gap: 14px;
    align-items: center;
    margin-top: 20px;
    padding: 14px;
    background: var(--surface-2);
    border-radius: 14px;
  }
  .tarjeta-cita p {
    margin: 2px 0 0;
  }
  .cambiar {
    margin-left: auto;
    align-self: flex-start;
    font-size: 14px;
  }
  .fecha-grande {
    display: grid;
    place-items: center;
    width: 56px;
    height: 60px;
    border-radius: 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    flex: none;
    overflow: hidden;
  }
  .mes-corto {
    width: 100%;
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    text-align: center;
    color: var(--marca-texto);
    background: var(--marca);
    padding: 2px 0;
  }
  .dia-num {
    font-size: 22px;
    font-weight: 700;
    line-height: 1;
    padding-bottom: 6px;
  }
  .formulario {
    display: grid;
    gap: 18px;
    margin-top: 24px;
    max-width: 520px;
  }
  .telefono {
    display: grid;
    grid-template-columns: 112px 1fr;
    gap: 8px;
  }
  .indicativo {
    padding-right: 6px;
  }
  textarea.ag-campo {
    resize: vertical;
    min-height: 72px;
  }
  .opcional {
    font-weight: 400;
    color: var(--text-3);
  }
  .whatsapp {
    margin-top: 4px;
  }

  /* ---- Código ---- */
  .centrado {
    display: grid;
    justify-items: center;
    text-align: center;
    gap: 8px;
    max-width: 420px;
    margin: 12px auto 0;
  }
  .centrado .ag-subtitulo {
    margin-bottom: 12px;
  }
  .burbuja-wa {
    display: grid;
    place-items: center;
    width: 72px;
    height: 72px;
    border-radius: 24px;
    background: #25d366;
    color: #fff;
    margin-bottom: 8px;
    box-shadow: 0 14px 30px -14px #25d366;
    animation: flotar 3s ease-in-out infinite;
  }
  .burbuja-wa .material-icons {
    font-size: 36px;
  }
  .zona-codigo {
    width: 100%;
    margin: 8px 0 4px;
  }
  .centro {
    justify-content: center;
  }
  .acciones-codigo {
    display: flex;
    gap: 4px;
    flex-wrap: wrap;
    justify-content: center;
  }
  .girando {
    width: 18px;
    height: 18px;
    border-radius: 999px;
    border: 2.5px solid currentColor;
    border-right-color: transparent;
    animation: girar 700ms linear infinite;
  }

  /* ---- Éxito ---- */
  .exito .ag-subtitulo {
    margin-bottom: 0;
  }
  .check {
    width: 88px;
    height: 88px;
    margin-bottom: 8px;
  }
  .check circle {
    fill: var(--ok-suave);
    stroke: var(--ok);
    stroke-width: 3;
    stroke-dasharray: 190;
    stroke-dashoffset: 190;
    animation: trazo 600ms var(--ease-out) forwards;
  }
  .check path {
    fill: none;
    stroke: var(--ok);
    stroke-width: 4;
    stroke-linecap: round;
    stroke-linejoin: round;
    stroke-dasharray: 40;
    stroke-dashoffset: 40;
    animation: trazo 420ms var(--ease-out) 420ms forwards;
  }
  .tarjeta-final {
    display: flex;
    gap: 16px;
    max-width: 460px;
    margin: 24px auto 0;
    padding: 18px;
    border-radius: 16px;
    background: var(--surface-2);
  }
  .final-detalle p {
    margin: 2px 0 0;
    font-size: 14px;
  }
  .final-detalle .material-icons {
    font-size: 16px;
  }
  .acciones-final {
    display: grid;
    gap: 10px;
    max-width: 460px;
    margin: 20px auto 0;
  }

  /* ---- Otros ---- */
  .vacio {
    display: grid;
    place-items: center;
    text-align: center;
    gap: 8px;
    min-height: 80dvh;
    padding: 24px;
    align-content: center;
  }
  .icono-vacio {
    font-size: 56px !important;
    color: var(--text-3);
  }
  .abrir-app {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 10px 16px;
    font-size: 13px;
    font-weight: 600;
    color: var(--marca-texto);
    background: var(--marca);
    text-decoration: none;
  }
  .barra-inferior {
    display: none;
  }
  .pie {
    text-align: center;
    font-size: 13px;
    color: var(--text-3);
    padding: 8px 16px 32px;
  }
  .pie a {
    color: inherit;
  }

  @keyframes entrar {
    from { opacity: 0; transform: translateY(8px); }
    to { opacity: 1; transform: none; }
  }
  @keyframes trazo {
    to { stroke-dashoffset: 0; }
  }
  @keyframes girar {
    to { transform: rotate(360deg); }
  }
  @keyframes flotar {
    0%, 100% { transform: translateY(0); }
    50% { transform: translateY(-4px); }
  }

  /* ---- Tablet ---- */
  @media (max-width: 1024px) {
    .horario {
      grid-template-columns: 1fr;
    }
    /* En una sola columna el calendario no crece de más: días de ~48 px. */
    .calendario {
      width: 100%;
      max-width: 400px;
      margin-inline: auto;
    }
  }

  /* ---- Teléfono ---- */
  @media (max-width: 900px) {
    .contenedor {
      grid-template-columns: 1fr;
      padding: 12px 12px 110px;
      gap: 12px;
    }
    .panel-negocio {
      position: static;
      padding: 16px;
    }
    .avatar-negocio {
      width: 48px;
      height: 48px;
      font-size: 17px;
    }
    .nombre-negocio {
      font-size: 18px;
    }
    .descripcion,
    .datos-negocio,
    .contacto {
      display: none;
    }
    .resumen {
      margin-top: 14px;
      padding-top: 14px;
    }
    .panel-paso {
      padding: 16px 16px 24px;
      min-height: 60dvh;
    }
    .progreso .texto-paso {
      display: none;
    }
    .progreso .actual .texto-paso {
      display: inline;
    }
    .continuar-escritorio {
      display: none;
    }
    .barra-inferior {
      display: flex;
      align-items: center;
      gap: 12px;
      position: fixed;
      left: 0;
      right: 0;
      bottom: 0;
      z-index: 20;
      padding: 12px 16px calc(12px + env(safe-area-inset-bottom));
      background: color-mix(in srgb, var(--surface) 88%, transparent);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      border-top: 1px solid var(--border);
      box-shadow: 0 -12px 30px -18px rgba(15, 23, 42, 0.3);
    }
    .barra-texto {
      display: grid;
      flex: 1;
      min-width: 0;
      font-size: 14px;
    }
    .barra-texto .tenue {
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      font-size: 13px;
    }
    .compacto .panel-negocio {
      display: none;
    }
    /* El paso ya muestra la tarjeta de la cita: no se repite arriba. */
    .ocultar-movil {
      display: none;
    }
  }

  @media (max-width: 380px) {
    .grilla-profesionales {
      grid-template-columns: 1fr 1fr;
    }
    .grilla-turnos {
      grid-template-columns: repeat(3, 1fr);
    }
    .telefono {
      grid-template-columns: 96px 1fr;
    }
  }
</style>
