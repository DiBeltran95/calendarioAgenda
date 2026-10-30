import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../data/models.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../event_categories.dart';
import '../events_repository.dart';
import '../mensajes.dart';

/// Abre el formulario para crear o editar un evento o un cumpleaños.
Future<void> abrirFormularioEvento(
  BuildContext context, {
  Evento? evento,
  Cumple? cumple,
  String? fecha,
  String categoriaInicial = 'reunion',
}) {
  return showAppSheet(
    context,
    (_) => EventFormSheet(evento: evento, cumple: cumple, fecha: fecha ?? evento?.fecha ?? hoyYmd(), categoriaInicial: cumple != null ? 'cumpleanos' : categoriaInicial),
  );
}

/// Pregunta el alcance de un cambio sobre una serie.
Future<AlcanceSerie?> preguntarAlcance(BuildContext context, {required bool borrar}) async {
  final i = await elegirOpcion(
    context,
    titulo: borrar ? 'Eliminar evento repetido' : 'Editar evento repetido',
    mensaje: borrar
        ? 'Este evento forma parte de una serie. Los ya pagados se conservan.'
        : '¿Aplicar los cambios solo a este evento o también a los siguientes?',
    opciones: [
      ('Solo este evento', Icons.event_rounded, false),
      ('Este y los siguientes', Icons.event_repeat_rounded, borrar),
    ],
  );
  return switch (i) { 0 => AlcanceSerie.soloEste, 1 => AlcanceSerie.esteYFuturos, _ => null };
}

class EventFormSheet extends ConsumerStatefulWidget {
  const EventFormSheet({super.key, this.evento, this.cumple, required this.fecha, this.categoriaInicial = 'reunion'});

  final Evento? evento;
  final Cumple? cumple;
  final String fecha;
  final String categoriaInicial;

  @override
  ConsumerState<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends ConsumerState<EventFormSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _ubicacion;
  late final TextEditingController _costo;
  late final TextEditingController _anio;
  late final TextEditingController _telefono;
  late final TextEditingController _mensaje;
  late final String _inicial;

  String _firma() => [_titulo, _ubicacion, _costo, _anio, _telefono, _mensaje].map((c) => c.text).join('|');

  late String _categoria;
  late String _fecha;
  String? _hora;
  late String _frecuencia;
  late String _tipoTx;
  late String _estado;
  bool _guardando = false;

  bool get _editando => widget.evento != null || widget.cumple != null;
  bool get _esCumple => _categoria == 'cumpleanos';

  @override
  void initState() {
    super.initState();
    final e = widget.evento;
    final c = widget.cumple;
    _categoria = e?.categoria ?? widget.categoriaInicial;
    _fecha = c?.fecha ?? widget.fecha;
    // Un cumpleaños se muestra en el año visible aunque se haya creado otro año.
    if (c != null) _fecha = '${widget.fecha.substring(0, 4)}${c.fecha.substring(4)}';
    _hora = e?.hora;
    _frecuencia = e?.frecuencia ?? 'unica';
    _tipoTx = e?.tipoTransaccion ?? 'ninguno';
    _estado = e?.estadoPago ?? 'pendiente';
    _titulo = TextEditingController(text: e?.titulo ?? c?.nombre ?? '');
    _ubicacion = TextEditingController(text: e?.ubicacion ?? '');
    _costo = TextEditingController(text: montoInicial(e?.costo ?? 0));
    _anio = TextEditingController(text: c?.anioNacimiento?.toString() ?? '');
    _telefono = TextEditingController(text: c?.telefono ?? '');
    _mensaje = TextEditingController(text: c?.mensaje ?? '');
    _inicial = _firma();
  }

