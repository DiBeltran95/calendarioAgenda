import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/net/json.dart';

/// Tipos de inversión que ofrece el formulario.
class TipoInversion {
  const TipoInversion(this.valor, this.etiqueta, this.icono, this.par, this.ejemplo);
  final String valor;
  final String etiqueta;
  final IconData icono;
  final ColorPar par;

  /// Sugerencia para el nombre.
  final String ejemplo;
}

const tiposInversion = <TipoInversion>[
  TipoInversion('dolares', 'Dólares', Icons.attach_money_rounded, ColorPar(Color(0xFF8F5706), Color(0xFFF5C451)), 'Ej.: ARQ'),
  TipoInversion('ganado', 'Ganado', Icons.agriculture_rounded, ColorPar(Color(0xFF8F5706), Color(0xFFFBBF24)), 'Ej.: 10 novillos de levante'),
  TipoInversion('inmueble', 'Casa o terreno', Icons.home_work_rounded, ColorPar(Color(0xFF1D4ED8), Color(0xFF60A5FA)), 'Ej.: Casa en Villeta'),
  TipoInversion('vehiculo', 'Vehículo', Icons.directions_car_rounded, ColorPar(Color(0xFF0E7490), Color(0xFF22D3EE)), 'Ej.: Moto de trabajo'),
  TipoInversion('negocio', 'Negocio', Icons.storefront_rounded, ColorPar(Color(0xFF6D28D9), Color(0xFFA78BFA)), 'Ej.: Tienda del barrio'),
  TipoInversion('otro', 'Otro', Icons.category_rounded, ColorPar(Color(0xFF475569), Color(0xFF94A3B8)), 'Ej.: Maquinaria'),
];

TipoInversion tipoInversion(String v) => tiposInversion.firstWhere((t) => t.valor == v, orElse: () => tiposInversion.last);

/// Qué pasó con la inversión en una fecha.
enum TipoMovimiento {
  /// Entró dinero (o se registró lo que ya tenía).
  aporte('aporte', 'Inversión'),

  /// Se vendió una parte.
  retiro('retiro', 'Venta de una parte'),

  /// Se vendió todo: la inversión queda cerrada.
  venta('venta', 'Venta total'),

  /// "Hoy vale esto". No mueve dinero.
  valoracion('valoracion', 'Valor actualizado');

  const TipoMovimiento(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  static TipoMovimiento de(String v) => values.firstWhere((t) => t.valor == v, orElse: () => aporte);
}

class MovimientoInversion {
  const MovimientoInversion({required this.id, required this.tipo, required this.monto, this.montoUsd, required this.fecha, this.cuentaId, this.cuentaNombre, this.nota = ''});

  factory MovimientoInversion.fromJson(Map<String, dynamic> m) => MovimientoInversion(
        id: asInt(m['id']),
        tipo: TipoMovimiento.de(asString(m['tipo'])),
        monto: asDouble(m['monto']),
        montoUsd: m['monto_usd'] == null ? null : asDouble(m['monto_usd']),
        fecha: asString(m['fecha']),
        cuentaId: asIntOrNull(m['cuenta_id']),
        cuentaNombre: m['cuenta_nombre'] == null ? null : asString(m['cuenta_nombre']),
        nota: asString(m['nota']),
      );

  final int id;
  final TipoMovimiento tipo;
  final double monto;

  /// Dólares comprados, vendidos o que se tienen hoy (en inversiones en dólares).
  final double? montoUsd;
  final String fecha;
  final int? cuentaId;
  final String? cuentaNombre;
  final String nota;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tipo': tipo.valor,
        'monto': monto,
        'monto_usd': montoUsd,
        'fecha': fecha,
        'cuenta_id': cuentaId,
        'cuenta_nombre': cuentaNombre,
        'nota': nota,
      };
}

class Inversion {
  Inversion({required this.id, required this.nombre, required this.tipo, this.nota = '', required List<MovimientoInversion> movimientos})
      : movimientos = [...movimientos]..sort((a, b) {
            final f = a.fecha.compareTo(b.fecha);
            return f != 0 ? f : a.id.compareTo(b.id);
          });

