import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/providers.dart';
import '../data/sync.dart';
import '../features/notifications/notification_service.dart';
import '../features/notifications/push_registro.dart';
import '../features/notifications/refresco_fondo.dart';
import 'theme/app_module.dart';
import 'theme/palette.dart';
import 'theme/tokens.dart';

class _Destino {
  const _Destino(this.label, this.icon, this.iconSel, this.module);
  final String label;
  final IconData icon;
  final IconData iconSel;
  final AppModule? module;
}

/// Orden de las pestañas (coincide con las ramas del router).
final _destinos = [
  for (final m in [AppModule.inicio, AppModule.eventos, AppModule.citas, AppModule.finanzas, AppModule.ciclo]) _Destino(m.label, m.icon, m.iconSelected, m),
];

/// Contenedor principal: navegación inferior en teléfono y riel lateral en
/// pantallas anchas. Al cambiar de módulo el tema global interpola su color.
///
/// También mantiene viva la programación de notificaciones y refresca los
/// datos cuando la app vuelve a primer plano.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: () {
      ref.read(sincronizadorProvider).refrescarTodo();
      ref.read(permisoAvisosProvider.notifier).revisar();
      ref.read(registroPushProvider).sincronizar();
    });
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  void _ir(int i) {
    HapticFeedback.selectionClick();
    final m = _destinos[i].module;
    if (m != null) ref.read(moduloActivoProvider.notifier).set(m);
    widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Programación de notificaciones siempre activa mientras hay sesión.
    ref.watch(programadorAvisosProvider);
    ref.watch(sincronizadorPushProvider);
    ref.watch(refrescoFondoProvider);

    final shell = widget.shell;
    final m = _destinos[shell.currentIndex].module;
    if (m != null && ref.read(moduloActivoProvider) != m) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(moduloActivoProvider.notifier).set(m));
    }

    final wide = MediaQuery.sizeOf(context).width >= 980;
    final p = context.palette;
    final cuerpo = Column(children: [const _BannerRed(), Expanded(child: shell)]);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _ir,
              labelType: NavigationRailLabelType.all,
              backgroundColor: p.surface,
              indicatorColor: p.accent.withValues(alpha: 0.2),
              selectedIconTheme: IconThemeData(color: p.accent),
              unselectedIconTheme: IconThemeData(color: p.textSecondary),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/images/logo.png', width: 44, height: 44, semanticLabel: 'Agendaservi'),
                ),
              ),
              destinations: [
                for (final d in _destinos)
                  NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.iconSel), label: Text(d.label)),
              ],
            ),
            VerticalDivider(width: 1, color: p.border),
            Expanded(child: cuerpo),
          ],
        ),
      );
    }

    return Scaffold(
      body: cuerpo,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _ir,
          animationDuration: Motion.of(context, Motion.slow),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final d in _destinos) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.iconSel), label: d.label),
          ],
        ),
      ),
    );
  }
}

/// Aviso discreto cuando el servidor no responde: la app sigue mostrando lo
/// guardado en el teléfono y ofrece reintentar.
class _BannerRed extends ConsumerWidget {
  const _BannerRed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final offline = ref.watch(redProvider) == EstadoRed.sinConexion;
    return AnimatedSize(
      duration: Motion.of(context, Motion.medium),
      curve: Motion.enter,
      child: !offline
          ? const SizedBox(width: double.infinity)
          : Material(
              color: Color.alphaBlend(p.warning.withValues(alpha: 0.16), p.bg),
              child: SafeArea(
                bottom: false,
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.xs, Gap.xs),
                    child: Row(children: [
                      Icon(Icons.cloud_off_rounded, color: p.warning, size: IconSizes.md),
                      const HGap.sm(),
                      Expanded(child: Text('Sin conexión · mostrando lo guardado en tu teléfono', style: context.text.bodySmall?.copyWith(color: p.text))),
                      TextButton(onPressed: () => ref.read(sincronizadorProvider).refrescarTodo(), child: const Text('Reintentar')),
                    ]),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Muestra la rama activa con un "fade through" (desvanecer + escala sutil),
/// conservando el estado de todas las ramas (scroll, día seleccionado...).
///
/// Cuando termina la transición, la rama saliente pasa a `Offstage`: deja de
/// medirse y pintarse (como un IndexedStack), pero mantiene su estado.
class AnimatedBranches extends StatefulWidget {
  const AnimatedBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<AnimatedBranches> createState() => _AnimatedBranchesState();
}

class _AnimatedBranchesState extends State<AnimatedBranches> {
  int? _saliente;

  @override
  void didUpdateWidget(AnimatedBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _saliente = old.index;
  }

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, const Duration(milliseconds: 300));
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          Offstage(
            offstage: i != widget.index && i != _saliente,
            child: IgnorePointer(
              ignoring: i != widget.index,
              child: ExcludeSemantics(
                excluding: i != widget.index,
                // Opacidad y escala van FUERA del TickerMode: si quedaran
                // dentro, la rama saliente congelaría su fundido.
                child: AnimatedOpacity(
                  opacity: i == widget.index ? 1 : 0,
                  duration: d,
                  curve: i == widget.index ? const Interval(0.35, 1, curve: Motion.standard) : const Interval(0, 0.35),
                  onEnd: () {
                    if (i == _saliente && mounted) setState(() => _saliente = null);
                  },
                  child: AnimatedScale(
                    scale: i == widget.index ? 1 : 0.97,
                    duration: d,
                    curve: Motion.enter,
                    child: TickerMode(enabled: i == widget.index, child: widget.children[i]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
