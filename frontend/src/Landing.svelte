<script lang="ts">
  // Inter empaquetada: la landing es solo web, pero tampoco depende del CDN.
  import '@fontsource/inter/400.css';
  import '@fontsource/inter/600.css';
  import '@fontsource/inter/700.css';
  import '@fontsource/inter/900.css';
  import { navigate } from './lib/router';

  let mobileOpen = false;
  let openFaq: number | null = 0;
  const year = new Date().getFullYear();

  // Contacto por WhatsApp
  const WHATSAPP_URL = 'https://wa.me/573212511313?text=' + encodeURIComponent('Hola, quiero saber más sobre Agendaservi 👋');

  function go(path: string) {
    mobileOpen = false;
    navigate(path);
  }
  function toggleFaq(i: number) {
    openFaq = openFaq === i ? null : i;
  }

  // Acción: revela el elemento al entrar en viewport.
  function inview(node: HTMLElement) {
    const obs = new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) { node.classList.add('visible'); obs.unobserve(node); } });
    }, { threshold: 0.12 });
    obs.observe(node);
    return { destroy() { obs.disconnect(); } };
  }

  // Módulos reales de la app
  const modulos = [
    { icon: 'event', color: 'blue', titulo: 'Calendario inteligente', desc: 'Eventos, cumpleaños y recordatorios con avisos por WhatsApp 30 min antes y a la hora exacta. Nunca más se te olvida nada.' },
    { icon: 'account_balance_wallet', color: 'green', titulo: 'Finanzas bajo control', desc: 'Cuentas, presupuestos, metas de ahorro, tarjetas con fecha de corte y gráficas que muestran a dónde se va tu dinero.' },
    { icon: 'favorite', color: 'pink', titulo: 'Salud femenina', desc: 'Seguimiento del ciclo, días fértiles y predicciones. Privado, claro y a tu ritmo.' },
    { icon: 'self_improvement', color: 'amber', titulo: 'Hábitos y rutinas', desc: 'Crea hábitos, marca tu progreso diario y construye constancia con un mapa visual de tus logros.' }
  ];

  const features = [
    { icon: 'link', titulo: 'Link personalizado', desc: 'Tu propio enlace de agendamiento para compartir en redes, WhatsApp o tu bio.' },
    { icon: 'verified', titulo: 'Confirmación por WhatsApp', desc: 'Tus clientes confirman con un código por WhatsApp. Sin spam, sin citas falsas.' },
    { icon: 'calendar_month', titulo: 'Horarios flexibles', desc: 'Define días, horas y duración de cada servicio. Bloquea fechas cuando lo necesites.' },
    { icon: 'groups', titulo: 'Gestión de clientes', desc: 'Historial, estadísticas y la opción de bloquear clientes problemáticos.' },
    { icon: 'notifications_active', titulo: 'Avisos en tiempo real', desc: 'Te enteras al instante cuando alguien agenda o cancela una cita.' },
    { icon: 'smartphone', titulo: 'Sin apps para el cliente', desc: 'Abren tu link desde el navegador y agendan en segundos. Cero fricción.' }
  ];

  const pasos = [
    { n: 1, titulo: 'Crea tu cuenta', desc: 'Regístrate con tu nombre y WhatsApp. En menos de 2 minutos tu cuenta está lista.' },
    { n: 2, titulo: 'Configura todo', desc: 'Define tus horarios de atención y, si quieres, tus cuentas, presupuestos y metas.' },
    { n: 3, titulo: 'Comparte y crece', desc: 'Comparte tu link, recibe citas y mira cómo tu agenda y tus finanzas se ordenan solas.' }
  ];

  const beneficios = [
    'Gratis para empezar, sin tarjeta de crédito',
    'Recordatorios automáticos por WhatsApp',
    'Tus citas y tu dinero en un mismo lugar',
    'Funciona en cualquier celular o computador',
    'Tus datos protegidos y privados',
    'Listo para usar en minutos'
  ];

  const profesiones = [
    { emoji: '💈', titulo: 'Barberos' }, { emoji: '💇‍♀️', titulo: 'Estilistas' },
    { emoji: '🩺', titulo: 'Médicos' }, { emoji: '🦷', titulo: 'Odontólogos' },
    { emoji: '⚖️', titulo: 'Abogados' }, { emoji: '🧠', titulo: 'Psicólogos' },
    { emoji: '💪', titulo: 'Entrenadores' }, { emoji: '💅', titulo: 'Manicuristas' }
  ];

  // NOTA: testimonios de ejemplo — reemplazar por reseñas reales.
  const testimonios = [
    { texto: 'Antes perdía citas por olvidos. Ahora mis clientes confirman por WhatsApp y mi agenda está siempre llena.', nombre: 'Laura M.', rol: 'Estilista · Medellín', emoji: '💇‍♀️' },
    { texto: 'Lo mejor es tener mis citas y mis finanzas en el mismo lugar. Por fin sé cuánto gano cada mes.', nombre: 'Andrés P.', rol: 'Barbero · Bogotá', emoji: '💈' },
    { texto: 'Mis pacientes agendan solos desde el link. Me ahorro horas de mensajes cada semana.', nombre: 'Dra. Carolina R.', rol: 'Odontóloga · Cali', emoji: '🦷' }
  ];

  const faqs = [
    { q: '¿Agendaservi es gratis?', a: 'Sí. Puedes crear tu cuenta, configurar tu agenda y empezar a recibir citas sin ningún costo ni cargos ocultos.' },
    { q: '¿Mis clientes necesitan descargar una app?', a: 'No. Solo abren tu link desde cualquier navegador, en celular o computador. No crean cuentas ni instalan nada.' },
    { q: '¿Cómo funciona la confirmación por WhatsApp?', a: 'Cuando un cliente agenda, recibe un código por WhatsApp para confirmar. Así evitas citas falsas y tú recibes el aviso al instante.' },
    { q: '¿Qué pasa si un cliente cancela?', a: 'Puede cancelar desde un link en su confirmación. El horario vuelve a quedar disponible automáticamente y tú recibes la notificación.' },
    { q: '¿También sirve para mis finanzas personales?', a: 'Sí. Además de la agenda, tienes control de cuentas, presupuestos, metas de ahorro, hábitos y un calendario inteligente con recordatorios.' },
    { q: '¿Puedo personalizar mi link?', a: 'Claro. Se genera un link con tu nombre y puedes personalizarlo desde tu panel para que sea fácil de recordar y compartir.' }
  ];
