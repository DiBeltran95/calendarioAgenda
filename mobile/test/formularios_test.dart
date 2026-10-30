// Formularios: no se envían dos veces, avisan antes de perder lo escrito y
// marcan el error junto al campo.

import 'dart:async';

import 'package:agendaservi/app/theme/app_module.dart';
import 'package:agendaservi/app/theme/app_theme.dart';
import 'package:agendaservi/core/widgets/sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pantalla mínima con un botón que abre la hoja.
Widget _app(WidgetBuilder hoja) => MaterialApp(
      theme: buildTheme(Brightness.light, AppModule.inicio),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => showAppSheet<void>(context, hoja), child: const Text('Abrir'))),
        ),
      ),
    );

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('dos toques seguidos solo guardan una vez', (t) async {
    final fin = Completer<void>();
    var veces = 0;
    await t.pumpWidget(_app((_) => SheetScaffold(
          title: 'Hoja',
          primaryLabel: 'Guardar',
          onPrimary: () {
            veces++;
            return fin.future;
          },
          children: const [SizedBox(height: 40)],
        )));
    await t.tap(find.text('Abrir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Guardar'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    // Ya está ocupado: el botón está desactivado y muestra el progreso.
    expect(find.text('Guardar'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.tap(find.byType(FilledButton), warnIfMissed: false);
    await t.pump();
    expect(veces, 1);
    fin.complete();
    await t.pumpAndSettle();
    expect(find.text('Guardar'), findsOneWidget);
  });

  group('cerrar con cambios', () {
    Widget hoja(TextEditingController c) => _app((_) => SheetScaffold(
          title: 'Hoja',
          hayCambios: () => c.text.isNotEmpty,
          children: [TextField(controller: c)],
        ));

    testWidgets('sin cambios cierra de una vez', (t) async {
      await t.pumpWidget(hoja(TextEditingController()));
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Cerrar'));
      await t.pumpAndSettle();
      expect(find.text('Hoja'), findsNothing);
      expect(find.text('¿Descartar cambios?'), findsNothing);
    });

    testWidgets('con cambios pregunta: "Cancelar" los conserva y "Descartar" cierra', (t) async {
      await t.pumpWidget(hoja(TextEditingController()));
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'algo');
      await t.tap(find.byTooltip('Cerrar'));
      await t.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);

      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(find.text('Hoja'), findsOneWidget);
      expect(find.text('algo'), findsOneWidget);

      await t.tap(find.byTooltip('Cerrar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Descartar'));
      await t.pumpAndSettle();
      expect(find.text('Hoja'), findsNothing);
    });

    testWidgets('arrastrar la hoja hacia abajo también pregunta y la deja en su sitio', (t) async {
      await t.pumpWidget(hoja(TextEditingController()));
      await t.tap(find.text('Abrir'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'algo');
      await t.fling(find.text('Hoja'), const Offset(0, 500), 2000);
      await t.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);
      await t.tap(find.text('Cancelar'));
      await t.pumpAndSettle();
      expect(find.text('Hoja').hitTestable(), findsOneWidget);
    });
  });

  testWidgets('validarFormulario lleva el foco al primer campo con error', (t) async {
    final form = GlobalKey<FormState>();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: form,
          child: Column(children: [
            TextFormField(key: const Key('a'), validator: (_) => null),
            TextFormField(key: const Key('b'), validator: (v) => (v ?? '').isEmpty ? 'Falta este dato' : null),
          ]),
        ),
      ),
    ));
    expect(validarFormulario(form), isFalse);
    await t.pumpAndSettle();
    expect(find.text('Falta este dato'), findsOneWidget);
    final b = t.widget<EditableText>(find.descendant(of: find.byKey(const Key('b')), matching: find.byType(EditableText)));
    expect(b.focusNode.hasFocus, isTrue);
  });
}
