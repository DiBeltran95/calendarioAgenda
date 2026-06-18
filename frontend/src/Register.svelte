<script lang="ts">
  import { navigate } from './lib/router';
  import { API_BASE_URL } from './lib/config';
  import { onMount } from 'svelte';

  let nombre = '';
  let email = '';
  let password = '';
  let whatsapp = '';
  let verificationCode = '';
  let step: 'register' | 'verify' = 'register';
  let isLoading = false;
  let resendLoading = false;
  let errorMessage = '';
  let infoMessage = '';
  let countdown = 0;
  let countdownInterval: any;

  onMount(() => {
    const savedEmail = localStorage.getItem('verification_email');
    if (savedEmail) {
      email = savedEmail;
      step = 'verify';
      startCountdown();
    }

    return () => {
      if (countdownInterval) clearInterval(countdownInterval);
    };
  });

  function startCountdown() {
    countdown = 60;
    if (countdownInterval) clearInterval(countdownInterval);
    countdownInterval = setInterval(() => {
      countdown--;
      if (countdown <= 0) {
        clearInterval(countdownInterval);
      }
    }, 1000);
  }

  async function handleRegister(e: Event) {
    e.preventDefault();
    isLoading = true;
    errorMessage = '';
    infoMessage = '';

    try {
      const res = await fetch(`${API_BASE_URL}/api/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ nombre, email, password, whatsapp })
      });

      const data = await res.json();

      if (res.ok) {
        if (data.verification_required) {
          localStorage.setItem('verification_email', email);
          step = 'verify';
          startCountdown();
        } else {
          localStorage.setItem('token', data.token);
          localStorage.setItem('user', JSON.stringify(data.user));
          navigate('/dashboard');
        }
      } else {
        errorMessage = data.message || 'Error en el registro';
      }
    } catch (err) {
      errorMessage = 'Error de conexión con el servidor';
    } finally {
      isLoading = false;
    }
  }

  async function handleVerify(e: Event) {
    e.preventDefault();
    isLoading = true;
    errorMessage = '';
    infoMessage = '';

    try {
      const res = await fetch(`${API_BASE_URL}/api/register/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, code: verificationCode })
      });

      const data = await res.json();

      if (res.ok && data.token) {
        localStorage.removeItem('verification_email');
        localStorage.setItem('token', data.token);
        localStorage.setItem('user', JSON.stringify(data.user));
        navigate('/dashboard');
      } else {
        errorMessage = data.message || 'Código incorrecto o expirado';
      }
    } catch (err) {
      errorMessage = 'Error de conexión con el servidor';
    } finally {
      isLoading = false;
    }
  }

  async function handleResendCode() {
    if (countdown > 0 || resendLoading) return;
    resendLoading = true;
    errorMessage = '';
    infoMessage = '';

    try {
      const res = await fetch(`${API_BASE_URL}/api/register/resend-code`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email })
      });

      const data = await res.json();

      if (res.ok) {
        infoMessage = 'Código enviado correctamente';
        startCountdown();
      } else {
        errorMessage = data.message || 'Error al reenviar el código';
      }
    } catch (err) {
      errorMessage = 'Error de conexión al reenviar código';
    } finally {
      resendLoading = false;
    }
  }

  function goBackToRegister() {
    localStorage.removeItem('verification_email');
    step = 'register';
    verificationCode = '';
    errorMessage = '';
    infoMessage = '';
  }

  function goToLogin() {
    localStorage.removeItem('verification_email');
    navigate('/login');
  }
</script>

