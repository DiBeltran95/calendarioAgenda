<script lang="ts">
  import { navigate } from './lib/router';
  import { onMount } from 'svelte';

  let visible = false;
  let cardHovered: 'personal' | 'empresa' | null = null;
  let empresaClicked = false;

  const user = JSON.parse(localStorage.getItem('user') || '{}');
  const userName: string = user.nombre ? user.nombre.split(' ')[0] : 'Usuario';

  onMount(() => {
    window.scrollTo(0, 0);
    setTimeout(() => (visible = true), 50);
  });

  function goPersonal() {
    navigate('/dashboard');
  }

  function goEmpresa() {
    empresaClicked = true;
    setTimeout(() => (empresaClicked = false), 3000);
  }

  function handleLogout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    navigate('/login');
  }
</script>

<main class="min-h-screen relative flex flex-col items-center justify-center p-6 overflow-hidden bg-[#09090b]">

  <!-- Orbs de fondo animados -->
  <div class="orb orb-cyan"></div>
  <div class="orb orb-indigo"></div>
  <div class="orb orb-purple"></div>

  <!-- Grid de puntos de fondo -->
  <div class="dot-grid"></div>

  <!-- Botón salir -->
  <button
    type="button"
    onclick={handleLogout}
    class="absolute top-5 right-5 z-20 flex items-center gap-2 px-4 py-2 rounded-xl text-sm text-gray-400 hover:text-white border border-white/10 hover:border-white/20 bg-white/5 hover:bg-white/10 backdrop-blur-md transition-all duration-300"
  >
    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
      <polyline points="16 17 21 12 16 7"/>
      <line x1="21" y1="12" x2="9" y2="12"/>
    </svg>
    Salir
  </button>

  <!-- Contenido principal -->
  <div class="relative z-10 w-full max-w-5xl flex flex-col items-center" class:fade-in={visible}>

    <!-- Header -->
    <div class="text-center mb-16">
      <div class="relative inline-block mb-6">
        <div class="logo-glow"></div>
        <img src="/logo22.png" alt="Agendaservi" class="relative w-20 h-20 object-contain" />
      </div>
      <p class="text-sm font-semibold text-cyan-400 tracking-[0.25em] uppercase mb-3">Bienvenido de vuelta</p>
      <h1 class="text-5xl font-black text-white mb-4 leading-tight">
        Hola, <span class="gradient-text">{userName}</span>
      </h1>
      <p class="text-gray-400 text-lg">¿Cómo deseas continuar hoy?</p>
    </div>

    <!-- Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-8 w-full max-w-3xl">

      <!-- Card Personal -->
      <button
        type="button"
        onclick={goPersonal}
        onmouseenter={() => (cardHovered = 'personal')}
        onmouseleave={() => (cardHovered = null)}
        class="card-btn group relative overflow-hidden rounded-3xl border border-white/10 bg-white/5 backdrop-blur-xl p-8 text-left transition-all duration-500 hover:border-cyan-500/50 hover:bg-white/8 hover:shadow-[0_0_60px_rgba(6,182,212,0.2)] hover:-translate-y-2"
      >
        <!-- Brillo de hover -->
        <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 bg-gradient-to-br from-cyan-500/10 to-indigo-600/10 rounded-3xl"></div>

        <!-- Icono animado -->
        <div class="relative mb-6">
          <div class="icon-wrapper icon-personal {cardHovered === 'personal' ? 'icon-active' : ''}">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-10 h-10 text-cyan-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
              <circle cx="12" cy="7" r="4"/>
            </svg>
          </div>
        </div>

        <h2 class="text-2xl font-bold text-white mb-2 group-hover:text-cyan-300 transition-colors duration-300">Personal</h2>
        <p class="text-gray-400 text-sm leading-relaxed mb-6">
          Tu espacio personal: calendarios, finanzas, ciclos, hábitos y mucho más.
        </p>

        <!-- Tags de módulos -->
        <div class="flex flex-wrap gap-2 mb-6">
          {#each ['Finanzas', 'Calendario', 'Ciclo', 'Hábitos', 'Notas'] as tag}
            <span class="tag-personal">{tag}</span>
          {/each}
        </div>

        <!-- CTA -->
        <div class="flex items-center gap-2 text-cyan-400 font-semibold text-sm group-hover:gap-4 transition-all duration-300">
          <span>Ingresar</span>
          <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 transition-transform duration-300 group-hover:translate-x-1" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <line x1="5" y1="12" x2="19" y2="12"/>
            <polyline points="12 5 19 12 12 19"/>
          </svg>
        </div>

        <!-- Línea decorativa inferior -->
        <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-cyan-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
      </button>

      <!-- Card Empresa -->
      <button
        type="button"
        onclick={goEmpresa}
        onmouseenter={() => (cardHovered = 'empresa')}
        onmouseleave={() => (cardHovered = null)}
        class="card-btn group relative overflow-hidden rounded-3xl border border-white/10 bg-white/5 backdrop-blur-xl p-8 text-left transition-all duration-500 hover:border-indigo-500/50 hover:bg-white/8 hover:shadow-[0_0_60px_rgba(99,102,241,0.2)] hover:-translate-y-2"
      >
        <div class="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-500 bg-gradient-to-br from-indigo-500/10 to-purple-600/10 rounded-3xl"></div>

        <!-- Badge "Próximamente" -->
        <div class="absolute top-5 right-5 px-3 py-1 rounded-full bg-indigo-500/20 border border-indigo-500/40 text-indigo-300 text-xs font-semibold tracking-wider">
          PRÓXIMAMENTE
        </div>

        <!-- Icono animado -->
        <div class="relative mb-6">
          <div class="icon-wrapper icon-empresa {cardHovered === 'empresa' ? 'icon-active' : ''}">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-10 h-10 text-indigo-400" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <rect x="2" y="7" width="20" height="14" rx="2"/>
              <path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/>
              <line x1="12" y1="12" x2="12" y2="16"/>
              <line x1="10" y1="14" x2="14" y2="14"/>
            </svg>
          </div>
        </div>

        <h2 class="text-2xl font-bold text-white mb-2 group-hover:text-indigo-300 transition-colors duration-300">Empresa</h2>
        <p class="text-gray-400 text-sm leading-relaxed mb-6">
          Gestión empresarial, equipos, facturación y reportes avanzados para tu negocio.
        </p>

        <!-- Tags -->
        <div class="flex flex-wrap gap-2 mb-6">
          {#each ['Equipos', 'Reportes', 'Facturación', 'Analytics'] as tag}
            <span class="tag-empresa">{tag}</span>
          {/each}
        </div>

        <!-- Mensaje al hacer click -->
        {#if empresaClicked}
          <div class="flex items-center gap-2 text-indigo-300 font-semibold text-sm animate-pulse">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <line x1="12" y1="8" x2="12" y2="12"/>
              <line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            <span>Estamos trabajando en este módulo...</span>
          </div>
        {:else}
          <div class="flex items-center gap-2 text-indigo-400/60 font-semibold text-sm">
            <span>Disponible pronto</span>
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          </div>
        {/if}

        <div class="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-transparent via-indigo-500 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
      </button>

    </div>

    <!-- Footer -->
    <p class="mt-16 text-gray-600 text-xs tracking-widest uppercase">Control Financiero · Tu plataforma inteligente</p>
  </div>
</main>

<style>
  /* Orbs */
  .orb {
    position: absolute;
    border-radius: 9999px;
    filter: blur(100px);
    animation: blob 8s infinite;
    pointer-events: none;
  }
  .orb-cyan {
    width: 450px; height: 450px;
    top: -15%; right: -10%;
    background: rgba(6, 182, 212, 0.18);
    animation-delay: 0s;
  }
  .orb-indigo {
    width: 400px; height: 400px;
    top: 30%; left: -12%;
    background: rgba(99, 102, 241, 0.18);
    animation-delay: 2.5s;
  }
  .orb-purple {
    width: 350px; height: 350px;
    bottom: -15%; right: 25%;
    background: rgba(168, 85, 247, 0.15);
    animation-delay: 5s;
  }

  @keyframes blob {
    0%   { transform: translate(0,   0)   scale(1);   }
    33%  { transform: translate(30px, -40px) scale(1.08); }
    66%  { transform: translate(-20px, 25px) scale(0.93); }
    100% { transform: translate(0,   0)   scale(1);   }
  }

  /* Dot grid */
  .dot-grid {
    position: absolute;
    inset: 0;
    background-image: radial-gradient(rgba(255,255,255,0.04) 1px, transparent 1px);
    background-size: 32px 32px;
    pointer-events: none;
  }

  /* Fade in container */
  .fade-in {
    animation: fadeUp 0.7s cubic-bezier(0.16, 1, 0.3, 1) forwards;
  }
  @keyframes fadeUp {
    from { opacity: 0; transform: translateY(24px); }
    to   { opacity: 1; transform: translateY(0); }
  }

  /* Logo glow */
  .logo-glow {
    position: absolute;
    inset: -8px;
    background: radial-gradient(circle, rgba(6,182,212,0.25) 0%, transparent 70%);
    border-radius: 9999px;
    animation: pulse-glow 3s ease-in-out infinite;
  }
  @keyframes pulse-glow {
    0%, 100% { opacity: 0.6; transform: scale(1); }
    50%       { opacity: 1;   transform: scale(1.15); }
  }

  /* Gradient text */
  .gradient-text {
    background: linear-gradient(135deg, #06b6d4, #818cf8);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  /* Icon wrapper */
  .icon-wrapper {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 72px;
    height: 72px;
    border-radius: 20px;
    transition: all 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
  }
  .icon-personal {
    background: rgba(6, 182, 212, 0.12);
    border: 1px solid rgba(6, 182, 212, 0.25);
  }
  .icon-empresa {
    background: rgba(99, 102, 241, 0.12);
    border: 1px solid rgba(99, 102, 241, 0.25);
  }
  .icon-active {
    transform: scale(1.1) rotate(-4deg);
  }
  .icon-personal.icon-active {
    background: rgba(6, 182, 212, 0.22);
    box-shadow: 0 0 30px rgba(6, 182, 212, 0.3);
  }
  .icon-empresa.icon-active {
    background: rgba(99, 102, 241, 0.22);
    box-shadow: 0 0 30px rgba(99, 102, 241, 0.3);
  }

  /* Tags */
  .tag-personal {
    padding: 4px 10px;
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 600;
    background: rgba(6, 182, 212, 0.1);
    border: 1px solid rgba(6, 182, 212, 0.2);
    color: rgba(6, 182, 212, 0.8);
    letter-spacing: 0.03em;
  }
  .tag-empresa {
    padding: 4px 10px;
    border-radius: 9999px;
    font-size: 11px;
    font-weight: 600;
    background: rgba(99, 102, 241, 0.1);
    border: 1px solid rgba(99, 102, 241, 0.2);
    color: rgba(99, 102, 241, 0.8);
    letter-spacing: 0.03em;
  }

  /* Card button reset */
  .card-btn {
    appearance: none;
    cursor: pointer;
    width: 100%;
  }
</style>
