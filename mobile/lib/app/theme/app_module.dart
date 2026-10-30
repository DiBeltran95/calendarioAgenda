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
    accentDark: Brand.violetaOscuro,
    accentLight: Brand.violetaClaro,
    secondaryDark: Brand.coral,
    secondaryLight: Color(0xFFD9482B),
  ),
  eventos(
    label: 'Eventos',
    titulo: 'Calendario de eventos',
    icon: Icons.event_note_outlined,
    iconSelected: Icons.event_note_rounded,
    accentDark: Color(0xFF2DD4BF),
    accentLight: Color(0xFF0F766E),
    secondaryDark: Color(0xFF38BDF8),
    secondaryLight: Color(0xFF0369A1),
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
    accentDark: Color(0xFFFB923C),
    accentLight: Color(0xFFB83D0B),
    secondaryDark: Color(0xFFFB7185),
    secondaryLight: Color(0xFFBE123C),
  ),
  finanzas(
    label: 'Finanzas',
    titulo: 'Control financiero',
    icon: Icons.account_balance_wallet_outlined,
    iconSelected: Icons.account_balance_wallet_rounded,
    accentDark: Color(0xFF34D399),
    accentLight: Color(0xFF047857),
    secondaryDark: Color(0xFF22D3EE),
    secondaryLight: Color(0xFF0E7490),
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
