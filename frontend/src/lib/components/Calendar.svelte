<script lang="ts">
  import { onMount } from 'svelte';
  import { getCycleDetails, buildCycleStats } from '../cycleUtils';
  import { API_BASE_URL } from '../config';
  import { leer } from '../api';
  import { claveAnio, leerCache, escribirCache } from '../storage';
  import { getTodayLocal, toDateOnly } from '../dateUtils';

  export let isFemaleMode = false;
  export let isFinanceMode = false;
  export let isNotesMode = false;
  export let isHabitsMode = false;
  
  let currentDate = new Date();
  export let currentMonth = currentDate.getMonth();
  export let currentYear = currentDate.getFullYear();
  let daysInMonth: any[] = [];
  let blankDays: any[] = [];

  // Festivos y días importantes dependen del AÑO mostrado, así que el Calendar
  // los sigue cargando él mismo (al montar y al cambiar de año). El resto de los
  // datos llega por props desde el bootstrap del Dashboard (una sola petición).
  export let holidays: any[] = [];
  export let importantDays: any[] = [];
  export let cycleLogs: any[] = [];
  export let notes: any[] = [];
  export let habits: any[] = [];
  export let habitLogs: any[] = [];
  export let events: any[] = [];
  export let cumpleanos: any[] = [];
  export let transacciones: any[] = [];
  export let plannedOccurrences: any[] = [];
  export let selectedDateStr: string | null = null;

  const months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  async function loadHolidays(year: number) {
    // 1) Mostramos al instante desde caché local (los festivos de un año no cambian).
    const cacheKey = claveAnio('CO', 'holidays', year);
    const cached = leerCache<any[]>(cacheKey);
    if (cached) holidays = cached;

    // 2) Refrescamos en segundo plano con timeout, para que la API externa
    //    nunca pueda congelar la carga del calendario.
    try {
      const ctrl = new AbortController();
      const t = setTimeout(() => ctrl.abort(), 5000);
      const res = await fetch(`https://date.nager.at/api/v3/PublicHolidays/${year}/CO`, { signal: ctrl.signal });
      clearTimeout(t);
      if (res.ok) {
        holidays = await res.json();
        escribirCache(cacheKey, holidays);
      }
    } catch (err) {
      // Si falla o expira, conservamos lo que haya en caché.
      console.error('Error fetching holidays', err);
    }
  }

  async function loadImportantDays(year: number) {
    // Se cachean por año, igual que los festivos, para que el calendario esté
    // completo sin conexión. No dependen del usuario (el backend los devuelve
    // iguales para todos) ni cambian dentro de un mismo año.
    const cacheKey = claveAnio('all', 'importantDays', year);
    const cached = leerCache<any[]>(cacheKey);
    if (cached) importantDays = cached;

    const data = await leer<any[]>(`/api/important-days?year=${year}`);
    if (data === null) return; // sin conexión: nos quedamos con lo cacheado
    importantDays = data;
    escribirCache(cacheKey, data);
  }


  function getDaysInMonth(year: number, month: number) {
    return new Date(year, month + 1, 0).getDate();
  }

  function getFirstDayOfMonth(year: number, month: number) {
    return new Date(year, month, 1).getDay(); // 0 = Sunday
  }

  function renderCalendar() {
    const totalDays = getDaysInMonth(currentYear, currentMonth);
    const firstDay = getFirstDayOfMonth(currentYear, currentMonth);

    // El promedio del ciclo se calcula una sola vez por render y se reutiliza en
    // las ~42 celdas, en lugar de recalcularlo (y reordenar el histórico) en cada una.
    const cycleStats = isFemaleMode && cycleLogs.length > 0 ? buildCycleStats(cycleLogs) : null;

    blankDays = Array(firstDay).fill(0);
    daysInMonth = Array.from({ length: totalDays }, (_, i) => {
      const day = i + 1;
      const dateStr = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
      
      const isToday = dateStr === getTodayLocal();
      
      const holiday = holidays.find(h => h.date === dateStr);
      const importantDay = importantDays.find(d => {
        const dStr = toDateOnly(d.date);
        return dStr === dateStr;
      });
      
      const dayEvents = events.filter(e => {
        const eStr = toDateOnly(e.fecha);
        return eStr === dateStr;
      });

      // Cumpleaños del día (coinciden mes y día)
      const dayBirthdays = cumpleanos.filter(c => {
        if (!c.fecha) return false;
        const cStr = toDateOnly(c.fecha);
        return cStr.slice(5) === dateStr.slice(5); // Solo comparar MM-DD
      });

      let cyclePhase = null;
      let cycleDetails = null;
      if (cycleStats) {
         cycleDetails = getCycleDetails(dateStr, cycleStats);
         cyclePhase = cycleDetails ? cycleDetails.phaseKey : null;
      }

      const finEvents = dayEvents.filter(e => e.tipo_transaccion && e.tipo_transaccion !== 'ninguno');
      const dayTxs = transacciones.filter(t => toDateOnly(t.fecha) === dateStr);
      const dayOccs = plannedOccurrences.filter(o => o.fecha_esperada === dateStr);

      const hasFinance = finEvents.length > 0 || dayTxs.length > 0 || dayOccs.length > 0;
      const hasPendingFinance = finEvents.some(e => e.estado_pago === 'pendiente') || dayOccs.some(o => !o.verificado);
      const totalFinanceAmount = finEvents.reduce((sum, e) => sum + Number(e.costo || 0), 0) + 
                                 dayTxs.reduce((sum, t) => sum + Number(t.monto), 0) +
                                 dayOccs.filter(o => !o.verificado).reduce((sum, o) => sum + Number(o.monto), 0);

      // Notas
      const dayNotes = notes.filter(n => {
        const nStr = toDateOnly(n.fecha);
        return nStr === dateStr;
      });
      const hasNote = dayNotes.length > 0;

      // Hábitos
      const totalHabits = habits.length;
      const dayLogs = habitLogs.filter(l => {
        const lStr = toDateOnly(l.fecha);
        return lStr === dateStr && l.completado;
      });
      const completedHabitsCount = dayLogs.length;
      const habitCompletionRate = totalHabits > 0 ? (completedHabitsCount / totalHabits) : 0;
      
      return { 
        day, 
        dateStr, 
        isToday, 
        holiday, 
        importantDay, 
        dayEvents, 
        dayBirthdays,
        cyclePhase,
        cycleDetails,
        finEvents,
        hasFinance,
        hasPendingFinance,
        totalFinanceAmount,
        dayNotes,
        hasNote,
        totalHabits,
        completedHabitsCount,
        habitCompletionRate
      };
    });
  }

  /**
   * Selecciona un día del mes visible desde fuera del calendario (por ejemplo,
   * desde la lista de "Próximos" del Dashboard). Emite el mismo evento que un
   * click en la celda, así el detalle del día se arma igual en los dos casos.
   */
  export function selectDay(dateStr: string) {
    const dayData = daysInMonth.find(d => d.dateStr === dateStr);
    if (dayData) dispatch('click_day', { dateStr, dayData });
  }

  async function changeMonth(delta: number) {
    let newMonth = currentMonth + delta;
    let newYear = currentYear;
    if (newMonth > 11) { newMonth = 0; newYear++; }
    else if (newMonth < 0) { newMonth = 11; newYear--; }
    
    currentMonth = newMonth;
    if (newYear !== currentYear) {
      currentYear = newYear;
      await Promise.all([
        loadHolidays(currentYear),
        loadImportantDays(currentYear)
      ]);
    }
    renderCalendar();
  }

  // Re-render reactivo e incremental: la grilla se redibuja en cuanto cambia
  // el mes/modo o llega CUALQUIER conjunto de datos. Así los cumpleaños y
  // eventos aparecen apenas responde el backend, sin esperar a la API de
  // festivos (externa y lenta) ni a las demás peticiones.
  $: {
    holidays; importantDays; events; cumpleanos; cycleLogs; notes; habits; habitLogs;
    transacciones; plannedOccurrences; currentMonth; currentYear;
    isFemaleMode; isFinanceMode; isNotesMode; isHabitsMode; selectedDateStr;
    renderCalendar();
  }

  // Recarga sólo lo que depende del año mostrado (festivos + días importantes).
  // El resto de los datos los refresca el Dashboard vía bootstrap y llegan por props.
  export async function refreshData() {
    await Promise.all([
      loadHolidays(currentYear),
      loadImportantDays(currentYear)
    ]);
  }

  onMount(() => {
    // Sólo festivos (cacheados) y días importantes del año actual. Los demás
    // datos llegan por props desde el bootstrap del Dashboard. La grilla ya se
    // pinta de inmediato y se completa de forma reactiva al llegar cada prop.
    loadHolidays(currentYear);
    loadImportantDays(currentYear);
  });
  import { createEventDispatcher } from 'svelte';
  const dispatch = createEventDispatcher();

  let lastClickTime = 0;
  let lastClickedDate: string | null = null;
  
  function handleRobustClick(dayData: any) {
    const currentTime = new Date().getTime();
    const timeDiff = currentTime - lastClickTime;
    
    // Si el clic es en el mismo día y ocurrió hace menos de 400ms, es doble clic
    if (timeDiff < 400 && lastClickedDate === dayData.dateStr) {
      dispatch('dblclick_day', { dateStr: dayData.dateStr, dayData });
      lastClickTime = 0; // Resetear para evitar triples clics
    } else {
      // Es un clic simple (o el primero de un posible doble)
      dispatch('click_day', { dateStr: dayData.dateStr, dayData });
      lastClickTime = currentTime;
      lastClickedDate = dayData.dateStr;
    }
  }
