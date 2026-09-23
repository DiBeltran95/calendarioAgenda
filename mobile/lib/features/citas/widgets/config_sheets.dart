import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/motion.dart';
import '../../../core/net/json.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../citas_models.dart';
import '../citas_repository.dart';
import 'horario_editor.dart';

/// Paleta para la marca del negocio, servicios y profesionales.
const coloresAgenda = <int>[
  0xFF2563EB, 0xFF0F766E, 0xFF059669, 0xFF7C3AED, 0xFFDB2777, 0xFFDC2626, //
  0xFFEA580C, 0xFFCA8A04, 0xFF0891B2, 0xFF4F46E5, 0xFF334155, 0xFF9333EA,
];

class SelectorColor extends StatelessWidget {
  const SelectorColor({super.key, required this.valor, required this.onChanged});
  final int valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
      for (final c in coloresAgenda)
        Semantics(
          button: true,
          selected: c == valor,
          label: 'Color ${colorAHex(c)}',
          child: Pressable(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(c);
            },
            child: AnimatedContainer(
              duration: Motion.of(context, Motion.fast),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: c == valor ? context.palette.text : Colors.transparent, width: 3),
              ),
              child: c == valor ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
            ),
          ),
        ),
    ]);
  }
}

Future<bool> _guardar(BuildContext context, Future<void> Function() accion, String ok) async {
  final toaster = Toaster.of(context);
  try {
    await accion();
    HapticFeedback.lightImpact();
    toaster.show(ok);
    return true;
  } on AgendaError catch (e) {
    toaster.show(e.mensaje, error: true);
    return false;
  }
}

// ─────────────────────── Datos y reglas del negocio ───────────────────────

class NegocioSheet extends ConsumerStatefulWidget {
  const NegocioSheet({super.key, required this.negocio});
  final NegocioAgenda negocio;

  @override
  ConsumerState<NegocioSheet> createState() => _NegocioSheetState();
}

