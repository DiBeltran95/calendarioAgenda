import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../../core/motion.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../core/widgets/fields.dart';
import '../../core/widgets/sheets.dart';
import 'citas_models.dart';
import 'citas_repository.dart';
import 'widgets/config_sheets.dart';
import 'widgets/enlace_card.dart';
import 'widgets/horario_editor.dart';

/// Servicio sugerido por rubro (nombre y duración) para arrancar rápido.
const _sugerencias = <String, (String, int)>{
  'psicologia': ('Consulta psicológica', 60),
  'salud': ('Consulta médica', 30),
  'odontologia': ('Valoración odontológica', 30),
  'peluqueria': ('Corte y peinado', 45),
  'barberia': ('Corte clásico', 30),
  'estetica': ('Limpieza facial', 60),
  'spa': ('Masaje relajante', 60),
  'unas': ('Manicure', 45),
  'fitness': ('Sesión personalizada', 60),
  'consultoria': ('Asesoría', 60),
  'educacion': ('Clase', 60),
  'mascotas': ('Baño y peluquería', 60),
  'otro': ('Cita', 30),
};

/// "Peluquería Doña Ana" → "peluqueria-dona-ana".
String slugDe(String texto) {
  const de = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const a = 'aaaaaeeeeiiiiooooouuuunc';
  final b = StringBuffer();
  for (final ch in texto.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? a[i] : ch);
  }
  final s = b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.length > 50 ? s.substring(0, 50).replaceAll(RegExp(r'-+$'), '') : s;
}

/// Asistente para crear la página de citas en 4 pasos.
class CrearPaginaScreen extends ConsumerStatefulWidget {
  const CrearPaginaScreen({super.key});

  @override
  ConsumerState<CrearPaginaScreen> createState() => _CrearPaginaScreenState();
}

class _CrearPaginaScreenState extends ConsumerState<CrearPaginaScreen> {
  final _paginas = PageController();
  int _paso = 0;
  static const _total = 4;

  String _tipo = 'profesional';
  final _nombre = TextEditingController();
  final _slug = TextEditingController();
  bool _slugTocado = false;
  String _rubro = 'psicologia';
  int _color = coloresAgenda.first;
  String? _estadoSlug; // null = sin verificar, 'ok', o mensaje de error
  bool _verificando = false;
  Timer? _debounce;

  final _servicio = TextEditingController();
  bool _servicioTocado = false;
  int _duracion = 60;
  final _precio = TextEditingController();

  List<HorarioDia> _horario = horarioPlantilla('oficina');
  bool _duenoAtiende = true;