  factory Inversion.fromJson(Map<String, dynamic> m) => Inversion(
        id: asInt(m['id']),
        nombre: asString(m['nombre']),
        tipo: asString(m['tipo']),
        nota: asString(m['nota']),
        movimientos: parseList(m['movimientos'], MovimientoInversion.fromJson),
      );

  final int id;
  final String nombre;
  final String tipo;
  final String nota;

  /// Del más antiguo al más reciente.
  final List<MovimientoInversion> movimientos;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'nota': nota,
        'movimientos': [for (final m in movimientos) m.toJson()],
      };

  /// Dólares comprados en ARQ y similares: se lleva la cuenta en dólares y el valor
  /// en pesos sale del dólar más reciente que se conozca.
  bool get esDolares => tipo == 'dolares';

  /// Dólares que había al terminar el día [fecha].
  double usdEn(String fecha) {
    var u = 0.0;
    for (final m in movimientos) {
      if (m.fecha.compareTo(fecha) > 0) break;
      final d = m.montoUsd ?? 0;
      switch (m.tipo) {
        case TipoMovimiento.aporte:
          u += d;
        case TipoMovimiento.retiro:
          u = u > d ? u - d : 0;
        case TipoMovimiento.venta:
          u = 0;
        case TipoMovimiento.valoracion:
          u = d;
      }
    }
    return u;
  }

  /// Dólares que hay hoy.
  double get usd => usdEn('9999-12-31');

  /// Pesos por dólar en la operación más reciente hasta [fecha].
  double? tasaEn(String fecha) {
    double? t;
    for (final m in movimientos) {
      if (m.fecha.compareTo(fecha) > 0) break;
      final d = m.montoUsd ?? 0;
      if (d > 0 && m.monto > 0) t = m.monto / d;
    }
    return t;
  }

  double? get tasaActual => tasaEn('9999-12-31');

  /// Todos los dólares que se han comprado.
  double get usdComprados => movimientos.where((m) => m.tipo == TipoMovimiento.aporte).fold(0, (s, m) => s + (m.montoUsd ?? 0));

  /// A cuánto salió cada dólar comprado, en promedio.
  double? get dolarPromedio => usdComprados > 0 ? invertido / usdComprados : null;

  /// Valor de la inversión al terminar el día [fecha] (YYYY-MM-DD).
  double valorEn(String fecha) {
    if (esDolares) return usdEn(fecha) * (tasaEn(fecha) ?? 0);
    var v = 0.0;
    for (final m in movimientos) {
      if (m.fecha.compareTo(fecha) > 0) break;
      switch (m.tipo) {
        case TipoMovimiento.aporte:
          v += m.monto;
        case TipoMovimiento.retiro:
          v = v > m.monto ? v - m.monto : 0;
        case TipoMovimiento.venta:
          v = 0;
        case TipoMovimiento.valoracion:
          v = m.monto;
      }
    }
    return v;
  }

  /// Valor con todo lo registrado.
  double get valor => valorEn('9999-12-31');

  /// Todo lo que se ha metido.
  double get invertido => movimientos.where((m) => m.tipo == TipoMovimiento.aporte).fold(0, (s, m) => s + m.monto);

  /// Todo lo que se ha recibido por ventas.
  double get recibido => movimientos.where((m) => m.tipo == TipoMovimiento.retiro || m.tipo == TipoMovimiento.venta).fold(0, (s, m) => s + m.monto);

  /// Lo que vale más lo que ya devolvió, menos lo que costó.
  double get ganancia => valor + recibido - invertido;

  /// Ganancia sobre lo invertido, en %. null si no hay nada invertido.
  double? get rentabilidad => invertido > 0 ? ganancia / invertido * 100 : null;

  bool get vendida => movimientos.isNotEmpty && movimientos.last.tipo == TipoMovimiento.venta;

  /// Fecha de la primera inversión.
  String? get desde => movimientos.where((m) => m.tipo == TipoMovimiento.aporte).firstOrNull?.fecha;
}

/// Suma del valor de todas las inversiones.
double valorTotalInversiones(Iterable<Inversion> lista) => lista.fold(0, (s, i) => s + i.valor);
