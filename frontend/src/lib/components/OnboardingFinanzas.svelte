<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  export let cuentasCount = 0;
  export let ingresosCount = 0;
  export let presupuestosCount = 0;
  export let userName = '';

  const dispatch = createEventDispatcher();

  let collapsed = false;

  $: firstName = userName ? userName.split(' ')[0] : '';

  $: steps = [
    {
      key: 'accounts',
      icon: 'account_balance_wallet',
      title: 'Agrega tus cuentas',
      desc: 'Registra tus cuentas de ahorro, efectivo, CDT y tarjetas de crédito con su saldo actual.',
      done: cuentasCount > 0,
      cta: 'Agregar cuenta',
      event: 'accounts'
    },
    {
      key: 'income',
      icon: 'payments',
      title: 'Registra tu sueldo o ingresos',
      desc: '¿Recibes un sueldo o ingreso recurrente? Planifícalo para proyectar tu mes.',
      done: ingresosCount > 0,
      cta: 'Planificar ingreso',
      event: 'income'
    },
    {
      key: 'budget',
      icon: 'pie_chart',
      title: 'Define tus presupuestos',
      desc: 'Asigna un límite mensual por categoría para controlar en qué gastas.',
      done: presupuestosCount > 0,
      cta: 'Crear presupuesto',
      event: 'budget'
    }
  ];

  $: completedCount = steps.filter(s => s.done).length;
  $: progress = Math.round((completedCount / steps.length) * 100);
  $: allDone = completedCount === steps.length;
  // El primer paso pendiente es el "activo" que se resalta
  $: activeKey = steps.find(s => !s.done)?.key ?? null;

  function handleStep(ev: string) {
    dispatch(ev);
  }

  function dismiss() {
    dispatch('dismiss');
  }
</script>

