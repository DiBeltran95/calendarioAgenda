<script lang="ts">
  // agendaservi.com/cita/<token>[?c=código]
  // Enlace que llega por WhatsApp: confirma la reserva con un toque, muestra
  // el estado de la cita y permite añadirla al calendario o cancelarla.
  import '@fontsource/inter/400.css';
  import '@fontsource/inter/500.css';
  import '@fontsource/inter/600.css';
  import '@fontsource/inter/700.css';
  import './tema.css';
  import { onMount, tick } from 'svelte';
  import { fade, fly, scale } from 'svelte/transition';
  import { agendaApi, ErrorApi, type CitaPublica } from './api';
  import CodigoInput from './CodigoInput.svelte';
  import AgregarCalendario from './AgregarCalendario.svelte';
  import { enlaceWhatsApp, fechaCorta, fechaLarga, hora12, pesos, reduceMovimiento, textoSobre } from './util';

  let { token }: { token: string } = $props();
  const t = (ms: number) => (reduceMovimiento() ? 0 : ms);

  let cita = $state<CitaPublica | null>(null);
  let error = $state<string | null>(null);
  let recienConfirmada = $state(false);
  let codigo = $state('');
  let errorCodigo = $state<string | null>(null);
  let confirmando = $state(false);
  let preguntandoCancelar = $state(false);
  let motivo = $state('');
  let cancelando = $state(false);
  let codigoInput: ReturnType<typeof CodigoInput> | undefined = $state();
  let errorCancelar = $state<string | null>(null);

  const color = $derived(cita?.negocio.color ?? '#2563eb');

  onMount(async () => {
    try {
      cita = await agendaApi.cita(token);
      document.title = `Tu cita · ${cita.negocio.nombre}`;
      const c = new URLSearchParams(location.search).get('c');
      if (c && cita.estado === 'pendiente') {
        // Se quita el código de la URL (no debe quedar en el historial).
        history.replaceState(null, '', location.pathname);
        await confirmar(c);
      }
    } catch (e) {
      error = e instanceof ErrorApi && e.status === 404 ? 'no-existe' : (e as Error).message;
    }
  });

  async function confirmar(c: string) {
    if (!cita || confirmando) return;
    confirmando = true;
    errorCodigo = null;
    try {
      cita = await agendaApi.confirmar(token, c);
      recienConfirmada = true;
    } catch (e) {
      errorCodigo = (e as Error).message;
      if ((e as ErrorApi).status === 410) cita = { ...cita, estado: 'expirada' };
    } finally {
      confirmando = false;
    }
    if (errorCodigo && cita?.estado === 'pendiente') tick().then(() => codigoInput?.limpiar());
  }

  async function cancelar() {
    cancelando = true;
    errorCancelar = null;
    try {
      cita = await agendaApi.cancelar(token, motivo.trim() || undefined);
      preguntandoCancelar = false;
    } catch (e) {
      errorCancelar = (e as Error).message;
    } finally {
      cancelando = false;
    }
  }

  const ESTADOS = {
    pendiente: { icono: 'hourglass_top', texto: 'Esperando confirmación', clase: 'pendiente' },
    confirmada: { icono: 'check_circle', texto: 'Confirmada', clase: 'ok' },
    completada: { icono: 'task_alt', texto: 'Completada', clase: 'ok' },
    cancelada: { icono: 'cancel', texto: 'Cancelada', clase: 'mal' },
    no_asistio: { icono: 'person_off', texto: 'No asististe', clase: 'mal' },
    expirada: { icono: 'timer_off', texto: 'Reserva vencida', clase: 'mal' },
  } as const;
</script>

