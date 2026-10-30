import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/auth_widgets.dart' show indicativos;
import '../../events/whatsapp.dart' show abrirWhatsApp;
import '../citas_models.dart';
import '../citas_repository.dart';
import 'config_sheets.dart' show duracionTexto;

/// Color y ícono por estado (siempre acompañados de texto).
(Color, IconData) estiloEstado(BuildContext context, EstadoCita e) {
  final p = context.palette;
  return switch (e) {
    EstadoCita.confirmada => (p.accent, Icons.event_available_rounded),
    EstadoCita.completada => (p.success, Icons.task_alt_rounded),
    EstadoCita.pendiente => (p.warning, Icons.hourglass_top_rounded),
    EstadoCita.noAsistio => (p.danger, Icons.person_off_rounded),
    EstadoCita.cancelada => (p.danger, Icons.event_busy_rounded),
    EstadoCita.expirada => (p.textSecondary, Icons.timer_off_rounded),
  };
}

// ─────────────────────── Detalle de una cita ───────────────────────

class CitaDetalleSheet extends ConsumerStatefulWidget {
  const CitaDetalleSheet({super.key, required this.cita});
  final CitaAgenda cita;

  @override
  ConsumerState<CitaDetalleSheet> createState() => _CitaDetalleSheetState();
}

class _CitaDetalleSheetState extends ConsumerState<CitaDetalleSheet> {
  late CitaAgenda _cita = widget.cita;
  bool _ocupado = false;

  bool get _yaPaso {
    final ahora = DateTime.now();
    final hhmm = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
    return _cita.fecha.compareTo(hoyYmd()) < 0 || (_cita.fecha == hoyYmd() && _cita.horaInicio.compareTo(hhmm) <= 0);
  }

