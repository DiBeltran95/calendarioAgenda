<script lang="ts">
  import { toDateOnly } from '../dateUtils';
  import { API_BASE_URL } from '../config';

  export let cuentas: any[] = [];
  export let categorias: any[] = [];

  let activeFilter = '30d';

  // Las gráficas son la ÚNICA vista con histórico. Cargan sólo el rango elegido
  // (y sólo cuando se abre esta pestaña), trayendo del backend campos mínimos.
  let transacciones: any[] = [];
  let loadingAnalytics = false;

  async function loadAnalytics(dias: number) {
    loadingAnalytics = true;
    try {
      const token = localStorage.getItem('token');
      const res = await fetch(`${API_BASE_URL}/api/finanzas/analytics?dias=${dias}`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      if (res.ok) {
        const data = await res.json();
        transacciones = data.transacciones || [];
      }
    } catch (e) {
      console.error('Error al cargar analíticas', e);
    } finally {
      loadingAnalytics = false;
    }
  }

  // Recarga al cambiar el rango (y una vez al montar con el filtro por defecto).
  $: loadAnalytics(getDaysCount(activeFilter));

  // ===== CATEGORY VISUAL CONFIG =====
  const CAT_BASE: Record<string, { label: string, color: string, icon: string }> = {
    comida:          { label: 'Comida',          color: '#FF7043', icon: 'restaurant' },
    transporte:      { label: 'Transporte',      color: '#29B6F6', icon: 'directions_car' },
    servicios:       { label: 'Servicios',       color: '#AB47BC', icon: 'receipt_long' },
    entretenimiento: { label: 'Entretenimiento', color: '#FFCA28', icon: 'sports_esports' },
    salud:           { label: 'Salud',           color: '#26A69A', icon: 'medication' },
    educacion:       { label: 'Educación',       color: '#EC407A', icon: 'school' },
    ahorro:          { label: 'Ahorro/Inversión',color: '#66BB6A', icon: 'savings' },
    arriendo:        { label: 'Arriendo',        color: '#8D6E63', icon: 'real_estate_agent' },
    otros:           { label: 'Otros',           color: '#78909C', icon: 'payments' }
  };

  const CUSTOM_COLORS = ['#F06292','#4DD0E1','#AED581','#FFB74D','#CE93D8','#80DEEA','#FFCC02','#A5D6A7'];

  $: CAT = (() => {
    const merged = { ...CAT_BASE };
    categorias.forEach((cat, i) => {
      if (!merged[cat.valor]) {
        merged[cat.valor] = {
          label: cat.label,
          color: CUSTOM_COLORS[i % CUSTOM_COLORS.length],
          icon: cat.icono || 'sell'
        };
      }
    });
    return merged;
  })();

  const FILTERS: [string, string, string][] = [
    ['7d',  '7D',  '7 Días'],
    ['30d', '30D', '30 Días'],
    ['3m',  '3M',  '3 Meses'],
    ['6m',  '6M',  '6 Meses'],
    ['1y',  '1A',  '1 Año'],
  ];

  function getDaysCount(f: string): number {
    const m: Record<string,number> = { '7d':7, '30d':30, '3m':90, '6m':180, '1y':365 };
    return m[f] || 30;
  }

  // ===== CORE REACTIVE DATA =====
  $: daysCount = getDaysCount(activeFilter);

  $: dateRange = (() => {
    const end = new Date(); end.setHours(0,0,0,0);
    const start = new Date(end); start.setDate(start.getDate() - daysCount + 1);
    return { start: toDateOnly(start), end: toDateOnly(end) };
  })();

  $: filteredTxs = transacciones.filter(t => {
    const d = toDateOnly(t.fecha);
    return d >= dateRange.start && d <= dateRange.end;
  });

  $: incomes  = filteredTxs.filter(t => t.tipo === 'ingreso');
  $: expenses = filteredTxs.filter(t => t.tipo === 'gasto');
  $: totalIncome  = incomes.reduce((s, t) => s + Number(t.monto), 0);
  $: totalExpense = expenses.reduce((s, t) => s + Number(t.monto), 0);
  $: netBalance   = totalIncome - totalExpense;
  $: savingsRate  = totalIncome > 0 ? ((totalIncome - totalExpense) / totalIncome * 100) : 0;
  $: avgDailyExpense = daysCount > 0 ? totalExpense / daysCount : 0;

  // ===== HELPERS =====
  function fmt(v: number): string {
    return new Intl.NumberFormat('es-CO', { style:'currency', currency:'COP', minimumFractionDigits:0 }).format(v);
  }
  function fmtK(v: number): string {
    const a = Math.abs(v);
    if (a >= 1000000) return (v/1000000).toFixed(1) + 'M';
    if (a >= 1000) return (v/1000).toFixed(0) + 'K';
    return v.toFixed(0);
  }
  function fmtDate(s: string): string {
    const p = s.split('-');
    if (p.length !== 3) return s;
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return `${p[2]} ${m[parseInt(p[1])-1]}`;
  }
  function fmtMonth(s: string): string {
    const p = s.split('-');
    if (p.length < 2) return s;
    const m = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    return `${m[parseInt(p[1])-1]} ${p[0].slice(2)}`;
  }

  // ===== 1. NET WORTH TREND =====
  $: trendPoints = (() => {
    const dates: string[] = [];
    const today = new Date(); today.setHours(0,0,0,0);
    for (let i = daysCount - 1; i >= 0; i--) {
      const d = new Date(today); d.setDate(d.getDate() - i);
      dates.push(toDateOnly(d));
    }
    let bal = 0;
    for (const c of cuentas) {
      const s = Number(c.saldo);
      bal += c.tipo === 'tarjeta_credito' ? -s : s;
    }
    const txMap: Record<string, any[]> = {};
    for (const t of transacciones) {
      const ds = toDateOnly(t.fecha);
      if (!txMap[ds]) txMap[ds] = [];
      txMap[ds].push(t);
    }
    const rev = [...dates].reverse();
    const bMap: Record<string, number> = {};
    bMap[rev[0]] = bal;
    for (const ds of rev) {
      bMap[ds] = bal;
      for (const tx of txMap[ds] || []) {
        const a = Number(tx.monto);
        if (tx.tipo === 'ingreso') bal -= a; else if (tx.tipo === 'gasto') bal += a;
      }
    }
    return dates.map(d => ({ date: d, balance: bMap[d] ?? bal }));
  })();

  // ===== 2. EXPENSE DISTRIBUTION (Donut) =====
  $: catData = (() => {
    const g: Record<string, number> = {};
    let total = 0;
    for (const t of expenses) {
      const c = t.categoria || 'otros';
      g[c] = (g[c] || 0) + Number(t.monto);
      total += Number(t.monto);
    }
    const list = Object.entries(g).map(([k, v]) => {
      const s = CAT[k] || { label: k, color: '#78909C', icon: 'payments' };
      return { key: k, label: s.label, value: v, pct: total > 0 ? (v / total * 100) : 0, color: s.color, icon: s.icon };
    }).sort((a, b) => b.value - a.value);
    return { list, total };
  })();

  // ===== 3. MONTHLY INCOME vs EXPENSE BARS =====
  $: monthlyBars = (() => {
    const months: Record<string, { inc: number, exp: number }> = {};
    for (const t of filteredTxs) {
      const m = toDateOnly(t.fecha).slice(0, 7); // YYYY-MM
      if (!months[m]) months[m] = { inc: 0, exp: 0 };
      const a = Number(t.monto);
      if (t.tipo === 'ingreso') months[m].inc += a; else months[m].exp += a;
    }
    return Object.entries(months)
      .sort(([a],[b]) => a.localeCompare(b))
      .map(([month, data]) => ({ month, ...data, net: data.inc - data.exp }));
  })();

  // ===== 4. DAILY CASH FLOW (last N days as bars) =====
  $: dailyFlow = (() => {
    const maxDays = Math.min(daysCount, 30); // max 30 bars for readability
    const today = new Date(); today.setHours(0,0,0,0);
    const days: { date: string, inc: number, exp: number, net: number }[] = [];
    for (let i = maxDays - 1; i >= 0; i--) {
      const d = new Date(today); d.setDate(d.getDate() - i);
      const ds = toDateOnly(d);
      let inc = 0, exp = 0;
      for (const t of filteredTxs) {
        if (toDateOnly(t.fecha) === ds) {
          const a = Number(t.monto);
          if (t.tipo === 'ingreso') inc += a; else exp += a;
        }
      }
      days.push({ date: ds, inc, exp, net: inc - exp });
    }
    return days;
  })();

  // ===== 5. TOP EXPENSES =====
  $: topExpenses = (() => {
    return [...expenses]
      .sort((a, b) => Number(b.monto) - Number(a.monto))
      .slice(0, 8)
      .map(t => ({
        desc: t.descripcion || 'Sin descripción',
        monto: Number(t.monto),
        fecha: toDateOnly(t.fecha),
        cat: t.categoria || 'otros',
        cuenta: cuentas.find(c => c.id === t.cuenta_id)?.nombre || '—'
      }));
  })();

  // ===== 6. INCOME DISTRIBUTION (by account) =====
  $: incomeByAccount = (() => {
    const g: Record<string, { name: string, total: number }> = {};
    for (const t of incomes) {
      const acct = cuentas.find(c => c.id === t.cuenta_id);
      const key = t.cuenta_id || 'sin-cuenta';
      const name = acct?.nombre || 'Sin cuenta';
      if (!g[key]) g[key] = { name, total: 0 };
      g[key].total += Number(t.monto);
    }
    return Object.values(g).sort((a, b) => b.total - a.total);
  })();

  // ===== 7. ACCOUNT BALANCES =====
  $: accountBalances = cuentas
    .map(c => ({
      name: c.nombre,
      tipo: c.tipo,
      saldo: Number(c.saldo),
      color: c.tipo === 'tarjeta_credito' ? '#F44336' :
             c.tipo === 'cdt' ? '#FFD700' :
             c.tipo === 'ahorros' ? '#34E47E' : '#29B6F6'
    }))
    .sort((a, b) => b.saldo - a.saldo);

  // ===== DONUT SEGMENTS =====
  function getCoord(pct: number): [number, number] {
    const a = pct * 2 * Math.PI - Math.PI / 2;
    return [Math.cos(a), Math.sin(a)];
  }
  $: donutSegs = (() => {
    let acc = 0;
    return catData.list.map(item => {
      const s = acc, e = s + item.pct / 100;
      acc = e;
      const r = 58, cx = 75, cy = 75;
      const [sx, sy] = getCoord(s);
      const [ex, ey] = getCoord(e);
      const la = e - s > 0.5 ? 1 : 0;
      if (item.pct >= 99.9) return { d: `M ${cx} ${cy-r} A ${r} ${r} 0 1 1 ${cx-0.01} ${cy-r}`, color: item.color, item };
      return { d: `M ${cx+sx*r} ${cy+sy*r} A ${r} ${r} 0 ${la} 1 ${cx+ex*r} ${cy+ey*r}`, color: item.color, item };
    });
  })();

  // ===== CHART SCALE HELPERS =====
  const CW = 480, CH = 200, PL = 58, PR = 12, PT = 16, PB = 32;

  $: tMinMax = (() => {
    if (!trendPoints.length) return { min: 0, max: 1000 };
    const bs = trendPoints.map(p => p.balance);
    let mn = Math.min(...bs), mx = Math.max(...bs), d = mx - mn;
    if (d === 0) d = Math.abs(mn) > 0 ? Math.abs(mn) * 0.2 : 1e6;
    return { min: mn - d * 0.08, max: mx + d * 0.08 };
  })();

  $: tGetX = (i: number) => trendPoints.length <= 1 ? PL : PL + (i/(trendPoints.length-1)) * (CW-PL-PR);
  $: tGetY = (v: number) => {
    const {min,max} = tMinMax;
    return CH - PB - ((v-min)/(max-min)) * (CH-PT-PB);
  };
  $: tLine = trendPoints.map((p,i) => `${i?'L':'M'} ${tGetX(i)} ${tGetY(p.balance)}`).join(' ');
  $: tArea = (() => {
    if (!trendPoints.length) return '';
    const pts = trendPoints.map((p,i) => `L ${tGetX(i)} ${tGetY(p.balance)}`).join(' ');
    return `M ${tGetX(0)} ${CH-PB} ${pts} L ${tGetX(trendPoints.length-1)} ${CH-PB} Z`;
  })();
  $: tYGrid = (() => {
    const {min,max} = tMinMax;
    return [0,1,2,3,4].map(i => min + (i/4)*(max-min));
  })();
  $: tXIdxs = (() => {
    const n = trendPoints.length;
    if (n <= 5) return trendPoints.map((_,i) => i);
    return [0,1,2,3,4].map(i => Math.floor((i/4)*(n-1)));
  })();

  // Tooltip state
  let hoverPt: any = null;
  let hoverX = 0, hoverY = 0;
  let hoverBar: any = null;

  // Monthly bars scale
  $: mbMax = Math.max(1, ...monthlyBars.flatMap(b => [b.inc, b.exp]));

  // Daily flow scale
  $: dfMax = Math.max(1, ...dailyFlow.map(d => Math.max(d.inc, d.exp)));

  // Top expenses max
  $: teMax = topExpenses.length > 0 ? topExpenses[0].monto : 1;

  // Account balance max
  $: abMax = Math.max(1, ...accountBalances.map(a => Math.abs(a.saldo)));
</script>

<!-- ======================================
     INLINE ANALYTICS - FULL DASHBOARD
     ====================================== -->
<div class="aa">

  <!-- Filter Pills -->
  <div class="aa-filters">
    {#each FILTERS as [val, short, label]}
      <button class="aa-pill {activeFilter === val ? 'on' : ''}" on:click={() => activeFilter = val} title={label}>{short}</button>
    {/each}
  </div>

  <!-- ===== KPI SUMMARY ===== -->
  <div class="aa-kpis">
    <div class="aa-kpi">
      <div class="aa-kpi-ico g"><i class="material-icons">trending_up</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Ingresos</span>
        <span class="aa-kpi-val g">+{fmt(totalIncome)}</span>
      </div>
    </div>
    <div class="aa-kpi">
      <div class="aa-kpi-ico r"><i class="material-icons">trending_down</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Gastos</span>
        <span class="aa-kpi-val r">-{fmt(totalExpense)}</span>
      </div>
    </div>
    <div class="aa-kpi">
      <div class="aa-kpi-ico {netBalance >= 0 ? 'g' : 'r'}"><i class="material-icons">account_balance_wallet</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Balance Neto</span>
        <span class="aa-kpi-val {netBalance >= 0 ? 'g' : 'r'}">{netBalance >= 0 ? '+' : ''}{fmt(netBalance)}</span>
      </div>
    </div>
    <div class="aa-kpi">
      <div class="aa-kpi-ico {savingsRate >= 10 ? 'g' : savingsRate >= 0 ? 'y' : 'r'}"><i class="material-icons">savings</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Tasa Ahorro</span>
        <span class="aa-kpi-val {savingsRate >= 10 ? 'g' : savingsRate >= 0 ? 'y' : 'r'}">{savingsRate.toFixed(1)}%</span>
      </div>
    </div>
    <div class="aa-kpi">
      <div class="aa-kpi-ico b"><i class="material-icons">calendar_today</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Gasto/Día Prom</span>
        <span class="aa-kpi-val b">{fmt(avgDailyExpense)}</span>
      </div>
    </div>
    <div class="aa-kpi">
      <div class="aa-kpi-ico y"><i class="material-icons">receipt</i></div>
      <div class="aa-kpi-txt">
        <span class="aa-kpi-lbl">Transacciones</span>
        <span class="aa-kpi-val y">{filteredTxs.length}</span>
      </div>
    </div>
  </div>

  <!-- ===== 1. NET WORTH TREND ===== -->
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#34E47E;">show_chart</i><div><h4>Tendencia de Patrimonio Neto</h4><p>Evolución diaria · Ahorros + CDTs - Tarjetas</p></div></div>
    <div class="aa-svg-wrap">
      <svg viewBox="0 0 {CW} {CH}" class="aa-svg" preserveAspectRatio="xMidYMid meet">
        <defs>
          <linearGradient id="ag" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#34E47E" stop-opacity="0.2"/><stop offset="100%" stop-color="#34E47E" stop-opacity="0"/></linearGradient>
          <filter id="gl"><feDropShadow dx="0" dy="1" stdDeviation="2" flood-color="#34E47E" flood-opacity="0.3"/></filter>
        </defs>
        {#each tYGrid as v}{@const y = tGetY(v)}<line x1={PL} y1={y} x2={CW-PR} y2={y} stroke="rgba(255,255,255,0.03)" stroke-width="1"/><text x={PL-5} y={y+3} text-anchor="end" class="aa-ax">{fmtK(v)}</text>{/each}
        {#each tXIdxs as idx}{@const p = trendPoints[idx]}{#if p}{@const x = tGetX(idx)}<line x1={x} y1={PT} x2={x} y2={CH-PB} stroke="rgba(255,255,255,0.02)" stroke-width="1" stroke-dasharray="3 3"/><text x={x} y={CH-PB+13} text-anchor="middle" class="aa-ax">{fmtDate(p.date)}</text>{/if}{/each}
        {#if tArea}<path d={tArea} fill="url(#ag)"/>{/if}
        {#if tLine}<path d={tLine} fill="none" stroke="#34E47E" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" filter="url(#gl)"/>{/if}
        {#each trendPoints as pt, i}{@const cx = tGetX(i)}{@const cy = tGetY(pt.balance)}<circle {cx} {cy} r="9" fill="transparent" class="aa-htrig" on:mouseenter={() => { hoverPt = pt; hoverX = cx; hoverY = cy - 6; }} on:mouseleave={() => hoverPt = null}/><circle {cx} {cy} r="2.5" fill="var(--bg-secondary,#0F2A1C)" stroke="#34E47E" stroke-width="2" class="aa-dot {hoverPt === pt ? 'on' : ''}"/>{/each}
      </svg>
      {#if hoverPt}<div class="aa-tip" style="left:{(hoverX/CW)*100}%;top:{(hoverY/CH)*100}%"><span class="aa-tip-d">{fmtDate(hoverPt.date)}</span><span class="aa-tip-v">{fmt(hoverPt.balance)}</span></div>{/if}
    </div>
  </div>

  <!-- ===== 2. MONTHLY INCOME vs EXPENSE ===== -->
  {#if monthlyBars.length > 0}
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#29B6F6;">bar_chart</i><div><h4>Ingresos vs Gastos Mensuales</h4><p>Comparación mensual de flujo de efectivo</p></div></div>
    <div class="aa-bars-container">
      {#each monthlyBars as bar, i}
        <div class="aa-bar-group" on:mouseenter={() => hoverBar = bar} on:mouseleave={() => hoverBar = null}>
          <div class="aa-bar-pair">
            <div class="aa-bar inc" style="height: {mbMax > 0 ? (bar.inc / mbMax * 100) : 0}%;" title="Ingreso: {fmt(bar.inc)}"></div>
            <div class="aa-bar exp" style="height: {mbMax > 0 ? (bar.exp / mbMax * 100) : 0}%;" title="Gasto: {fmt(bar.exp)}"></div>
          </div>
          <span class="aa-bar-label">{fmtMonth(bar.month)}</span>
          {#if hoverBar === bar}
            <div class="aa-bar-tooltip">
              <div><span class="aa-bt-dot g"></span> {fmt(bar.inc)}</div>
              <div><span class="aa-bt-dot r"></span> {fmt(bar.exp)}</div>
              <div class="aa-bt-net {bar.net >= 0 ? 'g' : 'r'}">{bar.net >= 0 ? '+' : ''}{fmt(bar.net)}</div>
            </div>
          {/if}
        </div>
      {/each}
    </div>
    <div class="aa-legend-mini">
      <span><span class="aa-bt-dot g"></span> Ingresos</span>
      <span><span class="aa-bt-dot r"></span> Gastos</span>
    </div>
  </div>
  {/if}

  <!-- ===== 3. DAILY CASH FLOW ===== -->
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#AB47BC;">waterfall_chart</i><div><h4>Flujo de Caja Diario</h4><p>Ingresos y gastos por día · Últimos {dailyFlow.length} días</p></div></div>
    <div class="aa-flow-container">
      {#each dailyFlow as day, i}
        {@const barH = dfMax > 0 ? Math.max(2, Math.max(day.inc, day.exp) / dfMax * 100) : 2}
        <div class="aa-flow-bar" title="{fmtDate(day.date)}: +{fmt(day.inc)} / -{fmt(day.exp)}" style="flex: 1; min-width: 0;">
          <div class="aa-flow-stack" style="height: {barH}%;">
            {#if day.inc > 0}<div class="aa-flow-seg inc" style="height: {day.inc / Math.max(day.inc, day.exp) * 100}%;"></div>{/if}
            {#if day.exp > 0}<div class="aa-flow-seg exp" style="height: {day.exp / Math.max(day.inc, day.exp) * 100}%;"></div>{/if}
          </div>
          {#if i % Math.max(1, Math.floor(dailyFlow.length / 5)) === 0 || i === dailyFlow.length - 1}
            <span class="aa-flow-lbl">{day.date.slice(8)}</span>
          {:else}
            <span class="aa-flow-lbl"></span>
          {/if}
        </div>
      {/each}
    </div>
    <div class="aa-legend-mini"><span><span class="aa-bt-dot g"></span> Ingreso</span><span><span class="aa-bt-dot r"></span> Gasto</span></div>
  </div>

  <!-- ===== 4. EXPENSE DISTRIBUTION (Donut) ===== -->
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#FFCA28;">donut_large</i><div><h4>Distribución de Gastos</h4><p>Egresos clasificados por categoría</p></div></div>
    {#if catData.list.length === 0}
      <div class="aa-empty"><i class="material-icons">payments</i><p>Sin gastos registrados en este periodo</p></div>
    {:else}
      <div class="aa-donut-row">
        <div class="aa-donut-wrap">
          <svg viewBox="0 0 150 150" class="aa-donut-svg">
            {#each donutSegs as seg}<path d={seg.d} fill="none" stroke={seg.color} stroke-width="13" class="aa-dseg"/>{/each}
          </svg>
          <div class="aa-donut-ctr"><span class="aa-dc-lbl">Total</span><span class="aa-dc-val">{fmt(catData.total)}</span></div>
        </div>
        <div class="aa-cat-list">
          {#each catData.list as c}
            <div class="aa-cat-row">
              <div class="aa-cat-left"><div class="aa-cdot" style="background:{c.color}"></div><i class="material-icons" style="color:{c.color};font-size:14px;">{c.icon}</i><span>{c.label}</span></div>
              <div class="aa-cat-right"><span class="aa-cat-amt">{fmt(c.value)}</span><span class="aa-cat-pct">{c.pct.toFixed(1)}%</span></div>
            </div>
          {/each}
        </div>
      </div>
    {/if}
  </div>

  <!-- ===== 5. TOP GASTOS ===== -->
  {#if topExpenses.length > 0}
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#F44336;">leaderboard</i><div><h4>Top Gastos del Periodo</h4><p>Los {topExpenses.length} egresos más grandes</p></div></div>
    <div class="aa-top-list">
      {#each topExpenses as tx, i}
        {@const catStyle = CAT[tx.cat] || CAT['otros']}
        <div class="aa-top-row">
          <div class="aa-top-rank">#{i + 1}</div>
          <div class="aa-top-info">
            <div class="aa-top-name">{tx.desc}</div>
            <div class="aa-top-meta">
              <i class="material-icons" style="font-size:12px;color:{catStyle.color};">{catStyle.icon}</i>
              {catStyle.label} · {fmtDate(tx.fecha)} · {tx.cuenta}
            </div>
          </div>
          <div class="aa-top-amt">{fmt(tx.monto)}</div>
          <div class="aa-top-bar-bg"><div class="aa-top-bar-fill" style="width: {teMax > 0 ? (tx.monto / teMax * 100) : 0}%;"></div></div>
        </div>
      {/each}
    </div>
  </div>
  {/if}

  <!-- ===== 6. INCOME BY ACCOUNT ===== -->
  {#if incomeByAccount.length > 0}
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#66BB6A;">account_balance</i><div><h4>Fuentes de Ingreso</h4><p>Distribución de ingresos por cuenta</p></div></div>
    <div class="aa-inc-list">
      {#each incomeByAccount as acct}
        {@const pct = totalIncome > 0 ? (acct.total / totalIncome * 100) : 0}
        <div class="aa-inc-row">
          <div class="aa-inc-info"><span class="aa-inc-name">{acct.name}</span><span class="aa-inc-pct">{pct.toFixed(1)}%</span></div>
          <div class="aa-inc-bar-bg"><div class="aa-inc-bar-fill" style="width:{pct}%;"></div></div>
          <span class="aa-inc-amt">{fmt(acct.total)}</span>
        </div>
      {/each}
    </div>
  </div>
  {/if}

  <!-- ===== 7. BALANCE POR CUENTA ===== -->
  {#if accountBalances.length > 0}
  <div class="aa-card">
    <div class="aa-hdr"><i class="material-icons" style="color:#FFD700;">pie_chart</i><div><h4>Distribución de Saldos</h4><p>Saldo actual por cuenta</p></div></div>
    <div class="aa-bal-list">
      {#each accountBalances as acct}
        <div class="aa-bal-row">
          <div class="aa-bal-left">
            <div class="aa-bal-dot" style="background:{acct.color};"></div>
            <div class="aa-bal-info">
              <span class="aa-bal-name">{acct.name}</span>
              <span class="aa-bal-type">{acct.tipo === 'tarjeta_credito' ? 'Tarjeta Crédito' : acct.tipo === 'cdt' ? 'CDT/Inversión' : acct.tipo === 'ahorros' ? 'Ahorros' : 'Efectivo'}</span>
            </div>
          </div>
          <div class="aa-bal-right">
            <span class="aa-bal-amt" style="color:{acct.color};">{acct.tipo === 'tarjeta_credito' ? '-' : ''}{fmt(acct.saldo)}</span>
            <div class="aa-bal-bar-bg"><div class="aa-bal-bar-fill" style="width:{abMax > 0 ? (Math.abs(acct.saldo) / abMax * 100) : 0}%; background:{acct.color};"></div></div>
          </div>
        </div>
      {/each}
    </div>
  </div>
  {/if}

</div>

<style>
  .aa { display: flex; flex-direction: column; gap: 14px; animation: aaIn .3s ease; }

  /* Filters */
  .aa-filters { display: flex; gap: 5px; padding: 3px; background: rgba(0,0,0,.18); border: 1px solid var(--border-color, rgba(255,255,255,.04)); border-radius: 10px; width: fit-content; }
  .aa-pill { background: transparent; border: none; color: var(--text-secondary,#8696A0); font-size: .73rem; font-weight: 600; padding: 5px 13px; border-radius: 7px; cursor: pointer; transition: all .2s; letter-spacing: .3px; }
  .aa-pill:hover { color: var(--text-primary,#E9EDEF); background: rgba(255,215,0,.04); }
  .aa-pill.on { background: rgba(255,215,0,.1); color: #FFD700; border: 1px solid rgba(255,215,0,.15); }

  /* KPIs */
  .aa-kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .aa-kpi { display: flex; align-items: center; gap: 8px; padding: 10px 12px; background: linear-gradient(135deg, rgba(255,255,255,.025), rgba(255,255,255,.008)); border: 1px solid var(--border-color, rgba(255,255,255,.06)); border-radius: 10px; }
  .aa-kpi-ico { width: 30px; height: 30px; border-radius: 8px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
  .aa-kpi-ico i { font-size: 16px; }
  .aa-kpi-ico.g { background: rgba(52,228,126,.1); color: #34E47E; }
  .aa-kpi-ico.r { background: rgba(244,67,54,.1); color: #F44336; }
  .aa-kpi-ico.y { background: rgba(255,215,0,.1); color: #FFD700; }
  .aa-kpi-ico.b { background: rgba(41,182,246,.1); color: #29B6F6; }
  .aa-kpi-txt { display: flex; flex-direction: column; gap: 0; min-width: 0; }
  .aa-kpi-lbl { font-size: .62rem; color: var(--text-secondary,#8696A0); text-transform: uppercase; letter-spacing: .4px; font-weight: 600; }
  .aa-kpi-val { font-size: .88rem; font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aa-kpi-val.g { color: #34E47E; } .aa-kpi-val.r { color: #F44336; } .aa-kpi-val.y { color: #FFD700; } .aa-kpi-val.b { color: #29B6F6; }

  /* Cards */
  .aa-card { background: linear-gradient(135deg, rgba(255,255,255,.025), rgba(255,255,255,.008)); border: 1px solid var(--border-color, rgba(255,255,255,.06)); border-radius: 12px; padding: 14px; display: flex; flex-direction: column; gap: 12px; }
  .aa-hdr { display: flex; align-items: center; gap: 10px; }
  .aa-hdr > i { font-size: 20px; flex-shrink: 0; }
  .aa-hdr h4 { font-size: .88rem; font-weight: 600; color: var(--text-primary,#E9EDEF); margin: 0; }
  .aa-hdr p { font-size: .68rem; color: var(--text-secondary,#8696A0); margin: 0; }

  /* SVG Chart (Trend) */
  .aa-svg-wrap { position: relative; width: 100%; }
  .aa-svg { width: 100%; height: auto; overflow: visible; }
  .aa-ax { fill: var(--text-tertiary,#667781); font-size: 7.5px; font-weight: 500; font-family: monospace; }
  .aa-htrig { cursor: pointer; }
  .aa-dot { transition: r .2s, stroke-width .2s, fill .2s; pointer-events: none; }
  .aa-dot.on { r: 4.5; stroke-width: 2.5; fill: #34E47E; }
  .aa-tip { position: absolute; transform: translate(-50%,-100%); background: var(--bg-secondary,rgba(11,20,26,.95)); border: 1px solid rgba(52,228,126,.3); padding: 4px 8px; border-radius: 7px; pointer-events: none; box-shadow: 0 3px 10px rgba(0,0,0,.5); z-index: 10; display: flex; flex-direction: column; gap: 1px; animation: aaTipIn .15s cubic-bezier(.175,.885,.32,1.275); }
  .aa-tip-d { font-size: .58rem; color: var(--text-secondary,#8696A0); text-transform: uppercase; font-weight: 600; }
  .aa-tip-v { font-size: .78rem; font-weight: 750; color: #34E47E; font-family: monospace; }

  /* Monthly Bars */
  .aa-bars-container { display: flex; gap: 8px; align-items: flex-end; height: 140px; padding-top: 10px; }
  .aa-bar-group { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 4px; height: 100%; position: relative; }
  .aa-bar-pair { display: flex; gap: 3px; align-items: flex-end; flex: 1; width: 100%; }
  .aa-bar { flex: 1; border-radius: 4px 4px 0 0; min-height: 3px; transition: all .3s ease; cursor: pointer; }
  .aa-bar.inc { background: linear-gradient(to top, rgba(52,228,126,.6), rgba(52,228,126,.9)); }
  .aa-bar.inc:hover { background: #34E47E; box-shadow: 0 0 8px rgba(52,228,126,.4); }
  .aa-bar.exp { background: linear-gradient(to top, rgba(244,67,54,.5), rgba(244,67,54,.85)); }
  .aa-bar.exp:hover { background: #F44336; box-shadow: 0 0 8px rgba(244,67,54,.4); }
  .aa-bar-label { font-size: .6rem; color: var(--text-tertiary,#667781); white-space: nowrap; }
  .aa-bar-tooltip { position: absolute; bottom: 100%; left: 50%; transform: translateX(-50%); background: var(--bg-secondary,rgba(11,20,26,.95)); border: 1px solid var(--border-color,rgba(255,255,255,.08)); border-radius: 8px; padding: 6px 10px; font-size: .7rem; color: var(--text-primary,#E9EDEF); white-space: nowrap; z-index: 20; box-shadow: 0 4px 12px rgba(0,0,0,.5); animation: aaTipIn .15s ease; display: flex; flex-direction: column; gap: 2px; }
  .aa-bt-dot { display: inline-block; width: 7px; height: 7px; border-radius: 50%; margin-right: 4px; }
  .aa-bt-dot.g { background: #34E47E; }
  .aa-bt-dot.r { background: #F44336; }
  .aa-bt-net { font-weight: 700; padding-top: 2px; border-top: 1px solid rgba(255,255,255,.06); margin-top: 2px; }
  .aa-bt-net.g { color: #34E47E; } .aa-bt-net.r { color: #F44336; }
  .aa-legend-mini { display: flex; gap: 14px; justify-content: center; font-size: .65rem; color: var(--text-secondary,#8696A0); }

  /* Daily Cash Flow */
  .aa-flow-container { display: flex; align-items: flex-end; height: 110px; gap: 1px; }
  .aa-flow-bar { display: flex; flex-direction: column; align-items: center; height: 100%; justify-content: flex-end; }
  .aa-flow-stack { display: flex; flex-direction: column; width: 100%; border-radius: 2px 2px 0 0; overflow: hidden; transition: height .3s ease; }
  .aa-flow-seg { width: 100%; transition: all .2s; }
  .aa-flow-seg.inc { background: rgba(52,228,126,.7); }
  .aa-flow-seg.exp { background: rgba(244,67,54,.6); }
  .aa-flow-bar:hover .aa-flow-seg.inc { background: #34E47E; }
  .aa-flow-bar:hover .aa-flow-seg.exp { background: #F44336; }
  .aa-flow-lbl { font-size: .55rem; color: var(--text-tertiary,#667781); margin-top: 2px; min-height: 10px; }

  /* Donut */
  .aa-donut-row { display: flex; align-items: flex-start; gap: 16px; }
  .aa-donut-wrap { position: relative; width: 130px; height: 130px; flex-shrink: 0; }
  .aa-donut-svg { transform: rotate(-90deg); width: 100%; height: 100%; }
  .aa-dseg { transition: stroke-width .2s; } .aa-dseg:hover { stroke-width: 17; }
  .aa-donut-ctr { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; pointer-events: none; }
  .aa-dc-lbl { font-size: .56rem; color: var(--text-secondary,#8696A0); text-transform: uppercase; font-weight: 600; }
  .aa-dc-val { font-size: .8rem; font-weight: 800; color: var(--text-primary,#E9EDEF); max-width: 95px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; text-align: center; }
  .aa-cat-list { flex: 1; display: flex; flex-direction: column; gap: 5px; min-width: 0; }
  .aa-cat-row { display: flex; justify-content: space-between; align-items: center; padding: 4px 7px; background: rgba(255,255,255,.012); border: 1px solid rgba(255,255,255,.02); border-radius: 7px; transition: background .2s; }
  .aa-cat-row:hover { background: rgba(255,255,255,.04); }
  .aa-cat-left { display: flex; align-items: center; gap: 5px; min-width: 0; }
  .aa-cdot { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
  .aa-cat-left span { font-size: .72rem; color: var(--text-primary,#E9EDEF); font-weight: 550; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aa-cat-right { display: flex; flex-direction: column; align-items: flex-end; gap: 0; flex-shrink: 0; }
  .aa-cat-amt { font-size: .72rem; font-weight: 650; color: var(--text-primary,#E9EDEF); }
  .aa-cat-pct { font-size: .58rem; color: var(--text-secondary,#8696A0); font-weight: 600; }

  /* Top Expenses */
  .aa-top-list { display: flex; flex-direction: column; gap: 8px; }
  .aa-top-row { display: grid; grid-template-columns: 28px 1fr auto; grid-template-rows: auto auto; gap: 2px 10px; align-items: center; padding: 8px 10px; background: rgba(255,255,255,.012); border: 1px solid rgba(255,255,255,.025); border-radius: 8px; transition: background .2s; }
  .aa-top-row:hover { background: rgba(255,255,255,.04); }
  .aa-top-rank { grid-row: 1 / 3; font-size: .82rem; font-weight: 800; color: var(--text-tertiary,#667781); text-align: center; }
  .aa-top-info { grid-column: 2; grid-row: 1; }
  .aa-top-name { font-size: .78rem; font-weight: 600; color: var(--text-primary,#E9EDEF); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aa-top-meta { font-size: .6rem; color: var(--text-secondary,#8696A0); display: flex; align-items: center; gap: 3px; margin-top: 1px; }
  .aa-top-amt { grid-column: 3; grid-row: 1; font-size: .82rem; font-weight: 750; color: #F44336; text-align: right; }
  .aa-top-bar-bg { grid-column: 2 / 4; grid-row: 2; height: 4px; background: rgba(244,67,54,.08); border-radius: 2px; overflow: hidden; }
  .aa-top-bar-fill { height: 100%; background: linear-gradient(90deg, rgba(244,67,54,.5), #F44336); border-radius: 2px; transition: width .4s ease; }

  /* Income by Account */
  .aa-inc-list { display: flex; flex-direction: column; gap: 8px; }
  .aa-inc-row { display: flex; flex-direction: column; gap: 4px; }
  .aa-inc-info { display: flex; justify-content: space-between; align-items: baseline; }
  .aa-inc-name { font-size: .78rem; font-weight: 600; color: var(--text-primary,#E9EDEF); }
  .aa-inc-pct { font-size: .65rem; font-weight: 600; color: var(--text-secondary,#8696A0); }
  .aa-inc-bar-bg { height: 6px; background: rgba(102,187,106,.08); border-radius: 3px; overflow: hidden; }
  .aa-inc-bar-fill { height: 100%; background: linear-gradient(90deg, rgba(102,187,106,.5), #66BB6A); border-radius: 3px; transition: width .4s ease; }
  .aa-inc-amt { font-size: .75rem; font-weight: 700; color: #66BB6A; align-self: flex-end; }

  /* Balance by Account */
  .aa-bal-list { display: flex; flex-direction: column; gap: 8px; }
  .aa-bal-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 10px; background: rgba(255,255,255,.012); border: 1px solid rgba(255,255,255,.025); border-radius: 8px; gap: 12px; transition: background .2s; }
  .aa-bal-row:hover { background: rgba(255,255,255,.04); }
  .aa-bal-left { display: flex; align-items: center; gap: 8px; min-width: 0; }
  .aa-bal-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
  .aa-bal-info { display: flex; flex-direction: column; min-width: 0; }
  .aa-bal-name { font-size: .78rem; font-weight: 600; color: var(--text-primary,#E9EDEF); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .aa-bal-type { font-size: .6rem; color: var(--text-secondary,#8696A0); }
  .aa-bal-right { display: flex; flex-direction: column; align-items: flex-end; gap: 3px; flex-shrink: 0; }
  .aa-bal-amt { font-size: .82rem; font-weight: 750; }
  .aa-bal-bar-bg { width: 60px; height: 4px; background: rgba(255,255,255,.04); border-radius: 2px; overflow: hidden; }
  .aa-bal-bar-fill { height: 100%; border-radius: 2px; transition: width .4s ease; }

  /* Empty */
  .aa-empty { padding: 25px 10px; display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--text-secondary,#8696A0); text-align: center; }
  .aa-empty i { font-size: 32px; opacity: .3; }
  .aa-empty p { font-size: .78rem; margin: 0; }

  /* Animations */
  @keyframes aaIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
  @keyframes aaTipIn { from { opacity: 0; transform: translate(-50%,-100%) scale(.9); } to { opacity: 1; transform: translate(-50%,-100%) scale(1); } }

  /* Responsive */
  @media (max-width: 480px) {
    .aa-kpis { grid-template-columns: repeat(2, 1fr); }
    .aa-donut-row { flex-direction: column; align-items: center; }
    .aa-bars-container { height: 110px; }
  }
</style>
