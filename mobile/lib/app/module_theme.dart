import 'package:flutter/material.dart';

import '../core/motion.dart';
import 'theme/app_module.dart';
import 'theme/app_theme.dart';

final Map<(Brightness, AppModule), ThemeData> _cache = {};

/// Tema memoizado (construir un ThemeData con Google Fonts no es gratis).
ThemeData themeFor(Brightness b, AppModule m) => _cache.putIfAbsent((b, m), () => buildTheme(b, m));

/// Aplica el acento de un módulo a su subárbol. Cada pantalla conserva su
/// color aunque el tema global esté animándose hacia otro módulo.
class ModuleTheme extends StatelessWidget {
  const ModuleTheme({super.key, required this.module, required this.child});

  final AppModule module;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return AnimatedTheme(
      data: themeFor(b, module),
      duration: Motion.of(context, const Duration(milliseconds: 350)),
      curve: Motion.standard,
      child: child,
    );
  }
}
