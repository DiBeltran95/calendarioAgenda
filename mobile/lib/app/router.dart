import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/providers.dart';
import '../features/cycle/cycle_screen.dart';
import '../features/events/events_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/welcome_screen.dart';
import 'module_theme.dart';
import 'shell.dart';
import 'theme/app_module.dart';

CustomTransitionPage<void> _fade(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, a, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Motion.standard),
        child: c,
      ),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ValueNotifier<Preferencias?>(null);
  ref.listen(preferenciasProvider, (_, next) => prefs.value = next.value, fireImmediately: true);

  final router = GoRouter(
    initialLocation: '/eventos',
    refreshListenable: prefs,
    redirect: (context, state) {
      final p = prefs.value;
      final loc = state.matchedLocation;
      if (p == null) return loc == '/inicio' ? null : '/inicio';
      if (!p.bienvenidaVista) return loc == '/bienvenida' ? null : '/bienvenida';
      if (loc == '/inicio' || loc == '/bienvenida') return '/eventos';
      return null;
    },
    routes: [
      GoRoute(path: '/inicio', pageBuilder: (c, s) => _fade(const SplashScreen(), s)),
      GoRoute(path: '/bienvenida', pageBuilder: (c, s) => _fade(const WelcomeScreen(), s)),
      StatefulShellRoute(
        builder: (context, state, shell) => HomeShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) => AnimatedBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/eventos', builder: (c, s) => const ModuleTheme(module: AppModule.eventos, child: EventsScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ciclo', builder: (c, s) => const ModuleTheme(module: AppModule.ciclo, child: CycleScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/finanzas', builder: (c, s) => const ModuleTheme(module: AppModule.finanzas, child: FinanceScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ajustes', builder: (c, s) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    prefs.dispose();
  });
  return router;
});
