import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/net/tiempo_real.dart';
import '../core/providers.dart';
import '../core/widgets/sheets.dart';
import '../data/sync.dart';
import '../features/citas/citas_en_vivo.dart';
import '../features/finance/pagos/pagos_repository.dart';
import '../features/notifications/notification_service.dart';
import '../features/notifications/push_registro.dart';
import '../features/notifications/refresco_fondo.dart';
import 'barra_flotante.dart';
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
  void didUpdateWidget(HomeShell old) {
    super.didUpdateWidget(old);
    if (old.shell.currentIndex != widget.shell.currentIndex) _activarSiOculto();
  }

  /// Un enlace o notificación llevó a un módulo oculto: se muestra de nuevo,
  /// porque lo que la persona abrió pertenece a él.
  void _activarSiOculto() {
    final m = _destinos[widget.shell.currentIndex].module;
    final prefs = ref.read(preferenciasProvider).value;
    final elegidos = prefs?.modulos;
    if (m == null || elegidos == null || ref.read(modulosActivosProvider).contains(m)) return;
    ref.read(ajustesRepoProvider).setModulos({...elegidos, m});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) toast(context, 'Activamos ${m.label} para mostrarte esto.', icon: m.iconSelected);
    });
  }

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onResume: () {
        ref.read(sincronizadorProvider).refrescarTodo();
        ref.read(permisoAvisosProvider.notifier).revisar();
        ref.read(registroPushProvider).sincronizar();
        // Reabre el canal en vivo (y sincroniza lo que llegó mientras tanto).
        ref.read(tiempoRealProvider).reanudar();
        // Pagos que el teléfono leyó de los bancos mientras tanto (Android).
        ref.read(pagosRepoProvider).sincronizarAndroid();
      },
      // En segundo plano no se mantiene la conexión: allí avisan los push.
      onPause: () => ref.read(tiempoRealProvider).pausar(),
    );
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
    // Al entrar a Citas se trae lo último (por si el canal en vivo se perdió algo).
    if (m == AppModule.citas) ref.read(citasEnVivoProvider).refrescar();
    widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    // Programación de notificaciones siempre activa mientras hay sesión.
    ref.watch(programadorAvisosProvider);
    ref.watch(sincronizadorPushProvider);
    ref.watch(refrescoFondoProvider);
    // Cambios en vivo del servidor (citas nuevas o canceladas al instante).
    ref.watch(canalVivoProvider);
    ref.watch(citasEnVivoProvider);
    ref.watch(pagosEnVivoProvider);
    final activos = ref.watch(modulosActivosProvider);
    ref.listen(preferenciasProvider, (antes, ahora) {
      if (!ahora.hasValue) return;
      if (antes?.hasValue != true) {
        // Las preferencias acaban de cargar (app abierta desde un enlace).
        _activarSiOculto();
      } else {
        // Se apagó el módulo en el que estaba parado: vuelve a Hoy.
        final actual = _destinos[widget.shell.currentIndex].module;
        if (actual != null && !ref.read(modulosActivosProvider).contains(actual)) widget.shell.goBranch(0);
      }
    });

    final shell = widget.shell;
    final m = _destinos[shell.currentIndex].module;
    if (m != null && ref.read(moduloActivoProvider) != m) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(moduloActivoProvider.notifier).set(m));
    }

    final wide = MediaQuery.sizeOf(context).width >= 980;
    final p = context.palette;
    final cuerpo = Column(children: [const _BannerRed(), Expanded(child: shell)]);
    // Índices de rama de las pestañas visibles, en orden.
    final visibles = [
      for (var i = 0; i < _destinos.length; i++)
        if (_destinos[i].module == null || activos.contains(_destinos[i].module)) i,
    ];
    final elegida = visibles.indexOf(shell.currentIndex).clamp(0, visibles.length - 1);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: elegida,
              onDestinationSelected: (i) => _ir(visibles[i]),
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
                for (final i in visibles)
                  NavigationRailDestination(icon: Icon(_destinos[i].icon), selectedIcon: Icon(_destinos[i].iconSel), label: Text(_destinos[i].label)),
              ],
            ),
            VerticalDivider(width: 1, color: p.border),
            Expanded(child: cuerpo),
          ],
        ),
      );
    }

    // La barra flota sobre el contenido: cada pantalla la recibe como área
    // segura, así sus botones flotantes y avisos quedan por encima de ella.
    final mq = MediaQuery.of(context);
    final espacio = BarraFlotante.espacio(context);
    final teclado = mq.viewInsets.bottom > 0;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MediaQuery(
              data: teclado ? mq : mq.copyWith(padding: mq.padding.copyWith(bottom: espacio), viewPadding: mq.viewPadding.copyWith(bottom: espacio)),
              child: cuerpo,
            ),
          ),
          if (!teclado)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: BarraFlotante(
                  seleccionado: elegida,
                  onElegir: (i) => _ir(visibles[i]),
                  destinos: [
                    for (final i in visibles) DestinoBarra(etiqueta: _destinos[i].label, icono: _destinos[i].icon, iconoSel: _destinos[i].iconSel),
                  ],
                ),
              ),
            ),
        ],
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
