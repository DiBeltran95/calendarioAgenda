import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../dates.dart';
import '../motion.dart';
import '../providers.dart';

/// Datos de una celda del calendario.
class CalendarDay {
  const CalendarDay({required this.fecha, required this.day, required this.isToday, required this.isSelected, required this.isWeekend});
  final String fecha;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool isWeekend;
}

typedef DayCellBuilder = Widget Function(BuildContext context, CalendarDay day);
typedef DaySemantics = String Function(CalendarDay day);

final _base = DateTime(2000, 1);
int _indiceDe(DateTime m) => (m.year - _base.year) * 12 + (m.month - _base.month);
DateTime _mesDe(int i) => DateTime(_base.year, _base.month + i);

/// Calendario mensual deslizable.
///
/// - Se cambia de mes deslizando o con las flechas; el título se anima en la
///   dirección del cambio.
/// - Siempre ocupa 6 filas: el alto no salta al pasar de un mes de 5 a uno de 6.
/// - Toque = seleccionar; mantener presionado = acción rápida (crear).
class MonthCalendar extends ConsumerStatefulWidget {
  const MonthCalendar({
    super.key,
    required this.cursor,
    required this.selected,
    required this.cellBuilder,
    required this.onTap,
    this.onLongPress,
    this.semantics,
    this.footer,
  });

  final NotifierProvider<MonthCursor, DateTime> cursor;
  final String? selected;
  final DayCellBuilder cellBuilder;
  final ValueChanged<String> onTap;
  final ValueChanged<String>? onLongPress;
  final DaySemantics? semantics;
  final Widget? footer;

