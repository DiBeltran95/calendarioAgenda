import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../motion.dart';

/// Bloque de carga con brillo que recorre la forma del contenido que viene.
/// Con movimiento reducido queda estático.
class Esqueleto extends StatelessWidget {
  const Esqueleto({super.key, this.ancho, this.alto = 16, this.radio = Radii.sm});

  final double? ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bloque = Container(
      width: ancho,
      height: alto,
      decoration: BoxDecoration(color: p.surfaceHigh, borderRadius: BorderRadius.circular(radio)),
    );
    if (Motion.reduced(context)) return bloque;
    return bloque
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: const Duration(milliseconds: 1500), color: p.surfaceHighest);
  }
}

/// Tarjeta de carga genérica: la forma de una tarjeta de la app sin contenido.
class EsqueletoTarjeta extends StatelessWidget {
  const EsqueletoTarjeta({super.key, this.alto = 96});
  final double alto;

  @override
  Widget build(BuildContext context) => Esqueleto(alto: alto, radio: Radii.lg);
}

/// Lista de tarjetas de carga para una pantalla entera. Se anuncia una sola vez
/// a los lectores de pantalla.
class EsqueletoLista extends StatelessWidget {
  const EsqueletoLista({super.key, this.alturas = const [148, 96, 96, 72]});
  final List<double> alturas;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, a) in alturas.indexed) ...[
            if (i > 0) const VGap.sm(),
            EsqueletoTarjeta(alto: a),
          ],
        ],
      ),
    );
  }
}
