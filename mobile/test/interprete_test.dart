// Captura rápida: frases como las dice la gente en Colombia.

import 'package:agendaservi/features/captura/interprete.dart';
import 'package:flutter_test/flutter_test.dart';

// Viernes 30 de octubre de 2026, 9:00 a. m.
final _ahora = DateTime(2026, 10, 30, 9);

void main() {
  void movimiento(String frase, {required double monto, bool ingreso = false, String? desc, String fecha = '2026-10-30'}) {
    test('"$frase"', () {
      final r = interpretarFrase(frase, _ahora);
      expect(r, isA<MovimientoCapturado>());
      r as MovimientoCapturado;
      expect(r.monto, monto);
      expect(r.ingreso, ingreso);
      expect(r.fecha, fecha);
      if (desc != null) expect(r.descripcion, desc);
    });
  }

  void evento(String frase, {required String titulo, String fecha = '2026-10-30', String? hora, String categoria = 'reunion'}) {
    test('"$frase"', () {
      final r = interpretarFrase(frase, _ahora);
      expect(r, isA<EventoCapturado>());
      r as EventoCapturado;
      expect(r.titulo, titulo);
      expect(r.fecha, fecha);
      expect(r.hora, hora);
      expect(r.categoria, categoria);
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
  });

  group('ingresos', () {
    movimiento('me pagaron 2 millones', monto: 2000000, ingreso: true, desc: 'Me pagaron');
    movimiento('recibí 50 mil de Juan', monto: 50000, ingreso: true, desc: 'Recibí de Juan');
    movimiento('salario 3.500.000', monto: 3500000, ingreso: true, desc: 'Salario');
    movimiento('vendí la bicicleta en 400 mil', monto: 400000, ingreso: true);
  });

  group('eventos', () {
    evento('cita con Ana mañana 3pm', titulo: 'Cita con Ana', fecha: '2026-10-31', hora: '15:00');
    evento('reunión con el contador el lunes a las 10', titulo: 'Reunión con el contador', fecha: '2026-11-02', hora: '10:00');
    evento('dentista el 12 de noviembre a las 3 de la tarde', titulo: 'Dentista', fecha: '2026-11-12', hora: '15:00', categoria: 'dentista');
    evento('doctor mañana a las 8:30 am', titulo: 'Doctor', fecha: '2026-10-31', hora: '08:30', categoria: 'doctor');
    evento('llamar a mamá a las 7 de la noche', titulo: 'Llamar a mamá', hora: '19:00');
    evento('cambiar aceite pasado mañana', titulo: 'Cambiar aceite', fecha: '2026-11-01', categoria: 'aceite_moto');
    evento('tengo taller de la moto el viernes', titulo: 'Taller de la moto', fecha: '2026-11-06', categoria: 'mecanica');
    evento('almuerzo con Laura a las 12:30 p. m.', titulo: 'Almuerzo con Laura', hora: '12:30');
    evento('reunión 15/11 a las 16:00', titulo: 'Reunión', fecha: '2026-11-15', hora: '16:00');
    evento('pagar el SOAT el 5', titulo: 'Pagar el SOAT', fecha: '2026-11-05');
    evento('entrevista en enero 20 de enero', titulo: 'Entrevista en enero', fecha: '2027-01-20');
    evento('comprar leche', titulo: 'Comprar leche');
    evento('Reunión a mediodía', titulo: 'Reunión', hora: '12:00');
    test('evento con hora y costo', () {
      final r = interpretarFrase('peluquería mañana 4pm 60 mil', _ahora)! as EventoCapturado;
      expect((r.titulo, r.hora, r.monto), ('Peluquería', '16:00', 60000.0));
    });
  });

  group('cumpleaños', () {
    test('"cumpleaños de mamá 12 de marzo"', () {
      final r = interpretarFrase('cumpleaños de mamá 12 de marzo', _ahora)! as CumpleCapturado;
      expect((r.nombre, r.fecha), ('Mamá', '2027-03-12'));
    });
    test('sin fecha no se confunde: queda como evento', () {
      expect(interpretarFrase('cumpleaños de mamá', _ahora), isA<EventoCapturado>());
    });
  });

  group('sin nada que registrar', () {
    for (final f in ['', '   ', 'el', 'mañana']) {
      test('"$f"', () => expect(interpretarFrase(f, _ahora), isNull));
    }
  });

  test('números pequeños no son dinero', () {
    final r = interpretarFrase('reunión con 5 personas', _ahora)! as EventoCapturado;
    expect(r.monto, isNull);
    expect(r.titulo, 'Reunión con 5 personas');
  });
}
