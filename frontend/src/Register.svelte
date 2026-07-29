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

<main class="min-h-screen relative flex items-center justify-center p-4 overflow-hidden bg-[#0B141A]">
  <!-- Fondo con orbs de marca -->
  <div class="absolute top-[-10%] right-[-10%] w-96 h-96 bg-green-500/25 rounded-full filter blur-[110px] animate-blob"></div>
  <div class="absolute top-[25%] left-[-10%] w-96 h-96 bg-blue-500/20 rounded-full filter blur-[110px] animate-blob animation-delay-2000"></div>
  <div class="absolute bottom-[-20%] right-[15%] w-96 h-96 bg-emerald-500/15 rounded-full filter blur-[110px] animate-blob animation-delay-4000"></div>

  <!-- Tarjeta -->
  <div class="relative max-w-md w-full bg-white/5 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/10 overflow-hidden z-10 p-8 sm:p-10 transition-all duration-500 hover:border-white/20">
    
    {#if step === 'register'}
      <div class="text-center mb-8">
        <div class="relative inline-block mb-1">
          <div class="absolute inset-0 bg-gradient-to-tr from-green-500/25 to-blue-500/20 rounded-full blur-2xl scale-110"></div>
          <img src="/logo22.png" alt="Agendaservi" class="relative w-28 h-28 object-contain transition-transform duration-300 hover:scale-105" />
        </div>
        <p class="text-gray-400 text-sm">Comienza a gestionar tu agenda y tus finanzas</p>
      </div>

      {#if errorMessage}
        <div class="bg-red-500/10 border border-red-500/50 text-red-400 p-4 rounded-xl mb-6 text-sm text-center backdrop-blur-md">
          {errorMessage}
        </div>
      {/if}

      <form on:submit={handleRegister} class="space-y-6">
        <div class="group">
          <label for="nombre" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-green-400">Nombre completo</label>
          <input
            id="nombre"
            type="text"
            bind:value={nombre}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="Tu nombre completo"
          />
        </div>

        <div class="group">
          <label for="email" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-green-400">Correo Electrónico</label>
          <input
            id="email"
            type="email"
            bind:value={email}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="tucorreo@ejemplo.com"
          />
        </div>

        <div class="group">
          <label for="whatsapp" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-green-400">WhatsApp</label>
          <input
            id="whatsapp"
            type="tel"
            bind:value={whatsapp}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="Ej: 573001234567"
          />
          <p class="text-[10px] text-gray-500 mt-1">Ingresa el código de país sin el signo "+" (ej: 57 para Colombia).</p>
        </div>

        <div class="group">
          <label for="password" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-2 transition-colors group-focus-within:text-green-400">Contraseña</label>
          <input
            id="password"
            type="password"
            bind:value={password}
            required
            class="w-full px-5 py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="••••••••"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          class="relative w-full bg-gradient-to-r from-green-500 to-blue-600 hover:from-green-400 hover:to-blue-500 text-white font-bold py-4 px-6 rounded-xl transition-all duration-300 shadow-[0_8px_24px_rgba(34,197,94,0.35)] hover:shadow-[0_10px_30px_rgba(59,130,246,0.45)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center overflow-hidden group"
        >
          <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-in-out"></div>
          <span class="relative flex items-center">
            {#if isLoading}
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
              Creando cuenta...
            {:else}
              Crear cuenta gratis
            {/if}
          </span>
        </button>
      </form>

      <div class="mt-8 text-center text-sm text-gray-400">
        ¿Ya tienes cuenta?
        <!-- svelte-ignore a11y-invalid-attribute -->
        <a href="#" on:click|preventDefault={goToLogin} class="text-green-400 hover:text-green-300 font-semibold ml-1 transition-colors">
          Iniciar sesión
        </a>
      </div>
    {:else}
      <div class="text-center mb-8">
        <div class="relative inline-block mb-3">
          <div class="absolute inset-0 bg-gradient-to-tr from-green-500/25 to-blue-500/20 rounded-full blur-2xl scale-110"></div>
          <img src="/logo22.png" alt="Agendaservi" class="relative w-28 h-28 object-contain transition-transform duration-300 hover:scale-105" />
        </div>
        <h1 class="text-2xl sm:text-3xl font-bold text-white tracking-tight">Verificación</h1>
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
          <label for="code" class="block text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3 transition-colors group-focus-within:text-green-400">Código de 6 dígitos</label>
          <input
            id="code"
            type="text"
            bind:value={verificationCode}
            required
            maxLength={6}
            class="w-full text-center text-3xl font-mono tracking-[0.3em] pl-[0.3em] py-4 rounded-xl border border-white/10 bg-black/20 text-white placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-transparent transition-all shadow-inner focus:bg-black/40"
            placeholder="000000"
          />
        </div>

        <button
          type="submit"
          disabled={isLoading}
          class="relative w-full bg-gradient-to-r from-green-500 to-blue-600 hover:from-green-400 hover:to-blue-500 text-white font-bold py-4 px-6 rounded-xl transition-all duration-300 shadow-[0_8px_24px_rgba(34,197,94,0.35)] hover:shadow-[0_10px_30px_rgba(59,130,246,0.45)] disabled:opacity-50 disabled:cursor-not-allowed flex justify-center items-center overflow-hidden group"
        >
          <div class="absolute inset-0 bg-white/20 translate-y-full group-hover:translate-y-0 transition-transform duration-300 ease-in-out"></div>
          <span class="relative flex items-center">
            {#if isLoading}
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
              Verificando...
            {:else}
              Confirmar código
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
            <a href="#" on:click|preventDefault={handleResendCode} class="text-green-400 hover:text-green-300 font-semibold transition-colors">
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
