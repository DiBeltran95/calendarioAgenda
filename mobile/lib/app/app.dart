import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/motion.dart';
import '../core/providers.dart';
import 'module_theme.dart';
import 'router.dart';

class AgendaApp extends ConsumerWidget {
  const AgendaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferenciasProvider).value ?? const Preferencias();
    final modulo = ref.watch(moduloActivoProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Agendaservi',
      debugShowCheckedModeBanner: false,
      // El tema global sigue al módulo activo: al cambiar de pestaña todos los
      // colores se interpolan (barra inferior, diálogos, hojas).
      theme: themeFor(Brightness.light, modulo),
      darkTheme: themeFor(Brightness.dark, modulo),
      themeMode: prefs.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 450),
      themeAnimationCurve: Motion.standard,
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) {
        // "Reducir animaciones" de los ajustes se suma al del sistema: todo
        // el movimiento de la app consulta este mismo flag.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: mq.disableAnimations || prefs.reducirMovimiento),
          child: child!,
        );
      },
    );
  }
}
