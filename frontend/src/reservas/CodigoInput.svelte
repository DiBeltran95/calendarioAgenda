<script lang="ts">
  // Código de 6 dígitos: una casilla por dígito, avanza solo, acepta pegar
  // el código completo y el autocompletado de SMS/WhatsApp del sistema.
  interface Props {
    valor?: string;
    deshabilitado?: boolean;
    error?: boolean;
    alCompletar?: (codigo: string) => void;
  }
  let { valor = $bindable(''), deshabilitado = false, error = false, alCompletar }: Props = $props();

  let casillas: HTMLInputElement[] = $state([]);
  const digitos = $derived(Array.from({ length: 6 }, (_, i) => valor[i] ?? ''));

  function poner(texto: string, desde = 0) {
    const limpio = texto.replace(/\D/g, '');
    if (!limpio) return;
    const arr = digitos.slice();
    // Siempre se llena de izquierda a derecha: si hay casillas vacías antes,
    // el dígito va a la primera de ellas (el código nunca queda con huecos).
    const vacia = arr.findIndex((d) => d === '');
    let i = vacia === -1 ? desde : Math.min(desde, vacia);
    for (const d of limpio) {
      if (i > 5) break;
      arr[i++] = d;
    }
    valor = arr.join('');
    casillas[Math.min(i, 5)]?.focus();
    if (valor.length === 6 && !valor.includes(' ')) alCompletar?.(valor);
  }

  function alEscribir(i: number, e: Event) {
    const el = e.currentTarget as HTMLInputElement;
    const v = el.value;
    el.value = digitos[i] ?? '';
    if (v.length > 1) poner(v, i);
    else if (/\d/.test(v)) poner(v, i);
  }

  function alTecla(i: number, e: KeyboardEvent) {
    if (e.key === 'Backspace') {
      e.preventDefault();
      const arr = digitos.slice();
      if (arr[i]) arr[i] = '';
      else if (i > 0) {
        arr[i - 1] = '';
        casillas[i - 1]?.focus();
      }
      valor = arr.join('').trimEnd();
    } else if (e.key === 'ArrowLeft' && i > 0) casillas[i - 1]?.focus();
    else if (e.key === 'ArrowRight' && i < 5) casillas[i + 1]?.focus();
  }

  export function limpiar() {
    valor = '';
    casillas[0]?.focus();
  }

  export function enfocar() {
    casillas[Math.min(valor.length, 5)]?.focus();
  }
</script>

<div class="codigo" class:error role="group" aria-label="Código de confirmación de 6 dígitos">
  {#each digitos as d, i}
    <input
      bind:this={casillas[i]}
      class="casilla ag-num"
      class:llena={d !== ''}
      value={d}
      inputmode="numeric"
      autocomplete={i === 0 ? 'one-time-code' : 'off'}
      maxlength={i === 0 ? 6 : 1}
      aria-label={`Dígito ${i + 1}`}
      disabled={deshabilitado}
      oninput={(e) => alEscribir(i, e)}
      onkeydown={(e) => alTecla(i, e)}
      onpaste={(e) => {
        e.preventDefault();
        poner(e.clipboardData?.getData('text') ?? '', 0);
      }}
      onfocus={(e) => (e.currentTarget as HTMLInputElement).select()}
    />
  {/each}
</div>

<style>
  .codigo {
    display: grid;
    grid-template-columns: repeat(6, minmax(0, 1fr));
    gap: clamp(4px, 2vw, 8px);
    width: 100%;
    max-width: 360px;
    margin: 0 auto;
  }
  .casilla {
    width: 100%;
    aspect-ratio: 0.85;
    text-align: center;
    font: inherit;
    font-size: 24px;
    font-weight: 700;
    color: var(--text);
    background: var(--surface);
    border: 1.5px solid var(--border);
    border-radius: 14px;
    transition: border-color 160ms, box-shadow 160ms, transform 160ms var(--ease);
    caret-color: var(--marca);
  }
  .casilla:focus {
    outline: none;
    border-color: var(--marca);
    box-shadow: 0 0 0 4px var(--marca-suave);
  }
  .casilla.llena {
    border-color: var(--marca-borde);
    animation: salto 200ms var(--ease-out);
  }
  .error .casilla {
    border-color: var(--danger);
    animation: sacudir 380ms var(--ease);
  }
  @keyframes salto {
    from { transform: scale(0.92); }
    to { transform: scale(1); }
  }
  @keyframes sacudir {
    0%, 100% { transform: translateX(0); }
    20% { transform: translateX(-6px); }
    40% { transform: translateX(6px); }
    60% { transform: translateX(-4px); }
    80% { transform: translateX(4px); }
  }
</style>