  @override
  void dispose() {
    for (final c in [_titulo, _ubicacion, _costo, _anio, _telefono, _mensaje]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!validarFormulario(_form)) return;
    final repo = ref.read(eventsRepoProvider);
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    setState(() => _guardando = true);
    try {
      if (_esCumple) {
        final input = CumpleInput(
          nombre: _titulo.text,
          fecha: _fecha,
          anioNacimiento: int.tryParse(_anio.text),
          telefono: _telefono.text,
          mensaje: _mensaje.text,
        );
        if (widget.cumple != null) {
          await repo.actualizarCumple(widget.cumple!.id, input);
        } else {
          await repo.crearCumple(input);
        }
      } else {
        final input = EventoInput(
          titulo: _titulo.text,
          fecha: _fecha,
          hora: _hora,
          categoria: _categoria,
          ubicacion: _ubicacion.text,
          frecuencia: _frecuencia,
          costo: parseMonto(_costo.text),
          tipoTransaccion: _tipoTx,
          estadoPago: _estado,
        );
        final e = widget.evento;
        if (e == null) {
          await repo.crear(input);
        } else {
          var alcance = AlcanceSerie.soloEste;
          if (repo.esSerie(e)) {
            final a = await preguntarAlcance(context, borrar: false);
            if (a == null) {
              setState(() => _guardando = false);
              return;
            }
            alcance = a;
          }
          await repo.actualizar(e, input, alcance);
        }
      }
      HapticFeedback.mediumImpact();
      nav.pop();
      toaster.show(_editando ? 'Cambios guardados' : (_esCumple ? 'Cumpleaños agregado' : 'Evento creado'));
    } catch (err) {
      if (mounted) {
        setState(() => _guardando = false);
        toast(context, 'No se pudo guardar: $err', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cat = categoriaEvento(_categoria);
    return SheetScaffold(
      title: _editando ? (_esCumple ? 'Editar cumpleaños' : 'Editar evento') : (_esCumple ? 'Nuevo cumpleaños' : 'Nuevo evento'),
      subtitle: fechaConDia(_fecha),
      icon: cat.icon,
      primaryLabel: _editando ? 'Guardar cambios' : 'Crear',
      busy: _guardando,
      onPrimary: _guardar,
      hayCambios: () => _firma() != _inicial,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Categoría'),
              _CategoryPicker(
                value: _categoria,
                bloqueada: widget.cumple != null || (widget.evento != null),
                onChanged: (v) => setState(() {
                  _categoria = v;
                  if (v == 'arriendo' && _tipoTx == 'ninguno') {
                    _tipoTx = 'gasto';
                    _frecuencia = 'mensual';
                  }
                }),
              ),
              FieldLabel(_esCumple ? 'Nombre del cumpleañero' : 'Título', required: true),
              TextFormField(
                controller: _titulo,
                autofocus: !_editando,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 255,
                decoration: InputDecoration(
                  hintText: _esCumple ? 'Ej. Mamá' : 'Ej. Pagar SOAT de la moto',
                  counterText: '',
                  prefixIcon: Icon(_esCumple ? Icons.person_rounded : Icons.title_rounded),
                ),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe ${_esCumple ? 'un nombre' : 'un título'}' : null,
              ),
              const FieldLabel('Fecha'),
              DateField(value: _fecha, onChanged: (v) => setState(() => _fecha = v)),
              SmoothSwitcher(
                child: _esCumple ? _camposCumple(context) : _camposEvento(context, p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _camposCumple(BuildContext context) {
    return Column(
      key: const ValueKey('cumple'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Año de nacimiento'),
        TextFormField(
          controller: _anio,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(hintText: 'Opcional · para calcular la edad', prefixIcon: Icon(Icons.cake_rounded)),
          validator: (v) {
            if ((v ?? '').isEmpty) return null;
            final n = int.tryParse(v!);
            if (n == null || n < 1900 || n > DateTime.now().year) return 'Año no válido';
            return null;
          },
        ),
        const FieldLabel('Teléfono (WhatsApp)'),
        TextFormField(
          controller: _telefono,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'Opcional · 300 123 4567', prefixIcon: Icon(Icons.phone_rounded)),
        ),
        const FieldLabel('Mensaje de felicitación'),
        TextFormField(
          controller: _mensaje,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Opcional · aparecerá en tu recordatorio'),
        ),
        const VGap.md(),
        const _AvisosCard(categoria: 'cumpleanos', hora: null),
      ],
    );
  }

  Widget _camposEvento(BuildContext context, Palette p) {
    return Column(
      key: const ValueKey('evento'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const FieldLabel('Hora'),
        TimeField(value: _hora, onChanged: (v) => setState(() => _hora = v)),
        const FieldLabel('Ubicación'),
        TextFormField(
          controller: _ubicacion,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Opcional', prefixIcon: Icon(Icons.place_rounded)),
        ),
        const FieldLabel('Se repite'),
        ChoiceChips<String>(
          options: [
            ...frecuenciasEvento,
            if (!frecuenciasEvento.any((f) => f.$1 == _frecuencia)) (_frecuencia, frecuenciaLabel(_frecuencia)),
          ],
          value: _frecuencia,
          onChanged: (v) => setState(() => _frecuencia = v),
        ),
        Padding(
          padding: const EdgeInsets.only(top: Gap.xs),
          child: SmoothSwitcher(
            child: Text(
              _frecuencia == 'unica'
                  ? frecuenciaDetalle(_frecuencia)
                  : '${frecuenciaDetalle(_frecuencia)} · se agendan las próximas ${maxOcurrencias(_frecuencia)} fechas.',
              key: ValueKey(_frecuencia),
              style: context.text.bodySmall,
            ),
          ),
        ),
        const FieldLabel('Movimiento de dinero'),
        SegmentedPill<String>(
          options: const [
            ('ninguno', 'Ninguno', Icons.block_rounded),
            ('gasto', 'Gasto', Icons.south_east_rounded),
            ('ingreso', 'Ingreso', Icons.north_east_rounded),
          ],
          colors: {'gasto': p.danger, 'ingreso': p.success},
          value: _tipoTx,
          onChanged: (v) => setState(() => _tipoTx = v),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.medium),
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: _tipoTx == 'ninguno'
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Valor', required: true),
                    MoneyField(
                      controller: _costo,
                      validator: (v) => v <= 0 ? 'Ingresa un valor mayor a 0' : null,
                    ),
                    const FieldLabel('Estado'),
                    SegmentedPill<String>(
                      options: const [
                        ('pendiente', 'Pendiente', Icons.schedule_rounded),
                        ('pagado', 'Pagado', Icons.check_circle_rounded),
                      ],
                      colors: {'pendiente': p.warning, 'pagado': p.success},
                      value: _estado,
                      onChanged: (v) => setState(() => _estado = v),
                    ),
                  ],
                ),
        ),
        const VGap.md(),
        _AvisosCard(categoria: _categoria, hora: _hora),
      ],
    );
  }
}

/// Selector de categoría: fila desplazable de chips con ícono y color propio.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.value, required this.onChanged, this.bloqueada = false});

  final String value;
  final ValueChanged<String> onChanged;

  /// Al editar no se puede convertir un evento en cumpleaños ni al revés.
  final bool bloqueada;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final opciones = eventCategories.where((c) {
      if (!bloqueada) return true;
      return value == 'cumpleanos' ? c.value == 'cumpleanos' : c.value != 'cumpleanos';
    }).toList();
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const HGap.xs(),
        itemBuilder: (context, i) {
          final c = opciones[i];
          final sel = c.value == value;
          return Semantics(
            selected: sel,
            button: true,
            label: c.label,
            child: Pressable(
              onTap: () => onChanged(c.value),
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.enter,
                width: 82,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: Gap.xs),
                decoration: BoxDecoration(
                  color: sel ? c.colorDe(context).withValues(alpha: context.isDark ? 0.2 : 0.14) : p.surfaceHigh,
                  borderRadius: Radii.rMd,
                  border: Border.all(color: sel ? c.colorDe(context) : p.border, width: sel ? 1.6 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: sel ? 1.12 : 1,
                      duration: Motion.of(context, Motion.medium),
                      curve: Curves.easeOutBack,
                      child: Icon(c.icon, color: sel ? c.colorDe(context) : p.textSecondary, size: IconSizes.lg),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(color: sel ? p.text : p.textSecondary, letterSpacing: 0, height: 1.15),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Explica cuándo llegará el recordatorio según la categoría y la hora (las
/// mismas reglas del cron): así el usuario sabe qué esperar antes de guardar.
class _AvisosCard extends StatelessWidget {
  const _AvisosCard({required this.categoria, required this.hora});
  final String categoria;
  final String? hora;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const wa = Brand.whatsapp;
    final texto = descripcionAvisos(categoria: categoria, hora: hora);
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: wa.withValues(alpha: context.isDark ? 0.1 : 0.08),
        borderRadius: Radii.rMd,
        border: Border.all(color: wa.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.notifications_active_rounded, color: wa, size: IconSizes.md),
        const HGap.xs(),
        Expanded(
          child: SmoothSwitcher(
            child: Text(texto, key: ValueKey(texto), style: context.text.bodySmall?.copyWith(color: p.text)),
          ),
        ),
      ]),
    );
  }
}
