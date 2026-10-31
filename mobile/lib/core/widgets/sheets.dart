import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';
import '../motion.dart';

/// Abre una hoja inferior con el estilo de la app. Se desliza desde abajo
/// (su origen natural en móvil), se cierra arrastrando o tocando el fondo.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  // Sobre el navegador raíz: la hoja cubre también la barra inferior.
  final nav = Navigator.of(context, rootNavigator: true);
  final textos = MaterialLocalizations.of(context);
  return nav.push(_RutaHoja<T>(
    builder: builder,
    capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
    barrierLabel: textos.scrimLabel,
    barrierOnTapHint: textos.scrimOnTapHint(textos.bottomSheetLabel),
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: AnimationStyle(
      duration: Motion.of(context, const Duration(milliseconds: 380)),
      reverseDuration: Motion.of(context, const Duration(milliseconds: 240)),
      curve: Motion.enter,
      reverseCurve: Motion.exit,
    ),
  ));
}

/// Hoja que no se deja cerrar sin avisar si el formulario tiene cambios: vale
/// para la X, tocar el fondo, arrastrarla hacia abajo y el gesto de atrás.
class _RutaHoja<T> extends ModalBottomSheetRoute<T> {
  _RutaHoja({
    required super.builder,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    required super.isScrollControlled,
    super.useSafeArea,
    super.showDragHandle,
    super.constraints,
    super.sheetAnimationStyle,
  });

  /// Lo fija [SheetScaffold]: ¿hay algo que se perdería al cerrar?
  bool Function()? hayCambios;
  bool _preguntando = false;
  bool _descartar = false;

  @override
  bool didPop(T? result) {
    if (_descartar || hayCambios == null || !hayCambios!()) return super.didPop(result);
    // Si venía de arrastrarla, vuelve a su sitio mientras se decide.
    controller?.forward();
    if (!_preguntando) {
      _preguntando = true;
      // El navegador sigue ocupado con este "pop": el diálogo espera su turno.
      scheduleMicrotask(_preguntar);
    }
    return false;
  }

  Future<void> _preguntar() async {
    final nav = navigator;
    if (nav == null) return;
    final si = await confirmar(
      nav.context,
      titulo: '¿Descartar cambios?',
      mensaje: 'Lo que escribiste en este formulario no se ha guardado.',
      confirmar: 'Descartar',
      destructivo: true,
    );
    _preguntando = false;
    if (si && isActive) {
      _descartar = true;
      if (isCurrent) {
        nav.pop();
      } else {
        nav.removeRoute(this);
      }
    }
  }
}

/// Valida un formulario y, si falla, lleva al primer campo con error: lo hace
/// visible y le da el foco para corregirlo enseguida.
bool validarFormulario(GlobalKey<FormState> form) {
  final estado = form.currentState;
  if (estado == null) return false;
  if (estado.validate()) return true;
  Element? primero;
  void buscar(Element e) {
    if (primero != null) return;
    if (e is StatefulElement && e.state is FormFieldState && (e.state as FormFieldState).hasError) {
      primero = e;
      return;
    }
    e.visitChildren(buscar);
  }

  form.currentContext?.visitChildElements(buscar);
  final campo = primero;
  if (campo != null) {
    Scrollable.ensureVisible(campo, alignment: 0.2, duration: const Duration(milliseconds: 200));
    void enfocar(Element e) {
      if (e is StatefulElement && e.widget is EditableText) {
        (e.widget as EditableText).focusNode.requestFocus();
        return;
      }
      e.visitChildren(enfocar);
    }

    campo.visitChildren(enfocar);
  }
  return false;
}

/// Estructura común de las hojas: título, contenido desplazable y una barra
/// inferior fija con la acción principal (se eleva sobre el teclado).
///
/// Mientras corre [onPrimary] el botón queda ocupado: un segundo toque no
/// repite la operación.
class SheetScaffold extends StatefulWidget {
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
    this.hayCambios,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  final String? primaryLabel;
  final FutureOr<void> Function()? onPrimary;
  final bool busy;

  /// Acción secundaria a la izquierda de la principal (p. ej. Eliminar).
  final Widget? secondary;
  final Widget? headerAction;

  /// Si devuelve true, cerrar la hoja pregunta antes de descartar.
  final bool Function()? hayCambios;

  @override
  State<SheetScaffold> createState() => _SheetScaffoldState();
}

class _SheetScaffoldState extends State<SheetScaffold> {
  bool _ocupado = false;

  Future<void> _primaria() async {
    if (_ocupado) return;
    final r = widget.onPrimary?.call();
    if (r is! Future) return;
    setState(() => _ocupado = true);
    try {
      await r;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final busy = widget.busy || _ocupado;
    final ruta = ModalRoute.of(context);
    // Guardar también cierra la hoja: eso no es descartar.
    if (ruta is _RutaHoja) ruta.hayCambios = widget.hayCambios == null ? null : () => !busy && !_ocupado && widget.hayCambios!();
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
                  if (widget.icon != null) ...[IconBadge(widget.icon!, size: 40), const HGap.sm()],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(header: true, child: Text(widget.title, style: context.text.titleLarge)),
                        if (widget.subtitle != null) Text(widget.subtitle!, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  ?widget.headerAction,
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
              ),
            ),
            if (widget.primaryLabel != null)
              Container(
                padding: EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.sm + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(top: BorderSide(color: p.border)),
                ),
                child: Row(
                  children: [
                    if (widget.secondary != null) ...[widget.secondary!, const HGap.sm()],
                    Expanded(
                      child: FilledButton(
                        onPressed: busy || widget.onPrimary == null ? null : _primaria,
                        child: AnimatedSwitcher(
                          duration: Motion.of(context, Motion.fast),
                          child: busy
                              ? SizedBox(
                                  key: const ValueKey('busy'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.4, color: p.textSecondary),
                                )
                              : Text(widget.primaryLabel!, key: const ValueKey('label')),
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
  String cancelar = 'Cancelar',
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
          child: Text(cancelar),
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
