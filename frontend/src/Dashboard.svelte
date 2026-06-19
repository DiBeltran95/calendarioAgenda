<script lang="ts">
  import { navigate } from './lib/router';
  import { onMount } from 'svelte';
  import Calendar from './lib/components/Calendar.svelte';
  import CurrencyInput from './lib/components/CurrencyInput.svelte';
  import AdvancedAnalytics from './lib/components/AdvancedAnalytics.svelte';
  import { API_BASE_URL } from './lib/config';
  import { getTodayLocal, toDateOnly } from './lib/dateUtils';
  
  import './assets/css/styles.css';
  import './assets/css/calendar.css';
  import './assets/css/modal.css';

  let isFemaleMode = false;
  let isFinanceMode = false;
  let isNotesMode = false;
  let isHabitsMode = false;
  let userName = '';
  
  let calendarComponent;
  let selectedDay = null;
  let showEventModal = false;
  let showPeriodModal = false;
  let showSearchBar = false;
  let canSearch = false;
  let searchQuery = '';
  let searchActive = false;
  let searchResults: any = null;
  let autocompleteResults: any[] = [];
  let showAutocomplete = false;
  let selectedAutocompleteIndex = -1;
  let autocompleteTimeout: any = null;
  let searchLoading = false;
  let familyToggles: Record<string | number, boolean> = {};
  let showNoteModal = false;
  let showHabitModal = false;

  let notesList = [];
  let habitsList = [];
  let habitLogsList = [];

  let noteData = { id: null, contenido: '', etiqueta: 'personal', color: '#4FC3F7' };
  let habitData = { id: null, nombre: '', icono: 'check_circle', color: '#4CAF50', frecuencia: 'diario', meta_diaria: 1 };

  // Módulo de finanzas
  let cuentasList = [];
  let ingresosPlanificadosList = [];
  let transaccionesList = [];
  let verificacionesList = [];
  let metasList = [];
  let presupuestosList = [];
  let activeFinanceTab = 'resumen';

  let showAccountModal = false;
  let showPlannedIncomeModal = false;
  let showTransactionModal = false;
  let showVerifyIncomeModal = false;
  let showMetaModal = false;
  let showPresupuestoModal = false;

  let accountData = { id: null, nombre: '', tipo: 'ahorros', saldo: 0, limite: 0, interes_tasa: 0, fecha_inicio: '', plazo_dias: 0, dia_corte: null as number | null };
  let plannedIncomeData = { id: null, cuenta_id: '', descripcion: '', monto: 0, frecuencia: 'mensual', fecha_inicio: '' };
  let transactionData = { id: null, cuenta_id: '', tipo: 'gasto', monto: 0, descripcion: '', fecha: '', categoria: 'otros', cuotas: 1 };
  let verifyIncomeData = { planId: null, descripcion: '', fecha_esperada: '', fecha_real: '', monto_real: 0, cuenta_id: '' };
  let metaData = { id: null, nombre: '', descripcion: '', monto_objetivo: 0, monto_actual: 0, fecha_objetivo: '', icono: 'savings', color: '#34E47E', completada: false };
  let presupuestoData = { id: null, categoria: 'comida', monto_limite: 0, mes: 0, anio: 0 };

  // Categorías de finanzas: se cargan desde la API por usuario.
  // Se inicializan con los valores por defecto como fallback mientras carga.
  let TRANSACTIONS_CATEGORIES = [
    { value: 'comida', label: 'Comida', icon: 'restaurant' },
    { value: 'transporte', label: 'Transporte', icon: 'directions_car' },
    { value: 'servicios', label: 'Servicios/Facturas', icon: 'receipt_long' },
    { value: 'entretenimiento', label: 'Entretenimiento/Ocio', icon: 'sports_esports' },
    { value: 'salud', label: 'Salud/Bienestar', icon: 'medication' },
    { value: 'educacion', label: 'Educación', icon: 'school' },
    { value: 'ahorro', label: 'Ahorro/Inversión', icon: 'savings' },
    { value: 'otros', label: 'Otros', icon: 'payments' }
  ];

  // Lista cruda de categorías (incluye id y es_default) para la gestión
  let categoriasFinanzas: any[] = [];

  // Estado de gestión de categorías (inline en el tab)
  let nuevaCategoriaLabel = '';
  let nuevaCategoriaIcono = 'sell';
  let categoriaError = '';
  let categoriaGuardando = false;

  // Iconos con nombre en español
  const ICONOS_CATEGORIA = [
    { value: 'sell',               label: 'Etiqueta' },
    { value: 'shopping_cart',      label: 'Carrito' },
    { value: 'restaurant',         label: 'Restaurante' },
    { value: 'fastfood',           label: 'Comida rápida' },
    { value: 'local_cafe',         label: 'Café' },
    { value: 'directions_car',     label: 'Carro' },
    { value: 'local_gas_station',  label: 'Gasolina' },
    { value: 'flight',             label: 'Vuelo' },
    { value: 'home',               label: 'Hogar' },
    { value: 'receipt_long',       label: 'Factura' },
    { value: 'bolt',               label: 'Electricidad' },
    { value: 'water_drop',         label: 'Agua' },
    { value: 'wifi',               label: 'Internet' },
    { value: 'phone_iphone',       label: 'Celular' },
    { value: 'sports_esports',     label: 'Videojuegos' },
    { value: 'movie',              label: 'Cine' },
    { value: 'fitness_center',     label: 'Gimnasio' },
    { value: 'medication',         label: 'Salud' },
    { value: 'school',             label: 'Educación' },
    { value: 'savings',            label: 'Ahorro' },
    { value: 'pets',               label: 'Mascotas' },
    { value: 'child_care',         label: 'Niños' },
    { value: 'checkroom',          label: 'Ropa' },
    { value: 'card_giftcard',      label: 'Regalo' },
    { value: 'volunteer_activism', label: 'Donación' },
    { value: 'build',              label: 'Reparación' },
    { value: 'payments',           label: 'Pago' },
    { value: 'attach_money',       label: 'Dinero' },
    { value: 'work',               label: 'Trabajo' },
    { value: 'celebration',        label: 'Celebración' },
  ];

  // Categorías actualmente en uso (transacciones o presupuestos), para bloquear su borrado
  $: categoriasEnUso = (() => {
    const usados = new Set<string>();
    for (const t of transaccionesList) if (t.categoria) usados.add(t.categoria);
    for (const p of presupuestosList) if (p.categoria) usados.add(p.categoria);
    return usados;
  })();

  // Enlace de datos del calendario
  let dashboardEvents = [];
  let currentMonth;
  let currentYear;

  let eventData = { 
    id: null,
    parent_id: null,
    titulo: '', 
    hora: '', 
    ubicacion: '', 
    categoria: 'reunion', 
    repeticion: 'unica',
    frecuencia: 'unica',
    costo: 0,
    tipo_transaccion: 'ninguno',
    estado_pago: 'pendiente',
    anio_nacimiento: null,
    mensaje: '',
    telefono: ''
  };
  let periodData = { observacion: '' };

  $: selectedDayNotes = selectedDay ? notesList.filter(n => toDateOnly(n.fecha) === selectedDay.dateStr) : [];
  $: selectedDayHabitLogs = selectedDay ? habitLogsList.filter(l => toDateOnly(l.fecha) === selectedDay.dateStr) : [];
  $: selectedDayTransactions = selectedDay ? transaccionesList.filter(t => toDateOnly(t.fecha) === selectedDay.dateStr) : [];

  async function loadDashboardNotes() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/notes`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) notesList = await res.json();
    } catch (err) {
      console.error(err);
    }
  }

  async function loadDashboardHabits() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/habits`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) habitsList = await res.json();
    } catch (err) {
      console.error(err);
    }
  }

  async function loadDashboardHabitLogs() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/habits/logs`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) habitLogsList = await res.json();
    } catch (err) {
      console.error(err);
    }
  }

  async function loadDashboardFinance() {
    try {
      const token = localStorage.getItem('token');
      const now = new Date();
      const mes = now.getMonth() + 1;
      const anio = now.getFullYear();
      const [resCuentas, resPlanificados, resTransacciones, resVerificaciones, resMetas, resPresupuestos] = await Promise.all([
        fetch(`${API_BASE_URL}/api/finanzas/cuentas`, { headers: { 'Authorization': `Bearer ${token}` } }),
        fetch(`${API_BASE_URL}/api/finanzas/ingresos-planificados`, { headers: { 'Authorization': `Bearer ${token}` } }),
        fetch(`${API_BASE_URL}/api/finanzas/transacciones`, { headers: { 'Authorization': `Bearer ${token}` } }),
        fetch(`${API_BASE_URL}/api/finanzas/verificaciones`, { headers: { 'Authorization': `Bearer ${token}` } }),
        fetch(`${API_BASE_URL}/api/finanzas/metas`, { headers: { 'Authorization': `Bearer ${token}` } }),
        fetch(`${API_BASE_URL}/api/finanzas/presupuestos?mes=${mes}&anio=${anio}`, { headers: { 'Authorization': `Bearer ${token}` } })
      ]);

      if (resCuentas.ok) cuentasList = await resCuentas.json();
      if (resPlanificados.ok) ingresosPlanificadosList = await resPlanificados.json();
      if (resTransacciones.ok) transaccionesList = await resTransacciones.json();
      if (resVerificaciones.ok) verificacionesList = await resVerificaciones.json();
      if (resMetas.ok) metasList = await resMetas.json();
      if (resPresupuestos.ok) presupuestosList = await resPresupuestos.json();
      await loadCategoriasFinanzas();
    } catch (err) {
      console.error('Error al cargar datos financieros:', err);
    }
  }

  async function loadCategoriasFinanzas() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/categorias`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data) && data.length > 0) {
          categoriasFinanzas = data;
          // Mapea a la forma {value, label, icon} que usan los selects/vistas
          TRANSACTIONS_CATEGORIES = data.map((c: any) => ({ value: c.valor, label: c.label, icon: c.icono }));
        }
      }
    } catch (err) {
      console.error('Error al cargar categorías:', err);
    }
  }

  async function crearCategoria() {
    categoriaError = '';
    const label = nuevaCategoriaLabel.trim();
    if (!label) {
      categoriaError = 'Escribe un nombre para la categoría.';
      return;
    }
    categoriaGuardando = true;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/categorias`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ label, icono: nuevaCategoriaIcono })
      });
      const data = await res.json();
      if (res.ok) {
        nuevaCategoriaLabel = '';
        nuevaCategoriaIcono = 'sell';
        await loadCategoriasFinanzas();
      } else {
        categoriaError = data.message || 'No se pudo crear la categoría.';
      }
    } catch (err) {
      categoriaError = 'Error de conexión con el servidor.';
    } finally {
      categoriaGuardando = false;
    }
  }

  async function eliminarCategoria(cat: any) {
    if (categoriasEnUso.has(cat.valor)) {
      alert('No puedes eliminar esta categoría porque tiene transacciones o presupuestos asociados.');
      return;
    }
    if (!confirm(`¿Eliminar la categoría "${cat.label}"?`)) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/categorias/${cat.id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await res.json();
      if (res.ok) {
        await loadCategoriasFinanzas();
      } else {
        alert(data.message || 'No se pudo eliminar la categoría.');
      }
    } catch (err) {
      alert('Error de conexión con el servidor.');
    }
  }

  async function refreshDashboardNotesAndHabits() {
    await Promise.all([
      loadDashboardNotes(),
      loadDashboardHabits(),
      loadDashboardHabitLogs(),
      loadDashboardFinance()
    ]);
    if (calendarComponent) {
      await calendarComponent.refreshData();
    }
    if (selectedDay) {
      const dayEvents = dashboardEvents.filter(ev => toDateOnly(ev.fecha) === selectedDay.dateStr);
      selectedDay = { ...selectedDay, dayEvents };
    }
  }

  // --- FUNCIONES DE FINANZAS ---

  // Ocurrencias del planificador en el mes
  function generateMonthlyOccurrences(plannedIncomes, year, month, verifications) {
    if (year === undefined || month === undefined) return [];
    const occurrences = [];
    const startDate = new Date(year, month, 1);
    const endDate = new Date(year, month + 1, 0);

    for (const plan of plannedIncomes) {
      if (!plan.activo) continue;
      const initDate = new Date(plan.fecha_inicio + 'T00:00:00');
      let current = new Date(initDate);

      // Loop to find occurrences
      let iteration = 0; // Guard to avoid infinite loop
      while (current <= endDate && iteration < 100) {
        iteration++;
        if (current >= startDate) {
          const dateStr = current.toISOString().split('T')[0];
          // Check if already verified
          const verification = verifications.find(v => v.ingreso_planificado_id === plan.id && toDateOnly(v.fecha_esperada) === dateStr);
          
          occurrences.push({
            planId: plan.id,
            descripcion: plan.descripcion,
            monto: Number(plan.monto),
            fecha_esperada: dateStr,
            frecuencia: plan.frecuencia,
            cuenta_id: plan.cuenta_id,
            verificado: !!verification,
            verificacionId: verification ? verification.id : null,
            fecha_real: verification ? toDateOnly(verification.fecha_real) : null,
            monto_real: verification ? Number(verification.monto_real) : null
          });
        }

        // Advance based on frequency
        if (plan.frecuencia === 'diario') {
          current.setDate(current.getDate() + 1);
        } else if (plan.frecuencia === 'semanal') {
          current.setDate(current.getDate() + 7);
        } else if (plan.frecuencia === 'quincenal') {
          current.setDate(current.getDate() + 15);
        } else if (plan.frecuencia === 'mensual') {
          current.setMonth(current.getMonth() + 1);
        } else {
          // 'unica'
          break;
        }
      }
    }

    return occurrences.sort((a, b) => a.fecha_esperada.localeCompare(b.fecha_esperada));
  }

  // --- CRUD Cuentas ---
  async function saveAccount() {
    try {
      const token = localStorage.getItem('token');
      const isEdit = accountData.id !== null;
      const url = isEdit ? `${API_BASE_URL}/api/finanzas/cuentas/${accountData.id}` : `${API_BASE_URL}/api/finanzas/cuentas`;
      const method = isEdit ? 'PUT' : 'POST';

      // Prepare payload to ensure valid types and defaults
      const payload = {
        ...accountData,
        interes_tasa: accountData.tipo === 'cdt' ? Number(accountData.interes_tasa || 0) : 0,
        plazo_dias: accountData.tipo === 'cdt' ? (accountData.plazo_dias ? Number(accountData.plazo_dias) : 0) : 0,
        fecha_inicio: accountData.tipo === 'cdt' ? (accountData.fecha_inicio || getTodayLocal()) : null,
        dia_corte: accountData.tipo === 'tarjeta_credito' && accountData.dia_corte ? Number(accountData.dia_corte) : null
      };

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });

      if (res.ok) {
        showAccountModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        const data = await res.json();
        alert(data.message || 'Error al guardar la cuenta');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  async function deleteAccount(id) {
    if (!confirm('¿Estás seguro de eliminar esta cuenta?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/cuentas/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al eliminar la cuenta');
      }
    } catch (err) {
      console.error(err);
    }
  }

  function editAccount(cuenta) {
    accountData = {
      id: cuenta.id,
      nombre: cuenta.nombre,
      tipo: cuenta.tipo,
      saldo: Number(cuenta.saldo),
      limite: Number(cuenta.limite || 0),
      interes_tasa: Number(cuenta.interes_tasa || 0),
      fecha_inicio: cuenta.fecha_inicio ? cuenta.fecha_inicio.substring(0, 10) : '',
      plazo_dias: Number(cuenta.plazo_dias || 0),
      dia_corte: cuenta.dia_corte ? Number(cuenta.dia_corte) : null
    };
    showAccountModal = true;
  }

  // Funciones auxiliares para calcular métricas de CDT
  function calculateCDTDailyYield(saldo, tasa) {
    if (!tasa || !saldo) return 0;
    const r = Number(tasa) / 100;
    const yieldFactor = Math.pow(1 + r, 1 / 365) - 1;
    return Number(saldo) * yieldFactor;
  }

  function calculateCDTTotalYield(saldo, tasa, plazo) {
    if (!tasa || !saldo || !plazo) return 0;
    const r = Number(tasa) / 100;
    const t = Number(plazo) / 365;
    const yieldFactor = Math.pow(1 + r, t) - 1;
    return Number(saldo) * yieldFactor;
  }

  function getProjectedCDTBalance(cuenta, dateStr) {
    if (cuenta.tipo !== 'cdt') return Number(cuenta.saldo);
    
    const todayStr = getTodayLocal();
    if (dateStr <= todayStr) return Number(cuenta.saldo);
    
    const today = new Date(todayStr + 'T00:00:00');
    const target = new Date(dateStr + 'T00:00:00');
    const diffTime = target.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    const r = Number(cuenta.interes_tasa || 0) / 100;
    const hasMaturity = cuenta.plazo_dias && Number(cuenta.plazo_dias) > 0;
    
    let compoundDays = diffDays;
    
    if (hasMaturity) {
      const start = new Date(cuenta.fecha_inicio + 'T00:00:00');
      const maturityDate = new Date(start.getTime() + Number(cuenta.plazo_dias) * 24 * 60 * 60 * 1000);
      const diffMaturityTime = maturityDate.getTime() - today.getTime();
      const daysToMaturity = Math.ceil(diffMaturityTime / (1000 * 60 * 60 * 24));
      
      if (diffDays > daysToMaturity) {
        compoundDays = Math.max(0, daysToMaturity);
      }
    }
    
    if (compoundDays <= 0) return Number(cuenta.saldo);
    const projected = Number(cuenta.saldo) * Math.pow(1 + r, compoundDays / 365);
    return projected;
  }

  function getDaysRemaining(fechaInicio, plazoDias) {
    if (!fechaInicio || !plazoDias) return 0;
    const start = new Date(fechaInicio + 'T00:00:00');
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const end = new Date(start.getTime() + Number(plazoDias) * 24 * 60 * 60 * 1000);
    const diffTime = end.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays > 0 ? diffDays : 0;
  }

  function getMaturityDateStr(fechaInicio, plazoDias) {
    if (!fechaInicio || !plazoDias) return '';
    const start = new Date(fechaInicio + 'T00:00:00');
    const end = new Date(start.getTime() + Number(plazoDias) * 24 * 60 * 60 * 1000);
    return end.toLocaleDateString('es-CO', { year: 'numeric', month: 'long', day: 'numeric' });
  }

  function getCDTProgressPercent(fechaInicio, plazoDias) {
    if (!fechaInicio || !plazoDias) return 0;
    const start = new Date(fechaInicio + 'T00:00:00').getTime();
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTime = today.getTime();
    const end = start + Number(plazoDias) * 24 * 60 * 60 * 1000;
    const total = end - start;
    if (total <= 0) return 100;
    const elapsed = todayTime - start;
    const pct = Math.max(0, Math.min(100, (elapsed / total) * 100));
    return pct;
  }

  // --- CRUD Ingresos Planificados ---
  async function savePlannedIncome() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/ingresos-planificados`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(plannedIncomeData)
      });

      if (res.ok) {
        showPlannedIncomeModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al guardar planificación');
      }
    } catch (err) {
      console.error(err);
    }
  }

  async function deletePlannedIncome(id) {
    if (!confirm('¿Estás seguro de eliminar esta planificación?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/ingresos-planificados/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al eliminar la planificación');
      }
    } catch (err) {
      console.error(err);
    }
  }

  // --- CRUD Transacciones ---
  async function saveTransaction() {
    try {
      const token = localStorage.getItem('token');
      const isEdit = transactionData.id !== null;
      const url = isEdit
        ? `${API_BASE_URL}/api/finanzas/transacciones/${transactionData.id}`
        : `${API_BASE_URL}/api/finanzas/transacciones`;
      const res = await fetch(url, {
        method: isEdit ? 'PUT' : 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(transactionData)
      });

      if (res.ok) {
        showTransactionModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        alert(isEdit ? 'Error al actualizar la transacción' : 'Error al registrar la transacción');
      }
    } catch (err) {
      console.error(err);
    }
  }

  function editTransaction(tx: any) {
    transactionData = {
      id: tx.id,
      cuenta_id: tx.cuenta_id || '',
      tipo: tx.tipo,
      monto: tx.monto,
      descripcion: tx.descripcion,
      fecha: toDateOnly(tx.fecha),
      categoria: tx.categoria || 'otros',
      cuotas: tx.cuotas || 1
    };
    showTransactionModal = true;
  }

  async function deleteTransaction(id) {
    if (!confirm('¿Estás seguro de eliminar esta transacción? Se revertirá su efecto en el saldo de la cuenta.')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/transacciones/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al eliminar la transacción');
      }
    } catch (err) {
      console.error(err);
    }
  }

  // --- Verificaciones ---
  async function verifyPlannedIncome() {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/ingresos-planificados/verificar`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          ingreso_planificado_id: verifyIncomeData.planId,
          fecha_esperada: verifyIncomeData.fecha_esperada,
          fecha_real: verifyIncomeData.fecha_real,
          monto_real: verifyIncomeData.monto_real,
          cuenta_id: verifyIncomeData.cuenta_id || null
        })
      });

      if (res.ok) {
        showVerifyIncomeModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        const data = await res.json();
        alert(data.message || 'Error al verificar el ingreso');
      }
    } catch (err) {
      console.error(err);
    }
  }

  async function undoVerification(verificacionId) {
    if (!confirm('¿Estás seguro de deshacer esta verificación? Se eliminará el ingreso registrado y se restará del saldo de tu cuenta.')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/verificaciones/${verificacionId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al deshacer verificación');
      }
    } catch (err) {
      console.error(err);
    }
  }

  function openVerifyModal(occurrence) {
    verifyIncomeData = {
      planId: occurrence.planId,
      descripcion: occurrence.descripcion,
      fecha_esperada: occurrence.fecha_esperada,
      fecha_real: occurrence.fecha_esperada,
      monto_real: occurrence.monto,
      cuenta_id: occurrence.cuenta_id || ''
    };
    showVerifyIncomeModal = true;
  }

  // --- CRUD Metas de Ahorro ---
  async function saveMeta() {
    try {
      const token = localStorage.getItem('token');
      const isEdit = metaData.id !== null;
      const url = isEdit ? `${API_BASE_URL}/api/finanzas/metas/${metaData.id}` : `${API_BASE_URL}/api/finanzas/metas`;
      const method = isEdit ? 'PUT' : 'POST';
      const res = await fetch(url, {
        method,
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify(metaData)
      });
      if (res.ok) {
        showMetaModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        const data = await res.json();
        alert(data.message || 'Error al guardar la meta');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  async function deleteMeta(id) {
    if (!confirm('¿Estás seguro de eliminar esta meta de ahorro?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/metas/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) await refreshDashboardNotesAndHabits();
      else alert('Error al eliminar la meta');
    } catch (err) { console.error(err); }
  }

  function editMeta(meta) {
    metaData = {
      id: meta.id,
      nombre: meta.nombre,
      descripcion: meta.descripcion || '',
      monto_objetivo: Number(meta.monto_objetivo),
      monto_actual: Number(meta.monto_actual),
      fecha_objetivo: meta.fecha_objetivo ? meta.fecha_objetivo.split('T')[0] : '',
      icono: meta.icono || 'savings',
      color: meta.color || '#34E47E',
      completada: !!meta.completada
    };
    showMetaModal = true;
  }

  function openContributionModal(meta) {
    transactionData = {
      id: null,
      cuenta_id: '',
      tipo: 'gasto',
      monto: 0,
      descripcion: `Aporte a meta: ${meta.nombre}`,
      fecha: selectedDay ? selectedDay.dateStr : getTodayLocal(),
      categoria: 'ahorro',
      cuotas: 1
    };
    showTransactionModal = true;
  }

  function getMetaProgress(meta) {
    const obj = Number(meta.monto_objetivo);
    const act = Number(meta.monto_actual);
    if (obj <= 0) return 0;
    return Math.min(100, Math.round((act / obj) * 100));
  }

  function getDaysUntilGoal(fecha_objetivo) {
    if (!fecha_objetivo) return null;
    const today = new Date();
    today.setHours(0,0,0,0);
    const goal = new Date(fecha_objetivo + 'T00:00:00');
    const diff = Math.ceil((goal.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));
    return diff;
  }

  // --- CRUD Presupuesto Mensual ---
  async function savePresupuesto() {
    try {
      const token = localStorage.getItem('token');
      const now = new Date();
      const payload = {
        ...presupuestoData,
        mes: presupuestoData.mes || (now.getMonth() + 1),
        anio: presupuestoData.anio || now.getFullYear()
      };
      const res = await fetch(`${API_BASE_URL}/api/finanzas/presupuestos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        showPresupuestoModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        const data = await res.json();
        alert(data.message || 'Error al guardar el presupuesto');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function editPresupuestoByCategoria(categoria: string) {
    const budget = presupuestosList.find(p => p.categoria === categoria);
    const now = new Date();
    if (budget) {
      presupuestoData = { id: budget.id, categoria: budget.categoria, monto_limite: Number(budget.monto_limite), mes: budget.mes, anio: budget.anio };
    } else {
      presupuestoData = { id: null, categoria, monto_limite: 0, mes: now.getMonth() + 1, anio: now.getFullYear() };
    }
    showPresupuestoModal = true;
  }

  async function deletePresupuesto(id) {
    if (!confirm('¿Eliminar este límite de presupuesto?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/presupuestos/${id}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) await refreshDashboardNotesAndHabits();
      else alert('Error al eliminar presupuesto');
    } catch (err) { console.error(err); }
  }


  function getBudgetStatus(categoria, pList = presupuestosList, mTransactions = monthlyTransactions) {
    const budget = pList.find(p => p.categoria === categoria);
    const spent = mTransactions
      .filter(t => t.tipo === 'gasto' && t.categoria === categoria)
      .reduce((sum, t) => sum + Number(t.monto), 0);
    if (!budget) return { spent, limit: 0, pct: 0, status: 'none' };
    const limit = Number(budget.monto_limite);
    const pct = limit > 0 ? Math.min(100, Math.round((spent / limit) * 100)) : 0;
    const status = pct >= 100 ? 'danger' : pct >= 80 ? 'warning' : 'ok';
    return { spent, limit, pct, status, id: budget.id };
  }

  function getAccountStartBalance(cuenta, dateStr, tList = transaccionesList) {
    let balance = Number(cuenta.saldo);
    const txsOnOrAfter = tList.filter(t => t.cuenta_id === cuenta.id && toDateOnly(t.fecha) >= dateStr);
    for (const t of txsOnOrAfter) {
      if (t.tipo === 'ingreso') {
        balance -= Number(t.monto);
      } else if (t.tipo === 'gasto') {
        balance += Number(t.monto);
      }
    }
    return balance;
  }

  // --- REACTIVIDAD DEL EXPERTO ECONÓMICO ---
  $: totalSavings = cuentasList.filter(c => c.tipo === 'ahorros' || c.tipo === 'efectivo' || c.tipo === 'cdt').reduce((sum, c) => sum + Number(c.saldo), 0);
  $: totalCreditDebt = cuentasList.filter(c => c.tipo === 'tarjeta_credito').reduce((sum, c) => sum + Number(c.saldo), 0);
  $: totalCreditLimit = cuentasList.filter(c => c.tipo === 'tarjeta_credito').reduce((sum, c) => sum + Number(c.limite), 0);
  $: creditUsageRatio = totalCreditLimit > 0 ? (totalCreditDebt / totalCreditLimit) * 100 : 0;

  $: monthlyTransactions = transaccionesList.filter(t => {
    if (currentMonth === undefined || currentYear === undefined) return false;
    const parts = toDateOnly(t.fecha).split('-');
    const tYear = Number(parts[0]);
    const tMonth = Number(parts[1]) - 1;
    return tYear === currentYear && tMonth === currentMonth;
  });

  $: totalMonthlyIncomes = monthlyTransactions.filter(t => t.tipo === 'ingreso').reduce((sum, t) => sum + Number(t.monto), 0);
  $: totalMonthlyExpenses = monthlyTransactions.filter(t => t.tipo === 'gasto').reduce((sum, t) => sum + Number(t.monto), 0);
  $: savingsRate = totalMonthlyIncomes > 0 ? ((totalMonthlyIncomes - totalMonthlyExpenses) / totalMonthlyIncomes) * 100 : 0;

  $: categoryTotals = monthlyTransactions.filter(t => t.tipo === 'gasto').reduce((acc, t) => {
    acc[t.categoria] = (acc[t.categoria] || 0) + Number(t.monto);
    return acc;
  }, {});

  $: topExpenseCategoryObj = Object.entries(categoryTotals).reduce((max, [cat, val]) => {
    return val > max.val ? { cat, val } : max;
  }, { cat: 'ninguno', val: 0 });

  $: occurrencesList = generateMonthlyOccurrences(ingresosPlanificadosList, currentYear, currentMonth, verificacionesList);
  $: pendingOccurrences = occurrencesList.filter(o => !o.verificado);

  $: recommendations = (() => {
    const list = [];
    
    // Tasa de ahorro
    if (totalMonthlyIncomes > 0) {
      if (savingsRate < 0) {
        list.push({
          type: 'danger',
          icon: 'trending_down',
          title: 'Presupuesto deficitario',
          text: `¡Cuidado! Este mes tus gastos superan tus ingresos por ${formatPrice(Math.abs(totalMonthlyIncomes - totalMonthlyExpenses))}. Estás en una tasa de ahorro de ${savingsRate.toFixed(1)}%. Revisa tus gastos de inmediato.`
        });
      } else if (savingsRate < 10) {
        list.push({
          type: 'warning',
          icon: 'warning',
          title: 'Ahorro insuficiente',
          text: `Estás ahorrando solo el ${savingsRate.toFixed(1)}% de tus ingresos. Los expertos recomiendan destinar al menos el 20% al ahorro/inversión (regla 50/30/20). Intenta recortar deseos.`
        });
      } else if (savingsRate < 20) {
        list.push({
          type: 'info',
          icon: 'trending_up',
          title: 'Buen ritmo de ahorro',
          text: `Tu tasa de ahorro mensual es de ${savingsRate.toFixed(1)}%. ¡Sigue así! Intenta automatizar este dinero apenas llegue a tu cuenta para no tentarte a gastarlo.`
        });
      } else {
        list.push({
          type: 'success',
          icon: 'stars',
          title: 'Excelente nivel de ahorro',
          text: `¡Felicidades! Estás ahorrando el ${savingsRate.toFixed(1)}% de tus ingresos. Esto es excelente para construir riqueza. Considera poner una parte a rentar en un CDT o fondos de inversión.`
        });
      }
    } else {
      list.push({
        type: 'info',
        icon: 'info',
        title: 'Registra tus transacciones',
        text: 'Registra tus ingresos y gastos para que el experto económico analice tu tasa de ahorro y te brinde recomendaciones inteligentes.'
      });
    }

    // Endeudamiento en tarjetas de crédito
    if (totalCreditLimit > 0) {
      if (creditUsageRatio > 50) {
        list.push({
          type: 'danger',
          icon: 'credit_card_off',
          title: 'Alto endeudamiento en tarjetas',
          text: `Estás usando el ${creditUsageRatio.toFixed(1)}% de tu cupo disponible en tarjetas de crédito. Esto puede afectar tu score financiero. Paga la totalidad a una cuota.`
        });
      } else if (creditUsageRatio > 30) {
        list.push({
          type: 'warning',
          icon: 'credit_card',
          title: 'Uso de tarjeta medio',
          text: `Has ocupado el ${creditUsageRatio.toFixed(1)}% de tu límite en tarjetas. Trata de mantenerlo por debajo del 30% para optimizar tu historial de crédito.`
        });
      } else {
        list.push({
          type: 'success',
          icon: 'credit_score',
          title: 'Uso de tarjeta ideal',
          text: `Uso de tarjetas óptimo (${creditUsageRatio.toFixed(1)}%). Estás utilizando el crédito de manera responsable y sin comprometer tus finanzas.`
        });
      }
    }

    // Mayor categoría de gasto
    if (topExpenseCategoryObj.val > 0) {
      const catName = TRANSACTIONS_CATEGORIES.find(c => c.value === topExpenseCategoryObj.cat)?.label || topExpenseCategoryObj.cat;
      list.push({
        type: 'info',
        icon: 'pie_chart',
        title: `Mayor gasto: ${catName}`,
        text: `Tu mayor egreso del mes es en "${catName}" por un valor de ${formatPrice(topExpenseCategoryObj.val)}. ¿Se puede optimizar?`
      });
    }

    // Sugerencia CDT
    const hasCDT = cuentasList.some(c => c.tipo === 'cdt');
    if (totalSavings > 1000000 && !hasCDT) {
      list.push({
        type: 'info',
        icon: 'account_balance',
        title: 'Haz crecer tu dinero',
        text: `Tienes ahorros por ${formatPrice(totalSavings)}. Puedes rentabilizar una parte abriendo un CDT de 90 o 180 días con bajo riesgo.`
      });
    }

    return list;
  })();

  // --- REGLA 50/30/20 (Necesidades / Deseos / Ahorro) ---
  // Clasificación automática de categorías por su slug. Las desconocidas caen en "Deseos".
  const NECESIDADES_SLUGS = [
    'comida', 'mercado', 'transporte', 'servicios', 'salud', 'medicina', 'medicamentos',
    'educacion', 'arriendo', 'alquiler', 'vivienda', 'hogar', 'home', 'agua', 'luz',
    'gas', 'internet', 'electricidad', 'transporte_publico', 'gasolina'
  ];
  const AHORRO_SLUGS = ['ahorro', 'ahorros', 'inversion', 'inversiones'];

  function classify503020(slug: string): 'necesidades' | 'deseos' | 'ahorro' {
    const s = (slug || '').toLowerCase();
    if (AHORRO_SLUGS.includes(s)) return 'ahorro';
    if (NECESIDADES_SLUGS.includes(s)) return 'necesidades';
    return 'deseos';
  }

  $: regla503020 = (() => {
    const income = totalMonthlyIncomes;
    let needs = 0, wants = 0;
    for (const t of monthlyTransactions) {
      if (t.tipo !== 'gasto') continue;
      const bucket = classify503020(t.categoria);
      const amt = Number(t.monto);
      if (bucket === 'necesidades') needs += amt;
      else if (bucket === 'deseos') wants += amt;
      // 'ahorro' no suma a gastos: queda dentro del bloque de ahorro
    }
    // Todo lo que no son necesidades ni deseos cuenta como ahorro/abono a deuda
    const savings = income - needs - wants;
    const base = income > 0 ? income : 0;
    const pct = (v: number) => base > 0 ? (v / base) * 100 : 0;
    // Estado de cada bloque frente a su meta ideal
    const needsStatus = needs / (base || 1) * 100 <= 50 ? 'ok' : (needs / (base || 1) * 100 <= 60 ? 'warn' : 'bad');
    const wantsStatus = wants / (base || 1) * 100 <= 30 ? 'ok' : (wants / (base || 1) * 100 <= 40 ? 'warn' : 'bad');
    const savePctVal = pct(savings);
    const savingsStatus = savePctVal >= 20 ? 'ok' : (savePctVal >= 10 ? 'warn' : 'bad');
    return {
      income, needs, wants, savings,
      needsPct: pct(needs), wantsPct: pct(wants), savingsPct: savePctVal,
      needsStatus, wantsStatus, savingsStatus,
      hasData: income > 0
    };
  })();

  async function saveNote() {
    try {
      const token = localStorage.getItem('token');
      const isEdit = noteData.id !== null;
      const url = isEdit ? `${API_BASE_URL}/api/notes/${noteData.id}` : `${API_BASE_URL}/api/notes`;
      const method = isEdit ? 'PUT' : 'POST';
      
      const payload = {
        fecha: selectedDay.dateStr,
        contenido: noteData.contenido,
        etiqueta: noteData.etiqueta,
        color: noteData.color
      };

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });

      if (res.ok) {
        showNoteModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al guardar la nota');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function editNote(note) {
    noteData = {
      id: note.id,
      contenido: note.contenido,
      etiqueta: note.etiqueta,
      color: note.color
    };
    showNoteModal = true;
  }

  async function deleteNote(id) {
    if (!confirm('¿Estás seguro de eliminar esta nota?')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/notes/${id}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al eliminar la nota');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  async function saveHabit() {
    try {
      const token = localStorage.getItem('token');
      const isEdit = habitData.id !== null;
      const url = isEdit ? `${API_BASE_URL}/api/habits/${habitData.id}` : `${API_BASE_URL}/api/habits`;
      const method = isEdit ? 'PUT' : 'POST';

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(habitData)
      });

      if (res.ok) {
        showHabitModal = false;
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al guardar el hábito');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function editHabit(habit) {
    habitData = { ...habit };
    showHabitModal = true;
  }

  async function deleteHabit(id) {
    if (!confirm('¿Estás seguro de eliminar este hábito? Esto también afectará el historial.')) return;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/habits/${id}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al eliminar el hábito');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  async function toggleHabitLog(habitId, dateStr, currentCompleted) {
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/habits/log`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          habito_id: habitId,
          fecha: dateStr,
          completado: !currentCompleted
        })
      });

      if (res.ok) {
        await refreshDashboardNotesAndHabits();
      } else {
        alert('Error al actualizar el progreso del hábito');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function getHabitStreak(habitId, logs) {
    const habitLogs = logs
      .filter(l => l.habito_id === habitId && l.completado)
      .map(l => toDateOnly(l.fecha))
      .sort((a, b) => b.localeCompare(a));
      
    if (habitLogs.length === 0) return 0;
    
    let streak = 0;
    let checkDate = new Date();
    checkDate.setHours(0,0,0,0);
    
    const todayStr = getTodayLocal(checkDate);
    checkDate.setDate(checkDate.getDate() - 1);
    const yesterdayStr = getTodayLocal(checkDate);
    
    const doneToday = habitLogs.includes(todayStr);
    const doneYesterday = habitLogs.includes(yesterdayStr);
    
    if (!doneToday && !doneYesterday) {
      return 0;
    }
    
    checkDate = new Date();
    checkDate.setHours(0,0,0,0);
    if (!doneToday) {
      checkDate.setDate(checkDate.getDate() - 1);
    }
    
    while (true) {
      const dateStr = getTodayLocal(checkDate);
      if (habitLogs.includes(dateStr)) {
        streak++;
        checkDate.setDate(checkDate.getDate() - 1);
      } else {
        break;
      }
    }
    
    return streak;
  }

  function toggleNotesMode() {
    isNotesMode = !isNotesMode;
    if (isNotesMode) {
      isFemaleMode = false;
      isFinanceMode = false;
      isHabitsMode = false;
      document.body.classList.remove('theme-female', 'theme-finance', 'theme-habits');
      document.body.classList.add('theme-notes');
    } else {
      document.body.classList.remove('theme-notes');
    }
  }

  function toggleHabitsMode() {
    isHabitsMode = !isHabitsMode;
    if (isHabitsMode) {
      isFemaleMode = false;
      isFinanceMode = false;
      isNotesMode = false;
      document.body.classList.remove('theme-female', 'theme-finance', 'theme-notes');
      document.body.classList.add('theme-habits');
    } else {
      document.body.classList.remove('theme-habits');
    }
  }

  function toggleFemaleMode() {
    isFemaleMode = !isFemaleMode;
    if (isFemaleMode) {
      isFinanceMode = false;
      isNotesMode = false;
      isHabitsMode = false;
      document.body.classList.remove('theme-finance', 'theme-notes', 'theme-habits');
      document.body.classList.add('theme-female');
    } else {
      document.body.classList.remove('theme-female');
    }
  }

  function toggleFinanceMode() {
    isFinanceMode = !isFinanceMode;
    if (isFinanceMode) {
      isFemaleMode = false;
      isNotesMode = false;
      isHabitsMode = false;
      document.body.classList.remove('theme-female', 'theme-notes', 'theme-habits');
      document.body.classList.add('theme-finance');
    } else {
      document.body.classList.remove('theme-finance');
    }
  }

  function handleLogout() {
    navigate('/select');
  }

  onMount(async () => {
    window.scrollTo(0, 0);
    const token = localStorage.getItem('token');
    if (!token) {
      navigate('/login');
    }
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    userName = user.nombre || '';
    canSearch = user.id === 1 || user.email === 'di.beltran@udla.edu.co';
    
    await refreshDashboardNotesAndHabits();
  });

  function handleDayClick(e) {
    if (selectedDay && selectedDay.dateStr === e.detail.dayData.dateStr) {
      selectedDay = null;
    } else {
      selectedDay = e.detail.dayData;
      if (selectedDay) {
        const dateStr = selectedDay.dateStr;
        const dayEvents = dashboardEvents.filter(ev => toDateOnly(ev.fecha) === dateStr);
        selectedDay = { ...selectedDay, dayEvents };
      }
    }
  }

  const CATEGORIES = [
    { value: 'reunion', label: 'Reunión', icon: 'fiber_manual_record' },
    { value: 'cumpleanos', label: 'Cumpleaños', icon: 'cake' },
    { value: 'moto', label: 'Moto', icon: 'two_wheeler' },
    { value: 'carro', label: 'Carro', icon: 'directions_car' },
    { value: 'casa', label: 'Casa', icon: 'home' },
    { value: 'arriendo', label: 'Arriendo', icon: 'real_estate_agent' },
    { value: 'aceite_moto', label: 'Aceite (Moto)', icon: 'water_drop' },
    { value: 'mecanica', label: 'Mecánica', icon: 'handyman' },
    { value: 'servicios', label: 'Servicios', icon: 'receipt_long' },
    { value: 'doctor', label: 'Doctor', icon: 'local_hospital' },
    { value: 'medicamentos', label: 'Medicamentos', icon: 'medication' },
    { value: 'dentista', label: 'Dentista', icon: 'health_and_safety' },
    { value: 'cita_amor', label: 'Cita amor', icon: 'favorite' },
    { value: 'aniversario', label: 'Aniversario', icon: 'celebration' },
    { value: 'matrimonio', label: 'Matrimonio', icon: 'diversity_1' },
    { value: 'mesiversario', label: 'Mesiversario', icon: 'favorite_border' }
  ];

  let showCategoryDropdown = false;
  let categorySearch = '';
  
  $: filteredCategories = CATEGORIES.filter(c => c.label.toLowerCase().includes(categorySearch.toLowerCase()));
  $: selectedCategoryObj = CATEGORIES.find(c => c.value === eventData.categoria) || CATEGORIES[0];

  // Reactividad para las estadísticas financieras del mes actual
  $: currentMonthEvents = dashboardEvents.filter(ev => {
    if (currentMonth === undefined || currentYear === undefined) return false;
    const parts = toDateOnly(ev.fecha).split('-');
    const evYear = Number(parts[0]);
    const evMonth = Number(parts[1]) - 1;
    return evYear === currentYear && evMonth === currentMonth;
  });

  $: monthlyStats = currentMonthEvents.reduce((acc, ev) => {
    const costo = Number(ev.costo || 0);
    if (ev.tipo_transaccion === 'gasto') {
      if (ev.estado_pago === 'pagado') acc.gastosPagados += costo;
      else acc.gastosPendientes += costo;
    } else if (ev.tipo_transaccion === 'ingreso') {
      acc.totalIngresos += costo;
    }
    return acc;
  }, { gastosPagados: 0, gastosPendientes: 0, totalIngresos: 0 });

  $: selectedDayFinEvents = selectedDay && selectedDay.dayEvents ? selectedDay.dayEvents.filter(e => e.tipo_transaccion && e.tipo_transaccion !== 'ninguno') : [];
  $: selectedDayGeneralEvents = selectedDay && selectedDay.dayEvents ? selectedDay.dayEvents.filter(e => !e.tipo_transaccion || e.tipo_transaccion === 'ninguno') : [];
  $: pendingMonthlyEvents = currentMonthEvents ? currentMonthEvents.filter(e => e.tipo_transaccion && e.tipo_transaccion !== 'ninguno' && e.estado_pago === 'pendiente') : [];

  $: netBalance = monthlyStats.totalIngresos - (monthlyStats.gastosPagados + monthlyStats.gastosPendientes);

  function formatPrice(value) {
    if (value === undefined || value === null) return '$0';
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0
    }).format(value);
  }

  async function deleteEvent(ev) {
    const isSeries = ev.frecuencia !== 'unica' || ev.parent_id !== null;
    let deleteMode = 'instance';
    if (isSeries) {
      const deleteSeries = confirm("¿Deseas eliminar esta y todas las futuras ocurrencias de la serie?\n\n(Aceptar = Eliminar serie futura / Cancelar = Eliminar solo este evento)");
      if (deleteSeries === null || deleteSeries === undefined) return;
      deleteMode = deleteSeries ? 'future' : 'instance';
    } else {
      if (!confirm('¿Estás seguro de eliminar este evento?')) return;
    }

    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/events/${ev.id}?deleteMode=${deleteMode}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });
      if (res.ok) {
        if (calendarComponent) await calendarComponent.refreshData();
        if (selectedDay) {
          const dayEvents = dashboardEvents.filter(e => toDateOnly(e.fecha) === selectedDay.dateStr);
          selectedDay = { ...selectedDay, dayEvents };
        }
      } else {
        alert('Error al eliminar el evento');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function editCumpleanos(birthday) {
      eventData = {
          id: birthday.id,
          titulo: birthday.nombre,
          hora: '',
          ubicacion: '',
          categoria: 'cumpleanos',
          repeticion: 'unica',
          costo: 0,
          tipo_transaccion: 'ninguno',
          estado_pago: 'pendiente',
          anio_nacimiento: birthday.anio_nacimiento,
          mensaje: birthday.mensaje,
          telefono: birthday.telefono
      };
      showCategoryDropdown = false;
      categorySearch = '';
      showEventModal = true;
  }

  function editEvent(ev) {
    eventData = {
      id: ev.id,
      parent_id: ev.parent_id,
      titulo: ev.titulo || '',
      hora: ev.hora || '',
      ubicacion: ev.ubicacion || '',
      categoria: ev.categoria || 'reunion',
      repeticion: ev.repeticion || 'unica',
      frecuencia: ev.frecuencia || 'unica',
      costo: ev.costo || 0,
      tipo_transaccion: ev.tipo_transaccion || 'ninguno',
      estado_pago: ev.estado_pago || 'pendiente',
      anio_nacimiento: ev.anio_nacimiento || null,
      mensaje: ev.mensaje || '',
      telefono: ev.telefono || ''
    };
    showCategoryDropdown = false;
    categorySearch = '';
    showEventModal = true;
  }

  async function deleteCumpleanos(id) {
      if (!confirm('¿Estás seguro de eliminar este cumpleaños?')) return;
      try {
          const token = localStorage.getItem('token');
          const res = await fetch(`${API_BASE_URL}/api/cumpleanos/${id}`, {
              method: 'DELETE',
              headers: { 'Authorization': `Bearer ${token}` }
          });
          if (res.ok) {
              if (calendarComponent) {
                  await calendarComponent.refreshData();
                  const currentStr = selectedDay.dateStr.slice(5);
                  const updatedBirthdays = calendarComponent.cumpleanos.filter(c => c.fecha && c.fecha.slice(5) === currentStr);
                  selectedDay = { ...selectedDay, dayBirthdays: updatedBirthdays };
              }
          } else {
              alert('Error al eliminar cumpleaños');
          }
      } catch (err) {
          console.error(err);
          alert('Error de conexión');
      }
  }

  async function togglePayment(ev) {
    const nuevoEstado = ev.estado_pago === 'pagado' ? 'pendiente' : 'pagado';
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/events/${ev.id}/toggle-pago`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ estado_pago: nuevoEstado })
      });
      if (res.ok) {
        ev.estado_pago = nuevoEstado;
        if (calendarComponent) await calendarComponent.refreshData();
        // Forzar reactividad del panel
        if (selectedDay) {
          const dayEvents = dashboardEvents.filter(e => toDateOnly(e.fecha) === selectedDay.dateStr);
          selectedDay = { ...selectedDay, dayEvents };
        }
      } else {
        alert('Error al cambiar el estado de pago');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function getWhatsAppMessage(ev) {
    const timeStr = ev.hora ? ` a las ${ev.hora.slice(0, 5)}` : '';
    const valStr = ev.tipo_transaccion && ev.tipo_transaccion !== 'ninguno' && ev.costo > 0 
      ? `\\n💰 Valor: ${formatPrice(ev.costo)}`
      : '';
    const linkStr = `\\n🔗 Confirma aquí: ${window.location.origin}/confirmar/${ev.uuid_confirmacion}`;
    
    return `Hola! Te recuerdo tu compromiso:\\n📌 *${ev.titulo}*\\n📅 Fecha: ${toDateOnly(ev.fecha)}${timeStr}${valStr}${linkStr}`;
  }

  function copyToClipboard(text) {
    navigator.clipboard.writeText(text).then(() => {
      if (text.startsWith('http')) {
        alert('¡Enlace de confirmación copiado al portapapeles!');
      } else {
        alert('¡Mensaje de WhatsApp copiado al portapapeles!');
      }
    }).catch(err => {
      console.error('Error al copiar', err);
    });
  }

  function handleDayDoubleClick(e) {
    selectedDay = e.detail.dayData;
    if (isFemaleMode) {
      periodData.observacion = '';
      showPeriodModal = true;
    } else if (isNotesMode) {
      noteData = { id: null, contenido: '', etiqueta: 'personal', color: '#4FC3F7' };
      showNoteModal = true;
    } else if (isHabitsMode) {
      habitData = { id: null, nombre: '', icono: 'check_circle', color: '#4CAF50', frecuencia: 'diario', meta_diaria: 1 };
      showHabitModal = true;
    } else if (isFinanceMode) {
      transactionData = { id: null, cuenta_id: '', tipo: 'gasto', monto: 0, descripcion: '', fecha: selectedDay.dateStr, categoria: 'otros', cuotas: 1 };
      showTransactionModal = true;
    } else {
      eventData = { 
        id: null,
        parent_id: null,
        titulo: '', 
        hora: '', 
        ubicacion: '', 
        categoria: 'reunion', 
        repeticion: 'unica',
        frecuencia: 'unica',
        costo: 0,
        tipo_transaccion: 'ninguno',
        estado_pago: 'pendiente',
        anio_nacimiento: null,
        mensaje: '',
        telefono: ''
      };
      showCategoryDropdown = false;
      categorySearch = '';
      showEventModal = true;
    }
  }

  async function saveEvent() {
    try {
      const token = localStorage.getItem('token');

      if (eventData.categoria === 'cumpleanos') {
        const payload = {
            nombre: eventData.titulo,
            fecha: selectedDay.dateStr,
            anio_nacimiento: eventData.anio_nacimiento || null,
            mensaje: eventData.mensaje || null,
            telefono: eventData.telefono || null
        };
        const isEdit = eventData.id !== null && eventData.id !== undefined;
        const url = isEdit ? `${API_BASE_URL}/api/cumpleanos/${eventData.id}` : `${API_BASE_URL}/api/cumpleanos`;
        const method = isEdit ? 'PUT' : 'POST';

        const res = await fetch(url, {
            method,
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(payload)
        });
        if (res.ok) {
            showEventModal = false;
            if (calendarComponent) {
                await calendarComponent.refreshData();
                const currentStr = selectedDay.dateStr.slice(5);
                const updatedBirthdays = calendarComponent.cumpleanos.filter(c => c.fecha && c.fecha.slice(5) === currentStr);
                selectedDay = { ...selectedDay, dayBirthdays: updatedBirthdays };
            }
        } else {
            alert('Error al guardar cumpleaños');
        }
        return;
      }

      const isEdit = eventData.id !== null && eventData.id !== undefined;
      let editMode = 'instance';
      if (isEdit && (eventData.frecuencia !== 'unica' || eventData.parent_id !== null)) {
        const editSeries = confirm("¿Deseas aplicar los cambios a esta y a todas las futuras ocurrencias de la serie?\n\n(Aceptar = Editar serie / Cancelar = Editar solo este evento)");
        editMode = editSeries ? 'future' : 'instance';
      }

      const payload = {
        ...eventData,
        fecha: selectedDay.dateStr
      };
      
      const url = isEdit ? `${API_BASE_URL}/api/events/${eventData.id}?editMode=${editMode}` : `${API_BASE_URL}/api/events`;
      const method = isEdit ? 'PUT' : 'POST';

      const res = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      
      if (res.ok) {
        showEventModal = false;
        if (calendarComponent) await calendarComponent.refreshData();
        // Disparar click_day de nuevo para actualizar el panel derecho
        if (selectedDay) {
          const dayEvents = dashboardEvents.filter(ev => toDateOnly(ev.fecha) === selectedDay.dateStr);
          selectedDay = { ...selectedDay, dayEvents };
        }
      } else {
        alert('Error al guardar el evento');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  async function savePeriod() {
    try {
      const token = localStorage.getItem('token');
      const payload = {
        fecha_inicio: selectedDay.dateStr,
        observacion: periodData.observacion
      };
      
      const res = await fetch(`${API_BASE_URL}/api/cycles`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(payload)
      });
      
      if (res.ok) {
        showPeriodModal = false;
        if (calendarComponent) await calendarComponent.refreshData();
      } else {
        alert('Error al registrar el periodo');
      }
    } catch (err) {
      console.error(err);
      alert('Error de conexión');
    }
  }

  function toggleSearchBar() {
    showSearchBar = !showSearchBar;
    if (!showSearchBar) {
      searchActive = false;
      searchResults = null;
      searchQuery = '';
      showAutocomplete = false;
    }
  }

  async function handleSearch() {
    if (!canSearch) {
      alert('Buscador deshabilitado para su usuario.');
      return;
    }
    const query = searchQuery.trim();
    if (!query) {
      searchActive = false;
      searchResults = null;
      return;
    }

    try {
      searchLoading = true;
      searchActive = true;
      showAutocomplete = false;

      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/api/search`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({
          db_key: 'db_uno',
          query: query
        })
      });

      if (!response.ok) {
        throw new Error('Error al conectar con el servidor');
      }

      const result = await response.json();
      if (result.success) {
        if (result.data) {
          searchResults = { type: 'FAMILIA', data: result.data };
        } else if (result.empresa) {
          searchResults = { type: 'EMPRESA', data: result.empresa };
        } else if (result.results_by_name) {
          searchResults = { type: 'NOMBRE', data: result.results_by_name };
        } else {
          searchResults = { type: 'NONE', error: 'No se encontraron resultados' };
        }
      } else {
        searchResults = { type: 'NONE', error: result.error || 'No se encontraron resultados' };
      }
    } catch (error: any) {
      console.error('Error al realizar búsqueda externa:', error);
      searchResults = { type: 'NONE', error: 'Error al realizar la búsqueda externa.' };
    } finally {
      searchLoading = false;
    }
  }

  async function searchEmpresas(query: string) {
    if (!canSearch) return;
    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/api/empresas/search?q=${encodeURIComponent(query)}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const result = await response.json();
      if (result.success && result.empresas && result.empresas.length > 0) {
        autocompleteResults = result.empresas;
        showAutocomplete = true;
      } else {
        autocompleteResults = [];
        showAutocomplete = true;
      }
    } catch (error) {
      console.error('Error buscando empresas:', error);
      showAutocomplete = false;
    }
  }

  function selectAutocompleteItem(empresa: any) {
    searchQuery = empresa.nit;
    showAutocomplete = false;
    handleSearch();
  }

  async function exportarExcelEmpresa(nit: string, razsoc: string) {
    if (!canSearch) return;
    alert('Generando Excel...');

    try {
      const token = localStorage.getItem('token');
      const response = await fetch(`${API_BASE_URL}/api/empresa/excel`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify({ nit })
      });

      const result = await response.json();
      if (result.success && result.url) {
        alert('Excel generado. Descargando...');
        
        const link = document.createElement('a');
        link.href = `${API_BASE_URL}${result.url}`;
        link.download = result.filename || `emtraben_${nit}.xlsx`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      } else {
        alert(result.error || 'No se pudo generar el Excel');
      }
    } catch (error) {
      console.error('Error generando Excel:', error);
      alert('Error al generar el Excel');
    }
  }

  function toggleTrabajadorFamily(index: string | number) {
    familyToggles[index] = !familyToggles[index];
    familyToggles = { ...familyToggles };
  }

  function calculateAge(dateStr: string | null): number | string {
    if (!dateStr) return '';
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return '';

    const today = new Date();
    let age = today.getFullYear() - d.getFullYear();
    const m = today.getMonth() - d.getMonth();
    if (m < 0 || (m === 0 && today.getDate() < d.getDate())) {
      age--;
    }
    if (age < 0 || age > 120) return '';
    return age;
  }

  function copyTextToClipboard(doc: string) {
    if (!doc) return;
    navigator.clipboard.writeText(doc).then(() => {
      alert('Documento copiado al portapapeles');
    }).catch(() => {
      alert('No se pudo copiar el documento');
    });
  }

  function navigateAutocomplete(direction: number) {
    if (autocompleteResults.length === 0) return;
    selectedAutocompleteIndex += direction;
    if (selectedAutocompleteIndex < 0) {
      selectedAutocompleteIndex = autocompleteResults.length - 1;
    } else if (selectedAutocompleteIndex >= autocompleteResults.length) {
      selectedAutocompleteIndex = 0;
    }
  }

  function handleSearchKeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      showAutocomplete = false;
      showSearchBar = false;
      searchActive = false;
      searchResults = null;
      searchQuery = '';
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (selectedAutocompleteIndex >= 0 && autocompleteResults[selectedAutocompleteIndex]) {
        selectAutocompleteItem(autocompleteResults[selectedAutocompleteIndex]);
      } else {
        showAutocomplete = false;
        handleSearch();
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      navigateAutocomplete(1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      navigateAutocomplete(-1);
    }
  }

  function handleSearchInput(e: any) {
    const val = e.target.value;
    searchQuery = val;

    if (autocompleteTimeout) {
      clearTimeout(autocompleteTimeout);
    }

    if (val.trim().length < 2) {
      showAutocomplete = false;
      autocompleteResults = [];
      return;
    }

    autocompleteTimeout = setTimeout(() => {
      searchEmpresas(val.trim());
    }, 300);
  }

  function handleCloseSearchClick() {
    showSearchBar = false;
    searchQuery = '';
    searchActive = false;
    searchResults = null;
    showAutocomplete = false;
  }

  function formatCurrency(val: any) {
    if (val === null || val === undefined || val === '') return '$0';
    const num = Number(val);
    if (isNaN(num)) return '$0';
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0
    }).format(num);
  }
</script>

<svelte:head>
  <link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap" rel="stylesheet">
</svelte:head>

<!-- Header estilo WhatsApp -->
<header class="header">
    <div class="header-content">
        <div class="header-left">
            <i class="material-icons">
                {isFemaleMode ? 'female' : isFinanceMode ? 'payments' : isNotesMode ? 'note_add' : isHabitsMode ? 'self_improvement' : 'event'}
            </i>
            <h1>
                {isFemaleMode ? 'Salud Femenina' : isFinanceMode ? 'Control Financiero' : isNotesMode ? 'Notas Rápidas' : isHabitsMode ? 'Hábitos y Rutinas' : 'Calendario de Eventos'}
            </h1>
        </div>

        <!-- Barra de búsqueda deslizante en el centro -->
        <div class="search-bar {showSearchBar ? 'active' : ''}" id="searchBar">
            <div class="search-input-wrapper">
                <i class="material-icons search-icon">search</i>
                <input type="text" id="searchInput" class="search-input" placeholder="Buscar persona o empresa..." autocomplete="off" bind:value={searchQuery} on:input={handleSearchInput} on:keydown={handleSearchKeydown}>
                <button class="icon-btn search-close" on:click={handleCloseSearchClick} id="searchCloseBtn" title="Cerrar búsqueda">
                    <i class="material-icons">close</i>
                </button>
            </div>
            <!-- Autocompletado de empresas -->
            <div class="search-autocomplete {showAutocomplete ? 'active' : ''}" id="searchAutocomplete">
                {#if autocompleteResults.length > 0}
                    <div class="autocomplete-header">
                        Empresas ({autocompleteResults.length})
                    </div>
                    {#each autocompleteResults as emp, index}
                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                        <div class="autocomplete-item {index === selectedAutocompleteIndex ? 'selected' : ''}" on:click={() => selectAutocompleteItem(emp)}>
                            <div class="autocomplete-info">
                                <span class="autocomplete-name">{emp.razsoc || 'Sin nombre'}</span>
                                <span class="autocomplete-nit">NIT: {emp.nit || ''}</span>
                            </div>
                        </div>
                    {/each}
                {:else if searchQuery.length >= 2}
                    <div class="autocomplete-empty">
                        <i class="material-icons">search_off</i>
                        <div>No se encontraron empresas</div>
                    </div>
                {/if}
            </div>
        </div>

        <div class="header-right {showSearchBar ? 'hidden-by-search' : ''}">
            {#if canSearch}
                <button class="icon-btn" on:click={toggleSearchBar} id="searchBtn" title="Buscar">
                    <i class="material-icons">search</i>
                </button>
            {/if}
            <button class="icon-btn {isFemaleMode ? 'neon-active' : ''}" on:click={toggleFemaleMode} id="femaleSwitchBtn" title="Filtro Femenino">
                <i class="material-icons">female</i>
            </button>
            <button class="icon-btn {isFinanceMode ? 'finance-active' : ''}" on:click={toggleFinanceMode} id="financeSwitchBtn" title="Modo Finanzas">
                <i class="material-icons">payments</i>
            </button>
            <button class="icon-btn {isNotesMode ? 'notes-active' : ''}" on:click={toggleNotesMode} id="notesSwitchBtn" title="Notas Rápidas">
                <i class="material-icons">note_add</i>
            </button>
            <button class="icon-btn {isHabitsMode ? 'habits-active' : ''}" on:click={toggleHabitsMode} id="habitsSwitchBtn" title="Hábitos y Bienestar">
                <i class="material-icons">self_improvement</i>
            </button>
            <button class="icon-btn" on:click={handleLogout} title="Cerrar sesión">
                <i class="material-icons" style="color: #F44336;">logout</i>
            </button>
        </div>
    </div>
</header>

<!-- Contenedor principal -->
<main class="main-container">
    <Calendar bind:this={calendarComponent} bind:events={dashboardEvents} bind:currentMonth bind:currentYear selectedDateStr={selectedDay?.dateStr ?? null} {isFemaleMode} {isFinanceMode} {isNotesMode} {isHabitsMode} transacciones={transaccionesList} plannedOccurrences={occurrencesList} on:click_day={handleDayClick} on:dblclick_day={handleDayDoubleClick} />

    <!-- Próximos eventos / Eventos del día -->
    <div class="upcoming-section">
        {#if searchActive}
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon" style="color: var(--wa-green-light);">person_search</i>
                <span id="upcomingTitleText">Resultados de búsqueda</span>
            </h3>
            <div class="interaction-hint" id="interactionHint" style="border-left-color: var(--wa-green-light);">
                <i class="material-icons" id="interactionHintIcon" style="color: var(--wa-green-light);">info</i>
                <span id="interactionHintText">Doble click en el botón X de búsqueda para volver</span>
            </div>

            <div class="upcoming-list" id="upcomingList" style="display: flex; flex-direction: column; gap: 10px; margin-top: 15px;">
                {#if searchLoading}
                    <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 40px; gap: 10px;">
                        <i class="material-icons" style="font-size: 40px; color: var(--wa-green); animation: spin 2s linear/infinite;">sync</i>
                        <span style="color: var(--text-secondary); font-size: 0.95rem;">Realizando búsqueda...</span>
                    </div>
                {:else if searchResults}
                    {#if searchResults.type === 'FAMILIA'}
                        <div class="search-results-header">
                            <div class="search-results-title">
                                <i class="material-icons">person_search</i>
                                <div>
                                    <h4>Búsqueda de núcleo familiar</h4>
                                    <p>Cédula consultada: <span>{searchQuery}</span></p>
                                </div>
                            </div>
                            {#if searchResults.data.rol_buscado}
                                <span class="search-role-badge">{searchResults.data.rol_buscado}</span>
                            {/if}
                        </div>

                        {@const mainPersona = searchResults.data.rol_buscado === 'CÓNYUGE' ? (searchResults.data.nucleo_familiar?.conyuges?.find(c => c.cedcon === searchQuery) || searchResults.data.nucleo_familiar?.conyuges?.[0]) : searchResults.data.rol_buscado === 'BENEFICIARIO' ? (searchResults.data.nucleo_familiar?.otros_beneficiarios?.find(b => b.documento === searchQuery) || searchResults.data.nucleo_familiar?.otros_beneficiarios?.[0]) : searchResults.data.afiliado_principal}
                        
                        {#if mainPersona}
                            {@const isActivo = String(searchResults.data.rol_buscado === 'CÓNYUGE' || searchResults.data.rol_buscado === 'BENEFICIARIO' ? (mainPersona.estado_activo ? 'ACTIVO' : mainPersona.estado) : (mainPersona.estado_desc || mainPersona.estado)).toUpperCase() === 'ACTIVO' || String(searchResults.data.rol_buscado === 'CÓNYUGE' || searchResults.data.rol_buscado === 'BENEFICIARIO' ? (mainPersona.estado_activo ? 'ACTIVO' : mainPersona.estado) : (mainPersona.estado_desc || mainPersona.estado)).toUpperCase() === 'A'}
                            {@const cedula = searchResults.data.rol_buscado === 'CÓNYUGE' ? mainPersona.cedcon : searchResults.data.rol_buscado === 'BENEFICIARIO' ? mainPersona.documento : mainPersona.cedtra}
                            {@const fecnac = mainPersona.fecnac}
                            {@const edad = calculateAge(fecnac)}
                            {@const estado = searchResults.data.rol_buscado === 'CÓNYUGE' || searchResults.data.rol_buscado === 'BENEFICIARIO' ? (mainPersona.estado_activo ? 'ACTIVO' : mainPersona.estado) : (mainPersona.estado_desc || mainPersona.estado)}
                            {@const sexo = mainPersona.sexo}
                            {@const ciunac = mainPersona.ciunac}
                            {@const direccion = mainPersona.direccion}
                            {@const telefono = mainPersona.telefono}
                            {@const email = mainPersona.email}
                            {@const salario = mainPersona.salario}
                            {@const numcue = mainPersona.numcue}

                            <div class="search-card search-card-main {!isActivo ? 'search-card--inactive' : ''}">
                                <div class="search-card-header">
                                    <div class="search-card-title">
                                        <i class="material-icons">person</i>
                                        <div>
                                            <span class="search-card-subtitle">Persona buscada</span>
                                            <h5>
                                                {#if searchResults.data.rol_buscado === 'CÓNYUGE'}Cónyuge{:else if searchResults.data.rol_buscado === 'BENEFICIARIO'}Beneficiario{:else}Afiliado principal{/if}
                                            </h5>
                                        </div>
                                    </div>
                                </div>
                                <div class="search-card-body">
                                    <div class="search-card-grid">
                                        <div class="search-field">
                                            <div class="search-field-label">Cédula</div>
                                            <div class="search-field-value">{cedula || searchQuery}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Nombre completo</div>
                                            <div class="search-field-value">{[mainPersona.prinom, mainPersona.segnom, mainPersona.priape, mainPersona.segape].filter(Boolean).join(' ')}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Fecha de nacimiento</div>
                                            <div class="search-field-value">{fecnac || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Edad</div>
                                            <div class="search-field-value">{edad ? `${edad} años` : 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Estado</div>
                                            <div class="search-field-value">
                                                {#if estado}
                                                    <span class="status-pill {String(estado).toUpperCase() === 'ACTIVO' || String(estado).toUpperCase() === 'A' ? 'status-pill--active' : 'status-pill--inactive'}">{estado}</span>
                                                {:else}
                                                    <span class="search-field-empty">No registra</span>
                                                {/if}
                                            </div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Género</div>
                                            <div class="search-field-value">{sexo || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Ciudad de nacimiento (código)</div>
                                            <div class="search-field-value">{ciunac || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Dirección</div>
                                            <div class="search-field-value">{direccion || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Teléfono</div>
                                            <div class="search-field-value">{telefono || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Email</div>
                                            <div class="search-field-value">{email || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Salario</div>
                                            <div class="search-field-value">{formatCurrency(salario)}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Número de cuenta</div>
                                            <div class="search-field-value">{numcue || 'No registra'}</div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {#if searchResults.data.afiliado_principal && searchResults.data.rol_buscado !== 'AFILIADO' && searchResults.data.rol_buscado}
                            {@const af = searchResults.data.afiliado_principal}
                            {@const afEdad = calculateAge(af.fecnac)}
                            <div class="search-card">
                                <div class="search-card-header">
                                    <div class="search-card-title">
                                        <i class="material-icons">verified_user</i>
                                        <div>
                                            <span class="search-card-subtitle">Afiliado principal</span>
                                            <h5>{[af.prinom, af.segnom, af.priape, af.segape].filter(Boolean).join(' ') || 'Sin nombre registrado'}</h5>
                                        </div>
                                    </div>
                                </div>
                                <div class="search-card-body">
                                    <div class="search-card-grid">
                                        <div class="search-field">
                                            <div class="search-field-label">Cédula</div>
                                            <div class="search-field-value">{searchResults.data.cedula_afiliado_principal || af.cedtra}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Nombre completo</div>
                                            <div class="search-field-value">{[af.prinom, af.segnom, af.priape, af.segape].filter(Boolean).join(' ')}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Dirección</div>
                                            <div class="search-field-value">{af.direccion || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Teléfono</div>
                                            <div class="search-field-value">{af.telefono || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Email</div>
                                            <div class="search-field-value">{af.email || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Salario</div>
                                            <div class="search-field-value">{formatCurrency(af.salario)}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Fecha de nacimiento</div>
                                            <div class="search-field-value">{af.fecnac || 'No registra'}{afEdad ? ` (${afEdad} años)` : ''}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Edad</div>
                                            <div class="search-field-value">{afEdad ? `${afEdad} años` : 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Ciudad de nacimiento (código)</div>
                                            <div class="search-field-value">{af.ciunac || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Género</div>
                                            <div class="search-field-value">{af.sexo || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Número de cuenta</div>
                                            <div class="search-field-value">{af.numcue || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Categoría</div>
                                            <div class="search-field-value">{af.codcat || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Estado</div>
                                            <div class="search-field-value">
                                                {#if af.estado_desc || af.estado}
                                                    <span class="status-pill {String(af.estado_desc || af.estado).toUpperCase() === 'ACTIVO' || String(af.estado_desc || af.estado).toUpperCase() === 'A' ? 'status-pill--active' : 'status-pill--inactive'}">{af.estado_desc || af.estado}</span>
                                                {:else}
                                                    <span class="search-field-empty">No registra</span>
                                                {/if}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {#if searchResults.data.empresa_actual && Object.keys(searchResults.data.empresa_actual).length > 0}
                            {@const em = searchResults.data.empresa_actual}
                            <div class="search-card">
                                <div class="search-card-header">
                                    <div class="search-card-title">
                                        <i class="material-icons">business</i>
                                        <div>
                                            <span class="search-card-subtitle">Empresa actual</span>
                                            <h5>{em.razsoc || em.nomemp || 'Sin razón social'}</h5>
                                        </div>
                                    </div>
                                </div>
                                <div class="search-card-body">
                                    <div class="search-card-grid">
                                        <div class="search-field">
                                            <div class="search-field-label">Nombre Empleador</div>
                                            <div class="search-field-value">{[em.prinom, em.segnom, em.priape, em.segape].filter(Boolean).join(' ') || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Razón social</div>
                                            <div class="search-field-value">{em.razsoc || em.nomemp || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">NIT</div>
                                            <div class="search-field-value">{em.nit || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Dirección</div>
                                            <div class="search-field-value">{em.direccion || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Ciudad</div>
                                            <div class="search-field-value">{em.codciu || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Teléfono</div>
                                            <div class="search-field-value">{em.telefono || em.telr || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Email</div>
                                            <div class="search-field-value">{em.email || em.mailt || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Fecha afiliación</div>
                                            <div class="search-field-value">{em.fecafi || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Fecha última novedad</div>
                                            <div class="search-field-value">{em.feccam || em.feccor || 'No registra'}</div>
                                        </div>
                                        <div class="search-field">
                                            <div class="search-field-label">Estado</div>
                                            <div class="search-field-value">
                                                {#if em.estado}
                                                    <span class="status-pill {String(em.estado).toUpperCase() === 'ACTIVO' || String(em.estado).toUpperCase() === 'A' ? 'status-pill--active' : 'status-pill--inactive'}">{em.estado}</span>
                                                {:else}
                                                    <span class="search-field-empty">No registra</span>
                                                {/if}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {@const conyuges = searchResults.data.nucleo_familiar?.conyuges || []}
                        {@const beneficiarios = searchResults.data.nucleo_familiar?.otros_beneficiarios || []}
                        {#if conyuges.length > 0 || beneficiarios.length > 0}
                            <div class="search-card">
                                <div class="search-card-header">
                                    <div class="search-card-title">
                                        <i class="material-icons">groups</i>
                                        <div>
                                            <span class="search-card-subtitle">Núcleo familiar</span>
                                            <h5>Composición del grupo familiar</h5>
                                        </div>
                                    </div>
                                </div>
                                <div class="search-card-body family-card-body">
                                    <div class="family-group">
                                        <div class="family-group-title">Cónyuge</div>
                                        <div class="family-list">
                                            {#if conyuges.length > 0}
                                                {#each conyuges as c}
                                                    {@const cNombre = [c.prinom, c.segnom, c.priape, c.segape].filter(Boolean).join(' ')}
                                                    {@const cActivo = !!c.estado_activo || String(c.estado).toUpperCase() === 'A'}
                                                    {@const cEdad = calculateAge(c.fecnac)}
                                                    <div class="family-member {!cActivo ? 'family-member--inactive' : ''}">
                                                        <div class="family-member-main">
                                                            <span class="family-member-name">{cNombre || 'Sin nombre'}</span>
                                                            <span class="family-member-doc">{c.cedcon || ''}</span>
                                                        </div>
                                                        <div class="family-member-meta">
                                                            <span class="family-member-role">Cónyuge{cEdad ? ` • ${cEdad} años` : ''}</span>
                                                            <span class="family-member-status">{cActivo ? 'ACTIVO' : 'INACTIVO'}</span>
                                                        </div>
                                                    </div>
                                                {/each}
                                            {:else}
                                                <p class="family-empty">No hay cónyuge registrado.</p>
                                            {/if}
                                        </div>
                                    </div>
                                    <div class="family-group">
                                        <div class="family-group-title">Beneficiarios</div>
                                        <div class="family-list">
                                            {#if beneficiarios.length > 0}
                                                {#each beneficiarios as b}
                                                    {@const bNombre = [b.prinom, b.segnom, b.priape, b.segape].filter(Boolean).join(' ')}
                                                    {@const bActivo = !!b.estado_activo || String(b.estado).toUpperCase() === 'A'}
                                                    {@const bEdad = calculateAge(b.fecnac)}
                                                    <div class="family-member {!bActivo ? 'family-member--inactive' : ''}">
                                                        <div class="family-member-main">
                                                            <span class="family-member-name">{bNombre || 'Sin nombre'}</span>
                                                            <span class="family-member-doc">{b.documento || ''}</span>
                                                        </div>
                                                        <div class="family-member-meta">
                                                            <span class="family-member-role">Beneficiario{bEdad ? ` • ${bEdad} años` : ''}</span>
                                                            <span class="family-member-status">{bActivo ? 'ACTIVO' : 'INACTIVO'}</span>
                                                        </div>
                                                    </div>
                                                {/each}
                                            {:else}
                                                <p class="family-empty">No hay beneficiarios registrados.</p>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {@const historial = searchResults.data.historial_completo || []}
                        {#if historial.length > 0}
                            <div class="search-card">
                                <div class="search-card-header">
                                    <div class="search-card-title">
                                        <i class="material-icons">work_history</i>
                                        <div>
                                            <span class="search-card-subtitle">Historial laboral</span>
                                            <h5>Empresas en las que ha trabajado</h5>
                                        </div>
                                    </div>
                                </div>
                                <div class="search-card-body history-card-body">
                                    <div class="history-list">
                                        {#each historial as item}
                                            {@const vigente = !item.fecret}
                                            <div class="history-item {vigente ? 'history-item--current' : 'history-item--retired'}">
                                                <div class="history-main">
                                                    <div class="history-company">{item.empresa_nombre || 'Sin nombre'}</div>
                                                    <div class="history-nit">NIT: {item.nit || ''}</div>
                                                </div>
                                                <div class="history-meta">
                                                    <span class="history-period">{item.fecafi} → {item.fecret || 'Vigente'}</span>
                                                    <span class="history-badge {vigente ? 'history-badge--vigente' : 'history-badge--retired'}">{vigente ? 'Vigente' : 'Retirado'}</span>
                                                </div>
                                            </div>
                                        {/each}
                                    </div>
                                </div>
                            </div>
                        {/if}

                    {:else if searchResults.type === 'NOMBRE'}
                        <div class="search-results-header">
                            <div class="search-results-title">
                                <i class="material-icons">people_alt</i>
                                <div>
                                    <h4>Búsqueda por nombre</h4>
                                    <p>Texto consultado: <span>{searchQuery}</span></p>
                                </div>
                            </div>
                            <span class="search-role-badge">COINCIDENCIAS ({searchResults.data.length})</span>
                        </div>

                        <div class="search-card">
                            <div class="search-card-header">
                                <div class="search-card-title">
                                    <i class="material-icons">list</i>
                                    <div>
                                        <span class="search-card-subtitle">Coincidencias encontradas</span>
                                        <h5>Selecciona una persona para más detalles (futuro)</h5>
                                    </div>
                                </div>
                            </div>
                            <div class="search-card-body">
                                <div class="name-results-list">
                                    {#each searchResults.data as item}
                                        {@const nombre = [item.prinom, item.segnom, item.priape, item.segape].filter(Boolean).join(' ')}
                                        {@const upperEstado = String(item.estado_desc || item.estado || '').toUpperCase()}
                                        {@const isActivo = upperEstado === 'ACTIVO' || upperEstado === 'A'}
                                        {@const edad = calculateAge(item.fecnac)}

                                        <div class="name-result-item {!isActivo ? 'name-result-item--inactive' : ''}">
                                            <div class="name-result-main">
                                                <span class="name-result-name">{nombre || 'Sin nombre'}</span>
                                                <!-- svelte-ignore a11y_click_events_have_key_events -->
                                                <!-- svelte-ignore a11y_no_static_element_interactions -->
                                                <span class="name-result-doc" on:click={() => copyTextToClipboard(String(item.documento))}>
                                                    {item.documento || ''}
                                                </span>
                                            </div>
                                            <div class="name-result-meta">
                                                <span class="name-result-role">{item.rol || 'SIN ROL'}</span>
                                                <span class="name-result-status">
                                                    {#if item.estado_desc || item.estado}
                                                        <span class="status-pill {isActivo ? 'status-pill--active' : 'status-pill--inactive'}">{item.estado_desc || item.estado}</span>
                                                    {:else}
                                                        <span class="search-field-empty">No registra</span>
                                                    {/if}
                                                </span>
                                            </div>
                                            <div class="name-result-extra">
                                                {#if edad !== ''}
                                                    <span class="name-result-chip">Edad: {edad} años</span>
                                                {/if}
                                                {#if item.codcat}
                                                    <span class="name-result-chip">Categoría: {item.codcat}</span>
                                                {/if}
                                            </div>
                                            <div class="name-result-extra">
                                                {#if item.telefono}
                                                    <span class="name-result-chip">Tel: {item.telefono}</span>
                                                {/if}
                                                {#if item.direccion}
                                                    <span class="name-result-chip">Dir: {item.direccion}</span>
                                                {/if}
                                                {#if isActivo && item.empresa_nombre}
                                                    <span class="name-result-company">{item.empresa_nombre}</span>
                                                {/if}
                                            </div>
                                        </div>
                                    {/each}
                                </div>
                            </div>
                        </div>

                    {:else if searchResults.type === 'EMPRESA'}
                        {@const emp = searchResults.data}
                        {@const trab = emp.trabajadores || []}
                        {@const totalTrabajadores = trab.length}
                        {@const totalConyuges = trab.filter(t => t.conyuge).length}
                        {@const totalBeneficiarios = trab.reduce((sum, t) => sum + (t.beneficiarios?.length || 0), 0)}

                        <div class="search-results-header empresa-header">
                            <div class="search-results-title">
                                <i class="material-icons">business</i>
                                <div>
                                    <h4>{emp.razsoc || 'Empresa'}</h4>
                                    <p>NIT: <span>{emp.nit || searchQuery}</span></p>
                                </div>
                            </div>
                            <div class="empresa-stats">
                                <span class="stat-badge"><i class="material-icons">people</i> {totalTrabajadores}</span>
                                <span class="stat-badge"><i class="material-icons">favorite</i> {totalConyuges}</span>
                                <span class="stat-badge"><i class="material-icons">child_care</i> {totalBeneficiarios}</span>
                            </div>
                        </div>

                        <div class="search-card">
                            <div class="search-card-header">
                                <div class="search-card-title">
                                    <i class="material-icons">business</i>
                                    <div>
                                        <span class="search-card-subtitle">Empresa actual</span>
                                        <h5>{emp.razsoc || emp.nomemp || 'Sin razón social'}</h5>
                                    </div>
                                </div>
                            </div>
                            <div class="search-card-body">
                                <div class="search-card-grid">
                                    <div class="search-field">
                                        <div class="search-field-label">Nombre Empleador</div>
                                        <div class="search-field-value">{[emp.prinom, emp.segnom, emp.priape, emp.segape].filter(Boolean).join(' ') || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Razón social</div>
                                        <div class="search-field-value">{emp.razsoc || emp.nomemp || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">NIT</div>
                                        <div class="search-field-value">{emp.nit || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Dirección</div>
                                        <div class="search-field-value">{emp.direccion || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Ciudad</div>
                                        <div class="search-field-value">{emp.codciu || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Teléfono</div>
                                        <div class="search-field-value">{emp.telefono || emp.telr || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Email</div>
                                        <div class="search-field-value">{emp.email || emp.mailt || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Fecha afiliación</div>
                                        <div class="search-field-value">{emp.fecafi || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Fecha última novedad</div>
                                        <div class="search-field-value">{emp.feccam || emp.feccor || 'No registra'}</div>
                                    </div>
                                    <div class="search-field">
                                        <div class="search-field-label">Estado</div>
                                        <div class="search-field-value">
                                            {#if emp.estado}
                                                <span class="status-pill {String(emp.estado).toUpperCase() === 'ACTIVO' || String(emp.estado).toUpperCase() === 'A' ? 'status-pill--active' : 'status-pill--inactive'}">{emp.estado}</span>
                                            {:else}
                                                <span class="search-field-empty">No registra</span>
                                            {/if}
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div class="search-card">
                            <div class="search-card-header">
                                <div class="search-card-title">
                                    <i class="material-icons">groups</i>
                                    <div>
                                        <span class="search-card-subtitle">Trabajadores activos</span>
                                        <h5>{totalTrabajadores} trabajador{totalTrabajadores !== 1 ? 'es' : ''} encontrado{totalTrabajadores !== 1 ? 's' : ''}</h5>
                                    </div>
                                </div>
                                {#if totalTrabajadores > 0}
                                    <button class="btn btn-secondary btn-sm" on:click={() => exportarExcelEmpresa(String(emp.nit), String(emp.razsoc))} style="display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 6px;">
                                        <i class="material-icons" style="font-size: 16px;">download</i>
                                        Exportar Excel
                                    </button>
                                {/if}
                            </div>

                            <div class="search-card-body">
                                {#if totalTrabajadores > 0}
                                    <div class="name-results-list">
                                        {#each trab as t, index}
                                            {@const tNombre = t.nombre || [t.priape, t.segape, t.prinom, t.segnom].filter(Boolean).join(' ') || 'Sin nombre'}
                                            {@const tEdad = calculateAge(t.fecnac)}
                                            {@const tieneFamilia = t.conyuge || (t.beneficiarios && t.beneficiarios.length > 0)}
                                            {@const totalBens = t.beneficiarios?.length || 0}

                                            <div class="name-result-item trabajador-item">
                                                <div class="name-result-main">
                                                    <span class="name-result-name">{tNombre}</span>
                                                    <span class="name-result-doc">{t.cedtra || ''}</span>
                                                </div>
                                                <div class="name-result-meta">
                                                    <span class="name-result-role">TRABAJADOR</span>
                                                    <span class="status-pill status-pill--active">ACTIVO</span>
                                                </div>
                                                <div class="name-result-extra">
                                                    {#if tEdad}
                                                        <span class="name-result-chip">Edad: {tEdad} años</span>
                                                    {/if}
                                                    {#if t.codcat}
                                                        <span class="name-result-chip">Cat: {t.codcat}</span>
                                                    {/if}
                                                    {#if t.cargo}
                                                        <span class="name-result-chip">{t.cargo}</span>
                                                    {/if}
                                                </div>
                                                <div class="name-result-extra">
                                                    {#if t.telefono}
                                                        <span class="name-result-chip">Tel: {t.telefono}</span>
                                                    {/if}
                                                    {#if t.salario}
                                                        <span class="name-result-chip salario-chip">{formatCurrency(t.salario)}</span>
                                                    {/if}
                                                </div>

                                                {#if tieneFamilia}
                                                    <!-- svelte-ignore a11y_click_events_have_key_events -->
                                                    <!-- svelte-ignore a11y_no_static_element_interactions -->
                                                    <div class="name-result-extra family-toggle" on:click={() => toggleTrabajadorFamily(index)}>
                                                        <span class="family-toggle-btn">
                                                            <i class="material-icons">family_restroom</i>
                                                            {#if t.conyuge}1 Cónyuge{/if}
                                                            {#if t.conyuge && totalBens > 0} + {/if}
                                                            {#if totalBens > 0}{totalBens} Beneficiario{totalBens > 1 ? 's' : ''}{/if}
                                                            <i class="material-icons toggle-icon" style="transform: {familyToggles[index] ? 'rotate(180deg)' : 'none'};">expand_more</i>
                                                        </span>
                                                    </div>

                                                    {#if familyToggles[index]}
                                                        <div class="trabajador-family-section">
                                                            {#if t.conyuge}
                                                                {@const con = t.conyuge}
                                                                {@const conNombre = con.nombre || [con.priape, con.segape, con.prinom, con.segnom].filter(Boolean).join(' ') || 'Sin nombre'}
                                                                {@const conEdad = calculateAge(con.fecnac)}
                                                                <div class="family-item conyuge-item" style="border-left-color: #E91E63;">
                                                                    <div class="family-item-icon"><i class="material-icons" style="color: #E91E63;">favorite</i></div>
                                                                    <div class="family-item-info">
                                                                        <span class="family-item-name">{conNombre}</span>
                                                                        <span class="family-item-doc">{con.cedcon || ''}</span>
                                                                    </div>
                                                                    <div class="family-item-meta" style="margin-left: auto; display: flex; align-items: center; gap: 8px;">
                                                                        {#if conEdad}
                                                                            <span class="name-result-chip" style="margin: 0;">{conEdad} años</span>
                                                                        {/if}
                                                                        <span class="family-badge conyuge-badge" style="background: rgba(233,30,99,0.15); color: #E91E63; font-size: 0.72rem; padding: 2px 8px; border-radius: 4px; font-weight: bold;">Cónyuge</span>
                                                                    </div>
                                                                </div>
                                                            {/if}

                                                            {#if t.beneficiarios && t.beneficiarios.length > 0}
                                                                {#each t.beneficiarios as ben}
                                                                    {@const benNombre = ben.nombre || [ben.priape, ben.segape, ben.prinom, ben.segnom].filter(Boolean).join(' ') || 'Sin nombre'}
                                                                    {@const benEdad = calculateAge(ben.fecnac)}
                                                                    <div class="family-item beneficiario-item" style="border-left-color: #2196F3;">
                                                                        <div class="family-item-icon"><i class="material-icons" style="color: #2196F3;">child_care</i></div>
                                                                        <div class="family-item-info">
                                                                            <span class="family-item-name">{benNombre}</span>
                                                                            <span class="family-item-doc">{ben.documento || ben.codben || ''}</span>
                                                                        </div>
                                                                        <div class="family-item-meta" style="margin-left: auto; display: flex; align-items: center; gap: 8px;">
                                                                            {#if benEdad}
                                                                                <span class="name-result-chip" style="margin: 0;">{benEdad} años</span>
                                                                            {/if}
                                                                            <span class="family-badge beneficiario-badge" style="background: rgba(33,150,243,0.15); color: #2196F3; font-size: 0.72rem; padding: 2px 8px; border-radius: 4px; font-weight: bold;">Beneficiario</span>
                                                                        </div>
                                                                    </div>
                                                                {/each}
                                                            {/if}
                                                        </div>
                                                    {/if}
                                                {/if}
                                            </div>
                                        {/each}
                                    </div>
                                {:else}
                                    <div class="no-workers-message" style="text-align: center; padding: 20px; color: var(--text-secondary);">
                                        <i class="material-icons" style="font-size: 36px; opacity: 0.5; margin-bottom: 6px;">person_off</i>
                                        <p>No se encontraron trabajadores activos en esta empresa</p>
                                    </div>
                                {/if}
                            </div>
                        </div>
                    {/if}
                {:else}
                    <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                        <i class="material-icons" style="font-size: 32px; opacity: 0.5; margin-bottom: 8px; display: block; width: 100%;">search</i>
                        <p>No se encontraron resultados para la consulta.</p>
                    </div>
                {/if}
            </div>
        {:else if isFemaleMode}
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon">water_drop</i>
                <span id="upcomingTitleText">Análisis del Ciclo</span>
            </h3>
            <div class="interaction-hint" id="interactionHint">
                <i class="material-icons" id="interactionHintIcon">touch_app</i>
                <span id="interactionHintText">Click: Ver ciclo del día | Doble click: Registrar periodo</span>
            </div>
            <div class="cycle-insights" id="cycleInsights" style="display: flex; flex-direction: column; gap: 10px; margin-top: 20px;">
                {#if selectedDay && selectedDay.cycleDetails}
                    <div class="insight-card">
                        <div class="insight-header">
                            <i class="material-icons">favorite</i>
                            <span class="insight-title">{selectedDay.cycleDetails.dateTitle}</span>
                        </div>
                        <div class="insight-desc">
                            <div style="margin-bottom: 12px; display: flex; align-items: center; gap: 8px; background: var(--bg-tertiary); padding: 8px 12px; border-radius: 8px; border-left: 4px solid {selectedDay.cycleDetails.fertilityColor};">
                                <i class="material-icons" style="color: {selectedDay.cycleDetails.fertilityColor};">child_care</i>
                                <span style="font-size: 0.9em;">Probabilidad de embarazo: <strong style="color: {selectedDay.cycleDetails.fertilityColor};">{selectedDay.cycleDetails.fertilityChance}</strong></span>
                            </div>
                            <div style="margin-bottom: 8px;"><strong>{selectedDay.cycleDetails.phase}</strong>:</div>
                            <div style="line-height: 1.5;">{selectedDay.cycleDetails.description}</div>
                            <div class="insight-progress-bg" style="width: 100%; height: 6px; background: rgba(0,0,0,0.2); border-radius: 3px; margin-top: 12px; overflow: hidden;">
                                <div class="insight-progress-bar" style="width: {selectedDay.cycleDetails.progressPercent}%; height: 100%; background: linear-gradient(90deg, #ff4081, #c51162); border-radius: 3px; transition: width 0.3s ease;"></div>
                            </div>
                        </div>
                    </div>
                    <div class="insight-card" style="margin-top: 15px;">
                        <div class="insight-header">
                            <i class="material-icons">water_drop</i>
                            <span class="insight-title">Próximo Periodo</span>
                        </div>
                        <div class="insight-desc">
                            Esperado en {selectedDay.cycleDetails.nextPeriodIn} día{selectedDay.cycleDetails.nextPeriodIn !== 1 ? 's' : ''}.
                        </div>
                    </div>
                    <div class="insight-card" style="margin-top: 15px;">
                        <div class="insight-header">
                            <i class="material-icons">palette</i>
                            <span class="insight-title">Leyenda de Colores</span>
                        </div>
                        <div class="insight-desc" style="display: flex; flex-direction: column; gap: 8px; margin-top: 10px;">
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <div style="width: 20px; height: 20px; border-radius: 50%; background: linear-gradient(135deg, #c2185b, #e91e63);"></div>
                                <span>Menstruación</span>
                            </div>
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <div style="width: 20px; height: 20px; border-radius: 50%; background: rgba(255, 105, 180, 0.2); border: 2px dashed rgba(255, 105, 180, 0.8);"></div>
                                <span>Ventana Fértil</span>
                            </div>
                            <div style="display: flex; align-items: center; gap: 10px;">
                                <div style="width: 20px; height: 20px; border-radius: 50%; background: linear-gradient(135deg, #ba68c8, #9c27b0); box-shadow: 0 0 10px rgba(156, 39, 176, 0.5);"></div>
                                <span>Ovulación</span>
                            </div>
                        </div>
                    </div>
                {:else if selectedDay}
                    <div class="text-center text-text-secondary w-full" style="padding: 20px 0;">
                        <i class="material-icons" style="font-size: 48px; opacity: 0.5; margin-bottom: 10px;">spa</i>
                        <p>Sin registros de ciclo para poder realizar el análisis. Empieza registrando tu periodo.</p>
                    </div>
                {:else}
                    <div class="text-center text-text-secondary w-full" style="padding: 20px 0;">
                        <i class="material-icons" style="font-size: 48px; opacity: 0.5; margin-bottom: 10px;">spa</i>
                        <p>Selecciona un día en el calendario para ver tu análisis de ciclo y recomendaciones diarias.</p>
                    </div>
                {/if}
            </div>
        {:else if isFinanceMode}
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon" style="color: #FFD700;">monetization_on</i>
                <span id="upcomingTitleText">Control de Finanzas</span>
            </h3>
            <div class="interaction-hint" id="interactionHint" style="border-left-color: #FFD700;">
                <i class="material-icons" id="interactionHintIcon" style="color: #FFD700;">touch_app</i>
                <span id="interactionHintText">Doble click en el calendario para registrar gasto/ingreso</span>
            </div>

            <!-- Finance Sub-tabs -->
            <div class="finance-subtabs">
                <button class="fin-tab {activeFinanceTab === 'resumen' ? 'active' : ''}" on:click={() => activeFinanceTab = 'resumen'}>
                    <i class="material-icons">analytics</i> Resumen
                </button>
                <button class="fin-tab {activeFinanceTab === 'cuentas' ? 'active' : ''}" on:click={() => activeFinanceTab = 'cuentas'}>
                    <i class="material-icons">credit_card</i> Cuentas
                </button>
                <button class="fin-tab {activeFinanceTab === 'metas' ? 'active' : ''}" on:click={() => activeFinanceTab = 'metas'}>
                    <i class="material-icons">flag</i> Metas
                </button>
                <button class="fin-tab {activeFinanceTab === 'presupuesto' ? 'active' : ''}" on:click={() => activeFinanceTab = 'presupuesto'}>
                    <i class="material-icons">pie_chart</i> Presupuesto
                </button>
                <button class="fin-tab {activeFinanceTab === 'planificador' ? 'active' : ''}" on:click={() => activeFinanceTab = 'planificador'}>
                    <i class="material-icons">schedule</i> Plan
                </button>
                <button class="fin-tab {activeFinanceTab === 'historial' ? 'active' : ''}" on:click={() => activeFinanceTab = 'historial'}>
                    <i class="material-icons">history</i> Historial
                </button>
                <button class="fin-tab {activeFinanceTab === 'graficos' ? 'active' : ''}" on:click={() => activeFinanceTab = 'graficos'}>
                    <i class="material-icons">query_stats</i> Gráficos
                </button>
            </div>

            {#if selectedDay}
                <div class="selected-day-header finance-filter-banner" style="border-left: 4px solid #FFD700; background: rgba(16, 79, 49, 0.25); display: flex; justify-content: space-between; align-items: center; padding: 10px 15px; border-radius: 8px; margin: 10px 0; border: 1px solid rgba(255, 215, 0, 0.15); animation: fadeIn 0.3s ease;">
                    <div class="selected-day-info" style="display: flex; flex-direction: column; gap: 2px;">
                        <h4 style="margin: 0; font-size: 0.9rem; display: flex; align-items: center; gap: 6px; color: var(--text-primary);">
                            <i class="material-icons" style="color: #FFD700; font-size: 18px;">calendar_today</i> 
                            Día: {selectedDay.dateStr}
                        </h4>
                        <p style="color: #90CBA6; font-size: 0.72rem; margin: 0;">Filtrando finanzas por este día</p>
                    </div>
                    <button class="icon-btn" on:click={() => selectedDay = null} title="Quitar filtro de día" style="padding: 4px; border-radius: 50%; background: rgba(255,255,255,0.05); display: flex; align-items: center; justify-content: center; cursor: pointer; border: none; color: var(--text-secondary);">
                        <i class="material-icons" style="font-size: 16px;">close</i>
                    </button>
                </div>
            {/if}

            <div class="upcoming-list" id="upcomingList" style="display: flex; flex-direction: column; gap: 10px; margin-top: 15px;">
                {#if activeFinanceTab === 'resumen'}
                    <!-- 1. PESTAÑA RESUMEN Y CONSEJOS -->
                    {#if selectedDay}
                        {@const dailyIncomes = selectedDayTransactions.filter(t => t.tipo === 'ingreso').reduce((sum, t) => sum + Number(t.monto), 0)}
                        {@const dailyExpenses = selectedDayTransactions.filter(t => t.tipo === 'gasto').reduce((sum, t) => sum + Number(t.monto), 0)}
                        <div class="finance-summary-card daily-summary-card" style="border-color: rgba(52, 228, 126, 0.35); background: rgba(16, 79, 49, 0.25); border-radius: 12px; padding: 15px; border: 1px solid var(--border-color); animation: fadeIn 0.3s ease; margin-bottom: 12px;">
                            <div class="finance-summary-title" style="display: flex; align-items: center; gap: 8px; font-weight: bold; font-size: 1rem; color: #34E47E; margin-bottom: 12px;">
                                <i class="material-icons" style="color: #34E47E;">today</i>
                                <span>Resumen del Día ({selectedDay.dateStr})</span>
                            </div>
                            <div class="finance-stat-row" style="display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 0.9rem;">
                                <span class="finance-stat-label" style="color: var(--text-secondary);">Ingresos de hoy:</span>
                                <span class="finance-stat-value green" style="color: #34E47E; font-weight: bold;">{formatPrice(dailyIncomes)}</span>
                            </div>
                            <div class="finance-stat-row" style="display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 0.9rem;">
                                <span class="finance-stat-label" style="color: var(--text-secondary);">Gastos de hoy:</span>
                                <span class="finance-stat-value red" style="color: #F44336; font-weight: bold;">{formatPrice(dailyExpenses)}</span>
                            </div>
                            <div class="finance-stat-row" style="display: flex; justify-content: space-between; border-top: 1px dashed var(--divider-color); margin-top: 8px; padding-top: 8px; font-size: 0.95rem;">
                                <span class="finance-stat-label" style="color: var(--text-primary); font-weight: bold;">Balance del día:</span>
                                <span class="finance-stat-value {dailyIncomes - dailyExpenses >= 0 ? 'green' : 'red'}" style="color: {dailyIncomes - dailyExpenses >= 0 ? '#34E47E' : '#F44336'}; font-weight: bold;">
                                    {formatPrice(dailyIncomes - dailyExpenses)}
                                </span>
                            </div>
                            
                            <div style="margin-top: 12px; font-size: 0.8rem; line-height: 1.4; color: var(--text-secondary); background: rgba(0,0,0,0.15); padding: 8px 10px; border-radius: 6px; display: flex; align-items: flex-start; gap: 6px;">
                                <i class="material-icons" style="font-size: 16px; color: #34E47E; margin-top: 2px;">tips_and_updates</i>
                                <span>
                                    {#if dailyExpenses === 0 && dailyIncomes === 0}
                                        No has registrado movimientos financieros hoy. ¡Excelente! Mantener un día libre de gastos es ideal para tu salud financiera.
                                    {:else if dailyExpenses > 0 && dailyExpenses > dailyIncomes}
                                        Hoy tus egresos superan tus ingresos. Trata de limitar las compras de impulso y compensar en los próximos días con cero gastos.
                                    {:else if dailyIncomes > 0 && dailyIncomes >= dailyExpenses}
                                        ¡Fantástico! Has recibido un ingreso hoy. Es el momento perfecto para destinar una parte directamente al ahorro o a tus metas.
                                    {/if}
                                </span>
                            </div>
                        </div>

                        <!-- Proyección de Inversiones (CDT/Cajitas) a futuro -->
                        {#if selectedDay.dateStr > getTodayLocal()}
                            {@const cdtCuentas = cuentasList.filter(c => c.tipo === 'cdt' && Number(c.interes_tasa) > 0)}
                            {#if cdtCuentas.length > 0}
                                {@const totalActual = cdtCuentas.reduce((acc, c) => acc + Number(c.saldo), 0)}
                                {@const totalProjected = cdtCuentas.reduce((acc, c) => acc + getProjectedCDTBalance(c, selectedDay.dateStr), 0)}
                                {@const totalYield = totalProjected - totalActual}
                                
                                <div class="finance-summary-card projection-summary-card" style="border: 1px solid rgba(79, 195, 247, 0.25); background: linear-gradient(135deg, rgba(16, 60, 79, 0.35), rgba(8, 30, 40, 0.2)); border-radius: 16px; padding: 16px; box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3); backdrop-filter: blur(4px); -webkit-backdrop-filter: blur(4px); animation: fadeIn 0.3s ease; margin-bottom: 15px; display: flex; flex-direction: column; gap: 12px;">
                                    <div style="display: flex; align-items: center; justify-content: space-between;">
                                        <div class="finance-summary-title" style="display: flex; align-items: center; gap: 8px; font-weight: bold; font-size: 0.95rem; color: #4FC3F7; margin-bottom: 0; padding: 0; background: transparent; border: none; height: auto;">
                                            <i class="material-icons" style="color: #4FC3F7; font-size: 20px;">insights</i>
                                            <span>Proyección de Rendimientos</span>
                                        </div>
                                        <span style="font-size: 0.72rem; color: #4FC3F7; background: rgba(79, 195, 247, 0.12); padding: 3px 8px; border-radius: 20px; font-weight: bold; letter-spacing: 0.5px;">
                                            {selectedDay.dateStr}
                                        </span>
                                    </div>
                                    
                                    <!-- Gran Métrica de Retorno Acumulado -->
                                    <div style="background: rgba(0, 0, 0, 0.2); border: 1px solid rgba(79, 195, 247, 0.1); border-radius: 12px; padding: 12px; text-align: center; display: flex; flex-direction: column; align-items: center; gap: 4px;">
                                        <span style="font-size: 0.7rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">Interés Total Acumulado Estimado</span>
                                        <span style="font-size: 1.6rem; font-weight: 800; color: #34E47E; letter-spacing: -0.5px; text-shadow: 0 0 10px rgba(52, 228, 126, 0.15);">
                                            +{formatPrice(totalYield)}
                                        </span>
                                        <span style="font-size: 0.72rem; color: var(--text-secondary);">
                                            Saldo Total Proyectado: <strong style="color: #E9EDEF;">{formatPrice(totalProjected)}</strong>
                                        </span>
                                    </div>

                                    <div style="display: flex; flex-direction: column; gap: 8px; margin-top: 4px;">
                                        {#each cdtCuentas as c}
                                            {@const projBalance = getProjectedCDTBalance(c, selectedDay.dateStr)}
                                            {@const accumulated = projBalance - Number(c.saldo)}
                                            <div style="background: rgba(255, 255, 255, 0.02); padding: 10px 12px; border-radius: 10px; border: 1px solid rgba(255, 255, 255, 0.05); display: flex; flex-direction: column; gap: 4px;">
                                                <div style="display: flex; justify-content: space-between; font-weight: 600; font-size: 0.85rem; color: var(--text-primary);">
                                                    <span>{c.nombre}</span>
                                                    <span style="color: #34E47E;">{formatPrice(projBalance)}</span>
                                                </div>
                                                <div style="display: flex; justify-content: space-between; font-size: 0.75rem; color: var(--text-secondary);">
                                                    <span>Ganancia estimada:</span>
                                                    <span style="color: #4FC3F7; font-weight: 600;">+{formatPrice(accumulated)}</span>
                                                </div>
                                                <div style="display: flex; justify-content: space-between; font-size: 0.7rem; color: var(--text-secondary); margin-top: 2px; border-top: 1px solid rgba(255,255,255,0.03); padding-top: 4px;">
                                                    <span>Tasa: <strong style="color: #DAA520;">{c.interes_tasa}% E.A.</strong></span>
                                                    <span>
                                                        {#if c.plazo_dias && Number(c.plazo_dias) > 0}
                                                            Plazo: <strong style="color: #E9EDEF;">{c.plazo_dias} días</strong>
                                                        {:else}
                                                            <strong style="color: #4FC3F7;">Rendimiento Continuo</strong>
                                                        {/if}
                                                    </span>
                                                </div>
                                            </div>
                                        {/each}
                                    </div>
                                </div>
                            {/if}
                        {/if}
                    {/if}

                    <div class="finance-summary-card" style="border-color: rgba(255, 215, 0, 0.25); background: rgba(15, 42, 28, 0.4); border-radius: 12px; padding: 15px; border: 1px solid var(--border-color);">
                        <div class="finance-summary-title" style="display: flex; align-items: center; gap: 8px; font-weight: bold; font-size: 1rem; color: #FFD700; margin-bottom: 12px;">
                            <i class="material-icons" style="color: #FFD700;">account_balance_wallet</i>
                            <span>Resumen Mensual (Este Mes)</span>
                        </div>
                        <div class="finance-stat-row" style="display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 0.9rem;">
                            <span class="finance-stat-label" style="color: var(--text-secondary);">Total Ingresos:</span>
                            <span class="finance-stat-value green" style="color: #34E47E; font-weight: bold;">{formatPrice(totalMonthlyIncomes)}</span>
                        </div>
                        <div class="finance-stat-row" style="display: flex; justify-content: space-between; margin-bottom: 8px; font-size: 0.9rem;">
                            <span class="finance-stat-label" style="color: var(--text-secondary);">Total Gastos:</span>
                            <span class="finance-stat-value red" style="color: #F44336; font-weight: bold;">{formatPrice(totalMonthlyExpenses)}</span>
                        </div>
                        <div class="finance-stat-row" style="display: flex; justify-content: space-between; border-top: 1px dashed var(--divider-color); margin-top: 8px; padding-top: 8px; font-size: 0.95rem;">
                            <span class="finance-stat-label" style="color: var(--text-primary); font-weight: bold;">Balance Neto:</span>
                            <span class="finance-stat-value {totalMonthlyIncomes - totalMonthlyExpenses >= 0 ? 'green' : 'red'}" style="color: {totalMonthlyIncomes - totalMonthlyExpenses >= 0 ? '#34E47E' : '#F44336'}; font-weight: bold;">
                                {formatPrice(totalMonthlyIncomes - totalMonthlyExpenses)}
                            </span>
                        </div>
                    </div>

                    <!-- Regla 50/30/20 -->
                    <div style="margin-top: 15px; background: rgba(0,0,0,0.2); border: 1px solid var(--border-color); border-radius: 12px; padding: 15px;">
                        <h4 style="color: #4FC3F7; font-size: 0.95rem; font-weight: bold; margin-bottom: 4px; display: flex; align-items: center; gap: 8px;">
                            <i class="material-icons">balance</i>
                            Regla 50 / 30 / 20
                        </h4>
                        <p style="font-size: 0.74rem; color: var(--text-secondary); margin-bottom: 14px;">
                            Distribución ideal de tus ingresos: 50% necesidades, 30% deseos, 20% ahorro.
                        </p>

                        {#if !regla503020.hasData}
                            <div style="font-size: 0.82rem; color: var(--text-secondary); background: rgba(0,0,0,0.15); padding: 12px; border-radius: 8px; text-align: center;">
                                Registra ingresos este mes para ver cómo se distribuye tu dinero.
                            </div>
                        {:else}
                            <!-- Barra apilada: distribución real -->
                            {@const segs = [
                                { key: 'n', pct: regla503020.needsPct, color: '#29B6F6' },
                                { key: 'w', pct: regla503020.wantsPct, color: '#FFA726' },
                                { key: 's', pct: Math.max(0, regla503020.savingsPct), color: '#34E47E' }
                            ]}
                            <div style="display: flex; height: 22px; border-radius: 8px; overflow: hidden; background: rgba(244,67,54,0.15); margin-bottom: 4px;">
                                {#each segs as seg}
                                    {#if seg.pct > 0}
                                        <div style="width: {Math.min(seg.pct, 100)}%; background: {seg.color}; transition: width 0.4s ease;"></div>
                                    {/if}
                                {/each}
                            </div>
                            <div style="font-size: 0.68rem; color: var(--text-tertiary); text-align: right; margin-bottom: 14px;">
                                {#if regla503020.savings < 0}
                                    <span style="color: #F44336;">⚠ Estás gastando más de lo que ingresas</span>
                                {:else}
                                    Distribución de {formatPrice(regla503020.income)} en ingresos
                                {/if}
                            </div>

                            <!-- Filas comparativas -->
                            {@const rows = [
                                { label: 'Necesidades', sub: 'Vivienda, comida, servicios, salud, transporte', ideal: '50%', color: '#29B6F6', pct: regla503020.needsPct, val: regla503020.needs, status: regla503020.needsStatus },
                                { label: 'Deseos', sub: 'Ocio, entretenimiento, antojos', ideal: '30%', color: '#FFA726', pct: regla503020.wantsPct, val: regla503020.wants, status: regla503020.wantsStatus },
                                { label: 'Ahorro / Deuda', sub: 'Lo que no gastas + abonos a ahorro', ideal: '20%', color: '#34E47E', pct: regla503020.savingsPct, val: regla503020.savings, status: regla503020.savingsStatus }
                            ]}
                            <div style="display: flex; flex-direction: column; gap: 10px;">
                                {#each rows as r}
                                    <div style="background: rgba(255,255,255,0.02); border: 1px solid rgba(255,255,255,0.05); border-radius: 8px; padding: 10px 12px; border-left: 4px solid {r.color};">
                                        <div style="display: flex; justify-content: space-between; align-items: center;">
                                            <div style="display: flex; align-items: center; gap: 8px;">
                                                <span style="width: 10px; height: 10px; border-radius: 50%; background: {r.color}; display: inline-block;"></span>
                                                <span style="font-size: 0.85rem; font-weight: bold; color: var(--text-primary);">{r.label}</span>
                                            </div>
                                            <div style="display: flex; align-items: center; gap: 8px;">
                                                <span style="font-size: 0.9rem; font-weight: 800; color: {r.status === 'ok' ? '#34E47E' : r.status === 'warn' ? '#FFA726' : '#F44336'};">
                                                    {r.pct.toFixed(0)}%
                                                </span>
                                                <span style="font-size: 0.7rem; color: var(--text-tertiary);">/ ideal {r.ideal}</span>
                                                <i class="material-icons" style="font-size: 16px; color: {r.status === 'ok' ? '#34E47E' : r.status === 'warn' ? '#FFA726' : '#F44336'};">
                                                    {r.status === 'ok' ? 'check_circle' : r.status === 'warn' ? 'warning' : 'error'}
                                                </i>
                                            </div>
                                        </div>
                                        <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 4px;">
                                            <span style="font-size: 0.7rem; color: var(--text-secondary);">{r.sub}</span>
                                            <span style="font-size: 0.78rem; font-weight: 600; color: var(--text-primary);">{formatPrice(r.val)}</span>
                                        </div>
                                    </div>
                                {/each}
                            </div>

                            <!-- Diagnóstico -->
                            <div style="margin-top: 12px; font-size: 0.78rem; line-height: 1.4; color: var(--text-secondary); background: rgba(79,195,247,0.06); border: 1px solid rgba(79,195,247,0.15); padding: 10px 12px; border-radius: 8px; display: flex; align-items: flex-start; gap: 8px;">
                                <i class="material-icons" style="font-size: 16px; color: #4FC3F7; margin-top: 1px; flex-shrink: 0;">tips_and_updates</i>
                                <span>
                                    {#if regla503020.savings < 0}
                                        Tus gastos superan tus ingresos este mes. Prioriza reducir los "deseos" y revisa si alguna "necesidad" se puede optimizar.
                                    {:else if regla503020.savingsStatus === 'ok' && regla503020.needsStatus === 'ok'}
                                        ¡Excelente equilibrio! Estás cumpliendo la regla 50/30/20. Mantén este ritmo y considera invertir tu ahorro.
                                    {:else if regla503020.savingsStatus === 'bad'}
                                        Tu ahorro está por debajo del 20% recomendado. Intenta recortar gastos en "deseos" para fortalecer tu colchón financiero.
                                    {:else if regla503020.needsStatus === 'bad'}
                                        Tus necesidades consumen más del 60% de tus ingresos. Esto deja poco margen; evalúa gastos fijos como vivienda o servicios.
                                    {:else}
                                        Vas por buen camino. Pequeños ajustes en "deseos" te acercarán al ahorro ideal del 20%.
                                    {/if}
                                </span>
                            </div>
                        {/if}
                    </div>

                    <!-- Caja del Experto en Economía -->
                    <div style="margin-top: 15px; background: rgba(0,0,0,0.2); border: 1px solid var(--border-color); border-radius: 12px; padding: 15px;">
                        <h4 style="color: #FFD700; font-size: 0.95rem; font-weight: bold; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                            <i class="material-icons">support_agent</i>
                            Consejos del Experto en Economía
                        </h4>
                        <div style="display: flex; flex-direction: column; gap: 10px;">
                            {#each recommendations as rec}
                                <div style="display: flex; gap: 10px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); padding: 10px; border-radius: 8px; border-left: 4px solid {rec.type === 'danger' ? '#F44336' : rec.type === 'warning' ? '#FFA726' : rec.type === 'success' ? '#34E47E' : '#29B6F6'};">
                                    <i class="material-icons" style="color: {rec.type === 'danger' ? '#F44336' : rec.type === 'warning' ? '#FFA726' : rec.type === 'success' ? '#34E47E' : '#29B6F6'}; font-size: 20px;">{rec.icon}</i>
                                    <div>
                                        <div style="font-weight: bold; font-size: 0.85rem; color: var(--text-primary);">{rec.title}</div>
                                        <p style="font-size: 0.78rem; color: var(--text-secondary); margin-top: 2px; line-height: 1.3;">{rec.text}</p>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    </div>

                {:else if activeFinanceTab === 'cuentas'}
                    <!-- 2. PESTAÑA MIS CUENTAS / TARJETAS -->
                    <button type="button" class="btn btn-secondary w-full" on:click={() => { accountData = { id: null, nombre: '', tipo: 'ahorros', saldo: 0, limite: 0, interes_tasa: 0, fecha_inicio: getTodayLocal(), plazo_dias: 0, dia_corte: null }; showAccountModal = true; }} style="margin-bottom: 10px; display: flex; align-items: center; justify-content: center; gap: 8px; border: 1px solid rgba(255, 215, 0, 0.3); background: rgba(255, 215, 0, 0.05); color: #FFD700;">
                        <i class="material-icons" style="font-size: 18px;">add_card</i> Agregar Tarjeta / Cuenta
                    </button>

                    {#if cuentasList.length > 0}
                        <div style="display: flex; flex-direction: column; gap: 10px;">
                            {#each cuentasList as c}
                                <div class="upcoming-item" style="border-left-color: {c.tipo === 'tarjeta_credito' ? '#FF5252' : c.tipo === 'cdt' ? '#B8860B' : '#4CAF50'}; border-left-width: 4px; background: rgba(255,255,255,0.03); border: 1px solid var(--border-color); border-radius: 14px; padding: 14px; display: flex; flex-direction: column; gap: 10px; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.15); transition: transform 0.2s ease, box-shadow 0.2s ease;">
                                    
                                    <!-- 1. Header: Icono + Nombre + Botones de Acción -->
                                    <div style="display: flex; justify-content: space-between; align-items: center;">
                                        <div style="display: flex; align-items: center; gap: 8px;">
                                            <i class="material-icons" style="color: {c.tipo === 'tarjeta_credito' ? '#FF5252' : c.tipo === 'cdt' ? '#DAA520' : '#4CAF50'}; font-size: 20px;">
                                                {c.tipo === 'tarjeta_credito' ? 'credit_card' : c.tipo === 'cdt' ? 'trending_up' : 'savings'}
                                            </i>
                                            <span style="font-weight: 700; font-size: 0.98rem; color: var(--text-primary);">{c.nombre}</span>
                                        </div>
                                        <div style="display: flex; gap: 6px;">
                                            <button class="icon-btn" style="width:26px; height:26px; display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 6px;" on:click={() => editAccount(c)} title="Editar">
                                                <i class="material-icons" style="font-size: 15px;">edit</i>
                                            </button>
                                            <button class="icon-btn" style="width:26px; height:26px; display: flex; align-items: center; justify-content: center; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.05); border-radius: 6px;" on:click={() => deleteAccount(c.id)} title="Eliminar">
                                                <i class="material-icons" style="font-size: 15px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>

                                    <!-- 2. Fila de Balance: Tipo de Cuenta + Saldo / Límite -->
                                    <div style="display: flex; justify-content: space-between; align-items: center; background: rgba(0,0,0,0.12); padding: 8px 12px; border-radius: 8px; border: 1px solid rgba(255,255,255,0.02);">
                                        <div style="display: flex; flex-direction: column; gap: 2px;">
                                            <span style="font-size: 0.65rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.8px; font-weight: bold;">Tipo de Cuenta</span>
                                            <span style="font-size: 0.72rem; font-weight: 600; color: {c.tipo === 'tarjeta_credito' ? '#FF5252' : c.tipo === 'cdt' ? '#DAA520' : '#4CAF50'}; text-transform: uppercase; letter-spacing: 0.5px;">
                                                {c.tipo.replace('_', ' ')}
                                            </span>
                                        </div>
                                        
                                        <!-- Mostramos saldo dinámico dependiendo de si hay proyección a futuro seleccionada -->
                                        {#if c.tipo === 'cdt' && selectedDay && selectedDay.dateStr > getTodayLocal()}
                                            {@const proj = getProjectedCDTBalance(c, selectedDay.dateStr)}
                                            <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 2px;">
                                                <span style="font-size: 0.65rem; color: var(--text-secondary); font-weight: bold; text-transform: uppercase; letter-spacing: 0.8px;">Saldo Proyectado</span>
                                                <div style="display: flex; align-items: center; gap: 4px;">
                                                    <span style="font-size: 1.15rem; font-weight: 800; color: #34E47E;">
                                                        {formatPrice(proj)}
                                                    </span>
                                                    <span style="font-size: 0.7rem; color: #4FC3F7; background: rgba(79, 195, 247, 0.1); padding: 1px 4px; border-radius: 4px; font-weight: bold;">
                                                        +{formatPrice(proj - Number(c.saldo))}
                                                    </span>
                                                </div>
                                            </div>
                                        {:else}
                                            <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 2px;">
                                                <span style="font-size: 0.65rem; color: var(--text-secondary); font-weight: bold; text-transform: uppercase; letter-spacing: 0.8px;">
                                                    {c.tipo === 'tarjeta_credito' ? 'Deuda Actual' : 'Saldo Disponible'}
                                                </span>
                                                <span style="font-size: 1.25rem; font-weight: 800; color: {c.tipo === 'tarjeta_credito' ? '#FF5252' : Number(c.saldo) >= 0 ? '#34E47E' : '#F44336'}; letter-spacing: -0.3px;">
                                                    {formatPrice(c.saldo)}
                                                </span>
                                            </div>
                                        {/if}
                                    </div>

                                    <!-- 3. Cupo Límite y Día de Corte si es Tarjeta de Crédito -->
                                    {#if c.tipo === 'tarjeta_credito'}
                                        <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem; color: var(--text-secondary); padding: 0 4px;">
                                            <span>Cupo Límite Autorizado:</span>
                                            <span style="font-weight: 600; color: var(--text-primary);">{formatPrice(c.limite)}</span>
                                        </div>
                                        {#if c.dia_corte}
                                            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem; color: var(--text-secondary); padding: 0 4px; margin-top: 4px;">
                                                <span style="display: flex; align-items: center; gap: 4px;"><i class="material-icons" style="font-size: 13px; color: #FFD700;">scissors</i> Día de Corte:</span>
                                                <span style="font-weight: 600; color: #FFD700;">Día {c.dia_corte} de cada mes</span>
                                            </div>
                                        {/if}
                                    {/if}

                                    <!-- 4. Bloque de Métricas CDT (Ocupa el 100% del Ancho) -->
                                    {#if c.tipo === 'cdt'}
                                        <div style="display: flex; flex-direction: column; gap: 8px; width: 100%; border-top: 1px solid rgba(255,255,255,0.06); padding-top: 10px; margin-top: 2px;">
                                            
                                            <!-- Grid de Métricas Premium -->
                                            <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; width: 100%;">
                                                
                                                <!-- Tasa Pactada -->
                                                <div style="background: rgba(255, 215, 0, 0.02); border: 1px solid rgba(255, 215, 0, 0.1); border-radius: 8px; padding: 6px 10px; display: flex; flex-direction: column; gap: 2px;">
                                                    <span style="font-size: 0.62rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">Tasa Pactada</span>
                                                    <span style="font-size: 0.85rem; font-weight: 700; color: #DAA520;">{c.interes_tasa || 0}% E.A.</span>
                                                </div>

                                                <!-- Rendimiento Diario -->
                                                <div style="background: rgba(52, 228, 126, 0.02); border: 1px solid rgba(52, 228, 126, 0.1); border-radius: 8px; padding: 6px 10px; display: flex; flex-direction: column; gap: 2px;">
                                                    <span style="font-size: 0.62rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">Rendimiento Diario</span>
                                                    <span style="font-size: 0.85rem; font-weight: 700; color: #34E47E;">+{formatPrice(calculateCDTDailyYield(c.saldo, c.interes_tasa))}</span>
                                                </div>

                                                {#if c.plazo_dias && Number(c.plazo_dias) > 0}
                                                    <!-- Retorno Total Estimado -->
                                                    <div style="background: rgba(79, 195, 247, 0.02); border: 1px solid rgba(79, 195, 247, 0.1); border-radius: 8px; padding: 6px 10px; display: flex; flex-direction: column; gap: 2px;">
                                                        <span style="font-size: 0.62rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">Retorno Estimado</span>
                                                        <span style="font-size: 0.85rem; font-weight: 700; color: #4FC3F7;">+{formatPrice(calculateCDTTotalYield(c.saldo, c.interes_tasa, c.plazo_dias))}</span>
                                                    </div>

                                                    <!-- Plazo / Días Restantes -->
                                                    <div style="background: rgba(233, 237, 239, 0.02); border: 1px solid rgba(233, 237, 239, 0.1); border-radius: 8px; padding: 6px 10px; display: flex; flex-direction: column; gap: 2px;">
                                                        <span style="font-size: 0.62rem; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px;">Plazo / Restante</span>
                                                        <span style="font-size: 0.85rem; font-weight: 700; color: #E9EDEF;">
                                                            {c.plazo_dias}d / <strong style="color: #4FC3F7;">{getDaysRemaining(c.fecha_inicio, c.plazo_dias)}d</strong>
                                                        </span>
                                                    </div>
                                                {:else}
                                                    <!-- Tipo Inversión (Para Cajita - Ocupa ambas columnas) -->
                                                    <div style="grid-column: span 2; background: rgba(79, 195, 247, 0.04); border: 1px solid rgba(79, 195, 247, 0.15); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; justify-content: center; gap: 6px;">
                                                        <i class="material-icons" style="font-size: 14px; color: #4FC3F7;">all_inclusive</i>
                                                        <span style="font-size: 0.72rem; font-weight: 600; color: #4FC3F7; text-transform: uppercase; letter-spacing: 0.5px;">Rendimiento Continuo (Cajita/Bolsillo)</span>
                                                    </div>
                                                {/if}
                                            </div>

                                            {#if c.plazo_dias && Number(c.plazo_dias) > 0}
                                                <!-- Fila de Vencimiento Completa con Barra de Progreso -->
                                                <div style="display: flex; flex-direction: column; gap: 4px; margin-top: 2px; background: rgba(0, 0, 0, 0.1); padding: 8px 10px; border-radius: 8px; border: 1px solid rgba(255, 255, 255, 0.02);">
                                                    <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: var(--text-secondary);">
                                                        <span>Vence: <strong style="color: var(--text-primary);">{getMaturityDateStr(c.fecha_inicio, c.plazo_dias)}</strong></span>
                                                        <span style="font-weight: 600; color: #DAA520;">{getCDTProgressPercent(c.fecha_inicio, c.plazo_dias).toFixed(0)}%</span>
                                                    </div>
                                                    <!-- Barra de progreso del plazo -->
                                                    <div style="width: 100%; height: 6px; background: rgba(255,255,255,0.06); border-radius: 3px; overflow: hidden; position: relative;" title="Progreso del plazo">
                                                        <div style="width: {getCDTProgressPercent(c.fecha_inicio, c.plazo_dias)}%; height: 100%; background: linear-gradient(90deg, #b8860b, #daa520, #ffd700); border-radius: 3px; box-shadow: 0 0 8px rgba(255, 215, 0, 0.3);"></div>
                                                    </div>
                                                </div>
                                            {/if}
                                        </div>
                                    {/if}

                                    <!-- 5. Bloque de Proyección de Rendimientos (Full-Width, Estilo Glassmorphism Premium) -->
                                    {#if c.tipo === 'cdt' && selectedDay && selectedDay.dateStr > getTodayLocal()}
                                        {@const proj = getProjectedCDTBalance(c, selectedDay.dateStr)}
                                        {@const diffDays = Math.ceil((new Date(selectedDay.dateStr + 'T00:00:00') - new Date(getTodayLocal() + 'T00:00:00')) / (1000 * 60 * 60 * 24))}
                                        {@const hasMaturity = c.plazo_dias && Number(c.plazo_dias) > 0}
                                        {@const daysToMaturity = hasMaturity ? Math.ceil((new Date(new Date(c.fecha_inicio + 'T00:00:00').getTime() + Number(c.plazo_dias) * 24 * 60 * 60 * 1000) - new Date(getTodayLocal() + 'T00:00:00')) / (1000 * 60 * 60 * 24)) : 999999}
                                        {@const compoundDays = hasMaturity && diffDays > daysToMaturity ? Math.max(0, daysToMaturity) : diffDays}
                                        {@const limitReached = hasMaturity && diffDays > daysToMaturity}
                                        
                                        <div style="margin-top: 4px; padding: 12px; background: linear-gradient(135deg, rgba(79, 195, 247, 0.08), rgba(79, 195, 247, 0.01)); border: 1px solid rgba(79, 195, 247, 0.2); border-radius: 10px; display: flex; flex-direction: column; gap: 6px; box-shadow: 0 4px 15px rgba(0,0,0,0.15), inset 0 1px 1px rgba(255,255,255,0.05); animation: fadeIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);">
                                            <div style="display: flex; align-items: center; justify-content: space-between; border-bottom: 1px solid rgba(79, 195, 247, 0.12); padding-bottom: 6px; margin-bottom: 2px;">
                                                <div style="display: flex; align-items: center; gap: 6px; font-size: 0.72rem; color: #4FC3F7; font-weight: bold; text-transform: uppercase; letter-spacing: 0.5px;">
                                                    <i class="material-icons" style="font-size: 15px; color: #4FC3F7;">online_prediction</i>
                                                    <span>Detalle de Proyección</span>
                                                </div>
                                                <span style="font-size: 0.7rem; color: var(--text-secondary); background: rgba(255, 255, 255, 0.05); padding: 2px 6px; border-radius: 10px;">
                                                    {selectedDay.dateStr}
                                                </span>
                                            </div>
                                            
                                            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem;">
                                                <span style="color: var(--text-secondary);">Tiempo transcurrido:</span>
                                                <span style="font-weight: 600; color: #E9EDEF;">{diffDays} días</span>
                                            </div>
                                            
                                            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem;">
                                                <span style="color: var(--text-secondary);">Días capitalizados:</span>
                                                <span style="font-weight: 600; color: #4FC3F7;">{compoundDays} días</span>
                                            </div>
                                            
                                            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.78rem;">
                                                <span style="color: var(--text-secondary);">Interés estimado:</span>
                                                <span style="font-weight: bold; color: #34E47E; font-size: 0.82rem;">+{formatPrice(proj - Number(c.saldo))}</span>
                                            </div>

                                            {#if limitReached}
                                                <div style="margin-top: 4px; padding: 6px 8px; background: rgba(255, 167, 38, 0.08); border: 1px solid rgba(255, 167, 38, 0.25); border-radius: 6px; font-size: 0.65rem; color: #FFA726; display: flex; align-items: flex-start; gap: 4px; line-height: 1.3;">
                                                    <i class="material-icons" style="font-size: 12px; margin-top: 1px; color: #FFA726;">warning_amber</i>
                                                    <span>CDT vence a los {daysToMaturity} días ({getMaturityDateStr(c.fecha_inicio, c.plazo_dias)}). Capitalización finalizada.</span>
                                                </div>
                                            {/if}
                                        </div>
                                    {/if}

                                    <!-- 6. Movimientos del Día -->
                                    {#if selectedDay}
                                        {@const cardTxs = selectedDayTransactions.filter(t => t.cuenta_id === c.id)}
                                        {@const startBalance = getAccountStartBalance(c, selectedDay.dateStr, transaccionesList)}
                                        <div style="border-top: 1px dashed rgba(255,255,255,0.08); padding-top: 8px; margin-top: 2px;">
                                            <div style="font-size: 0.72rem; color: var(--text-secondary); margin-bottom: 6px; display: flex; align-items: center; justify-content: space-between;">
                                                <div style="display: flex; align-items: center; gap: 4px;">
                                                    <i class="material-icons" style="font-size: 14px; color: #FFD700;">receipt_long</i>
                                                    <span>Movimientos de hoy:</span>
                                                </div>
                                                <span>Inicio del día: <span style="font-weight: bold; color: {startBalance >= 0 ? '#34E47E' : '#F44336'};">{formatPrice(startBalance)}</span></span>
                                            </div>
                                            {#if cardTxs.length > 0}
                                                <div style="display: flex; flex-direction: column; gap: 4px;">
                                                    {#each cardTxs as tx}
                                                        <div style="display: flex; justify-content: space-between; align-items: center; background: rgba(0,0,0,0.15); padding: 5px 8px; border-radius: 6px; font-size: 0.76rem;">
                                                            <div style="display: flex; align-items: center; gap: 4px; min-width: 0; flex: 1;">
                                                                <i class="material-icons" style="font-size: 12px; color: {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'};">{tx.tipo === 'ingreso' ? 'arrow_upward' : 'arrow_downward'}</i>
                                                                <span style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--text-primary);">{tx.descripcion}</span>
                                                            </div>
                                                            <span style="font-weight: bold; color: {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'}; margin-left: 6px;">
                                                                {tx.tipo === 'ingreso' ? '+' : '-'}{formatPrice(tx.monto)}
                                                            </span>
                                                        </div>
                                                    {/each}
                                                </div>
                                            {:else}
                                                <div style="font-size: 0.72rem; color: var(--text-secondary); font-style: italic; opacity: 0.75; padding-left: 16px;">
                                                    Sin movimientos hoy.
                                                </div>
                                            {/if}
                                        </div>
                                    {/if}
                                </div>
                            {/each}
                        </div>
                    {:else}
                        <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                            <i class="material-icons" style="font-size: 32px; opacity: 0.5; margin-bottom: 8px; display: block; width: 100%;">credit_card</i>
                            No tienes tarjetas ni cuentas registradas. Comienza registrando una haciendo click en el botón de arriba.
                        </div>
                    {/if}

                {:else if activeFinanceTab === 'planificador'}
                    <!-- 3. PESTAÑA PLANIFICADOR -->
                    <button type="button" class="btn btn-secondary w-full" on:click={() => { plannedIncomeData = { id: null, cuenta_id: '', descripcion: '', monto: 0, frecuencia: 'mensual', fecha_inicio: '' }; showPlannedIncomeModal = true; }} style="margin-bottom: 12px; display: flex; align-items: center; justify-content: center; gap: 8px; border: 1px solid rgba(255, 215, 0, 0.3); background: rgba(255, 215, 0, 0.05); color: #FFD700;">
                        <i class="material-icons" style="font-size: 18px;">date_range</i> Planificar Ingreso Recurrente
                    </button>

                    <div style="margin-top: 10px;">
                        {#if selectedDay}
                            {@const dayOccurrences = occurrencesList.filter(o => o.fecha_esperada === selectedDay.dateStr)}
                            <h4 style="color: var(--text-primary); font-size: 0.9rem; font-weight: bold; margin-bottom: 8px;">Cobros/Ingresos Planeados para hoy ({dayOccurrences.length})</h4>
                            
                            {#if dayOccurrences.length > 0}
                                <div style="display: flex; flex-direction: column; gap: 10px; max-height: 300px; overflow-y: auto;">
                                    {#each dayOccurrences as occ}
                                        <div style="background: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 10px 12px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; border-left: 4px solid {occ.verificado ? '#34E47E' : '#FFA726'};">
                                            <div>
                                                <div style="font-weight: bold; font-size: 0.85rem; color: var(--text-primary);">{occ.descripcion}</div>
                                                <div style="font-size: 0.72rem; color: var(--text-secondary); margin-top: 2px;">
                                                    Esperado: {occ.fecha_esperada} ({occ.frecuencia})
                                                    {#if occ.verificado}
                                                        <div style="color: #34E47E; margin-top: 2px;">✔ Recibido el {occ.fecha_real}</div>
                                                    {/if}
                                                </div>
                                            </div>
                                            <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 4px;">
                                                <span style="font-weight: bold; font-size: 0.85rem; color: {occ.verificado ? '#34E47E' : '#FFA726'};">
                                                    {occ.verificado ? formatPrice(occ.monto_real) : formatPrice(occ.monto)}
                                                </span>
                                                {#if !occ.verificado}
                                                    <button class="btn btn-primary btn-sm" style="font-size: 0.7rem; padding: 3px 8px; border-radius: 4px;" on:click={() => openVerifyModal(occ)}>
                                                        Verificar
                                                    </button>
                                                {:else}
                                                    <button class="btn btn-secondary btn-sm" style="font-size: 0.7rem; padding: 3px 8px; border-radius: 4px; color: var(--danger);" on:click={() => undoVerification(occ.verificacionId)}>
                                                        Deshacer
                                                    </button>
                                                {/if}
                                            </div>
                                        </div>
                                    {/each}
                                </div>
                            {:else}
                                <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 15px; text-align: center; color: var(--text-secondary); font-size: 0.8rem;">
                                    No hay cobros ni ingresos recurrentes previstos para este día.
                                </div>
                            {/if}
                        {:else}
                            <h4 style="color: var(--text-primary); font-size: 0.9rem; font-weight: bold; margin-bottom: 8px;">Cobros/Ingresos Esperados del Mes ({pendingOccurrences.length})</h4>
                            
                            {#if occurrencesList.length > 0}
                                <div style="display: flex; flex-direction: column; gap: 10px; max-height: 300px; overflow-y: auto;">
                                    {#each occurrencesList as occ}
                                        <div style="background: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 10px 12px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; border-left: 4px solid {occ.verificado ? '#34E47E' : '#FFA726'};">
                                            <div>
                                                <div style="font-weight: bold; font-size: 0.85rem; color: var(--text-primary);">{occ.descripcion}</div>
                                                <div style="font-size: 0.72rem; color: var(--text-secondary); margin-top: 2px;">
                                                    Esperado: {occ.fecha_esperada} ({occ.frecuencia})
                                                    {#if occ.verificado}
                                                        <div style="color: #34E47E; margin-top: 2px;">✔ Recibido el {occ.fecha_real}</div>
                                                    {/if}
                                                </div>
                                            </div>
                                            <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 4px;">
                                                <span style="font-weight: bold; font-size: 0.85rem; color: {occ.verificado ? '#34E47E' : '#FFA726'};">
                                                    {occ.verificado ? formatPrice(occ.monto_real) : formatPrice(occ.monto)}
                                                </span>
                                                {#if !occ.verificado}
                                                    <button class="btn btn-primary btn-sm" style="font-size: 0.7rem; padding: 3px 8px; border-radius: 4px;" on:click={() => openVerifyModal(occ)}>
                                                        Verificar
                                                    </button>
                                                {:else}
                                                    <button class="btn btn-secondary btn-sm" style="font-size: 0.7rem; padding: 3px 8px; border-radius: 4px; color: var(--danger);" on:click={() => undoVerification(occ.verificacionId)}>
                                                        Deshacer
                                                    </button>
                                                {/if}
                                            </div>
                                        </div>
                                    {/each}
                                </div>
                            {:else}
                                <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 15px; text-align: center; color: var(--text-secondary); font-size: 0.8rem;">
                                    No hay ingresos previstos para este mes en tu calendario de planificación.
                                </div>
                            {/if}
                        {/if}
                    </div>

                    <div style="margin-top: 20px; border-top: 1px dashed var(--divider-color); padding-top: 15px;">
                        <h4 style="color: var(--text-primary); font-size: 0.9rem; font-weight: bold; margin-bottom: 8px;">Configuración de Recurrentes</h4>
                        {#if ingresosPlanificadosList.length > 0}
                            <div style="display: flex; flex-direction: column; gap: 8px;">
                                {#each ingresosPlanificadosList as plan}
                                    <div style="background: rgba(0,0,0,0.15); border: 1px solid rgba(255,255,255,0.05); padding: 8px 12px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                                        <div>
                                            <span style="font-weight: 500; font-size: 0.85rem;">{plan.descripcion}</span>
                                            <div style="font-size: 0.7rem; color: var(--text-secondary);">Monto: {formatPrice(plan.monto)} | Frec: {plan.frecuencia}</div>
                                        </div>
                                        <button class="icon-btn" style="width:28px; height:28px;" on:click={() => deletePlannedIncome(plan.id)} title="Eliminar">
                                            <i class="material-icons" style="font-size: 16px; color: var(--danger);">delete</i>
                                        </button>
                                    </div>
                                {/each}
                            </div>
                        {:else}
                            <div style="color: var(--text-secondary); font-size: 0.75rem; text-align: center;">Sin ingresos recurrentes configurados.</div>
                        {/if}
                    </div>

                {:else if activeFinanceTab === 'metas'}
                    <!-- PESTAÑA METAS DE AHORRO -->
                    <button type="button" class="fin-add-btn" on:click={() => { metaData = { id: null, nombre: '', descripcion: '', monto_objetivo: 0, monto_actual: 0, fecha_objetivo: '', icono: 'savings', color: '#34E47E', completada: false }; showMetaModal = true; }}>
                        <i class="material-icons">add</i> Nueva Meta de Ahorro
                    </button>

                    {#if metasList.length > 0}
                        <div class="metas-grid">
                            {#each metasList as meta}
                                {@const pct = getMetaProgress(meta)}
                                {@const daysLeft = getDaysUntilGoal(meta.fecha_objetivo)}
                                <div class="meta-card {meta.completada ? 'completed' : ''}" style="--meta-color: {meta.color || '#34E47E'}">
                                    <div class="meta-card-header">
                                        <div class="meta-icon-wrap" style="background: {meta.color}22; color: {meta.color};">
                                            <i class="material-icons">{meta.icono || 'savings'}</i>
                                        </div>
                                        <div class="meta-title-block">
                                            <span class="meta-nombre">{meta.nombre}</span>
                                            {#if meta.completada}
                                                <span class="meta-badge completed-badge">✅ Completada</span>
                                            {:else if daysLeft !== null}
                                                <span class="meta-badge {daysLeft < 0 ? 'overdue-badge' : daysLeft <= 30 ? 'soon-badge' : 'normal-badge'}">
                                                    {daysLeft < 0 ? `Venció hace ${Math.abs(daysLeft)}d` : `${daysLeft}d restantes`}
                                                </span>
                                            {/if}
                                        </div>
                                        <div class="meta-actions">
                                            {#if selectedDay}
                                                <button class="icon-btn" style="width:26px; height:26px; color: #34E47E;" on:click={() => openContributionModal(meta)} title="Registrar aporte hoy">
                                                    <i class="material-icons" style="font-size: 15px;">savings</i>
                                                </button>
                                            {/if}
                                            <button class="icon-btn" style="width:26px; height:26px;" on:click={() => editMeta(meta)} title="Editar">
                                                <i class="material-icons" style="font-size: 15px;">edit</i>
                                            </button>
                                            <button class="icon-btn" style="width:26px; height:26px;" on:click={() => deleteMeta(meta.id)} title="Eliminar">
                                                <i class="material-icons" style="font-size: 15px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>

                                    {#if selectedDay && meta.fecha_objetivo === selectedDay.dateStr}
                                        <div style="background: rgba(255, 215, 0, 0.15); border: 1px solid rgba(255, 215, 0, 0.3); border-radius: 6px; padding: 6px 10px; margin: 4px 0 8px 0; font-size: 0.75rem; display: flex; align-items: center; gap: 6px; color: #FFD700;">
                                            <i class="material-icons" style="font-size: 14px;">alarm</i>
                                            <span>¡Hoy es la fecha límite de esta meta!</span>
                                        </div>
                                    {/if}

                                    {#if meta.descripcion}
                                        <p class="meta-desc">{meta.descripcion}</p>
                                    {/if}

                                    <div class="meta-progress-section">
                                        <div class="meta-amounts">
                                            <span class="meta-actual" style="color: {meta.color};">{formatPrice(meta.monto_actual)}</span>
                                            <span class="meta-separator">/</span>
                                            <span class="meta-objetivo">{formatPrice(meta.monto_objetivo)}</span>
                                        </div>
                                        <div class="meta-progress-bar-bg">
                                            <div class="meta-progress-bar-fill"
                                                style="width: {pct}%; background: linear-gradient(90deg, {meta.color}99, {meta.color});"
                                            ></div>
                                        </div>
                                        <div class="meta-pct-label">{pct}% alcanzado</div>
                                    </div>
                                </div>
                            {/each}
                        </div>
                    {:else}
                        <div class="fin-empty-state">
                            <i class="material-icons" style="font-size: 40px; color: #34E47E; opacity: 0.5;">flag</i>
                            <p>No tienes metas de ahorro. ¡Crea una y empieza a construir tu futuro!</p>
                        </div>
                    {/if}

                {:else if activeFinanceTab === 'presupuesto'}
                    <!-- PESTAÑA PRESUPUESTO + CATEGORÍAS (inline) -->

                    <!-- Divisor -->
                    <div style="display:flex; align-items:center; gap:10px; margin-bottom:14px;">
                        <div style="flex:1; height:1px; background:var(--divider-color);"></div>
                        <span style="font-size:0.78rem; font-weight:700; color:var(--text-secondary); letter-spacing:0.06em; text-transform:uppercase;">Límites Mensuales</span>
                        <div style="flex:1; height:1px; background:var(--divider-color);"></div>
                    </div>

                    <!-- Grid de presupuestos por categoría -->
                    <div class="budget-grid">
                        {#each TRANSACTIONS_CATEGORIES.filter(c => c.value !== 'otros') as cat}
                            {@const bs = getBudgetStatus(cat.value, presupuestosList, monthlyTransactions)}
                            {@const dailySpent = selectedDay ? selectedDayTransactions.filter(t => t.tipo === 'gasto' && t.categoria === cat.value).reduce((sum, t) => sum + Number(t.monto), 0) : 0}
                            <!-- svelte-ignore a11y_no_static_element_interactions -->
                            <div class="budget-card {bs.status}" on:dblclick={() => editPresupuestoByCategoria(cat.value)} style="cursor: pointer;" title="Doble clic para editar">
                                <div class="budget-card-top">
                                    <div class="budget-cat-icon">
                                        <i class="material-icons">{cat.icon}</i>
                                    </div>
                                    <div class="budget-cat-label">{cat.label}</div>
                                    {#if bs.limit > 0}
                                        <button class="icon-btn" style="width:22px; height:22px; margin-left: auto;" on:click={() => deletePresupuesto(bs.id)} title="Eliminar límite">
                                            <i class="material-icons" style="font-size: 14px; color: var(--danger);">close</i>
                                        </button>
                                    {/if}
                                </div>

                                <div class="budget-amounts">
                                    <span class="budget-spent" style="color: {bs.status === 'danger' ? '#F44336' : bs.status === 'warning' ? '#FFA726' : 'var(--text-primary)'};">
                                        {formatPrice(bs.spent)}
                                    </span>
                                    {#if bs.limit > 0}
                                        <span class="budget-limit">/ {formatPrice(bs.limit)}</span>
                                    {:else}
                                        <button class="budget-set-btn" on:click={() => editPresupuestoByCategoria(cat.value)}>+ Límite</button>
                                    {/if}
                                </div>

                                {#if bs.limit > 0}
                                    <div class="budget-bar-bg">
                                        <div class="budget-bar-fill {bs.status}" style="width: {bs.pct}%;"></div>
                                    </div>
                                    <div class="budget-pct">
                                        {#if bs.status === 'danger'}<span style="color:#F44336;">⚠ Excedido ({bs.pct}%)</span>
                                        {:else if bs.status === 'warning'}<span style="color:#FFA726;">⚡ {bs.pct}% usado</span>
                                        {:else}<span style="color:#34E47E;">{bs.pct}% usado</span>
                                        {/if}
                                    </div>
                                {/if}

                                {#if selectedDay && dailySpent > 0}
                                    <div class="budget-daily-spent" style="font-size: 0.74rem; color: #FFA726; margin-top: 6px; display: flex; align-items: center; gap: 4px; border-top: 1px dashed rgba(255,255,255,0.05); padding-top: 6px;">
                                        <i class="material-icons" style="font-size: 13px; color: #FFA726;">shopping_basket</i>
                                        <span>Gastado hoy: <strong style="color: #fff;">{formatPrice(dailySpent)}</strong></span>
                                    </div>
                                {/if}
                            </div>
                        {/each}
                    </div>

                    <!-- Divisor -->
                    <div style="display:flex; align-items:center; gap:10px; margin:18px 0 14px;">
                        <div style="flex:1; height:1px; background:var(--divider-color);"></div>
                        <span style="font-size:0.78rem; font-weight:700; color:var(--text-secondary); letter-spacing:0.06em; text-transform:uppercase;">Mis Categorías</span>
                        <div style="flex:1; height:1px; background:var(--divider-color);"></div>
                    </div>

                    <!-- Sección: Mis Categorías -->
                    <div style="margin-bottom: 18px;">
                        <div style="display:flex; align-items:center; justify-content:flex-end; margin-bottom:10px;">
                            <span style="font-size:0.72rem; color:var(--text-tertiary);">{categoriasFinanzas.length} categorías</span>
                        </div>

                        <!-- Lista de categorías existentes -->
                        <div style="display:flex; flex-direction:column; gap:6px; margin-bottom:10px;">
                            {#each categoriasFinanzas as cat}
                                {@const enUso = categoriasEnUso.has(cat.valor)}
                                <div style="display:flex; align-items:center; gap:10px; background:rgba(255,255,255,0.02); border:1px solid var(--border-color); border-radius:8px; padding:8px 12px;">
                                    <i class="material-icons" style="color:#FFA726; font-size:18px;">{cat.icono}</i>
                                    <span style="flex:1; font-size:0.85rem; color:var(--text-primary);">{cat.label}</span>
                                    {#if cat.es_default}
                                        <span style="font-size:0.65rem; color:var(--text-tertiary); border:1px solid var(--border-color); border-radius:5px; padding:2px 6px;">predefinida</span>
                                    {/if}
                                    {#if enUso}
                                        <span title="Tiene registros asociados, no se puede eliminar" style="display:flex; align-items:center; color:var(--text-tertiary);">
                                            <i class="material-icons" style="font-size:16px;">lock</i>
                                        </span>
                                    {:else}
                                        <button class="icon-btn" style="width:26px; height:26px;" on:click={() => eliminarCategoria(cat)} title="Eliminar categoría">
                                            <i class="material-icons" style="font-size:16px; color:var(--danger);">delete</i>
                                        </button>
                                    {/if}
                                </div>
                            {/each}
                        </div>

                        <!-- Formulario nueva categoría -->
                        <div style="background:rgba(255,167,38,0.04); border:1px dashed rgba(255,167,38,0.25); border-radius:10px; padding:10px;">
                            <label style="font-size:0.74rem; color:var(--text-secondary); display:block; margin-bottom:8px;">➕ Nueva categoría personalizada</label>
                            <div style="display:flex; gap:8px; align-items:center; flex-wrap:wrap;">
                                <select bind:value={nuevaCategoriaIcono} style="padding:8px; border-radius:8px; border:1px solid var(--border-color); background:var(--bg-tertiary); color:var(--text-primary); min-width:130px;">
                                    {#each ICONOS_CATEGORIA as ic}
                                        <option value={ic.value}>{ic.label}</option>
                                    {/each}
                                </select>
                                <div style="display:flex; align-items:center; justify-content:center; width:36px; height:36px; border-radius:8px; background:var(--bg-tertiary); border:1px solid var(--border-color); flex-shrink:0;">
                                    <i class="material-icons" style="color:#FFA726; font-size:20px;">{nuevaCategoriaIcono}</i>
                                </div>
                                <input
                                    type="text"
                                    bind:value={nuevaCategoriaLabel}
                                    on:keydown={(e) => { if (e.key === 'Enter') { e.preventDefault(); crearCategoria(); } }}
                                    placeholder="Nombre, ej: Mascotas, Viajes..."
                                    maxlength="100"
                                    style="flex:1; min-width:120px; padding:8px 10px; border-radius:8px; border:1px solid var(--border-color); background:var(--bg-tertiary); color:var(--text-primary);"
                                />
                                <button type="button" disabled={categoriaGuardando} on:click={crearCategoria}
                                    style="padding:8px 14px; border-radius:8px; background:#FFA726; color:#000; font-weight:700; border:none; cursor:pointer; font-size:0.82rem; display:flex; align-items:center; gap:4px;">
                                    <i class="material-icons" style="font-size:16px;">add</i> Agregar
                                </button>
                            </div>
                            {#if categoriaError}
                                <p style="color:#F44336; font-size:0.76rem; margin-top:6px;">{categoriaError}</p>
                            {/if}
                        </div>
                    </div>

                {:else if activeFinanceTab === 'historial'}
                    <!-- 4. PESTAÑA HISTORIAL -->
                    <button type="button" class="fin-add-btn" on:click={() => { transactionData = { id: null, cuenta_id: '', tipo: 'gasto', monto: 0, descripcion: '', fecha: selectedDay ? selectedDay.dateStr : getTodayLocal(), categoria: 'otros', cuotas: 1 }; showTransactionModal = true; }}>
                        <i class="material-icons">add</i> Registrar Transacción {selectedDay ? 'para hoy' : 'Manual'}
                    </button>

                    {#if selectedDay}
                        <h4 style="color: var(--text-primary); font-size: 0.9rem; font-weight: bold; margin: 12px 0 8px 0;">Transacciones de hoy ({selectedDayTransactions.length})</h4>
                        {#if selectedDayTransactions.length > 0}
                            <div style="display: flex; flex-direction: column; gap: 10px; max-height: 450px; overflow-y: auto;">
                                {#each selectedDayTransactions as tx}
                                    <div
                                        on:dblclick={() => editTransaction(tx)}
                                        title="Doble click para editar"
                                        style="background: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 10px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; border-left: 4px solid {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'}; cursor: pointer; user-select: none;">
                                        <div>
                                            <div style="font-weight: bold; font-size: 0.85rem; color: var(--text-primary);">{tx.descripcion}</div>
                                            <div style="font-size: 0.72rem; color: var(--text-secondary); margin-top: 2px;">
                                                📅 {toDateOnly(tx.fecha)} | {cuentasList.find(c => c.id === tx.cuenta_id)?.nombre || 'Sin cuenta'} | {tx.categoria || 'otros'}
                                            </div>
                                        </div>
                                        <div style="display: flex; align-items: center; gap: 10px;">
                                            <span style="font-weight: bold; font-size: 0.88rem; color: {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'};">
                                                {tx.tipo === 'ingreso' ? '+' : '-'}{formatPrice(tx.monto)}
                                            </span>
                                            <button class="icon-btn" style="width:24px; height:24px;" on:click|stopPropagation={() => deleteTransaction(tx.id)} title="Eliminar">
                                                <i class="material-icons" style="font-size: 16px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {:else}
                            <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                                No hay transacciones registradas para hoy. ¿Deseas agregar una usando el botón superior?
                            </div>
                        {/if}
                    {:else}
                        {#if transaccionesList.length > 0}
                            <div style="display: flex; flex-direction: column; gap: 10px; max-height: 450px; overflow-y: auto;">
                                {#each transaccionesList as tx}
                                    <div
                                        on:dblclick={() => editTransaction(tx)}
                                        title="Doble click para editar"
                                        style="background: rgba(255,255,255,0.02); border: 1px solid var(--border-color); padding: 10px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; border-left: 4px solid {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'}; cursor: pointer; user-select: none;">
                                        <div>
                                            <div style="font-weight: bold; font-size: 0.85rem; color: var(--text-primary);">{tx.descripcion}</div>
                                            <div style="font-size: 0.72rem; color: var(--text-secondary); margin-top: 2px;">
                                                📅 {toDateOnly(tx.fecha)} | {cuentasList.find(c => c.id === tx.cuenta_id)?.nombre || 'Sin cuenta'} | {tx.categoria || 'otros'}
                                            </div>
                                        </div>
                                        <div style="display: flex; align-items: center; gap: 10px;">
                                            <span style="font-weight: bold; font-size: 0.88rem; color: {tx.tipo === 'ingreso' ? '#34E47E' : '#F44336'};">
                                                {tx.tipo === 'ingreso' ? '+' : '-'}{formatPrice(tx.monto)}
                                            </span>
                                            <button class="icon-btn" style="width:24px; height:24px;" on:click|stopPropagation={() => deleteTransaction(tx.id)} title="Eliminar">
                                                <i class="material-icons" style="font-size: 16px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {:else}
                            <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                                No has registrado gastos ni ingresos aún. Agrega tu primer registro con el botón superior.
                            </div>
                        {/if}
                    {/if}
                {:else if activeFinanceTab === 'graficos'}
                    <!-- 7. PESTAÑA GRÁFICOS AVANZADOS -->
                    <AdvancedAnalytics cuentas={cuentasList} transacciones={transaccionesList} categorias={categoriasFinanzas} />
                {/if}
            </div>

        {:else if isNotesMode}
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon" style="color: #4FC3F7;">edit_note</i>
                <span id="upcomingTitleText">Notas Rápidas</span>
            </h3>
            <div class="interaction-hint" id="interactionHint" style="border-left-color: #4FC3F7;">
                <i class="material-icons" id="interactionHintIcon" style="color: #4FC3F7;">touch_app</i>
                <span id="interactionHintText">Click: Ver notas del día | Doble click: Crear nota rápida</span>
            </div>
            
            <div class="upcoming-list" id="upcomingList" style="display: flex; flex-direction: column; gap: 10px; margin-top: 20px;">
                {#if selectedDay}
                    <div class="selected-day-header" style="border-left-color: #4FC3F7; background: rgba(13, 71, 161, 0.25);">
                        <div class="selected-day-info">
                            <h4>
                                <i class="material-icons" style="color: #4FC3F7;">calendar_today</i> 
                                {selectedDay.dateStr}
                            </h4>
                            <p style="color: #90CAF9;">Notas del Día</p>
                        </div>
                        <button class="icon-btn" on:click={() => selectedDay = null} title="Ver todas las notas">
                            <i class="material-icons">close</i>
                        </button>
                    </div>

                    <div class="selected-day-body" style="display: flex; flex-direction: column; gap: 10px; margin-top: 10px;">
                        {#if selectedDayNotes.length > 0}
                            {#each selectedDayNotes as note}
                                <div class="upcoming-item selected-day-item" style="border-left-color: {note.color || '#4FC3F7'}; background: rgba(27, 38, 68, 0.4); display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: 8px; border-left-width: 4px;">
                                    <div style="display: flex; align-items: center; justify-content: space-between; width: 100%;">
                                        <span style="background: {note.color || '#4FC3F7'}; color: #000; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: bold; text-transform: uppercase;">
                                            {note.etiqueta}
                                        </span>
                                        <div style="display: flex; gap: 4px;">
                                            <button class="action-btn edit" on:click={() => editNote(note)} title="Editar nota">
                                                <i class="material-icons" style="font-size: 18px;">edit</i>
                                            </button>
                                            <button class="action-btn delete" on:click={() => deleteNote(note.id)} title="Eliminar nota">
                                                <i class="material-icons" style="font-size: 18px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>
                                    <p style="color: var(--text-primary); font-size: 0.9rem; line-height: 1.4; white-space: pre-wrap; margin: 0;">{note.contenido}</p>
                                </div>
                            {/each}
                        {:else}
                            <div class="text-center text-text-secondary" style="padding: 20px 0;">
                                <p>No hay notas registradas para este día.</p>
                                <button type="button" class="btn btn-primary btn-sm" on:click={() => { noteData = { id: null, contenido: '', etiqueta: 'personal', color: '#4FC3F7' }; showNoteModal = true; }} style="margin-top: 10px; background-color: #4FC3F7; color: #000;">
                                    <i class="material-icons" style="font-size: 16px;">add</i> Crear Nota
                                </button>
                            </div>
                        {/if}
                    </div>
                {:else}
                    <!-- Resumen General / Últimas notas -->
                    <div style="display: flex; flex-direction: column; gap: 12px;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                            <h4 style="color: var(--text-primary); font-size: 0.95rem; font-weight: 500;">
                                Todas tus Notas ({notesList.length})
                            </h4>
                        </div>

                        {#if notesList.length > 0}
                            <div style="display: flex; flex-direction: column; gap: 10px; max-height: 500px; overflow-y: auto; padding-right: 4px;">
                                {#each notesList as note}
                                    <div class="upcoming-item" style="border-left-color: {note.color || '#4FC3F7'}; border-left-width: 4px; background: var(--bg-tertiary); display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: 8px;">
                                        <div style="display: flex; align-items: center; justify-content: space-between;">
                                            <span style="font-size: 0.75rem; color: var(--text-secondary); font-weight: 500;">
                                                📅 {toDateOnly(note.fecha)}
                                            </span>
                                            <span style="background: {note.color || '#4FC3F7'}; color: #000; padding: 1px 6px; border-radius: 3px; font-size: 0.7rem; font-weight: bold; text-transform: uppercase;">
                                                {note.etiqueta}
                                            </span>
                                        </div>
                                        <p style="color: var(--text-primary); font-size: 0.85rem; margin: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                            {note.contenido}
                                        </p>
                                        <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 4px; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 4px;">
                                            <button class="icon-btn" style="width:24px; height:24px;" on:click={() => { selectedDay = { dateStr: toDateOnly(note.fecha) }; editNote(note); }} title="Editar">
                                                <i class="material-icons" style="font-size: 16px;">edit</i>
                                            </button>
                                            <button class="icon-btn" style="width:24px; height:24px;" on:click={() => deleteNote(note.id)} title="Eliminar">
                                                <i class="material-icons" style="font-size: 16px; color: var(--danger);">delete</i>
                                            </button>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {:else}
                            <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                                <i class="material-icons" style="font-size: 32px; opacity: 0.5; margin-bottom: 8px; display: block; width: 100%;">edit_note</i>
                                No tienes notas guardadas. Haz doble click en cualquier día del calendario para agregar una nota rápida.
                            </div>
                        {/if}
                    </div>
                {/if}
            </div>

        {:else if isHabitsMode}
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon" style="color: #4CAF50;">self_improvement</i>
                <span id="upcomingTitleText">Hábitos y Bienestar</span>
            </h3>
            <div class="interaction-hint" id="interactionHint" style="border-left-color: #4CAF50;">
                <i class="material-icons" id="interactionHintIcon" style="color: #4CAF50;">touch_app</i>
                <span id="interactionHintText">Click en círculo para marcar completado | Doble click en el calendario para crear hábito</span>
            </div>

            <div class="upcoming-list" id="upcomingList" style="display: flex; flex-direction: column; gap: 10px; margin-top: 20px;">
                <button type="button" class="btn btn-secondary w-full" on:click={() => { habitData = { id: null, nombre: '', icono: 'check_circle', color: '#4CAF50', frecuencia: 'diario', meta_diaria: 1 }; showHabitModal = true; }} style="margin-bottom: 10px; display: flex; align-items: center; justify-content: center; gap: 8px; border: 1px solid rgba(76, 175, 80, 0.3); background: rgba(76, 175, 80, 0.05); color: #81C784;">
                    <i class="material-icons" style="font-size: 18px;">add_task</i> Crear Nuevo Hábito
                </button>

                {#if selectedDay}
                    <div class="selected-day-header" style="border-left-color: #4CAF50; background: rgba(27, 94, 32, 0.25);">
                        <div class="selected-day-info">
                            <h4>
                                <i class="material-icons" style="color: #4CAF50;">calendar_today</i> 
                                {selectedDay.dateStr}
                            </h4>
                            <p style="color: #A5D6A7;">Progreso de Hábitos</p>
                        </div>
                        <button class="icon-btn" on:click={() => selectedDay = null} title="Ver resumen de rachas">
                            <i class="material-icons">close</i>
                        </button>
                    </div>

                    <div class="selected-day-body" style="display: flex; flex-direction: column; gap: 10px; margin-top: 10px;">
                        {#if habitsList.length > 0}
                            {#each habitsList as habit}
                                {@const log = selectedDayHabitLogs.find(l => l.habito_id === habit.id)}
                                {@const isDone = !!(log && log.completado)}
                                <div class="upcoming-item selected-day-item" style="border-left-color: {habit.color || '#4CAF50'}; background: rgba(25, 59, 29, 0.4); display: flex; align-items: center; justify-content: space-between; padding: 12px; border-radius: 8px; border-left-width: 4px;">
                                    <div style="display: flex; align-items: center; gap: 12px; flex: 1; min-width: 0;">
                                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                                        <div on:click={() => toggleHabitLog(habit.id, selectedDay.dateStr, isDone)} style="cursor: pointer; display: flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 50%; border: 2px solid {isDone ? (habit.color || '#4CAF50') : 'var(--text-secondary)'}; background: {isDone ? (habit.color || '#4CAF50') : 'transparent'}; color: {isDone ? '#fff' : 'transparent'}; transition: all 0.2s ease;">
                                            {#if isDone}
                                                <i class="material-icons" style="font-size: 16px; font-weight: bold;">done</i>
                                            {/if}
                                        </div>
                                        <div style="display: flex; align-items: center; gap: 8px; min-width: 0; flex: 1;">
                                            <i class="material-icons" style="color: {habit.color || '#4CAF50'}; font-size: 20px;">{habit.icono || 'check_circle'}</i>
                                            <span style="font-size: 0.95rem; font-weight: 500; text-decoration: {isDone ? 'line-through' : 'none'}; color: {isDone ? 'var(--text-secondary)' : 'var(--text-primary)'}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
                                                {habit.nombre}
                                            </span>
                                        </div>
                                    </div>
                                    
                                    <div style="display: flex; align-items: center; gap: 6px;">
                                        <span class="streak-badge" style="font-size: 0.75rem; background: rgba(255, 167, 38, 0.15); color: #FFA726; padding: 2px 8px; border-radius: 4px; display: inline-flex; align-items: center; gap: 3px;" title="Racha actual">
                                            <i class="material-icons" style="font-size: 14px;">local_fire_department</i>
                                            {getHabitStreak(habit.id, habitLogsList)}d
                                        </span>
                                        <button class="icon-btn" style="width: 28px; height: 28px;" on:click={() => editHabit(habit)} title="Editar hábito">
                                            <i class="material-icons" style="font-size: 16px;">edit</i>
                                        </button>
                                        <button class="icon-btn" style="width: 28px; height: 28px;" on:click={() => deleteHabit(habit.id)} title="Eliminar hábito">
                                            <i class="material-icons" style="font-size: 16px; color: var(--danger);">delete</i>
                                        </button>
                                    </div>
                                </div>
                            {/each}
                        {:else}
                            <div class="text-center text-text-secondary" style="padding: 20px 0;">
                                <p>No tienes hábitos configurados.</p>
                                <button type="button" class="btn btn-primary btn-sm" on:click={() => { habitData = { id: null, nombre: '', icono: 'check_circle', color: '#4CAF50', frecuencia: 'diario', meta_diaria: 1 }; showHabitModal = true; }} style="margin-top: 10px; background-color: #4CAF50; color: #fff;">
                                    <i class="material-icons" style="font-size: 16px;">add</i> Agregar Hábito
                                </button>
                            </div>
                        {/if}
                    </div>
                {:else}
                    <!-- Resumen General / Rachas de Hábitos -->
                    <div style="display: flex; flex-direction: column; gap: 12px;">
                        <h4 style="color: var(--text-primary); font-size: 0.95rem; font-weight: 500;">
                            Tus Hábitos Activos ({habitsList.length})
                        </h4>

                        {#if habitsList.length > 0}
                            <div style="display: flex; flex-direction: column; gap: 10px;">
                                {#each habitsList as habit}
                                    {@const streak = getHabitStreak(habit.id, habitLogsList)}
                                    <div class="upcoming-item" style="border-left-color: {habit.color || '#4CAF50'}; border-left-width: 4px; background: var(--bg-tertiary); display: flex; align-items: center; justify-content: space-between; padding: 12px; border-radius: 8px;">
                                        <div style="display: flex; align-items: center; gap: 8px;">
                                            <i class="material-icons" style="color: {habit.color || '#4CAF50'};">{habit.icono || 'check_circle'}</i>
                                            <span style="font-weight: 500; font-size: 0.9rem;">{habit.nombre}</span>
                                        </div>
                                        <div style="display: flex; align-items: center; gap: 12px;">
                                            <span style="font-size: 0.8rem; color: var(--text-secondary); text-transform: capitalize;">{habit.frecuencia}</span>
                                            <span class="streak-badge" style="font-size: 0.8rem; background: rgba(255, 167, 38, 0.2); color: #FFA726; padding: 2px 8px; border-radius: 6px; display: inline-flex; align-items: center; gap: 4px; font-weight: bold;">
                                                <i class="material-icons" style="font-size: 16px;">local_fire_department</i>
                                                {streak} días
                                            </span>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {:else}
                            <div style="background: rgba(0,0,0,0.1); border: 1px dashed var(--border-color); border-radius: 8px; padding: 25px; text-align: center; color: var(--text-secondary); font-size: 0.85rem;">
                                <i class="material-icons" style="font-size: 32px; opacity: 0.5; margin-bottom: 8px; display: block; width: 100%;">self_improvement</i>
                                Registra tus hábitos diarios. Comienza por crear uno nuevo haciendo click en el botón de arriba.
                            </div>
                        {/if}
                    </div>
                {/if}
            </div>

        {:else}
            <!-- Detalle del Día (Modo Normal) -->
            <h3 id="upcomingTitle">
                <i class="material-icons" id="upcomingIcon">schedule</i>
                <span id="upcomingTitleText">Detalle del Día</span>
            </h3>
            <div class="interaction-hint" id="interactionHint">
                <i class="material-icons" id="interactionHintIcon">touch_app</i>
                <span id="interactionHintText">Click: Ver día | Doble click: Crear evento</span>
            </div>
            <div class="upcoming-list" id="upcomingList" style="display: flex; flex-direction: column; gap: 10px; margin-top: 20px;">
                {#if selectedDay}
                    {@const isHoliday = !!selectedDay.holiday}
                    {@const isImportant = !!selectedDay.importantDay}
                    {@const hasEvents = selectedDay.dayEvents && selectedDay.dayEvents.length > 0}
                    {@const hasBirthdays = selectedDay.dayBirthdays && selectedDay.dayBirthdays.length > 0}
                    {@const headerClass = isHoliday ? 'is-holiday' : isImportant ? 'has-important' : ''}
                    {@const headerIcon = isHoliday ? 'celebration' : isImportant ? 'star' : hasBirthdays ? 'cake' : 'event'}

                    <div class="selected-day-header {headerClass}">
                        <div class="selected-day-info">
                            <h4>
                                <i class="material-icons">{headerIcon}</i> 
                                {selectedDay.dateStr}
                            </h4>
                            {#if isHoliday}
                                <p class="holiday-name">🎉 {selectedDay.holiday.name || selectedDay.holiday.localName}</p>
                            {:else if isImportant}
                                <p class="holiday-name">★ {selectedDay.importantDay.nombre}</p>
                            {/if}
                            {#if hasBirthdays}
                                <p class="birthday-count">🎂 {selectedDay.dayBirthdays.length} cumpleaños</p>
                            {/if}
                            {#if hasEvents}
                                <p>{selectedDay.dayEvents.length} evento(s)</p>
                            {/if}
                        </div>
                        <button class="icon-btn" on:click={() => selectedDay = null} title="Ver próximos eventos">
                            <i class="material-icons">close</i>
                        </button>
                    </div>

                    <div class="selected-day-body">
                        {#if isHoliday}
                            <div class="holiday-info-card">
                                <div class="holiday-info-header">
                                    <i class="material-icons">info</i>
                                    <h5>Información del Festivo</h5>
                                </div>
                                <div class="holiday-info-content">
                                    <div class="holiday-info-item">
                                        <span class="holiday-info-label">Nombre:</span>
                                        <span class="holiday-info-value">{selectedDay.holiday.name || selectedDay.holiday.localName}</span>
                                    </div>
                                    <div class="holiday-info-item">
                                        <span class="holiday-info-label">Tipo:</span>
                                        <span class="holiday-info-value">{selectedDay.holiday.type || 'Festivo Nacional'}</span>
                                    </div>
                                    <div class="holiday-badge">
                                        <i class="material-icons">event_available</i>
                                        <span>Día No Laboral</span>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {#if isImportant}
                            <div class="holiday-info-card important-info-card">
                                <div class="holiday-info-header">
                                    <i class="material-icons">info</i>
                                    <h5>Día importante</h5>
                                </div>
                                <div class="holiday-info-content">
                                    <div class="holiday-info-item">
                                        <span class="holiday-info-label">Nombre:</span>
                                        <span class="holiday-info-value">{selectedDay.importantDay.nombre}</span>
                                    </div>
                                    <div class="holiday-info-item">
                                        <span class="holiday-info-label">Categoría:</span>
                                        <span class="holiday-info-value">{selectedDay.importantDay.categoria || 'Sin categoría'}</span>
                                    </div>
                                    {#if selectedDay.importantDay.descripcion}
                                        <div class="holiday-info-item">
                                            <span class="holiday-info-label">Descripción:</span>
                                            <span class="holiday-info-value">{selectedDay.importantDay.descripcion}</span>
                                        </div>
                                    {/if}
                                    <div class="holiday-badge important-badge">
                                        <i class="material-icons">star</i>
                                        <span>Día especial</span>
                                    </div>
                                </div>
                            </div>
                        {/if}

                        {#if hasEvents}
                            {#each selectedDay.dayEvents as ev}
                                <div class="upcoming-item selected-day-item" style="display: flex; flex-direction: column; align-items: stretch; gap: 8px;">
                                    <div style="display: flex; align-items: center; justify-content: space-between; width: 100%;">
                                        <div style="display: flex; align-items: center; gap: 10px; flex: 1; min-width: 0;">
                                            <div class="event-time-badge">
                                                <i class="material-icons">schedule</i>
                                                <span>{ev.hora ? ev.hora.slice(0, 5) : '00:00'}</span>
                                            </div>
                                            <div class="upcoming-details" style="min-width: 0; flex: 1;">
                                                <div class="upcoming-title" style="white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">{ev.titulo || 'Evento'}</div>
                                                {#if ev.ubicacion}
                                                    <div class="upcoming-meta">
                                                        <span><i class="material-icons">place</i>{ev.ubicacion}</span>
                                                    </div>
                                                {/if}
                                            </div>
                                        </div>
                                        <div class="upcoming-actions" style="margin-left: 8px; flex-shrink: 0;">
                                            <button class="action-btn edit" title="Editar" on:click={() => editEvent(ev)}>
                                                <i class="material-icons">edit</i>
                                            </button>
                                            <button class="action-btn delete" title="Eliminar" on:click={() => deleteEvent(ev)}>
                                                <i class="material-icons">delete</i>
                                            </button>
                                        </div>
                                    </div>


                                    <!-- Simulador de WhatsApp -->
                                    <div class="whatsapp-simulator">
                                        <div class="simulator-header">
                                            <i class="material-icons">share</i>
                                            <span>Recordatorio de WhatsApp</span>
                                        </div>
                                        <div class="simulator-body">
                                            <textarea readonly>{getWhatsAppMessage(ev)}</textarea>
                                            <div class="simulator-actions">
                                                <button type="button" class="btn btn-secondary btn-sm" on:click={() => copyToClipboard(getWhatsAppMessage(ev))}>
                                                    <i class="material-icons" style="font-size: 14px;">content_copy</i> Copiar
                                                </button>
                                                <a href="https://web.whatsapp.com/send?text={encodeURIComponent(getWhatsAppMessage(ev))}" target="_blank" class="btn btn-primary btn-sm btn-wa">
                                                    <i class="material-icons" style="font-size: 14px;">send</i> WhatsApp
                                                </a>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            {/each}
                        {/if}

                        {#if hasBirthdays}
                            <div class="birthdays-section">
                                <h5 class="section-title">
                                    <i class="material-icons">cake</i>
                                    Cumpleaños del Día
                                </h5>
                                {#each selectedDay.dayBirthdays as birthday}
                                    {@const age = birthday.anio_nacimiento ? (currentYear - birthday.anio_nacimiento) : null}
                                    <div class="birthday-item" style="position: relative;">
                                        <div class="birthday-icon">
                                            🎂
                                        </div>
                                        <div class="birthday-details">
                                            <div class="birthday-name">{birthday.nombre}</div>
                                            {#if age !== null}
                                                <div class="birthday-age">
                                                    <i class="material-icons">celebration</i>
                                                    <span>Cumple {age} años</span>
                                                </div>
                                            {/if}
                                            {#if birthday.mensaje}
                                                <div style="font-size: 0.85rem; color: var(--text-secondary); margin-top: 4px; font-style: italic;">"{birthday.mensaje}"</div>
                                            {/if}
                                        </div>
                                        <div class="upcoming-actions" style="position: absolute; right: 15px; top: 50%; transform: translateY(-50%); display: flex; gap: 5px;">
                                            <button class="action-btn edit" title="Editar" on:click={() => editCumpleanos(birthday)}>
                                                <i class="material-icons">edit</i>
                                            </button>
                                            <button class="action-btn delete" title="Eliminar" on:click={() => deleteCumpleanos(birthday.id)}>
                                                <i class="material-icons">delete</i>
                                            </button>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        {/if}

                        {#if !isHoliday && !isImportant && !hasEvents && !hasBirthdays}
                            <div class="text-center text-text-secondary" style="margin-top: 20px;">
                                <p>Día libre, no tienes eventos ni cumpleaños programados.</p>
                            </div>
                        {/if}
                    </div>
                {:else}
                    <!-- Vista sin día seleccionado: próximos eventos del mes -->
                    {@const upcomingEvents = currentMonthEvents.filter(e => {
                        const today = getTodayLocal();
                        return toDateOnly(e.fecha) >= today;
                    }).sort((a, b) => a.fecha.localeCompare(b.fecha)).slice(0, 5)}

                    {#if upcomingEvents.length > 0}
                        <div style="margin-bottom: 12px;">
                            <h4 style="color: var(--text-primary); font-size: 0.95rem; font-weight: 500; margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
                                <i class="material-icons" style="color: var(--wa-green); font-size: 20px;">upcoming</i>
                                Próximos Eventos
                            </h4>
                            <div style="display: flex; flex-direction: column; gap: 8px;">
                                {#each upcomingEvents as ev}
                                    <div class="upcoming-mini-card">
                                        <div class="upcoming-mini-left">
                                            <div class="upcoming-mini-date">
                                                <span class="upcoming-mini-day">{toDateOnly(ev.fecha).split('-')[2]}</span>
                                                <span class="upcoming-mini-month">{['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'][Number(toDateOnly(ev.fecha).split('-')[1]) - 1]}</span>
                                            </div>
                                            <div class="upcoming-mini-info">
                                                <span class="upcoming-mini-title">{ev.titulo}</span>
                                                <span class="upcoming-mini-time">
                                                    <i class="material-icons" style="font-size: 12px;">schedule</i>
                                                    {ev.hora ? ev.hora.slice(0, 5) : 'Todo el día'}
                                                </span>
                                            </div>
                                        </div>
                                    </div>
                                {/each}
                            </div>
                        </div>
                    {/if}

                    <div class="text-center text-text-secondary w-full" style="padding: 20px 0;">
                        <i class="material-icons" style="font-size: 48px; opacity: 0.5; margin-bottom: 10px;">event_available</i>
                        <p>Selecciona un día en el calendario para ver sus detalles o eventos.</p>
                    </div>
                {/if}
            </div>
        {/if}
    </div>
</main>

<!-- Footer -->
<footer class="app-footer">
    <div class="app-footer-inner">
        <span>SaaS - Sesión de <strong>{userName}</strong></span>
    </div>
</footer>

<!-- Modales -->
{#if showEventModal}
<div class="modal active">
    <div class="modal-content">
        <div class="modal-header">
            <h3>Nuevo Evento</h3>
            <button class="modal-close" on:click={() => showEventModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveEvent}>
            <div class="form-group">
                <label>
                    <i class="material-icons">category</i>
                    Categoría
                </label>
                <!-- on:click|stopPropagation en el custom-select-trigger -->
                <div class="custom-select-wrapper {showCategoryDropdown ? 'open' : ''}">
                    <!-- svelte-ignore a11y_click_events_have_key_events -->
                    <!-- svelte-ignore a11y_no_static_element_interactions -->
                    <div class="custom-select-trigger" on:click={() => showCategoryDropdown = !showCategoryDropdown}>
                        <i class="material-icons">{selectedCategoryObj.icon}</i>
                        <span>{selectedCategoryObj.label}</span>
                        <i class="material-icons arrow">arrow_drop_down</i>
                    </div>
                    {#if showCategoryDropdown}
                    <div class="custom-select-options active">
                        <div class="custom-select-search">
                            <input type="text" bind:value={categorySearch} placeholder="Buscar categoría...">
                        </div>
                        <div class="options-list">
                            {#each filteredCategories as cat}
                                <!-- svelte-ignore a11y_click_events_have_key_events -->
                                <!-- svelte-ignore a11y_no_static_element_interactions -->
                                <div class="custom-option" on:click={() => { 
                                    eventData.categoria = cat.value; 
                                    if (cat.value === 'arriendo') {
                                        eventData.tipo_transaccion = 'gasto';
                                        eventData.frecuencia = 'mensual';
                                    }
                                    showCategoryDropdown = false; 
                                    categorySearch = ''; 
                                }}>
                                    <i class="material-icons">{cat.icon}</i>
                                    <span>{cat.label}</span>
                                </div>
                            {/each}
                            {#if filteredCategories.length === 0}
                                <div style="padding: 10px; color: var(--text-secondary); text-align: center;">No se encontraron categorías</div>
                            {/if}
                        </div>
                    </div>
                    {/if}
                </div>
            </div>

            {#if eventData.categoria === 'cumpleanos'}
                <div class="form-group">
                    <label for="eventTitulo">
                        <i class="material-icons">person</i>
                        Nombre del Cumpleañero
                    </label>
                    <input type="text" id="eventTitulo" bind:value={eventData.titulo} required maxlength="255">
                </div>
                <div class="form-row">
                    <div class="form-group">
                        <label for="eventFecha">
                            <i class="material-icons">calendar_today</i>
                            Fecha
                        </label>
                        <input type="date" id="eventFecha" value={selectedDay ? selectedDay.dateStr : ''} disabled required>
                    </div>
                    <div class="form-group">
                        <label for="eventAnio">
                            <i class="material-icons">cake</i>
                            Año Nacimiento
                        </label>
                        <input type="number" id="eventAnio" bind:value={eventData.anio_nacimiento} placeholder="Opcional">
                    </div>
                </div>
                <div class="form-group">
                    <label for="eventMensaje">
                        <i class="material-icons">message</i>
                        Mensaje (Opcional)
                    </label>
                    <input type="text" id="eventMensaje" bind:value={eventData.mensaje} placeholder="Felicidades..." maxlength="1000">
                </div>
                <div class="form-group">
                    <label for="eventTelefono">
                        <i class="material-icons">phone</i>
                        Teléfono (Opcional)
                    </label>
                    <input type="text" id="eventTelefono" bind:value={eventData.telefono} placeholder="Número de contacto" maxlength="50">
                </div>
            {:else}
                <div class="form-group">
                    <label for="eventTitulo">
                        <i class="material-icons">title</i>
                        Título
                    </label>
                    <input type="text" id="eventTitulo" bind:value={eventData.titulo} required maxlength="255">
                </div>

                <div class="form-row">
                    <div class="form-group">
                        <label for="eventFecha">
                            <i class="material-icons">calendar_today</i>
                            Fecha
                        </label>
                        <input type="date" id="eventFecha" value={selectedDay ? selectedDay.dateStr : ''} disabled required>
                    </div>
                    <div class="form-group">
                        <label for="eventHora">
                            <i class="material-icons">access_time</i>
                            Hora
                        </label>
                        <input type="time" id="eventHora" bind:value={eventData.hora} required>
                    </div>
                </div>

                <div class="form-group">
                    <label for="eventUbicacion">
                        <i class="material-icons">place</i>
                        Ubicación
                    </label>
                    <input type="text" id="eventUbicacion" bind:value={eventData.ubicacion} maxlength="255">
                </div>
            {/if}

            {#if eventData.categoria !== 'cumpleanos'}
                <div class="form-group">
                    <label for="eventFrecuencia">
                        <i class="material-icons">repeat</i>
                        Frecuencia / Repetición
                    </label>
                    <select id="eventFrecuencia" bind:value={eventData.frecuencia} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        <option value="unica">Única</option>
                        <option value="diaria">Diaria</option>
                        <option value="quincenal">Quincenal</option>
                        <option value="mensual">Mensual</option>
                        <option value="trimestral">Trimestral</option>
                        <option value="semestral">Semestral</option>
                        <option value="anual">Anual</option>
                    </select>
                </div>

                <div class="form-group">
                    <label for="eventTipoTransaccion">
                        <i class="material-icons">monetization_on</i>
                        Transacción Financiera
                    </label>
                    <select id="eventTipoTransaccion" bind:value={eventData.tipo_transaccion} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        <option value="ninguno">Ninguna (Evento General)</option>
                        <option value="gasto">Gasto / Factura / Cita Médica 📉</option>
                        <option value="ingreso">Ingreso / Cobro / Pago Recibido 📈</option>
                    </select>
                </div>
            {/if}

            {#if eventData.tipo_transaccion !== 'ninguno'}
                <div class="form-row">
                    <div class="form-group">
                        <label for="eventCosto">
                            <i class="material-icons">payments</i>
                            Valor ($)
                        </label>
                        <CurrencyInput id="eventCosto" bind:value={eventData.costo} placeholder="0" required={true} />
                    </div>
                    <div class="form-group">
                        <label for="eventEstadoPago">
                            <i class="material-icons">hourglass_empty</i>
                            Estado
                        </label>
                        <select id="eventEstadoPago" bind:value={eventData.estado_pago} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                            <option value="pendiente">Pendiente</option>
                            <option value="pagado">Pagado / Confirmado</option>
                        </select>
                    </div>
                </div>
            {/if}

            <div class="modal-actions" style="margin-top: 15px;">
                <button type="button" class="btn btn-secondary" on:click={() => showEventModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary">
                    <i class="material-icons">save</i> Guardar
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showPeriodModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>Ciclo Menstrual</h3>
            <button class="modal-close" on:click={() => showPeriodModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <div class="modal-body">
            <p>¿Comenzó tu periodo el <strong>{selectedDay ? selectedDay.dateStr : ''}</strong>?</p>
            <div class="form-group" style="margin-top: 15px;">
                <label for="periodObservacion">
                    <i class="material-icons">edit_note</i>
                    Observaciones (Opcional)
                </label>
                <textarea id="periodObservacion" bind:value={periodData.observacion} rows="3" placeholder="Añade notas, síntomas o detalles..." style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;"></textarea>
            </div>
            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showPeriodModal = false}>Cancelar</button>
                <button type="button" class="btn btn-primary" on:click={savePeriod}>Confirmar</button>
            </div>
        </div>
    </div>
</div>
{/if}



{#if showNoteModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>{noteData.id ? 'Editar Nota' : 'Nueva Nota'}</h3>
            <button class="modal-close" on:click={() => showNoteModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveNote}>
            <div class="form-group">
                <label for="noteContenido">
                    <i class="material-icons">edit_note</i>
                    Contenido
                </label>
                <textarea id="noteContenido" bind:value={noteData.contenido} required rows="5" placeholder="Escribe tu nota aquí..."></textarea>
            </div>

            <div class="form-group">
                <label for="noteEtiqueta">
                    <i class="material-icons">sell</i>
                    Etiqueta
                </label>
                <select id="noteEtiqueta" bind:value={noteData.etiqueta} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    <option value="personal">Personal / General</option>
                    <option value="trabajo">Trabajo / Oficina</option>
                    <option value="salud">Salud / Bienestar</option>
                    <option value="ideas">Ideas / Inspiración</option>
                </select>
            </div>

            <div class="form-group">
                <label>
                    <i class="material-icons">palette</i>
                    Color de la Nota
                </label>
                <div style="display: flex; gap: 10px; margin-top: 8px;">
                    {#each ['#4FC3F7', '#FFB74D', '#81C784', '#BA68C8', '#F06292'] as color}
                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                        <div on:click={() => noteData.color = color} style="width: 30px; height: 30px; border-radius: 50%; background-color: {color}; cursor: pointer; border: 2px solid {noteData.color === color ? '#fff' : 'transparent'}; box-shadow: {noteData.color === color ? '0 0 8px ' + color : 'none'}; transform: {noteData.color === color ? 'scale(1.15)' : 'none'}; transition: all 0.2s ease;"></div>
                    {/each}
                </div>
            </div>

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showNoteModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #4FC3F7; color: #000;">
                    <i class="material-icons">save</i> Guardar
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showHabitModal}
<div class="modal active">
    <div class="modal-content">
        <div class="modal-header">
            <h3>{habitData.id ? 'Editar Hábito' : 'Nuevo Hábito'}</h3>
            <button class="modal-close" on:click={() => showHabitModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveHabit}>
            <div class="form-group">
                <label for="habitNombre">
                    <i class="material-icons">title</i>
                    Nombre del Hábito
                </label>
                <input type="text" id="habitNombre" bind:value={habitData.nombre} required maxlength="100" placeholder="Ej. Tomar 2L de agua, Meditar, Ejercicio...">
            </div>

            <div class="form-group">
                <label>
                    <i class="material-icons">palette</i>
                    Color del Hábito
                </label>
                <div style="display: flex; gap: 10px; margin-top: 8px;">
                    {#each ['#4CAF50', '#2196F3', '#9C27B0', '#FF9800', '#E91E63', '#00BCD4'] as color}
                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                        <div on:click={() => habitData.color = color} style="width: 30px; height: 30px; border-radius: 50%; background-color: {color}; cursor: pointer; border: 2px solid {habitData.color === color ? '#fff' : 'transparent'}; box-shadow: {habitData.color === color ? '0 0 8px ' + color : 'none'}; transform: {habitData.color === color ? 'scale(1.15)' : 'none'}; transition: all 0.2s ease;"></div>
                    {/each}
                </div>
            </div>

            <div class="form-group">
                <label>
                    <i class="material-icons">category</i>
                    Icono Representativo
                </label>
                <div style="display: grid; grid-template-columns: repeat(5, 1fr); gap: 10px; margin-top: 8px;">
                    {#each ['check_circle', 'water_drop', 'self_improvement', 'directions_run', 'book', 'local_hospital', 'schedule', 'favorite', 'restaurant', 'bedtime'] as icon}
                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                        <div on:click={() => habitData.icono = icon} style="display: flex; align-items: center; justify-content: center; height: 40px; border-radius: 8px; border: 2px solid {habitData.icono === icon ? (habitData.color || '#4CAF50') : 'var(--border-color)'}; background: {habitData.icono === icon ? 'rgba(255,255,255,0.05)' : 'var(--bg-tertiary)'}; cursor: pointer; transition: all 0.2s ease; color: {habitData.icono === icon ? (habitData.color || '#4CAF50') : 'var(--text-secondary)'};" title={icon}>
                            <i class="material-icons">{icon}</i>
                        </div>
                    {/each}
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="habitFrecuencia">
                        <i class="material-icons">loop</i>
                        Frecuencia
                    </label>
                    <select id="habitFrecuencia" bind:value={habitData.frecuencia} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        <option value="diario">Diario</option>
                        <option value="semanal">Semanal</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="habitMeta">
                        <i class="material-icons">track_changes</i>
                        Meta Diaria
                    </label>
                    <input type="number" id="habitMeta" bind:value={habitData.meta_diaria} min="1" required style="margin-top: 5px;">
                </div>
            </div>

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showHabitModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #4CAF50; color: #fff;">
                    <i class="material-icons">save</i> Guardar
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showAccountModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>{accountData.id ? 'Editar Cuenta' : 'Nueva Tarjeta o Cuenta'}</h3>
            <button class="modal-close" on:click={() => showAccountModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveAccount}>
            <div class="form-group">
                <label for="accNombre">Nombre de Cuenta / Tarjeta</label>
                <input type="text" id="accNombre" bind:value={accountData.nombre} required placeholder="Ej: Visa Crédito, Ahorros Principal" maxlength="255">
            </div>

            <div class="form-group">
                <label for="accTipo">Tipo de Cuenta</label>
                <select id="accTipo" bind:value={accountData.tipo} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    <option value="ahorros">Cuenta de Ahorros 💰</option>
                    <option value="corriente">Cuenta Corriente 🏦</option>
                    <option value="tarjeta_credito">Tarjeta de Crédito 💳</option>
                    <option value="cdt">Inversión / CDT / Cajita Rendimiento 📈</option>
                    <option value="efectivo">Efectivo 💵</option>
                    <option value="otro">Otro / Ahorros Especiales 💼</option>
                </select>
            </div>

            <div class="form-group">
                <label for="accSaldo">{accountData.tipo === 'tarjeta_credito' ? 'Deuda Actual ($)' : 'Saldo Inicial ($)'}</label>
                <CurrencyInput id="accSaldo" bind:value={accountData.saldo} required={true} />
            </div>

            {#if accountData.tipo === 'tarjeta_credito'}
                <div class="form-group">
                    <label for="accLimite">Límite de Crédito / Cupo ($)</label>
                    <CurrencyInput id="accLimite" bind:value={accountData.limite} />
                </div>

                <div class="form-group" style="margin-top: 12px;">
                    <label for="accDiaCorte" style="display: flex; align-items: center; gap: 6px;">
                        <i class="material-icons" style="font-size: 16px; color: #FFD700;">calendar_today</i>
                        Día de Corte (Opcional)
                    </label>
                    <input
                        type="number"
                        id="accDiaCorte"
                        bind:value={accountData.dia_corte}
                        min="1" max="31"
                        placeholder="Ej: 20  →  corte cada día 20 del mes"
                        style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;"
                    >
                    <p style="font-size: 0.75rem; color: var(--text-secondary); margin-top: 6px; line-height: 1.45;">
                        💡 <strong style="color: var(--text-primary);">¿Qué es el día de corte?</strong> Es el día del mes en que el banco cierra el período de facturación y genera tu extracto. Si compras <em>antes</em> de ese día, el cobro aparece en el extracto de este mes; si compras <em>después</em>, se va al extracto del mes siguiente.<br>
                        Con este dato, cada compra en esta tarjeta generará un recordatorio automático en el calendario en la fecha exacta en que ese cobro aparecerá en tu extracto.
                    </p>
                </div>
            {/if}

            {#if accountData.tipo === 'cdt'}
                <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-top: 12px;">
                    <div class="form-group">
                        <label for="accInteresTasa">Tasa de Interés (% E.A.)</label>
                        <input type="number" id="accInteresTasa" bind:value={accountData.interes_tasa} step="0.01" min="0" max="100" placeholder="Ej: 12.5" style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;" required>
                    </div>
                    <div class="form-group">
                        <label for="accPlazoDias">Plazo en Días (Opcional)</label>
                        <input type="number" id="accPlazoDias" bind:value={accountData.plazo_dias} min="0" placeholder="0 = Sin vencimiento" style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    </div>
                </div>
                <div class="form-group" style="margin-top: 12px;">
                    <label for="accFechaInicio">Fecha de Constitución / Inicio</label>
                    <input type="date" id="accFechaInicio" bind:value={accountData.fecha_inicio} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;" required>
                </div>
            {/if}

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showAccountModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #FFD700; color: #000;">
                    <i class="material-icons">save</i> Guardar
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showPlannedIncomeModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>Planificar Ingreso Recurrente</h3>
            <button class="modal-close" on:click={() => showPlannedIncomeModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={savePlannedIncome}>
            <div class="form-group">
                <label for="planDesc">Descripción del Ingreso</label>
                <input type="text" id="planDesc" bind:value={plannedIncomeData.descripcion} required placeholder="Ej: Nómina, Arriendo, Ventas" maxlength="255">
            </div>

            <div class="form-group">
                <label for="planMonto">Monto de Ingreso Esperado ($)</label>
                <CurrencyInput id="planMonto" bind:value={plannedIncomeData.monto} required={true} />
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="planFrec">Frecuencia</label>
                    <select id="planFrec" bind:value={plannedIncomeData.frecuencia} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        <option value="diario">Diario</option>
                        <option value="semanal">Semanal</option>
                        <option value="quincenal">Quincenal (Cada 15 días)</option>
                        <option value="mensual">Mensual</option>
                        <option value="unica">Única vez</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="planInicio">Fecha Inicio</label>
                    <input type="date" id="planInicio" bind:value={plannedIncomeData.fecha_inicio} required style="margin-top: 5px;">
                </div>
            </div>

            <div class="form-group">
                <label for="planCuenta">Cuenta de Llegada (Predeterminada)</label>
                <select id="planCuenta" bind:value={plannedIncomeData.cuenta_id} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    <option value="">Ninguna (Solo registrar evento)</option>
                    {#each cuentasList as c}
                        <option value={c.id}>{c.nombre} ({formatPrice(c.saldo)})</option>
                    {/each}
                </select>
            </div>

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showPlannedIncomeModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #FFD700; color: #000;">
                    <i class="material-icons">save</i> Planificar
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showTransactionModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>{transactionData.id ? 'Editar Transacción' : 'Registrar Gasto / Ingreso'}</h3>
            <button class="modal-close" on:click={() => showTransactionModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveTransaction}>
            <div class="form-group">
                <label for="txTipo">Tipo de Transacción</label>
                <select id="txTipo" bind:value={transactionData.tipo} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    <option value="gasto">Gasto / Egreso 📉</option>
                    <option value="ingreso">Ingreso / Cobro 📈</option>
                </select>
            </div>

            <div class="form-group">
                <label for="txDesc">Detalle / Concepto</label>
                <input type="text" id="txDesc" bind:value={transactionData.descripcion} required placeholder="Ej: Compra supermercado, Pago nómina..." maxlength="255">
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="txMonto">Monto ($)</label>
                    <CurrencyInput id="txMonto" bind:value={transactionData.monto} required={true} />
                </div>
                <div class="form-group">
                    <label for="txFecha">Fecha</label>
                    <input type="date" id="txFecha" bind:value={transactionData.fecha} required style="margin-top: 5px;">
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="txCuenta">Cuenta Afectada</label>
                    <select id="txCuenta" bind:value={transactionData.cuenta_id} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        <option value="">Ninguna</option>
                        {#each cuentasList as c}
                            <option value={c.id}>{c.nombre} ({formatPrice(c.saldo)})</option>
                        {/each}
                    </select>
                </div>
                <div class="form-group">
                    <label for="txCat">Categoría</label>
                    <select id="txCat" bind:value={transactionData.categoria} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        {#each TRANSACTIONS_CATEGORIES as cat}
                            <option value={cat.value}>{cat.label}</option>
                        {/each}
                    </select>
                </div>
            </div>

            {#if transactionData.tipo === 'gasto' && cuentasList.find(c => c.id == transactionData.cuenta_id)?.tipo === 'tarjeta_credito'}
                <div class="form-group" style="margin-top: 10px;">
                    <label for="txCuotas">Diferir a cuotas (meses)</label>
                    <select id="txCuotas" bind:value={transactionData.cuotas} style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                        {#each Array(36) as _, i}
                            <option value={i + 1}>{i + 1} {i === 0 ? 'cuota' : 'cuotas'}</option>
                        {/each}
                    </select>
                </div>
            {/if}

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showTransactionModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #FFD700; color: #000;">
                    <i class="material-icons">save</i> {transactionData.id ? 'Guardar Cambios' : 'Registrar'}
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

{#if showVerifyIncomeModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header">
            <h3>Verificar Llegada de Dinero</h3>
            <button class="modal-close" on:click={() => showVerifyIncomeModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={verifyPlannedIncome}>
            <p style="font-size: 0.88rem; color: var(--text-secondary); margin-bottom: 15px;">
                Confirmas que recibiste el ingreso: <strong>{verifyIncomeData.descripcion}</strong>
            </p>

            <div class="form-group">
                <label for="verMonto">Valor Real Recibido ($)</label>
                <CurrencyInput id="verMonto" bind:value={verifyIncomeData.monto_real} required={true} />
            </div>

            <div class="form-group">
                <label for="verFecha">Fecha Real de Recepción</label>
                <input type="date" id="verFecha" bind:value={verifyIncomeData.fecha_real} required style="margin-top: 5px;">
            </div>

            <div class="form-group">
                <label for="verCuenta">Depositar en la Cuenta</label>
                <select id="verCuenta" bind:value={verifyIncomeData.cuenta_id} required style="width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border-color); background: var(--bg-tertiary); color: var(--text-primary); margin-top: 5px;">
                    <option value="" disabled>Selecciona una cuenta...</option>
                    {#each cuentasList as c}
                        <option value={c.id}>{c.nombre} ({formatPrice(c.saldo)})</option>
                    {/each}
                </select>
            </div>

            <div class="modal-actions" style="margin-top: 20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showVerifyIncomeModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background-color: #FFD700; color: #000;">
                    <i class="material-icons">done</i> Confirmar Recepción
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

<!-- MODAL: Meta de Ahorro -->
{#if showMetaModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header" style="background: linear-gradient(135deg, rgba(52,228,126,0.15), rgba(0,0,0,0)); border-bottom: 1px solid rgba(52,228,126,0.2);">
            <h3 style="display:flex; align-items:center; gap:8px;">
                <i class="material-icons" style="color: {metaData.color};">{metaData.icono || 'savings'}</i>
                {metaData.id ? 'Editar Meta' : 'Nueva Meta de Ahorro'}
            </h3>
            <button class="modal-close" on:click={() => showMetaModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={saveMeta}>
            <div class="form-group">
                <label for="metaNombre"><i class="material-icons">flag</i> Nombre de la Meta</label>
                <input type="text" id="metaNombre" bind:value={metaData.nombre} required placeholder="Ej: Viaje a Europa, Fondo de emergencia..." maxlength="255">
            </div>

            <div class="form-group">
                <label for="metaDesc"><i class="material-icons">edit_note</i> Descripción (Opcional)</label>
                <textarea id="metaDesc" bind:value={metaData.descripcion} rows="2" placeholder="¿Para qué es esta meta?" style="width:100%; padding:10px; border-radius:8px; border:1px solid var(--border-color); background:var(--bg-tertiary); color:var(--text-primary); margin-top:5px; resize:vertical;"></textarea>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="metaObjetivo"><i class="material-icons">payments</i> Monto Objetivo ($)</label>
                    <CurrencyInput id="metaObjetivo" bind:value={metaData.monto_objetivo} required={true} />
                </div>
                <div class="form-group">
                    <label for="metaActual"><i class="material-icons">savings</i> Monto Actual ($)</label>
                    <CurrencyInput id="metaActual" bind:value={metaData.monto_actual} />
                </div>
            </div>

            <div class="form-row">
                <div class="form-group">
                    <label for="metaFecha"><i class="material-icons">event</i> Fecha Objetivo</label>
                    <input type="date" id="metaFecha" bind:value={metaData.fecha_objetivo} style="margin-top:5px;">
                </div>
                <div class="form-group">
                    <label><i class="material-icons">palette</i> Color</label>
                    <div style="display:flex; gap:8px; flex-wrap:wrap; margin-top:8px;">
                        {#each ['#34E47E','#29B6F6','#FFA726','#AB47BC','#FF5252','#FFD700','#26C6DA','#FF80AB'] as c}
                            <!-- svelte-ignore a11y_click_events_have_key_events -->
                            <!-- svelte-ignore a11y_no_static_element_interactions -->
                            <div on:click={() => metaData.color = c} style="width:24px; height:24px; border-radius:50%; background:{c}; cursor:pointer; border:3px solid {metaData.color === c ? '#fff' : 'transparent'}; transition:transform 0.15s; box-shadow:0 0 6px {c}55;" title="{c}"></div>
                        {/each}
                    </div>
                </div>
            </div>

            <div class="form-group">
                <label><i class="material-icons">emoji_objects</i> Ícono</label>
                <div style="display:flex; gap:8px; flex-wrap:wrap; margin-top:8px;">
                    {#each ['savings','flight','home','directions_car','school','medical_services','devices','shopping_cart','beach_access','sports_esports','pets','favorite'] as ico}
                        <!-- svelte-ignore a11y_click_events_have_key_events -->
                        <!-- svelte-ignore a11y_no_static_element_interactions -->
                        <div on:click={() => metaData.icono = ico} class="icon-selector {metaData.icono === ico ? 'selected' : ''}" title="{ico}">
                            <i class="material-icons" style="font-size:20px; color: {metaData.icono === ico ? metaData.color : 'var(--text-secondary)'};">{ico}</i>
                        </div>
                    {/each}
                </div>
            </div>

            <!-- Vista previa de la barra de progreso -->
            {#if metaData.monto_objetivo > 0}
                {@const prevPct = Math.min(100, Math.round((metaData.monto_actual / metaData.monto_objetivo) * 100))}
                <div style="background:rgba(0,0,0,0.2); border-radius:10px; padding:10px 12px; margin-top:4px;">
                    <div style="font-size:0.78rem; color:var(--text-secondary); margin-bottom:6px;">Vista previa — {prevPct}% alcanzado</div>
                    <div style="height:8px; background:rgba(255,255,255,0.08); border-radius:4px; overflow:hidden;">
                        <div style="height:100%; width:{prevPct}%; background:linear-gradient(90deg,{metaData.color}99,{metaData.color}); border-radius:4px; transition:width 0.4s ease;"></div>
                    </div>
                </div>
            {/if}

            {#if metaData.id}
                <label style="display:flex; align-items:center; gap:8px; margin-top:12px; cursor:pointer; font-size:0.9rem;">
                    <input type="checkbox" bind:checked={metaData.completada} style="accent-color:{metaData.color};">
                    Marcar como completada
                </label>
            {/if}

            <div class="modal-actions" style="margin-top:20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showMetaModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background: linear-gradient(135deg, {metaData.color}, {metaData.color}cc); color:#000;">
                    <i class="material-icons">save</i> Guardar Meta
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

<!-- MODAL: Presupuesto Mensual -->
{#if showPresupuestoModal}
<div class="modal active">
    <div class="modal-content modal-small">
        <div class="modal-header" style="background: linear-gradient(135deg, rgba(255,167,38,0.12), rgba(0,0,0,0)); border-bottom: 1px solid rgba(255,167,38,0.2);">
            <h3 style="display:flex; align-items:center; gap:8px;">
                <i class="material-icons" style="color:#FFA726;">pie_chart</i>
                {presupuestoData.id ? 'Modificar Límite de Presupuesto' : 'Definir Límite de Presupuesto'}
            </h3>
            <button class="modal-close" on:click={() => showPresupuestoModal = false}>
                <i class="material-icons">close</i>
            </button>
        </div>
        <form class="modal-body" on:submit|preventDefault={savePresupuesto}>
            <div class="form-group">
                <label for="presCat"><i class="material-icons">category</i> Categoría</label>
                <select id="presCat" bind:value={presupuestoData.categoria} style="width:100%; padding:10px; border-radius:8px; border:1px solid var(--border-color); background:var(--bg-tertiary); color:var(--text-primary); margin-top:5px;">
                    {#each TRANSACTIONS_CATEGORIES as cat}
                        <option value={cat.value}>{cat.label}</option>
                    {/each}
                </select>
            </div>
            <div class="form-group">
                <label for="presLimite"><i class="material-icons">money</i> Límite Mensual ($)</label>
                <CurrencyInput id="presLimite" bind:value={presupuestoData.monto_limite} required={true} placeholder="Ej: 500000" />
            </div>
            <p style="font-size:0.78rem; color:var(--text-secondary); background:rgba(255,167,38,0.08); border:1px solid rgba(255,167,38,0.15); border-radius:8px; padding:8px 12px; display:flex; align-items:flex-start; gap:8px;">
                <i class="material-icons" style="font-size:16px; color:#FFA726; flex-shrink:0; margin-top:1px;">lightbulb</i>
                El sistema mostrará en tiempo real cuánto has gastado vs tu límite definido para el mes actual.
            </p>
            <div class="modal-actions" style="margin-top:20px;">
                <button type="button" class="btn btn-secondary" on:click={() => showPresupuestoModal = false}>Cancelar</button>
                <button type="submit" class="btn btn-primary" style="background: linear-gradient(135deg, #FFA726, #FF8F00); color:#000;">
                    <i class="material-icons">save</i> Guardar Límite
                </button>
            </div>
        </form>
    </div>
</div>
{/if}

<style>
  .whatsapp-simulator {
    margin-top: 10px;
    background: rgba(11, 20, 26, 0.4);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 12px;
    font-size: 0.85rem;
    box-shadow: var(--shadow-sm);
  }
  
  .simulator-header {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #25D366;
    font-weight: 500;
    margin-bottom: 8px;
  }
  
  .simulator-header i {
    font-size: 18px;
  }
  
  .simulator-body textarea {
    width: 100%;
    background: var(--bg-primary);
    border: 1px solid var(--divider-color);
    border-radius: 6px;
    color: var(--text-primary);
    padding: 8px;
    font-size: 0.8rem;
    resize: none;
    height: 85px;
    font-family: inherit;
    outline: none;
    line-height: 1.4;
  }
  
  .simulator-body textarea:focus {
    border-color: var(--wa-green-light);
  }
  
  .simulator-actions {
    display: flex;
    justify-content: flex-end;
    gap: 8px;
    margin-top: 8px;
  }
  
  :global(.btn-sm) {
    padding: 4px 10px !important;
    font-size: 0.75rem !important;
    border-radius: 6px !important;
  }
  
  :global(.btn-wa) {
    background-color: #25D366 !important;
    color: #ffffff !important;
    text-decoration: none;
  }
  
  :global(.btn-wa:hover) {
    background-color: #1DA855 !important;
  }
  
  .finance-badge {
    padding: 3px 8px;
    border-radius: 6px;
    font-size: 0.75rem;
    font-weight: bold;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  
  .finance-badge.gasto {
    background: rgba(244, 67, 54, 0.15);
    color: #FF5252;
  }
  
  .finance-badge.ingreso {
    background: rgba(52, 228, 126, 0.15);
    color: #34E47E;
  }
  
  .payment-status-badge {
    padding: 3px 10px;
    border-radius: 12px;
    font-size: 0.75rem;
    font-weight: 500;
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    gap: 4px;
    user-select: none;
    border: 1px solid transparent;
    transition: all 0.2s ease;
  }
  
  .payment-status-badge.pagado {
    background: rgba(37, 211, 102, 0.15);
    color: #34E47E;
    border-color: rgba(37, 211, 102, 0.3);
  }
  
  .payment-status-badge.pagado:hover {
    background: rgba(37, 211, 102, 0.25);
  }
  
  .payment-status-badge.pendiente {
    background: rgba(255, 167, 38, 0.15);
    color: #FFA726;
    border-color: rgba(255, 167, 38, 0.3);
  }
  
  .payment-status-badge.pendiente:hover {
    background: rgba(255, 167, 38, 0.25);
  }
  
  .finance-summary-card {
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 12px;
    padding: 16px;
    margin-bottom: 20px;
    box-shadow: var(--shadow-sm);
  }
  
  .finance-summary-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 1rem;
    color: var(--text-primary);
    font-weight: 500;
    margin-bottom: 12px;
    border-bottom: 1px solid var(--divider-color);
    padding-bottom: 8px;
  }
  
  .finance-summary-title i {
    color: var(--wa-green-light);
  }
  
  .finance-stat-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    font-size: 0.9rem;
    margin-bottom: 8px;
  }
  
  .finance-stat-row:last-child {
    margin-bottom: 0;
  }
  
  .finance-stat-label {
    color: var(--text-secondary);
  }
  
  .finance-stat-value {
    font-weight: bold;
  }
  
  .finance-stat-value.green {
    color: #34E47E;
  }
  
  .finance-stat-value.red {
    color: #FF5252;
  }
  
  .finance-stat-value.orange {
    color: #FFA726;
  }

  /* ============================================
     EVENT PAY HINT (Subtle finance info in events mode)
     ============================================ */
  .event-pay-hint {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    background: rgba(255, 255, 255, 0.03);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 6px 10px;
    margin-top: 2px;
    transition: all 0.2s ease;
  }

  .event-pay-hint:hover {
    background: rgba(255, 255, 255, 0.06);
  }

  .event-pay-hint-left {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.78rem;
    color: var(--text-secondary);
    font-weight: 500;
  }

  .event-pay-hint-left i {
    font-size: 15px;
    opacity: 0.7;
  }

  .event-pay-hint-right {
    display: flex;
    align-items: center;
    gap: 6px;
  }

  .btn-confirm-link {
    width: 28px;
    height: 28px;
    border: none;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-secondary);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    transition: all 0.2s ease;
    padding: 0;
  }

  .btn-confirm-link:hover {
    background: rgba(var(--wa-green), 0.15);
    color: var(--wa-green-light);
    transform: scale(1.1);
  }

  .btn-confirm-link i {
    font-size: 16px;
  }

  /* ============================================
     UPCOMING MINI CARDS (Events mode, no day selected)
     ============================================ */
  .upcoming-mini-card {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 12px;
    background: var(--bg-tertiary);
    border: 1px solid var(--border-color);
    border-radius: 10px;
    transition: all 0.2s ease;
    cursor: default;
  }

  .upcoming-mini-card:hover {
    background: var(--bg-hover);
    transform: translateX(3px);
    box-shadow: var(--shadow-sm);
  }

  .upcoming-mini-left {
    display: flex;
    align-items: center;
    gap: 12px;
    flex: 1;
    min-width: 0;
  }

  .upcoming-mini-date {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    min-width: 40px;
    padding: 4px 6px;
    background: rgba(37, 211, 102, 0.08);
    border-radius: 8px;
    border: 1px solid rgba(37, 211, 102, 0.15);
  }

  .upcoming-mini-day {
    font-size: 1.1rem;
    font-weight: 700;
    color: var(--wa-green-light);
    line-height: 1;
  }

  .upcoming-mini-month {
    font-size: 0.6rem;
    text-transform: uppercase;
    color: var(--text-secondary);
    font-weight: 600;
    letter-spacing: 0.5px;
  }

  .upcoming-mini-info {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }

  .upcoming-mini-title {
    font-size: 0.85rem;
    font-weight: 500;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .upcoming-mini-time {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 0.72rem;
    color: var(--text-secondary);
  }

  .upcoming-mini-badge {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.7rem;
    font-weight: 700;
    flex-shrink: 0;
  }

  .upcoming-mini-badge.paid {
    background: rgba(52, 228, 126, 0.15);
    color: #34E47E;
    border: 1px solid rgba(52, 228, 126, 0.3);
  }

  .upcoming-mini-badge.pending {
    background: rgba(255, 167, 38, 0.15);
    color: #FFA726;
    border: 1px solid rgba(255, 167, 38, 0.3);
    animation: pulse 2s ease-in-out infinite;
  }

  /* ============================================
     FINANCE SUB-TABS (nueva barra de pestañas)
     ============================================ */
  .finance-subtabs {
    display: flex;
    gap: 4px;
    margin-top: 15px;
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 0;
    overflow-x: auto;
    scrollbar-width: none;
  }
  .finance-subtabs::-webkit-scrollbar { display: none; }

  .fin-tab {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 7px 12px;
    font-size: 0.78rem;
    font-weight: 500;
    color: var(--text-secondary);
    background: transparent;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: all 0.2s ease;
    white-space: nowrap;
    border-radius: 0;
  }
  .fin-tab i { font-size: 15px; }
  .fin-tab:hover {
    color: #FFD700;
    background: rgba(255,215,0,0.05);
  }
  .fin-tab.active {
    color: #FFD700;
    border-bottom-color: #FFD700;
    background: rgba(255,215,0,0.07);
  }

  /* ============================================
     FIN-ADD-BTN (botón de agregar unificado)
     ============================================ */
  .fin-add-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    width: 100%;
    padding: 10px;
    margin-bottom: 14px;
    background: rgba(255,215,0,0.05);
    border: 1px dashed rgba(255,215,0,0.35);
    border-radius: 10px;
    color: #FFD700;
    font-size: 0.85rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.25s ease;
  }
  .fin-add-btn:hover {
    background: rgba(255,215,0,0.1);
    border-style: solid;
    transform: translateY(-1px);
    box-shadow: 0 4px 15px rgba(255,215,0,0.1);
  }
  .fin-add-btn i { font-size: 18px; }

  /* ============================================
     METAS DE AHORRO - Cards con animaciones
     ============================================ */
  .metas-grid {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }

  .meta-card {
    background: linear-gradient(135deg, rgba(255,255,255,0.03), rgba(255,255,255,0.01));
    border: 1px solid rgba(255,255,255,0.07);
    border-radius: 14px;
    padding: 14px;
    position: relative;
    overflow: hidden;
    transition: all 0.3s ease;
    animation: slideInUp 0.4s ease both;
    border-left: 4px solid var(--meta-color, #34E47E);
  }
  .meta-card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0; height: 1px;
    background: linear-gradient(90deg, transparent, var(--meta-color, #34E47E), transparent);
    opacity: 0.5;
  }
  .meta-card:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.3), 0 0 0 1px rgba(255,255,255,0.06);
  }
  .meta-card.completed {
    opacity: 0.7;
    filter: saturate(0.6);
  }
  .meta-card.completed::after {
    content: '';
    position: absolute;
    inset: 0;
    background: repeating-linear-gradient(
      45deg,
      transparent,
      transparent 10px,
      rgba(255,255,255,0.01) 10px,
      rgba(255,255,255,0.01) 20px
    );
  }

  .meta-card-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
  }
  .meta-icon-wrap {
    width: 38px;
    height: 38px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .meta-icon-wrap i { font-size: 20px; }

  .meta-title-block {
    display: flex;
    flex-direction: column;
    gap: 3px;
    flex: 1;
    min-width: 0;
  }
  .meta-nombre {
    font-weight: 600;
    font-size: 0.9rem;
    color: var(--text-primary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .meta-badge {
    font-size: 0.68rem;
    padding: 2px 7px;
    border-radius: 20px;
    font-weight: 600;
    letter-spacing: 0.3px;
    width: fit-content;
  }
  .completed-badge { background: rgba(52,228,126,0.15); color: #34E47E; }
  .overdue-badge { background: rgba(244,67,54,0.15); color: #F44336; }
  .soon-badge { background: rgba(255,167,38,0.15); color: #FFA726; }
  .normal-badge { background: rgba(41,182,246,0.15); color: #29B6F6; }

  .meta-actions {
    display: flex;
    gap: 2px;
    margin-left: auto;
    flex-shrink: 0;
  }

  .meta-desc {
    font-size: 0.8rem;
    color: var(--text-secondary);
    margin: 0 0 10px 0;
    line-height: 1.4;
    font-style: italic;
  }

  .meta-progress-section { display: flex; flex-direction: column; gap: 6px; }
  .meta-amounts {
    display: flex;
    align-items: baseline;
    gap: 5px;
    font-size: 0.85rem;
  }
  .meta-actual { font-weight: 700; font-size: 1rem; }
  .meta-separator { color: var(--text-secondary); }
  .meta-objetivo { color: var(--text-secondary); font-size: 0.82rem; }

  .meta-progress-bar-bg {
    height: 8px;
    background: rgba(255,255,255,0.08);
    border-radius: 4px;
    overflow: hidden;
  }
  .meta-progress-bar-fill {
    height: 100%;
    border-radius: 4px;
    transition: width 0.8s cubic-bezier(0.34, 1.56, 0.64, 1);
    animation: fillProgress 1.2s ease both;
    position: relative;
    overflow: hidden;
  }
  .meta-progress-bar-fill::after {
    content: '';
    position: absolute;
    top: 0; left: -100%; width: 100%; height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.35), transparent);
    animation: shimmer 2.5s ease-in-out infinite;
  }
  .meta-pct-label {
    font-size: 0.72rem;
    color: var(--text-secondary);
    text-align: right;
  }

  /* ============================================
     PRESUPUESTO MENSUAL - Grid de categorías
     ============================================ */
  .budget-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
  }

  .budget-card {
    background: rgba(255,255,255,0.03);
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 12px;
    padding: 12px;
    transition: all 0.25s ease;
    animation: fadeInScale 0.35s ease both;
  }
  .budget-card:hover {
    background: rgba(255,255,255,0.05);
    transform: translateY(-1px);
  }
  .budget-card.danger { border-color: rgba(244,67,54,0.3); background: rgba(244,67,54,0.04); }
  .budget-card.warning { border-color: rgba(255,167,38,0.3); background: rgba(255,167,38,0.04); }
  .budget-card.ok { border-color: rgba(52,228,126,0.15); }

  .budget-card-top {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 8px;
  }
  .budget-cat-icon {
    width: 30px;
    height: 30px;
    border-radius: 8px;
    background: rgba(255,255,255,0.06);
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
  }
  .budget-cat-icon i { font-size: 17px; color: var(--text-secondary); }
  .budget-cat-label {
    font-size: 0.75rem;
    font-weight: 500;
    color: var(--text-primary);
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .budget-amounts {
    display: flex;
    align-items: baseline;
    gap: 4px;
    margin-bottom: 8px;
  }
  .budget-spent { font-weight: 700; font-size: 0.9rem; }
  .budget-limit { font-size: 0.72rem; color: var(--text-secondary); }
  .budget-set-btn {
    font-size: 0.68rem;
    padding: 2px 7px;
    border-radius: 20px;
    background: rgba(255,215,0,0.1);
    color: #FFD700;
    border: 1px solid rgba(255,215,0,0.2);
    cursor: pointer;
    transition: all 0.2s;
  }
  .budget-set-btn:hover { background: rgba(255,215,0,0.2); }

  .budget-bar-bg {
    height: 6px;
    background: rgba(255,255,255,0.07);
    border-radius: 3px;
    overflow: hidden;
    margin-bottom: 5px;
  }
  .budget-bar-fill {
    height: 100%;
    border-radius: 3px;
    transition: width 0.9s cubic-bezier(0.34, 1.2, 0.64, 1);
    animation: fillProgress 1s ease both;
    position: relative;
    overflow: hidden;
  }
  .budget-bar-fill.ok { background: linear-gradient(90deg, #34E47E88, #34E47E); }
  .budget-bar-fill.warning { background: linear-gradient(90deg, #FFA72688, #FFA726); }
  .budget-bar-fill.danger { 
    background: linear-gradient(90deg, #F4433688, #F44336);
    animation: fillProgress 1s ease both, dangerPulse 1.5s ease-in-out infinite 1s;
  }
  .budget-bar-fill::after {
    content: '';
    position: absolute;
    top: 0; left: -100%; width: 100%; height: 100%;
    background: linear-gradient(90deg, transparent, rgba(255,255,255,0.3), transparent);
    animation: shimmer 2s ease-in-out infinite;
  }
  .budget-pct { font-size: 0.68rem; }

  /* ============================================
     ICON SELECTOR (Metas)
     ============================================ */
  .icon-selector {
    width: 36px;
    height: 36px;
    border-radius: 8px;
    background: rgba(255,255,255,0.04);
    border: 1px solid rgba(255,255,255,0.06);
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.2s ease;
  }
  .icon-selector:hover { background: rgba(255,255,255,0.1); transform: scale(1.1); }
  .icon-selector.selected {
    background: rgba(255,255,255,0.1);
    border-color: rgba(255,255,255,0.25);
    box-shadow: 0 0 0 2px rgba(255,255,255,0.15);
    transform: scale(1.1);
  }

  /* FIN EMPTY STATE */
  .fin-empty-state {
    background: rgba(0,0,0,0.1);
    border: 1px dashed var(--border-color);
    border-radius: 10px;
    padding: 28px;
    text-align: center;
    color: var(--text-secondary);
    font-size: 0.85rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 10px;
  }

  /* ============================================
     KEYFRAME ANIMATIONS
     ============================================ */
  @keyframes slideInUp {
    from { opacity: 0; transform: translateY(16px); }
    to   { opacity: 1; transform: translateY(0); }
  }
  @keyframes fadeInScale {
    from { opacity: 0; transform: scale(0.95); }
    to   { opacity: 1; transform: scale(1); }
  }
  @keyframes fillProgress {
    from { transform: scaleX(0); transform-origin: left; }
    to   { transform: scaleX(1); transform-origin: left; }
  }
  @keyframes shimmer {
    0%   { left: -100%; }
    60%  { left: 100%; }
    100% { left: 100%; }
  }
  @keyframes dangerPulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.65; }
  }


</style>