<div class="ag-root" style="--marca:{color}; --marca-texto:{textoSobre(color)}">
  <main class="pagina">
    {#if error === 'no-existe'}
      <div class="vacio" in:fade={{ duration: t(200) }}>
        <span class="material-icons icono-vacio" aria-hidden="true">search_off</span>
        <h1 class="ag-titulo">No encontramos esta cita</h1>
        <p class="ag-subtitulo">Revisa que el enlace esté completo.</p>
      </div>
    {:else if error}
      <div class="vacio">
        <span class="material-icons icono-vacio" aria-hidden="true">wifi_off</span>
        <h1 class="ag-titulo">No pudimos cargar tu cita</h1>
        <p class="ag-subtitulo">{error}</p>
        <button class="ag-btn ag-btn-primario" onclick={() => location.reload()}>Reintentar</button>
      </div>
    {:else if !cita || (confirmando && !recienConfirmada && cita.estado === 'pendiente' && !codigo)}
      <div class="ag-card tarjeta" aria-busy="true">
        <div class="ag-esqueleto" style="width:56px;height:56px;border-radius:999px;margin:0 auto"></div>
        <div class="ag-esqueleto" style="width:60%;height:22px;margin:16px auto 0"></div>
        <div class="ag-esqueleto" style="height:120px;margin-top:24px"></div>
      </div>
    {:else}
      {@const e = ESTADOS[cita.estado]}
      <article class="ag-card tarjeta" in:fly={{ y: 12, duration: t(320) }}>
        <header class="cabecera">
          <span class="ag-avatar logo" style="background:{color}; color:{textoSobre(color)}">{cita.negocio.nombre.slice(0, 1)}</span>
          <div>
            <p class="negocio">{cita.negocio.nombre}</p>
            <span class="estado {e.clase}"><span class="material-icons" aria-hidden="true">{e.icono}</span>{e.texto}</span>
          </div>
        </header>

        {#if recienConfirmada}
          <div class="celebracion" in:scale={{ start: 0.9, duration: t(360) }}>
            <svg class="check" viewBox="0 0 64 64" aria-hidden="true"><circle cx="32" cy="32" r="29" /><path d="M20 33 l8 8 l16 -18" /></svg>
            <h1 class="ag-titulo">¡Listo, {cita.cliente_nombre}!</h1>
            <p class="ag-subtitulo">Tu cita quedó confirmada. Te recordaremos antes por WhatsApp.</p>
          </div>
        {/if}

        <div class="detalle" class:tachado={cita.estado === 'cancelada' || cita.estado === 'expirada'}>
          <div class="fecha-grande">
            <span class="mes-corto">{fechaCorta(cita.fecha).split(' ')[2]}</span>
            <span class="dia-num ag-num">{Number(cita.fecha.slice(8))}</span>
          </div>
          <div class="lineas">
            <strong class="capital">{fechaLarga(cita.fecha)}</strong>
            <p class="ag-num">{hora12(cita.hora_inicio)} – {hora12(cita.hora_fin)}</p>
            <p>{cita.servicio}{cita.precio > 0 ? ` · ${pesos(cita.precio)}` : ''}</p>
            <p class="tenue">Con {cita.profesional.nombre}</p>
            {#if cita.negocio.direccion}
              <a class="tenue direccion" href={`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(cita.negocio.direccion)}`} target="_blank" rel="noopener">
                <span class="material-icons" aria-hidden="true">location_on</span>{cita.negocio.direccion}
              </a>
            {/if}
          </div>
        </div>

        {#if cita.estado === 'pendiente'}
          <section class="bloque">
            <h2 class="bloque-titulo">Confirma con el código de WhatsApp</h2>
            <p class="tenue">Lo enviamos al {cita.whatsapp}.</p>
            <div class="zona-codigo">
              <CodigoInput bind:this={codigoInput} bind:valor={codigo} deshabilitado={confirmando} error={!!errorCodigo} alCompletar={confirmar} />
            </div>
            {#if errorCodigo}<p class="ag-error" role="alert"><span class="material-icons">error</span>{errorCodigo}</p>{/if}
            <button class="ag-btn ag-btn-primario ag-btn-bloque" disabled={codigo.length < 6 || confirmando} onclick={() => confirmar(codigo)}>
              {confirmando ? 'Confirmando…' : 'Confirmar cita'}
            </button>
          </section>
        {:else if cita.estado === 'cancelada'}
          <p class="aviso"><span class="material-icons" aria-hidden="true">info</span>Esta cita fue cancelada{cita.motivo_cancelacion ? `: ${cita.motivo_cancelacion}` : '.'}</p>
        {:else if cita.estado === 'expirada'}
          <p class="aviso"><span class="material-icons" aria-hidden="true">info</span>La reserva no se confirmó a tiempo y el horario se liberó.</p>
        {/if}

        <div class="acciones">
          {#if cita.estado === 'confirmada'}
            <AgregarCalendario
              datos={{
                titulo: `${cita.servicio} · ${cita.negocio.nombre}`,
                fecha: cita.fecha,
                inicio: cita.hora_inicio,
                fin: cita.hora_fin,
                detalle: `Con ${cita.profesional.nombre}. Gestiona tu cita: ${location.href}`,
                lugar: cita.negocio.direccion,
              }}
            />
          {/if}
          {#if cita.negocio.whatsapp}
            <a class="ag-btn ag-btn-secundario ag-btn-bloque" href={enlaceWhatsApp(cita.negocio.whatsapp, `Hola, tengo una cita el ${fechaLarga(cita.fecha)} a las ${hora12(cita.hora_inicio)}.`)} target="_blank" rel="noopener">
              <span class="material-icons" aria-hidden="true">chat</span> Escribir al negocio
            </a>
          {/if}
          {#if cita.estado !== 'confirmada' && cita.estado !== 'pendiente'}
            <a class="ag-btn ag-btn-primario ag-btn-bloque" href={`/agenda/${cita.negocio.slug}`}>
              <span class="material-icons" aria-hidden="true">event_available</span> Agendar una nueva cita
            </a>
          {/if}
          {#if cita.puede_cancelar && !preguntandoCancelar}
            <button class="ag-btn ag-btn-texto ag-btn-bloque cancelar" onclick={() => (preguntandoCancelar = true)}>Cancelar cita</button>
          {/if}
        </div>

        {#if preguntandoCancelar}
          <div class="bloque confirmar-cancelar" transition:fly={{ y: 8, duration: t(220) }} role="alertdialog" aria-modal="false" aria-labelledby="titulo-cancelar">
            <h2 class="bloque-titulo" id="titulo-cancelar">¿Cancelar tu cita?</h2>
            <p class="tenue">El horario quedará libre para otra persona. Avisaremos al negocio.</p>
            <label class="ag-etiqueta" for="motivo">Motivo <span class="tenue">(opcional)</span></label>
            <input id="motivo" class="ag-campo" bind:value={motivo} maxlength="200" placeholder="Ej.: me surgió un viaje" />
            {#if errorCancelar}<p class="ag-error" role="alert"><span class="material-icons">error</span>{errorCancelar}</p>{/if}
            <div class="dos">
              <button class="ag-btn ag-btn-secundario" onclick={() => (preguntandoCancelar = false)}>Mantener</button>
              <button class="ag-btn ag-btn-peligro" disabled={cancelando} onclick={cancelar}>{cancelando ? 'Cancelando…' : 'Sí, cancelar'}</button>
            </div>
          </div>
        {/if}
      </article>
    {/if}
    <footer class="pie">Agenda en línea con <a href="/"><strong>Agendaservi</strong></a></footer>
  </main>
</div>

<style>
  .pagina {
    max-width: 520px;
    margin: 0 auto;
    padding: 32px 16px;
  }
  .tarjeta {
    padding: 24px;
  }
  .cabecera {
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .logo {
    width: 48px;
    height: 48px;
    font-size: 20px;
  }
  .negocio {
    margin: 0;
    font-weight: 700;
    font-size: 17px;
  }
  .estado {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-top: 4px;
    padding: 2px 10px 2px 6px;
    border-radius: 999px;
    font-size: 13px;
    font-weight: 600;
  }
  .estado .material-icons {
    font-size: 16px;
  }
  .estado.ok {
    background: var(--ok-suave);
    color: var(--ok);
  }
  .estado.pendiente {
    background: color-mix(in srgb, var(--warn) 14%, transparent);
    color: var(--warn);
  }
  .estado.mal {
    background: var(--danger-suave);
    color: var(--danger);
  }
  .celebracion {
    text-align: center;
    margin-top: 20px;
  }
  .check {
    width: 76px;
    height: 76px;
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
  .detalle {
    display: flex;
    gap: 16px;
    margin-top: 20px;
    padding: 16px;
    border-radius: 16px;
    background: var(--surface-2);
    transition: opacity 300ms;
  }
  .detalle.tachado {
    opacity: 0.6;
  }
  .detalle.tachado strong {
    text-decoration: line-through;
  }
  .lineas p {
    margin: 2px 0 0;
    font-size: 14px;
  }
  .tenue {
    color: var(--text-3);
    font-size: 14px;
    margin: 0;
  }
  .direccion {
    display: flex;
    gap: 4px;
    align-items: center;
    margin-top: 4px;
    text-decoration: none;
  }
  .direccion:hover {
    color: var(--marca-tinta);
  }
  .direccion .material-icons {
    font-size: 16px;
  }
  .capital {
    display: inline-block;
  }
  .capital::first-letter {
    text-transform: uppercase;
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
  .bloque {
    display: grid;
    gap: 10px;
    margin-top: 20px;
  }
  .bloque-titulo {
    margin: 0;
    font-size: 16px;
    font-weight: 700;
  }
  .zona-codigo {
    margin: 6px 0;
  }
  .acciones {
    display: grid;
    gap: 10px;
    margin-top: 20px;
  }
  .cancelar {
    color: var(--danger);
  }
  .confirmar-cancelar {
    padding: 16px;
    border-radius: 14px;
    border: 1px solid var(--danger-suave);
    background: color-mix(in srgb, var(--danger) 5%, var(--surface));
  }
  .dos {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-top: 4px;
  }
  .dos .ag-btn {
    padding: 0 12px;
    white-space: nowrap;
  }
  .aviso {
    display: flex;
    gap: 8px;
    align-items: center;
    margin: 16px 0 0;
    padding: 12px 14px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 14px;
    color: var(--text-2);
  }
  .vacio {
    display: grid;
    gap: 8px;
    justify-items: center;
    text-align: center;
    padding: 48px 0;
  }
  .icono-vacio {
    font-size: 56px !important;
    color: var(--text-3);
  }
  .pie {
    text-align: center;
    font-size: 13px;
    color: var(--text-3);
    padding: 24px 0 8px;
  }
  .pie a {
    color: inherit;
  }
  @keyframes trazo {
    to {
      stroke-dashoffset: 0;
    }
  }
</style>