  @override
  ConsumerState<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<MonthCalendar> {
  late final PageController _page;
  int _direccion = 1;

  @override
  void initState() {
    super.initState();
    _page = PageController(initialPage: _indiceDe(ref.read(widget.cursor)));
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _irA(DateTime mes) {
    if (!_page.hasClients) return;
    final destino = _indiceDe(mes);
    final actual = _page.page?.round() ?? destino;
    if (destino == actual) return;
    if ((destino - actual).abs() > 2 || Motion.reduced(context)) {
      _page.jumpToPage(destino);
    } else {
      _page.animateToPage(destino, duration: const Duration(milliseconds: 380), curve: Motion.enter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mes = ref.watch(widget.cursor);
    ref.listen(widget.cursor, (prev, next) {
      if (prev != null) _direccion = next.isAfter(prev) ? 1 : -1;
      _irA(next);
    });
    final p = context.palette;
    final ahora = DateTime.now();
    final esMesActual = mes.year == ahora.year && mes.month == ahora.month;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Cabecera: mes animado + navegación ──
        Row(
          children: [
            Expanded(
              child: ClipRect(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.medium),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  transitionBuilder: (child, anim) {
                    final entra = child.key == ValueKey(mes);
                    final dx = (entra ? 0.25 : -0.25) * _direccion;
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (c, prev) => Stack(alignment: Alignment.centerLeft, children: [...prev, ?c]),
                  child: Semantics(
                    key: ValueKey(mes),
                    liveRegion: true,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: mesesLargos[mes.month - 1], style: context.text.titleLarge),
                        TextSpan(text: '  ${mes.year}', style: context.text.titleLarge?.copyWith(color: p.textSecondary, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
              child: esMesActual
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () => ref.read(widget.cursor.notifier).hoy(),
                      icon: const Icon(Icons.today_rounded, size: IconSizes.sm),
                      label: const Text('Hoy'),
                    ),
            ),
            IconButton(
              tooltip: 'Mes anterior',
              onPressed: () => ref.read(widget.cursor.notifier).mover(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              tooltip: 'Mes siguiente',
              onPressed: () => ref.read(widget.cursor.notifier).mover(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const VGap.xs(),
        // ── Días de la semana ──
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      diasSemanaIniciales[i],
                      style: context.text.labelSmall?.copyWith(
                        color: i == 0 ? p.danger.withValues(alpha: 0.85) : p.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const VGap.xs(),
        // ── Rejilla deslizable ──
        LayoutBuilder(builder: (context, c) {
          final cellW = c.maxWidth / 7;
          final cellH = (cellW * 0.92).clamp(52.0, 70.0);
          return SizedBox(
            height: cellH * 6,
            child: PageView.builder(
              controller: _page,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                final m = _mesDe(i);
                if (m != ref.read(widget.cursor)) ref.read(widget.cursor.notifier).ir(m);
              },
              itemBuilder: (context, i) => _MesGrid(
                mes: _mesDe(i),
                cellH: cellH,
                selected: widget.selected,
                cellBuilder: widget.cellBuilder,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                semantics: widget.semantics,
              ),
            ),
          );
        }),
        if (widget.footer != null) ...[const VGap.sm(), widget.footer!],
      ],
    );
  }
}

class _MesGrid extends StatelessWidget {
  const _MesGrid({
    required this.mes,
    required this.cellH,
    required this.selected,
    required this.cellBuilder,
    required this.onTap,
    this.onLongPress,
    this.semantics,
  });

  final DateTime mes;
  final double cellH;
  final String? selected;
  final DayCellBuilder cellBuilder;
  final ValueChanged<String> onTap;
  final ValueChanged<String>? onLongPress;
  final DaySemantics? semantics;

  @override
  Widget build(BuildContext context) {
    final hoy = hoyYmd();
    final offset = DateTime(mes.year, mes.month, 1).weekday % 7; // domingo = 0
    final total = diasDelMes(mes.year, mes.month);
    return Column(
      children: [
        for (var fila = 0; fila < 6; fila++)
          SizedBox(
            height: cellH,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: () {
                      final n = fila * 7 + col - offset + 1;
                      if (n < 1 || n > total) return const SizedBox.shrink();
                      final fecha = ymd(DateTime(mes.year, mes.month, n));
                      final day = CalendarDay(
                        fecha: fecha,
                        day: n,
                        isToday: fecha == hoy,
                        isSelected: fecha == selected,
                        isWeekend: col == 0 || col == 6,
                      );
                      return Semantics(
                        button: true,
                        selected: day.isSelected,
                        label: semantics?.call(day) ?? fechaConDia(fecha),
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onTap(fecha);
                          },
                          onLongPress: onLongPress == null
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  onLongPress!(fecha);
                                },
                          child: Padding(padding: const EdgeInsets.all(2.5), child: cellBuilder(context, day)),
                        ),
                      );
                    }(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Marco visual común de una celda: número, relleno, anillo, marcadores.
class DayCellFrame extends StatelessWidget {
  const DayCellFrame({
    super.key,
    required this.day,
    this.fill,
    this.ring,
    this.numberColor,
    this.markers,
    this.corner,
    this.fillOpacity,
    this.strong = false,
  });

  final CalendarDay day;

  /// Color de fondo (fase del ciclo, festivo...).
  final Color? fill;
  final double? fillOpacity;

  /// Contorno (p. ej. periodo previsto).
  final Color? ring;
  final Color? numberColor;

  /// Fila de marcadores bajo el número.
  final Widget? markers;

  /// Icono pequeño en la esquina superior derecha.
  final Widget? corner;

  /// Relleno sólido (texto sobre color) en vez de tinte suave.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sel = day.isSelected;
    final bg = fill == null
        ? (sel ? p.accent.withValues(alpha: 0.12) : Colors.transparent)
        : strong
            ? fill!
            : fill!.withValues(alpha: fillOpacity ?? (context.isDark ? 0.2 : 0.16));
    final numColor = numberColor ??
        (strong ? textoSobre(fill!) : (day.isWeekend && fill == null ? p.text.withValues(alpha: 0.8) : p.text));

    return AnimatedContainer(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.enter,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        border: Border.all(
          color: sel ? p.accent : (ring ?? Colors.transparent),
          width: sel ? 2 : 1.4,
        ),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: Motion.of(context, Motion.medium),
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: day.isToday ? p.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day.day}',
                  style: context.text.labelLarge?.copyWith(
                    fontWeight: day.isToday || sel ? FontWeight.w800 : FontWeight.w600,
                    color: day.isToday ? p.onAccent : numColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(height: 16, child: markers == null ? null : Center(child: FittedBox(fit: BoxFit.scaleDown, child: markers))),
            ],
          ),
          if (corner != null) Positioned(top: 3, right: 3, child: corner!),
        ],
      ),
    );
  }
}

/// Punto de color para marcadores.
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 6});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
