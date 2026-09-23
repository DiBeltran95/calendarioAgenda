// Modelos de dominio tal como los envía el backend (`/api/...`).
//
// Los nombres de clase y campo son los que usa la interfaz; `fromJson` traduce
// desde las columnas de MySQL (snake_case, DECIMAL como texto, 0/1, etc.).

import '../core/net/json.dart';

class Usuario {
  const Usuario({required this.id, required this.nombre, required this.email, this.whatsapp = ''});
  final int id;
  final String nombre;
  final String email;
  final String whatsapp;

  factory Usuario.fromJson(Map<String, dynamic> j) => Usuario(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        email: asString(j['email']),
        whatsapp: asString(j['whatsapp']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'email': email, 'whatsapp': whatsapp};

  String get primerNombre => nombre.trim().split(RegExp(r'\s+')).first;
  String get iniciales {
    final p = nombre.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    return (p.first[0] + (p.length > 1 ? p[1][0] : '')).toUpperCase();
  }
}

// ─────────────────────────── Eventos ───────────────────────────

class Evento {
  const Evento({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.hora,
    this.categoria = 'reunion',
    this.ubicacion = '',
    this.frecuencia = 'unica',
    this.costo = 0,
    this.tipoTransaccion = 'ninguno',
    this.estadoPago = 'pendiente',
    this.parentId,
    this.tarjetaCreditoId,
    this.transaccionId,
    this.uuidConfirmacion,
  });

  final int id;
  final String titulo;
  final String fecha;

  /// `HH:mm`; null = todo el día.
  final String? hora;
  final String categoria;
  final String ubicacion;
  final String frecuencia;
  final double costo;
  final String tipoTransaccion;
  final String estadoPago;
  final int? parentId;
  final int? tarjetaCreditoId;
  final int? transaccionId;
  final String? uuidConfirmacion;

  bool get esTransaccion => tipoTransaccion != 'ninguno';
  bool get pagado => estadoPago == 'pagado';

  factory Evento.fromJson(Map<String, dynamic> j) => Evento(
        id: asInt(j['id']),
        titulo: asString(j['titulo']),
        fecha: asFecha(j['fecha']),
        hora: asHora(j['hora']),
        categoria: asStringOrNull(j['categoria']) ?? 'general',
        ubicacion: asString(j['ubicacion']),
        frecuencia: asStringOrNull(j['frecuencia']) ?? asStringOrNull(j['repeticion']) ?? 'unica',
        costo: asDouble(j['costo']),
        tipoTransaccion: asStringOrNull(j['tipo_transaccion']) ?? 'ninguno',
        estadoPago: asStringOrNull(j['estado_pago']) ?? 'pendiente',
        parentId: asIntOrNull(j['parent_id']),
        tarjetaCreditoId: asIntOrNull(j['tarjeta_credito_id']),
        transaccionId: asIntOrNull(j['transaccion_id']),
        uuidConfirmacion: asStringOrNull(j['uuid_confirmacion']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'fecha': fecha,
        'hora': hora,
        'categoria': categoria,
        'ubicacion': ubicacion,
        'frecuencia': frecuencia,
        'costo': costo,
        'tipo_transaccion': tipoTransaccion,
        'estado_pago': estadoPago,
        'parent_id': parentId,
        'tarjeta_credito_id': tarjetaCreditoId,
        'transaccion_id': transaccionId,
        'uuid_confirmacion': uuidConfirmacion,
      };

  Evento copyWith({String? estadoPago}) => Evento(
        id: id,
        titulo: titulo,
        fecha: fecha,
        hora: hora,
        categoria: categoria,
        ubicacion: ubicacion,
        frecuencia: frecuencia,
        costo: costo,
        tipoTransaccion: tipoTransaccion,
        estadoPago: estadoPago ?? this.estadoPago,
        parentId: parentId,
        tarjetaCreditoId: tarjetaCreditoId,
        transaccionId: transaccionId,
        uuidConfirmacion: uuidConfirmacion,
      );
}

class Cumple {
  const Cumple({required this.id, required this.nombre, required this.fecha, this.anioNacimiento, this.telefono = '', this.mensaje = ''});
  final int id;
  final String nombre;

  /// Solo importan mes y día: se repite cada año.
  final String fecha;
  final int? anioNacimiento;
  final String telefono;
  final String mensaje;