class _NegocioSheetState extends ConsumerState<NegocioSheet> {
  late final _nombre = TextEditingController(text: widget.negocio.nombre);
  late final _slug = TextEditingController(text: widget.negocio.slug);
  late final _descripcion = TextEditingController(text: widget.negocio.descripcion ?? '');
  late final _direccion = TextEditingController(text: widget.negocio.direccion ?? '');
  late final _whatsapp = TextEditingController(text: widget.negocio.whatsapp ?? '');
  late String _tipo = widget.negocio.tipo;
  late String _rubro = widget.negocio.rubro;
  late int _color = widget.negocio.color;
  late int _anticipacion = widget.negocio.anticipacionMin;
  late int _ventana = widget.negocio.ventanaDias;
  late int _intervalo = widget.negocio.intervaloMin;
  late bool _usarCalendario = widget.negocio.usarCalendario;
  late bool _activo = widget.negocio.activo;
  String? _errorSlug;
  bool _guardando = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_nombre, _slug, _descripcion, _direccion, _whatsapp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _revisarSlug(String v) {
    _debounce?.cancel();
    final s = v.trim().toLowerCase();
    if (s == widget.negocio.slug) return setState(() => _errorSlug = null);
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      try {
        final r = await ref.read(agendaRepoProvider).verificarSlug(s);
        if (!mounted) return;
        setState(() => _errorSlug = !r.valido ? 'Usa minúsculas, números y guiones (3 a 50)' : (!r.disponible ? 'Ya está en uso. Prueba "${r.sugerido}"' : null));
      } catch (_) {}
    });
  }

  Future<void> _enviar() async {
    if (_nombre.text.trim().length < 2) return Toaster.of(context).show('Escribe el nombre del negocio', error: true);
    if (_errorSlug != null) return Toaster.of(context).show(_errorSlug!, error: true);
    setState(() => _guardando = true);
    final ok = await _guardar(
      context,
      () => ref.read(agendaRepoProvider).guardarNegocio({
        'nombre': _nombre.text.trim(),
        'slug': _slug.text.trim().toLowerCase(),
        'tipo': _tipo,
        'rubro': _rubro,
        'descripcion': _descripcion.text.trim(),
        'direccion': _direccion.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'color': colorAHex(_color),
        'anticipacion_min': _anticipacion,
        'ventana_dias': _ventana,
        'intervalo_min': _intervalo,
        'usar_calendario': _usarCalendario,
        'activo': _activo,
      }),
      'Página actualizada',
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SheetScaffold(
      title: 'Tu página de citas',
      icon: Icons.storefront_rounded,
      primaryLabel: 'Guardar cambios',
      busy: _guardando,
      onPrimary: _enviar,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _activo,
          onChanged: (v) => setState(() => _activo = v),
          title: const Text('Recibir reservas'),
          subtitle: Text(_activo ? 'Tu enlace está abierto al público.' : 'Pausada: el enlace muestra que no hay agenda.', style: context.text.bodySmall),
        ),
        const VGap.sm(),
        SegmentedPill<String>(
          options: const [('profesional', 'Independiente', Icons.person_rounded), ('empresa', 'Con equipo', Icons.groups_rounded)],
          value: _tipo,
          onChanged: (v) => setState(() => _tipo = v),
        ),
        const VGap.md(),
        TextField(controller: _nombre, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre que verán tus clientes')),
        const VGap.sm(),
        TextField(
          controller: _slug,
          onChanged: _revisarSlug,
          autocorrect: false,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')), LengthLimitingTextInputFormatter(50)],
          decoration: InputDecoration(labelText: 'Enlace', prefixText: 'agendaservi.com/agenda/', errorText: _errorSlug, errorMaxLines: 2),
        ),
        const VGap.md(),
        const FieldLabel('Rubro'),
        ChoiceChips<String>(options: [for (final e in rubrosAgenda.entries) (e.key, e.value)], value: _rubro, onChanged: (v) => setState(() => _rubro = v)),
        const VGap.md(),
        TextField(
          controller: _descripcion,
          maxLines: 3,
          minLines: 2,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)', hintText: 'Qué ofreces, experiencia, qué llevar…'),
        ),
        TextField(controller: _direccion, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Dirección (opcional)', prefixIcon: Icon(Icons.location_on_outlined))),
        const VGap.sm(),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'WhatsApp de contacto (opcional)', helperText: 'Con indicativo, p. ej. 573001234567. Aparece como "¿Dudas? Escríbenos".', helperMaxLines: 2),
        ),
        const VGap.md(),
        const FieldLabel('Color de tu marca'),
        SelectorColor(valor: _color, onChanged: (v) => setState(() => _color = v)),
        const VGap.lg(),
        Text('Reglas de reserva', style: context.text.titleMedium),
        const VGap.sm(),
        const FieldLabel('Anticipación mínima'),
        ChoiceChips<int>(
          options: const [(0, 'Sin mínimo'), (60, '1 hora'), (120, '2 horas'), (240, '4 horas'), (720, '12 horas'), (1440, '1 día')],
          value: _anticipacion,
          onChanged: (v) => setState(() => _anticipacion = v),
        ),
        const VGap.md(),
        const FieldLabel('Se puede agendar con'),
        ChoiceChips<int>(
          options: const [(7, '1 semana'), (15, '15 días'), (30, '1 mes'), (60, '2 meses'), (90, '3 meses')],
          value: _ventana,
          onChanged: (v) => setState(() => _ventana = v),
        ),
        const VGap.md(),
        const FieldLabel('Horarios cada'),
        ChoiceChips<int>(
          options: const [(10, '10 min'), (15, '15 min'), (20, '20 min'), (30, '30 min'), (60, '1 hora')],
          value: _intervalo,
          onChanged: (v) => setState(() => _intervalo = v),
        ),
        const VGap.sm(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _usarCalendario,
          onChanged: (v) => setState(() => _usarCalendario = v),
          title: const Text('Respetar mi calendario personal'),
          subtitle: Text('Tus eventos con hora bloquean ese espacio (1 hora) para que no te agenden encima.', style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
        ),
      ],
    );
  }
}

// ─────────────────────── Servicio ───────────────────────

class ServicioSheet extends ConsumerStatefulWidget {
  const ServicioSheet({super.key, this.servicio, required this.config});
  final ServicioAgenda? servicio;
  final ConfigAgenda config;

  @override
  ConsumerState<ServicioSheet> createState() => _ServicioSheetState();
}