</script>

<div class="lp">
  <!-- NAV -->
  <nav class="nav">
    <div class="nav-inner">
      <a class="brand" href="/" on:click|preventDefault={() => go('/')} aria-label="Agendaservi inicio">
        <img src="/logo22.png" alt="Agendaservi" class="brand-logo" />
      </a>
      <div class="nav-links">
        <a href="#modulos" class="nav-link">Tu vida organizada</a>
        <a href="#funcionalidades" class="nav-link">Agendamiento</a>
        <a href="#como-funciona" class="nav-link">Cómo funciona</a>
        <a href="#faq" class="nav-link">FAQ</a>
        <button class="btn-ghost" on:click={() => go('/login')}>Iniciar sesión</button>
        <button class="btn-solid sm" on:click={() => go('/login')}>Crear cuenta</button>
      </div>
      <button class="menu-btn" on:click={() => (mobileOpen = !mobileOpen)} aria-label="Menú">
        <i class="material-icons">{mobileOpen ? 'close' : 'menu'}</i>
      </button>
    </div>
    {#if mobileOpen}
      <div class="mobile-nav">
        <a href="#modulos" on:click={() => (mobileOpen = false)}>Tu vida organizada</a>
        <a href="#funcionalidades" on:click={() => (mobileOpen = false)}>Agendamiento</a>
        <a href="#como-funciona" on:click={() => (mobileOpen = false)}>Cómo funciona</a>
        <a href="#faq" on:click={() => (mobileOpen = false)}>FAQ</a>
        <button class="btn-solid full" on:click={() => go('/login')}>Crear cuenta gratis</button>
      </div>
    {/if}
  </nav>

  <!-- HERO -->
  <header class="hero">
    <div class="orb orb-1"></div>
    <div class="orb orb-2"></div>
    <div class="hero-inner">
      <div class="hero-text">
        <span class="pill"><span class="dot"></span> Agenda · Finanzas · Bienestar</span>
        <h1>Tu agenda y tu dinero, <span class="hl">ordenados en un solo lugar</span></h1>
        <p class="subtitle">
          Recibe citas con confirmación automática por WhatsApp y, de paso, controla tus finanzas,
          tu salud y tus hábitos. Todo desde una sola plataforma. <strong>Gratis.</strong>
        </p>
        <div class="hero-actions">
          <button class="btn-solid lg" on:click={() => go('/login')}>
            <i class="material-icons">rocket_launch</i> Crear mi cuenta gratis
          </button>
          <a class="btn-outline lg" href="#como-funciona">
            <i class="material-icons">play_circle</i> Ver cómo funciona
          </a>
        </div>
        <div class="trust">
          <span><i class="material-icons">check_circle</i> Sin tarjeta de crédito</span>
          <span><i class="material-icons">check_circle</i> Listo en 2 minutos</span>
        </div>
      </div>

      <div class="hero-visual">
        <!-- Tarjeta de agenda -->
        <div class="float-card agenda-card">
          <div class="fc-head"><i class="material-icons">event_available</i> Agendar cita</div>
          <div class="slot"><span>8:00 AM</span><span class="ok">Disponible</span></div>
          <div class="slot busy"><span>9:00 AM</span><span>Ocupado</span></div>
          <div class="slot sel"><span>10:00 AM</span><span>✓ Tu cita</span></div>
          <div class="fc-btn">Confirmar por WhatsApp</div>
        </div>
        <!-- Tarjeta de finanzas -->
        <div class="float-card finance-card">
          <div class="fc-head fin"><i class="material-icons">trending_up</i> Resumen del mes</div>
          <div class="fin-row"><span>Ingresos</span><span class="up">+ $4.200.000</span></div>
          <div class="fin-row"><span>Gastos</span><span class="down">− $2.650.000</span></div>
          <div class="bar"><div class="bar-fill"></div></div>
          <div class="fin-balance"><span>Balance</span><strong>$1.550.000</strong></div>
        </div>
      </div>
    </div>
  </header>

  <!-- STATS -->
  <div class="stats">
    <div class="stats-inner">
      <div class="stat"><div class="num">100%</div><div class="lbl">Gratis para empezar</div></div>
      <div class="stat"><div class="num">💬</div><div class="lbl">Confirmación por WhatsApp</div></div>
      <div class="stat"><div class="num">24/7</div><div class="lbl">Agenda siempre abierta</div></div>
      <div class="stat"><div class="num">~30s</div><div class="lbl">Para agendar una cita</div></div>
    </div>
  </div>

  <!-- MÓDULOS -->
  <section class="section" id="modulos">
    <div class="sec-head fade" use:inview>
      <span class="badge">Tu vida organizada</span>
      <h2>Mucho más que una agenda de citas</h2>
      <p>Una sola plataforma para tus citas, tu dinero, tu salud y tus rutinas.</p>
    </div>
    <div class="grid grid-4">
      {#each modulos as m}
        <article class="card fade" use:inview>
          <div class="card-icon {m.color}"><i class="material-icons">{m.icon}</i></div>
          <h3>{m.titulo}</h3>
          <p>{m.desc}</p>
        </article>
      {/each}
    </div>
  </section>

  <!-- FUNCIONALIDADES -->
  <section class="section alt" id="funcionalidades">
    <div class="sec-head fade" use:inview>
      <span class="badge blue">Agendamiento</span>
      <h2>Todo para gestionar tus citas como un profesional</h2>
      <p>Herramientas pensadas para que ahorres tiempo y no pierdas ni una reserva.</p>
    </div>
    <div class="grid grid-3">
      {#each features as f}
        <article class="card fade" use:inview>
          <div class="card-icon green"><i class="material-icons">{f.icon}</i></div>
          <h3>{f.titulo}</h3>
          <p>{f.desc}</p>
        </article>
      {/each}
    </div>
  </section>

  <!-- CÓMO FUNCIONA -->
  <section class="section" id="como-funciona">
    <div class="sec-head fade" use:inview>
      <span class="badge">Cómo funciona</span>
      <h2>Empieza en 3 pasos simples</h2>
      <p>Configúralo en minutos y deja que la plataforma trabaje por ti.</p>
    </div>
    <div class="grid grid-3 steps">
      {#each pasos as p}
        <div class="step fade" use:inview>
          <div class="step-n">{p.n}</div>
          <h3>{p.titulo}</h3>
          <p>{p.desc}</p>
        </div>
      {/each}
    </div>
  </section>

  <!-- BENEFICIOS -->
  <section class="section alt">
    <div class="benefits">
      <div class="benefits-text fade" use:inview>
        <span class="badge blue">Por qué Agendaservi</span>
        <h2>Diseñado para profesionales independientes</h2>
        <p>Sin complicaciones, sin costos ocultos y sin curva de aprendizaje. Lo que necesitas para crecer, en un solo lugar.</p>
        <ul class="check-list">
          {#each beneficios as b}
            <li><i class="material-icons">check_circle</i> {b}</li>
          {/each}
        </ul>
        <button class="btn-solid" on:click={() => go('/login')}>
          <i class="material-icons">bolt</i> Empezar ahora
        </button>
      </div>
      <div class="benefits-visual fade" use:inview>
        <div class="glass-stat"><div class="gs-num">+30 min</div><div class="gs-lbl">de aviso antes de cada cita</div></div>
        <div class="glass-stat"><div class="gs-num">1 link</div><div class="gs-lbl">para todas tus reservas</div></div>
        <div class="glass-stat"><div class="gs-num">$0</div><div class="gs-lbl">para comenzar hoy</div></div>
      </div>
    </div>
  </section>

  <!-- PROFESIONES -->
  <section class="section" id="profesiones">
    <div class="sec-head fade" use:inview>
      <span class="badge">Para todos los profesionales</span>
      <h2>¿Quiénes usan Agendaservi?</h2>
      <p>Si trabajas con citas, Agendaservi es para ti.</p>
    </div>
    <div class="grid grid-4">
      {#each profesiones as p}
        <article class="prof fade" use:inview>
          <div class="prof-emoji">{p.emoji}</div>
          <h3>{p.titulo}</h3>
        </article>
      {/each}
    </div>
  </section>

  <!-- TESTIMONIOS -->
  <section class="section alt">
    <div class="sec-head fade" use:inview>
      <span class="badge blue">Testimonios</span>
      <h2>Lo que dicen quienes ya lo usan</h2>
    </div>
    <div class="grid grid-3">
      {#each testimonios as t}
        <article class="quote fade" use:inview>
          <div class="stars">★★★★★</div>
          <p class="quote-text">"{t.texto}"</p>
          <div class="quote-author">
            <span class="qa-emoji">{t.emoji}</span>
            <div><strong>{t.nombre}</strong><span>{t.rol}</span></div>
          </div>
        </article>
      {/each}
    </div>
  </section>

  <!-- FAQ -->
  <section class="section" id="faq">
    <div class="sec-head fade" use:inview>
      <span class="badge">Preguntas frecuentes</span>
      <h2>Resolvemos tus dudas</h2>
    </div>
    <div class="faq">
      {#each faqs as f, i}
        <div class="faq-item {openFaq === i ? 'open' : ''}">
          <button class="faq-q" on:click={() => toggleFaq(i)} aria-expanded={openFaq === i}>
            <span>{f.q}</span>
            <i class="material-icons">{openFaq === i ? 'remove' : 'add'}</i>
          </button>
          {#if openFaq === i}
            <div class="faq-a">{f.a}</div>
          {/if}
        </div>
      {/each}
    </div>
  </section>

  <!-- CTA -->
  <section class="cta">
    <div class="cta-card fade" use:inview>
      <h2>Empieza a organizar tu agenda y tu vida hoy</h2>
      <p>Crea tu cuenta gratis en 2 minutos. Sin tarjeta, sin compromisos.</p>
      <button class="btn-solid lg" on:click={() => go('/login')}>
        <i class="material-icons">person_add</i> Crear mi cuenta gratis
      </button>
    </div>
  </section>

  <!-- FOOTER -->
  <footer class="footer">
    <div class="footer-inner">
      <div class="footer-brand">
        <img src="/logo22.png" alt="Agendaservi" class="footer-logo" />
        <p>Agenda de citas online + suite personal de calendario, finanzas, salud y hábitos. Simplifica tu gestión y mejora la experiencia de tus clientes.</p>
      </div>
      <div class="footer-col">
        <h4>Plataforma</h4>
        <ul>
          <li><a href="#modulos">Tu vida organizada</a></li>
          <li><a href="#funcionalidades">Agendamiento</a></li>
          <li><a href="#como-funciona">Cómo funciona</a></li>
          <li><a href="#faq">Preguntas frecuentes</a></li>
        </ul>
      </div>
      <div class="footer-col">
        <h4>Cuenta</h4>
        <ul>
          <li><a href="/login" on:click|preventDefault={() => go('/login')}>Iniciar sesión</a></li>
          <li><a href="/login" on:click|preventDefault={() => go('/login')}>Crear cuenta</a></li>
        </ul>
      </div>
      <div class="footer-col">
        <h4>Contacto</h4>
        <ul>
          <li><a href={WHATSAPP_URL} target="_blank" rel="noopener" class="wa-link"><i class="material-icons">chat</i> WhatsApp</a></li>
        </ul>
      </div>
    </div>
    <div class="footer-bottom">© {year} Agendaservi. Todos los derechos reservados.</div>
  </footer>

  <!-- Botón flotante de WhatsApp -->
  <a class="wa-fab" href={WHATSAPP_URL} target="_blank" rel="noopener" aria-label="Escríbenos por WhatsApp">
    <svg viewBox="0 0 32 32" width="30" height="30" fill="currentColor" aria-hidden="true">
      <path d="M16.04 3C9.4 3 4 8.4 4 15.04c0 2.12.55 4.18 1.6 6L4 29l8.16-1.56a12 12 0 0 0 3.88.64h.01C22.69 28.08 28.08 22.69 28.08 16.05 28.08 8.4 22.68 3 16.04 3zm0 22.04c-1.2 0-2.38-.2-3.5-.6l-.25-.1-4.84.93.97-4.72-.16-.25a9.94 9.94 0 0 1-1.53-5.26c0-5.5 4.48-9.97 10-9.97 2.66 0 5.16 1.04 7.04 2.92a9.9 9.9 0 0 1 2.92 7.05c0 5.5-4.48 9.96-9.97 9.96zm5.46-7.46c-.3-.15-1.77-.87-2.04-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.02-.52-.07-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51l-.57-.01c-.2 0-.52.07-.79.37-.27.3-1.04 1.01-1.04 2.47s1.06 2.87 1.21 3.07c.15.2 2.1 3.2 5.08 4.49.71.31 1.26.49 1.69.62.71.23 1.36.2 1.87.12.57-.08 1.77-.72 2.02-1.42.25-.7.25-1.3.17-1.42-.07-.13-.27-.2-.57-.35z"/>
    </svg>
    <span class="wa-tip">¿Dudas? Escríbenos</span>
  </a>
</div>

<style>
  .lp {
    --bg: #0B141A;
    --bg2: #0f1c24;
    --card: rgba(255, 255, 255, 0.035);
    --border: rgba(255, 255, 255, 0.09);
    --text: #EAF0F2;
    --muted: #8A9BA8;
    --green: #22C55E;
    --blue: #3B82F6;
    --pink: #EC4899;
    --amber: #F59E0B;
    font-family: 'Inter', system-ui, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    overflow-x: hidden;
    scroll-behavior: smooth;
  }
  .lp :global(*) { box-sizing: border-box; }
  .lp a { color: inherit; text-decoration: none; }

  /* BUTTONS */
  .btn-solid, .btn-outline, .btn-ghost {
    display: inline-flex; align-items: center; gap: 8px; cursor: pointer;
    font-family: inherit; font-weight: 700; border-radius: 12px; transition: transform .15s, box-shadow .2s, background .2s;
    border: none; font-size: 0.95rem; padding: 12px 20px;
  }
  .btn-solid { background: linear-gradient(135deg, var(--green), #16a34a); color: #04210f; }
  .btn-solid:hover { transform: translateY(-2px); box-shadow: 0 10px 30px rgba(34, 197, 94, 0.4); }
  .btn-solid.lg { padding: 15px 26px; font-size: 1.02rem; }
  .btn-solid.sm { padding: 9px 16px; font-size: 0.88rem; }
  .btn-solid.full { width: 100%; justify-content: center; margin-top: 6px; }
  .btn-outline { background: transparent; color: var(--text); border: 1px solid var(--border); }
  .btn-outline:hover { background: rgba(255, 255, 255, 0.05); }
  .btn-outline.lg { padding: 15px 24px; font-size: 1.02rem; }
  .btn-ghost { background: transparent; color: var(--muted); padding: 9px 12px; }
  .btn-ghost:hover { color: var(--text); }

  /* NAV */
  .nav { position: sticky; top: 0; z-index: 100; background: rgba(11, 20, 26, 0.82); backdrop-filter: blur(14px); border-bottom: 1px solid var(--border); }
  .nav-inner { max-width: 1180px; margin: 0 auto; padding: 10px 20px; display: flex; align-items: center; justify-content: space-between; }
  .brand { display: flex; align-items: center; }
  .brand-logo { height: 46px; width: auto; object-fit: contain; }
  .nav-links { display: flex; align-items: center; gap: 22px; }
  .nav-link { color: var(--muted); font-weight: 500; font-size: 0.92rem; transition: color .2s; }
  .nav-link:hover { color: var(--text); }
  .menu-btn { display: none; background: none; border: none; color: var(--text); cursor: pointer; }
  .mobile-nav { display: flex; flex-direction: column; gap: 14px; padding: 16px 20px 22px; border-top: 1px solid var(--border); }
  .mobile-nav a { color: var(--muted); font-weight: 500; }

  /* HERO */
  .hero { position: relative; padding: 72px 20px 48px; overflow: hidden; }
  .orb { position: absolute; border-radius: 50%; filter: blur(90px); opacity: 0.5; pointer-events: none; }
  .orb-1 { width: 460px; height: 460px; background: rgba(34, 197, 94, 0.22); top: -120px; right: -80px; }
  .orb-2 { width: 420px; height: 420px; background: rgba(59, 130, 246, 0.18); bottom: -160px; left: -100px; }
  .hero-inner { position: relative; max-width: 1180px; margin: 0 auto; display: grid; grid-template-columns: 1.05fr 0.95fr; gap: 48px; align-items: center; }
  .pill { display: inline-flex; align-items: center; gap: 8px; padding: 7px 14px; border-radius: 99px; background: rgba(34, 197, 94, 0.1); border: 1px solid rgba(34, 197, 94, 0.3); color: var(--green); font-weight: 600; font-size: 0.78rem; margin-bottom: 20px; }
  .pill .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--green); box-shadow: 0 0 0 4px rgba(34, 197, 94, 0.2); }
  .hero-text h1 { font-size: clamp(2.1rem, 5vw, 3.5rem); line-height: 1.06; font-weight: 900; margin: 0 0 18px; letter-spacing: -0.02em; }
  .hl { background: linear-gradient(120deg, var(--green), var(--blue)); -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent; }
  .subtitle { color: var(--muted); font-size: 1.08rem; line-height: 1.6; max-width: 540px; margin: 0 0 28px; }
  .subtitle strong { color: var(--text); }
  .hero-actions { display: flex; gap: 14px; flex-wrap: wrap; }
  .trust { display: flex; gap: 20px; margin-top: 22px; flex-wrap: wrap; }
  .trust span { display: inline-flex; align-items: center; gap: 6px; color: var(--muted); font-size: 0.86rem; }
  .trust i { color: var(--green); font-size: 18px; }

  /* HERO VISUAL */
  .hero-visual { position: relative; min-height: 360px; display: flex; align-items: center; justify-content: center; }
  .float-card { position: absolute; background: linear-gradient(160deg, #16242c, #101e26); border: 1px solid var(--border); border-radius: 18px; padding: 18px; box-shadow: 0 30px 70px rgba(0, 0, 0, 0.5); width: 300px; }
  .agenda-card { transform: translate(-46px, -54px) rotate(-3deg); z-index: 2; animation: floaty 6s ease-in-out infinite; }
  .finance-card { transform: translate(58px, 78px) rotate(3deg); z-index: 1; width: 280px; animation: floaty 6s ease-in-out infinite 1.2s; }
  @keyframes floaty { 0%,100% { margin-top: 0; } 50% { margin-top: -12px; } }
  .fc-head { display: flex; align-items: center; gap: 8px; font-weight: 700; margin-bottom: 14px; color: var(--green); }
  .fc-head.fin { color: var(--blue); }
  .fc-head i { font-size: 20px; }
  .slot { display: flex; justify-content: space-between; align-items: center; padding: 11px 13px; border-radius: 10px; background: rgba(255, 255, 255, 0.03); border: 1px solid var(--border); font-size: 0.85rem; margin-bottom: 8px; }
  .slot .ok { color: var(--green); }
  .slot.busy span:last-child { color: #EF4444; }
  .slot.sel { background: rgba(34, 197, 94, 0.14); border-color: var(--green); color: #fff; }
  .fc-btn { margin-top: 6px; text-align: center; background: var(--green); color: #04210f; padding: 11px; border-radius: 10px; font-weight: 700; font-size: 0.88rem; }
  .fin-row { display: flex; justify-content: space-between; font-size: 0.88rem; margin-bottom: 10px; color: var(--muted); }
  .fin-row .up { color: var(--green); font-weight: 700; }
  .fin-row .down { color: #EF4444; font-weight: 700; }
  .bar { height: 8px; border-radius: 99px; background: rgba(255, 255, 255, 0.08); overflow: hidden; margin: 4px 0 12px; }
  .bar-fill { height: 100%; width: 63%; border-radius: 99px; background: linear-gradient(90deg, var(--blue), var(--green)); }
  .fin-balance { display: flex; justify-content: space-between; align-items: center; font-size: 0.9rem; color: var(--muted); }
  .fin-balance strong { color: var(--text); font-size: 1.1rem; }

  /* STATS */
  .stats { border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); background: var(--bg2); }
  .stats-inner { max-width: 1180px; margin: 0 auto; padding: 28px 20px; display: grid; grid-template-columns: repeat(4, 1fr); gap: 18px; }
  .stat { text-align: center; }
  .num { font-size: 1.9rem; font-weight: 900; background: linear-gradient(120deg, var(--green), var(--blue)); -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent; }
  .lbl { color: var(--muted); font-size: 0.82rem; margin-top: 4px; }

  /* SECTIONS */
  .section { max-width: 1180px; margin: 0 auto; padding: 84px 20px; }
  .section.alt { max-width: 100%; background: var(--bg2); border-top: 1px solid var(--border); border-bottom: 1px solid var(--border); }
  .section.alt > *:not(.benefits) { max-width: 1180px; margin-left: auto; margin-right: auto; }
  .sec-head { text-align: center; max-width: 660px; margin: 0 auto 48px; }
  .badge { display: inline-block; padding: 6px 14px; border-radius: 99px; font-size: 0.76rem; font-weight: 700; background: rgba(34, 197, 94, 0.1); border: 1px solid rgba(34, 197, 94, 0.3); color: var(--green); margin-bottom: 14px; }
  .badge.blue { background: rgba(59, 130, 246, 0.12); border-color: rgba(59, 130, 246, 0.32); color: var(--blue); }
  .sec-head h2 { font-size: clamp(1.7rem, 3.6vw, 2.4rem); font-weight: 800; margin: 0 0 12px; letter-spacing: -0.01em; }
  .sec-head p { color: var(--muted); font-size: 1.04rem; line-height: 1.6; margin: 0; }

  .grid { display: grid; gap: 20px; }
  .grid-3 { grid-template-columns: repeat(3, 1fr); }
  .grid-4 { grid-template-columns: repeat(4, 1fr); }

  .card { background: var(--card); border: 1px solid var(--border); border-radius: 18px; padding: 26px; transition: transform .2s, border-color .2s, box-shadow .2s; }
  .card:hover { transform: translateY(-5px); border-color: rgba(34, 197, 94, 0.4); box-shadow: 0 16px 44px rgba(0, 0, 0, 0.38); }
  .card-icon { width: 54px; height: 54px; border-radius: 15px; display: flex; align-items: center; justify-content: center; margin-bottom: 16px; }
  .card-icon i { font-size: 27px; }
  .card-icon.green { background: rgba(34, 197, 94, 0.13); border: 1px solid rgba(34, 197, 94, 0.3); }
  .card-icon.green i { color: var(--green); }
  .card-icon.blue { background: rgba(59, 130, 246, 0.13); border: 1px solid rgba(59, 130, 246, 0.3); }
  .card-icon.blue i { color: var(--blue); }
  .card-icon.pink { background: rgba(236, 72, 153, 0.13); border: 1px solid rgba(236, 72, 153, 0.3); }
  .card-icon.pink i { color: var(--pink); }
  .card-icon.amber { background: rgba(245, 158, 11, 0.13); border: 1px solid rgba(245, 158, 11, 0.3); }
  .card-icon.amber i { color: var(--amber); }
  .card h3 { margin: 0 0 8px; font-size: 1.12rem; font-weight: 700; }
  .card p { margin: 0; color: var(--muted); font-size: 0.92rem; line-height: 1.55; }

  /* STEPS */
  .steps .step { text-align: center; padding: 26px; position: relative; }
  .step-n { width: 56px; height: 56px; margin: 0 auto 16px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 900; font-size: 1.4rem; background: linear-gradient(135deg, var(--green), var(--blue)); color: #04210f; }
  .step h3 { margin: 0 0 8px; font-size: 1.12rem; }
  .step p { color: var(--muted); font-size: 0.92rem; line-height: 1.55; margin: 0; }

  /* BENEFITS */
  .benefits { max-width: 1180px; margin: 0 auto; display: grid; grid-template-columns: 1.1fr 0.9fr; gap: 50px; align-items: center; }
  .benefits-text h2 { font-size: clamp(1.7rem, 3.4vw, 2.3rem); font-weight: 800; margin: 12px 0; }
  .benefits-text > p { color: var(--muted); font-size: 1.02rem; line-height: 1.6; margin: 0 0 22px; }
  .check-list { list-style: none; padding: 0; margin: 0 0 26px; display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
  .check-list li { display: flex; align-items: center; gap: 8px; font-size: 0.92rem; color: var(--text); }
  .check-list i { color: var(--green); font-size: 19px; }
  .benefits-visual { display: flex; flex-direction: column; gap: 16px; }
  .glass-stat { background: linear-gradient(135deg, rgba(34, 197, 94, 0.1), rgba(59, 130, 246, 0.08)); border: 1px solid var(--border); border-radius: 16px; padding: 22px 24px; }
  .gs-num { font-size: 1.8rem; font-weight: 900; background: linear-gradient(120deg, var(--green), var(--blue)); -webkit-background-clip: text; background-clip: text; -webkit-text-fill-color: transparent; }
  .gs-lbl { color: var(--muted); font-size: 0.9rem; margin-top: 2px; }

  /* PROFESSIONS */
  .prof { text-align: center; background: var(--card); border: 1px solid var(--border); border-radius: 14px; padding: 26px 14px; transition: transform .2s, border-color .2s; }
  .prof:hover { transform: translateY(-4px); border-color: rgba(59, 130, 246, 0.4); }
  .prof-emoji { font-size: 2.3rem; margin-bottom: 8px; }
  .prof h3 { margin: 0; font-size: 1rem; }

  /* TESTIMONIALS */
  .quote { background: var(--card); border: 1px solid var(--border); border-radius: 18px; padding: 26px; display: flex; flex-direction: column; gap: 14px; }
  .stars { color: #F5B301; letter-spacing: 2px; font-size: 0.95rem; }
  .quote-text { margin: 0; font-size: 0.98rem; line-height: 1.6; color: var(--text); flex: 1; }
  .quote-author { display: flex; align-items: center; gap: 12px; }
  .qa-emoji { width: 42px; height: 42px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1.3rem; background: rgba(255, 255, 255, 0.05); border: 1px solid var(--border); }
  .quote-author strong { display: block; font-size: 0.92rem; }
  .quote-author span { color: var(--muted); font-size: 0.8rem; }

  /* FAQ */
  .faq { max-width: 780px; margin: 0 auto; display: flex; flex-direction: column; gap: 12px; }
  .faq-item { background: var(--card); border: 1px solid var(--border); border-radius: 14px; overflow: hidden; transition: border-color .2s; }
  .faq-item.open { border-color: rgba(34, 197, 94, 0.4); }
  .faq-q { width: 100%; display: flex; align-items: center; justify-content: space-between; gap: 12px; background: none; border: none; color: var(--text); cursor: pointer; padding: 19px 22px; font-size: 1.02rem; font-weight: 600; text-align: left; font-family: inherit; }
  .faq-q i { color: var(--green); }
  .faq-a { padding: 0 22px 20px; color: var(--muted); line-height: 1.65; font-size: 0.96rem; }

  /* CTA */
  .cta { padding: 90px 20px; }
  .cta-card { max-width: 880px; margin: 0 auto; text-align: center; padding: 56px 30px; border-radius: 26px; background: linear-gradient(135deg, rgba(34, 197, 94, 0.14), rgba(59, 130, 246, 0.12)); border: 1px solid var(--border); position: relative; overflow: hidden; }
  .cta-card h2 { font-size: clamp(1.7rem, 3.6vw, 2.4rem); font-weight: 800; margin: 0 0 12px; }
  .cta-card p { color: var(--muted); font-size: 1.06rem; margin: 0 0 28px; }

  /* FOOTER */
  .footer { background: var(--bg2); border-top: 1px solid var(--border); }
  .footer-inner { max-width: 1180px; margin: 0 auto; padding: 52px 20px 30px; display: grid; grid-template-columns: 2fr 1fr 1fr 1fr; gap: 34px; }
  .wa-link { display: inline-flex; align-items: center; gap: 6px; }
  .wa-link i { font-size: 18px; color: #25D366; }
  .footer-logo { height: 50px; width: auto; object-fit: contain; margin-bottom: 12px; }
  .footer-brand p { color: var(--muted); font-size: 0.9rem; line-height: 1.6; max-width: 380px; }
  .footer-col h4 { margin: 0 0 14px; font-size: 0.95rem; }
  .footer-col ul { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 10px; }
  .footer-col a { color: var(--muted); font-size: 0.9rem; transition: color .2s; }
  .footer-col a:hover { color: var(--text); }
  .footer-bottom { text-align: center; padding: 20px; border-top: 1px solid var(--border); color: var(--muted); font-size: 0.84rem; }

  /* WHATSAPP FAB */
  .wa-fab {
    position: fixed; right: 22px; bottom: 22px; z-index: 200;
    display: inline-flex; align-items: center; gap: 0;
    background: #25D366; color: #fff; border-radius: 999px;
    width: 60px; height: 60px; justify-content: center;
    box-shadow: 0 10px 30px rgba(37, 211, 102, 0.45);
    transition: width .3s ease, transform .15s ease, box-shadow .2s ease; overflow: hidden;
  }
  .wa-fab:hover { transform: translateY(-2px); width: 220px; gap: 10px; box-shadow: 0 14px 38px rgba(37, 211, 102, 0.55); }
  .wa-fab svg { flex-shrink: 0; }
  .wa-tip { white-space: nowrap; max-width: 0; opacity: 0; font-weight: 700; font-size: 0.92rem; transition: max-width .3s ease, opacity .2s ease; }
  .wa-fab:hover .wa-tip { max-width: 160px; opacity: 1; }
  .wa-fab::after {
    content: ''; position: absolute; inset: 0; border-radius: 999px;
    box-shadow: 0 0 0 0 rgba(37, 211, 102, 0.5); animation: waPulse 2.4s ease-out infinite;
  }
  @keyframes waPulse { 0% { box-shadow: 0 0 0 0 rgba(37, 211, 102, 0.5); } 70% { box-shadow: 0 0 0 16px rgba(37, 211, 102, 0); } 100% { box-shadow: 0 0 0 0 rgba(37, 211, 102, 0); } }

  /* FADE-IN */
  .fade { opacity: 0; transform: translateY(22px); transition: opacity .6s ease, transform .6s ease; }
  .fade:global(.visible) { opacity: 1; transform: none; }

  /* RESPONSIVE */
  @media (max-width: 920px) {
    .nav-links { display: none; }
    .menu-btn { display: flex; }
    .hero-inner { grid-template-columns: 1fr; text-align: center; }
    .subtitle { margin-left: auto; margin-right: auto; }
    .hero-actions, .trust { justify-content: center; }
    .hero-visual { min-height: 440px; margin-top: 20px; }
    .benefits { grid-template-columns: 1fr; gap: 30px; }
    .grid-3, .grid-4 { grid-template-columns: repeat(2, 1fr); }
    .footer-inner { grid-template-columns: 1fr; }
  }
  @media (max-width: 560px) {
    .stats-inner { grid-template-columns: repeat(2, 1fr); }
    .grid-3, .grid-4 { grid-template-columns: 1fr; }
    .check-list { grid-template-columns: 1fr; }
    .float-card { width: 270px; }
    .agenda-card { transform: translate(0, -90px) rotate(-2deg); }
    .finance-card { transform: translate(0, 90px) rotate(2deg); }
  }
</style>
