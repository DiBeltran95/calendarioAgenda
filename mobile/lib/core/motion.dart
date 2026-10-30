import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/theme/palette.dart';
import '../app/theme/tokens.dart';
import 'money.dart';

/// Tokens de movimiento: toda la app comparte el mismo ritmo.
///
/// - Micro-interacciones 150–250 ms, transiciones complejas ≤ 420 ms.
/// - Entrar desacelera (ease-out enfatizado); salir acelera y es más corto.
abstract final class Motion {
  static const fast = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  /// Curvas "emphasized" de Material 3.
  static const enter = Cubic(0.05, 0.7, 0.1, 1.0);
  static const exit = Cubic(0.3, 0.0, 0.8, 0.15);
  static const standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Resorte suave para lo que sigue al dedo o entra con inercia (hojas).
  static const resorte = SpringDescription(mass: 1, stiffness: 340, damping: 32);

  /// Retraso entre elementos de una lista escalonada.
  static const stagger = Duration(milliseconds: 40);

  /// true si el usuario pidió reducir el movimiento (sistema o ajustes).
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Duración efectiva: cero cuando el movimiento está reducido.
  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}

/// Entrada escalonada (fade + desplazamiento corto hacia arriba).
///
/// Se limita el retraso acumulado para que una lista larga no tarde en
/// aparecer: a partir del elemento 8 todos entran a la vez.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.index = 0, this.offset = 0.06, this.delay = Duration.zero});

  final Widget child;
  final int index;
  final double offset;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    final d = delay + Motion.stagger * index.clamp(0, 8);
    return child
        .animate(delay: d)
        .fadeIn(duration: Motion.medium, curve: Motion.enter)
        .slideY(begin: offset, end: 0, duration: Motion.slow, curve: Motion.enter);
  }
}

/// Superficie pulsable con respuesta táctil: escala sutil (0.97), feedback
/// háptico ligero y semántica de botón. No cambia el tamaño del layout.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.semanticLabel,
    this.scale = 0.97,
    this.borderRadius,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final String? semanticLabel;
  final double scale;
  final BorderRadius? borderRadius;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null || widget.onDoubleTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onDoubleTap: widget.onDoubleTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onDoubleTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                _set(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Motion.of(context, _down ? const Duration(milliseconds: 90) : Motion.fast),
          curve: _down ? Motion.exit : Motion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Cifra en pesos que "cuenta" hasta su valor cuando cambia.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, this.style, this.signed = false});

  final double value;
  final TextStyle? style;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.of(context, const Duration(milliseconds: 700)),
      curve: Motion.enter,
      builder: (_, v, _) => Text(
        signed ? copConSigno(v) : cop(v),
        style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Barra de progreso redondeada que se llena con animación.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color, this.height = 8, this.background});

  /// 0..1 (se recorta).
  final double value;
  final Color? color;
  final Color? background;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: background ?? p.surfaceHighest,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.isNaN ? 0 : value.clamp(0, 1).toDouble()),
          duration: Motion.of(context, const Duration(milliseconds: 650)),
          curve: Motion.enter,
          builder: (_, v, _) => FractionallySizedBox(
            widthFactor: v,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color ?? p.accent,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cambia de contenido con un fundido + desplazamiento corto (fade-through).
class SmoothSwitcher extends StatelessWidget {
  const SmoothSwitcher({super.key, required this.child, this.axis = Axis.vertical, this.offset = 0.04});

  final Widget child;
  final Axis axis;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      reverseDuration: Motion.of(context, Motion.fast),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, anim) {
        final slide = Tween<Offset>(
          begin: axis == Axis.vertical ? Offset(0, offset) : Offset(offset, 0),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: child));
      },
      child: child,
    );
  }
}

/// Pequeño ícono dentro de un círculo tintado.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color, this.size = 40, this.iconSize});

  final IconData icon;
  final Color? color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.accent;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: c, size: iconSize ?? size * 0.5),
    );
  }
}

/// Espaciadores con nombre, para que el ritmo de 8 dp se lea en el código.
class VGap extends SizedBox {
  const VGap(double h, {super.key}) : super(height: h);
  const VGap.xs({super.key}) : super(height: Gap.xs);
  const VGap.sm({super.key}) : super(height: Gap.sm);
  const VGap.md({super.key}) : super(height: Gap.md);
  const VGap.lg({super.key}) : super(height: Gap.lg);
  const VGap.xl({super.key}) : super(height: Gap.xl);
}

class HGap extends SizedBox {
  const HGap(double w, {super.key}) : super(width: w);
  const HGap.xs({super.key}) : super(width: Gap.xs);
  const HGap.sm({super.key}) : super(width: Gap.sm);
  const HGap.md({super.key}) : super(width: Gap.md);
}
