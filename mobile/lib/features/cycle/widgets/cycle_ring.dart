import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/motion.dart';
import '../cycle_engine.dart';

Color colorFase(Fase f) => switch (f) {
      Fase.periodo => PhaseColors.period,
      Fase.periodoPrevisto => PhaseColors.predicted,
      Fase.periodoRetrasado => PhaseColors.late,
      Fase.ovulacion => PhaseColors.ovulation,
      Fase.fertil => PhaseColors.fertile,
      Fase.folicular => PhaseColors.follicular,
      Fase.lutea => PhaseColors.luteal,
    };

IconData iconoFase(Fase f) => switch (f) {
      Fase.periodo => Icons.water_drop_rounded,
      Fase.periodoPrevisto => Icons.water_drop_outlined,
      Fase.periodoRetrasado => Icons.hourglass_bottom_rounded,
      Fase.ovulacion => Icons.auto_awesome_rounded,
      Fase.fertil => Icons.local_florist_rounded,
      Fase.folicular => Icons.trending_up_rounded,
      Fase.lutea => Icons.nightlight_round,
    };

/// Rueda del ciclo: cada día es un segmento coloreado según su fase y un
/// marcador recorre la rueda hasta el día consultado.
///
/// Animaciones: los segmentos se "dibujan" al aparecer y el marcador viaja
/// con una curva suave cuando cambia el día seleccionado.
class CycleRing extends StatelessWidget {
  const CycleRing({super.key, required this.details, this.size = 220});

  final CycleDetails details;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = details;
    final color = colorFase(d.fase);
    return Semantics(
      label: 'Día ${d.diaDelCiclo} de ${d.duracionCiclo}. ${d.fase.nombre}.',
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          // Dibujo inicial de los segmentos.
          tween: Tween(begin: 0, end: 1),
          duration: Motion.of(context, const Duration(milliseconds: 900)),
          curve: Motion.enter,
          builder: (context, reveal, _) => TweenAnimationBuilder<double>(
            // El marcador viaja al nuevo día.
            tween: Tween(end: (d.diaDelCiclo - 0.5) / d.duracionCiclo),
            duration: Motion.of(context, const Duration(milliseconds: 650)),
            curve: Curves.easeInOutCubic,
            builder: (context, pos, _) => CustomPaint(
              painter: _RingPainter(
                total: d.duracionCiclo,
                sangrado: math.min(d.diasSangrado, d.duracionCiclo),
                ovulacion: d.diaOvulacion,
                faseActual: d.fase,
                posicion: pos,
                reveal: reveal,
                track: p.surfaceHighest,
                markerRing: p.surface,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('DÍA', style: context.text.labelSmall?.copyWith(letterSpacing: 2)),
                    AnimatedSwitcher(
                      duration: Motion.of(context, Motion.medium),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: c),
                      ),
                      child: Text(
                        '${d.diaDelCiclo}',
                        key: ValueKey(d.diaDelCiclo),
                        style: context.text.displaySmall?.copyWith(fontSize: 52, height: 1, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('de ${d.duracionCiclo}', style: context.text.bodySmall),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.medium),
                      constraints: BoxConstraints(maxWidth: size * 0.62),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoFase(d.fase), size: 14, color: color),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              d.fase.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.total,
    required this.sangrado,
    required this.ovulacion,
    required this.faseActual,
    required this.posicion,
    required this.reveal,
    required this.track,
    required this.markerRing,
  });

  final int total;
  final int sangrado;
  final int ovulacion;
  final Fase faseActual;
  final double posicion;
  final double reveal;
  final Color track;
  final Color markerRing;

  Color _colorDia(int dia) {
    if (dia <= sangrado) {
      return faseActual == Fase.periodoPrevisto
          ? PhaseColors.predicted
          : faseActual == Fase.periodoRetrasado
              ? PhaseColors.late
              : PhaseColors.period;
    }
    if (dia == ovulacion) return PhaseColors.ovulation;
    if (dia >= ovulacion - 5 && dia <= ovulacion + 1) return PhaseColors.fertile;
    if (dia < ovulacion - 5) return PhaseColors.follicular;
    return PhaseColors.luteal;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(center, radius, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);

    final seg = 2 * math.pi / total;
    final gap = math.min(0.035, seg * 0.25);
    final visibles = (total * reveal).ceil();
    for (var i = 0; i < visibles; i++) {
      final dia = i + 1;
      final paint = Paint()
        ..color = _colorDia(dia).withValues(alpha: dia <= sangrado || dia == ovulacion ? 1 : 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, -math.pi / 2 + i * seg + gap / 2, seg - gap, false, paint);
    }

    // Marcador del día.
    final ang = -math.pi / 2 + posicion * 2 * math.pi;
    final m = center + Offset(math.cos(ang), math.sin(ang)) * radius;
    final c = _colorDia(((posicion * total).floor() + 1).clamp(1, total));
    canvas.drawCircle(m, 16, Paint()..color = c.withValues(alpha: 0.28 * reveal));
    canvas.drawCircle(m, 11, Paint()..color = markerRing);
    canvas.drawCircle(m, 8, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.posicion != posicion || old.reveal != reveal || old.total != total || old.sangrado != sangrado ||
      old.ovulacion != ovulacion || old.track != track || old.faseActual != faseActual;
}
