import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/dates.dart';
import '../../../core/motion.dart';
import '../citas_models.dart';

/// Días en el orden en que se muestran (lunes primero); valor = 0 domingo…6 sábado.
const diasSemana = <(int, String, String)>[
  (1, 'L', 'Lunes'),
  (2, 'M', 'Martes'),
  (3, 'X', 'Miércoles'),
  (4, 'J', 'Jueves'),
  (5, 'V', 'Viernes'),
  (6, 'S', 'Sábado'),
  (0, 'D', 'Domingo'),
];

/// Plantillas rápidas de horario.
List<HorarioDia> horarioPlantilla(String cual) => switch (cual) {
      'oficina' => [for (final d in [1, 2, 3, 4, 5]) ...[HorarioDia(dia: d, inicio: '08:00', fin: '12:00'), HorarioDia(dia: d, inicio: '14:00', fin: '18:00')]],
      'comercio' => [for (final d in [1, 2, 3, 4, 5, 6]) HorarioDia(dia: d, inicio: '09:00', fin: '19:00')],
      'tardes' => [for (final d in [1, 2, 3, 4, 5]) HorarioDia(dia: d, inicio: '14:00', fin: '20:00')],
      _ => const [],
    };

/// Resumen legible: "L–V 8:00–12:00 y 14:00–18:00 · S 9:00–13:00".
String resumenHorario(List<HorarioDia> h) {
  if (h.isEmpty) return 'Sin horario';
  final porDia = <int, String>{};
  for (final (d, _, _) in diasSemana) {
    final r = h.where((x) => x.dia == d).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));
    if (r.isNotEmpty) porDia[d] = r.map((x) => '${_h(x.inicio)}–${_h(x.fin)}').join(' y ');
  }
  // Agrupa días consecutivos con el mismo horario.
  final grupos = <(List<String>, String)>[];
  for (final (d, letra, _) in diasSemana) {
    final t = porDia[d];
    if (t == null) continue;
    if (grupos.isNotEmpty && grupos.last.$2 == t && _consecutivo(grupos.last.$1.last, letra)) {
      grupos.last.$1.add(letra);
    } else {
      grupos.add(([letra], t));
    }
  }
  return grupos.map((g) => '${g.$1.length > 2 ? '${g.$1.first}–${g.$1.last}' : g.$1.join(', ')} ${g.$2}').join(' · ');
}

bool _consecutivo(String a, String b) {
  const orden = 'LMXJVSD';
  return orden.indexOf(b) == orden.indexOf(a) + 1;
}

String _h(String hhmm) {
  final p = hhmm.split(':');
  final m = p[1] == '00' ? '' : ':${p[1]}';
  return '${int.parse(p[0])}$m';
}

/// Editor semanal: cada día se activa o no y admite varios rangos (jornada
/// partida). Arriba, plantillas de un toque.
class HorarioEditor extends StatelessWidget {
  const HorarioEditor({super.key, required this.horarios, required this.onChanged, this.plantillas = true});

  final List<HorarioDia> horarios;
  final ValueChanged<List<HorarioDia>> onChanged;
  final bool plantillas;

  List<HorarioDia> _de(int dia) => horarios.where((h) => h.dia == dia).toList()..sort((a, b) => a.inicio.compareTo(b.inicio));

  void _alternar(int dia, bool on) {
    HapticFeedback.selectionClick();
    final resto = horarios.where((h) => h.dia != dia).toList();
    if (on) {
      // Copia el horario del día anterior con horario (lo más común).
      final base = horarios.where((h) => h.dia != dia).toList();
      final modelo = base.isEmpty ? [const HorarioDia(dia: 0, inicio: '08:00', fin: '17:00')] : base.where((h) => h.dia == base.first.dia).toList();
      resto.addAll([for (final m in modelo) HorarioDia(dia: dia, inicio: m.inicio, fin: m.fin)]);
    }
    onChanged(resto);
  }

