import 'package:flutter/material.dart';

/// Escala de espaciado (ritmo de 4/8 dp).
abstract final class Gap {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Radios de esquina.
abstract final class Radii {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;

  static final BorderRadius rSm = BorderRadius.circular(sm);
  static final BorderRadius rMd = BorderRadius.circular(md);
  static final BorderRadius rLg = BorderRadius.circular(lg);
  static final BorderRadius rXl = BorderRadius.circular(xl);
}

/// Tamaños de icono como tokens (evita 20/22/26 arbitrarios).
abstract final class IconSizes {
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

/// Colores base de la marca, independientes del módulo. Neutros cálidos
/// "Tinta / Papel" con el violeta de Agendaservi y el coral como firma.
abstract final class Brand {
  /// Sello "USD" de las tarjetas de dólares.
  static const oroDolares = Color(0xFFF5C451);

  static const darkBg = Color(0xFF0F1115);
  static const darkSurface = Color(0xFF171A21);
  static const darkSurfaceHigh = Color(0xFF1F232C);
  static const darkSurfaceHighest = Color(0xFF2A2F3A);
  static const darkText = Color(0xFFECEDEF);
  static const darkTextSecondary = Color(0xFF9AA1AE);

  static const lightBg = Color(0xFFF6F5F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEFEDE8);
  static const lightSurfaceHighest = Color(0xFFE6E3DC);
  static const lightText = Color(0xFF14161B);
  static const lightTextSecondary = Color(0xFF545966);

  static const violetaClaro = Color(0xFF5B4CF0);
  static const violetaOscuro = Color(0xFFA49BFF);

  /// Acento de firma: degradado de héroes, onboarding y celebraciones.
  static const coral = Color(0xFFFF7A59);

  /// Verde de WhatsApp: solo para lo que ES WhatsApp, no como color de marca.
  static const whatsapp = Color(0xFF25D366);
}

/// Color de dato (categoría, tipo de cuenta) con su versión para cada modo:
/// los tonos vivos que se leen bien sobre oscuro no alcanzan contraste en claro.
@immutable
class ColorPar {
  const ColorPar(this.claro, this.oscuro);
  final Color claro;
  final Color oscuro;

  Color de(Brightness b) => b == Brightness.dark ? oscuro : claro;
}

/// Colores de las fases del ciclo (mismo significado que en la web).
abstract final class PhaseColors {
  static const period = Color(0xFFF43F5E);
  static const predicted = Color(0xFFFB7185);
  static const late = Color(0xFFEF4444);
  static const fertile = Color(0xFFF59E0B);
  static const ovulation = Color(0xFFD946EF);
  static const follicular = Color(0xFF38BDF8);
  static const luteal = Color(0xFF818CF8);
}