  factory Cumple.fromJson(Map<String, dynamic> j) => Cumple(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        fecha: asFecha(j['fecha']),
        anioNacimiento: asIntOrNull(j['anio_nacimiento']),
        telefono: asString(j['telefono']),
        mensaje: asString(j['mensaje']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'fecha': fecha,
        'anio_nacimiento': anioNacimiento,
        'telefono': telefono,
        'mensaje': mensaje,
      };
}

/// Día especial configurado en el servidor (tabla `dias_importantes`).
class DiaImportante {
  const DiaImportante({required this.fecha, required this.nombre, this.categoria = '', this.descripcion = ''});
  final String fecha;
  final String nombre;
  final String categoria;
  final String descripcion;

  factory DiaImportante.fromJson(Map<String, dynamic> j) => DiaImportante(
        fecha: asFecha(j['date']),
        nombre: asString(j['nombre']),
        categoria: asString(j['categoria']),
        descripcion: asString(j['descripcion']),
      );

  Map<String, dynamic> toJson() => {'date': fecha, 'nombre': nombre, 'categoria': categoria, 'descripcion': descripcion};
}

// ─────────────────────────── Ciclo ───────────────────────────

class Ciclo {
  const Ciclo({required this.id, required this.fechaInicio, this.observacion = '', this.diasSangrado});
  final int id;
  final String fechaInicio;
  final String observacion;
  final int? diasSangrado;

  factory Ciclo.fromJson(Map<String, dynamic> j) => Ciclo(
        id: asInt(j['id']),
        fechaInicio: asFecha(j['fecha_inicio']),
        observacion: asString(j['observacion']),
        diasSangrado: asIntOrNull(j['dias_sangrado']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'fecha_inicio': fechaInicio, 'observacion': observacion, 'dias_sangrado': diasSangrado};
}

// ─────────────────────────── Finanzas ───────────────────────────

class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    this.saldo = 0,
    this.limite = 0,
    this.interesTasa = 0,
    this.fechaInicio,
    this.plazoDias = 0,
    this.diaCorte,
  });
  final int id;
  final String nombre;

  /// ahorros · corriente · tarjeta_credito · cdt · efectivo · otro
  final String tipo;

  /// En tarjetas de crédito es la DEUDA.
  final double saldo;
  final double limite;
  final double interesTasa;
  final String? fechaInicio;
  final int plazoDias;
  final int? diaCorte;

  factory Cuenta.fromJson(Map<String, dynamic> j) => Cuenta(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        tipo: asStringOrNull(j['tipo']) ?? 'otro',
        saldo: asDouble(j['saldo']),
        limite: asDouble(j['limite']),
        interesTasa: asDouble(j['interes_tasa']),
        fechaInicio: asFechaOrNull(j['fecha_inicio']),
        plazoDias: asInt(j['plazo_dias']),
        diaCorte: asIntOrNull(j['dia_corte']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'tipo': tipo,
        'saldo': saldo,
        'limite': limite,
        'interes_tasa': interesTasa,
        'fecha_inicio': fechaInicio,
        'plazo_dias': plazoDias,
        'dia_corte': diaCorte,
      };
}

class Transaccion {
  const Transaccion({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.descripcion = '',
    this.cuentaId,
    this.categoria = 'otros',
    this.cuotas = 1,
    this.ingresoPlanificadoId,
  });
  final int id;
  final int? cuentaId;

  /// gasto · ingreso
  final String tipo;
  final double monto;
  final String descripcion;
  final String fecha;
  final String categoria;
  final int cuotas;
  final int? ingresoPlanificadoId;

  factory Transaccion.fromJson(Map<String, dynamic> j) => Transaccion(
        id: asInt(j['id']),
        cuentaId: asIntOrNull(j['cuenta_id']),
        tipo: asStringOrNull(j['tipo']) ?? 'gasto',
        monto: asDouble(j['monto']),
        descripcion: asString(j['descripcion']),
        fecha: asFecha(j['fecha']),
        categoria: asStringOrNull(j['categoria']) ?? 'otros',
        cuotas: asInt(j['cuotas'], fallback: 1),
        ingresoPlanificadoId: asIntOrNull(j['ingreso_planificado_id']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cuenta_id': cuentaId,
        'tipo': tipo,
        'monto': monto,
        'descripcion': descripcion,
        'fecha': fecha,
        'categoria': categoria,
        'cuotas': cuotas,
        'ingreso_planificado_id': ingresoPlanificadoId,
      };
}

class Transferencia {
  const Transferencia({required this.id, required this.cuentaOrigenId, required this.cuentaDestinoId, required this.monto, required this.fecha, this.descripcion = ''});
  final int id;
  final int cuentaOrigenId;
  final int cuentaDestinoId;
  final double monto;
  final String descripcion;
  final String fecha;

