<script lang="ts">
  import { onMount } from 'svelte';
  import { API_BASE_URL } from '../config';
  import { toDateOnly } from '../dateUtils';

  export let uuid = '';

  let loading = true;
  let errorMsg = '';
  let eventData: any = null;
  let confirmSuccess = false;

  // Lista para almacenar partículas de confeti nativo
  let confettiParticles: Array<{ id: number; style: string }> = [];

  // Variables para la integración financiera
  let registrarTransaccion = true;
  let selectedCuentaId = '';
  let selectedCategoria = 'otros';
  let costoValue = 0;

  // Aplica los valores por defecto una sola vez al cargar el evento.
  // (No se usa un bloque reactivo para no sobreescribir lo que el usuario seleccione manualmente.)
  function applyDefaults() {
    if (!eventData) return;

    costoValue = Number(eventData.costo || 0);

    const cats: any[] = eventData.categorias || [];
    const evCat = eventData.categoria;

    // 1. Si la categoría de la compra existe entre las categorías de finanzas, usarla tal cual.
    if (evCat && cats.some(c => c.valor === evCat)) {
      selectedCategoria = evCat;
    // 2. Mapeo de categorías generales de calendario hacia finanzas.
    } else if (['moto', 'carro', 'aceite_moto', 'mecanica'].includes(evCat)) {
      selectedCategoria = 'transporte';
    } else if (['servicios', 'casa', 'arriendo'].includes(evCat)) {
      selectedCategoria = 'servicios';
    } else if (['doctor', 'medicamentos', 'dentista'].includes(evCat)) {
      selectedCategoria = 'salud';
    } else if (['cita_amor', 'aniversario', 'matrimonio', 'mesiversario', 'cumpleanos'].includes(evCat)) {
      selectedCategoria = 'entretenimiento';
    } else {
      selectedCategoria = cats.some(c => c.valor === 'otros') ? 'otros' : (cats[0]?.valor || 'otros');
    }

    // Cuenta por defecto: priorizar ahorros/efectivo/corriente; la tarjeta de crédito queda de última.
    const cuentas: any[] = eventData.cuentas || [];
    if (cuentas.length > 0) {
      const prioridad: Record<string, number> = {
        ahorros: 1, efectivo: 2, corriente: 3, cdt: 4, otro: 5, tarjeta_credito: 99
      };
      const ordenadas = [...cuentas].sort(
        (a, b) => (prioridad[a.tipo] ?? 50) - (prioridad[b.tipo] ?? 50)
      );
      selectedCuentaId = ordenadas[0].id;
    }
  }

  onMount(async () => {
    if (!uuid) {
      errorMsg = 'Enlace de confirmación no válido';
      loading = false;
      return;
    }
    await loadEventDetails();
  });

  async function loadEventDetails() {
    try {
      loading = true;
      errorMsg = '';
      const res = await fetch(`${API_BASE_URL}/api/public/events/confirmar/${uuid}`);
      if (res.ok) {
        eventData = await res.json();
        applyDefaults();
      } else {
        const err = await res.json().catch(() => ({}));
        errorMsg = err.message || 'El evento no existe o el enlace es inválido';
      }
    } catch (err) {
      console.error(err);
      errorMsg = 'Error al conectar con el servidor';
    } finally {
      loading = false;
    }
  }

  async function handleConfirm() {
    try {
      loading = true;
      const res = await fetch(`${API_BASE_URL}/api/public/events/confirmar/${uuid}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          estado: 'pagado',
          costo: Number(costoValue),
          registrarTransaccion,
          cuentaId: registrarTransaccion ? Number(selectedCuentaId) : null,
          categoriaTransaccion: registrarTransaccion ? selectedCategoria : null
        })
      });

      if (res.ok) {
        confirmSuccess = true;
        eventData.estado_pago = 'pagado';
        eventData.costo = Number(costoValue);
        triggerConfetti();
      } else {
        const err = await res.json().catch(() => ({}));
        alert(err.message || 'Error al confirmar el evento');
      }
    } catch (err) {
      console.error(err);
      alert('Error de red al intentar confirmar');
    } finally {
      loading = false;
    }
  }

  function triggerConfetti() {
    const colors = ['#25D366', '#34E47E', '#128C7E', '#ff4081', '#FFD700', '#00BFFF'];
    const particles = [];
    for (let i = 0; i < 80; i++) {
      const size = Math.random() * 8 + 5;
      const left = Math.random() * 100;
      const color = colors[Math.floor(Math.random() * colors.length)];
      const delay = Math.random() * 0.5;
      const duration = Math.random() * 2 + 1.5;
      const rotation = Math.random() * 360;

      particles.push({
        id: i,
        style: `
          left: ${left}%; 
          width: ${size}px; 
          height: ${size}px; 
          background-color: ${color}; 
          animation-delay: ${delay}s; 
          animation-duration: ${duration}s;
          transform: rotate(${rotation}deg);
        `
      });
    }
    confettiParticles = particles;

    // Limpiar confeti después de unos segundos
    setTimeout(() => {
      confettiParticles = [];
    }, 4000);
  }

  function formatPrice(value: number) {
    if (value === undefined || value === null) return '$0';
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0
    }).format(value);
  }

  function formatDate(dateStr: string) {
    if (!dateStr) return 'Fecha no especificada';
    try {
      const cleanDate = toDateOnly(dateStr);
      const parts = cleanDate.split('-');
      if (parts.length !== 3) return String(dateStr);
      
      const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
      if (isNaN(date.getTime())) return String(dateStr);
      
      return date.toLocaleDateString('es-CO', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
    } catch(err) {
      return String(dateStr);
    }
  }

  let isEditingPrice = false;
  let editPriceValue = 0;

  function startEditingPrice() {
    editPriceValue = Number(eventData.costo || 0);
    isEditingPrice = true;
  }

  async function savePriceChange() {
    if (!isEditingPrice) return;
    
    const parsedValue = Number(editPriceValue);
    if (isNaN(parsedValue) || parsedValue < 0) {
      alert('Por favor ingrese un valor de costo válido.');
      return;
    }
    
    // Evitar peticiones redundantes si no cambió
    if (parsedValue === Number(eventData.costo)) {
      isEditingPrice = false;
      return;
    }
    
    try {
      loading = true;
      const res = await fetch(`${API_BASE_URL}/api/public/events/confirmar/${uuid}/costo`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ costo: parsedValue })
      });
      
      if (res.ok) {
        eventData.costo = parsedValue;
        isEditingPrice = false;
      } else {
        const err = await res.json().catch(() => ({}));
        alert(err.message || 'Error al actualizar el costo');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    } finally {
      loading = false;
    }
  }

  function handlePriceKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter') {
      savePriceChange();
    } else if (e.key === 'Escape') {
      isEditingPrice = false;
    }
  }
</script>

<div class="confirm-container">
  <!-- Efecto de Confeti -->
  {#if confettiParticles.length > 0}
    <div class="confetti-container">
      {#each confettiParticles as p (p.id)}
        <div class="confetti-particle" style={p.style}></div>
      {/each}
    </div>
  {/if}

  {#if loading && !eventData}
    <div class="confirm-card glass loading-card">
      <div class="spinner"></div>
      <p>Cargando información del compromiso...</p>
    </div>
  {:else if errorMsg}
    <div class="confirm-card glass error-card">
      <div class="status-icon error">
        <i class="material-icons">error_outline</i>
      </div>
      <h2>Enlace no válido</h2>
      <p class="error-detail">{errorMsg}</p>
      <div class="card-footer">
        <span class="brand-text"><i class="material-icons">event</i> SaaS Calendar</span>
      </div>
    </div>
  {:else if eventData}
    <div class="confirm-card glass">
      <div class="confirm-header">
        <div class="logo-wrapper">
          <i class="material-icons">verified_user</i>
        </div>
        <span>Confirmación de Compromiso</span>
      </div>

      <div class="confirm-body">
        <h1 class="event-title">{eventData.titulo}</h1>

        <div class="details-list">
          <div class="detail-item">
            <i class="material-icons text-green">calendar_today</i>
            <div class="detail-content">
              <span class="detail-label">Fecha</span>
              <span class="detail-value">{formatDate(eventData.fecha)}</span>
            </div>
          </div>

          {#if eventData.hora}
            <div class="detail-item">
              <i class="material-icons text-green">access_time</i>
              <div class="detail-content">
                <span class="detail-label">Hora</span>
                <span class="detail-value">{eventData.hora.slice(0, 5)}</span>
              </div>
            </div>
          {/if}

          {#if eventData.ubicacion}
            <div class="detail-item">
              <i class="material-icons text-green">place</i>
              <div class="detail-content">
                <span class="detail-label">Ubicación</span>
                <span class="detail-value">{eventData.ubicacion}</span>
              </div>
            </div>
          {/if}

          {#if eventData.tipo_transaccion && eventData.tipo_transaccion !== 'ninguno'}
            <div class="detail-item price-item">
              <i class="material-icons text-green">payments</i>
              <div class="detail-content" style="width: 100%;">
                <span class="detail-label">Monto Asociado (Haz click para editar)</span>
                {#if isEditingPrice}
                  <div class="inline-price-edit">
                    <span class="price-symbol">$</span>
                    <input 
                      type="number" 
                      bind:value={editPriceValue} 
                      on:blur={savePriceChange}
                      on:keydown={handlePriceKeydown}
                      class="inline-price-input"
                      autofocus
                    />
                    <button type="button" class="inline-save-btn" on:click={savePriceChange} title="Guardar">
                      <i class="material-icons">check</i>
                    </button>
                    <button type="button" class="inline-cancel-btn" on:click={() => isEditingPrice = false} title="Cancelar">
                      <i class="material-icons">close</i>
                    </button>
                  </div>
                {:else}
                  <!-- svelte-ignore a11y_click_events_have_key_events -->
                  <!-- svelte-ignore a11y_no_static_element_interactions -->
                  <span class="detail-value price editable-price" on:click={startEditingPrice} title="Click para editar valor">
                    {formatPrice(Number(eventData.costo))}
                    <i class="material-icons edit-indicator-icon">edit</i>
                  </span>
                {/if}
              </div>
            </div>
          {/if}
        </div>

        {#if eventData.estado_pago === 'pagado'}
          <div class="status-alert success-alert">
            <i class="material-icons">check_circle</i>
            <span>¡Este compromiso ya ha sido confirmado / pagado!</span>
          </div>
        {:else}
          <div class="status-alert pending-alert">
            <i class="material-icons">pending_actions</i>
            <span>Estado: Pendiente de Confirmación</span>
          </div>

          <!-- Formulario de Configuración de Gasto/Pago -->
          <div class="finance-form-box">
            <h3 class="finance-form-title">
              <i class="material-icons">payments</i> Registrar Información de Pago
            </h3>
            
            <div class="form-group">
              <label for="costoInput">Valor / Costo del Compromiso</label>
              <div class="input-with-icon">
                <span class="currency-symbol">$</span>
                <input 
                  id="costoInput" 
                  type="number" 
                  bind:value={costoValue} 
                  min="0"
                  placeholder="0.00" 
                  class="finance-input"
                />
              </div>
            </div>

            <div class="form-checkbox">
              <label class="checkbox-label">
                <input type="checkbox" bind:checked={registrarTransaccion} class="finance-checkbox" />
                <span>Registrar como gasto en finanzas</span>
              </label>
            </div>

            {#if registrarTransaccion}
              <div class="form-row">
                <div class="form-group half-width">
                  <label for="cuentaSelect">Cuenta Afectada</label>
                  <select id="cuentaSelect" bind:value={selectedCuentaId} class="finance-select">
                    {#if !eventData.cuentas || eventData.cuentas.length === 0}
                      <option value="">(Sin cuentas registradas)</option>
                    {:else}
                      {#each eventData.cuentas as c}
                        <option value={c.id}>{c.nombre} (${Number(c.saldo).toLocaleString('es-CO')})</option>
                      {/each}
                    {/if}
                  </select>
                </div>

                <div class="form-group half-width">
                  <label for="categoriaSelect">Categoría de Gasto</label>
                  <select id="categoriaSelect" bind:value={selectedCategoria} class="finance-select">
                    {#each (eventData.categorias || []) as cat}
                      <option value={cat.valor}>{cat.label}</option>
                    {/each}
                  </select>
                </div>
              </div>
            {/if}
          </div>
        {/if}
      </div>

      {#if eventData.estado_pago !== 'pagado'}
        <div class="confirm-actions">
          <button class="btn-confirm" on:click={handleConfirm} disabled={loading}>
            {#if loading}
              <div class="spinner-small"></div> Confirmando...
            {:else}
              <i class="material-icons animate-icon">check</i> Confirmar Compromiso / Pago
            {/if}
          </button>
        </div>
      {:else}
        <div class="confirm-actions">
          <div class="success-check-wrapper">
            <div class="success-ring">
              <i class="material-icons">check</i>
            </div>
            <p>Confirmado exitosamente por {eventData.creador || 'el sistema'}</p>
          </div>
        </div>
      {/if}

      <div class="card-footer">
        <span class="brand-text"><i class="material-icons">event</i> SaaS Calendar</span>
      </div>
    </div>
  {/if}
</div>

<style>
  .confirm-container {
    min-height: 100vh;
    width: 100%;
    background: radial-gradient(circle at top, #128C7E 0%, #0B141A 70%);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
    box-sizing: border-box;
    font-family: 'Roboto', -apple-system, BlinkMacSystemFont, sans-serif;
    color: #E9EDEF;
    position: relative;
    overflow: hidden;
  }

  .glass {
    background: rgba(28, 42, 51, 0.75);
    backdrop-filter: blur(16px);
    -webkit-backdrop-filter: blur(16px);
    border: 1px solid rgba(255, 255, 255, 0.08);
    box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.5);
  }

  .confirm-card {
    width: 100%;
    max-width: 480px;
    border-radius: 16px;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    animation: scaleUp 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
  }

  @keyframes scaleUp {
    from {
      opacity: 0;
      transform: scale(0.9);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }

  .loading-card {
    padding: 50px 30px;
    align-items: center;
    justify-content: center;
    gap: 20px;
    text-align: center;
    color: #8696A0;
  }

  .spinner {
    width: 50px;
    height: 50px;
    border: 3px solid rgba(37, 211, 102, 0.1);
    border-radius: 50%;
    border-top-color: #25D366;
    animation: spin 1s ease-in-out infinite;
  }

  .spinner-small {
    width: 20px;
    height: 20px;
    border: 2px solid rgba(255, 255, 255, 0.2);
    border-radius: 50%;
    border-top-color: #ffffff;
    animation: spin 1s ease-in-out infinite;
    display: inline-block;
    margin-right: 8px;
    vertical-align: middle;
  }

  @keyframes spin {
    to { transform: rotate(360deg); }
  }

  .error-card {
    padding: 40px 30px;
    align-items: center;
    text-align: center;
  }

  .status-icon.error {
    width: 70px;
    height: 70px;
    background: rgba(244, 67, 54, 0.15);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-bottom: 20px;
  }

  .status-icon.error i {
    font-size: 44px;
    color: #F44336;
  }

  .error-card h2 {
    font-size: 1.5rem;
    margin-bottom: 10px;
    color: #E9EDEF;
  }

  .error-detail {
    color: #8696A0;
    font-size: 0.95rem;
    line-height: 1.4;
    margin-bottom: 20px;
  }

  /* Header Card */
  .confirm-header {
    padding: 20px 24px;
    background: rgba(32, 44, 51, 0.5);
    border-bottom: 1px solid rgba(255, 255, 255, 0.04);
    display: flex;
    align-items: center;
    gap: 12px;
    font-weight: 500;
    color: #8696A0;
    font-size: 0.9rem;
  }

  .logo-wrapper {
    width: 32px;
    height: 32px;
    background: #075E54;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .logo-wrapper i {
    color: #25D366;
    font-size: 18px;
  }

  /* Card Body */
  .confirm-body {
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 20px;
  }

  .event-title {
    font-size: 1.6rem;
    font-weight: 600;
    color: #E9EDEF;
    line-height: 1.3;
    margin-bottom: 5px;
  }

  .details-list {
    display: flex;
    flex-direction: column;
    gap: 16px;
    background: rgba(0, 0, 0, 0.15);
    padding: 18px;
    border-radius: 12px;
    border: 1px solid rgba(255, 255, 255, 0.03);
  }

  .detail-item {
    display: flex;
    gap: 14px;
    align-items: flex-start;
  }

  .detail-item i {
    font-size: 22px;
    margin-top: 2px;
  }

  .text-green {
    color: #25D366;
  }

  .detail-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .detail-label {
    font-size: 0.75rem;
    color: #8696A0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .detail-value {
    font-size: 1rem;
    color: #E9EDEF;
    font-weight: 500;
  }

  .price-item {
    border-top: 1px solid rgba(255, 255, 255, 0.05);
    padding-top: 14px;
    margin-top: 4px;
  }

  .price {
    font-size: 1.25rem;
    color: #34E47E;
    font-weight: 700;
  }

  /* Alerts */
  .status-alert {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    border-radius: 8px;
    font-size: 0.9rem;
    font-weight: 500;
  }

  .pending-alert {
    background: rgba(255, 167, 38, 0.12);
    border: 1px solid rgba(255, 167, 38, 0.25);
    color: #FFA726;
  }

  .pending-alert i {
    color: #FFA726;
  }

  .success-alert {
    background: rgba(37, 211, 102, 0.12);
    border: 1px solid rgba(37, 211, 102, 0.25);
    color: #34E47E;
  }

  .success-alert i {
    color: #34E47E;
  }

  /* Actions */
  .confirm-actions {
    padding: 0 24px 24px;
  }

  .btn-confirm {
    width: 100%;
    background: #25D366;
    color: #ffffff;
    border: none;
    padding: 15px;
    border-radius: 10px;
    font-size: 1.05rem;
    font-weight: 600;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 10px;
    box-shadow: 0 4px 12px rgba(37, 211, 102, 0.3);
    transition: all 0.2s ease-in-out;
  }

  .btn-confirm:hover {
    background: #1DA855;
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(37, 211, 102, 0.4);
  }

  .btn-confirm:active {
    transform: translateY(0);
  }

  .animate-icon {
    animation: pulse 1.5s infinite;
  }

  @keyframes pulse {
    0% { transform: scale(1); }
    50% { transform: scale(1.15); }
    100% { transform: scale(1); }
  }

  .success-check-wrapper {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    text-align: center;
    padding: 10px 0;
  }

  .success-ring {
    width: 60px;
    height: 60px;
    background: rgba(37, 211, 102, 0.15);
    border: 2px solid #25D366;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    animation: popCheck 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  }

  .success-ring i {
    color: #25D366;
    font-size: 36px;
    font-weight: bold;
  }

  @keyframes popCheck {
    from {
      opacity: 0;
      transform: scale(0.3);
    }
    to {
      opacity: 1;
      transform: scale(1);
    }
  }

  .success-check-wrapper p {
    font-size: 0.95rem;
    color: #8696A0;
  }

  /* Card Footer */
  .card-footer {
    padding: 15px 24px;
    background: rgba(32, 44, 51, 0.3);
    border-top: 1px solid rgba(255, 255, 255, 0.04);
    display: flex;
    justify-content: center;
  }

  .brand-text {
    font-size: 0.8rem;
    color: #667781;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .brand-text i {
    font-size: 14px;
  }

  /* Confetti Styles */
  .confetti-container {
    position: absolute;
    inset: 0;
    pointer-events: none;
    z-index: 100;
  }

  .confetti-particle {
    position: absolute;
    top: -10px;
    border-radius: 2px;
    opacity: 0.9;
    animation: fall linear forwards;
  }

  @keyframes fall {
    0% {
      top: -10px;
      opacity: 1;
    }
    85% {
      opacity: 1;
    }
    100% {
      top: 105%;
      opacity: 0;
    }
  }

  /* Estilos para edición en línea sutil de costo */
  .editable-price {
    cursor: pointer;
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    border-bottom: 1px dashed transparent;
    transition: all 0.2s ease;
    user-select: none;
  }

  .editable-price:hover {
    border-bottom-color: rgba(52, 228, 126, 0.4);
    color: #34E47E;
  }

  .edit-indicator-icon {
    font-size: 14px !important;
    color: rgba(52, 228, 126, 0.4);
    opacity: 0;
    transition: opacity 0.2s ease;
    margin-top: 0 !important;
  }

  .editable-price:hover .edit-indicator-icon {
    opacity: 1;
  }

  .inline-price-edit {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 4px;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 4px 8px;
    width: fit-content;
    animation: fadeIn 0.2s ease;
  }

  @keyframes fadeIn {
    from { opacity: 0; transform: translateY(-2px); }
    to { opacity: 1; transform: translateY(0); }
  }

  .price-symbol {
    font-size: 1.25rem;
    color: #34E47E;
    font-weight: 700;
  }

  .inline-price-input {
    background: transparent;
    border: none;
    outline: none;
    color: #34E47E;
    font-size: 1.25rem;
    font-weight: 700;
    width: 140px;
    font-family: inherit;
    padding: 0;
  }

  /* Eliminar spinners de input type="number" */
  .inline-price-input::-webkit-outer-spin-button,
  .inline-price-input::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .inline-price-input[type=number] {
    -moz-appearance: textfield;
  }

  .inline-save-btn, .inline-cancel-btn {
    background: transparent;
    border: none;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 4px;
    border-radius: 6px;
    transition: background 0.2s;
  }

  .inline-save-btn i {
    color: #25D366;
    font-size: 20px !important;
    margin-top: 0 !important;
  }

  .inline-cancel-btn i {
    color: #F44336;
    font-size: 20px !important;
    margin-top: 0 !important;
  }

  .inline-save-btn:hover {
    background: rgba(37, 211, 102, 0.15);
  }

  .inline-cancel-btn:hover {
    background: rgba(244, 67, 54, 0.15);
  }

  /* Estilos del Formulario de Finanzas */
  .finance-form-box {
    margin-top: 20px;
    padding: 18px;
    background: rgba(0, 0, 0, 0.2);
    border: 1px solid rgba(255, 255, 255, 0.05);
    border-radius: 12px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    text-align: left;
  }

  .finance-form-title {
    font-size: 1.05rem;
    font-weight: 600;
    color: #E9EDEF;
    display: flex;
    align-items: center;
    gap: 8px;
    margin: 0 0 4px 0;
  }

  .finance-form-title i {
    color: #25D366;
    font-size: 20px;
  }

  .form-group {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }

  .form-group label {
    font-size: 0.78rem;
    color: #8696A0;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 500;
  }

  .input-with-icon {
    position: relative;
    display: flex;
    align-items: center;
  }

  .currency-symbol {
    position: absolute;
    left: 14px;
    color: #25D366;
    font-size: 1.15rem;
    font-weight: 600;
  }

  .finance-input {
    width: 100%;
    padding: 12px 14px 12px 30px;
    background: rgba(18, 27, 34, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    color: #E9EDEF;
    font-size: 1.1rem;
    font-weight: 600;
    outline: none;
    transition: border-color 0.2s;
    box-sizing: border-box;
  }

  .finance-input:focus {
    border-color: #25D366;
  }

  .finance-input::-webkit-outer-spin-button,
  .finance-input::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
  }

  .finance-input[type=number] {
    -moz-appearance: textfield;
  }

  .form-checkbox {
    display: flex;
    align-items: center;
  }

  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 10px;
    cursor: pointer;
    font-size: 0.9rem;
    color: #E9EDEF;
    user-select: none;
  }

  .finance-checkbox {
    width: 18px;
    height: 18px;
    accent-color: #25D366;
    cursor: pointer;
  }

  .form-row {
    display: flex;
    gap: 14px;
    width: 100%;
  }

  .half-width {
    width: 50%;
  }

  .finance-select {
    width: 100%;
    padding: 12px;
    background: rgba(18, 27, 34, 0.8);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    color: #E9EDEF;
    font-size: 0.9rem;
    outline: none;
    cursor: pointer;
    transition: border-color 0.2s;
    box-sizing: border-box;
  }

  .finance-select:focus {
    border-color: #25D366;
  }

  .finance-select option {
    background: #182229;
    color: #E9EDEF;
  }
</style>
