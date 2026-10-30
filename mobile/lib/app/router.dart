import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion.dart';
import '../core/providers.dart';
import '../core/session.dart';
import '../features/auth/auth_screens.dart';
import '../features/citas/ajustes_agenda_screen.dart';
import '../features/citas/citas_screen.dart';
import '../features/citas/crear_pagina_screen.dart';
import '../features/citas/reservar_screen.dart';
import '../features/cycle/cycle_screen.dart';
import '../features/events/events_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/finance/inversiones/inversiones_screen.dart';
import '../features/finance/pagos/pagos_screen.dart';
import '../features/home/today_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';
import 'module_theme.dart';
import 'shell.dart';
import 'theme/app_module.dart';

CustomTransitionPage<void> _fade(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, a, _, c) => Motion.reduced(context)
          ? c
          : FadeTransition(
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
        if (Motion.reduced(context)) return c;
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

/// Pantalla que se apila sobre la actual deslizándose desde la derecha.
CustomTransitionPage<void> _deslizar(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, a, sa, c) {
        if (Motion.reduced(context)) return c;
        final entra = CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Motion.exit);
        return FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: a, curve: const Interval(0, 0.6))),
          child: SlideTransition(position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(entra), child: c),
        );
      },
    );

/// Pantalla que sube desde abajo (flujos de creación y reserva).
CustomTransitionPage<void> _subir(Widget child, GoRouterState s) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, a, sa, c) {
        if (Motion.reduced(context)) return c;
        final entra = CurvedAnimation(parent: a, curve: Motion.enter, reverseCurve: Motion.exit);
        return FadeTransition(
          opacity: entra,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(entra), child: c),
        );
      },
    );

const _rutasAuth = {'/login', '/registro', '/verificar'};

/// Páginas públicas de reserva: se abren con o sin sesión (enlace compartido).
bool _esPublica(String loc) => loc.startsWith('/agenda/');

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
      if (s.isLoading && !s.hasValue) {
        // Enlace que abrió la app en frío (reserva, notificación de un pago…):
        // se recuerda para después de cargar la sesión.
        if (loc != '/inicio' && !_rutasAuth.contains(loc) && loc != '/hoy') {
          final destino = state.uri.toString();
          Future.microtask(() => ref.read(rutaPendienteProvider.notifier).set(destino));
        }
        return loc == '/inicio' ? null : '/inicio';
      }
      if (_esPublica(loc)) return null;
      final logueado = s.value != null;
      final pendiente = ref.read(rutaPendienteProvider);
      if (!logueado) {
        if (loc == '/inicio' && pendiente != null && _esPublica(pendiente)) {
          Future.microtask(() => ref.read(rutaPendienteProvider.notifier).set(null));
          return pendiente;
        }
        return _rutasAuth.contains(loc) ? null : '/login';
      }
      if (pendiente != null) Future.microtask(() => ref.read(rutaPendienteProvider.notifier).set(null));
      if (_rutasAuth.contains(loc) || loc == '/inicio') {
        if (ref.read(bienvenidaPendienteProvider)) return '/bienvenida';
        return pendiente ?? '/hoy';
      }
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
      // Botón del widget de la pantalla de inicio: Hoy con la captura abierta.
      GoRoute(
        path: '/capturar',
        redirect: (c, s) {
          Future.microtask(() => ref.read(capturaPendienteProvider.notifier).set(true));
          return '/hoy';
        },
      ),
      GoRoute(path: '/bienvenida', pageBuilder: (c, s) => _fade(const ModuleTheme(module: AppModule.inicio, child: OnboardingScreen()), s)),
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
            GoRoute(path: '/citas', builder: (c, s) => const ModuleTheme(module: AppModule.citas, child: CitasScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/finanzas', builder: (c, s) => const ModuleTheme(module: AppModule.finanzas, child: FinanceScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ciclo', builder: (c, s) => const ModuleTheme(module: AppModule.ciclo, child: CycleScreen())),
          ]),
        ],
      ),
      // Perfil y ajustes: se abre desde el avatar de cada módulo.
      GoRoute(path: '/perfil', pageBuilder: (c, s) => _deslizar(const ModuleTheme(module: AppModule.inicio, child: SettingsScreen()), s)),
      GoRoute(path: '/finanzas/pagos', pageBuilder: (c, s) => _deslizar(const ModuleTheme(module: AppModule.finanzas, child: PagosScreen()), s)),
      GoRoute(path: '/finanzas/inversiones', pageBuilder: (c, s) => _deslizar(const ModuleTheme(module: AppModule.finanzas, child: InversionesScreen()), s)),
      GoRoute(path: '/citas/ajustes', pageBuilder: (c, s) => _deslizar(const ModuleTheme(module: AppModule.citas, child: AjustesAgendaScreen()), s)),
      GoRoute(path: '/citas/crear', pageBuilder: (c, s) => _subir(const ModuleTheme(module: AppModule.citas, child: CrearPaginaScreen()), s)),
      GoRoute(
        path: '/agenda/:slug',
        pageBuilder: (c, s) => _subir(ModuleTheme(module: AppModule.citas, child: ReservarScreen(slug: s.pathParameters['slug']!.toLowerCase())), s),
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