  factory Transferencia.fromJson(Map<String, dynamic> j) => Transferencia(
        id: asInt(j['id']),
        cuentaOrigenId: asInt(j['cuenta_origen_id']),
        cuentaDestinoId: asInt(j['cuenta_destino_id']),
        monto: asDouble(j['monto']),
        descripcion: asString(j['descripcion']),
        fecha: asFecha(j['fecha']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cuenta_origen_id': cuentaOrigenId,
        'cuenta_destino_id': cuentaDestinoId,
        'monto': monto,
        'descripcion': descripcion,
        'fecha': fecha,
      };
}

class IngresoPlanificado {
  const IngresoPlanificado({required this.id, required this.descripcion, required this.monto, required this.frecuencia, required this.fechaInicio, this.cuentaId, this.activo = true});
  final int id;
  final int? cuentaId;
  final String descripcion;
  final double monto;

  /// diario · semanal · quincenal · mensual · unica
  final String frecuencia;
  final String fechaInicio;
  final bool activo;

  factory IngresoPlanificado.fromJson(Map<String, dynamic> j) => IngresoPlanificado(
        id: asInt(j['id']),
        cuentaId: asIntOrNull(j['cuenta_id']),
        descripcion: asString(j['descripcion']),
        monto: asDouble(j['monto']),
        frecuencia: asStringOrNull(j['frecuencia']) ?? 'mensual',
        fechaInicio: asFecha(j['fecha_inicio']),
        activo: asBool(j['activo'], fallback: true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cuenta_id': cuentaId,
        'descripcion': descripcion,
        'monto': monto,
        'frecuencia': frecuencia,
        'fecha_inicio': fechaInicio,
        'activo': activo ? 1 : 0,
      };
}

class Verificacion {
  const Verificacion({required this.id, required this.ingresoPlanificadoId, required this.fechaEsperada, required this.fechaReal, required this.montoReal, this.transaccionId});
  final int id;
  final int ingresoPlanificadoId;
  final String fechaEsperada;
  final String fechaReal;
  final double montoReal;
  final int? transaccionId;

  factory Verificacion.fromJson(Map<String, dynamic> j) => Verificacion(
        id: asInt(j['id']),
        ingresoPlanificadoId: asInt(j['ingreso_planificado_id']),
        fechaEsperada: asFecha(j['fecha_esperada']),
        fechaReal: asFecha(j['fecha_real']),
        montoReal: asDouble(j['monto_real']),
        transaccionId: asIntOrNull(j['transaccion_id']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'ingreso_planificado_id': ingresoPlanificadoId,
        'fecha_esperada': fechaEsperada,
        'fecha_real': fechaReal,
        'monto_real': montoReal,
        'transaccion_id': transaccionId,
      };
}

class Meta {
  const Meta({
    required this.id,
    required this.nombre,
    required this.montoObjetivo,
    this.descripcion = '',
    this.montoActual = 0,
    this.fechaObjetivo,
    this.icono = 'savings',
    this.color = 0xFF34E47E,
    this.completada = false,
  });
  final int id;
  final String nombre;
  final String descripcion;
  final double montoObjetivo;
  final double montoActual;
  final String? fechaObjetivo;
  final String icono;

  /// ARGB (el servidor lo guarda como `#RRGGBB`).
  final int color;
  final bool completada;

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        descripcion: asString(j['descripcion']),
        montoObjetivo: asDouble(j['monto_objetivo']),
        montoActual: asDouble(j['monto_actual']),
        fechaObjetivo: asFechaOrNull(j['fecha_objetivo']),
        icono: asStringOrNull(j['icono']) ?? 'savings',
        color: colorDesdeHex(j['color']),
        completada: asBool(j['completada']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'monto_objetivo': montoObjetivo,
        'monto_actual': montoActual,
        'fecha_objetivo': fechaObjetivo,
        'icono': icono,
        'color': colorAHex(color),
        'completada': completada ? 1 : 0,
      };
}

class Presupuesto {
  const Presupuesto({required this.id, required this.categoria, required this.montoLimite, required this.mes, required this.anio});
  final int id;
  final String categoria;
  final double montoLimite;

  /// 1..12
  final int mes;
  final int anio;

