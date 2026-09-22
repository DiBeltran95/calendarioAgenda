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
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
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

/// Colores base de la marca, independientes del módulo.
abstract final class Brand {
  // Fondo oscuro heredado del estilo WhatsApp Dark de la versión web.
  static const darkBg = Color(0xFF0B141A);
  static const darkSurface = Color(0xFF111B21);
  static const darkSurfaceHigh = Color(0xFF1A252D);
  static const darkSurfaceHighest = Color(0xFF233138);
  static const darkText = Color(0xFFE9EDEF);
  static const darkTextSecondary = Color(0xFF8FA0AA); // 6.3:1 sobre darkBg

  static const lightBg = Color(0xFFF4F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEDF1F4);
  static const lightSurfaceHighest = Color(0xFFE2E8ED);
  static const lightText = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF4B5968); // 7:1 sobre lightBg

  static const green = Color(0xFF25D366);
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
