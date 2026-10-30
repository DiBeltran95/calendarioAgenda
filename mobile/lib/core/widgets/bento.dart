import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Celda de un [BentoGrid]: ocupa una columna o el ancho completo de la fila.
class CeldaBento {
  const CeldaBento(this.child, {this.ancha = false});
  final Widget child;
  final bool ancha;
}

/// Rejilla modular de tarjetas: dos columnas en teléfono y cuatro en tablet.
/// Las celdas de una fila se igualan en altura; con texto muy grande o pantalla
/// muy estrecha todas pasan a ocupar el ancho completo para no recortar nada.
class BentoGrid extends StatelessWidget {
  const BentoGrid({super.key, required this.celdas, this.separacion = Gap.sm});

  final List<CeldaBento> celdas;
  final double separacion;

  @override
  Widget build(BuildContext context) {
    final texto = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, c) {
      final columnas = c.maxWidth >= 720 ? 4 : 2;
      final minimo = 150 * texto;
      final unaColumna = columnas == 2 && (c.maxWidth - separacion) / 2 < minimo;

      final filas = <List<CeldaBento>>[];
      var fila = <CeldaBento>[];
      var usadas = 0;
      for (final celda in celdas) {
        final ocupa = unaColumna || celda.ancha ? columnas : 1;
        if (usadas + ocupa > columnas) {
          filas.add(fila);
          fila = [];
          usadas = 0;
        }
        fila.add(celda);
        usadas += ocupa;
      }
      if (fila.isNotEmpty) filas.add(fila);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, f) in filas.indexed) ...[
            if (i > 0) SizedBox(height: separacion),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (j, celda) in f.indexed) ...[
                    if (j > 0) SizedBox(width: separacion),
                    Expanded(flex: unaColumna || celda.ancha ? columnas : 1, child: celda.child),
                  ],
                  // Fila incompleta: las celdas conservan su ancho de columna.
                  if (_ocupadas(f, columnas, unaColumna) < columnas) ...[
                    SizedBox(width: separacion),
                    Expanded(flex: columnas - _ocupadas(f, columnas, unaColumna), child: const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  static int _ocupadas(List<CeldaBento> f, int columnas, bool unaColumna) =>
      f.fold(0, (s, c) => s + (unaColumna || c.ancha ? columnas : 1));
}
