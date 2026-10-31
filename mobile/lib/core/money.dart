import 'package:intl/intl.dart';

final _miles = NumberFormat.decimalPattern('es_CO');

/// `$ 1.250.000` en pesos colombianos, sin decimales.
///
/// Se arma a mano: el patrón de moneda de `es_CO` en intl pone el símbolo al
/// final ("1.250.000 $"), que no es como se escribe en Colombia.
String cop(num valor) {
  final n = valor.round();
  final s = '\$ ${_miles.format(n.abs())}';
  return n < 0 ? '-$s' : s;
}

final _dolares = NumberFormat('#,##0.00', 'es_CO');

/// `US\$ 1.250,50`: los dólares sí llevan centavos.
String usd(num valor) {
  final s = 'US\$ ${_dolares.format(valor.abs())}';
  return valor < 0 ? '-$s' : s;
}

/// Versión con signo explícito para flujos: `+$ 50.000` / `-$ 20.000`.
String copConSigno(num valor) => valor >= 0 ? '+${cop(valor)}' : cop(valor);

/// Forma compacta para ejes de gráficas: 1,2M · 350K · 900.
String copCompacto(num v) {
  final a = v.abs();
  if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (a >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

/// Separador de miles para los campos de dinero mientras se escribe.
String miles(num v) => _miles.format(v);

/// Redondeo a 2 decimales (las cuotas se reparten así, como en el backend).
double redondear2(double v) => (v * 100).roundToDouble() / 100;
