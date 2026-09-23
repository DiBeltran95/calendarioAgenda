<script lang="ts">
  import { descargarIcs, enlaceGoogleCalendar, enlaceOutlook, type DatosCalendario } from './util';

  let { datos }: { datos: DatosCalendario } = $props();
  let abierto = $state(false);
</script>

<div class="agregar">
  <button class="ag-btn ag-btn-secundario ag-btn-bloque" aria-expanded={abierto} onclick={() => (abierto = !abierto)}>
    <span class="material-icons" aria-hidden="true">event</span>
    Añadir a mi calendario
    <span class="material-icons flecha" class:girada={abierto} aria-hidden="true">expand_more</span>
  </button>
  {#if abierto}
    <div class="opciones">
      <a class="opcion" href={enlaceGoogleCalendar(datos)} target="_blank" rel="noopener">
        <span class="logo google" aria-hidden="true">G</span> Google Calendar
      </a>
      <button class="opcion" onclick={() => descargarIcs(datos)}>
        <span class="material-icons" aria-hidden="true">phone_iphone</span> Apple / otro (.ics)
      </button>
      <a class="opcion" href={enlaceOutlook(datos)} target="_blank" rel="noopener">
        <span class="logo outlook" aria-hidden="true">O</span> Outlook
      </a>
    </div>
  {/if}
</div>

<style>
  .flecha {
    margin-left: auto;
    transition: transform 200ms var(--ease);
  }
  .girada {
    transform: rotate(180deg);
  }
  .opciones {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-top: 8px;
    animation: aparecer 220ms var(--ease-out);
  }
  .opcion {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 12px 6px;
    min-height: 72px;
    font: inherit;
    font-size: 12px;
    font-weight: 600;
    color: var(--text);
    text-align: center;
    text-decoration: none;
    background: var(--surface-2);
    border: 1px solid transparent;
    border-radius: 12px;
    cursor: pointer;
    transition: border-color 160ms, transform 160ms var(--ease);
  }
  .opcion:hover {
    border-color: var(--border);
  }
  .opcion:active {
    transform: scale(0.97);
  }
  .logo {
    display: grid;
    place-items: center;
    width: 24px;
    height: 24px;
    border-radius: 6px;
    font-weight: 800;
    color: #fff;
  }
  .google {
    background: conic-gradient(#4285f4 0 25%, #34a853 0 50%, #fbbc05 0 75%, #ea4335 0);
  }
  .outlook {
    background: #0a64d8;
  }
  @keyframes aparecer {
    from { opacity: 0; transform: translateY(-4px); }
    to { opacity: 1; transform: none; }
  }
</style>