  Future<void> _editarRango(BuildContext context, HorarioDia? actual, int dia) async {
    final inicio = await _elegirHora(context, actual?.inicio ?? '08:00', 'Hora de inicio');
    if (inicio == null || !context.mounted) return;
    final finSugerido = actual?.fin ?? _sumar(inicio, 240);
    final fin = await _elegirHora(context, finSugerido, 'Hora de fin');
    if (fin == null) return;
    if (fin.compareTo(inicio) <= 0) {
      if (context.mounted) {
        toast(context, 'La hora de fin debe ser después de la de inicio.', error: true);
      }
      return;
    }
    final nuevo = [...horarios];
    if (actual != null) nuevo.remove(actual);
    nuevo.add(HorarioDia(dia: dia, inicio: inicio, fin: fin));
    onChanged(nuevo);
  }

  static String _sumar(String hhmm, int min) {
    final p = hhmm.split(':').map(int.parse).toList();
    final t = (p[0] * 60 + p[1] + min).clamp(0, 23 * 60 + 45);
    return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
  }

  static Future<String?> _elegirHora(BuildContext context, String hhmm, String ayuda) async {
    final p = hhmm.split(':').map(int.parse).toList();
    final t = await showTimePicker(
      context: context,
      helpText: ayuda,
      initialTime: TimeOfDay(hour: p[0], minute: p[1]),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (t == null) return null;
    // Se redondea a múltiplos de 5 minutos.
    final m = (t.minute / 5).round() * 5;
    final h = t.hour + m ~/ 60;
    return '${(h % 24).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plantillas) ...[
          Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
            for (final (k, l) in const [('oficina', 'L–V · 8–12 y 14–18'), ('comercio', 'L–S · 9–19'), ('tardes', 'L–V · 14–20')])
              ActionChip(
                avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(l),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onChanged(horarioPlantilla(k));
                },
              ),
          ]),
          const VGap.sm(),
        ],
        for (final (dia, _, nombre) in diasSemana)
          _FilaDia(
            nombre: nombre,
            rangos: _de(dia),
            onAlternar: (v) => _alternar(dia, v),
            onEditar: (r) => _editarRango(context, r, dia),
            onQuitar: (r) => onChanged([...horarios]..remove(r)),
            onAgregar: () => _editarRango(context, null, dia),
            color: p.accent,
          ),
      ],
    );
  }
}

class _FilaDia extends StatelessWidget {
  const _FilaDia({
    required this.nombre,
    required this.rangos,
    required this.onAlternar,
    required this.onEditar,
    required this.onQuitar,
    required this.onAgregar,
    required this.color,
  });

  final String nombre;
  final List<HorarioDia> rangos;
  final ValueChanged<bool> onAlternar;
  final ValueChanged<HorarioDia> onEditar;
  final ValueChanged<HorarioDia> onQuitar;
  final VoidCallback onAgregar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activo = rangos.isNotEmpty;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.standard,
      margin: const EdgeInsets.only(bottom: Gap.xs),
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xxs, Gap.xs, Gap.xxs),
      decoration: BoxDecoration(
        color: activo ? color.withValues(alpha: 0.07) : p.surfaceHigh.withValues(alpha: 0.5),
        borderRadius: Radii.rMd,
        border: Border.all(color: activo ? color.withValues(alpha: 0.25) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(nombre, style: context.text.titleSmall?.copyWith(color: activo ? p.text : p.textSecondary))),
            if (!activo) Text('Cerrado', style: context.text.bodySmall),
            Switch(value: activo, onChanged: onAlternar),
          ]),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: !activo
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: Gap.xs),
                    child: Wrap(spacing: Gap.xs, runSpacing: Gap.xs, children: [
                      for (final r in rangos)
                        InputChip(
                          label: Text('${hora12(r.inicio)} – ${hora12(r.fin)}'),
                          onPressed: () => onEditar(r),
                          onDeleted: () => onQuitar(r),
                          deleteButtonTooltipMessage: 'Quitar rango',
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Rango'),
                        tooltip: 'Agregar otro rango (jornada partida)',
                        onPressed: onAgregar,
                      ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}