  Future<void> _cambiar(EstadoCita e, {String? motivo, required String ok}) async {
    setState(() => _ocupado = true);
    final toaster = Toaster.of(context);
    try {
      final c = await ref.read(agendaRepoProvider).cambiarEstado(_cita, e, motivo: motivo);
      HapticFeedback.mediumImpact();
      toaster.show(ok);
      if (mounted) setState(() => _cita = c);
    } on AgendaError catch (err) {
      toaster.show(err.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar() async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.event_busy_rounded, color: ctx.palette.danger, size: IconSizes.xl),
        title: const Text('¿Cancelar la cita?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _cita.clienteWhatsapp != null ? 'Le avisaremos a ${_cita.clienteNombre} por WhatsApp y el espacio quedará libre.' : 'El espacio quedará libre para otra reserva.',
          ),
          const VGap.sm(),
          TextField(controller: motivo, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Motivo (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mantener')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.palette.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    final texto = motivo.text.trim();
    motivo.dispose();
    if (ok == true) await _cambiar(EstadoCita.cancelada, motivo: texto.isEmpty ? null : texto, ok: 'Cita cancelada');
  }

  @override
  Widget build(BuildContext context) {
    // Si la cita cambia mientras está abierta (la cancelan, la confirman), el
    // detalle se actualiza en vivo.
    void seguir(List<CitaAgenda>? l) {
      final nueva = l?.where((x) => x.id == _cita.id).firstOrNull;
      if (nueva != null && nueva.estado != _cita.estado && !_ocupado) setState(() => _cita = nueva);
    }

    ref.listen(citasAgendaProvider, (_, n) => seguir(n.value));
    ref.listen(misReservasProvider, (_, n) => seguir(n.value));
    final p = context.palette;
    final c = _cita;
    final (color, icono) = estiloEstado(context, c.estado);
    final esCliente = c.rol == 'cliente';
    return SheetScaffold(
      title: c.servicioNombre,
      subtitle: '${fechaConDia(c.fecha)} · ${hora12(c.horaInicio)} – ${hora12(c.horaFin)}',
      icon: Icons.event_note_rounded,
      children: [
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.medium),
          child: Align(
            key: ValueKey(c.estado),
            alignment: Alignment.centerLeft,
            child: Tag(c.estado.etiqueta, color: color, icon: icono),
          ),
        ),
        const VGap.md(),
        AppCard(
          child: Column(children: [
            _Fila(
              icono: esCliente ? Icons.storefront_rounded : Icons.person_rounded,
              titulo: esCliente ? c.negocioNombre : c.clienteNombre,
              detalle: esCliente ? 'Con ${c.profesionalNombre}' : (c.clienteWhatsapp != null ? '+${c.clienteWhatsapp}' : 'Sin WhatsApp'),
              accion: !esCliente && c.clienteWhatsapp != null
                  ? IconButton.filledTonal(
                      tooltip: 'Escribir por WhatsApp',
                      icon: const Icon(Icons.chat_rounded),
                      onPressed: () => abrirWhatsApp(
                        'Hola ${c.clienteNombre.split(' ').first}, te escribo de ${c.negocioNombre} sobre tu cita de ${c.servicioNombre} el ${fechaConDia(c.fecha)} a las ${hora12(c.horaInicio)}.',
                        telefono: c.clienteWhatsapp,
                      ),
                    )
                  : null,
            ),
            if (!esCliente) ...[
              const Divider(height: Gap.lg),
              _Fila(icono: Icons.badge_rounded, titulo: c.profesionalNombre, detalle: 'Profesional', colorIcono: Color(c.profesionalColor)),
            ],
            const Divider(height: Gap.lg),
            _Fila(icono: Icons.schedule_rounded, titulo: duracionTexto(c.duracionMin), detalle: c.precio > 0 ? cop(c.precio) : 'Sin precio'),
            if (c.nota != null && c.nota!.isNotEmpty) ...[
              const Divider(height: Gap.lg),
              _Fila(icono: Icons.sticky_note_2_rounded, titulo: c.nota!, detalle: 'Nota del cliente'),
            ],
            if (c.motivoCancelacion != null) ...[
              const Divider(height: Gap.lg),
              _Fila(icono: Icons.info_outline_rounded, titulo: c.motivoCancelacion!, detalle: 'Motivo de cancelación'),
            ],
          ]),
        ),
        const VGap.xs(),
        Text(
          switch (c.origen) {
            'negocio' => 'Agendada por el negocio',
            'app' => 'Reservada desde la app',
            _ => 'Reservada desde el enlace web',
          },
          style: context.text.bodySmall,
          textAlign: TextAlign.center,
        ),
        if (!esCliente) ...[
          const VGap.lg(),
          if (c.estado == EstadoCita.confirmada && _yaPaso) ...[
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _ocupado ? null : () => _cambiar(EstadoCita.completada, ok: 'Cita completada'),
                  icon: const Icon(Icons.task_alt_rounded),
                  label: const Text('Asistió'),
                ),
              ),
              const HGap.sm(),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ocupado ? null : () => _cambiar(EstadoCita.noAsistio, ok: 'Marcada como inasistencia'),
                  icon: const Icon(Icons.person_off_rounded),
                  label: const Text('No asistió'),
                ),
              ),
            ]),
            const VGap.sm(),
          ],
          if (c.estado == EstadoCita.completada || c.estado == EstadoCita.noAsistio)
            OutlinedButton.icon(
              onPressed: _ocupado ? null : () => _cambiar(EstadoCita.confirmada, ok: 'Cita marcada como pendiente'),
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Deshacer'),
            ),
          if (c.estado.activa && (c.estado == EstadoCita.pendiente || !_yaPaso))
            TextButton.icon(
              onPressed: _ocupado ? null : _cancelar,
              style: TextButton.styleFrom(foregroundColor: p.danger),
              icon: const Icon(Icons.event_busy_rounded),
              label: const Text('Cancelar cita'),
            ),
        ],
      ],
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icono, required this.titulo, required this.detalle, this.accion, this.colorIcono});
  final IconData icono;
  final String titulo;
  final String detalle;
  final Widget? accion;
  final Color? colorIcono;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconBadge(icono, size: 40, color: colorIcono),
      const HGap.sm(),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: context.text.titleSmall),
          Text(detalle, style: context.text.bodySmall),
        ]),
      ),
      ?accion,
    ]);
  }
}

// ─────────────────────── Nueva cita (agendada por el negocio) ───────────────────────

class NuevaCitaSheet extends ConsumerStatefulWidget {
  const NuevaCitaSheet({super.key, required this.config, this.fecha});
  final ConfigAgenda config;
  final String? fecha;