  factory Presupuesto.fromJson(Map<String, dynamic> j) => Presupuesto(
        id: asInt(j['id']),
        categoria: asString(j['categoria']),
        montoLimite: asDouble(j['monto_limite']),
        mes: asInt(j['mes']),
        anio: asInt(j['anio']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'categoria': categoria, 'monto_limite': montoLimite, 'mes': mes, 'anio': anio};
}

class CategoriaFinanzas {
  const CategoriaFinanzas({required this.id, required this.valor, required this.label, this.icono = 'sell', this.esDefault = false});
  final int id;
  final String valor;
  final String label;
  final String icono;
  final bool esDefault;

  factory CategoriaFinanzas.fromJson(Map<String, dynamic> j) => CategoriaFinanzas(
        id: asInt(j['id']),
        valor: asString(j['valor']),
        label: asString(j['label']),
        icono: asStringOrNull(j['icono']) ?? 'sell',
        esDefault: asBool(j['es_default']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'valor': valor, 'label': label, 'icono': icono, 'es_default': esDefault ? 1 : 0};
}

// ─────────────────────────── Cargas agrupadas ───────────────────────────

/// Respuesta de `/api/dashboard/bootstrap`: lo que no depende del mes.
class Bootstrap {
  const Bootstrap({
    this.cumples = const [],
    this.ciclos = const [],
    this.cuentas = const [],
    this.planes = const [],
    this.verificaciones = const [],
    this.metas = const [],
    this.categorias = const [],
    this.categoriasUsadas = const {},
  });

  final List<Cumple> cumples;
  final List<Ciclo> ciclos;
  final List<Cuenta> cuentas;
  final List<IngresoPlanificado> planes;
  final List<Verificacion> verificaciones;
  final List<Meta> metas;
  final List<CategoriaFinanzas> categorias;
  final Set<String> categoriasUsadas;

  static const vacio = Bootstrap();

  factory Bootstrap.fromJson(Map<String, dynamic> j) {
    final f = asMap(j['finanzas']);
    return Bootstrap(
      cumples: parseList(j['cumpleanos'], Cumple.fromJson),
      ciclos: parseList(j['cycles'], Ciclo.fromJson),
      cuentas: parseList(f['cuentas'], Cuenta.fromJson),
      planes: parseList(f['ingresosPlanificados'], IngresoPlanificado.fromJson),
      verificaciones: parseList(f['verificaciones'], Verificacion.fromJson),
      metas: parseList(f['metas'], Meta.fromJson),
      categorias: parseList(f['categorias'], CategoriaFinanzas.fromJson),
      categoriasUsadas: {for (final c in (j['categoriasUsadas'] as List? ?? const [])) '$c'},
    );
  }

  Map<String, dynamic> toJson() => {
        'cumpleanos': [for (final x in cumples) x.toJson()],
        'cycles': [for (final x in ciclos) x.toJson()],
        'categoriasUsadas': categoriasUsadas.toList(),
        'finanzas': {
          'cuentas': [for (final x in cuentas) x.toJson()],
          'ingresosPlanificados': [for (final x in planes) x.toJson()],
          'verificaciones': [for (final x in verificaciones) x.toJson()],
          'metas': [for (final x in metas) x.toJson()],
          'categorias': [for (final x in categorias) x.toJson()],
        },
      };
}

/// Respuesta de `/api/dashboard/month`: lo de alto volumen, acotado a un mes.
class MonthData {
  const MonthData({this.eventos = const [], this.transacciones = const [], this.transferencias = const [], this.presupuestos = const []});

  final List<Evento> eventos;
  final List<Transaccion> transacciones;
  final List<Transferencia> transferencias;
  final List<Presupuesto> presupuestos;

  static const vacio = MonthData();

  factory MonthData.fromJson(Map<String, dynamic> j) => MonthData(
        eventos: parseList(j['events'], Evento.fromJson),
        transacciones: parseList(j['transacciones'], Transaccion.fromJson),
        transferencias: parseList(j['transferencias'], Transferencia.fromJson),
        presupuestos: parseList(j['presupuestos'], Presupuesto.fromJson),
      );

  Map<String, dynamic> toJson() => {
        'events': [for (final x in eventos) x.toJson()],
        'transacciones': [for (final x in transacciones) x.toJson()],
        'transferencias': [for (final x in transferencias) x.toJson()],
        'presupuestos': [for (final x in presupuestos) x.toJson()],
      };

  MonthData conEventos(List<Evento> e) =>
      MonthData(eventos: e, transacciones: transacciones, transferencias: transferencias, presupuestos: presupuestos);
}
