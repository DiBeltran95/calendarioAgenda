import 'package:flutter/material.dart';

import 'tokens.dart';

/// Los tres calendarios de la app. Cada uno tiene su identidad de color; al
/// cambiar de módulo el tema completo se interpola (colores animados).
enum AppModule {
  inicio(
    label: 'Hoy',
    titulo: 'Tu día',
    icon: Icons.wb_twilight_outlined,
    iconSelected: Icons.wb_twilight_rounded,
    accentDark: Color(0xFF2DD4BF),
    accentLight: Color(0xFF0F766E),
    secondaryDark: Brand.green,
    secondaryLight: Color(0xFF047857),
  ),
  eventos(
    label: 'Eventos',
    titulo: 'Calendario de eventos',
    icon: Icons.event_note_outlined,
    iconSelected: Icons.event_note_rounded,
    accentDark: Brand.green,
    accentLight: Color(0xFF047857),
    secondaryDark: Color(0xFF34D399),
    secondaryLight: Color(0xFF059669),
  ),
  ciclo(
    label: 'Ciclo',
    titulo: 'Calendario del ciclo',
    icon: Icons.water_drop_outlined,
    iconSelected: Icons.water_drop_rounded,
    accentDark: Color(0xFFF472B6),
    accentLight: Color(0xFFBE185D),
    secondaryDark: Color(0xFFA78BFA),
    secondaryLight: Color(0xFF7C3AED),
  ),
  citas(
    label: 'Citas',
    titulo: 'Agenda de citas',
    icon: Icons.book_online_outlined,
    iconSelected: Icons.book_online_rounded,
    accentDark: Color(0xFFA78BFA),
    accentLight: Color(0xFF6D28D9),
    secondaryDark: Color(0xFF60A5FA),
    secondaryLight: Color(0xFF2563EB),
  ),
  finanzas(
    label: 'Finanzas',
    titulo: 'Control financiero',
    icon: Icons.account_balance_wallet_outlined,
    iconSelected: Icons.account_balance_wallet_rounded,
    accentDark: Color(0xFF60A5FA),
    accentLight: Color(0xFF1D4ED8),
    secondaryDark: Color(0xFF34D399),
    secondaryLight: Color(0xFF047857),
  );

  const AppModule({
    required this.label,
    required this.titulo,
    required this.icon,
    required this.iconSelected,
    required this.accentDark,
    required this.accentLight,
    required this.secondaryDark,
    required this.secondaryLight,
  });

  final String label;
  final String titulo;
  final IconData icon;
  final IconData iconSelected;
  final Color accentDark;
  final Color accentLight;
  final Color secondaryDark;
  final Color secondaryLight;

  Color accent(Brightness b) => b == Brightness.dark ? accentDark : accentLight;
  Color secondary(Brightness b) => b == Brightness.dark ? secondaryDark : secondaryLight;
}
