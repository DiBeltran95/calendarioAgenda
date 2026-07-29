<script lang="ts">
  import { createEventDispatcher, onMount, onDestroy, tick } from 'svelte';

  export let target: string;          // CSS selector del elemento a resaltar
  export let title = '';
  export let description = '';
  export let icon = 'lightbulb';
  export let cta = 'Entendido';       // botón principal (cierra)
  export let cta2 = '';               // botón secundario opcional (acción)
  export let accent = '#FFD700';

  const dispatch = createEventDispatcher();
  const PAD = 8;

  let rect: { top: number; left: number; width: number; height: number } | null = null;
  let popH = 0;
  let raf = 0;

  function loop() {
    const el = target ? (document.querySelector(target) as HTMLElement | null) : null;
    if (el) {
      const r = el.getBoundingClientRect();
      rect = { top: r.top, left: r.left, width: r.width, height: r.height };
    } else {
      rect = null;
    }
    raf = requestAnimationFrame(loop);
  }

  onMount(async () => {
    const el = target ? (document.querySelector(target) as HTMLElement | null) : null;
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'center' });
    await tick();
    loop();
  });
  onDestroy(() => cancelAnimationFrame(raf));

  $: vw = typeof window !== 'undefined' ? window.innerWidth : 360;
  $: vh = typeof window !== 'undefined' ? window.innerHeight : 640;
  $: popW = Math.min(330, vw - 24);

  $: spot = rect
    ? { top: rect.top - PAD, left: rect.left - PAD, width: rect.width + PAD * 2, height: rect.height + PAD * 2 }
    : null;

  // Colocar el popover debajo si hay espacio; si no, arriba; si no hay objetivo, centrado.
  $: placeBelow = rect ? rect.top + rect.height + 18 + popH < vh : false;
  $: popTop = rect
    ? (placeBelow ? rect.top + rect.height + PAD + 12 : Math.max(12, rect.top - PAD - 12 - popH))
    : vh / 2 - popH / 2;
  $: popLeft = rect
    ? Math.min(Math.max(12, rect.left + rect.width / 2 - popW / 2), vw - popW - 12)
    : vw / 2 - popW / 2;

  function done() { dispatch('next'); }
  function action() { dispatch('action'); }
  function skip() { dispatch('skip'); }
</script>

<div class="cm-overlay" role="presentation">
  {#if spot}
    <div class="cm-spot" style="top:{spot.top}px; left:{spot.left}px; width:{spot.width}px; height:{spot.height}px; --accent:{accent};"></div>
  {:else}
    <div class="cm-dim"></div>
  {/if}

  <div class="cm-pop" bind:offsetHeight={popH} style="top:{popTop}px; left:{popLeft}px; width:{popW}px; --accent:{accent};">
    <button class="cm-close" on:click={skip} title="Cerrar">
      <i class="material-icons">close</i>
    </button>
    <div class="cm-head">
      <span class="cm-icon"><i class="material-icons">{icon}</i></span>
      <h4 class="cm-title">{title}</h4>
    </div>
    <p class="cm-desc">{description}</p>
    <div class="cm-foot">
      {#if cta2}
        <button class="cm-btn-ghost" on:click={action}>{cta2}</button>
      {/if}
      <button class="cm-btn-primary" on:click={done}>{cta}</button>
    </div>
  </div>
</div>

<style>
  .cm-overlay {
    position: fixed;
    inset: 0;
    z-index: 99999;
    pointer-events: auto;
  }
  .cm-dim {
    position: absolute;
    inset: 0;
    background: rgba(0, 0, 0, 0.72);
    animation: cmFade 0.3s ease;
  }
  .cm-spot {
    position: absolute;
    border-radius: 14px;
    box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.72);
    outline: 2px solid var(--accent);
    pointer-events: none;
    transition: top 0.25s ease, left 0.25s ease, width 0.25s ease, height 0.25s ease;
  }
  .cm-spot::after {
    content: '';
    position: absolute;
    inset: -3px;
    border-radius: 17px;
    border: 2px solid var(--accent);
    animation: cmRing 1.7s ease-out infinite;
  }

  .cm-pop {
    position: absolute;
    background: var(--bg-secondary, #1f2c33);
    border: 1px solid rgba(255, 255, 255, 0.09);
    border-radius: 16px;
    padding: 16px 16px 14px;
    box-shadow: 0 18px 55px rgba(0, 0, 0, 0.55);
    pointer-events: auto;
    animation: cmIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    transition: top 0.25s ease, left 0.25s ease;
  }
  .cm-close {
    position: absolute;
    top: 8px;
    right: 8px;
    background: rgba(255, 255, 255, 0.05);
    border: none;
    border-radius: 8px;
    width: 26px;
    height: 26px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    color: var(--text-secondary, #9fb0ad);
    transition: background 0.2s;
  }
  .cm-close:hover { background: rgba(255, 255, 255, 0.12); }
  .cm-close i { font-size: 16px; }

  .cm-head {
    display: flex;
    align-items: center;
    gap: 10px;
    padding-right: 28px;
  }
  .cm-icon {
    width: 34px;
    height: 34px;
    flex-shrink: 0;
    border-radius: 10px;
    background: color-mix(in srgb, var(--accent) 16%, transparent);
    border: 1px solid color-mix(in srgb, var(--accent) 35%, transparent);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .cm-icon i { color: var(--accent); font-size: 19px; }
  .cm-title {
    margin: 0;
    font-size: 0.95rem;
    font-weight: 700;
    color: var(--text-primary, #e9edef);
  }
  .cm-desc {
    margin: 11px 0 14px;
    font-size: 0.82rem;
    line-height: 1.5;
    color: var(--text-secondary, #b9c4c2);
  }
  .cm-foot {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
  }
  .cm-btn-primary {
    background: var(--accent);
    color: #000;
    border: none;
    border-radius: 9px;
    padding: 8px 16px;
    font-size: 0.82rem;
    font-weight: 700;
    cursor: pointer;
    transition: transform 0.15s ease, box-shadow 0.2s ease;
  }
  .cm-btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 5px 16px color-mix(in srgb, var(--accent) 40%, transparent);
  }
  .cm-btn-ghost {
    background: transparent;
    color: var(--text-primary, #e9edef);
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 9px;
    padding: 8px 14px;
    font-size: 0.82rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.2s;
  }
  .cm-btn-ghost:hover { background: rgba(255, 255, 255, 0.07); }

  @keyframes cmRing {
    0% { transform: scale(1); opacity: 0.75; }
    100% { transform: scale(1.07); opacity: 0; }
  }
  @keyframes cmFade {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  @keyframes cmIn {
    from { opacity: 0; transform: translateY(8px) scale(0.98); }
    to { opacity: 1; transform: translateY(0) scale(1); }
  }
</style>
