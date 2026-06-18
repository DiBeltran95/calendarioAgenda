<script lang="ts">
  import { currentRoute, navigate } from './lib/router';
  import Login from './Login.svelte';
  import Register from './Register.svelte';
  import Dashboard from './Dashboard.svelte';
  import Confirmar from './lib/components/Confirmar.svelte';
  import { onMount } from 'svelte';

  onMount(() => {
    const token = localStorage.getItem('token');
    
    // Redirect logic on load
    if (!$currentRoute.startsWith('/confirmar/')) {
      if ($currentRoute === '/' || $currentRoute === '/login') {
        if (token) navigate('/dashboard');
        else navigate('/login');
      }
    }
  });
</script>

{#if $currentRoute === '/login'}
  <Login />
{:else if $currentRoute === '/register'}
  <Register />
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
