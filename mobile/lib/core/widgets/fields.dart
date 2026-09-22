import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../dates.dart';
import '../money.dart';
import '../motion.dart';

/// Etiqueta visible encima de un control (nunca solo placeholder).
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.xs, top: Gap.md),
      child: Text.rich(TextSpan(
        text: text,
        style: context.text.labelMedium?.copyWith(color: p.text, fontWeight: FontWeight.w600),
        children: [if (required) TextSpan(text: ' *', style: TextStyle(color: p.danger))],
      )),
    );
  }
}

/// Formatea con separador de miles mientras se escribe (1.250.000).
class _MilesFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final txt = miles(int.parse(digits.length > 15 ? digits.substring(0, 15) : digits));
    return TextEditingValue(text: txt, selection: TextSelection.collapsed(offset: txt.length));
  }
}

double parseMonto(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

String montoInicial(double v) => v <= 0 ? '' : miles(v.round());

/// Campo de dinero en pesos con teclado numérico y miles automáticos.
class MoneyField extends StatelessWidget {
  const MoneyField({super.key, required this.controller, this.label, this.hint = '0', this.autofocus = false, this.validator, this.big = false});

  final TextEditingController controller;
  final String? label;
  final String hint;
  final bool autofocus;
  final bool big;
  final String? Function(double)? validator;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [_MilesFormatter()],
      style: (big ? context.text.headlineSmall : context.text.titleMedium)?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: Gap.md, right: Gap.xs),
          child: Text(r'$', style: (big ? context.text.headlineSmall : context.text.titleMedium)?.copyWith(color: p.textSecondary)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: validator == null ? null : (v) => validator!(parseMonto(v ?? '')),
    );
  }
}

/// Selector de fecha que muestra "Jueves, 5 de marzo".
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged, this.first, this.last, this.label});

  final String value;
  final ValueChanged<String> onChanged;
  final DateTime? first;
  final DateTime? last;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _TapField(
      icon: Icons.calendar_today_rounded,
      text: '${fechaConDia(value)} ${parseYmd(value).year}',
      label: label,
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: parseYmd(value),
          firstDate: first ?? DateTime(2000),
          lastDate: last ?? DateTime(2100),
          locale: const Locale('es', 'CO'),
        );
        if (d != null) onChanged(ymd(d));
      },
      trailing: Icon(Icons.expand_more_rounded, color: p.textSecondary),
    );
  }
}

/// Selector de hora (HH:mm) o vacío.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _TapField(
      icon: Icons.schedule_rounded,
      text: value == null ? 'Elegir hora' : hora12(value),
      muted: value == null,
      onTap: () async {
        final parts = (value ?? '08:00').split(':');
        final t = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
        );
        if (t != null) onChanged('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      },
      trailing: value == null
          ? Icon(Icons.expand_more_rounded, color: p.textSecondary)
          : IconButton(tooltip: 'Quitar hora', onPressed: () => onChanged(null), icon: const Icon(Icons.close_rounded, size: IconSizes.md)),
    );
  }
}

class _TapField extends StatelessWidget {
  const _TapField({required this.icon, required this.text, required this.onTap, this.trailing, this.label, this.muted = false});

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: p.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd, side: BorderSide(color: p.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: Padding(
              padding: const EdgeInsets.only(left: Gap.md, right: Gap.xs),
              child: Row(
                children: [
                  Icon(icon, size: IconSizes.md, color: p.accent),
                  const HGap.sm(),
                  Expanded(
                    child: Text(text, style: context.text.bodyLarge?.copyWith(color: muted ? p.textSecondary : p.text)),
                  ),
                  if (trailing != null) trailing! else const SizedBox(width: Gap.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Control segmentado con indicador que se desliza entre opciones.
class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({super.key, required this.options, required this.value, required this.onChanged, this.colors});

  final List<(T, String, IconData?)> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Color del indicador por opción (si no, el acento).
  final Map<T, Color>? colors;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final idx = options.indexWhere((o) => o.$1 == value).clamp(0, options.length - 1);
    final color = colors?[value] ?? p.accent;
    return LayoutBuilder(builder: (context, c) {
      // Ancho útil = ancho total menos el padding de 4 a cada lado.
      final w = (c.maxWidth - 8) / options.length;
      return Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd, border: Border.all(color: p.border)),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              left: idx * w,
              top: 0,
              bottom: 0,
              width: w,
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.medium),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: context.isDark ? 0.22 : 0.16),
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
              ),
            ),
            Row(
              children: [
                for (final o in options)
                  Expanded(
                    child: Semantics(
                      selected: o.$1 == value,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(o.$1);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.of(context, Motion.fast),
                            style: context.text.labelLarge!.copyWith(
                              color: o.$1 == value ? (colors?[o.$1] ?? p.accent) : p.textSecondary,
                              fontSize: 13.5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (o.$3 != null) ...[
                                  Icon(o.$3, size: IconSizes.sm, color: o.$1 == value ? (colors?[o.$1] ?? p.accent) : p.textSecondary),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(child: Text(o.$2, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}

/// Grupo de chips de selección única que se ajusta en varias líneas.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.value, required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Gap.xs,
      runSpacing: Gap.xs,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: o.$1 == value,
            showCheckmark: false,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onChanged(o.$1);
            },
          ),
      ],
    );
  }
}

/// Contador +/- para enteros pequeños (días de sangrado, cuotas...).
class StepperField extends StatelessWidget {
  const StepperField({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 99, this.suffix = ''});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget btn(IconData i, int delta, String tip) => IconButton.filledTonal(
          tooltip: tip,
          onPressed: (value + delta < min || value + delta > max)
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onChanged(value + delta);
                },
          icon: Icon(i),
          style: IconButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: p.surfaceHighest),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: Radii.rMd, border: Border.all(color: p.border)),
      child: Row(
        children: [
          btn(Icons.remove_rounded, -1, 'Menos'),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
                child: Text('$value$suffix', key: ValueKey(value), style: context.text.titleLarge),
              ),
            ),
          ),
          btn(Icons.add_rounded, 1, 'Más'),
        ],
      ),
    );
  }
}