  @override
  ConsumerState<NuevaCitaSheet> createState() => _NuevaCitaSheetState();
}

class _NuevaCitaSheetState extends ConsumerState<NuevaCitaSheet> {
  late ServicioAgenda? _servicio = widget.config.serviciosActivos.firstOrNull;
  late int? _profesional = _prestadores.firstOrNull?.id;
  late String _fecha = widget.fecha != null && widget.fecha!.compareTo(hoyYmd()) >= 0 ? widget.fecha! : hoyYmd();
  String? _hora;
  bool _otraHora = false;
  List<Turno>? _turnos;
  bool _cargandoTurnos = false;
  final _nombre = TextEditingController();
  final _numero = TextEditingController();
  final _nota = TextEditingController();
  String _indicativo = '57';
  bool _notificar = true;
  bool _guardando = false;

  /// Ya intentó guardar: desde ahora se marcan los campos que faltan.
  bool _intento = false;
  final _focoNombre = FocusNode();

  List<ProfesionalAgenda> get _prestadores =>
      _servicio == null ? const [] : [for (final p in widget.config.equipoActivo) if (_servicio!.profesionales.contains(p.id)) p];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTurnos());
  }

  @override
  void dispose() {
    _nombre.dispose();
    _numero.dispose();
    _nota.dispose();
    _focoNombre.dispose();
    super.dispose();
  }

  Future<void> _cargarTurnos() async {
    final n = widget.config.negocio;
    if (n == null || _servicio == null || _profesional == null) return;
    setState(() {
      _cargandoTurnos = true;
      _hora = null;
    });
    try {
      final dias = await ref.read(agendaRepoProvider).disponibilidad(n.slug, servicio: _servicio!.id, profesional: _profesional!, desde: _fecha, dias: 1);
      if (mounted) setState(() => _turnos = dias.firstOrNull?.turnos ?? const []);
    } catch (_) {
      if (mounted) setState(() => _turnos = const []);
    } finally {
      if (mounted) setState(() => _cargandoTurnos = false);
    }
  }

  Future<void> _enviar({bool forzar = false}) async {
    final toaster = Toaster.of(context);
    if (_servicio == null || _profesional == null) return toaster.show('Elige el servicio', error: true);
    setState(() => _intento = true);
    if (_hora == null || _nombre.text.trim().length < 2) {
      if (_nombre.text.trim().length < 2 && _hora != null) _focoNombre.requestFocus();
      return;
    }
    setState(() => _guardando = true);
    try {
      final numero = _numero.text.replaceAll(RegExp(r'\D'), '');
      await ref.read(agendaRepoProvider).crearCita({
        'servicio_id': _servicio!.id,
        'profesional_id': _profesional,
        'fecha': _fecha,
        'hora': _hora,
        'cliente_nombre': _nombre.text.trim(),
        if (numero.isNotEmpty) 'cliente_whatsapp': '$_indicativo$numero',
        'nota': _nota.text.trim(),
        'notificar': _notificar,
        'forzar': forzar,
      });
      HapticFeedback.mediumImpact();
      toaster.show(numero.isNotEmpty && _notificar ? 'Cita agendada · le avisamos por WhatsApp' : 'Cita agendada');
      if (mounted) Navigator.pop(context);
    } on AgendaError catch (e) {
      if (!mounted) return;
      if (e.ocupado && !forzar) {
        setState(() => _guardando = false);
        final si = await confirmar(context, titulo: 'Ese horario está ocupado', mensaje: '${e.mensaje.split('.').first}. Puedes agendarla de todas formas (quedarán dos citas a la vez).', confirmar: 'Agendar igual', icon: Icons.warning_amber_rounded);
        if (si && mounted) return _enviar(forzar: true);
        return;
      }
      toaster.show(e.mensaje, error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final servicios = widget.config.serviciosActivos;
    return SheetScaffold(
      title: 'Nueva cita',
      subtitle: 'Para clientes que llaman o llegan: queda confirmada de inmediato.',
      icon: Icons.add_task_rounded,
      primaryLabel: 'Agendar',
      busy: _guardando,
      onPrimary: _enviar,
      hayCambios: () => _nombre.text.isNotEmpty || _numero.text.isNotEmpty || _nota.text.isNotEmpty,
      children: [
        if (servicios.isEmpty)
          const EmptyState(icon: Icons.spa_outlined, title: 'Primero crea un servicio', message: 'Ve a Ajustes de citas → Servicios.', compact: true)
        else ...[
          const FieldLabel('Servicio'),
          ChoiceChips<int>(
            options: [for (final s in servicios) (s.id, s.nombre)],
            value: _servicio?.id ?? -1,
            onChanged: (v) {
              setState(() {
                _servicio = widget.config.servicio(v);
                if (!_prestadores.any((x) => x.id == _profesional)) _profesional = _prestadores.firstOrNull?.id;
              });
              _cargarTurnos();
            },
          ),
          if (_prestadores.length > 1) ...[
            const VGap.md(),
            const FieldLabel('Profesional'),
            ChoiceChips<int>(
              options: [for (final x in _prestadores) (x.id, x.nombre)],
              value: _profesional ?? -1,
              onChanged: (v) {
                setState(() => _profesional = v);
                _cargarTurnos();
              },
            ),
          ],
          const VGap.md(),
          DateField(
            value: _fecha,
            first: DateTime.now(),
            label: 'Fecha',
            onChanged: (v) {
              setState(() => _fecha = v);
              _cargarTurnos();
            },
          ),
          const VGap.md(),
          Row(children: [
            const Expanded(child: FieldLabel('Hora')),
            TextButton(onPressed: () => setState(() => _otraHora = !_otraHora), child: Text(_otraHora ? 'Ver horarios libres' : 'Otra hora')),
          ]),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.medium),
            child: _otraHora
                ? TimeField(key: const ValueKey('otra'), value: _hora, onChanged: (v) => setState(() => _hora = v))
                : _cargandoTurnos
                    ? const Padding(key: ValueKey('cargando'), padding: EdgeInsets.all(Gap.md), child: Center(child: CircularProgressIndicator()))
                    : (_turnos?.isEmpty ?? true)
                        ? Padding(
                            key: const ValueKey('vacio'),
                            padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                            child: Text('No hay horarios libres ese día. Usa "Otra hora" para agendar fuera de horario.', style: context.text.bodySmall?.copyWith(color: p.textSecondary)),
                          )
                        : Wrap(
                            key: ValueKey('turnos$_fecha$_profesional${_servicio?.id}'),
                            spacing: Gap.xs,
                            runSpacing: Gap.xs,
                            children: [
                              for (final t in _turnos!)
                                ChoiceChip(
                                  label: Text(hora12(t.hora)),
                                  selected: _hora == t.hora,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _hora = t.hora);
                                  },
                                ),
                            ],
                          ),
          ),
          if (_intento && _hora == null)
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Text('Elige la hora de la cita', style: context.text.bodySmall?.copyWith(color: p.danger)),
            ),
          const VGap.lg(),
          Text('Cliente', style: context.text.titleMedium),
          const VGap.sm(),
          TextField(
            controller: _nombre,
            focusNode: _focoNombre,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_intento) setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: _intento && _nombre.text.trim().length < 2 ? 'Escribe el nombre del cliente' : null,
            ),
          ),
          const VGap.sm(),
          TextField(
            controller: _numero,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
            decoration: InputDecoration(
              labelText: 'WhatsApp (opcional)',
              prefixIcon: PopupMenuButton<String>(
                tooltip: 'Indicativo del país',
                initialValue: _indicativo,
                onSelected: (v) => setState(() => _indicativo = v),
                itemBuilder: (_) => [for (final (c, n) in indicativos) PopupMenuItem(value: c, child: Text('+$c  $n'))],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Text('+$_indicativo'), const Icon(Icons.arrow_drop_down_rounded)]),
                ),
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _notificar,
            onChanged: (v) => setState(() => _notificar = v),
            title: const Text('Enviarle la confirmación por WhatsApp'),
            subtitle: Text('Con el enlace para cancelar si no puede asistir.', style: context.text.bodySmall),
          ),
          TextField(controller: _nota, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nota (opcional)')),
        ],
      ],
    );
  }
}
