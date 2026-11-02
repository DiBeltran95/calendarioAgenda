// Captura rápida: frases como las dice la gente en Colombia.

import 'package:agendaservi/features/captura/interprete.dart';
import 'package:flutter_test/flutter_test.dart';

// Viernes 30 de octubre de 2026, 9:00 a. m.
final _ahora = DateTime(2026, 10, 30, 9);

void main() {
  void movimiento(String frase, {required double monto, bool ingreso = false, String? desc, String fecha = '2026-10-30'}) {
    test('"$frase"', () {
      final r = interpretarFrase(frase, _ahora)!;
      expect(r.monto, monto);
      expect(r.ingreso, ingreso);
      expect(r.fecha, fecha);
      if (desc != null) expect(r.descripcion, desc);
    });
  }

  group('gastos', () {
    movimiento('almuerzo 25 mil', monto: 25000, desc: 'Almuerzo');
    movimiento('Almuerzo 25mil', monto: 25000, desc: 'Almuerzo');
    movimiento('gasté 50 mil en gasolina', monto: 50000, desc: 'Gasolina');
    movimiento('pagué 120000 de internet', monto: 120000, desc: 'Internet');
    movimiento('compré un pantalón por \$89.900', monto: 89900, desc: 'Pantalón');
    movimiento('mercado 350.000', monto: 350000, desc: 'Mercado');
    movimiento('taxi 15k', monto: 15000, desc: 'Taxi');
    movimiento('almuerzo 30 lucas', monto: 30000, desc: 'Almuerzo');
    movimiento('arriendo 1.2 millones', monto: 1200000, desc: 'Arriendo');
    movimiento('moto 2 millones y medio', monto: 2500000, desc: 'Moto');
    movimiento('computador 2 millones 500 mil', monto: 2500000, desc: 'Computador');
    movimiento('cena veinticinco mil', monto: 25000, desc: 'Cena');
    movimiento('tinto dos mil quinientos', monto: 2500, desc: 'Tinto');
    movimiento('zapatos cien mil pesos', monto: 100000, desc: 'Zapatos');
    movimiento('ayer almuerzo 25 mil', monto: 25000, desc: 'Almuerzo', fecha: '2026-10-29');
    movimiento('mercado 80 mil el 15', monto: 80000, desc: 'Mercado', fecha: '2026-10-15');
    movimiento('el lunes almuerzo 25 mil', monto: 25000, desc: 'Almuerzo', fecha: '2026-10-26');
    movimiento('regalo 80 mil el 12 de diciembre', monto: 80000, desc: 'Regalo', fecha: '2025-12-12');
    movimiento('peluquería 4pm 60 mil', monto: 60000, desc: 'Peluquería');
  });

  group('ingresos', () {
    movimiento('me pagaron 2 millones', monto: 2000000, ingreso: true, desc: 'Me pagaron');
    movimiento('recibí 50 mil de Juan', monto: 50000, ingreso: true, desc: 'Recibí de Juan');
    movimiento('salario 3.500.000', monto: 3500000, ingreso: true, desc: 'Salario');
    movimiento('vendí la bicicleta en 400 mil', monto: 400000, ingreso: true);
  });

  group('sin monto no hay nada que registrar', () {
    for (final f in ['', '   ', 'el', 'mañana', 'almuerzo', 'cita con Ana mañana 3pm', 'cumpleaños de mamá 12 de marzo', 'reunión con 5 personas']) {
      test('"$f"', () => expect(interpretarFrase(f, _ahora), isNull));
    }
  });
}
