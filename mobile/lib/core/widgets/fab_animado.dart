import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion.dart';

/// Botón flotante que se presenta y luego se recoge.
///
/// Cada vez que el usuario entra al módulo, el botón se despliega mostrando
/// su texto (con un destello que lo recorre), lo sostiene unos segundos y se
/// recoge suavemente hasta quedar solo el ícono, que gira un cuarto de vuelta
/// como remate. Así el usuario aprende la acción sin que el texto tape el
/// contenido el resto del tiempo. Al mantenerlo presionado se vuelve a
/// desplegar; el lector de pantalla siempre anuncia el texto completo.
class FabAnimado extends StatefulWidget {
  const FabAnimado({
    super.key,
    required this.icono,
    required this.etiqueta,
    required this.onPressed,
    this.heroTag,
    this.sostener = const Duration(milliseconds: 2600),
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onPressed;
  final Object? heroTag;

  /// Cuánto tiempo se ve el texto antes de recogerse.
  final Duration sostener;

  @override
  State<FabAnimado> createState() => _FabAnimadoState();
}

class _FabAnimadoState extends State<FabAnimado> with SingleTickerProviderStateMixin {
  /// 1 = desplegado (ícono + texto), 0 = recogido (solo ícono).
  late final AnimationController _c = AnimationController(vsync: this, value: 0);
  Timer? _recoger;
  bool _visible = false;
  int _vuelta = 0;

  static const _abrir = Duration(milliseconds: 420);
  static const _cerrar = Duration(milliseconds: 560);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Las ramas del shell se mantienen vivas pero con TickerMode apagado:
    // cuando se enciende, el usuario acaba de entrar a este módulo.
    final activo = TickerMode.valuesOf(context).enabled;
    if (activo && !_visible) _presentar(reconstruir: false);
    if (!activo) {
      _recoger?.cancel();
      _c.value = 0;
    }
    _visible = activo;
  }

  /// Despliega el botón y programa su cierre. Desde didChangeDependencies no
  /// hace falta setState: el widget se reconstruye a continuación.
  void _presentar({bool reconstruir = true}) {
    _recoger?.cancel();
    final reducido = Motion.reduced(context);
    if (reconstruir) {
      setState(() => _vuelta++);
    } else {
      _vuelta++;
    }
    if (reducido) {
      _c.value = 1;
    } else {
      _c.animateTo(1, duration: _abrir, curve: Motion.enter);
    }
    _recoger = Timer(widget.sostener, () {
      if (!mounted) return;
      if (Motion.reduced(context)) {
        _c.value = 0;
      } else {
        _c.animateBack(0, duration: _cerrar, curve: Curves.easeInOutCubicEmphasized);
      }
    });
  }

  @override
  void dispose() {
    _recoger?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fab = Theme.of(context).floatingActionButtonTheme;
    final colorTexto = fab.foregroundColor ?? esquema.onPrimaryContainer;

    return Semantics(
      button: true,
      label: widget.etiqueta,
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: _presentar,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Etiqueta: se pliega hacia el ícono mientras se desvanece y se
            // desliza un poco, así el cierre se lee como "entrar al botón".
            final etiqueta = ClipRect(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: Curves.easeOut.transform(t),
                child: Opacity(
                  opacity: Interval(0.35, 1).transform(t),
                  child: Transform.translate(offset: Offset(lerpDouble(-10, 0, t)!, 0), child: Text(widget.etiqueta, maxLines: 1, softWrap: false)),
                ),
              ),
            );
            Widget contenido = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Un cuarto de vuelta al recogerse: remata el gesto.
                Transform.rotate(angle: (1 - t) * 1.5708, child: Icon(widget.icono)),
                SizedBox(width: 8 * t),
                etiqueta,
              ],
            );
            if (!Motion.reduced(context)) {
              contenido = contenido.animate(key: ValueKey(_vuelta)).shimmer(delay: 260.ms, duration: 1100.ms, color: colorTexto.withValues(alpha: 0.55));
            }
            return FloatingActionButton.extended(
              heroTag: widget.heroTag,
              onPressed: widget.onPressed,
              tooltip: t < 0.5 ? widget.etiqueta : null,
              // 16 + 24 + 16 = 56: recogido mide lo mismo que un FAB normal.
              extendedPadding: EdgeInsetsDirectional.only(start: 16, end: lerpDouble(16, 20, t)!),
              extendedIconLabelSpacing: 0,
              label: contenido,
            );
          },
        ),
      ),
    );
  }
}
