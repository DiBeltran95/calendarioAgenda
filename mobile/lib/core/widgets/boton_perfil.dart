import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/palette.dart';
import '../motion.dart';
import '../session.dart';

/// Avatar del usuario en la cabecera de cada módulo: abre Perfil y ajustes
/// (patrón de Gmail, Instagram…). Así la barra inferior deja sitio a los
/// cinco módulos sin pasar del máximo recomendado.
class BotonPerfil extends ConsumerWidget {
  const BotonPerfil({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final usuario = ref.watch(sesionProvider).value?.usuario;
    return Tooltip(
      message: 'Perfil',
      child: Semantics(
        button: true,
        label: 'Perfil y ajustes',
        excludeSemantics: true,
        child: Pressable(
          onTap: () => context.push('/perfil'),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.accent, p.accent2])),
            child: Text(
              usuario?.iniciales ?? '',
              style: TextStyle(color: p.onAccent, fontWeight: FontWeight.w800, fontSize: size * 0.34),
            ),
          ),
        ),
      ),
    );
  }
}
