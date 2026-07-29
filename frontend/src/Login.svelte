<script lang="ts">
  import { navigate } from './lib/router';
  import { API_BASE_URL } from './lib/config';
  import ParticleAnimation from './lib/components/ParticleAnimation.svelte';

  let email = '';
  let password = '';
  let isLoading = false;
  let errorMessage = '';

  async function handleLogin(e: Event) {
    e.preventDefault();
    isLoading = true;
    errorMessage = '';

    try {
      const res = await fetch(`${API_BASE_URL}/api/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });

      const data = await res.json();

      if (res.ok && data.token) {
        localStorage.setItem('token', data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        navigate('/select');
      } else if (res.status === 403 && data.verification_required) {
        localStorage.setItem('verification_email', data.email);
        navigate('/register');
      } else {
        errorMessage = data.message || 'Credenciales inválidas';
      }
    } catch (err) {
      errorMessage = 'Error de conexión con el servidor';
    } finally {
      isLoading = false;
    }
  }

  function goToRegister() {
    navigate('/register');
  }
</script>

<main class="min-h-screen relative flex items-center justify-center p-4 overflow-hidden bg-[#0B141A]">
  <!-- Fondo con orbs de marca -->
  <div class="absolute top-[-10%] right-[-10%] w-96 h-96 bg-green-500/25 rounded-full filter blur-[110px] animate-blob"></div>
  <div class="absolute top-[25%] left-[-10%] w-96 h-96 bg-blue-500/20 rounded-full filter blur-[110px] animate-blob animation-delay-2000"></div>
  <div class="absolute bottom-[-20%] right-[15%] w-96 h-96 bg-emerald-500/15 rounded-full filter blur-[110px] animate-blob animation-delay-4000"></div>

  <!-- Tarjeta -->
  <div class="relative max-w-md w-full bg-white/5 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/10 z-10 p-8 sm:p-10 transition-all duration-500 hover:border-white/20">
    <div class="text-center mb-8">
      <!-- Logo + partículas -->
      <div class="relative inline-flex items-center justify-center mb-3" style="width:180px; height:180px;">
        <!-- Capa de partículas (fondo) -->
        <div class="absolute inset-0">
          <ParticleAnimation />
        </div>
        <!-- Logo centrado encima -->
        <img src="/logo22.png" alt="Agendaservi" class="relative z-10 w-28 h-28 object-contain transition-transform duration-300 hover:scale-105" style="pointer-events:none;" />
      </div>
      <h1 class="text-2xl sm:text-3xl font-bold text-white tracking-tight">Bienvenido de nuevo</h1>
      <p class="text-gray-400 mt-2 text-sm">Inicia sesión para gestionar tu agenda y tus finanzas</p>
    </div>

    {#if errorMessage}
      <div class="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
        {errorMessage}
      </div>
    {/if}

    <form on:submit={handleLogin} class="space-y-5">
      <div class="group">
        <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-green-400">Correo electrónico</label>
        <input
          id="email"
          type="email"
          bind:value={email}
          required
          class="w-full px-5 py-3.5 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all focus:bg-black/40"
          placeholder="tucorreo@ejemplo.com"
        />
      </div>

      <div class="group">
        <div class="flex justify-between mb-2">
          <label for="password" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider transition-colors group-focus-within:text-green-400">Contraseña</label>
          <a href="#" class="text-xs text-green-400 hover:text-green-300 transition-colors">¿Olvidaste tu contraseña?</a>
        </div>
        <input
          id="password"
          type="password"
          bind:value={password}
          required
          class="w-full px-5 py-3.5 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all focus:bg-black/40"
          placeholder="••••••••"
        />
      </div>

      <button
        type="submit"
        disabled={isLoading}
        class="relative w-full bg-gradient-to-r from-green-500 to-blue-600 hover:from-green-400 hover:to-blue-500 text-white font-bold py-3.5 px-6 rounded-xl transition-all duration-300 shadow-[0_8px_24px_rgba(34,197,94,0.35)] hover:shadow-[0_10px_30px_rgba(59,130,246,0.45)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center"
      >
        <span class="relative flex items-center">
          {#if isLoading}
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
            Ingresando...
          {:else}
            Iniciar sesión
          {/if}
        </span>
      </button>
    </form>

    <div class="mt-8 text-center text-sm text-gray-400">
      ¿No tienes cuenta?
      <!-- svelte-ignore a11y-invalid-attribute -->
      <a href="#" on:click|preventDefault={goToRegister} class="text-green-400 hover:text-green-300 font-semibold ml-1 transition-colors">
        Crear cuenta gratis
      </a>
    </div>
  </div>
</main>

<style>
  @keyframes blob {
    0% { transform: translate(0px, 0px) scale(1); }
    33% { transform: translate(30px, -50px) scale(1.1); }
    66% { transform: translate(-20px, 20px) scale(0.9); }
    100% { transform: translate(0px, 0px) scale(1); }
  }
  .animate-blob {
    animation: blob 7s infinite;
  }
  .animation-delay-2000 {
    animation-delay: 2s;
  }
  .animation-delay-4000 {
    animation-delay: 4s;
  }
</style>
