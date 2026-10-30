import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/dates.dart';
import '../../core/money.dart';
import '../../core/motion.dart';
import '../../core/session.dart';
import '../../core/widgets/ui.dart';
import '../auth/auth_widgets.dart' show OtpField, OtpFieldState, WhatsAppField, indicativos;
import 'citas_models.dart';
import 'citas_repository.dart';
import '../../core/widgets/sheets.dart';
import 'widgets/config_sheets.dart' show duracionTexto;

enum _Paso { servicio, profesional, horario, datos, codigo, listo }

/// Reservar una cita desde la app (enlace `agendaservi.com/agenda/<slug>`).
/// Mismo flujo que la página web, con los datos del usuario ya llenos.
class ReservarScreen extends ConsumerStatefulWidget {
  const ReservarScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ReservarScreen> createState() => _ReservarScreenState();
}

class _ReservarScreenState extends ConsumerState<ReservarScreen> {
  PaginaAgenda? _pagina;
  String? _error;
  _Paso _paso = _Paso.servicio;
  bool _adelante = true;

  ServicioAgenda? _servicio;
  int _profesional = 0;
  final _dias = <DiaTurnos>[];
  bool _cargandoDias = false;
  bool _sinMas = false;
  String? _fecha;
  String? _hora;

  final _nombre = TextEditingController();
  final _numero = TextEditingController();
  final _nota = TextEditingController();
  String _indicativo = '57';
  bool _enviando = false;
  String? _errorForm;

  ReservaPublica? _reserva;
  String? _errorCodigo;
  bool _confirmando = false;
  int _segundos = 0;
  int _esperaReenvio = 0;
  Timer? _reloj;
  final _otp = GlobalKey<OtpFieldState>();