class _ServicioSheetState extends ConsumerState<ServicioSheet> {
  late final _nombre = TextEditingController(text: widget.servicio?.nombre ?? '');
  late final _descripcion = TextEditingController(text: widget.servicio?.descripcion ?? '');
  late final _precio = TextEditingController(text: widget.servicio == null || widget.servicio!.precio == 0 ? '' : widget.servicio!.precio.toStringAsFixed(0));
  late int _duracion = widget.servicio?.duracionMin ?? 30;
  late int _color = widget.servicio?.color ?? widget.config.negocio?.color ?? coloresAgenda.first;
  late bool _activo = widget.servicio?.activo ?? true;
  late Set<int> _profs = {...?widget.servicio?.profesionales};
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.servicio == null) _profs = {for (final p in widget.config.equipoActivo) p.id};
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nombre.text.trim().length < 2) return Toaster.of(context).show('Escribe el nombre del servicio', error: true);
    setState(() => _guardando = true);
    final precio = double.tryParse(_precio.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final ok = await _guardar(
      context,
      () => ref.read(agendaRepoProvider).guardarServicio({
        'nombre': _nombre.text.trim(),
        'descripcion': _descripcion.text.trim(),
        'duracion_min': _duracion,
        'precio': precio,
        'color': colorAHex(_color),
        'activo': _activo,
        if (widget.config.profesionales.length > 1) 'profesionales': _profs.toList(),
      }, id: widget.servicio?.id),
      widget.servicio == null ? 'Servicio creado' : 'Servicio actualizado',
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _eliminar() async {
    final s = widget.servicio!;
    final ok = await confirmar(
      context,
      titulo: '¿Eliminar "${s.nombre}"?',
      mensaje: 'Ya no se podrá agendar. Las citas existentes se conservan.',
      confirmar: 'Eliminar',
      destructivo: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    if (await _guardar(context, () => ref.read(agendaRepoProvider).eliminarServicio(s.id), 'Servicio eliminado') && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final equipo = widget.config.profesionales;
    return SheetScaffold(
      title: widget.servicio == null ? 'Nuevo servicio' : 'Editar servicio',
      icon: Icons.spa_rounded,
      primaryLabel: 'Guardar',
      busy: _guardando,
      onPrimary: _enviar,
      headerAction: widget.servicio == null ? null : IconButton(tooltip: 'Eliminar', onPressed: _eliminar, icon: const Icon(Icons.delete_outline_rounded)),
      children: [
        TextField(controller: _nombre, autofocus: widget.servicio == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej.: Consulta, Corte clásico, Manicure')),
        const VGap.sm(),
        TextField(controller: _descripcion, maxLines: 2, maxLength: 300, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
        const FieldLabel('Duración'),
        ChoiceChips<int>(
          options: [for (final m in {15, 20, 30, 45, 60, 75, 90, 120, 180, _duracion}.toList()..sort()) (m, _dur(m))],
          value: _duracion,
          onChanged: (v) => setState(() => _duracion = v),
        ),
        const VGap.md(),
        MoneyField(controller: _precio, label: 'Precio (opcional)'),
        const VGap.md(),
        const FieldLabel('Color'),
        SelectorColor(valor: _color, onChanged: (v) => setState(() => _color = v)),
        if (equipo.length > 1) ...[
          const VGap.md(),
          const FieldLabel('¿Quién lo presta?'),
          Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
            for (final p in equipo)
              FilterChip(
                avatar: CircleAvatar(backgroundColor: Color(p.color), child: Text(p.iniciales, style: const TextStyle(fontSize: 10, color: Colors.white))),
                label: Text(p.nombre),
                selected: _profs.contains(p.id),
                onSelected: (v) => setState(() => v ? _profs.add(p.id) : _profs.remove(p.id)),
              ),
          ]),
        ],
        const VGap.sm(),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _activo, onChanged: (v) => setState(() => _activo = v), title: const Text('Disponible para agendar')),
      ],
    );
  }
}

String _dur(int m) => m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60}');

String duracionTexto(int m) => m < 60 ? '$m min' : (m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min');

// ─────────────────────── Profesional ───────────────────────

class ProfesionalSheet extends ConsumerStatefulWidget {
  const ProfesionalSheet({super.key, this.profesional, required this.config});
  final ProfesionalAgenda? profesional;
  final ConfigAgenda config;

  @override
  ConsumerState<ProfesionalSheet> createState() => _ProfesionalSheetState();
}

class _ProfesionalSheetState extends ConsumerState<ProfesionalSheet> {
  late final _nombre = TextEditingController(text: widget.profesional?.nombre ?? '');
  late final _cargo = TextEditingController(text: widget.profesional?.cargo ?? '');
  late final _whatsapp = TextEditingController(text: widget.profesional?.whatsapp ?? '');
  late final _vincular = TextEditingController(text: widget.profesional?.usuarioEmail ?? '');
  late int _color = widget.profesional?.color ?? coloresAgenda[(widget.config.profesionales.length + 1) % coloresAgenda.length];
  late List<HorarioDia> _horario = widget.profesional?.horarios ?? horarioPlantilla('oficina');
  late Set<int> _servicios = {...?widget.profesional?.servicios};
  late bool _activo = widget.profesional?.activo ?? true;
  bool _guardando = false;

  bool get _esDueno => widget.profesional?.esDueno ?? false;

  @override
  void initState() {
    super.initState();
    if (widget.profesional == null) _servicios = {for (final s in widget.config.serviciosActivos) s.id};
  }

  @override
  void dispose() {
    for (final c in [_nombre, _cargo, _whatsapp, _vincular]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nombre.text.trim().length < 2) return Toaster.of(context).show('Escribe el nombre', error: true);
    setState(() => _guardando = true);
    final vinculoPrevio = widget.profesional?.usuarioEmail ?? '';
    final ok = await _guardar(
      context,
      () => ref.read(agendaRepoProvider).guardarProfesional({
        'nombre': _nombre.text.trim(),
        'cargo': _cargo.text.trim(),
        'whatsapp': _whatsapp.text.trim(),
        'color': colorAHex(_color),
        'activo': _activo,
        'horarios': [for (final h in _horario) h.toJson()],
        'servicios': _servicios.toList(),
        if (!_esDueno && _vincular.text.trim() != vinculoPrevio) 'vincular': _vincular.text.trim(),
      }, id: widget.profesional?.id),
      widget.profesional == null ? 'Profesional agregado' : 'Cambios guardados',
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _eliminar() async {
    final pr = widget.profesional!;
    final ok = await confirmar(
      context,
      titulo: '¿Quitar a ${pr.nombre}?',
      mensaje: 'Si tiene citas pasadas se desactiva para conservar el historial.',
      confirmar: 'Quitar',
      destructivo: true,
      icon: Icons.person_remove_outlined,
    );
    if (!ok || !mounted) return;
    if (await _guardar(context, () => ref.read(agendaRepoProvider).eliminarProfesional(pr.id), 'Profesional quitado') && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final servicios = widget.config.servicios;
    return SheetScaffold(
      title: _esDueno ? 'Tu perfil y horario' : (widget.profesional == null ? 'Nuevo profesional' : 'Editar profesional'),
      icon: Icons.badge_rounded,
      primaryLabel: 'Guardar',
      busy: _guardando,
      onPrimary: _enviar,
      headerAction: widget.profesional == null || _esDueno ? null : IconButton(tooltip: 'Quitar', onPressed: _eliminar, icon: const Icon(Icons.person_remove_outlined)),
      children: [
        Row(children: [
          AnimatedContainer(
            duration: Motion.of(context, Motion.medium),
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Color(_color), shape: BoxShape.circle),
            child: Text(iniciales(_nombre.text.isEmpty ? '?' : _nombre.text), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          const HGap.md(),
          Expanded(
            child: TextField(
              controller: _nombre,
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          ),
        ]),
        const VGap.sm(),
        TextField(controller: _cargo, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Cargo (opcional)', hintText: 'Ej.: Barbero, Psicóloga clínica')),
        const VGap.sm(),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'WhatsApp (opcional)', helperText: 'Si no usa la app, le avisamos de sus citas por aquí. Con indicativo: 57…', helperMaxLines: 2),
        ),
        if (!_esDueno) ...[
          const VGap.sm(),
          TextField(
            controller: _vincular,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Vincular con su cuenta de Agendaservi (opcional)',
              hintText: 'correo@ejemplo.com',
              helperText: widget.profesional?.usuarioNombre != null
                  ? 'Vinculado con ${widget.profesional!.usuarioNombre}: recibe sus citas en la app y en su calendario.'
                  : 'Con su correo, recibe sus citas en la app y se cruzan con su calendario.',
              helperMaxLines: 3,
              prefixIcon: Icon(Icons.link_rounded, color: widget.profesional?.usuarioId != null ? p.success : null),
            ),
          ),
        ],
        const VGap.md(),
        const FieldLabel('Color en la agenda'),
        SelectorColor(valor: _color, onChanged: (v) => setState(() => _color = v)),
        if (servicios.isNotEmpty && (!_esDueno || widget.config.profesionales.length > 1)) ...[
          const VGap.md(),
          const FieldLabel('Servicios que presta'),
          Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
            for (final s in servicios)
              FilterChip(
                label: Text(s.nombre),
                selected: _servicios.contains(s.id),
                onSelected: (v) => setState(() => v ? _servicios.add(s.id) : _servicios.remove(s.id)),
              ),
          ]),
        ],
        const VGap.lg(),
        Text('Horario de atención', style: context.text.titleMedium),
        const VGap.xs(),
        HorarioEditor(horarios: _horario, onChanged: (h) => setState(() => _horario = h)),
        if (!_esDueno)
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _activo, onChanged: (v) => setState(() => _activo = v), title: const Text('Disponible para agendar')),
      ],
    );
  }
}

// ─────────────────────── Bloqueo (día u horas libres) ───────────────────────

class BloqueoSheet extends ConsumerStatefulWidget {
  const BloqueoSheet({super.key, required this.config});
  final ConfigAgenda config;

  @override
  ConsumerState<BloqueoSheet> createState() => _BloqueoSheetState();
}

class _BloqueoSheetState extends ConsumerState<BloqueoSheet> {
  String _fecha = sumarDiasYmd(hoyYmd(), 1);
  bool _diaCompleto = true;
  String? _inicio = '08:00';
  String? _fin = '12:00';
  int _profesional = 0; // 0 = todo el equipo
  final _motivo = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_diaCompleto && (_inicio == null || _fin == null || _fin!.compareTo(_inicio!) <= 0)) {
      return Toaster.of(context).show('La hora final debe ser después de la inicial', error: true);
    }
    setState(() => _guardando = true);
    final ok = await _guardar(
      context,
      () => ref.read(agendaRepoProvider).crearBloqueo({
        'fecha': _fecha,
        if (!_diaCompleto) 'inicio': _inicio,
        if (!_diaCompleto) 'fin': _fin,
        if (_profesional != 0) 'profesional_id': _profesional,
        'motivo': _motivo.text.trim(),
      }),
      'Espacio bloqueado',
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final equipo = widget.config.equipoActivo;
    return SheetScaffold(
      title: 'Bloquear tiempo',
      subtitle: 'Vacaciones, diligencias o un festivo propio: nadie podrá agendar ahí.',
      icon: Icons.event_busy_rounded,
      primaryLabel: 'Bloquear',
      busy: _guardando,
      onPrimary: _enviar,
      children: [
        DateField(value: _fecha, first: DateTime.now(), onChanged: (v) => setState(() => _fecha = v), label: 'Fecha'),
        const VGap.sm(),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: _diaCompleto, onChanged: (v) => setState(() => _diaCompleto = v), title: const Text('Todo el día')),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          child: _diaCompleto
              ? const SizedBox(width: double.infinity)
              : Row(children: [
                  Expanded(child: TimeField(value: _inicio, onChanged: (v) => setState(() => _inicio = v))),
                  const HGap.sm(),
                  Expanded(child: TimeField(value: _fin, onChanged: (v) => setState(() => _fin = v))),
                ]),
        ),
        if (equipo.length > 1) ...[
          const VGap.md(),
          const FieldLabel('¿Para quién?'),
          ChoiceChips<int>(options: [(0, 'Todo el equipo'), for (final p in equipo) (p.id, p.nombre)], value: _profesional, onChanged: (v) => setState(() => _profesional = v)),
        ],
        const VGap.md(),
        TextField(controller: _motivo, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Ej.: Vacaciones')),
      ],
    );
  }
}