  bool _creando = false;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(sesionProvider).value?.usuario;
    if (u != null) {
      _nombre.text = u.nombre;
      _slug.text = slugDe(u.nombre);
      WidgetsBinding.instance.addPostFrameCallback((_) => _verificarSlug(_slug.text));
    }
    _aplicarSugerencia();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _paginas.dispose();
    for (final c in [_nombre, _slug, _servicio, _precio]) {
      c.dispose();
    }
    super.dispose();
  }

  void _aplicarSugerencia() {
    if (_servicioTocado) return;
    final (n, d) = _sugerencias[_rubro] ?? _sugerencias['otro']!;
    _servicio.text = n;
    _duracion = d;
  }

  void _verificarSlug(String v) {
    _debounce?.cancel();
    final s = v.trim().toLowerCase();
    setState(() {
      _estadoSlug = null;
      _verificando = s.isNotEmpty;
    });
    if (s.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final r = await ref.read(agendaRepoProvider).verificarSlug(s);
        if (!mounted || _slug.text.trim().toLowerCase() != s) return;
        setState(() {
          _verificando = false;
          if (!r.valido) {
            _estadoSlug = 'Usa minúsculas, números y guiones (3 a 50)';
          } else if (!r.disponible) {
            _estadoSlug = 'Ya está en uso';
            // Se propone el sugerido si el usuario no lo ha escrito a mano.
            if (!_slugTocado && r.sugerido.isNotEmpty) {
              _slug.text = r.sugerido;
              _estadoSlug = 'ok';
            }
          } else {
            _estadoSlug = 'ok';
          }
        });
      } catch (_) {
        if (mounted) setState(() => _verificando = false);
      }
    });
  }

  bool get _puedeSeguir => switch (_paso) {
        0 => true,
        1 => _nombre.text.trim().length >= 2 && _estadoSlug == 'ok',
        2 => _servicio.text.trim().length >= 2,
        _ => _tipo == 'empresa' && !_duenoAtiende || _horario.isNotEmpty,
      };

  Future<void> _siguiente() async {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    if (_paso < _total - 1) {
      setState(() => _paso++);
      await _paginas.animateToPage(_paso, duration: Motion.of(context, Motion.slow), curve: Motion.standard);
    } else {
      await _crear();
    }
  }

  void _atras() {
    if (_paso == 0) return context.pop();
    setState(() => _paso--);
    _paginas.animateToPage(_paso, duration: Motion.of(context, Motion.medium), curve: Motion.standard);
  }

  Future<void> _crear() async {
    setState(() => _creando = true);
    final repo = ref.read(agendaRepoProvider);
    final toaster = Toaster.of(context);
    try {
      final atiende = _tipo == 'profesional' || _duenoAtiende;
      await repo.guardarNegocio({
        'nombre': _nombre.text.trim(),
        'slug': _slug.text.trim().toLowerCase(),
        'tipo': _tipo,
        'rubro': _rubro,
        'color': colorAHex(_color),
        'dueno_atiende': atiende,
        if (atiende) 'horarios': [for (final h in _horario) h.toJson()],
      });
      await repo.guardarServicio({
        'nombre': _servicio.text.trim(),
        'duracion_min': _duracion,
        'precio': double.tryParse(_precio.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        'color': colorAHex(_color),
      });
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _listo = true);
    } on AgendaError catch (e) {
      toaster.show(e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_listo) return _Listo(onIrAgenda: () => context.pop());
    final marca = Color(_color);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(tooltip: _paso == 0 ? 'Cerrar' : 'Atrás', onPressed: _atras, icon: Icon(_paso == 0 ? Icons.close_rounded : Icons.arrow_back_rounded)),
        title: Text('Paso ${_paso + 1} de $_total'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_paso + 1) / _total),
            duration: Motion.of(context, Motion.slow),
            curve: Motion.standard,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 4, color: marca, backgroundColor: p.border),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _paginas,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Paso(
                  titulo: '¿Cómo trabajas?',
                  subtitulo: 'Así adaptamos tu página. Puedes cambiarlo después.',
                  children: [
                    _OpcionTipo(
                      icono: Icons.person_rounded,
                      titulo: 'Profesional independiente',
                      texto: 'Atiendes tú: psicólogos, entrenadores, consultores, tutores…',
                      elegido: _tipo == 'profesional',
                      onTap: () => setState(() => _tipo = 'profesional'),
                    ),
                    const VGap.sm(),
                    _OpcionTipo(
                      icono: Icons.groups_rounded,
                      titulo: 'Negocio con equipo',
                      texto: 'Varias personas atienden: peluquerías, spas, clínicas, barberías…',
                      elegido: _tipo == 'empresa',
                      onTap: () => setState(() => _tipo = 'empresa'),
                    ),
                  ],
                ),
                _Paso(
                  titulo: 'Tu página',
                  subtitulo: 'Así te verán tus clientes.',
                  children: [
                    TextField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(labelText: _tipo == 'empresa' ? 'Nombre del negocio' : 'Tu nombre profesional', hintText: _tipo == 'empresa' ? 'Ej.: Barbería Don Juan' : 'Ej.: Psicóloga Laura Gómez'),
                      onChanged: (v) {
                        setState(() {});
                        if (!_slugTocado) {
                          _slug.text = slugDe(v);
                          _verificarSlug(_slug.text);
                        }
                      },
                    ),
                    const VGap.md(),
                    TextField(
                      controller: _slug,
                      autocorrect: false,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')), LengthLimitingTextInputFormatter(50)],
                      onChanged: (v) {
                        _slugTocado = true;
                        _verificarSlug(v);
                      },
                      decoration: InputDecoration(
                        labelText: 'Tu enlace',
                        prefixText: 'agendaservi.com/agenda/',
                        errorText: _estadoSlug != null && _estadoSlug != 'ok' ? _estadoSlug : null,
                        suffixIcon: _verificando
                            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                            : _estadoSlug == 'ok'
                                ? Icon(Icons.check_circle_rounded, color: p.success, semanticLabel: 'Disponible')
                                : null,
                      ),
                    ),
                    const VGap.lg(),
                    const FieldLabel('Rubro'),
                    ChoiceChips<String>(
                      options: [for (final e in rubrosAgenda.entries) (e.key, e.value)],
                      value: _rubro,
                      onChanged: (v) => setState(() {
                        _rubro = v;
                        _aplicarSugerencia();
                      }),
                    ),
                    const VGap.lg(),
                    const FieldLabel('Color de tu marca'),
                    SelectorColor(valor: _color, onChanged: (v) => setState(() => _color = v)),
                  ],
                ),
                _Paso(
                  titulo: 'Tu primer servicio',
                  subtitulo: 'Después puedes agregar todos los que ofreces.',
                  children: [
                    TextField(
                      controller: _servicio,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _servicioTocado = true),
                      decoration: const InputDecoration(labelText: 'Nombre del servicio'),
                    ),
                    const VGap.lg(),
                    const FieldLabel('Duración'),
                    ChoiceChips<int>(
                      options: const [(15, '15 min'), (30, '30 min'), (45, '45 min'), (60, '1 hora'), (90, '1 h 30'), (120, '2 horas')],
                      value: _duracion,
                      onChanged: (v) => setState(() => _duracion = v),
                    ),
                    const VGap.lg(),
                    MoneyField(controller: _precio, label: 'Precio (opcional)'),
                  ],
                ),
                _Paso(
                  titulo: _tipo == 'empresa' ? '¿Quién atiende?' : 'Tu horario',
                  subtitulo: _tipo == 'empresa' ? 'Luego agregas a tu equipo, cada uno con su horario.' : 'Solo se ofrecerán horas dentro de este horario.',
                  children: [
                    if (_tipo == 'empresa')
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _duenoAtiende,
                        onChanged: (v) => setState(() => _duenoAtiende = v),
                        title: const Text('Yo también atiendo'),
                        subtitle: Text(_duenoAtiende ? 'Serás el primer profesional de tu equipo.' : 'Agregarás a tu equipo en Ajustes de citas.', style: context.text.bodySmall),
                      ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.medium),
                      alignment: Alignment.topCenter,
                      child: _tipo == 'empresa' && !_duenoAtiende
                          ? const SizedBox(width: double.infinity)
                          : HorarioEditor(horarios: _horario, onChanged: (h) => setState(() => _horario = h)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _puedeSeguir && !_creando ? _siguiente : null,
                style: FilledButton.styleFrom(backgroundColor: marca, foregroundColor: marca.computeLuminance() > 0.45 ? Colors.black : Colors.white),
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: _creando
                      ? const SizedBox(key: ValueKey('c'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text(_paso == _total - 1 ? 'Crear mi página' : 'Continuar', key: ValueKey(_paso == _total - 1)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.titulo, required this.subtitulo, required this.children});
  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.md, Gap.lg, Gap.lg),
          children: [
            Semantics(header: true, child: Text(titulo, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: Gap.xxs),
            Text(subtitulo, style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary)),
            const VGap.lg(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _OpcionTipo extends StatelessWidget {
  const _OpcionTipo({required this.icono, required this.titulo, required this.texto, required this.elegido, required this.onTap});
  final IconData icono;
  final String titulo;
  final String texto;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: elegido,
      button: true,
      child: Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.standard,
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: elegido ? p.accent.withValues(alpha: 0.10) : p.surface,
            borderRadius: Radii.rLg,
            border: Border.all(color: elegido ? p.accent : p.border, width: elegido ? 2 : 1),
          ),
          child: Row(children: [
            IconBadge(icono, size: 52),
            const HGap.md(),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: context.text.titleMedium),
                Text(texto, style: context.text.bodySmall),
              ]),
            ),
            AnimatedScale(
              scale: elegido ? 1 : 0,
              duration: Motion.of(context, Motion.medium),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_circle_rounded, color: p.accent),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Celebración final con el enlace listo para compartir.
class _Listo extends ConsumerWidget {
  const _Listo({required this.onIrAgenda});
  final VoidCallback onIrAgenda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final negocio = ref.watch(configAgendaProvider).value?.negocio;
    final quieto = Motion.reduced(context);
    Widget anim(Widget w, int ms) => quieto ? w : w.animate(delay: ms.ms).fadeIn(duration: 360.ms).slideY(begin: 0.15, curve: Motion.enter);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(Gap.lg),
              children: [
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: p.success.withValues(alpha: 0.15)),
                    child: Icon(Icons.celebration_rounded, size: 52, color: p.success),
                  ),
                ).animate().scale(begin: quieto ? const Offset(1, 1) : const Offset(0.4, 0.4), duration: 520.ms, curve: Curves.elasticOut),
                const VGap.lg(),
                anim(Text('¡Tu página está lista!', textAlign: TextAlign.center, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), 150),
                const VGap.xs(),
                anim(
                  Text(
                    'Compártela con tus clientes. Cada reserva se confirma por WhatsApp y te avisamos aquí al instante.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: p.textSecondary),
                  ),
                  250,
                ),
                const VGap.lg(),
                if (negocio != null) anim(TarjetaEnlace(negocio: negocio), 350),
                const VGap.lg(),
                anim(FilledButton(onPressed: onIrAgenda, child: const Text('Ir a mi agenda')), 450),
                const VGap.sm(),
                anim(
                  TextButton(
                    onPressed: () {
                      onIrAgenda();
                      context.push('/citas/ajustes');
                    },
                    child: const Text('Agregar más servicios o mi equipo'),
                  ),
                  500,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