<main class="min-h-screen relative flex items-center justify-center p-4 overflow-hidden bg-[#09090b]">
  <!-- Animated Background Elements -->
  <div class="absolute top-[-10%] left-[-10%] w-96 h-96 bg-indigo-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob"></div>
  <div class="absolute top-[20%] right-[-10%] w-96 h-96 bg-purple-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob animation-delay-2000"></div>
  <div class="absolute bottom-[-20%] left-[20%] w-96 h-96 bg-blue-600/30 rounded-full mix-blend-screen filter blur-[100px] animate-blob animation-delay-4000"></div>

  <!-- Glassmorphism Card -->
  <div class="relative max-w-md w-full bg-white/5 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/10 overflow-hidden z-10 p-8 sm:p-10 transition-all duration-500 hover:shadow-indigo-500/20 hover:border-white/20">
    
    {#if step === 'register'}
      <div class="text-center mb-8">
        <div class="relative inline-block mb-4">
          <!-- Pulse glow behind the logo -->
          <div class="absolute inset-0 w-24 h-24 bg-gradient-to-tr from-indigo-500/20 to-purple-500/20 rounded-full blur-xl scale-125 animate-pulse"></div>
          <img src="/logoSinFondo.png" alt="Logo" class="relative w-24 h-24 object-contain transition-transform duration-300 hover:scale-105" />
        </div>
        <h1 class="text-3xl font-bold bg-gradient-to-r from-white via-gray-100 to-gray-400 bg-clip-text text-transparent tracking-tight">
          Crear Cuenta
        </h1>
        <p class="text-gray-400 mt-2 text-sm">El futuro de tus finanzas comienza aquí</p>
      </div>

      {#if errorMessage}
        <div class="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
          {errorMessage}
        </div>
      {/if}

      <form on:submit={handleRegister} class="space-y-6">
        <div class="group">
          <label for="nombre" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-indigo-400">Nombre completo</label>
          <input
            id="nombre"
            type="text"
            bind:value={nombre}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="Tu nombre estelar"
          />
        </div>

        <div class="group">
          <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-indigo-400">Correo Electrónico</label>
          <input
            id="email"
            type="email"
            bind:value={email}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="holograma@correo.com"
          />
        </div>

        <div class="group">
          <label for="whatsapp" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-indigo-400">WhatsApp</label>
          <input
            id="whatsapp"
            type="tel"
            bind:value={whatsapp}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="Ej: 573001234567"
          />
          <p class="text-[10px] text-gray-500 mt-1">Ingresa el código de país sin el signo "+" (ej: 57 para Colombia).</p>
        </div>

        <div class="group">
          <label for="password" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-indigo-400">Contraseña</label>
          <input
            id="password"
            type="password"
            bind:value={password}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="••••••••"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          class="relative w-full bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-400 hover:to-purple-500 text-white font-bold py-4 px-6 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(99,102,241,0.4)] hover:shadow-[0_0_30px_rgba(168,85,247,0.6)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center overflow-hidden group"
        >
          <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-in-out"></div>
          <span class="relative flex items-center">
            {#if isLoading}
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
              Sincronizando...
            {:else}
              Inicializar Secuencia
            {/if}
          </span>
        </button>
      </form>

      <div class="mt-8 text-center text-sm text-gray-400">
        ¿Ya estás en el sistema?
        <!-- svelte-ignore a11y-invalid-attribute -->
        <a href="#" on:click|preventDefault={goToLogin} class="text-indigo-400 hover:text-indigo-300 font-semibold ml-1 transition-colors drop-shadow-[0_0_8px_rgba(129,140,248,0.5)]">
          Conéctate aquí
        </a>
      </div>
    {:else}
      <div class="text-center mb-8">
        <div class="relative inline-block mb-4">
          <!-- Pulse glow behind the logo -->
          <div class="absolute inset-0 w-24 h-24 bg-gradient-to-tr from-purple-500/20 to-indigo-500/20 rounded-full blur-xl scale-125 animate-pulse"></div>
          <img src="/logoSinFondo.png" alt="Logo" class="relative w-24 h-24 object-contain transition-transform duration-300 hover:scale-105" />
        </div>
        <h1 class="text-3xl font-bold bg-gradient-to-r from-white via-gray-100 to-gray-400 bg-clip-text text-transparent tracking-tight">
          Verificación
        </h1>
        <p class="text-gray-400 mt-2 text-sm">Ingresa el código enviado a tu WhatsApp</p>
      </div>

      {#if errorMessage}
        <div class="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
          {errorMessage}
        </div>
      {/if}

      {#if infoMessage}
        <div class="bg-green-500/10 border border-green-500/50 text-green-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
          {infoMessage}
        </div>
      {/if}

      <form on:submit={handleVerify} class="space-y-6">
        <div class="group text-center">
          <label for="code" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3 transition-colors group-focus-within:text-indigo-400">Código de 6 dígitos</label>
          <input
            id="code"
            type="text"
            bind:value={verificationCode}
            required
            maxLength={6}
            class="w-full text-center text-3xl font-mono tracking-[0.3em] pl-[0.3em] py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="000000"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          class="relative w-full bg-gradient-to-r from-purple-500 to-indigo-600 hover:from-purple-400 hover:to-indigo-500 text-white font-bold py-4 px-6 rounded-xl transition-all duration-300 shadow-[0_0_20px_rgba(168,85,247,0.4)] hover:shadow-[0_0_30px_rgba(99,102,241,0.6)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center overflow-hidden group"
        >
          <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-in-out"></div>
          <span class="relative flex items-center">
            {#if isLoading}
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
              Verificando...
            {:else}
              Confirmar Enlace
            {/if}
          </span>
        </button>
      </form>

      <div class="mt-8 text-center text-sm text-gray-400 flex flex-col space-y-4">
        <div>
          {#if countdown > 0}
            <span class="text-gray-500">Reenviar código en {countdown}s</span>
          {:else}
            <!-- svelte-ignore a11y-invalid-attribute -->
            <a href="#" on:click|preventDefault={handleResendCode} class="text-indigo-400 hover:text-indigo-300 font-semibold transition-colors drop-shadow-[0_0_8px_rgba(129,140,248,0.5)]">
              {#if resendLoading}Reenviando...{:else}Reenviar código por WhatsApp{/if}
            </a>
          {/if}
        </div>
        <div>
          <!-- svelte-ignore a11y-invalid-attribute -->
          <a href="#" on:click|preventDefault={goBackToRegister} class="text-gray-500 hover:text-gray-400 font-semibold text-xs transition-colors">
            Volver al registro
          </a>
        </div>
      </div>
    {/if}
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
