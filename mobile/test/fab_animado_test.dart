import 'package:agendaservi/core/widgets/fab_animado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({bool activo = true}) => MaterialApp(
        home: TickerMode(
          enabled: activo,
          child: Scaffold(floatingActionButton: FabAnimado(icono: Icons.add, etiqueta: 'Nuevo evento', onPressed: () {})),
        ),
      );

  double ancho(WidgetTester t) => t.getSize(find.byType(FloatingActionButton)).width;

  testWidgets('al entrar muestra el texto y luego se recoge al tamaño de un FAB', (t) async {
    await t.pumpWidget(app());
    await t.pump(const Duration(milliseconds: 600));
    final desplegado = ancho(t);
    expect(desplegado, greaterThan(120));

    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 700));
    expect(ancho(t), lessThan(60)); // solo el ícono: tamaño de un FAB normal

    // Al volver al módulo se presenta de nuevo.
    await t.pumpWidget(app(activo: false));
    await t.pumpWidget(app());
    await t.pump(const Duration(milliseconds: 600));
    expect(ancho(t), closeTo(desplegado, 0.5));
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('el lector de pantalla anuncia la acción aunque esté recogido', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(app());
    await t.pump(const Duration(seconds: 4));
    expect(find.bySemanticsLabel('Nuevo evento'), findsOneWidget);
    h.dispose();
  });
}