</script>

<style>
  .calendar-day {
    user-select: none; /* Prevenir selección de texto al hacer doble clic */
    -webkit-user-select: none;
  }
</style>

<div class="calendar-nav">
    <button class="nav-btn" on:click={() => changeMonth(-1)} id="prevMonth">
        <i class="material-icons">chevron_left</i>
    </button>
    <h2 class="month-year" id="monthYear">{months[currentMonth]} {currentYear}</h2>
    <button class="nav-btn" on:click={() => changeMonth(1)} id="nextMonth">
        <i class="material-icons">chevron_right</i>
    </button>
</div>

<!-- Calendario -->
<div class="calendar-container">
    <div class="calendar-weekdays">
        <div class="weekday">D</div>
        <div class="weekday">L</div>
        <div class="weekday">M</div>
        <div class="weekday">X</div>
        <div class="weekday">J</div>
        <div class="weekday">V</div>
        <div class="weekday">S</div>
    </div>
    <div class="calendar-days" id="calendarDays">
        {#each blankDays as _}
            <div class="calendar-day empty"></div>
        {/each}

        {#each daysInMonth as dayData}
            <div class="calendar-day 
                {dayData.isToday ? 'today' : ''}
                {selectedDateStr === dayData.dateStr ? 'selected' : ''}
                {!isFemaleMode && !isFinanceMode && !isNotesMode && !isHabitsMode && dayData.holiday ? 'holiday' : ''} 
                {!isFemaleMode && !isFinanceMode && !isNotesMode && !isHabitsMode && dayData.importantDay ? 'important-day' : ''}
                {!isFemaleMode && !isFinanceMode && !isNotesMode && !isHabitsMode && dayData.dayEvents.length > 0 ? 'has-events' : ''}
                {isFemaleMode && dayData.cyclePhase === 'period' ? 'cycle-period' : ''}
                {isFemaleMode && dayData.cyclePhase === 'predicted-period' ? 'cycle-predicted-period' : ''}
                {isFemaleMode && dayData.cyclePhase === 'late-period' ? 'cycle-late-period' : ''}
                {isFemaleMode && dayData.cyclePhase === 'fertile' ? 'cycle-fertile' : ''}
                {isFemaleMode && dayData.cyclePhase === 'ovulation' ? 'cycle-ovulation' : ''}
                {isFinanceMode && dayData.hasFinance ? 'has-finance' : ''}
                {isFinanceMode && dayData.hasPendingFinance ? 'has-pending-finance' : ''}
                {isNotesMode && dayData.hasNote ? 'has-note' : ''}
                {isHabitsMode && dayData.totalHabits > 0 ? 'habit-day' : ''}
                {isHabitsMode && dayData.totalHabits > 0 && dayData.habitCompletionRate === 0 ? 'habit-heat-0' : ''}
                {isHabitsMode && dayData.totalHabits > 0 && dayData.habitCompletionRate > 0 && dayData.habitCompletionRate <= 0.33 ? 'habit-heat-1' : ''}
                {isHabitsMode && dayData.totalHabits > 0 && dayData.habitCompletionRate > 0.33 && dayData.habitCompletionRate <= 0.66 ? 'habit-heat-2' : ''}
                {isHabitsMode && dayData.totalHabits > 0 && dayData.habitCompletionRate > 0.66 && dayData.habitCompletionRate < 1.0 ? 'habit-heat-3' : ''}
                {isHabitsMode && dayData.totalHabits > 0 && dayData.habitCompletionRate === 1.0 ? 'habit-heat-4' : ''}
            " 
            role="button" 
            tabindex="0"
            aria-selected={selectedDateStr === dayData.dateStr}
            aria-current={dayData.isToday ? 'date' : undefined}
            on:click={() => handleRobustClick(dayData)}
            on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') handleRobustClick(dayData) }}
            >
                <div class="day-number">{dayData.day}</div>
                
                <!-- Indicadores en modo femenino -->
                {#if isFemaleMode}
                    {#if dayData.cyclePhase === 'period'}
                        <div class="cycle-indicator" title="Menstruación">🩸</div>
                    {:else if dayData.cyclePhase === 'late-period'}
                        <div class="cycle-indicator" title="Periodo con retraso">⏳</div>
                    {:else if dayData.cyclePhase === 'predicted-period'}
                        <div class="cycle-indicator" title="Periodo Previsto" style="opacity: 0.5;">🩸</div>
                    {:else if dayData.cyclePhase === 'fertile'}
                        <div class="cycle-indicator" title="Ventana Fértil">🌸</div>
                    {:else if dayData.cyclePhase === 'ovulation'}
                        <div class="cycle-indicator" title="Ovulación">✨</div>
                    {/if}
                {/if}

                <!-- Indicadores en modo normal -->
                {#if !isFemaleMode && !isFinanceMode && !isNotesMode && !isHabitsMode}
                    {#if dayData.holiday}
                        <div class="holiday-indicator" title="{dayData.holiday.name || dayData.holiday.localName}">🎉</div>
                    {:else if dayData.importantDay}
                        <div class="important-indicator" title="{dayData.importantDay.nombre} — {dayData.importantDay.descripcion || ''}"></div>
                    {/if}
                    <div class="calendar-indicators">
                      {#if dayData.dayEvents.length > 0}
                        <div class="event-indicator" title="{dayData.dayEvents.length} evento(s)">
                          {#each dayData.dayEvents.slice(0, 3) as event}
                            <div class="event-dot"></div>
                          {/each}
                        </div>
                      {/if}
                      {#if dayData.dayBirthdays && dayData.dayBirthdays.length > 0}
                        <div class="birthday-indicator" title="Cumpleaños">🎂</div>
                      {/if}
                    </div>
                {/if}

                <!-- Indicadores en modo finanzas -->
                {#if isFinanceMode && dayData.hasFinance}
                    <div class="finance-indicator {dayData.hasPendingFinance ? 'pending' : 'paid'}" title="Finanzas: {dayData.finEvents.length} transacciones">
                        <i class="material-icons">payments</i>
                    </div>
                {/if}

                <!-- Indicadores en modo notas -->
                {#if isNotesMode && dayData.hasNote}
                    <div class="notes-indicator" title="Nota registrada">
                        <i class="material-icons" style="font-size: 16px; color: #4FC3F7;">edit_note</i>
                    </div>
                {/if}

                <!-- Indicadores en modo hábitos -->
                {#if isHabitsMode && dayData.totalHabits > 0}
                    <div class="habit-indicator-badge" title="Progreso de hábitos: {dayData.completedHabitsCount}/{dayData.totalHabits}">
                        <span>{dayData.completedHabitsCount}/{dayData.totalHabits}</span>
                    </div>
                {/if}
            </div>
        {/each}
    </div>
</div>
