import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/session.dart';
import '../features/auth/auth_screens.dart';
import '../features/cycle/cycle_screen.dart';
import '../features/events/events_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/home/today_screen.dart';
import '../features/settings/settings_screen.dart';
import 'module_theme.dart';
import 'shell.dart';
import 'theme/app_module.dart';

CustomTransitionPage<void> _fade(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, a, _, c) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Motion.standard),
        child: c,
      ),
    );

/// Transición "shared axis" horizontal entre login, registro y verificación.
CustomTransitionPage<void> _eje(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, a, sa, c) {
        final entra = CurvedAnimation(parent: a, curve: Motion.enter);
        final sale = CurvedAnimation(parent: sa, curve: Motion.exit);
        return FadeTransition(
          opacity: entra,
          child: SlideTransition(
            position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(entra),
            child: FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.0).animate(sale),
              child: SlideTransition(position: Tween(begin: Offset.zero, end: const Offset(-0.06, 0)).animate(sale), child: c),
            ),
          ),
        );
      },
    );

const _rutasAuth = {'/login', '/registro', '/verificar'};

/// Destino pedido antes de tener la sesión lista (p. ej. al abrir la app
/// tocando una notificación): se respeta en cuanto termina la carga.
class RutaPendiente extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? r) => state = r;
}

final rutaPendienteProvider = NotifierProvider<RutaPendiente, String?>(RutaPendiente.new);

final routerProvider = Provider<GoRouter>((ref) {
  // Estado de sesión como Listenable para que el router reevalúe redirecciones.
  final sesion = ValueNotifier<AsyncValue<Sesion?>>(const AsyncLoading());
  ref.listen(sesionProvider, (_, next) => sesion.value = next, fireImmediately: true);

  final router = GoRouter(
    initialLocation: '/hoy',
    refreshListenable: sesion,
    redirect: (context, state) {
      final s = sesion.value;
      final loc = state.matchedLocation;
      if (s.isLoading && !s.hasValue) return loc == '/inicio' ? null : '/inicio';
      final logueado = s.value != null;
      if (!logueado) return _rutasAuth.contains(loc) ? null : '/login';
      final pendiente = ref.read(rutaPendienteProvider);
      if (pendiente != null) Future.microtask(() => ref.read(rutaPendienteProvider.notifier).set(null));
      if (_rutasAuth.contains(loc) || loc == '/inicio') return pendiente ?? '/hoy';
      return null;
    },
    routes: [
      GoRoute(path: '/inicio', pageBuilder: (c, s) => _fade(const SplashScreen(), s)),
      GoRoute(path: '/login', pageBuilder: (c, s) => _fade(const LoginScreen(), s)),
      GoRoute(path: '/registro', pageBuilder: (c, s) => _eje(const RegisterScreen(), s)),
      GoRoute(
        path: '/verificar',
        pageBuilder: (c, s) {
          final d = s.extra is DatosVerificacion ? s.extra! as DatosVerificacion : null;
          if (d == null) return _fade(const LoginScreen(), s);
          return _eje(VerifyScreen(datos: d), s);
        },
      ),
      StatefulShellRoute(
        builder: (context, state, shell) => HomeShell(shell: shell),
        navigatorContainerBuilder: (context, shell, children) => AnimatedBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/hoy', builder: (c, s) => const ModuleTheme(module: AppModule.inicio, child: TodayScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/eventos', builder: (c, s) => const ModuleTheme(module: AppModule.eventos, child: EventsScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/finanzas', builder: (c, s) => const ModuleTheme(module: AppModule.finanzas, child: FinanceScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ciclo', builder: (c, s) => const ModuleTheme(module: AppModule.ciclo, child: CycleScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/perfil', builder: (c, s) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    sesion.dispose();
  });
  return router;
});

/// Pantalla breve mientras se lee la sesión guardada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Hero(
          tag: 'logo-auth',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset('assets/images/logo.png', width: 88, height: 88, semanticLabel: 'Agendaservi'),
          ),
        ),
      ),
    );
  }
}
