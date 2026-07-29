<script lang="ts">
  import { currentRoute, navigate } from './lib/router';
  import Login from './Login.svelte';
  import Register from './Register.svelte';
  import Dashboard from './Dashboard.svelte';
  import ModuleSelector from './ModuleSelector.svelte';
  import Confirmar from './lib/components/Confirmar.svelte';
  import { onMount } from 'svelte';

  // Bandera de build. En el APK (vite build --mode apk) VITE_APK='true':
  // la landing de marketing NUNCA se incluye ni se muestra.
  const IS_APK = import.meta.env.VITE_APK === 'true';

  // Landing solo-web, cargada de forma perezosa. Cuando IS_APK es true, esta
  // rama queda como código muerto y el bundler elimina el import del APK.
  let LandingComp: any = null;
  $: if (!IS_APK && $currentRoute === '/' && !LandingComp) {
    import('./Landing.svelte').then((m) => { LandingComp = m.default; });
  }

  onMount(() => {
    const token = localStorage.getItem('token');

    if ($currentRoute.startsWith('/confirmar/')) return;

    if (IS_APK) {
      // App empaquetada: no hay landing; '/' entra directo a la app.
      if ($currentRoute === '/' || $currentRoute === '/login') {
        navigate(token ? '/select' : '/login');
      } else if (($currentRoute === '/select' || $currentRoute === '/dashboard') && !token) {
        navigate('/login');
      }
      return;
    }

    // Web: '/' es la landing de marketing (no se redirige).
    if ($currentRoute === '/login' && token) {
      navigate('/select');
    } else if (($currentRoute === '/select' || $currentRoute === '/dashboard') && !token) {
      navigate('/login');
    }
  });
</script>

{#if $currentRoute === '/'}
  {#if !IS_APK}
    {#if LandingComp}
      <svelte:component this={LandingComp} />
    {/if}
  {/if}
  <!-- En APK '/' se redirige en onMount; no se pinta nada aquí. -->
{:else if $currentRoute === '/login'}
  <Login />
{:else if $currentRoute === '/register'}
  <Register />
{:else if $currentRoute === '/select'}
  <ModuleSelector />
{:else if $currentRoute === '/dashboard'}
  <Dashboard />
{:else if $currentRoute.startsWith('/confirmar/')}
  {@const uuid = $currentRoute.split('/').pop()}
  <Confirmar {uuid} />
{:else}
  <main class="min-h-screen flex items-center justify-center text-gray-500">
    <div class="text-center">
      <h1 class="text-2xl font-bold mb-2">Página no encontrada</h1>
      <button on:click={() => navigate('/')} class="text-accent underline">Volver al inicio</button>
    </div>
  </main>
{/if}
