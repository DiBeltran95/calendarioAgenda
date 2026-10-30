import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/dates.dart';
import '../../../core/db/database.dart';
import '../../../data/models.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../cycle_engine.dart';
import '../cycle_repository.dart';

/// Abre el registro de periodo para una fecha: crea uno nuevo o edita el que
/// ya empieza ese día.
Future<void> abrirPeriodo(BuildContext context, WidgetRef ref, String fecha) {
  final ciclos = ref.read(ciclosProvider).value ?? const <Ciclo>[];
  final existente = ciclos.where((c) => c.fechaInicio == fecha).firstOrNull;
  return showAppSheet(context, (_) => PeriodSheet(fecha: fecha, existente: existente));
}

class PeriodSheet extends ConsumerStatefulWidget {
  const PeriodSheet({super.key, required this.fecha, this.existente});
  final String fecha;
  final Ciclo? existente;

  @override
  ConsumerState<PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends ConsumerState<PeriodSheet> {
  late String _fecha;
  late int _dias;
  late bool _diasConocidos;
  late final TextEditingController _obs;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existente;
    final hoy = hoyYmd();
    _fecha = e?.fechaInicio ?? (widget.fecha.compareTo(hoy) > 0 ? hoy : widget.fecha);
    // En un ciclo nuevo se precarga el promedio: solo se cambia si fue distinto.
    _dias = e?.diasSangrado ?? ref.read(cycleStatsProvider).avgPeriodLength;
    _diasConocidos = e == null || e.diasSangrado != null;
    _obs = TextEditingController(text: e?.observacion ?? '');
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final r = await ref.read(cycleRepoProvider).guardarPeriodo(
            id: widget.existente?.id,
            fecha: _fecha,
            diasSangrado: _diasConocidos ? _dias : null,
            observacion: _obs.text,
          );
      HapticFeedback.mediumImpact();
      nav.pop();
      // El aviso (dos inicios muy seguidos) tiene prioridad sobre la confirmación.
      toaster.show(
        r.advertencia ?? (widget.existente == null ? 'Periodo registrado. El calendario se recalculó.' : 'Ciclo actualizado'),
        icon: r.advertencia != null ? Icons.info_outline_rounded : Icons.water_drop_rounded,
      );
    } on CicloError catch (e) {
      setState(() {
        _guardando = false;
        _error = e.mensaje;
      });
    }
  }

  Future<void> _eliminar() async {
    final c = widget.existente!;
    final nav = Navigator.of(context);
    final toaster = Toaster.of(context);
    final repo = ref.read(cycleRepoProvider);
    await repo.eliminarPeriodo(c.id);
    nav.pop();
    toaster.show('Ciclo del ${fechaCorta(c.fechaInicio)} eliminado', icon: Icons.delete_outline_rounded, onUndo: () => repo.restaurarPeriodo(c));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final editando = widget.existente != null;
    return SheetScaffold(
      title: editando ? 'Editar ciclo' : 'Registrar periodo',
      subtitle: 'Día 1 = primer día de sangrado',
      icon: Icons.water_drop_rounded,
      primaryLabel: editando ? 'Guardar cambios' : 'Registrar',
      busy: _guardando,
      onPrimary: _guardar,
      secondary: editando
          ? OutlinedButton.icon(
              onPressed: _eliminar,
              style: OutlinedButton.styleFrom(foregroundColor: p.danger, side: BorderSide(color: p.danger.withValues(alpha: 0.5))),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar'),
            )
          : null,
      children: [
        const FieldLabel('Primer día del periodo', required: true),
        DateField(value: _fecha, last: DateTime.now(), onChanged: (v) => setState(() => _fecha = v)),
        const FieldLabel('Días de sangrado'),
        StepperField(
          value: _dias,
          min: minSangrado,
          max: maxSangrado,
          suffix: _dias == 1 ? ' día' : ' días',
          onChanged: (v) => setState(() {
            _dias = v;
            _diasConocidos = true;
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _diasConocidos
              ? 'Se usa para pintar la duración real de este periodo.'
              : 'Sin especificar: se usará tu promedio. Ajusta el valor para registrarlo.',
          style: context.text.bodySmall,
        ),
        const FieldLabel('Observación'),
        TextField(
          controller: _obs,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Opcional · cómo te sentiste, medicamentos…'),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          Semantics(
            liveRegion: true,
            child: Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(color: p.danger.withValues(alpha: 0.12), borderRadius: Radii.rMd),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: p.danger),
                const SizedBox(width: Gap.xs),
                Expanded(child: Text(_error!, style: context.text.bodyMedium?.copyWith(color: p.danger))),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Registro diario: flujo, ánimo y síntomas.
class DayLogSheet extends ConsumerStatefulWidget {
  const DayLogSheet({super.key, required this.fecha, this.registro});
  final String fecha;
  final RegistroDia? registro;

  @override
  ConsumerState<DayLogSheet> createState() => _DayLogSheetState();
}

class _DayLogSheetState extends ConsumerState<DayLogSheet> {
  late int _flujo;
  String? _animo;
  late Set<String> _sintomas;
  late final TextEditingController _nota;

  @override
  void initState() {
    super.initState();
    final r = widget.registro;
    _flujo = r?.flujo ?? 0;
    _animo = r?.animo;
    _sintomas = {...?r?.sintomas.split(',').where((s) => s.isNotEmpty)};
    _nota = TextEditingController(text: r?.nota ?? '');
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '¿Cómo te sientes?',
      subtitle: fechaConDia(widget.fecha),
      icon: Icons.favorite_rounded,
      primaryLabel: 'Guardar',
      onPrimary: () async {
        final nav = Navigator.of(context);
        final toaster = Toaster.of(context);
        try {
          await ref.read(cycleRepoProvider).guardarRegistroDia(
                fecha: widget.fecha,
                flujo: _flujo,
                animo: _animo,
                sintomas: _sintomas,
                nota: _nota.text,
              );
          HapticFeedback.mediumImpact();
          nav.pop();
          toaster.show('Registro del día guardado', icon: Icons.favorite_rounded);
        } catch (e) {
          toaster.show('No se pudo guardar. Inténtalo de nuevo.', error: true);
        }
      },
      children: [
        const FieldLabel('Flujo'),
        SegmentedPill<int>(
          options: [for (var i = 0; i < nivelesFlujo.length; i++) (i, nivelesFlujo[i], null)],
          value: _flujo,
          onChanged: (v) => setState(() => _flujo = v),
        ),
        const FieldLabel('Estado de ánimo'),
        Wrap(
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: [
            for (final (k, l) in animosDisponibles)
              ChoiceChip(
                label: Text(l),
                selected: _animo == k,
                showCheckmark: false,
                onSelected: (s) => setState(() => _animo = s ? k : null),
              ),
          ],
        ),
        const FieldLabel('Síntomas'),
        Wrap(
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: [
            for (final (k, l) in sintomasDisponibles)
              FilterChip(
                label: Text(l),
                selected: _sintomas.contains(k),
                onSelected: (s) => setState(() => s ? _sintomas.add(k) : _sintomas.remove(k)),
              ),
          ],
        ),
        const FieldLabel('Nota'),
        TextField(
          controller: _nota,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Opcional'),
        ),
      ],
    );
  }
}
