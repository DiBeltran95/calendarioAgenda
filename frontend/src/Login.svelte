<script lang="ts">
  import { navigate } from './lib/router';
  import { API_BASE_URL } from './lib/config';

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

<main class="min-h-screen relative flex items-center justify-center p-4 overflow-hidden bg-[#09090b]">
  <!-- Animated Background Elements -->
  <div class="absolute top-[-10%] right-[-10%] w-96 h-96 bg-indigo-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob"></div>
  <div class="absolute top-[20%] left-[-10%] w-96 h-96 bg-cyan-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob animation-delay-2000"></div>
  <div class="absolute bottom-[-20%] right-[20%] w-96 h-96 bg-purple-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob animation-delay-4000"></div>

  <!-- Glassmorphism Card -->
  <div class="relative max-w-md w-full bg-white/5 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/10 overflow-hidden z-10 p-8 sm:p-10 transition-all duration-500 hover:shadow-cyan-500/20 hover:border-white/20">
    <div class="text-center mb-8">
      <div class="relative inline-block mb-4">
        <!-- Pulse glow behind the logo -->
        <div class="absolute inset-0 w-24 h-24 bg-gradient-to-tr from-cyan-500/20 to-indigo-500/20 rounded-full blur-xl scale-125 animate-pulse"></div>
        <img src="/logoSinFondo.png" alt="Logo" class="relative w-24 h-24 object-contain transition-transform duration-300 hover:scale-105" />
      </div>
      <h1 class="text-3xl font-bold bg-gradient-to-r from-white via-gray-100 to-gray-400 bg-clip-text text-transparent tracking-tight">
        Control Financiero
      </h1>
      <p class="text-gray-400 mt-2 text-sm">Ingresa a tu centro de control inteligente</p>
    </div>

    {#if errorMessage}
      <div class="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
        {errorMessage}
      </div>
    {/if}

    <form on:submit={handleLogin} class="space-y-6">
      <div class="group">
        <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-cyan-400">Identificador (Correo)</label>
        <input
          id="email"
          type="email"
          bind:value={email}
          required
          class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
          placeholder="holograma@correo.com"
        />
      </div>

      <div class="group">
        <div class="flex justify-between mb-2">
          <label for="password" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider transition-colors group-focus-within:text-cyan-400">Código de Acceso</label>
          <a href="#" class="text-xs text-cyan-500 hover:text-cyan-400 transition-colors">¿Olvidaste tu código?</a>
        </div>
        <input
          id="password"
          type="password"
          bind:value={password}
          required
          class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
          placeholder="••••••••"
        />
      </div>

      <button
        type="submit"
        disabled={isLoading}
        class="relative w-full bg-gradient-to-r from-cyan-500 to-indigo-600 hover:from-cyan-400 hover:to-indigo-500 text-white font-bold py-4 px-6 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(6,182,212,0.4)] hover:shadow-[0_0_30px_rgba(99,102,241,0.6)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center overflow-hidden group"
      >
        <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-in-out"></div>
        <span class="relative flex items-center">
          {#if isLoading}
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
            Autenticando...
          {:else}
            Establecer Conexión
          {/if}
        </span>
      </button>
    </form>

    <div class="mt-8 text-center text-sm text-gray-400">
      ¿Aún no estás en la red?
      <!-- svelte-ignore a11y-invalid-attribute -->
      <a href="#" on:click|preventDefault={goToRegister} class="text-cyan-400 hover:text-cyan-300 font-semibold ml-1 transition-colors drop-shadow-[0_0_8px_rgba(34,211,238,0.5)]">
        Inicia tu enlace aquí
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
