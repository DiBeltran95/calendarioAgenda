import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';

/// Lluvia breve de confeti al cumplir una meta. No bloquea la interacción y
/// se omite si el usuario pidió reducir el movimiento.
void celebrar(BuildContext context) {
  if (Motion.reduced(context)) return;
  HapticFeedback.heavyImpact();
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Confeti(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _Particula {
  _Particula(math.Random r)
      : x = 0.5 + (r.nextDouble() - 0.5) * 0.3,
        vx = (r.nextDouble() - 0.5) * 1.4,
        vy = -(0.9 + r.nextDouble() * 0.9),
        giro = r.nextDouble() * math.pi,
        vGiro = (r.nextDouble() - 0.5) * 12,
        tam = 6 + r.nextDouble() * 6,
        color = _colores[r.nextInt(_colores.length)];

  final double x, vx, vy, giro, vGiro, tam;
  final Color color;

  static const _colores = [
    Color(0xFF34D399), Color(0xFF60A5FA), Color(0xFFF472B6), Color(0xFFFBBF24), Color(0xFFA78BFA), Color(0xFFF87171),
  ];
}

class _Confeti extends StatefulWidget {
  const _Confeti({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_Confeti> createState() => _ConfetiState();
}

class _ConfetiState extends State<_Confeti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward().whenComplete(widget.onDone);
  final _particulas = List.generate(90, (_) => _Particula(math.Random()));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(size: Size.infinite, painter: _ConfetiPainter(_particulas, _c.value)),
      ),
    );
  }
}

class _ConfetiPainter extends CustomPainter {
  _ConfetiPainter(this.ps, this.t);
  final List<_Particula> ps;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const gravedad = 2.4;
    final opacidad = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);
    for (final p in ps) {
      final dx = (p.x + p.vx * t * 0.5) * size.width;
      final dy = size.height * 0.55 + (p.vy * t + 0.5 * gravedad * t * t) * size.height * 0.5;
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.giro + p.vGiro * t);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.tam, height: p.tam * 0.55),
        Paint()..color = p.color.withValues(alpha: opacidad),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfetiPainter old) => old.t != t;
}