<div class="ob-card" class:done={allDone}>
  <!-- Header -->
  <div class="ob-header">
    <div class="ob-header-left">
      <div class="ob-spark">
        <i class="material-icons">{allDone ? 'celebration' : 'rocket_launch'}</i>
      </div>
      <div>
        <h4 class="ob-title">
          {#if allDone}
            ¡Todo listo{firstName ? `, ${firstName}` : ''}! 🎉
          {:else}
            Configura tus finanzas{firstName ? `, ${firstName}` : ''}
          {/if}
        </h4>
        <p class="ob-subtitle">
          {#if allDone}
            Ya tienes lo esencial para controlar tu dinero.
          {:else}
            Sigue estos pasos para empezar con el pie derecho.
          {/if}
        </p>
      </div>
    </div>
    <div class="ob-header-actions">
      <button class="ob-icon-btn" on:click={() => (collapsed = !collapsed)} title={collapsed ? 'Expandir' : 'Contraer'}>
        <i class="material-icons">{collapsed ? 'expand_more' : 'expand_less'}</i>
      </button>
      <button class="ob-icon-btn" on:click={dismiss} title="Ocultar guía">
        <i class="material-icons">close</i>
      </button>
    </div>
  </div>

  <!-- Progress -->
  <div class="ob-progress-row">
    <div class="ob-progress-track">
      <div class="ob-progress-fill" style="width: {progress}%"></div>
    </div>
    <span class="ob-progress-label">{completedCount}/{steps.length}</span>
  </div>

  {#if !collapsed}
    <!-- Steps -->
    <div class="ob-steps">
      {#each steps as step, i}
        <div class="ob-step" class:done={step.done} class:active={step.key === activeKey}>
          <div class="ob-step-marker">
            {#if step.done}
              <i class="material-icons">check</i>
            {:else}
              <span>{i + 1}</span>
            {/if}
          </div>
          <div class="ob-step-body">
            <div class="ob-step-head">
              <i class="material-icons ob-step-icon">{step.icon}</i>
              <span class="ob-step-title">{step.title}</span>
              {#if step.done}
                <span class="ob-badge-done">Hecho</span>
              {/if}
            </div>
            <p class="ob-step-desc">{step.desc}</p>
            {#if !step.done}
              <button class="ob-step-btn" on:click={() => handleStep(step.event)}>
                <i class="material-icons">add</i> {step.cta}
              </button>
            {/if}
          </div>
        </div>
      {/each}
    </div>

    <!-- Footer -->
    <div class="ob-footer">
      {#if allDone}
        <button class="ob-finish-btn" on:click={dismiss}>
          <i class="material-icons">check_circle</i> Finalizar y ocultar
        </button>
      {:else}
        <button class="ob-dismiss-link" on:click={dismiss}>No mostrar de nuevo</button>
      {/if}
    </div>
  {/if}
</div>

<style>
  .ob-card {
    background: linear-gradient(160deg, rgba(255, 215, 0, 0.06), rgba(16, 79, 49, 0.12));
    border: 1px solid rgba(255, 215, 0, 0.22);
    border-radius: 16px;
    padding: 16px;
    margin: 12px 0 16px 0;
    box-shadow: 0 8px 30px rgba(0, 0, 0, 0.25);
    animation: obFadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .ob-card.done {
    border-color: rgba(52, 228, 126, 0.35);
    background: linear-gradient(160deg, rgba(52, 228, 126, 0.08), rgba(16, 79, 49, 0.15));
  }

  @keyframes obFadeIn {
    from { opacity: 0; transform: translateY(-8px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .ob-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 10px;
  }
  .ob-header-left {
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .ob-spark {
    width: 40px;
    height: 40px;
    flex-shrink: 0;
    border-radius: 12px;
    background: rgba(255, 215, 0, 0.15);
    border: 1px solid rgba(255, 215, 0, 0.3);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .ob-card.done .ob-spark {
    background: rgba(52, 228, 126, 0.15);
    border-color: rgba(52, 228, 126, 0.35);
  }
  .ob-spark i { color: #FFD700; font-size: 22px; }
  .ob-card.done .ob-spark i { color: #34E47E; }

  .ob-title {
    margin: 0;
    font-size: 0.98rem;
    font-weight: 700;
    color: var(--text-primary);
  }
  .ob-subtitle {
    margin: 2px 0 0 0;
    font-size: 0.76rem;
    color: var(--text-secondary);
    line-height: 1.35;
  }

  .ob-header-actions { display: flex; gap: 4px; }
  .ob-icon-btn {
    background: rgba(255, 255, 255, 0.04);
    border: none;
    border-radius: 8px;
    width: 30px;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    color: var(--text-secondary);
    transition: background 0.2s, color 0.2s;
  }
  .ob-icon-btn:hover { background: rgba(255, 255, 255, 0.1); color: var(--text-primary); }
  .ob-icon-btn i { font-size: 18px; }

  .ob-progress-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-top: 14px;
  }
  .ob-progress-track {
    flex: 1;
    height: 7px;
    background: rgba(255, 255, 255, 0.08);
    border-radius: 99px;
    overflow: hidden;
  }
  .ob-progress-fill {
    height: 100%;
    background: linear-gradient(90deg, #FFD700, #34E47E);
    border-radius: 99px;
    transition: width 0.5s cubic-bezier(0.16, 1, 0.3, 1);
  }
  .ob-progress-label {
    font-size: 0.72rem;
    font-weight: 700;
    color: var(--text-secondary);
    min-width: 26px;
    text-align: right;
  }

  .ob-steps {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 16px;
  }
  .ob-step {
    display: flex;
    gap: 12px;
    padding: 12px;
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.02);
    border: 1px solid rgba(255, 255, 255, 0.05);
    transition: all 0.25s ease;
  }
  .ob-step.active {
    background: rgba(255, 215, 0, 0.06);
    border-color: rgba(255, 215, 0, 0.25);
  }
  .ob-step.done { opacity: 0.7; }

  .ob-step-marker {
    width: 26px;
    height: 26px;
    flex-shrink: 0;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.06);
    border: 1px solid rgba(255, 255, 255, 0.12);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.78rem;
    font-weight: 700;
    color: var(--text-secondary);
  }
  .ob-step.active .ob-step-marker {
    background: rgba(255, 215, 0, 0.2);
    border-color: #FFD700;
    color: #FFD700;
  }
  .ob-step.done .ob-step-marker {
    background: rgba(52, 228, 126, 0.18);
    border-color: #34E47E;
    color: #34E47E;
  }
  .ob-step-marker i { font-size: 16px; }

  .ob-step-body { flex: 1; min-width: 0; }
  .ob-step-head {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .ob-step-icon { font-size: 16px !important; color: #FFD700; }
  .ob-step.done .ob-step-icon { color: #34E47E; }
  .ob-step-title {
    font-size: 0.85rem;
    font-weight: 600;
    color: var(--text-primary);
  }
  .ob-badge-done {
    margin-left: auto;
    font-size: 0.62rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    color: #34E47E;
    background: rgba(52, 228, 126, 0.12);
    border: 1px solid rgba(52, 228, 126, 0.25);
    padding: 2px 8px;
    border-radius: 99px;
  }
  .ob-step-desc {
    margin: 5px 0 0 0;
    font-size: 0.74rem;
    color: var(--text-secondary);
    line-height: 1.4;
  }
  .ob-step-btn {
    margin-top: 10px;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    background: #FFD700;
    color: #000;
    border: none;
    border-radius: 8px;
    padding: 7px 12px;
    font-size: 0.78rem;
    font-weight: 700;
    cursor: pointer;
    transition: transform 0.15s ease, box-shadow 0.2s ease;
  }
  .ob-step-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 12px rgba(255, 215, 0, 0.3);
  }
  .ob-step-btn i { font-size: 16px; }

  .ob-footer {
    margin-top: 14px;
    display: flex;
    justify-content: center;
  }
  .ob-dismiss-link {
    background: none;
    border: none;
    color: var(--text-secondary);
    font-size: 0.74rem;
    cursor: pointer;
    text-decoration: underline;
    opacity: 0.7;
    transition: opacity 0.2s;
  }
  .ob-dismiss-link:hover { opacity: 1; }

  .ob-finish-btn {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: #34E47E;
    color: #06210f;
    border: none;
    border-radius: 10px;
    padding: 9px 18px;
    font-size: 0.82rem;
    font-weight: 700;
    cursor: pointer;
    transition: transform 0.15s ease, box-shadow 0.2s ease;
  }
  .ob-finish-btn:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 14px rgba(52, 228, 126, 0.35);
  }
  .ob-finish-btn i { font-size: 18px; }
</style>
