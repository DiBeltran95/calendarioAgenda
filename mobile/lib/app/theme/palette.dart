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
    required this.bordeTarjeta,
    required this.sombraSuave,
    required this.sombraMedia,
    required this.sombraFlotante,
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

  /// Borde de las tarjetas: en oscuro las separa del fondo; en claro lo hace
  /// la sombra (transparente, para que el tamaño sea el mismo en ambos modos).
  final Color bordeTarjeta;

  /// Escala de elevación: tarjetas, elementos resaltados y lo que flota
  /// (barra inferior, avisos). Ningún widget debería escribir su propia sombra.
  final List<BoxShadow> sombraSuave;
  final List<BoxShadow> sombraMedia;
  final List<BoxShadow> sombraFlotante;

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
      onAccent: dark ? const Color(0xFF0B0D12) : Colors.white,
      bg: dark ? Brand.darkBg : Brand.lightBg,
      surface: dark ? Brand.darkSurface : Brand.lightSurface,
      surfaceHigh: dark ? Brand.darkSurfaceHigh : Brand.lightSurfaceHigh,
      surfaceHighest: dark ? Brand.darkSurfaceHighest : Brand.lightSurfaceHighest,
      border: dark ? const Color(0x1FFFFFFF) : const Color(0x1F14161B),
      bordeTarjeta: dark ? const Color(0x14FFFFFF) : const Color(0x00000000),
      sombraSuave: dark
          ? const []
          : const [
              BoxShadow(color: Color(0x0A14161B), blurRadius: 3, offset: Offset(0, 1)),
              BoxShadow(color: Color(0x0D14161B), blurRadius: 16, offset: Offset(0, 6)),
            ],
      sombraMedia: dark
          ? const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))]
          : const [
              BoxShadow(color: Color(0x0F14161B), blurRadius: 4, offset: Offset(0, 2)),
              BoxShadow(color: Color(0x1414161B), blurRadius: 24, offset: Offset(0, 10)),
            ],
      sombraFlotante: dark
          ? const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 12))]
          : const [
              BoxShadow(color: Color(0x1414161B), blurRadius: 6, offset: Offset(0, 2)),
              BoxShadow(color: Color(0x2414161B), blurRadius: 32, offset: Offset(0, 14)),
            ],
      text: dark ? Brand.darkText : Brand.lightText,
      textSecondary: dark ? Brand.darkTextSecondary : Brand.lightTextSecondary,
      success: dark ? const Color(0xFF34D399) : const Color(0xFF047857),
      warning: dark ? const Color(0xFFFBBF24) : const Color(0xFFA84C07),
      danger: dark ? const Color(0xFFF87171) : const Color(0xFFB91C1C),
      info: dark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      gold: dark ? const Color(0xFFF5C451) : const Color(0xFF8F5706),
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
        bordeTarjeta: bordeTarjeta,
        sombraSuave: sombraSuave,
        sombraMedia: sombraMedia,
        sombraFlotante: sombraFlotante,
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
      bordeTarjeta: l(bordeTarjeta, other.bordeTarjeta),
      sombraSuave: BoxShadow.lerpList(sombraSuave, other.sombraSuave, t) ?? other.sombraSuave,
      sombraMedia: BoxShadow.lerpList(sombraMedia, other.sombraMedia, t) ?? other.sombraMedia,
      sombraFlotante: BoxShadow.lerpList(sombraFlotante, other.sombraFlotante, t) ?? other.sombraFlotante,
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

  /// Color de dato en el modo actual.
  Color par(ColorPar c) => c.de(Theme.of(this).brightness);
}
