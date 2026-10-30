import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import 'theme/palette.dart';
import 'theme/tokens.dart';

/// Un destino de la barra inferior.
class DestinoBarra {
  const DestinoBarra({required this.etiqueta, required this.icono, required this.iconoSel});
  final String etiqueta;
  final IconData icono;
  final IconData iconoSel;
}

/// Barra de navegación flotante: cápsula translúcida sobre el contenido, con
/// un indicador que se desliza hasta la pestaña elegida.
class BarraFlotante extends StatelessWidget {
  const BarraFlotante({super.key, required this.destinos, required this.seleccionado, required this.onElegir});

  final List<DestinoBarra> destinos;
  final int seleccionado;
  final ValueChanged<int> onElegir;

  static const alto = 64.0;

  /// Margen inferior: el área segura del sistema o, si no hay, un respiro.
  static double margenInferior(BuildContext context) {
    final seguro = MediaQuery.viewPaddingOf(context).bottom;
    return seguro > 0 ? seguro : Gap.sm;
  }

  /// Espacio que la barra ocupa desde el borde inferior de la pantalla.
  static double espacio(BuildContext context) => alto + margenInferior(context);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radio = BorderRadius.circular(Radii.lg);
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, margenInferior(context)),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: radio, boxShadow: p.sombraFlotante),
            child: ClipRRect(
              borderRadius: radio,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: alto,
                  padding: const EdgeInsets.all(Gap.xxs),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: context.isDark ? 0.80 : 0.86),
                    borderRadius: radio,
                    border: Border.all(color: p.border),
                  ),
                  child: LayoutBuilder(builder: (context, c) {
                    final ancho = c.maxWidth / destinos.length;
                    return Stack(children: [
                      AnimatedPositioned(
                        duration: Motion.of(context, Motion.medium),
                        curve: Motion.standard,
                        left: ancho * seleccionado,
                        top: 0,
                        bottom: 0,
                        width: ancho,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: context.isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(Radii.lg - Gap.xxs),
                          ),
                        ),
                      ),
                      Row(children: [
                        for (final (i, d) in destinos.indexed)
                          Expanded(child: _Pestana(destino: d, activa: i == seleccionado, onTap: () => onElegir(i))),
                      ]),
                    ]);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({required this.destino, required this.activa, required this.onTap});
  final DestinoBarra destino;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = activa ? p.accent : p.textSecondary;
    return Semantics(
      button: true,
      selected: activa,
      label: destino.etiqueta,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        haptic: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: Icon(activa ? destino.iconoSel : destino.icono, key: ValueKey(activa), color: color, size: IconSizes.lg),
            ),
            const SizedBox(height: 2),
            // La etiqueta se ajusta al ancho en vez de cortarse con texto grande.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.xxs),
                child: Text(
                  destino.etiqueta,
                  maxLines: 1,
                  style: context.text.labelSmall?.copyWith(color: color, fontWeight: activa ? FontWeight.w700 : FontWeight.w500, letterSpacing: 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
