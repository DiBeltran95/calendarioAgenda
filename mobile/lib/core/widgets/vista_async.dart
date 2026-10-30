import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../motion.dart';
import '../net/api_exception.dart';
import 'esqueleto.dart';
import 'ui.dart';

/// Los tres estados de una carga, iguales en toda la app:
///
/// - hay datos (de la red o guardados en el teléfono): se muestran;
/// - falló y no hay nada que mostrar: error con "Reintentar";
/// - carga inicial: esqueleto con la forma del contenido.
///
/// Evita el `.value ?? const []` que convierte un fallo en una pantalla vacía.
class VistaAsync<T> extends StatelessWidget {
  const VistaAsync({super.key, required this.valor, required this.datos, this.esqueleto, this.onReintentar});

  final AsyncValue<T> valor;
  final Widget Function(T datos) datos;
  final Widget? esqueleto;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final Widget hijo;
    if (valor.hasValue) {
      hijo = KeyedSubtree(key: const ValueKey('datos'), child: datos(valor.requireValue));
    } else if (valor.hasError) {
      hijo = EstadoError(key: const ValueKey('error'), error: valor.error, onReintentar: onReintentar);
    } else {
      hijo = KeyedSubtree(key: const ValueKey('cargando'), child: esqueleto ?? const EsqueletoLista());
    }
    return SmoothSwitcher(child: hijo);
  }
}

/// Fallo de carga: dice qué pasó y cómo seguir.
class EstadoError extends StatelessWidget {
  const EstadoError({super.key, this.error, this.onReintentar, this.titulo});

  final Object? error;
  final VoidCallback? onReintentar;
  final String? titulo;

  static bool _sinRed(Object? e) => e is ApiException && e.isNetwork;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sinRed = _sinRed(error);
    return AppCard(
      padding: const EdgeInsets.all(Gap.lg),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(sinRed ? Icons.cloud_off_rounded : Icons.error_outline_rounded, color: sinRed ? p.warning : p.danger, size: 56),
            const VGap.md(),
            Text(titulo ?? (sinRed ? 'Sin conexión' : 'No pudimos cargar esto'), style: context.text.titleMedium, textAlign: TextAlign.center),
            const VGap.xs(),
            Text(
              sinRed ? 'Revisa tu internet e inténtalo de nuevo. Tus datos están a salvo.' : 'Fue un problema de nuestro lado. Tus datos están a salvo.',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onReintentar != null) ...[
              const VGap.md(),
              FilledButton.tonalIcon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: p.accent.withValues(alpha: 0.14),
                  foregroundColor: p.accent,
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