  @override
  void initState() {
    super.initState();
    final u = ref.read(sesionProvider).value?.usuario;
    if (u != null) {
      _nombre.text = u.nombre;
      final wa = u.whatsapp.replaceAll(RegExp(r'\D'), '');
      final ind = indicativos.map((i) => i.$1).where(wa.startsWith).fold<String?>(null, (m, i) => m == null || i.length > m.length ? i : m);
      if (ind != null && wa.length > ind.length + 6) {
        _indicativo = ind;
        _numero.text = wa.substring(ind.length);
      }
    }
    _cargar();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || (_segundos == 0 && _esperaReenvio == 0)) return;
      setState(() {
        if (_segundos > 0) _segundos--;
        if (_esperaReenvio > 0) _esperaReenvio--;
      });
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    for (final c in [_nombre, _numero, _nota]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final p = await ref.read(agendaRepoProvider).pagina(widget.slug);
      if (!mounted) return;
      setState(() => _pagina = p);
      if (p.servicios.length == 1) _elegirServicio(p.servicios.first);
    } on AgendaError catch (e) {
      if (mounted) setState(() => _error = e.status == 404 ? 'Esta página de citas no existe o está pausada.' : e.mensaje);
    }
  }

  List<_Paso> get _pasos => [
        if ((_pagina?.servicios.length ?? 0) > 1) _Paso.servicio,
        if (_equipo.length > 1) _Paso.profesional,
        _Paso.horario,
        _Paso.datos,
      ];

  List<ProfesionalAgenda> get _equipo =>
      _servicio == null || _pagina == null ? const [] : [for (final p in _pagina!.profesionales) if (_servicio!.profesionales.contains(p.id)) p];

  void _ir(_Paso p) {
    HapticFeedback.selectionClick();
    setState(() {
      _adelante = p.index >= _paso.index;
      _paso = p;
    });
  }

  void _atras() {
    if (_paso == _Paso.codigo) return _ir(_Paso.datos);
    final i = _pasos.indexOf(_paso);
    if (i > 0 && _paso != _Paso.listo) {
      _ir(_pasos[i - 1]);
    } else {
      context.canPop() ? context.pop() : context.go('/hoy');
    }
  }

  void _elegirServicio(ServicioAgenda s) {
    setState(() {
      _servicio = s;
      _profesional = 0;
    });
    if (_equipo.length > 1) {
      _ir(_Paso.profesional);
    } else {
      _profesional = _equipo.firstOrNull?.id ?? 0;
      _reiniciarDias();
      _ir(_Paso.horario);
    }
  }

  void _elegirProfesional(int id) {
    setState(() => _profesional = id);
    _reiniciarDias();
    _ir(_Paso.horario);
  }

  void _reiniciarDias() {
    _dias.clear();
    _fecha = null;
    _hora = null;
    _sinMas = false;
    _cargarDias();
  }

  Future<void> _cargarDias() async {
    if (_cargandoDias || _sinMas || _servicio == null) return;
    setState(() => _cargandoDias = true);
    final desde = _dias.isEmpty ? hoyYmd() : sumarDiasYmd(_dias.last.fecha, 1);
    try {
      final nuevos = await ref.read(agendaRepoProvider).disponibilidad(widget.slug, servicio: _servicio!.id, profesional: _profesional, desde: desde, dias: 14);
      if (!mounted) return;
      setState(() {
        _dias.addAll(nuevos);
        _sinMas = nuevos.length < 14;
        _fecha ??= _dias.where((d) => d.turnos.isNotEmpty).firstOrNull?.fecha;
      });
      // Si en dos semanas no hay nada, se busca más adelante solo.
      if (_fecha == null && !_sinMas && _dias.length < 42) unawaited(_cargarDias());
    } on AgendaError catch (e) {
      if (mounted) setState(() => _errorForm = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoDias = false);
    }
  }

  Future<void> _reservar() async {
    final numero = _numero.text.replaceAll(RegExp(r'\D'), '');
    if (_nombre.text.trim().length < 2 || numero.length < 7) {
      setState(() => _errorForm = 'Escribe tu nombre y tu WhatsApp');
      return;
    }
    setState(() {
      _enviando = true;
      _errorForm = null;
    });
    try {
      final r = await ref.read(agendaRepoProvider).reservar(widget.slug, {
        'servicio_id': _servicio!.id,
        'profesional_id': _profesional,
        'fecha': _fecha,
        'hora': _hora,
        'nombre': _nombre.text.trim(),
        'whatsapp': '$_indicativo$numero',
        'nota': _nota.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _reserva = r;
        _segundos = r.segundosRestantes;
        _esperaReenvio = 60;
        _errorCodigo = null;
      });
      _ir(_Paso.codigo);
    } on AgendaError catch (e) {
      if (!mounted) return;
      if (e.ocupado) {
        setState(() => _hora = null);
        _reiniciarDias();
        _ir(_Paso.horario);
        toast(context, 'Ese horario se acaba de ocupar. Elige otro, por favor.', error: true);
      } else {
        setState(() => _errorForm = e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmar(String codigo) async {
    if (_reserva == null || _confirmando) return;
    setState(() {
      _confirmando = true;
      _errorCodigo = null;
    });
    try {
      final r = await ref.read(agendaRepoProvider).confirmar(_reserva!.token, codigo);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() => _reserva = r);
      _ir(_Paso.listo);
    } on AgendaError catch (e) {
      if (!mounted) return;
      setState(() => _errorCodigo = e.mensaje);
      if (e.status == 410) setState(() => _segundos = 0);
      _otp.currentState?.limpiar();
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }

  Future<void> _reenviar() async {
    if (_reserva == null) return;
    setState(() => _esperaReenvio = 60);
    try {
      await ref.read(agendaRepoProvider).reenviar(_reserva!.token);
    } on AgendaError catch (e) {
      if (mounted) setState(() => _errorCodigo = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pagina = _pagina;
    final marca = Color(pagina?.color ?? p.accent.toARGB32());
    final tema = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(primary: marca, onPrimary: marca.computeLuminance() > 0.45 ? Colors.black : Colors.white),
    );
    final indice = _pasos.indexOf(_paso);
    return Theme(
      data: tema,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: _paso == _Paso.listo ? null : IconButton(tooltip: 'Atrás', onPressed: _atras, icon: const Icon(Icons.arrow_back_rounded)),
          automaticallyImplyLeading: false,
          title: Text(pagina?.nombre ?? 'Agendar cita', overflow: TextOverflow.ellipsis),
          bottom: indice < 0
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (indice + 1) / _pasos.length),
                    duration: Motion.of(context, Motion.slow),
                    curve: Motion.standard,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: marca, backgroundColor: p.border),
                  ),
                ),
        ),
        bottomNavigationBar: _paso == _Paso.horario && _hora != null && _fecha != null
            ? _BarraContinuar(
                texto: '${fechaCorta(_fecha!)} · ${hora12(_hora)}',
                detalle: _servicio?.nombre ?? '',
                onContinuar: () => _ir(_Paso.datos),
              )
            : null,
        body: SafeArea(
          top: false,
          child: _error != null
              ? EmptyState(icon: Icons.event_busy_rounded, title: 'No disponible', message: _error, actionLabel: 'Volver', onAction: () => context.canPop() ? context.pop() : context.go('/hoy'))
              : pagina == null
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.medium),
                          switchInCurve: Motion.enter,
                          switchOutCurve: Motion.exit,
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(position: Tween(begin: Offset(_adelante ? 0.06 : -0.06, 0), end: Offset.zero).animate(a), child: child),
                          ),
                          child: KeyedSubtree(key: ValueKey(_paso), child: _contenido(context, pagina, marca)),
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, PaginaAgenda pagina, Color marca) {
    final p = context.palette;
    Widget lista(String titulo, String? subtitulo, List<Widget> hijos) => ListView(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, Gap.xxl),
          children: [
            _Cabecera(pagina: pagina),
            const VGap.lg(),
            Semantics(header: true, child: Text(titulo, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            if (subtitulo != null) Text(subtitulo, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
            const VGap.md(),
            ...hijos,
          ],
        );

    switch (_paso) {
      case _Paso.servicio:
        return lista('¿Qué servicio necesitas?', null, [
          for (final (i, s) in pagina.servicios.indexed)
            Entrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: AppCard(
                  onTap: () => _elegirServicio(s),
                  semanticLabel: '${s.nombre}, ${duracionTexto(s.duracionMin)}${s.precio > 0 ? ', ${cop(s.precio)}' : ''}',
                  child: Row(children: [
                    Container(width: 4, height: 48, decoration: BoxDecoration(color: Color(s.color), borderRadius: BorderRadius.circular(2))),
                    const HGap.md(),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.nombre, style: context.text.titleMedium),
                        if (s.descripcion != null) Text(s.descripcion!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.schedule_rounded, size: 16, color: p.textSecondary),
                          const SizedBox(width: 4),
                          Text(duracionTexto(s.duracionMin), style: context.text.bodySmall),
                          const Spacer(),
                          if (s.precio > 0) Text(cop(s.precio), style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        ]),
                      ]),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ]),
                ),
              ),
            ),
        ]);
      case _Paso.profesional:
        return lista('¿Con quién?', 'Elige a alguien o deja que asignemos al primero libre.', [
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 560 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Gap.sm,
            crossAxisSpacing: Gap.sm,
            childAspectRatio: 0.95,
            children: [
              _TarjetaProfesional(
                nombre: 'Cualquier profesional',
                detalle: 'Más disponibilidad',
                avatar: Icon(Icons.bolt_rounded, color: marca, size: 30),
                color: marca.withValues(alpha: 0.15),
                onTap: () => _elegirProfesional(0),
                indice: 0,
              ),
              for (final (i, pr) in _equipo.indexed)
                _TarjetaProfesional(
                  nombre: pr.nombre,
                  detalle: pr.cargo ?? '',
                  avatar: Text(pr.iniciales, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                  color: Color(pr.color),
                  onTap: () => _elegirProfesional(pr.id),
                  indice: i + 1,
                ),
            ],
          ),
        ]);
      case _Paso.horario:
        final dia = _dias.where((d) => d.fecha == _fecha).firstOrNull;
        final grupos = <(String, IconData, List<Turno>)>[
          ('Mañana', Icons.wb_twilight_rounded, [for (final t in dia?.turnos ?? const <Turno>[]) if (t.hora.compareTo('12:00') < 0) t]),
          ('Tarde', Icons.light_mode_rounded, [for (final t in dia?.turnos ?? const <Turno>[]) if (t.hora.compareTo('12:00') >= 0 && t.hora.compareTo('18:00') < 0) t]),
          ('Noche', Icons.dark_mode_rounded, [for (final t in dia?.turnos ?? const <Turno>[]) if (t.hora.compareTo('18:00') >= 0) t]),
        ].where((g) => g.$3.isNotEmpty).toList();
        return lista('Elige fecha y hora', 'Hora de Colombia · ${duracionTexto(_servicio?.duracionMin ?? 0)}', [
          SizedBox(
            height: 84,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) _cargarDias();
                return false;
              },
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dias.length + (_cargandoDias ? 1 : 0),
                separatorBuilder: (_, _) => const HGap.xs(),
                itemBuilder: (context, i) {
                  if (i >= _dias.length) return const SizedBox(width: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                  final d = _dias[i];
                  final libre = d.turnos.isNotEmpty;
                  final elegido = d.fecha == _fecha;
                  final f = parseYmd(d.fecha);
                  return Semantics(
                    button: true,
                    selected: elegido,
                    enabled: libre,
                    label: '${fechaConDia(d.fecha)}, ${libre ? '${d.turnos.length} horarios' : 'sin horarios'}',
                    excludeSemantics: true,
                    child: Pressable(
                      onTap: libre
                          ? () => setState(() {
                                _fecha = d.fecha;
                                _hora = null;
                              })
                          : null,
                      child: AnimatedContainer(
                        duration: Motion.of(context, Motion.medium),
                        width: 60,
                        decoration: BoxDecoration(
                          color: elegido ? marca : (libre ? marca.withValues(alpha: 0.10) : Colors.transparent),
                          borderRadius: Radii.rMd,
                          border: Border.all(color: elegido ? marca : (libre ? marca.withValues(alpha: 0.3) : p.border)),
                        ),
                        child: Opacity(
                          opacity: libre ? 1 : 0.4,
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'][f.weekday % 7], style: context.text.labelSmall?.copyWith(color: elegido ? Colors.white : null)),
                            Text('${f.day}', style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: elegido ? Colors.white : null)),
                            Text(['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][f.month - 1], style: context.text.labelSmall?.copyWith(color: elegido ? Colors.white70 : null)),
                          ]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const VGap.lg(),
          if (_fecha == null && !_cargandoDias)
            const EmptyState(icon: Icons.event_busy_rounded, title: 'Sin horarios por ahora', message: 'No hay espacios libres en las próximas semanas.', compact: true)
          else if (dia != null) ...[
            Text(fechaConDia(dia.fecha), style: context.text.titleMedium),
            const VGap.sm(),
            for (final (titulo, icono, turnos) in grupos) ...[
              Row(children: [
                Icon(icono, size: 16, color: p.textSecondary),
                const SizedBox(width: 6),
                Text(titulo.toUpperCase(), style: context.text.labelSmall?.copyWith(letterSpacing: 1, color: p.textSecondary)),
              ]),
              const VGap.xs(),
              Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
                for (final (i, t) in turnos.indexed)
                  ChoiceChip(
                    label: Text(hora12(t.hora)),
                    selected: _hora == t.hora,
                    showCheckmark: false,
                    selectedColor: marca,
                    labelStyle: TextStyle(color: _hora == t.hora ? Colors.white : marca, fontWeight: FontWeight.w700),
                    side: BorderSide(color: marca.withValues(alpha: 0.4)),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _hora = t.hora);
                    },
                  ).animate(delay: (15 * i).ms).fadeIn(duration: 200.ms),
              ]),
              const VGap.md(),
            ],
          ],
        ]);
      case _Paso.datos:
        return lista('Tus datos', 'Te enviaremos un código por WhatsApp para confirmar.', [
          AppCard(
            child: Row(children: [
              Icon(Icons.event_available_rounded, color: marca),
              const HGap.sm(),
              Expanded(
                child: Text(
                  '${_servicio?.nombre}\n${fechaConDia(_fecha ?? hoyYmd())} · ${hora12(_hora)}${_profesional != 0 ? '\nCon ${_equipo.where((x) => x.id == _profesional).firstOrNull?.nombre ?? ''}' : ''}',
                  style: context.text.bodyMedium,
                ),
              ),
              TextButton(onPressed: () => _ir(_Paso.horario), child: const Text('Cambiar')),
            ]),
          ),
          const VGap.md(),
          TextField(controller: _nombre, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Nombre completo')),
          const VGap.sm(),
          WhatsAppField(controller: _numero, indicativo: _indicativo, onIndicativo: (v) => setState(() => _indicativo = v)),
          const VGap.sm(),
          TextField(controller: _nota, maxLength: 300, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nota para el negocio (opcional)')),
          if (_errorForm != null) Text(_errorForm!, style: context.text.bodySmall?.copyWith(color: p.danger)),
          const VGap.sm(),
          FilledButton.icon(
            onPressed: _enviando ? null : _reservar,
            icon: _enviando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
            label: const Text('Recibir código por WhatsApp'),
          ),
        ]);
      case _Paso.codigo:
        final r = _reserva!;
        return lista('Revisa tu WhatsApp', 'Enviamos un código de 6 dígitos al ${r.whatsapp ?? 'número que escribiste'}.', [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Brand.whatsapp, borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.chat_rounded, color: Colors.white, size: 38),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: -4, duration: 1500.ms, curve: Curves.easeInOut),
          ),
          const VGap.lg(),
          OtpField(key: _otp, onCompleto: _confirmar, error: _errorCodigo != null, enabled: !_confirmando && _segundos > 0),
          if (_errorCodigo != null) ...[
            const VGap.sm(),
            Text(_errorCodigo!, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(color: p.danger)),
          ],
          const VGap.md(),
          if (_segundos > 0) ...[
            Text('Vence en ${_segundos ~/ 60}:${(_segundos % 60).toString().padLeft(2, '0')}', textAlign: TextAlign.center, style: context.text.bodySmall),
            TextButton.icon(
              onPressed: _esperaReenvio > 0 ? null : _reenviar,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_esperaReenvio > 0 ? 'Reenviar en $_esperaReenvio s' : 'Reenviar código'),
            ),
          ] else
            FilledButton(onPressed: () => _ir(_Paso.horario), child: const Text('El código venció · elegir de nuevo')),
        ]);
      case _Paso.listo:
        final r = _reserva!;
        return ListView(
          padding: const EdgeInsets.all(Gap.lg),
          children: [
            const VGap.lg(),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(shape: BoxShape.circle, color: p.success.withValues(alpha: 0.15)),
                child: Icon(Icons.check_rounded, size: 56, color: p.success),
              ).animate().scale(begin: Motion.reduced(context) ? const Offset(1, 1) : const Offset(0.3, 0.3), duration: 520.ms, curve: Curves.elasticOut),
            ),
            const VGap.lg(),
            Text('¡Cita confirmada!', textAlign: TextAlign.center, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const VGap.xs(),
            Text('Te llegó la confirmación por WhatsApp y te recordaremos antes.', textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
            const VGap.lg(),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.negocio, style: context.text.titleMedium),
                const VGap.xs(),
                Text('${fechaConDia(r.fecha)} · ${hora12(r.horaInicio)} – ${hora12(r.horaFin)}', style: context.text.bodyMedium),
                Text('${r.servicio}${r.precio > 0 ? ' · ${cop(r.precio)}' : ''}', style: context.text.bodyMedium),
                Text('Con ${r.profesional}', style: context.text.bodySmall),
                if (r.direccion != null) Text(r.direccion!, style: context.text.bodySmall),
              ]),
            ).animate(delay: 250.ms).fadeIn(duration: 300.ms).slideY(begin: 0.1, curve: Motion.enter),
            const VGap.lg(),
            if (ref.watch(sesionProvider).value != null)
              FilledButton(onPressed: () => context.go('/citas'), child: const Text('Ver mis reservas'))
            else
              FilledButton(onPressed: () => context.canPop() ? context.pop() : context.go('/login'), child: const Text('Listo')),
          ],
        );
    }
  }
}

