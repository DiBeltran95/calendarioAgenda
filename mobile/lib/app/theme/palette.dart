import 'package:flutter/material.dart';

import 'tokens.dart';

/// Tokens semánticos que Material no cubre. Es una [ThemeExtension] con
/// `lerp`, así que cuando el tema cambia (módulo o modo claro/oscuro) todos
/// estos colores se animan junto con el resto del tema.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.accent,
    required this.accent2,
    required this.onAccent,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.gold,
  });

  final Color accent;
  final Color accent2;
  final Color onAccent;
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color gold;

  factory Palette.of(Brightness b, Color accent, Color accent2) {
    final dark = b == Brightness.dark;
    return Palette(
      accent: accent,
      accent2: accent2,
      // En oscuro los acentos son claros: texto oscuro encima (contraste AA).
      onAccent: dark ? const Color(0xFF06110C) : Colors.white,
      bg: dark ? Brand.darkBg : Brand.lightBg,
      surface: dark ? Brand.darkSurface : Brand.lightSurface,
      surfaceHigh: dark ? Brand.darkSurfaceHigh : Brand.lightSurfaceHigh,
      surfaceHighest: dark ? Brand.darkSurfaceHighest : Brand.lightSurfaceHighest,
      border: dark ? const Color(0x1FFFFFFF) : const Color(0x1F0F172A),
      text: dark ? Brand.darkText : Brand.lightText,
      textSecondary: dark ? Brand.darkTextSecondary : Brand.lightTextSecondary,
      success: dark ? const Color(0xFF34D399) : const Color(0xFF047857),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      danger: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      info: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      gold: dark ? const Color(0xFFF5C451) : const Color(0xFFA16207),
    );
  }

  @override
  Palette copyWith({Color? accent, Color? accent2}) => Palette(
        accent: accent ?? this.accent,
        accent2: accent2 ?? this.accent2,
        onAccent: onAccent,
        bg: bg,
        surface: surface,
        surfaceHigh: surfaceHigh,
        surfaceHighest: surfaceHighest,
        border: border,
        text: text,
        textSecondary: textSecondary,
        success: success,
        warning: warning,
        danger: danger,
        info: info,
        gold: gold,
      );

  @override
  Palette lerp(ThemeExtension<Palette>? other, double t) {
    if (other is! Palette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      accent: l(accent, other.accent),
      accent2: l(accent2, other.accent2),
      onAccent: l(onAccent, other.onAccent),
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      surfaceHighest: l(surfaceHighest, other.surfaceHighest),
      border: l(border, other.border),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      gold: l(gold, other.gold),
    );
  }
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
