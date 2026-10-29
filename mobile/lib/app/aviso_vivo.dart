import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion.dart';
import '../features/citas/citas_en_vivo.dart';
import '../features/citas/citas_screen.dart' show diaCitasProvider;
import 'router.dart';
import 'theme/palette.dart';
import 'theme/tokens.dart';

/// Aviso flotante en la parte superior cuando llega una cita o la cancelan
/// con la app abierta (como las notificaciones dentro de la app de Fresha o
/// Booksy). Está por encima de todas las pantallas; se toca para ir a la cita,
/// se desliza hacia arriba para descartarlo y se oculta solo a los 6 s.
class CapaAvisoVivo extends ConsumerWidget {
  const CapaAvisoVivo({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aviso = ref.watch(avisoVivoProvider);
    final d = Motion.of(context, Motion.slow);
    return Stack(fit: StackFit.expand, children: [
      child,
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedSwitcher(
                duration: d,
                reverseDuration: Motion.of(context, Motion.medium),
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: (c, a) => FadeTransition(
                  opacity: CurvedAnimation(parent: a, curve: const Interval(0, 0.6)),
                  child: SlideTransition(position: Tween(begin: const Offset(0, -0.6), end: Offset.zero).animate(a), child: c),
                ),
                child: aviso == null ? const SizedBox(key: ValueKey('sin-aviso'), width: double.infinity) : _Tarjeta(key: ValueKey(aviso.id), aviso: aviso),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Tarjeta extends ConsumerWidget {
  const _Tarjeta({super.key, required this.aviso});
  final AvisoVivo aviso;

  void _abrir(WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(avisoVivoProvider.notifier).cerrar();
    if (aviso.ruta != null) {
      ref.read(routerProvider).push(aviso.ruta!);
      return;
    }
    if (aviso.fecha != null) ref.read(diaCitasProvider.notifier).set(aviso.fecha!);
    if (aviso.citaId != null) ref.read(citaPorAbrirProvider.notifier).set(aviso.citaId);
    ref.read(routerProvider).go('/citas');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final color = switch (aviso.tipo) {
      TipoAvisoVivo.cancelada => p.danger,
      TipoAvisoVivo.pago => p.info,
      TipoAvisoVivo.nueva => p.success,
    };
    final notifier = ref.read(avisoVivoProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 0),
      child: Dismissible(
        key: ValueKey('aviso-${aviso.id}'),
        direction: DismissDirection.up,
        onDismissed: (_) => notifier.cerrar(),
        child: Semantics(
          liveRegion: true,
          container: true,
          button: true,
          label: '${aviso.titulo}. ${aviso.cuerpo}',
          hint: aviso.tipo == TipoAvisoVivo.pago ? 'Toca para clasificar el pago' : 'Toca para ver la cita',
          excludeSemantics: true,
          child: Listener(
            onPointerDown: (_) => notifier.sostener(),
            onPointerUp: (_) => notifier.soltar(),
            onPointerCancel: (_) => notifier.soltar(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: Radii.rLg,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.14), blurRadius: 28, offset: const Offset(0, 10))],
              ),
              child: Material(
                color: p.surfaceHigh,
                shape: RoundedRectangleBorder(borderRadius: Radii.rLg, side: BorderSide(color: color.withValues(alpha: 0.35))),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _abrir(ref),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.xxs, Gap.sm),
                      child: Row(children: [
                        _Icono(color: color, icono: switch (aviso.tipo) {
                          TipoAvisoVivo.cancelada => Icons.event_busy_rounded,
                          TipoAvisoVivo.pago => Icons.contactless_rounded,
                          TipoAvisoVivo.nueva => Icons.event_available_rounded,
                        }),
                        const HGap.sm(),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text(aviso.titulo, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(aviso.cuerpo, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        // Sin tooltip: esta capa está por encima del Navigator (no hay Overlay).
                        IconButton(
                          onPressed: notifier.cerrar,
                          icon: Icon(Icons.close_rounded, color: p.textSecondary, size: IconSizes.md),
                        ),
                      ]),
                    ),
                    // Tiempo restante del aviso.
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: 0),
                      duration: Motion.reduced(context) ? Duration.zero : AvisoVivoNotifier.duracion,
                      builder: (context, v, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: v,
                          child: Container(height: 3, color: color.withValues(alpha: 0.55)),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ícono con un pulso suave al aparecer.
class _Icono extends StatelessWidget {
  const _Icono({required this.color, required this.icono});
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.of(context, const Duration(milliseconds: 520)),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
        child: Icon(icono, color: color),
      ),
    );
  }
}