class _Cabecera extends StatelessWidget {
  const _Cabecera({required this.pagina});
  final PaginaAgenda pagina;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Hero(
        tag: 'negocio-${pagina.slug}',
        child: CircleAvatar(
          radius: 26,
          backgroundColor: Color(pagina.color),
          child: Text(iniciales(pagina.nombre), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
      const HGap.sm(),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(pagina.nombre, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text([rubrosAgenda[pagina.rubro] ?? '', if (pagina.direccion != null) pagina.direccion!].where((x) => x.isNotEmpty).join(' · '), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

class _TarjetaProfesional extends StatelessWidget {
  const _TarjetaProfesional({required this.nombre, required this.detalle, required this.avatar, required this.color, required this.onTap, required this.indice});
  final String nombre;
  final String detalle;
  final Widget avatar;
  final Color color;
  final VoidCallback onTap;
  final int indice;

  @override
  Widget build(BuildContext context) {
    return Entrance(
      index: indice,
      child: AppCard(
        onTap: onTap,
        semanticLabel: nombre,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircleAvatar(radius: 30, backgroundColor: color, child: avatar),
          const VGap.sm(),
          Text(nombre, textAlign: TextAlign.center, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (detalle.isNotEmpty) Text(detalle, textAlign: TextAlign.center, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

/// Barra inferior fija con el horario elegido (patrón Fresha / Booksy).
class _BarraContinuar extends StatelessWidget {
  const _BarraContinuar({required this.texto, required this.detalle, required this.onContinuar});
  final String texto;
  final String detalle;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.sm + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: p.surface, border: Border(top: BorderSide(color: p.border))),
      child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto, style: context.text.titleSmall),
            Text(detalle, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        FilledButton(onPressed: onContinuar, child: const Text('Continuar')),
      ]),
    ).animate().slideY(begin: 1, duration: Motion.of(context, Motion.medium), curve: Motion.enter);
  }
}
