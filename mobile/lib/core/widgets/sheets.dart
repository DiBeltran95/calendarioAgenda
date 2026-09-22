import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../motion.dart';

/// Abre una hoja inferior con el estilo de la app. Se desliza desde abajo
/// (su origen natural en móvil), se cierra arrastrando o tocando el fondo.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Sobre el navegador raíz: la hoja cubre también la barra inferior.
    useRootNavigator: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, const Duration(milliseconds: 380)),
      reverseDuration: Motion.of(context, const Duration(milliseconds: 240)),
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    ),
    builder: builder,
  );
}

/// Estructura común de las hojas: título, contenido desplazable y una barra
/// inferior fija con la acción principal (se eleva sobre el teclado).
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.primaryLabel,
    this.onPrimary,
    this.busy = false,
    this.secondary,
    this.headerAction,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final bool busy;

  /// Acción secundaria a la izquierda de la principal (p. ej. Eliminar).
  final Widget? secondary;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: Motion.of(context, Motion.fast),
      curve: Motion.standard,
      padding: EdgeInsets.only(bottom: insets),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.sm, Gap.sm),
              child: Row(
                children: [
                  if (icon != null) ...[IconBadge(icon!, size: 40), const HGap.sm()],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
                        if (subtitle != null) Text(subtitle!, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  ?headerAction,
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.lg),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
              ),
            ),
            if (primaryLabel != null)
              Container(
                padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(top: BorderSide(color: p.border)),
                ),
                child: Row(
                  children: [
                    if (secondary != null) ...[secondary!, const HGap.sm()],
                    Expanded(
                      child: FilledButton(
                        onPressed: busy ? null : onPrimary,
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.fast),
                          child: busy
                              ? SizedBox(
                                  key: const ValueKey('busy'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: p.textSecondary),
                                )
                              : Text(primaryLabel!, key: const ValueKey('label')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de confirmación. Las acciones destructivas usan el color de peligro
/// y quedan separadas de "Cancelar".
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Confirmar',
  bool destructivo = false,
  IconData? icon,
}) async {
  final p = context.palette;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon != null ? Icon(icon, color: destructivo ? p.danger : p.accent, size: IconSizes.xl) : null,
      title: Text(titulo, textAlign: icon != null ? TextAlign.center : null),
      content: Text(mensaje),
      actionsPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: p.textSecondary),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(ctx, true);
          },
          style: destructivo ? FilledButton.styleFrom(backgroundColor: p.danger, foregroundColor: Colors.white, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: Text(confirmar),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Diálogo con varias opciones (devuelve el índice elegido o null).
Future<int?> elegirOpcion(
  BuildContext context, {
  required String titulo,
  String? mensaje,
  required List<(String, IconData, bool destructivo)> opciones,
}) {
  final p = context.palette;
  return showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(titulo),
      contentPadding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.md),
      children: [
        if (mensaje != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.sm),
            child: Text(mensaje, style: context.text.bodyMedium?.copyWith(color: p.textSecondary)),
          ),
        for (var i = 0; i < opciones.length; i++)
          ListTile(
            leading: Icon(opciones[i].$2, color: opciones[i].$3 ? p.danger : p.accent),
            title: Text(opciones[i].$1, style: TextStyle(color: opciones[i].$3 ? p.danger : null)),
            onTap: () => Navigator.pop(ctx, i),
          ),
        ListTile(
          leading: Icon(Icons.close_rounded, color: p.textSecondary),
          title: const Text('Cancelar'),
          onTap: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

/// Aviso breve y flotante, con "Deshacer" opcional (se descarta solo a los 4 s).
void toast(BuildContext context, String mensaje, {IconData? icon, VoidCallback? onUndo, bool error = false}) =>
    Toaster.of(context).show(mensaje, icon: icon, onUndo: onUndo, error: error);

/// Captura el [ScaffoldMessenger] y la paleta ANTES de una operación
/// asíncrona, para poder avisar aunque el widget que la inició desaparezca
/// (p. ej. el tile de un evento que se acaba de borrar).
class Toaster {
  Toaster._(this._messenger, this._p);
  factory Toaster.of(BuildContext context) => Toaster._(ScaffoldMessenger.of(context), context.palette);

  final ScaffoldMessengerState _messenger;
  final Palette _p;

  void show(String mensaje, {IconData? icon, VoidCallback? onUndo, bool error = false}) {
    _messenger.hideCurrentSnackBar();
    _messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Icon(icon ?? (error ? Icons.error_outline_rounded : Icons.check_circle_rounded), color: error ? _p.danger : _p.accent, size: IconSizes.md),
          const HGap.sm(),
          Expanded(child: Text(mensaje)),
        ],
      ),
      action: onUndo == null ? null : SnackBarAction(label: 'Deshacer', onPressed: onUndo),
    ));
  }
}
