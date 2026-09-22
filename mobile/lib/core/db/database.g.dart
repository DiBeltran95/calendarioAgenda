// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EventosTable extends Eventos with TableInfo<$EventosTable, Evento> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _horaMeta = const VerificationMeta('hora');
  @override
  late final GeneratedColumn<String> hora = GeneratedColumn<String>(
    'hora',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriaMeta = const VerificationMeta(
    'categoria',
  );
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('reunion'),
  );
  static const VerificationMeta _ubicacionMeta = const VerificationMeta(
    'ubicacion',
  );
  @override
  late final GeneratedColumn<String> ubicacion = GeneratedColumn<String>(
    'ubicacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notasMeta = const VerificationMeta('notas');
  @override
  late final GeneratedColumn<String> notas = GeneratedColumn<String>(
    'notas',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _frecuenciaMeta = const VerificationMeta(
    'frecuencia',
  );
  @override
  late final GeneratedColumn<String> frecuencia = GeneratedColumn<String>(
    'frecuencia',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unica'),
  );
  static const VerificationMeta _costoMeta = const VerificationMeta('costo');
  @override
  late final GeneratedColumn<double> costo = GeneratedColumn<double>(
    'costo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _tipoTransaccionMeta = const VerificationMeta(
    'tipoTransaccion',
  );
  @override
  late final GeneratedColumn<String> tipoTransaccion = GeneratedColumn<String>(
    'tipo_transaccion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ninguno'),
  );
  static const VerificationMeta _estadoPagoMeta = const VerificationMeta(
    'estadoPago',
  );
  @override
  late final GeneratedColumn<String> estadoPago = GeneratedColumn<String>(
    'estado_pago',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pendiente'),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tarjetaCreditoIdMeta = const VerificationMeta(
    'tarjetaCreditoId',
  );
  @override
  late final GeneratedColumn<int> tarjetaCreditoId = GeneratedColumn<int>(
    'tarjeta_credito_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transaccionIdMeta = const VerificationMeta(
    'transaccionId',
  );
  @override
  late final GeneratedColumn<int> transaccionId = GeneratedColumn<int>(
    'transaccion_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    titulo,
    fecha,
    hora,
    categoria,
    ubicacion,
    notas,
    frecuencia,
    costo,
    tipoTransaccion,
    estadoPago,
    parentId,
    tarjetaCreditoId,
    transaccionId,
    creadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eventos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Evento> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('hora')) {
      context.handle(
        _horaMeta,
        hora.isAcceptableOrUnknown(data['hora']!, _horaMeta),
      );
    }
    if (data.containsKey('categoria')) {
      context.handle(
        _categoriaMeta,
        categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta),
      );
    }
    if (data.containsKey('ubicacion')) {
      context.handle(
        _ubicacionMeta,
        ubicacion.isAcceptableOrUnknown(data['ubicacion']!, _ubicacionMeta),
      );
    }
    if (data.containsKey('notas')) {
      context.handle(
        _notasMeta,
        notas.isAcceptableOrUnknown(data['notas']!, _notasMeta),
      );
    }
    if (data.containsKey('frecuencia')) {
      context.handle(
        _frecuenciaMeta,
        frecuencia.isAcceptableOrUnknown(data['frecuencia']!, _frecuenciaMeta),
      );
    }
    if (data.containsKey('costo')) {
      context.handle(
        _costoMeta,
        costo.isAcceptableOrUnknown(data['costo']!, _costoMeta),
      );
    }
    if (data.containsKey('tipo_transaccion')) {
      context.handle(
        _tipoTransaccionMeta,
        tipoTransaccion.isAcceptableOrUnknown(
          data['tipo_transaccion']!,
          _tipoTransaccionMeta,
        ),
      );
    }
    if (data.containsKey('estado_pago')) {
      context.handle(
        _estadoPagoMeta,
        estadoPago.isAcceptableOrUnknown(data['estado_pago']!, _estadoPagoMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('tarjeta_credito_id')) {
      context.handle(
        _tarjetaCreditoIdMeta,
        tarjetaCreditoId.isAcceptableOrUnknown(
          data['tarjeta_credito_id']!,
          _tarjetaCreditoIdMeta,
        ),
      );
    }
    if (data.containsKey('transaccion_id')) {
      context.handle(
        _transaccionIdMeta,
        transaccionId.isAcceptableOrUnknown(
          data['transaccion_id']!,
          _transaccionIdMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Evento map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Evento(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      hora: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hora'],
      ),
      categoria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria'],
      )!,
      ubicacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ubicacion'],
      )!,
      notas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notas'],
      )!,
      frecuencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frecuencia'],
      )!,
      costo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}costo'],
      )!,
      tipoTransaccion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_transaccion'],
      )!,
      estadoPago: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado_pago'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_id'],
      ),
      tarjetaCreditoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tarjeta_credito_id'],
      ),
      transaccionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaccion_id'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $EventosTable createAlias(String alias) {
    return $EventosTable(attachedDatabase, alias);
  }
}

class Evento extends DataClass implements Insertable<Evento> {
  final int id;
  final String titulo;
  final String fecha;

  /// HH:mm; null = todo el día.
  final String? hora;
  final String categoria;
  final String ubicacion;
  final String notas;

  /// unica · diaria · quincenal · mensual · trimestral · semestral · anual
  final String frecuencia;
  final double costo;

  /// ninguno · gasto · ingreso
  final String tipoTransaccion;

  /// pendiente · pagado
  final String estadoPago;

  /// Evento maestro de la serie (null en el propio maestro y en los únicos).
  final int? parentId;

  /// Cobros de tarjeta generados por una compra a cuotas.
  final int? tarjetaCreditoId;
  final int? transaccionId;
  final DateTime creadoEn;
  const Evento({
    required this.id,
    required this.titulo,
    required this.fecha,
    this.hora,
    required this.categoria,
    required this.ubicacion,
    required this.notas,
    required this.frecuencia,
    required this.costo,
    required this.tipoTransaccion,
    required this.estadoPago,
    this.parentId,
    this.tarjetaCreditoId,
    this.transaccionId,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['titulo'] = Variable<String>(titulo);
    map['fecha'] = Variable<String>(fecha);
    if (!nullToAbsent || hora != null) {
      map['hora'] = Variable<String>(hora);
    }
    map['categoria'] = Variable<String>(categoria);
    map['ubicacion'] = Variable<String>(ubicacion);
    map['notas'] = Variable<String>(notas);
    map['frecuencia'] = Variable<String>(frecuencia);
    map['costo'] = Variable<double>(costo);
    map['tipo_transaccion'] = Variable<String>(tipoTransaccion);
    map['estado_pago'] = Variable<String>(estadoPago);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    if (!nullToAbsent || tarjetaCreditoId != null) {
      map['tarjeta_credito_id'] = Variable<int>(tarjetaCreditoId);
    }
    if (!nullToAbsent || transaccionId != null) {
      map['transaccion_id'] = Variable<int>(transaccionId);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  EventosCompanion toCompanion(bool nullToAbsent) {
    return EventosCompanion(
      id: Value(id),
      titulo: Value(titulo),
      fecha: Value(fecha),
      hora: hora == null && nullToAbsent ? const Value.absent() : Value(hora),
      categoria: Value(categoria),
      ubicacion: Value(ubicacion),
      notas: Value(notas),
      frecuencia: Value(frecuencia),
      costo: Value(costo),
      tipoTransaccion: Value(tipoTransaccion),
      estadoPago: Value(estadoPago),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      tarjetaCreditoId: tarjetaCreditoId == null && nullToAbsent
          ? const Value.absent()
          : Value(tarjetaCreditoId),
      transaccionId: transaccionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transaccionId),
      creadoEn: Value(creadoEn),
    );
  }

  factory Evento.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Evento(
      id: serializer.fromJson<int>(json['id']),
      titulo: serializer.fromJson<String>(json['titulo']),
      fecha: serializer.fromJson<String>(json['fecha']),
      hora: serializer.fromJson<String?>(json['hora']),
      categoria: serializer.fromJson<String>(json['categoria']),
      ubicacion: serializer.fromJson<String>(json['ubicacion']),
      notas: serializer.fromJson<String>(json['notas']),
      frecuencia: serializer.fromJson<String>(json['frecuencia']),
      costo: serializer.fromJson<double>(json['costo']),
      tipoTransaccion: serializer.fromJson<String>(json['tipoTransaccion']),
      estadoPago: serializer.fromJson<String>(json['estadoPago']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      tarjetaCreditoId: serializer.fromJson<int?>(json['tarjetaCreditoId']),
      transaccionId: serializer.fromJson<int?>(json['transaccionId']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'titulo': serializer.toJson<String>(titulo),
      'fecha': serializer.toJson<String>(fecha),
      'hora': serializer.toJson<String?>(hora),
      'categoria': serializer.toJson<String>(categoria),
      'ubicacion': serializer.toJson<String>(ubicacion),
      'notas': serializer.toJson<String>(notas),
      'frecuencia': serializer.toJson<String>(frecuencia),
      'costo': serializer.toJson<double>(costo),
      'tipoTransaccion': serializer.toJson<String>(tipoTransaccion),
      'estadoPago': serializer.toJson<String>(estadoPago),
      'parentId': serializer.toJson<int?>(parentId),
      'tarjetaCreditoId': serializer.toJson<int?>(tarjetaCreditoId),
      'transaccionId': serializer.toJson<int?>(transaccionId),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  Evento copyWith({
    int? id,
    String? titulo,
    String? fecha,
    Value<String?> hora = const Value.absent(),
    String? categoria,
    String? ubicacion,
    String? notas,
    String? frecuencia,
    double? costo,
    String? tipoTransaccion,
    String? estadoPago,
    Value<int?> parentId = const Value.absent(),
    Value<int?> tarjetaCreditoId = const Value.absent(),
    Value<int?> transaccionId = const Value.absent(),
    DateTime? creadoEn,
  }) => Evento(
    id: id ?? this.id,
    titulo: titulo ?? this.titulo,
    fecha: fecha ?? this.fecha,
    hora: hora.present ? hora.value : this.hora,
    categoria: categoria ?? this.categoria,
    ubicacion: ubicacion ?? this.ubicacion,
    notas: notas ?? this.notas,
    frecuencia: frecuencia ?? this.frecuencia,
    costo: costo ?? this.costo,
    tipoTransaccion: tipoTransaccion ?? this.tipoTransaccion,
    estadoPago: estadoPago ?? this.estadoPago,
    parentId: parentId.present ? parentId.value : this.parentId,
    tarjetaCreditoId: tarjetaCreditoId.present
        ? tarjetaCreditoId.value
        : this.tarjetaCreditoId,
    transaccionId: transaccionId.present
        ? transaccionId.value
        : this.transaccionId,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  Evento copyWithCompanion(EventosCompanion data) {
    return Evento(
      id: data.id.present ? data.id.value : this.id,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      hora: data.hora.present ? data.hora.value : this.hora,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      ubicacion: data.ubicacion.present ? data.ubicacion.value : this.ubicacion,
      notas: data.notas.present ? data.notas.value : this.notas,
      frecuencia: data.frecuencia.present
          ? data.frecuencia.value
          : this.frecuencia,
      costo: data.costo.present ? data.costo.value : this.costo,
      tipoTransaccion: data.tipoTransaccion.present
          ? data.tipoTransaccion.value
          : this.tipoTransaccion,
      estadoPago: data.estadoPago.present
          ? data.estadoPago.value
          : this.estadoPago,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      tarjetaCreditoId: data.tarjetaCreditoId.present
          ? data.tarjetaCreditoId.value
          : this.tarjetaCreditoId,
      transaccionId: data.transaccionId.present
          ? data.transaccionId.value
          : this.transaccionId,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Evento(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('fecha: $fecha, ')
          ..write('hora: $hora, ')
          ..write('categoria: $categoria, ')
          ..write('ubicacion: $ubicacion, ')
          ..write('notas: $notas, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('costo: $costo, ')
          ..write('tipoTransaccion: $tipoTransaccion, ')
          ..write('estadoPago: $estadoPago, ')
          ..write('parentId: $parentId, ')
          ..write('tarjetaCreditoId: $tarjetaCreditoId, ')
          ..write('transaccionId: $transaccionId, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    titulo,
    fecha,
    hora,
    categoria,
    ubicacion,
    notas,
    frecuencia,
    costo,
    tipoTransaccion,
    estadoPago,
    parentId,
    tarjetaCreditoId,
    transaccionId,
    creadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Evento &&
          other.id == this.id &&
          other.titulo == this.titulo &&
          other.fecha == this.fecha &&
          other.hora == this.hora &&
          other.categoria == this.categoria &&
          other.ubicacion == this.ubicacion &&
          other.notas == this.notas &&
          other.frecuencia == this.frecuencia &&
          other.costo == this.costo &&
          other.tipoTransaccion == this.tipoTransaccion &&
          other.estadoPago == this.estadoPago &&
          other.parentId == this.parentId &&
          other.tarjetaCreditoId == this.tarjetaCreditoId &&
          other.transaccionId == this.transaccionId &&
          other.creadoEn == this.creadoEn);
}

class EventosCompanion extends UpdateCompanion<Evento> {
  final Value<int> id;
  final Value<String> titulo;
  final Value<String> fecha;
  final Value<String?> hora;
  final Value<String> categoria;
  final Value<String> ubicacion;
  final Value<String> notas;
  final Value<String> frecuencia;
  final Value<double> costo;
  final Value<String> tipoTransaccion;
  final Value<String> estadoPago;
  final Value<int?> parentId;
  final Value<int?> tarjetaCreditoId;
  final Value<int?> transaccionId;
  final Value<DateTime> creadoEn;
  const EventosCompanion({
    this.id = const Value.absent(),
    this.titulo = const Value.absent(),
    this.fecha = const Value.absent(),
    this.hora = const Value.absent(),
    this.categoria = const Value.absent(),
    this.ubicacion = const Value.absent(),
    this.notas = const Value.absent(),
    this.frecuencia = const Value.absent(),
    this.costo = const Value.absent(),
    this.tipoTransaccion = const Value.absent(),
    this.estadoPago = const Value.absent(),
    this.parentId = const Value.absent(),
    this.tarjetaCreditoId = const Value.absent(),
    this.transaccionId = const Value.absent(),
    this.creadoEn = const Value.absent(),
  });
  EventosCompanion.insert({
    this.id = const Value.absent(),
    required String titulo,
    required String fecha,
    this.hora = const Value.absent(),
    this.categoria = const Value.absent(),
    this.ubicacion = const Value.absent(),
    this.notas = const Value.absent(),
    this.frecuencia = const Value.absent(),
    this.costo = const Value.absent(),
    this.tipoTransaccion = const Value.absent(),
    this.estadoPago = const Value.absent(),
    this.parentId = const Value.absent(),
    this.tarjetaCreditoId = const Value.absent(),
    this.transaccionId = const Value.absent(),
    this.creadoEn = const Value.absent(),
  }) : titulo = Value(titulo),
       fecha = Value(fecha);
  static Insertable<Evento> custom({
    Expression<int>? id,
    Expression<String>? titulo,
    Expression<String>? fecha,
    Expression<String>? hora,
    Expression<String>? categoria,
    Expression<String>? ubicacion,
    Expression<String>? notas,
    Expression<String>? frecuencia,
    Expression<double>? costo,
    Expression<String>? tipoTransaccion,
    Expression<String>? estadoPago,
    Expression<int>? parentId,
    Expression<int>? tarjetaCreditoId,
    Expression<int>? transaccionId,
    Expression<DateTime>? creadoEn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (titulo != null) 'titulo': titulo,
      if (fecha != null) 'fecha': fecha,
      if (hora != null) 'hora': hora,
      if (categoria != null) 'categoria': categoria,
      if (ubicacion != null) 'ubicacion': ubicacion,
      if (notas != null) 'notas': notas,
      if (frecuencia != null) 'frecuencia': frecuencia,
      if (costo != null) 'costo': costo,
      if (tipoTransaccion != null) 'tipo_transaccion': tipoTransaccion,
      if (estadoPago != null) 'estado_pago': estadoPago,
      if (parentId != null) 'parent_id': parentId,
      if (tarjetaCreditoId != null) 'tarjeta_credito_id': tarjetaCreditoId,
      if (transaccionId != null) 'transaccion_id': transaccionId,
      if (creadoEn != null) 'creado_en': creadoEn,
    });
  }

  EventosCompanion copyWith({
    Value<int>? id,
    Value<String>? titulo,
    Value<String>? fecha,
    Value<String?>? hora,
    Value<String>? categoria,
    Value<String>? ubicacion,
    Value<String>? notas,
    Value<String>? frecuencia,
    Value<double>? costo,
    Value<String>? tipoTransaccion,
    Value<String>? estadoPago,
    Value<int?>? parentId,
    Value<int?>? tarjetaCreditoId,
    Value<int?>? transaccionId,
    Value<DateTime>? creadoEn,
  }) {
    return EventosCompanion(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      categoria: categoria ?? this.categoria,
      ubicacion: ubicacion ?? this.ubicacion,
      notas: notas ?? this.notas,
      frecuencia: frecuencia ?? this.frecuencia,
      costo: costo ?? this.costo,
      tipoTransaccion: tipoTransaccion ?? this.tipoTransaccion,
      estadoPago: estadoPago ?? this.estadoPago,
      parentId: parentId ?? this.parentId,
      tarjetaCreditoId: tarjetaCreditoId ?? this.tarjetaCreditoId,
      transaccionId: transaccionId ?? this.transaccionId,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (hora.present) {
      map['hora'] = Variable<String>(hora.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (ubicacion.present) {
      map['ubicacion'] = Variable<String>(ubicacion.value);
    }
    if (notas.present) {
      map['notas'] = Variable<String>(notas.value);
    }
    if (frecuencia.present) {
      map['frecuencia'] = Variable<String>(frecuencia.value);
    }
    if (costo.present) {
      map['costo'] = Variable<double>(costo.value);
    }
    if (tipoTransaccion.present) {
      map['tipo_transaccion'] = Variable<String>(tipoTransaccion.value);
    }
    if (estadoPago.present) {
      map['estado_pago'] = Variable<String>(estadoPago.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (tarjetaCreditoId.present) {
      map['tarjeta_credito_id'] = Variable<int>(tarjetaCreditoId.value);
    }
    if (transaccionId.present) {
      map['transaccion_id'] = Variable<int>(transaccionId.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventosCompanion(')
          ..write('id: $id, ')
          ..write('titulo: $titulo, ')
          ..write('fecha: $fecha, ')
          ..write('hora: $hora, ')
          ..write('categoria: $categoria, ')
          ..write('ubicacion: $ubicacion, ')
          ..write('notas: $notas, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('costo: $costo, ')
          ..write('tipoTransaccion: $tipoTransaccion, ')
          ..write('estadoPago: $estadoPago, ')
          ..write('parentId: $parentId, ')
          ..write('tarjetaCreditoId: $tarjetaCreditoId, ')
          ..write('transaccionId: $transaccionId, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }
}

class $CumplesTable extends Cumples with TableInfo<$CumplesTable, Cumple> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CumplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anioNacimientoMeta = const VerificationMeta(
    'anioNacimiento',
  );
  @override
  late final GeneratedColumn<int> anioNacimiento = GeneratedColumn<int>(
    'anio_nacimiento',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _telefonoMeta = const VerificationMeta(
    'telefono',
  );
  @override
  late final GeneratedColumn<String> telefono = GeneratedColumn<String>(
    'telefono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mensajeMeta = const VerificationMeta(
    'mensaje',
  );
  @override
  late final GeneratedColumn<String> mensaje = GeneratedColumn<String>(
    'mensaje',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    fecha,
    anioNacimiento,
    telefono,
    mensaje,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cumples';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cumple> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('anio_nacimiento')) {
      context.handle(
        _anioNacimientoMeta,
        anioNacimiento.isAcceptableOrUnknown(
          data['anio_nacimiento']!,
          _anioNacimientoMeta,
        ),
      );
    }
    if (data.containsKey('telefono')) {
      context.handle(
        _telefonoMeta,
        telefono.isAcceptableOrUnknown(data['telefono']!, _telefonoMeta),
      );
    }
    if (data.containsKey('mensaje')) {
      context.handle(
        _mensajeMeta,
        mensaje.isAcceptableOrUnknown(data['mensaje']!, _mensajeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cumple map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cumple(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      anioNacimiento: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anio_nacimiento'],
      ),
      telefono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telefono'],
      )!,
      mensaje: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mensaje'],
      )!,
    );
  }

  @override
  $CumplesTable createAlias(String alias) {
    return $CumplesTable(attachedDatabase, alias);
  }
}

class Cumple extends DataClass implements Insertable<Cumple> {
  final int id;
  final String nombre;

  /// Fecha de referencia; solo importan mes y día (se repite cada año).
  final String fecha;
  final int? anioNacimiento;
  final String telefono;
  final String mensaje;
  const Cumple({
    required this.id,
    required this.nombre,
    required this.fecha,
    this.anioNacimiento,
    required this.telefono,
    required this.mensaje,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['fecha'] = Variable<String>(fecha);
    if (!nullToAbsent || anioNacimiento != null) {
      map['anio_nacimiento'] = Variable<int>(anioNacimiento);
    }
    map['telefono'] = Variable<String>(telefono);
    map['mensaje'] = Variable<String>(mensaje);
    return map;
  }

  CumplesCompanion toCompanion(bool nullToAbsent) {
    return CumplesCompanion(
      id: Value(id),
      nombre: Value(nombre),
      fecha: Value(fecha),
      anioNacimiento: anioNacimiento == null && nullToAbsent
          ? const Value.absent()
          : Value(anioNacimiento),
      telefono: Value(telefono),
      mensaje: Value(mensaje),
    );
  }

  factory Cumple.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cumple(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      fecha: serializer.fromJson<String>(json['fecha']),
      anioNacimiento: serializer.fromJson<int?>(json['anioNacimiento']),
      telefono: serializer.fromJson<String>(json['telefono']),
      mensaje: serializer.fromJson<String>(json['mensaje']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'fecha': serializer.toJson<String>(fecha),
      'anioNacimiento': serializer.toJson<int?>(anioNacimiento),
      'telefono': serializer.toJson<String>(telefono),
      'mensaje': serializer.toJson<String>(mensaje),
    };
  }

  Cumple copyWith({
    int? id,
    String? nombre,
    String? fecha,
    Value<int?> anioNacimiento = const Value.absent(),
    String? telefono,
    String? mensaje,
  }) => Cumple(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    fecha: fecha ?? this.fecha,
    anioNacimiento: anioNacimiento.present
        ? anioNacimiento.value
        : this.anioNacimiento,
    telefono: telefono ?? this.telefono,
    mensaje: mensaje ?? this.mensaje,
  );
  Cumple copyWithCompanion(CumplesCompanion data) {
    return Cumple(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      anioNacimiento: data.anioNacimiento.present
          ? data.anioNacimiento.value
          : this.anioNacimiento,
      telefono: data.telefono.present ? data.telefono.value : this.telefono,
      mensaje: data.mensaje.present ? data.mensaje.value : this.mensaje,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cumple(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('fecha: $fecha, ')
          ..write('anioNacimiento: $anioNacimiento, ')
          ..write('telefono: $telefono, ')
          ..write('mensaje: $mensaje')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nombre, fecha, anioNacimiento, telefono, mensaje);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cumple &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.fecha == this.fecha &&
          other.anioNacimiento == this.anioNacimiento &&
          other.telefono == this.telefono &&
          other.mensaje == this.mensaje);
}

class CumplesCompanion extends UpdateCompanion<Cumple> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> fecha;
  final Value<int?> anioNacimiento;
  final Value<String> telefono;
  final Value<String> mensaje;
  const CumplesCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.fecha = const Value.absent(),
    this.anioNacimiento = const Value.absent(),
    this.telefono = const Value.absent(),
    this.mensaje = const Value.absent(),
  });
  CumplesCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    required String fecha,
    this.anioNacimiento = const Value.absent(),
    this.telefono = const Value.absent(),
    this.mensaje = const Value.absent(),
  }) : nombre = Value(nombre),
       fecha = Value(fecha);
  static Insertable<Cumple> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? fecha,
    Expression<int>? anioNacimiento,
    Expression<String>? telefono,
    Expression<String>? mensaje,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (fecha != null) 'fecha': fecha,
      if (anioNacimiento != null) 'anio_nacimiento': anioNacimiento,
      if (telefono != null) 'telefono': telefono,
      if (mensaje != null) 'mensaje': mensaje,
    });
  }

  CumplesCompanion copyWith({
    Value<int>? id,
    Value<String>? nombre,
    Value<String>? fecha,
    Value<int?>? anioNacimiento,
    Value<String>? telefono,
    Value<String>? mensaje,
  }) {
    return CumplesCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      fecha: fecha ?? this.fecha,
      anioNacimiento: anioNacimiento ?? this.anioNacimiento,
      telefono: telefono ?? this.telefono,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (anioNacimiento.present) {
      map['anio_nacimiento'] = Variable<int>(anioNacimiento.value);
    }
    if (telefono.present) {
      map['telefono'] = Variable<String>(telefono.value);
    }
    if (mensaje.present) {
      map['mensaje'] = Variable<String>(mensaje.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CumplesCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('fecha: $fecha, ')
          ..write('anioNacimiento: $anioNacimiento, ')
          ..write('telefono: $telefono, ')
          ..write('mensaje: $mensaje')
          ..write(')'))
        .toString();
  }
}

class $CiclosTable extends Ciclos with TableInfo<$CiclosTable, Ciclo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CiclosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fechaInicioMeta = const VerificationMeta(
    'fechaInicio',
  );
  @override
  late final GeneratedColumn<String> fechaInicio = GeneratedColumn<String>(
    'fecha_inicio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _observacionMeta = const VerificationMeta(
    'observacion',
  );
  @override
  late final GeneratedColumn<String> observacion = GeneratedColumn<String>(
    'observacion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _diasSangradoMeta = const VerificationMeta(
    'diasSangrado',
  );
  @override
  late final GeneratedColumn<int> diasSangrado = GeneratedColumn<int>(
    'dias_sangrado',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fechaInicio,
    observacion,
    diasSangrado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ciclos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ciclo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fecha_inicio')) {
      context.handle(
        _fechaInicioMeta,
        fechaInicio.isAcceptableOrUnknown(
          data['fecha_inicio']!,
          _fechaInicioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaInicioMeta);
    }
    if (data.containsKey('observacion')) {
      context.handle(
        _observacionMeta,
        observacion.isAcceptableOrUnknown(
          data['observacion']!,
          _observacionMeta,
        ),
      );
    }
    if (data.containsKey('dias_sangrado')) {
      context.handle(
        _diasSangradoMeta,
        diasSangrado.isAcceptableOrUnknown(
          data['dias_sangrado']!,
          _diasSangradoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ciclo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ciclo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fechaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_inicio'],
      )!,
      observacion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observacion'],
      )!,
      diasSangrado: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_sangrado'],
      ),
    );
  }

  @override
  $CiclosTable createAlias(String alias) {
    return $CiclosTable(attachedDatabase, alias);
  }
}

class Ciclo extends DataClass implements Insertable<Ciclo> {
  final int id;

  /// Día 1 del ciclo (primer día de sangrado).
  final String fechaInicio;
  final String observacion;

  /// Días de sangrado de ese ciclo; null = sin especificar (se usa el promedio).
  final int? diasSangrado;
  const Ciclo({
    required this.id,
    required this.fechaInicio,
    required this.observacion,
    this.diasSangrado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fecha_inicio'] = Variable<String>(fechaInicio);
    map['observacion'] = Variable<String>(observacion);
    if (!nullToAbsent || diasSangrado != null) {
      map['dias_sangrado'] = Variable<int>(diasSangrado);
    }
    return map;
  }

  CiclosCompanion toCompanion(bool nullToAbsent) {
    return CiclosCompanion(
      id: Value(id),
      fechaInicio: Value(fechaInicio),
      observacion: Value(observacion),
      diasSangrado: diasSangrado == null && nullToAbsent
          ? const Value.absent()
          : Value(diasSangrado),
    );
  }

  factory Ciclo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ciclo(
      id: serializer.fromJson<int>(json['id']),
      fechaInicio: serializer.fromJson<String>(json['fechaInicio']),
      observacion: serializer.fromJson<String>(json['observacion']),
      diasSangrado: serializer.fromJson<int?>(json['diasSangrado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fechaInicio': serializer.toJson<String>(fechaInicio),
      'observacion': serializer.toJson<String>(observacion),
      'diasSangrado': serializer.toJson<int?>(diasSangrado),
    };
  }

  Ciclo copyWith({
    int? id,
    String? fechaInicio,
    String? observacion,
    Value<int?> diasSangrado = const Value.absent(),
  }) => Ciclo(
    id: id ?? this.id,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    observacion: observacion ?? this.observacion,
    diasSangrado: diasSangrado.present ? diasSangrado.value : this.diasSangrado,
  );
  Ciclo copyWithCompanion(CiclosCompanion data) {
    return Ciclo(
      id: data.id.present ? data.id.value : this.id,
      fechaInicio: data.fechaInicio.present
          ? data.fechaInicio.value
          : this.fechaInicio,
      observacion: data.observacion.present
          ? data.observacion.value
          : this.observacion,
      diasSangrado: data.diasSangrado.present
          ? data.diasSangrado.value
          : this.diasSangrado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ciclo(')
          ..write('id: $id, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('observacion: $observacion, ')
          ..write('diasSangrado: $diasSangrado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fechaInicio, observacion, diasSangrado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ciclo &&
          other.id == this.id &&
          other.fechaInicio == this.fechaInicio &&
          other.observacion == this.observacion &&
          other.diasSangrado == this.diasSangrado);
}

class CiclosCompanion extends UpdateCompanion<Ciclo> {
  final Value<int> id;
  final Value<String> fechaInicio;
  final Value<String> observacion;
  final Value<int?> diasSangrado;
  const CiclosCompanion({
    this.id = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.observacion = const Value.absent(),
    this.diasSangrado = const Value.absent(),
  });
  CiclosCompanion.insert({
    this.id = const Value.absent(),
    required String fechaInicio,
    this.observacion = const Value.absent(),
    this.diasSangrado = const Value.absent(),
  }) : fechaInicio = Value(fechaInicio);
  static Insertable<Ciclo> custom({
    Expression<int>? id,
    Expression<String>? fechaInicio,
    Expression<String>? observacion,
    Expression<int>? diasSangrado,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (observacion != null) 'observacion': observacion,
      if (diasSangrado != null) 'dias_sangrado': diasSangrado,
    });
  }

  CiclosCompanion copyWith({
    Value<int>? id,
    Value<String>? fechaInicio,
    Value<String>? observacion,
    Value<int?>? diasSangrado,
  }) {
    return CiclosCompanion(
      id: id ?? this.id,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      observacion: observacion ?? this.observacion,
      diasSangrado: diasSangrado ?? this.diasSangrado,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fechaInicio.present) {
      map['fecha_inicio'] = Variable<String>(fechaInicio.value);
    }
    if (observacion.present) {
      map['observacion'] = Variable<String>(observacion.value);
    }
    if (diasSangrado.present) {
      map['dias_sangrado'] = Variable<int>(diasSangrado.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CiclosCompanion(')
          ..write('id: $id, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('observacion: $observacion, ')
          ..write('diasSangrado: $diasSangrado')
          ..write(')'))
        .toString();
  }
}

class $RegistrosDiaTable extends RegistrosDia
    with TableInfo<$RegistrosDiaTable, RegistroDia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RegistrosDiaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _flujoMeta = const VerificationMeta('flujo');
  @override
  late final GeneratedColumn<int> flujo = GeneratedColumn<int>(
    'flujo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _animoMeta = const VerificationMeta('animo');
  @override
  late final GeneratedColumn<String> animo = GeneratedColumn<String>(
    'animo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sintomasMeta = const VerificationMeta(
    'sintomas',
  );
  @override
  late final GeneratedColumn<String> sintomas = GeneratedColumn<String>(
    'sintomas',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notaMeta = const VerificationMeta('nota');
  @override
  late final GeneratedColumn<String> nota = GeneratedColumn<String>(
    'nota',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fecha,
    flujo,
    animo,
    sintomas,
    nota,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'registros_dia';
  @override
  VerificationContext validateIntegrity(
    Insertable<RegistroDia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('flujo')) {
      context.handle(
        _flujoMeta,
        flujo.isAcceptableOrUnknown(data['flujo']!, _flujoMeta),
      );
    }
    if (data.containsKey('animo')) {
      context.handle(
        _animoMeta,
        animo.isAcceptableOrUnknown(data['animo']!, _animoMeta),
      );
    }
    if (data.containsKey('sintomas')) {
      context.handle(
        _sintomasMeta,
        sintomas.isAcceptableOrUnknown(data['sintomas']!, _sintomasMeta),
      );
    }
    if (data.containsKey('nota')) {
      context.handle(
        _notaMeta,
        nota.isAcceptableOrUnknown(data['nota']!, _notaMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RegistroDia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistroDia(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      flujo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}flujo'],
      )!,
      animo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}animo'],
      ),
      sintomas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sintomas'],
      )!,
      nota: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nota'],
      )!,
    );
  }

  @override
  $RegistrosDiaTable createAlias(String alias) {
    return $RegistrosDiaTable(attachedDatabase, alias);
  }
}

class RegistroDia extends DataClass implements Insertable<RegistroDia> {
  final int id;
  final String fecha;

  /// 0 ninguno · 1 ligero · 2 medio · 3 abundante
  final int flujo;
  final String? animo;

  /// Claves de síntomas separadas por coma.
  final String sintomas;
  final String nota;
  const RegistroDia({
    required this.id,
    required this.fecha,
    required this.flujo,
    this.animo,
    required this.sintomas,
    required this.nota,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fecha'] = Variable<String>(fecha);
    map['flujo'] = Variable<int>(flujo);
    if (!nullToAbsent || animo != null) {
      map['animo'] = Variable<String>(animo);
    }
    map['sintomas'] = Variable<String>(sintomas);
    map['nota'] = Variable<String>(nota);
    return map;
  }

  RegistrosDiaCompanion toCompanion(bool nullToAbsent) {
    return RegistrosDiaCompanion(
      id: Value(id),
      fecha: Value(fecha),
      flujo: Value(flujo),
      animo: animo == null && nullToAbsent
          ? const Value.absent()
          : Value(animo),
      sintomas: Value(sintomas),
      nota: Value(nota),
    );
  }

  factory RegistroDia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RegistroDia(
      id: serializer.fromJson<int>(json['id']),
      fecha: serializer.fromJson<String>(json['fecha']),
      flujo: serializer.fromJson<int>(json['flujo']),
      animo: serializer.fromJson<String?>(json['animo']),
      sintomas: serializer.fromJson<String>(json['sintomas']),
      nota: serializer.fromJson<String>(json['nota']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fecha': serializer.toJson<String>(fecha),
      'flujo': serializer.toJson<int>(flujo),
      'animo': serializer.toJson<String?>(animo),
      'sintomas': serializer.toJson<String>(sintomas),
      'nota': serializer.toJson<String>(nota),
    };
  }

  RegistroDia copyWith({
    int? id,
    String? fecha,
    int? flujo,
    Value<String?> animo = const Value.absent(),
    String? sintomas,
    String? nota,
  }) => RegistroDia(
    id: id ?? this.id,
    fecha: fecha ?? this.fecha,
    flujo: flujo ?? this.flujo,
    animo: animo.present ? animo.value : this.animo,
    sintomas: sintomas ?? this.sintomas,
    nota: nota ?? this.nota,
  );
  RegistroDia copyWithCompanion(RegistrosDiaCompanion data) {
    return RegistroDia(
      id: data.id.present ? data.id.value : this.id,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      flujo: data.flujo.present ? data.flujo.value : this.flujo,
      animo: data.animo.present ? data.animo.value : this.animo,
      sintomas: data.sintomas.present ? data.sintomas.value : this.sintomas,
      nota: data.nota.present ? data.nota.value : this.nota,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RegistroDia(')
          ..write('id: $id, ')
          ..write('fecha: $fecha, ')
          ..write('flujo: $flujo, ')
          ..write('animo: $animo, ')
          ..write('sintomas: $sintomas, ')
          ..write('nota: $nota')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fecha, flujo, animo, sintomas, nota);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistroDia &&
          other.id == this.id &&
          other.fecha == this.fecha &&
          other.flujo == this.flujo &&
          other.animo == this.animo &&
          other.sintomas == this.sintomas &&
          other.nota == this.nota);
}

class RegistrosDiaCompanion extends UpdateCompanion<RegistroDia> {
  final Value<int> id;
  final Value<String> fecha;
  final Value<int> flujo;
  final Value<String?> animo;
  final Value<String> sintomas;
  final Value<String> nota;
  const RegistrosDiaCompanion({
    this.id = const Value.absent(),
    this.fecha = const Value.absent(),
    this.flujo = const Value.absent(),
    this.animo = const Value.absent(),
    this.sintomas = const Value.absent(),
    this.nota = const Value.absent(),
  });
  RegistrosDiaCompanion.insert({
    this.id = const Value.absent(),
    required String fecha,
    this.flujo = const Value.absent(),
    this.animo = const Value.absent(),
    this.sintomas = const Value.absent(),
    this.nota = const Value.absent(),
  }) : fecha = Value(fecha);
  static Insertable<RegistroDia> custom({
    Expression<int>? id,
    Expression<String>? fecha,
    Expression<int>? flujo,
    Expression<String>? animo,
    Expression<String>? sintomas,
    Expression<String>? nota,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fecha != null) 'fecha': fecha,
      if (flujo != null) 'flujo': flujo,
      if (animo != null) 'animo': animo,
      if (sintomas != null) 'sintomas': sintomas,
      if (nota != null) 'nota': nota,
    });
  }

  RegistrosDiaCompanion copyWith({
    Value<int>? id,
    Value<String>? fecha,
    Value<int>? flujo,
    Value<String?>? animo,
    Value<String>? sintomas,
    Value<String>? nota,
  }) {
    return RegistrosDiaCompanion(
      id: id ?? this.id,
      fecha: fecha ?? this.fecha,
      flujo: flujo ?? this.flujo,
      animo: animo ?? this.animo,
      sintomas: sintomas ?? this.sintomas,
      nota: nota ?? this.nota,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (flujo.present) {
      map['flujo'] = Variable<int>(flujo.value);
    }
    if (animo.present) {
      map['animo'] = Variable<String>(animo.value);
    }
    if (sintomas.present) {
      map['sintomas'] = Variable<String>(sintomas.value);
    }
    if (nota.present) {
      map['nota'] = Variable<String>(nota.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RegistrosDiaCompanion(')
          ..write('id: $id, ')
          ..write('fecha: $fecha, ')
          ..write('flujo: $flujo, ')
          ..write('animo: $animo, ')
          ..write('sintomas: $sintomas, ')
          ..write('nota: $nota')
          ..write(')'))
        .toString();
  }
}

class $CuentasTable extends Cuentas with TableInfo<$CuentasTable, Cuenta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuentasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saldoMeta = const VerificationMeta('saldo');
  @override
  late final GeneratedColumn<double> saldo = GeneratedColumn<double>(
    'saldo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _limiteMeta = const VerificationMeta('limite');
  @override
  late final GeneratedColumn<double> limite = GeneratedColumn<double>(
    'limite',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _interesTasaMeta = const VerificationMeta(
    'interesTasa',
  );
  @override
  late final GeneratedColumn<double> interesTasa = GeneratedColumn<double>(
    'interes_tasa',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fechaInicioMeta = const VerificationMeta(
    'fechaInicio',
  );
  @override
  late final GeneratedColumn<String> fechaInicio = GeneratedColumn<String>(
    'fecha_inicio',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plazoDiasMeta = const VerificationMeta(
    'plazoDias',
  );
  @override
  late final GeneratedColumn<int> plazoDias = GeneratedColumn<int>(
    'plazo_dias',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _diaCorteMeta = const VerificationMeta(
    'diaCorte',
  );
  @override
  late final GeneratedColumn<int> diaCorte = GeneratedColumn<int>(
    'dia_corte',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    tipo,
    saldo,
    limite,
    interesTasa,
    fechaInicio,
    plazoDias,
    diaCorte,
    creadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cuentas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Cuenta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('saldo')) {
      context.handle(
        _saldoMeta,
        saldo.isAcceptableOrUnknown(data['saldo']!, _saldoMeta),
      );
    }
    if (data.containsKey('limite')) {
      context.handle(
        _limiteMeta,
        limite.isAcceptableOrUnknown(data['limite']!, _limiteMeta),
      );
    }
    if (data.containsKey('interes_tasa')) {
      context.handle(
        _interesTasaMeta,
        interesTasa.isAcceptableOrUnknown(
          data['interes_tasa']!,
          _interesTasaMeta,
        ),
      );
    }
    if (data.containsKey('fecha_inicio')) {
      context.handle(
        _fechaInicioMeta,
        fechaInicio.isAcceptableOrUnknown(
          data['fecha_inicio']!,
          _fechaInicioMeta,
        ),
      );
    }
    if (data.containsKey('plazo_dias')) {
      context.handle(
        _plazoDiasMeta,
        plazoDias.isAcceptableOrUnknown(data['plazo_dias']!, _plazoDiasMeta),
      );
    }
    if (data.containsKey('dia_corte')) {
      context.handle(
        _diaCorteMeta,
        diaCorte.isAcceptableOrUnknown(data['dia_corte']!, _diaCorteMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Cuenta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Cuenta(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      saldo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}saldo'],
      )!,
      limite: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limite'],
      )!,
      interesTasa: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interes_tasa'],
      )!,
      fechaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_inicio'],
      ),
      plazoDias: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plazo_dias'],
      )!,
      diaCorte: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_corte'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $CuentasTable createAlias(String alias) {
    return $CuentasTable(attachedDatabase, alias);
  }
}

class Cuenta extends DataClass implements Insertable<Cuenta> {
  final int id;
  final String nombre;

  /// ahorros · corriente · tarjeta_credito · cdt · efectivo · otro
  final String tipo;

  /// En tarjetas de crédito el saldo es la DEUDA.
  final double saldo;
  final double limite;

  /// Tasa efectiva anual (%) de CDT / cajitas.
  final double interesTasa;
  final String? fechaInicio;
  final int plazoDias;

  /// Día de corte de la tarjeta de crédito (1..31).
  final int? diaCorte;
  final DateTime creadoEn;
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldo,
    required this.limite,
    required this.interesTasa,
    this.fechaInicio,
    required this.plazoDias,
    this.diaCorte,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['tipo'] = Variable<String>(tipo);
    map['saldo'] = Variable<double>(saldo);
    map['limite'] = Variable<double>(limite);
    map['interes_tasa'] = Variable<double>(interesTasa);
    if (!nullToAbsent || fechaInicio != null) {
      map['fecha_inicio'] = Variable<String>(fechaInicio);
    }
    map['plazo_dias'] = Variable<int>(plazoDias);
    if (!nullToAbsent || diaCorte != null) {
      map['dia_corte'] = Variable<int>(diaCorte);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  CuentasCompanion toCompanion(bool nullToAbsent) {
    return CuentasCompanion(
      id: Value(id),
      nombre: Value(nombre),
      tipo: Value(tipo),
      saldo: Value(saldo),
      limite: Value(limite),
      interesTasa: Value(interesTasa),
      fechaInicio: fechaInicio == null && nullToAbsent
          ? const Value.absent()
          : Value(fechaInicio),
      plazoDias: Value(plazoDias),
      diaCorte: diaCorte == null && nullToAbsent
          ? const Value.absent()
          : Value(diaCorte),
      creadoEn: Value(creadoEn),
    );
  }

  factory Cuenta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Cuenta(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      tipo: serializer.fromJson<String>(json['tipo']),
      saldo: serializer.fromJson<double>(json['saldo']),
      limite: serializer.fromJson<double>(json['limite']),
      interesTasa: serializer.fromJson<double>(json['interesTasa']),
      fechaInicio: serializer.fromJson<String?>(json['fechaInicio']),
      plazoDias: serializer.fromJson<int>(json['plazoDias']),
      diaCorte: serializer.fromJson<int?>(json['diaCorte']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'tipo': serializer.toJson<String>(tipo),
      'saldo': serializer.toJson<double>(saldo),
      'limite': serializer.toJson<double>(limite),
      'interesTasa': serializer.toJson<double>(interesTasa),
      'fechaInicio': serializer.toJson<String?>(fechaInicio),
      'plazoDias': serializer.toJson<int>(plazoDias),
      'diaCorte': serializer.toJson<int?>(diaCorte),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  Cuenta copyWith({
    int? id,
    String? nombre,
    String? tipo,
    double? saldo,
    double? limite,
    double? interesTasa,
    Value<String?> fechaInicio = const Value.absent(),
    int? plazoDias,
    Value<int?> diaCorte = const Value.absent(),
    DateTime? creadoEn,
  }) => Cuenta(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    saldo: saldo ?? this.saldo,
    limite: limite ?? this.limite,
    interesTasa: interesTasa ?? this.interesTasa,
    fechaInicio: fechaInicio.present ? fechaInicio.value : this.fechaInicio,
    plazoDias: plazoDias ?? this.plazoDias,
    diaCorte: diaCorte.present ? diaCorte.value : this.diaCorte,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  Cuenta copyWithCompanion(CuentasCompanion data) {
    return Cuenta(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      saldo: data.saldo.present ? data.saldo.value : this.saldo,
      limite: data.limite.present ? data.limite.value : this.limite,
      interesTasa: data.interesTasa.present
          ? data.interesTasa.value
          : this.interesTasa,
      fechaInicio: data.fechaInicio.present
          ? data.fechaInicio.value
          : this.fechaInicio,
      plazoDias: data.plazoDias.present ? data.plazoDias.value : this.plazoDias,
      diaCorte: data.diaCorte.present ? data.diaCorte.value : this.diaCorte,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Cuenta(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('saldo: $saldo, ')
          ..write('limite: $limite, ')
          ..write('interesTasa: $interesTasa, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('plazoDias: $plazoDias, ')
          ..write('diaCorte: $diaCorte, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nombre,
    tipo,
    saldo,
    limite,
    interesTasa,
    fechaInicio,
    plazoDias,
    diaCorte,
    creadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cuenta &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.tipo == this.tipo &&
          other.saldo == this.saldo &&
          other.limite == this.limite &&
          other.interesTasa == this.interesTasa &&
          other.fechaInicio == this.fechaInicio &&
          other.plazoDias == this.plazoDias &&
          other.diaCorte == this.diaCorte &&
          other.creadoEn == this.creadoEn);
}

class CuentasCompanion extends UpdateCompanion<Cuenta> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> tipo;
  final Value<double> saldo;
  final Value<double> limite;
  final Value<double> interesTasa;
  final Value<String?> fechaInicio;
  final Value<int> plazoDias;
  final Value<int?> diaCorte;
  final Value<DateTime> creadoEn;
  const CuentasCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.tipo = const Value.absent(),
    this.saldo = const Value.absent(),
    this.limite = const Value.absent(),
    this.interesTasa = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.plazoDias = const Value.absent(),
    this.diaCorte = const Value.absent(),
    this.creadoEn = const Value.absent(),
  });
  CuentasCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    required String tipo,
    this.saldo = const Value.absent(),
    this.limite = const Value.absent(),
    this.interesTasa = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.plazoDias = const Value.absent(),
    this.diaCorte = const Value.absent(),
    this.creadoEn = const Value.absent(),
  }) : nombre = Value(nombre),
       tipo = Value(tipo);
  static Insertable<Cuenta> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? tipo,
    Expression<double>? saldo,
    Expression<double>? limite,
    Expression<double>? interesTasa,
    Expression<String>? fechaInicio,
    Expression<int>? plazoDias,
    Expression<int>? diaCorte,
    Expression<DateTime>? creadoEn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (tipo != null) 'tipo': tipo,
      if (saldo != null) 'saldo': saldo,
      if (limite != null) 'limite': limite,
      if (interesTasa != null) 'interes_tasa': interesTasa,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (plazoDias != null) 'plazo_dias': plazoDias,
      if (diaCorte != null) 'dia_corte': diaCorte,
      if (creadoEn != null) 'creado_en': creadoEn,
    });
  }

  CuentasCompanion copyWith({
    Value<int>? id,
    Value<String>? nombre,
    Value<String>? tipo,
    Value<double>? saldo,
    Value<double>? limite,
    Value<double>? interesTasa,
    Value<String?>? fechaInicio,
    Value<int>? plazoDias,
    Value<int?>? diaCorte,
    Value<DateTime>? creadoEn,
  }) {
    return CuentasCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      saldo: saldo ?? this.saldo,
      limite: limite ?? this.limite,
      interesTasa: interesTasa ?? this.interesTasa,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      plazoDias: plazoDias ?? this.plazoDias,
      diaCorte: diaCorte ?? this.diaCorte,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (saldo.present) {
      map['saldo'] = Variable<double>(saldo.value);
    }
    if (limite.present) {
      map['limite'] = Variable<double>(limite.value);
    }
    if (interesTasa.present) {
      map['interes_tasa'] = Variable<double>(interesTasa.value);
    }
    if (fechaInicio.present) {
      map['fecha_inicio'] = Variable<String>(fechaInicio.value);
    }
    if (plazoDias.present) {
      map['plazo_dias'] = Variable<int>(plazoDias.value);
    }
    if (diaCorte.present) {
      map['dia_corte'] = Variable<int>(diaCorte.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuentasCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('saldo: $saldo, ')
          ..write('limite: $limite, ')
          ..write('interesTasa: $interesTasa, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('plazoDias: $plazoDias, ')
          ..write('diaCorte: $diaCorte, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }
}

class $TransaccionesTable extends Transacciones
    with TableInfo<$TransaccionesTable, Transaccion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransaccionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cuentaIdMeta = const VerificationMeta(
    'cuentaId',
  );
  @override
  late final GeneratedColumn<int> cuentaId = GeneratedColumn<int>(
    'cuenta_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoriaMeta = const VerificationMeta(
    'categoria',
  );
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('otros'),
  );
  static const VerificationMeta _cuotasMeta = const VerificationMeta('cuotas');
  @override
  late final GeneratedColumn<int> cuotas = GeneratedColumn<int>(
    'cuotas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _ingresoPlanificadoIdMeta =
      const VerificationMeta('ingresoPlanificadoId');
  @override
  late final GeneratedColumn<int> ingresoPlanificadoId = GeneratedColumn<int>(
    'ingreso_planificado_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaIdMeta = const VerificationMeta('metaId');
  @override
  late final GeneratedColumn<int> metaId = GeneratedColumn<int>(
    'meta_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cuentaId,
    tipo,
    monto,
    descripcion,
    fecha,
    categoria,
    cuotas,
    ingresoPlanificadoId,
    metaId,
    creadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transacciones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaccion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cuenta_id')) {
      context.handle(
        _cuentaIdMeta,
        cuentaId.isAcceptableOrUnknown(data['cuenta_id']!, _cuentaIdMeta),
      );
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descripcionMeta);
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    if (data.containsKey('categoria')) {
      context.handle(
        _categoriaMeta,
        categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta),
      );
    }
    if (data.containsKey('cuotas')) {
      context.handle(
        _cuotasMeta,
        cuotas.isAcceptableOrUnknown(data['cuotas']!, _cuotasMeta),
      );
    }
    if (data.containsKey('ingreso_planificado_id')) {
      context.handle(
        _ingresoPlanificadoIdMeta,
        ingresoPlanificadoId.isAcceptableOrUnknown(
          data['ingreso_planificado_id']!,
          _ingresoPlanificadoIdMeta,
        ),
      );
    }
    if (data.containsKey('meta_id')) {
      context.handle(
        _metaIdMeta,
        metaId.isAcceptableOrUnknown(data['meta_id']!, _metaIdMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaccion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaccion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cuentaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuenta_id'],
      ),
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
      categoria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria'],
      )!,
      cuotas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuotas'],
      )!,
      ingresoPlanificadoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingreso_planificado_id'],
      ),
      metaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meta_id'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $TransaccionesTable createAlias(String alias) {
    return $TransaccionesTable(attachedDatabase, alias);
  }
}

class Transaccion extends DataClass implements Insertable<Transaccion> {
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

  /// Aporte a una meta de ahorro (al borrarlo se descuenta de la meta).
  final int? metaId;
  final DateTime creadoEn;
  const Transaccion({
    required this.id,
    this.cuentaId,
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    required this.categoria,
    required this.cuotas,
    this.ingresoPlanificadoId,
    this.metaId,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || cuentaId != null) {
      map['cuenta_id'] = Variable<int>(cuentaId);
    }
    map['tipo'] = Variable<String>(tipo);
    map['monto'] = Variable<double>(monto);
    map['descripcion'] = Variable<String>(descripcion);
    map['fecha'] = Variable<String>(fecha);
    map['categoria'] = Variable<String>(categoria);
    map['cuotas'] = Variable<int>(cuotas);
    if (!nullToAbsent || ingresoPlanificadoId != null) {
      map['ingreso_planificado_id'] = Variable<int>(ingresoPlanificadoId);
    }
    if (!nullToAbsent || metaId != null) {
      map['meta_id'] = Variable<int>(metaId);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  TransaccionesCompanion toCompanion(bool nullToAbsent) {
    return TransaccionesCompanion(
      id: Value(id),
      cuentaId: cuentaId == null && nullToAbsent
          ? const Value.absent()
          : Value(cuentaId),
      tipo: Value(tipo),
      monto: Value(monto),
      descripcion: Value(descripcion),
      fecha: Value(fecha),
      categoria: Value(categoria),
      cuotas: Value(cuotas),
      ingresoPlanificadoId: ingresoPlanificadoId == null && nullToAbsent
          ? const Value.absent()
          : Value(ingresoPlanificadoId),
      metaId: metaId == null && nullToAbsent
          ? const Value.absent()
          : Value(metaId),
      creadoEn: Value(creadoEn),
    );
  }

  factory Transaccion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaccion(
      id: serializer.fromJson<int>(json['id']),
      cuentaId: serializer.fromJson<int?>(json['cuentaId']),
      tipo: serializer.fromJson<String>(json['tipo']),
      monto: serializer.fromJson<double>(json['monto']),
      descripcion: serializer.fromJson<String>(json['descripcion']),
      fecha: serializer.fromJson<String>(json['fecha']),
      categoria: serializer.fromJson<String>(json['categoria']),
      cuotas: serializer.fromJson<int>(json['cuotas']),
      ingresoPlanificadoId: serializer.fromJson<int?>(
        json['ingresoPlanificadoId'],
      ),
      metaId: serializer.fromJson<int?>(json['metaId']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cuentaId': serializer.toJson<int?>(cuentaId),
      'tipo': serializer.toJson<String>(tipo),
      'monto': serializer.toJson<double>(monto),
      'descripcion': serializer.toJson<String>(descripcion),
      'fecha': serializer.toJson<String>(fecha),
      'categoria': serializer.toJson<String>(categoria),
      'cuotas': serializer.toJson<int>(cuotas),
      'ingresoPlanificadoId': serializer.toJson<int?>(ingresoPlanificadoId),
      'metaId': serializer.toJson<int?>(metaId),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  Transaccion copyWith({
    int? id,
    Value<int?> cuentaId = const Value.absent(),
    String? tipo,
    double? monto,
    String? descripcion,
    String? fecha,
    String? categoria,
    int? cuotas,
    Value<int?> ingresoPlanificadoId = const Value.absent(),
    Value<int?> metaId = const Value.absent(),
    DateTime? creadoEn,
  }) => Transaccion(
    id: id ?? this.id,
    cuentaId: cuentaId.present ? cuentaId.value : this.cuentaId,
    tipo: tipo ?? this.tipo,
    monto: monto ?? this.monto,
    descripcion: descripcion ?? this.descripcion,
    fecha: fecha ?? this.fecha,
    categoria: categoria ?? this.categoria,
    cuotas: cuotas ?? this.cuotas,
    ingresoPlanificadoId: ingresoPlanificadoId.present
        ? ingresoPlanificadoId.value
        : this.ingresoPlanificadoId,
    metaId: metaId.present ? metaId.value : this.metaId,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  Transaccion copyWithCompanion(TransaccionesCompanion data) {
    return Transaccion(
      id: data.id.present ? data.id.value : this.id,
      cuentaId: data.cuentaId.present ? data.cuentaId.value : this.cuentaId,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      monto: data.monto.present ? data.monto.value : this.monto,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      cuotas: data.cuotas.present ? data.cuotas.value : this.cuotas,
      ingresoPlanificadoId: data.ingresoPlanificadoId.present
          ? data.ingresoPlanificadoId.value
          : this.ingresoPlanificadoId,
      metaId: data.metaId.present ? data.metaId.value : this.metaId,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaccion(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('tipo: $tipo, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha, ')
          ..write('categoria: $categoria, ')
          ..write('cuotas: $cuotas, ')
          ..write('ingresoPlanificadoId: $ingresoPlanificadoId, ')
          ..write('metaId: $metaId, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cuentaId,
    tipo,
    monto,
    descripcion,
    fecha,
    categoria,
    cuotas,
    ingresoPlanificadoId,
    metaId,
    creadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaccion &&
          other.id == this.id &&
          other.cuentaId == this.cuentaId &&
          other.tipo == this.tipo &&
          other.monto == this.monto &&
          other.descripcion == this.descripcion &&
          other.fecha == this.fecha &&
          other.categoria == this.categoria &&
          other.cuotas == this.cuotas &&
          other.ingresoPlanificadoId == this.ingresoPlanificadoId &&
          other.metaId == this.metaId &&
          other.creadoEn == this.creadoEn);
}

class TransaccionesCompanion extends UpdateCompanion<Transaccion> {
  final Value<int> id;
  final Value<int?> cuentaId;
  final Value<String> tipo;
  final Value<double> monto;
  final Value<String> descripcion;
  final Value<String> fecha;
  final Value<String> categoria;
  final Value<int> cuotas;
  final Value<int?> ingresoPlanificadoId;
  final Value<int?> metaId;
  final Value<DateTime> creadoEn;
  const TransaccionesCompanion({
    this.id = const Value.absent(),
    this.cuentaId = const Value.absent(),
    this.tipo = const Value.absent(),
    this.monto = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.fecha = const Value.absent(),
    this.categoria = const Value.absent(),
    this.cuotas = const Value.absent(),
    this.ingresoPlanificadoId = const Value.absent(),
    this.metaId = const Value.absent(),
    this.creadoEn = const Value.absent(),
  });
  TransaccionesCompanion.insert({
    this.id = const Value.absent(),
    this.cuentaId = const Value.absent(),
    required String tipo,
    required double monto,
    required String descripcion,
    required String fecha,
    this.categoria = const Value.absent(),
    this.cuotas = const Value.absent(),
    this.ingresoPlanificadoId = const Value.absent(),
    this.metaId = const Value.absent(),
    this.creadoEn = const Value.absent(),
  }) : tipo = Value(tipo),
       monto = Value(monto),
       descripcion = Value(descripcion),
       fecha = Value(fecha);
  static Insertable<Transaccion> custom({
    Expression<int>? id,
    Expression<int>? cuentaId,
    Expression<String>? tipo,
    Expression<double>? monto,
    Expression<String>? descripcion,
    Expression<String>? fecha,
    Expression<String>? categoria,
    Expression<int>? cuotas,
    Expression<int>? ingresoPlanificadoId,
    Expression<int>? metaId,
    Expression<DateTime>? creadoEn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cuentaId != null) 'cuenta_id': cuentaId,
      if (tipo != null) 'tipo': tipo,
      if (monto != null) 'monto': monto,
      if (descripcion != null) 'descripcion': descripcion,
      if (fecha != null) 'fecha': fecha,
      if (categoria != null) 'categoria': categoria,
      if (cuotas != null) 'cuotas': cuotas,
      if (ingresoPlanificadoId != null)
        'ingreso_planificado_id': ingresoPlanificadoId,
      if (metaId != null) 'meta_id': metaId,
      if (creadoEn != null) 'creado_en': creadoEn,
    });
  }

  TransaccionesCompanion copyWith({
    Value<int>? id,
    Value<int?>? cuentaId,
    Value<String>? tipo,
    Value<double>? monto,
    Value<String>? descripcion,
    Value<String>? fecha,
    Value<String>? categoria,
    Value<int>? cuotas,
    Value<int?>? ingresoPlanificadoId,
    Value<int?>? metaId,
    Value<DateTime>? creadoEn,
  }) {
    return TransaccionesCompanion(
      id: id ?? this.id,
      cuentaId: cuentaId ?? this.cuentaId,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
      categoria: categoria ?? this.categoria,
      cuotas: cuotas ?? this.cuotas,
      ingresoPlanificadoId: ingresoPlanificadoId ?? this.ingresoPlanificadoId,
      metaId: metaId ?? this.metaId,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cuentaId.present) {
      map['cuenta_id'] = Variable<int>(cuentaId.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (cuotas.present) {
      map['cuotas'] = Variable<int>(cuotas.value);
    }
    if (ingresoPlanificadoId.present) {
      map['ingreso_planificado_id'] = Variable<int>(ingresoPlanificadoId.value);
    }
    if (metaId.present) {
      map['meta_id'] = Variable<int>(metaId.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransaccionesCompanion(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('tipo: $tipo, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha, ')
          ..write('categoria: $categoria, ')
          ..write('cuotas: $cuotas, ')
          ..write('ingresoPlanificadoId: $ingresoPlanificadoId, ')
          ..write('metaId: $metaId, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }
}

class $TransferenciasTable extends Transferencias
    with TableInfo<$TransferenciasTable, Transferencia> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransferenciasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cuentaOrigenIdMeta = const VerificationMeta(
    'cuentaOrigenId',
  );
  @override
  late final GeneratedColumn<int> cuentaOrigenId = GeneratedColumn<int>(
    'cuenta_origen_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cuentaDestinoIdMeta = const VerificationMeta(
    'cuentaDestinoId',
  );
  @override
  late final GeneratedColumn<int> cuentaDestinoId = GeneratedColumn<int>(
    'cuenta_destino_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<String> fecha = GeneratedColumn<String>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cuentaOrigenId,
    cuentaDestinoId,
    monto,
    descripcion,
    fecha,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transferencias';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transferencia> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cuenta_origen_id')) {
      context.handle(
        _cuentaOrigenIdMeta,
        cuentaOrigenId.isAcceptableOrUnknown(
          data['cuenta_origen_id']!,
          _cuentaOrigenIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cuentaOrigenIdMeta);
    }
    if (data.containsKey('cuenta_destino_id')) {
      context.handle(
        _cuentaDestinoIdMeta,
        cuentaDestinoId.isAcceptableOrUnknown(
          data['cuenta_destino_id']!,
          _cuentaDestinoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cuentaDestinoIdMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transferencia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transferencia(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cuentaOrigenId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuenta_origen_id'],
      )!,
      cuentaDestinoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuenta_destino_id'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      )!,
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha'],
      )!,
    );
  }

  @override
  $TransferenciasTable createAlias(String alias) {
    return $TransferenciasTable(attachedDatabase, alias);
  }
}

class Transferencia extends DataClass implements Insertable<Transferencia> {
  final int id;
  final int cuentaOrigenId;
  final int cuentaDestinoId;
  final double monto;
  final String descripcion;
  final String fecha;
  const Transferencia({
    required this.id,
    required this.cuentaOrigenId,
    required this.cuentaDestinoId,
    required this.monto,
    required this.descripcion,
    required this.fecha,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['cuenta_origen_id'] = Variable<int>(cuentaOrigenId);
    map['cuenta_destino_id'] = Variable<int>(cuentaDestinoId);
    map['monto'] = Variable<double>(monto);
    map['descripcion'] = Variable<String>(descripcion);
    map['fecha'] = Variable<String>(fecha);
    return map;
  }

  TransferenciasCompanion toCompanion(bool nullToAbsent) {
    return TransferenciasCompanion(
      id: Value(id),
      cuentaOrigenId: Value(cuentaOrigenId),
      cuentaDestinoId: Value(cuentaDestinoId),
      monto: Value(monto),
      descripcion: Value(descripcion),
      fecha: Value(fecha),
    );
  }

  factory Transferencia.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transferencia(
      id: serializer.fromJson<int>(json['id']),
      cuentaOrigenId: serializer.fromJson<int>(json['cuentaOrigenId']),
      cuentaDestinoId: serializer.fromJson<int>(json['cuentaDestinoId']),
      monto: serializer.fromJson<double>(json['monto']),
      descripcion: serializer.fromJson<String>(json['descripcion']),
      fecha: serializer.fromJson<String>(json['fecha']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cuentaOrigenId': serializer.toJson<int>(cuentaOrigenId),
      'cuentaDestinoId': serializer.toJson<int>(cuentaDestinoId),
      'monto': serializer.toJson<double>(monto),
      'descripcion': serializer.toJson<String>(descripcion),
      'fecha': serializer.toJson<String>(fecha),
    };
  }

  Transferencia copyWith({
    int? id,
    int? cuentaOrigenId,
    int? cuentaDestinoId,
    double? monto,
    String? descripcion,
    String? fecha,
  }) => Transferencia(
    id: id ?? this.id,
    cuentaOrigenId: cuentaOrigenId ?? this.cuentaOrigenId,
    cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
    monto: monto ?? this.monto,
    descripcion: descripcion ?? this.descripcion,
    fecha: fecha ?? this.fecha,
  );
  Transferencia copyWithCompanion(TransferenciasCompanion data) {
    return Transferencia(
      id: data.id.present ? data.id.value : this.id,
      cuentaOrigenId: data.cuentaOrigenId.present
          ? data.cuentaOrigenId.value
          : this.cuentaOrigenId,
      cuentaDestinoId: data.cuentaDestinoId.present
          ? data.cuentaDestinoId.value
          : this.cuentaDestinoId,
      monto: data.monto.present ? data.monto.value : this.monto,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transferencia(')
          ..write('id: $id, ')
          ..write('cuentaOrigenId: $cuentaOrigenId, ')
          ..write('cuentaDestinoId: $cuentaDestinoId, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cuentaOrigenId,
    cuentaDestinoId,
    monto,
    descripcion,
    fecha,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transferencia &&
          other.id == this.id &&
          other.cuentaOrigenId == this.cuentaOrigenId &&
          other.cuentaDestinoId == this.cuentaDestinoId &&
          other.monto == this.monto &&
          other.descripcion == this.descripcion &&
          other.fecha == this.fecha);
}

class TransferenciasCompanion extends UpdateCompanion<Transferencia> {
  final Value<int> id;
  final Value<int> cuentaOrigenId;
  final Value<int> cuentaDestinoId;
  final Value<double> monto;
  final Value<String> descripcion;
  final Value<String> fecha;
  const TransferenciasCompanion({
    this.id = const Value.absent(),
    this.cuentaOrigenId = const Value.absent(),
    this.cuentaDestinoId = const Value.absent(),
    this.monto = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.fecha = const Value.absent(),
  });
  TransferenciasCompanion.insert({
    this.id = const Value.absent(),
    required int cuentaOrigenId,
    required int cuentaDestinoId,
    required double monto,
    this.descripcion = const Value.absent(),
    required String fecha,
  }) : cuentaOrigenId = Value(cuentaOrigenId),
       cuentaDestinoId = Value(cuentaDestinoId),
       monto = Value(monto),
       fecha = Value(fecha);
  static Insertable<Transferencia> custom({
    Expression<int>? id,
    Expression<int>? cuentaOrigenId,
    Expression<int>? cuentaDestinoId,
    Expression<double>? monto,
    Expression<String>? descripcion,
    Expression<String>? fecha,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cuentaOrigenId != null) 'cuenta_origen_id': cuentaOrigenId,
      if (cuentaDestinoId != null) 'cuenta_destino_id': cuentaDestinoId,
      if (monto != null) 'monto': monto,
      if (descripcion != null) 'descripcion': descripcion,
      if (fecha != null) 'fecha': fecha,
    });
  }

  TransferenciasCompanion copyWith({
    Value<int>? id,
    Value<int>? cuentaOrigenId,
    Value<int>? cuentaDestinoId,
    Value<double>? monto,
    Value<String>? descripcion,
    Value<String>? fecha,
  }) {
    return TransferenciasCompanion(
      id: id ?? this.id,
      cuentaOrigenId: cuentaOrigenId ?? this.cuentaOrigenId,
      cuentaDestinoId: cuentaDestinoId ?? this.cuentaDestinoId,
      monto: monto ?? this.monto,
      descripcion: descripcion ?? this.descripcion,
      fecha: fecha ?? this.fecha,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cuentaOrigenId.present) {
      map['cuenta_origen_id'] = Variable<int>(cuentaOrigenId.value);
    }
    if (cuentaDestinoId.present) {
      map['cuenta_destino_id'] = Variable<int>(cuentaDestinoId.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<String>(fecha.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransferenciasCompanion(')
          ..write('id: $id, ')
          ..write('cuentaOrigenId: $cuentaOrigenId, ')
          ..write('cuentaDestinoId: $cuentaDestinoId, ')
          ..write('monto: $monto, ')
          ..write('descripcion: $descripcion, ')
          ..write('fecha: $fecha')
          ..write(')'))
        .toString();
  }
}

class $IngresosPlanificadosTable extends IngresosPlanificados
    with TableInfo<$IngresosPlanificadosTable, IngresoPlanificado> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngresosPlanificadosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cuentaIdMeta = const VerificationMeta(
    'cuentaId',
  );
  @override
  late final GeneratedColumn<int> cuentaId = GeneratedColumn<int>(
    'cuenta_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frecuenciaMeta = const VerificationMeta(
    'frecuencia',
  );
  @override
  late final GeneratedColumn<String> frecuencia = GeneratedColumn<String>(
    'frecuencia',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaInicioMeta = const VerificationMeta(
    'fechaInicio',
  );
  @override
  late final GeneratedColumn<String> fechaInicio = GeneratedColumn<String>(
    'fecha_inicio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activoMeta = const VerificationMeta('activo');
  @override
  late final GeneratedColumn<bool> activo = GeneratedColumn<bool>(
    'activo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("activo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cuentaId,
    descripcion,
    monto,
    frecuencia,
    fechaInicio,
    activo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingresos_planificados';
  @override
  VerificationContext validateIntegrity(
    Insertable<IngresoPlanificado> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('cuenta_id')) {
      context.handle(
        _cuentaIdMeta,
        cuentaId.isAcceptableOrUnknown(data['cuenta_id']!, _cuentaIdMeta),
      );
    }
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descripcionMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('frecuencia')) {
      context.handle(
        _frecuenciaMeta,
        frecuencia.isAcceptableOrUnknown(data['frecuencia']!, _frecuenciaMeta),
      );
    } else if (isInserting) {
      context.missing(_frecuenciaMeta);
    }
    if (data.containsKey('fecha_inicio')) {
      context.handle(
        _fechaInicioMeta,
        fechaInicio.isAcceptableOrUnknown(
          data['fecha_inicio']!,
          _fechaInicioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaInicioMeta);
    }
    if (data.containsKey('activo')) {
      context.handle(
        _activoMeta,
        activo.isAcceptableOrUnknown(data['activo']!, _activoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IngresoPlanificado map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IngresoPlanificado(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cuentaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cuenta_id'],
      ),
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
      frecuencia: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frecuencia'],
      )!,
      fechaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_inicio'],
      )!,
      activo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}activo'],
      )!,
    );
  }

  @override
  $IngresosPlanificadosTable createAlias(String alias) {
    return $IngresosPlanificadosTable(attachedDatabase, alias);
  }
}

class IngresoPlanificado extends DataClass
    implements Insertable<IngresoPlanificado> {
  final int id;
  final int? cuentaId;
  final String descripcion;
  final double monto;

  /// diario · semanal · quincenal · mensual · unica
  final String frecuencia;
  final String fechaInicio;
  final bool activo;
  const IngresoPlanificado({
    required this.id,
    this.cuentaId,
    required this.descripcion,
    required this.monto,
    required this.frecuencia,
    required this.fechaInicio,
    required this.activo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || cuentaId != null) {
      map['cuenta_id'] = Variable<int>(cuentaId);
    }
    map['descripcion'] = Variable<String>(descripcion);
    map['monto'] = Variable<double>(monto);
    map['frecuencia'] = Variable<String>(frecuencia);
    map['fecha_inicio'] = Variable<String>(fechaInicio);
    map['activo'] = Variable<bool>(activo);
    return map;
  }

  IngresosPlanificadosCompanion toCompanion(bool nullToAbsent) {
    return IngresosPlanificadosCompanion(
      id: Value(id),
      cuentaId: cuentaId == null && nullToAbsent
          ? const Value.absent()
          : Value(cuentaId),
      descripcion: Value(descripcion),
      monto: Value(monto),
      frecuencia: Value(frecuencia),
      fechaInicio: Value(fechaInicio),
      activo: Value(activo),
    );
  }

  factory IngresoPlanificado.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IngresoPlanificado(
      id: serializer.fromJson<int>(json['id']),
      cuentaId: serializer.fromJson<int?>(json['cuentaId']),
      descripcion: serializer.fromJson<String>(json['descripcion']),
      monto: serializer.fromJson<double>(json['monto']),
      frecuencia: serializer.fromJson<String>(json['frecuencia']),
      fechaInicio: serializer.fromJson<String>(json['fechaInicio']),
      activo: serializer.fromJson<bool>(json['activo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cuentaId': serializer.toJson<int?>(cuentaId),
      'descripcion': serializer.toJson<String>(descripcion),
      'monto': serializer.toJson<double>(monto),
      'frecuencia': serializer.toJson<String>(frecuencia),
      'fechaInicio': serializer.toJson<String>(fechaInicio),
      'activo': serializer.toJson<bool>(activo),
    };
  }

  IngresoPlanificado copyWith({
    int? id,
    Value<int?> cuentaId = const Value.absent(),
    String? descripcion,
    double? monto,
    String? frecuencia,
    String? fechaInicio,
    bool? activo,
  }) => IngresoPlanificado(
    id: id ?? this.id,
    cuentaId: cuentaId.present ? cuentaId.value : this.cuentaId,
    descripcion: descripcion ?? this.descripcion,
    monto: monto ?? this.monto,
    frecuencia: frecuencia ?? this.frecuencia,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    activo: activo ?? this.activo,
  );
  IngresoPlanificado copyWithCompanion(IngresosPlanificadosCompanion data) {
    return IngresoPlanificado(
      id: data.id.present ? data.id.value : this.id,
      cuentaId: data.cuentaId.present ? data.cuentaId.value : this.cuentaId,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      monto: data.monto.present ? data.monto.value : this.monto,
      frecuencia: data.frecuencia.present
          ? data.frecuencia.value
          : this.frecuencia,
      fechaInicio: data.fechaInicio.present
          ? data.fechaInicio.value
          : this.fechaInicio,
      activo: data.activo.present ? data.activo.value : this.activo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IngresoPlanificado(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('descripcion: $descripcion, ')
          ..write('monto: $monto, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('activo: $activo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cuentaId,
    descripcion,
    monto,
    frecuencia,
    fechaInicio,
    activo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IngresoPlanificado &&
          other.id == this.id &&
          other.cuentaId == this.cuentaId &&
          other.descripcion == this.descripcion &&
          other.monto == this.monto &&
          other.frecuencia == this.frecuencia &&
          other.fechaInicio == this.fechaInicio &&
          other.activo == this.activo);
}

class IngresosPlanificadosCompanion
    extends UpdateCompanion<IngresoPlanificado> {
  final Value<int> id;
  final Value<int?> cuentaId;
  final Value<String> descripcion;
  final Value<double> monto;
  final Value<String> frecuencia;
  final Value<String> fechaInicio;
  final Value<bool> activo;
  const IngresosPlanificadosCompanion({
    this.id = const Value.absent(),
    this.cuentaId = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.monto = const Value.absent(),
    this.frecuencia = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.activo = const Value.absent(),
  });
  IngresosPlanificadosCompanion.insert({
    this.id = const Value.absent(),
    this.cuentaId = const Value.absent(),
    required String descripcion,
    required double monto,
    required String frecuencia,
    required String fechaInicio,
    this.activo = const Value.absent(),
  }) : descripcion = Value(descripcion),
       monto = Value(monto),
       frecuencia = Value(frecuencia),
       fechaInicio = Value(fechaInicio);
  static Insertable<IngresoPlanificado> custom({
    Expression<int>? id,
    Expression<int>? cuentaId,
    Expression<String>? descripcion,
    Expression<double>? monto,
    Expression<String>? frecuencia,
    Expression<String>? fechaInicio,
    Expression<bool>? activo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cuentaId != null) 'cuenta_id': cuentaId,
      if (descripcion != null) 'descripcion': descripcion,
      if (monto != null) 'monto': monto,
      if (frecuencia != null) 'frecuencia': frecuencia,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (activo != null) 'activo': activo,
    });
  }

  IngresosPlanificadosCompanion copyWith({
    Value<int>? id,
    Value<int?>? cuentaId,
    Value<String>? descripcion,
    Value<double>? monto,
    Value<String>? frecuencia,
    Value<String>? fechaInicio,
    Value<bool>? activo,
  }) {
    return IngresosPlanificadosCompanion(
      id: id ?? this.id,
      cuentaId: cuentaId ?? this.cuentaId,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      frecuencia: frecuencia ?? this.frecuencia,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      activo: activo ?? this.activo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cuentaId.present) {
      map['cuenta_id'] = Variable<int>(cuentaId.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (frecuencia.present) {
      map['frecuencia'] = Variable<String>(frecuencia.value);
    }
    if (fechaInicio.present) {
      map['fecha_inicio'] = Variable<String>(fechaInicio.value);
    }
    if (activo.present) {
      map['activo'] = Variable<bool>(activo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngresosPlanificadosCompanion(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('descripcion: $descripcion, ')
          ..write('monto: $monto, ')
          ..write('frecuencia: $frecuencia, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('activo: $activo')
          ..write(')'))
        .toString();
  }
}

class $VerificacionesTable extends Verificaciones
    with TableInfo<$VerificacionesTable, Verificacion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VerificacionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ingresoPlanificadoIdMeta =
      const VerificationMeta('ingresoPlanificadoId');
  @override
  late final GeneratedColumn<int> ingresoPlanificadoId = GeneratedColumn<int>(
    'ingreso_planificado_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaEsperadaMeta = const VerificationMeta(
    'fechaEsperada',
  );
  @override
  late final GeneratedColumn<String> fechaEsperada = GeneratedColumn<String>(
    'fecha_esperada',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaRealMeta = const VerificationMeta(
    'fechaReal',
  );
  @override
  late final GeneratedColumn<String> fechaReal = GeneratedColumn<String>(
    'fecha_real',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoRealMeta = const VerificationMeta(
    'montoReal',
  );
  @override
  late final GeneratedColumn<double> montoReal = GeneratedColumn<double>(
    'monto_real',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transaccionIdMeta = const VerificationMeta(
    'transaccionId',
  );
  @override
  late final GeneratedColumn<int> transaccionId = GeneratedColumn<int>(
    'transaccion_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ingresoPlanificadoId,
    fechaEsperada,
    fechaReal,
    montoReal,
    transaccionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'verificaciones';
  @override
  VerificationContext validateIntegrity(
    Insertable<Verificacion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ingreso_planificado_id')) {
      context.handle(
        _ingresoPlanificadoIdMeta,
        ingresoPlanificadoId.isAcceptableOrUnknown(
          data['ingreso_planificado_id']!,
          _ingresoPlanificadoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingresoPlanificadoIdMeta);
    }
    if (data.containsKey('fecha_esperada')) {
      context.handle(
        _fechaEsperadaMeta,
        fechaEsperada.isAcceptableOrUnknown(
          data['fecha_esperada']!,
          _fechaEsperadaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaEsperadaMeta);
    }
    if (data.containsKey('fecha_real')) {
      context.handle(
        _fechaRealMeta,
        fechaReal.isAcceptableOrUnknown(data['fecha_real']!, _fechaRealMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaRealMeta);
    }
    if (data.containsKey('monto_real')) {
      context.handle(
        _montoRealMeta,
        montoReal.isAcceptableOrUnknown(data['monto_real']!, _montoRealMeta),
      );
    } else if (isInserting) {
      context.missing(_montoRealMeta);
    }
    if (data.containsKey('transaccion_id')) {
      context.handle(
        _transaccionIdMeta,
        transaccionId.isAcceptableOrUnknown(
          data['transaccion_id']!,
          _transaccionIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ingresoPlanificadoId, fechaEsperada},
  ];
  @override
  Verificacion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Verificacion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ingresoPlanificadoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingreso_planificado_id'],
      )!,
      fechaEsperada: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_esperada'],
      )!,
      fechaReal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_real'],
      )!,
      montoReal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_real'],
      )!,
      transaccionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}transaccion_id'],
      ),
    );
  }

  @override
  $VerificacionesTable createAlias(String alias) {
    return $VerificacionesTable(attachedDatabase, alias);
  }
}

class Verificacion extends DataClass implements Insertable<Verificacion> {
  final int id;
  final int ingresoPlanificadoId;
  final String fechaEsperada;
  final String fechaReal;
  final double montoReal;
  final int? transaccionId;
  const Verificacion({
    required this.id,
    required this.ingresoPlanificadoId,
    required this.fechaEsperada,
    required this.fechaReal,
    required this.montoReal,
    this.transaccionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ingreso_planificado_id'] = Variable<int>(ingresoPlanificadoId);
    map['fecha_esperada'] = Variable<String>(fechaEsperada);
    map['fecha_real'] = Variable<String>(fechaReal);
    map['monto_real'] = Variable<double>(montoReal);
    if (!nullToAbsent || transaccionId != null) {
      map['transaccion_id'] = Variable<int>(transaccionId);
    }
    return map;
  }

  VerificacionesCompanion toCompanion(bool nullToAbsent) {
    return VerificacionesCompanion(
      id: Value(id),
      ingresoPlanificadoId: Value(ingresoPlanificadoId),
      fechaEsperada: Value(fechaEsperada),
      fechaReal: Value(fechaReal),
      montoReal: Value(montoReal),
      transaccionId: transaccionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transaccionId),
    );
  }

  factory Verificacion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Verificacion(
      id: serializer.fromJson<int>(json['id']),
      ingresoPlanificadoId: serializer.fromJson<int>(
        json['ingresoPlanificadoId'],
      ),
      fechaEsperada: serializer.fromJson<String>(json['fechaEsperada']),
      fechaReal: serializer.fromJson<String>(json['fechaReal']),
      montoReal: serializer.fromJson<double>(json['montoReal']),
      transaccionId: serializer.fromJson<int?>(json['transaccionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ingresoPlanificadoId': serializer.toJson<int>(ingresoPlanificadoId),
      'fechaEsperada': serializer.toJson<String>(fechaEsperada),
      'fechaReal': serializer.toJson<String>(fechaReal),
      'montoReal': serializer.toJson<double>(montoReal),
      'transaccionId': serializer.toJson<int?>(transaccionId),
    };
  }

  Verificacion copyWith({
    int? id,
    int? ingresoPlanificadoId,
    String? fechaEsperada,
    String? fechaReal,
    double? montoReal,
    Value<int?> transaccionId = const Value.absent(),
  }) => Verificacion(
    id: id ?? this.id,
    ingresoPlanificadoId: ingresoPlanificadoId ?? this.ingresoPlanificadoId,
    fechaEsperada: fechaEsperada ?? this.fechaEsperada,
    fechaReal: fechaReal ?? this.fechaReal,
    montoReal: montoReal ?? this.montoReal,
    transaccionId: transaccionId.present
        ? transaccionId.value
        : this.transaccionId,
  );
  Verificacion copyWithCompanion(VerificacionesCompanion data) {
    return Verificacion(
      id: data.id.present ? data.id.value : this.id,
      ingresoPlanificadoId: data.ingresoPlanificadoId.present
          ? data.ingresoPlanificadoId.value
          : this.ingresoPlanificadoId,
      fechaEsperada: data.fechaEsperada.present
          ? data.fechaEsperada.value
          : this.fechaEsperada,
      fechaReal: data.fechaReal.present ? data.fechaReal.value : this.fechaReal,
      montoReal: data.montoReal.present ? data.montoReal.value : this.montoReal,
      transaccionId: data.transaccionId.present
          ? data.transaccionId.value
          : this.transaccionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Verificacion(')
          ..write('id: $id, ')
          ..write('ingresoPlanificadoId: $ingresoPlanificadoId, ')
          ..write('fechaEsperada: $fechaEsperada, ')
          ..write('fechaReal: $fechaReal, ')
          ..write('montoReal: $montoReal, ')
          ..write('transaccionId: $transaccionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ingresoPlanificadoId,
    fechaEsperada,
    fechaReal,
    montoReal,
    transaccionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Verificacion &&
          other.id == this.id &&
          other.ingresoPlanificadoId == this.ingresoPlanificadoId &&
          other.fechaEsperada == this.fechaEsperada &&
          other.fechaReal == this.fechaReal &&
          other.montoReal == this.montoReal &&
          other.transaccionId == this.transaccionId);
}

class VerificacionesCompanion extends UpdateCompanion<Verificacion> {
  final Value<int> id;
  final Value<int> ingresoPlanificadoId;
  final Value<String> fechaEsperada;
  final Value<String> fechaReal;
  final Value<double> montoReal;
  final Value<int?> transaccionId;
  const VerificacionesCompanion({
    this.id = const Value.absent(),
    this.ingresoPlanificadoId = const Value.absent(),
    this.fechaEsperada = const Value.absent(),
    this.fechaReal = const Value.absent(),
    this.montoReal = const Value.absent(),
    this.transaccionId = const Value.absent(),
  });
  VerificacionesCompanion.insert({
    this.id = const Value.absent(),
    required int ingresoPlanificadoId,
    required String fechaEsperada,
    required String fechaReal,
    required double montoReal,
    this.transaccionId = const Value.absent(),
  }) : ingresoPlanificadoId = Value(ingresoPlanificadoId),
       fechaEsperada = Value(fechaEsperada),
       fechaReal = Value(fechaReal),
       montoReal = Value(montoReal);
  static Insertable<Verificacion> custom({
    Expression<int>? id,
    Expression<int>? ingresoPlanificadoId,
    Expression<String>? fechaEsperada,
    Expression<String>? fechaReal,
    Expression<double>? montoReal,
    Expression<int>? transaccionId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ingresoPlanificadoId != null)
        'ingreso_planificado_id': ingresoPlanificadoId,
      if (fechaEsperada != null) 'fecha_esperada': fechaEsperada,
      if (fechaReal != null) 'fecha_real': fechaReal,
      if (montoReal != null) 'monto_real': montoReal,
      if (transaccionId != null) 'transaccion_id': transaccionId,
    });
  }

  VerificacionesCompanion copyWith({
    Value<int>? id,
    Value<int>? ingresoPlanificadoId,
    Value<String>? fechaEsperada,
    Value<String>? fechaReal,
    Value<double>? montoReal,
    Value<int?>? transaccionId,
  }) {
    return VerificacionesCompanion(
      id: id ?? this.id,
      ingresoPlanificadoId: ingresoPlanificadoId ?? this.ingresoPlanificadoId,
      fechaEsperada: fechaEsperada ?? this.fechaEsperada,
      fechaReal: fechaReal ?? this.fechaReal,
      montoReal: montoReal ?? this.montoReal,
      transaccionId: transaccionId ?? this.transaccionId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ingresoPlanificadoId.present) {
      map['ingreso_planificado_id'] = Variable<int>(ingresoPlanificadoId.value);
    }
    if (fechaEsperada.present) {
      map['fecha_esperada'] = Variable<String>(fechaEsperada.value);
    }
    if (fechaReal.present) {
      map['fecha_real'] = Variable<String>(fechaReal.value);
    }
    if (montoReal.present) {
      map['monto_real'] = Variable<double>(montoReal.value);
    }
    if (transaccionId.present) {
      map['transaccion_id'] = Variable<int>(transaccionId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VerificacionesCompanion(')
          ..write('id: $id, ')
          ..write('ingresoPlanificadoId: $ingresoPlanificadoId, ')
          ..write('fechaEsperada: $fechaEsperada, ')
          ..write('fechaReal: $fechaReal, ')
          ..write('montoReal: $montoReal, ')
          ..write('transaccionId: $transaccionId')
          ..write(')'))
        .toString();
  }
}

class $MetasTable extends Metas with TableInfo<$MetasTable, Meta> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _montoObjetivoMeta = const VerificationMeta(
    'montoObjetivo',
  );
  @override
  late final GeneratedColumn<double> montoObjetivo = GeneratedColumn<double>(
    'monto_objetivo',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoActualMeta = const VerificationMeta(
    'montoActual',
  );
  @override
  late final GeneratedColumn<double> montoActual = GeneratedColumn<double>(
    'monto_actual',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fechaObjetivoMeta = const VerificationMeta(
    'fechaObjetivo',
  );
  @override
  late final GeneratedColumn<String> fechaObjetivo = GeneratedColumn<String>(
    'fecha_objetivo',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconoMeta = const VerificationMeta('icono');
  @override
  late final GeneratedColumn<String> icono = GeneratedColumn<String>(
    'icono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('savings'),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFF34E47E),
  );
  static const VerificationMeta _completadaMeta = const VerificationMeta(
    'completada',
  );
  @override
  late final GeneratedColumn<bool> completada = GeneratedColumn<bool>(
    'completada',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completada" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    descripcion,
    montoObjetivo,
    montoActual,
    fechaObjetivo,
    icono,
    color,
    completada,
    creadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'metas';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meta> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    }
    if (data.containsKey('monto_objetivo')) {
      context.handle(
        _montoObjetivoMeta,
        montoObjetivo.isAcceptableOrUnknown(
          data['monto_objetivo']!,
          _montoObjetivoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoObjetivoMeta);
    }
    if (data.containsKey('monto_actual')) {
      context.handle(
        _montoActualMeta,
        montoActual.isAcceptableOrUnknown(
          data['monto_actual']!,
          _montoActualMeta,
        ),
      );
    }
    if (data.containsKey('fecha_objetivo')) {
      context.handle(
        _fechaObjetivoMeta,
        fechaObjetivo.isAcceptableOrUnknown(
          data['fecha_objetivo']!,
          _fechaObjetivoMeta,
        ),
      );
    }
    if (data.containsKey('icono')) {
      context.handle(
        _iconoMeta,
        icono.isAcceptableOrUnknown(data['icono']!, _iconoMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('completada')) {
      context.handle(
        _completadaMeta,
        completada.isAcceptableOrUnknown(data['completada']!, _completadaMeta),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meta map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meta(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      )!,
      montoObjetivo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_objetivo'],
      )!,
      montoActual: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_actual'],
      )!,
      fechaObjetivo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fecha_objetivo'],
      ),
      icono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icono'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      completada: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completada'],
      )!,
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $MetasTable createAlias(String alias) {
    return $MetasTable(attachedDatabase, alias);
  }
}

class Meta extends DataClass implements Insertable<Meta> {
  final int id;
  final String nombre;
  final String descripcion;
  final double montoObjetivo;
  final double montoActual;
  final String? fechaObjetivo;
  final String icono;
  final int color;
  final bool completada;
  final DateTime creadoEn;
  const Meta({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.montoObjetivo,
    required this.montoActual,
    this.fechaObjetivo,
    required this.icono,
    required this.color,
    required this.completada,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['nombre'] = Variable<String>(nombre);
    map['descripcion'] = Variable<String>(descripcion);
    map['monto_objetivo'] = Variable<double>(montoObjetivo);
    map['monto_actual'] = Variable<double>(montoActual);
    if (!nullToAbsent || fechaObjetivo != null) {
      map['fecha_objetivo'] = Variable<String>(fechaObjetivo);
    }
    map['icono'] = Variable<String>(icono);
    map['color'] = Variable<int>(color);
    map['completada'] = Variable<bool>(completada);
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  MetasCompanion toCompanion(bool nullToAbsent) {
    return MetasCompanion(
      id: Value(id),
      nombre: Value(nombre),
      descripcion: Value(descripcion),
      montoObjetivo: Value(montoObjetivo),
      montoActual: Value(montoActual),
      fechaObjetivo: fechaObjetivo == null && nullToAbsent
          ? const Value.absent()
          : Value(fechaObjetivo),
      icono: Value(icono),
      color: Value(color),
      completada: Value(completada),
      creadoEn: Value(creadoEn),
    );
  }

  factory Meta.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meta(
      id: serializer.fromJson<int>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      descripcion: serializer.fromJson<String>(json['descripcion']),
      montoObjetivo: serializer.fromJson<double>(json['montoObjetivo']),
      montoActual: serializer.fromJson<double>(json['montoActual']),
      fechaObjetivo: serializer.fromJson<String?>(json['fechaObjetivo']),
      icono: serializer.fromJson<String>(json['icono']),
      color: serializer.fromJson<int>(json['color']),
      completada: serializer.fromJson<bool>(json['completada']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nombre': serializer.toJson<String>(nombre),
      'descripcion': serializer.toJson<String>(descripcion),
      'montoObjetivo': serializer.toJson<double>(montoObjetivo),
      'montoActual': serializer.toJson<double>(montoActual),
      'fechaObjetivo': serializer.toJson<String?>(fechaObjetivo),
      'icono': serializer.toJson<String>(icono),
      'color': serializer.toJson<int>(color),
      'completada': serializer.toJson<bool>(completada),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  Meta copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    double? montoObjetivo,
    double? montoActual,
    Value<String?> fechaObjetivo = const Value.absent(),
    String? icono,
    int? color,
    bool? completada,
    DateTime? creadoEn,
  }) => Meta(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    descripcion: descripcion ?? this.descripcion,
    montoObjetivo: montoObjetivo ?? this.montoObjetivo,
    montoActual: montoActual ?? this.montoActual,
    fechaObjetivo: fechaObjetivo.present
        ? fechaObjetivo.value
        : this.fechaObjetivo,
    icono: icono ?? this.icono,
    color: color ?? this.color,
    completada: completada ?? this.completada,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  Meta copyWithCompanion(MetasCompanion data) {
    return Meta(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      montoObjetivo: data.montoObjetivo.present
          ? data.montoObjetivo.value
          : this.montoObjetivo,
      montoActual: data.montoActual.present
          ? data.montoActual.value
          : this.montoActual,
      fechaObjetivo: data.fechaObjetivo.present
          ? data.fechaObjetivo.value
          : this.fechaObjetivo,
      icono: data.icono.present ? data.icono.value : this.icono,
      color: data.color.present ? data.color.value : this.color,
      completada: data.completada.present
          ? data.completada.value
          : this.completada,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meta(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('descripcion: $descripcion, ')
          ..write('montoObjetivo: $montoObjetivo, ')
          ..write('montoActual: $montoActual, ')
          ..write('fechaObjetivo: $fechaObjetivo, ')
          ..write('icono: $icono, ')
          ..write('color: $color, ')
          ..write('completada: $completada, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nombre,
    descripcion,
    montoObjetivo,
    montoActual,
    fechaObjetivo,
    icono,
    color,
    completada,
    creadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meta &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.descripcion == this.descripcion &&
          other.montoObjetivo == this.montoObjetivo &&
          other.montoActual == this.montoActual &&
          other.fechaObjetivo == this.fechaObjetivo &&
          other.icono == this.icono &&
          other.color == this.color &&
          other.completada == this.completada &&
          other.creadoEn == this.creadoEn);
}

class MetasCompanion extends UpdateCompanion<Meta> {
  final Value<int> id;
  final Value<String> nombre;
  final Value<String> descripcion;
  final Value<double> montoObjetivo;
  final Value<double> montoActual;
  final Value<String?> fechaObjetivo;
  final Value<String> icono;
  final Value<int> color;
  final Value<bool> completada;
  final Value<DateTime> creadoEn;
  const MetasCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.montoObjetivo = const Value.absent(),
    this.montoActual = const Value.absent(),
    this.fechaObjetivo = const Value.absent(),
    this.icono = const Value.absent(),
    this.color = const Value.absent(),
    this.completada = const Value.absent(),
    this.creadoEn = const Value.absent(),
  });
  MetasCompanion.insert({
    this.id = const Value.absent(),
    required String nombre,
    this.descripcion = const Value.absent(),
    required double montoObjetivo,
    this.montoActual = const Value.absent(),
    this.fechaObjetivo = const Value.absent(),
    this.icono = const Value.absent(),
    this.color = const Value.absent(),
    this.completada = const Value.absent(),
    this.creadoEn = const Value.absent(),
  }) : nombre = Value(nombre),
       montoObjetivo = Value(montoObjetivo);
  static Insertable<Meta> custom({
    Expression<int>? id,
    Expression<String>? nombre,
    Expression<String>? descripcion,
    Expression<double>? montoObjetivo,
    Expression<double>? montoActual,
    Expression<String>? fechaObjetivo,
    Expression<String>? icono,
    Expression<int>? color,
    Expression<bool>? completada,
    Expression<DateTime>? creadoEn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (montoObjetivo != null) 'monto_objetivo': montoObjetivo,
      if (montoActual != null) 'monto_actual': montoActual,
      if (fechaObjetivo != null) 'fecha_objetivo': fechaObjetivo,
      if (icono != null) 'icono': icono,
      if (color != null) 'color': color,
      if (completada != null) 'completada': completada,
      if (creadoEn != null) 'creado_en': creadoEn,
    });
  }

  MetasCompanion copyWith({
    Value<int>? id,
    Value<String>? nombre,
    Value<String>? descripcion,
    Value<double>? montoObjetivo,
    Value<double>? montoActual,
    Value<String?>? fechaObjetivo,
    Value<String>? icono,
    Value<int>? color,
    Value<bool>? completada,
    Value<DateTime>? creadoEn,
  }) {
    return MetasCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      montoObjetivo: montoObjetivo ?? this.montoObjetivo,
      montoActual: montoActual ?? this.montoActual,
      fechaObjetivo: fechaObjetivo ?? this.fechaObjetivo,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      completada: completada ?? this.completada,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (montoObjetivo.present) {
      map['monto_objetivo'] = Variable<double>(montoObjetivo.value);
    }
    if (montoActual.present) {
      map['monto_actual'] = Variable<double>(montoActual.value);
    }
    if (fechaObjetivo.present) {
      map['fecha_objetivo'] = Variable<String>(fechaObjetivo.value);
    }
    if (icono.present) {
      map['icono'] = Variable<String>(icono.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (completada.present) {
      map['completada'] = Variable<bool>(completada.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetasCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('descripcion: $descripcion, ')
          ..write('montoObjetivo: $montoObjetivo, ')
          ..write('montoActual: $montoActual, ')
          ..write('fechaObjetivo: $fechaObjetivo, ')
          ..write('icono: $icono, ')
          ..write('color: $color, ')
          ..write('completada: $completada, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }
}

class $PresupuestosTable extends Presupuestos
    with TableInfo<$PresupuestosTable, Presupuesto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresupuestosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _categoriaMeta = const VerificationMeta(
    'categoria',
  );
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoLimiteMeta = const VerificationMeta(
    'montoLimite',
  );
  @override
  late final GeneratedColumn<double> montoLimite = GeneratedColumn<double>(
    'monto_limite',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mesMeta = const VerificationMeta('mes');
  @override
  late final GeneratedColumn<int> mes = GeneratedColumn<int>(
    'mes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _anioMeta = const VerificationMeta('anio');
  @override
  late final GeneratedColumn<int> anio = GeneratedColumn<int>(
    'anio',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, categoria, montoLimite, mes, anio];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presupuestos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Presupuesto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('categoria')) {
      context.handle(
        _categoriaMeta,
        categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta),
      );
    } else if (isInserting) {
      context.missing(_categoriaMeta);
    }
    if (data.containsKey('monto_limite')) {
      context.handle(
        _montoLimiteMeta,
        montoLimite.isAcceptableOrUnknown(
          data['monto_limite']!,
          _montoLimiteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoLimiteMeta);
    }
    if (data.containsKey('mes')) {
      context.handle(
        _mesMeta,
        mes.isAcceptableOrUnknown(data['mes']!, _mesMeta),
      );
    } else if (isInserting) {
      context.missing(_mesMeta);
    }
    if (data.containsKey('anio')) {
      context.handle(
        _anioMeta,
        anio.isAcceptableOrUnknown(data['anio']!, _anioMeta),
      );
    } else if (isInserting) {
      context.missing(_anioMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {categoria, mes, anio},
  ];
  @override
  Presupuesto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Presupuesto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      categoria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria'],
      )!,
      montoLimite: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_limite'],
      )!,
      mes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mes'],
      )!,
      anio: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}anio'],
      )!,
    );
  }

  @override
  $PresupuestosTable createAlias(String alias) {
    return $PresupuestosTable(attachedDatabase, alias);
  }
}

class Presupuesto extends DataClass implements Insertable<Presupuesto> {
  final int id;
  final String categoria;
  final double montoLimite;

  /// 1..12
  final int mes;
  final int anio;
  const Presupuesto({
    required this.id,
    required this.categoria,
    required this.montoLimite,
    required this.mes,
    required this.anio,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['categoria'] = Variable<String>(categoria);
    map['monto_limite'] = Variable<double>(montoLimite);
    map['mes'] = Variable<int>(mes);
    map['anio'] = Variable<int>(anio);
    return map;
  }

  PresupuestosCompanion toCompanion(bool nullToAbsent) {
    return PresupuestosCompanion(
      id: Value(id),
      categoria: Value(categoria),
      montoLimite: Value(montoLimite),
      mes: Value(mes),
      anio: Value(anio),
    );
  }

  factory Presupuesto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Presupuesto(
      id: serializer.fromJson<int>(json['id']),
      categoria: serializer.fromJson<String>(json['categoria']),
      montoLimite: serializer.fromJson<double>(json['montoLimite']),
      mes: serializer.fromJson<int>(json['mes']),
      anio: serializer.fromJson<int>(json['anio']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'categoria': serializer.toJson<String>(categoria),
      'montoLimite': serializer.toJson<double>(montoLimite),
      'mes': serializer.toJson<int>(mes),
      'anio': serializer.toJson<int>(anio),
    };
  }

  Presupuesto copyWith({
    int? id,
    String? categoria,
    double? montoLimite,
    int? mes,
    int? anio,
  }) => Presupuesto(
    id: id ?? this.id,
    categoria: categoria ?? this.categoria,
    montoLimite: montoLimite ?? this.montoLimite,
    mes: mes ?? this.mes,
    anio: anio ?? this.anio,
  );
  Presupuesto copyWithCompanion(PresupuestosCompanion data) {
    return Presupuesto(
      id: data.id.present ? data.id.value : this.id,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      montoLimite: data.montoLimite.present
          ? data.montoLimite.value
          : this.montoLimite,
      mes: data.mes.present ? data.mes.value : this.mes,
      anio: data.anio.present ? data.anio.value : this.anio,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Presupuesto(')
          ..write('id: $id, ')
          ..write('categoria: $categoria, ')
          ..write('montoLimite: $montoLimite, ')
          ..write('mes: $mes, ')
          ..write('anio: $anio')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoria, montoLimite, mes, anio);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Presupuesto &&
          other.id == this.id &&
          other.categoria == this.categoria &&
          other.montoLimite == this.montoLimite &&
          other.mes == this.mes &&
          other.anio == this.anio);
}

class PresupuestosCompanion extends UpdateCompanion<Presupuesto> {
  final Value<int> id;
  final Value<String> categoria;
  final Value<double> montoLimite;
  final Value<int> mes;
  final Value<int> anio;
  const PresupuestosCompanion({
    this.id = const Value.absent(),
    this.categoria = const Value.absent(),
    this.montoLimite = const Value.absent(),
    this.mes = const Value.absent(),
    this.anio = const Value.absent(),
  });
  PresupuestosCompanion.insert({
    this.id = const Value.absent(),
    required String categoria,
    required double montoLimite,
    required int mes,
    required int anio,
  }) : categoria = Value(categoria),
       montoLimite = Value(montoLimite),
       mes = Value(mes),
       anio = Value(anio);
  static Insertable<Presupuesto> custom({
    Expression<int>? id,
    Expression<String>? categoria,
    Expression<double>? montoLimite,
    Expression<int>? mes,
    Expression<int>? anio,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoria != null) 'categoria': categoria,
      if (montoLimite != null) 'monto_limite': montoLimite,
      if (mes != null) 'mes': mes,
      if (anio != null) 'anio': anio,
    });
  }

  PresupuestosCompanion copyWith({
    Value<int>? id,
    Value<String>? categoria,
    Value<double>? montoLimite,
    Value<int>? mes,
    Value<int>? anio,
  }) {
    return PresupuestosCompanion(
      id: id ?? this.id,
      categoria: categoria ?? this.categoria,
      montoLimite: montoLimite ?? this.montoLimite,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (montoLimite.present) {
      map['monto_limite'] = Variable<double>(montoLimite.value);
    }
    if (mes.present) {
      map['mes'] = Variable<int>(mes.value);
    }
    if (anio.present) {
      map['anio'] = Variable<int>(anio.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresupuestosCompanion(')
          ..write('id: $id, ')
          ..write('categoria: $categoria, ')
          ..write('montoLimite: $montoLimite, ')
          ..write('mes: $mes, ')
          ..write('anio: $anio')
          ..write(')'))
        .toString();
  }
}

class $CategoriasFinanzasTable extends CategoriasFinanzas
    with TableInfo<$CategoriasFinanzasTable, CategoriaFinanzas> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriasFinanzasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconoMeta = const VerificationMeta('icono');
  @override
  late final GeneratedColumn<String> icono = GeneratedColumn<String>(
    'icono',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sell'),
  );
  static const VerificationMeta _esDefaultMeta = const VerificationMeta(
    'esDefault',
  );
  @override
  late final GeneratedColumn<bool> esDefault = GeneratedColumn<bool>(
    'es_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("es_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, valor, label, icono, esDefault];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categorias_finanzas';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoriaFinanzas> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('icono')) {
      context.handle(
        _iconoMeta,
        icono.isAcceptableOrUnknown(data['icono']!, _iconoMeta),
      );
    }
    if (data.containsKey('es_default')) {
      context.handle(
        _esDefaultMeta,
        esDefault.isAcceptableOrUnknown(data['es_default']!, _esDefaultMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoriaFinanzas map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriaFinanzas(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      icono: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icono'],
      )!,
      esDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}es_default'],
      )!,
    );
  }

  @override
  $CategoriasFinanzasTable createAlias(String alias) {
    return $CategoriasFinanzasTable(attachedDatabase, alias);
  }
}

class CategoriaFinanzas extends DataClass
    implements Insertable<CategoriaFinanzas> {
  final int id;
  final String valor;
  final String label;
  final String icono;
  final bool esDefault;
  const CategoriaFinanzas({
    required this.id,
    required this.valor,
    required this.label,
    required this.icono,
    required this.esDefault,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['valor'] = Variable<String>(valor);
    map['label'] = Variable<String>(label);
    map['icono'] = Variable<String>(icono);
    map['es_default'] = Variable<bool>(esDefault);
    return map;
  }

  CategoriasFinanzasCompanion toCompanion(bool nullToAbsent) {
    return CategoriasFinanzasCompanion(
      id: Value(id),
      valor: Value(valor),
      label: Value(label),
      icono: Value(icono),
      esDefault: Value(esDefault),
    );
  }

  factory CategoriaFinanzas.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriaFinanzas(
      id: serializer.fromJson<int>(json['id']),
      valor: serializer.fromJson<String>(json['valor']),
      label: serializer.fromJson<String>(json['label']),
      icono: serializer.fromJson<String>(json['icono']),
      esDefault: serializer.fromJson<bool>(json['esDefault']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'valor': serializer.toJson<String>(valor),
      'label': serializer.toJson<String>(label),
      'icono': serializer.toJson<String>(icono),
      'esDefault': serializer.toJson<bool>(esDefault),
    };
  }

  CategoriaFinanzas copyWith({
    int? id,
    String? valor,
    String? label,
    String? icono,
    bool? esDefault,
  }) => CategoriaFinanzas(
    id: id ?? this.id,
    valor: valor ?? this.valor,
    label: label ?? this.label,
    icono: icono ?? this.icono,
    esDefault: esDefault ?? this.esDefault,
  );
  CategoriaFinanzas copyWithCompanion(CategoriasFinanzasCompanion data) {
    return CategoriaFinanzas(
      id: data.id.present ? data.id.value : this.id,
      valor: data.valor.present ? data.valor.value : this.valor,
      label: data.label.present ? data.label.value : this.label,
      icono: data.icono.present ? data.icono.value : this.icono,
      esDefault: data.esDefault.present ? data.esDefault.value : this.esDefault,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriaFinanzas(')
          ..write('id: $id, ')
          ..write('valor: $valor, ')
          ..write('label: $label, ')
          ..write('icono: $icono, ')
          ..write('esDefault: $esDefault')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, valor, label, icono, esDefault);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriaFinanzas &&
          other.id == this.id &&
          other.valor == this.valor &&
          other.label == this.label &&
          other.icono == this.icono &&
          other.esDefault == this.esDefault);
}

class CategoriasFinanzasCompanion extends UpdateCompanion<CategoriaFinanzas> {
  final Value<int> id;
  final Value<String> valor;
  final Value<String> label;
  final Value<String> icono;
  final Value<bool> esDefault;
  const CategoriasFinanzasCompanion({
    this.id = const Value.absent(),
    this.valor = const Value.absent(),
    this.label = const Value.absent(),
    this.icono = const Value.absent(),
    this.esDefault = const Value.absent(),
  });
  CategoriasFinanzasCompanion.insert({
    this.id = const Value.absent(),
    required String valor,
    required String label,
    this.icono = const Value.absent(),
    this.esDefault = const Value.absent(),
  }) : valor = Value(valor),
       label = Value(label);
  static Insertable<CategoriaFinanzas> custom({
    Expression<int>? id,
    Expression<String>? valor,
    Expression<String>? label,
    Expression<String>? icono,
    Expression<bool>? esDefault,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (valor != null) 'valor': valor,
      if (label != null) 'label': label,
      if (icono != null) 'icono': icono,
      if (esDefault != null) 'es_default': esDefault,
    });
  }

  CategoriasFinanzasCompanion copyWith({
    Value<int>? id,
    Value<String>? valor,
    Value<String>? label,
    Value<String>? icono,
    Value<bool>? esDefault,
  }) {
    return CategoriasFinanzasCompanion(
      id: id ?? this.id,
      valor: valor ?? this.valor,
      label: label ?? this.label,
      icono: icono ?? this.icono,
      esDefault: esDefault ?? this.esDefault,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (icono.present) {
      map['icono'] = Variable<String>(icono.value);
    }
    if (esDefault.present) {
      map['es_default'] = Variable<bool>(esDefault.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriasFinanzasCompanion(')
          ..write('id: $id, ')
          ..write('valor: $valor, ')
          ..write('label: $label, ')
          ..write('icono: $icono, ')
          ..write('esDefault: $esDefault')
          ..write(')'))
        .toString();
  }
}

class $AjustesTable extends Ajustes with TableInfo<$AjustesTable, Ajuste> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AjustesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
    'clave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [clave, valor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ajustes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ajuste> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('clave')) {
      context.handle(
        _claveMeta,
        clave.isAcceptableOrUnknown(data['clave']!, _claveMeta),
      );
    } else if (isInserting) {
      context.missing(_claveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clave};
  @override
  Ajuste map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ajuste(
      clave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      )!,
    );
  }

  @override
  $AjustesTable createAlias(String alias) {
    return $AjustesTable(attachedDatabase, alias);
  }
}

class Ajuste extends DataClass implements Insertable<Ajuste> {
  final String clave;
  final String valor;
  const Ajuste({required this.clave, required this.valor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clave'] = Variable<String>(clave);
    map['valor'] = Variable<String>(valor);
    return map;
  }

  AjustesCompanion toCompanion(bool nullToAbsent) {
    return AjustesCompanion(clave: Value(clave), valor: Value(valor));
  }

  factory Ajuste.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ajuste(
      clave: serializer.fromJson<String>(json['clave']),
      valor: serializer.fromJson<String>(json['valor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clave': serializer.toJson<String>(clave),
      'valor': serializer.toJson<String>(valor),
    };
  }

  Ajuste copyWith({String? clave, String? valor}) =>
      Ajuste(clave: clave ?? this.clave, valor: valor ?? this.valor);
  Ajuste copyWithCompanion(AjustesCompanion data) {
    return Ajuste(
      clave: data.clave.present ? data.clave.value : this.clave,
      valor: data.valor.present ? data.valor.value : this.valor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ajuste(')
          ..write('clave: $clave, ')
          ..write('valor: $valor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clave, valor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ajuste &&
          other.clave == this.clave &&
          other.valor == this.valor);
}

class AjustesCompanion extends UpdateCompanion<Ajuste> {
  final Value<String> clave;
  final Value<String> valor;
  final Value<int> rowid;
  const AjustesCompanion({
    this.clave = const Value.absent(),
    this.valor = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AjustesCompanion.insert({
    required String clave,
    required String valor,
    this.rowid = const Value.absent(),
  }) : clave = Value(clave),
       valor = Value(valor);
  static Insertable<Ajuste> custom({
    Expression<String>? clave,
    Expression<String>? valor,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clave != null) 'clave': clave,
      if (valor != null) 'valor': valor,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AjustesCompanion copyWith({
    Value<String>? clave,
    Value<String>? valor,
    Value<int>? rowid,
  }) {
    return AjustesCompanion(
      clave: clave ?? this.clave,
      valor: valor ?? this.valor,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AjustesCompanion(')
          ..write('clave: $clave, ')
          ..write('valor: $valor, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventosTable eventos = $EventosTable(this);
  late final $CumplesTable cumples = $CumplesTable(this);
  late final $CiclosTable ciclos = $CiclosTable(this);
  late final $RegistrosDiaTable registrosDia = $RegistrosDiaTable(this);
  late final $CuentasTable cuentas = $CuentasTable(this);
  late final $TransaccionesTable transacciones = $TransaccionesTable(this);
  late final $TransferenciasTable transferencias = $TransferenciasTable(this);
  late final $IngresosPlanificadosTable ingresosPlanificados =
      $IngresosPlanificadosTable(this);
  late final $VerificacionesTable verificaciones = $VerificacionesTable(this);
  late final $MetasTable metas = $MetasTable(this);
  late final $PresupuestosTable presupuestos = $PresupuestosTable(this);
  late final $CategoriasFinanzasTable categoriasFinanzas =
      $CategoriasFinanzasTable(this);
  late final $AjustesTable ajustes = $AjustesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    eventos,
    cumples,
    ciclos,
    registrosDia,
    cuentas,
    transacciones,
    transferencias,
    ingresosPlanificados,
    verificaciones,
    metas,
    presupuestos,
    categoriasFinanzas,
    ajustes,
  ];
}

typedef $$EventosTableCreateCompanionBuilder =
    EventosCompanion Function({
      Value<int> id,
      required String titulo,
      required String fecha,
      Value<String?> hora,
      Value<String> categoria,
      Value<String> ubicacion,
      Value<String> notas,
      Value<String> frecuencia,
      Value<double> costo,
      Value<String> tipoTransaccion,
      Value<String> estadoPago,
      Value<int?> parentId,
      Value<int?> tarjetaCreditoId,
      Value<int?> transaccionId,
      Value<DateTime> creadoEn,
    });
typedef $$EventosTableUpdateCompanionBuilder =
    EventosCompanion Function({
      Value<int> id,
      Value<String> titulo,
      Value<String> fecha,
      Value<String?> hora,
      Value<String> categoria,
      Value<String> ubicacion,
      Value<String> notas,
      Value<String> frecuencia,
      Value<double> costo,
      Value<String> tipoTransaccion,
      Value<String> estadoPago,
      Value<int?> parentId,
      Value<int?> tarjetaCreditoId,
      Value<int?> transaccionId,
      Value<DateTime> creadoEn,
    });

class $$EventosTableFilterComposer
    extends Composer<_$AppDatabase, $EventosTable> {
  $$EventosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hora => $composableBuilder(
    column: $table.hora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ubicacion => $composableBuilder(
    column: $table.ubicacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costo => $composableBuilder(
    column: $table.costo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoTransaccion => $composableBuilder(
    column: $table.tipoTransaccion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estadoPago => $composableBuilder(
    column: $table.estadoPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tarjetaCreditoId => $composableBuilder(
    column: $table.tarjetaCreditoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventosTableOrderingComposer
    extends Composer<_$AppDatabase, $EventosTable> {
  $$EventosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hora => $composableBuilder(
    column: $table.hora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ubicacion => $composableBuilder(
    column: $table.ubicacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costo => $composableBuilder(
    column: $table.costo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoTransaccion => $composableBuilder(
    column: $table.tipoTransaccion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estadoPago => $composableBuilder(
    column: $table.estadoPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tarjetaCreditoId => $composableBuilder(
    column: $table.tarjetaCreditoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventosTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventosTable> {
  $$EventosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get hora =>
      $composableBuilder(column: $table.hora, builder: (column) => column);

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<String> get ubicacion =>
      $composableBuilder(column: $table.ubicacion, builder: (column) => column);

  GeneratedColumn<String> get notas =>
      $composableBuilder(column: $table.notas, builder: (column) => column);

  GeneratedColumn<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costo =>
      $composableBuilder(column: $table.costo, builder: (column) => column);

  GeneratedColumn<String> get tipoTransaccion => $composableBuilder(
    column: $table.tipoTransaccion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estadoPago => $composableBuilder(
    column: $table.estadoPago,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<int> get tarjetaCreditoId => $composableBuilder(
    column: $table.tarjetaCreditoId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);
}

class $$EventosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventosTable,
          Evento,
          $$EventosTableFilterComposer,
          $$EventosTableOrderingComposer,
          $$EventosTableAnnotationComposer,
          $$EventosTableCreateCompanionBuilder,
          $$EventosTableUpdateCompanionBuilder,
          (Evento, BaseReferences<_$AppDatabase, $EventosTable, Evento>),
          Evento,
          PrefetchHooks Function()
        > {
  $$EventosTableTableManager(_$AppDatabase db, $EventosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<String?> hora = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<String> ubicacion = const Value.absent(),
                Value<String> notas = const Value.absent(),
                Value<String> frecuencia = const Value.absent(),
                Value<double> costo = const Value.absent(),
                Value<String> tipoTransaccion = const Value.absent(),
                Value<String> estadoPago = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int?> tarjetaCreditoId = const Value.absent(),
                Value<int?> transaccionId = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => EventosCompanion(
                id: id,
                titulo: titulo,
                fecha: fecha,
                hora: hora,
                categoria: categoria,
                ubicacion: ubicacion,
                notas: notas,
                frecuencia: frecuencia,
                costo: costo,
                tipoTransaccion: tipoTransaccion,
                estadoPago: estadoPago,
                parentId: parentId,
                tarjetaCreditoId: tarjetaCreditoId,
                transaccionId: transaccionId,
                creadoEn: creadoEn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String titulo,
                required String fecha,
                Value<String?> hora = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<String> ubicacion = const Value.absent(),
                Value<String> notas = const Value.absent(),
                Value<String> frecuencia = const Value.absent(),
                Value<double> costo = const Value.absent(),
                Value<String> tipoTransaccion = const Value.absent(),
                Value<String> estadoPago = const Value.absent(),
                Value<int?> parentId = const Value.absent(),
                Value<int?> tarjetaCreditoId = const Value.absent(),
                Value<int?> transaccionId = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => EventosCompanion.insert(
                id: id,
                titulo: titulo,
                fecha: fecha,
                hora: hora,
                categoria: categoria,
                ubicacion: ubicacion,
                notas: notas,
                frecuencia: frecuencia,
                costo: costo,
                tipoTransaccion: tipoTransaccion,
                estadoPago: estadoPago,
                parentId: parentId,
                tarjetaCreditoId: tarjetaCreditoId,
                transaccionId: transaccionId,
                creadoEn: creadoEn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventosTable, Evento>(table),
                  BaseReferences<_$AppDatabase, $EventosTable, Evento>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventosTable,
      Evento,
      $$EventosTableFilterComposer,
      $$EventosTableOrderingComposer,
      $$EventosTableAnnotationComposer,
      $$EventosTableCreateCompanionBuilder,
      $$EventosTableUpdateCompanionBuilder,
      (Evento, BaseReferences<_$AppDatabase, $EventosTable, Evento>),
      Evento,
      PrefetchHooks Function()
    >;
typedef $$CumplesTableCreateCompanionBuilder =
    CumplesCompanion Function({
      Value<int> id,
      required String nombre,
      required String fecha,
      Value<int?> anioNacimiento,
      Value<String> telefono,
      Value<String> mensaje,
    });
typedef $$CumplesTableUpdateCompanionBuilder =
    CumplesCompanion Function({
      Value<int> id,
      Value<String> nombre,
      Value<String> fecha,
      Value<int?> anioNacimiento,
      Value<String> telefono,
      Value<String> mensaje,
    });

class $$CumplesTableFilterComposer
    extends Composer<_$AppDatabase, $CumplesTable> {
  $$CumplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anioNacimiento => $composableBuilder(
    column: $table.anioNacimiento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mensaje => $composableBuilder(
    column: $table.mensaje,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CumplesTableOrderingComposer
    extends Composer<_$AppDatabase, $CumplesTable> {
  $$CumplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anioNacimiento => $composableBuilder(
    column: $table.anioNacimiento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telefono => $composableBuilder(
    column: $table.telefono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mensaje => $composableBuilder(
    column: $table.mensaje,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CumplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CumplesTable> {
  $$CumplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<int> get anioNacimiento => $composableBuilder(
    column: $table.anioNacimiento,
    builder: (column) => column,
  );

  GeneratedColumn<String> get telefono =>
      $composableBuilder(column: $table.telefono, builder: (column) => column);

  GeneratedColumn<String> get mensaje =>
      $composableBuilder(column: $table.mensaje, builder: (column) => column);
}

class $$CumplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CumplesTable,
          Cumple,
          $$CumplesTableFilterComposer,
          $$CumplesTableOrderingComposer,
          $$CumplesTableAnnotationComposer,
          $$CumplesTableCreateCompanionBuilder,
          $$CumplesTableUpdateCompanionBuilder,
          (Cumple, BaseReferences<_$AppDatabase, $CumplesTable, Cumple>),
          Cumple,
          PrefetchHooks Function()
        > {
  $$CumplesTableTableManager(_$AppDatabase db, $CumplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CumplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CumplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CumplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<int?> anioNacimiento = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<String> mensaje = const Value.absent(),
              }) => CumplesCompanion(
                id: id,
                nombre: nombre,
                fecha: fecha,
                anioNacimiento: anioNacimiento,
                telefono: telefono,
                mensaje: mensaje,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nombre,
                required String fecha,
                Value<int?> anioNacimiento = const Value.absent(),
                Value<String> telefono = const Value.absent(),
                Value<String> mensaje = const Value.absent(),
              }) => CumplesCompanion.insert(
                id: id,
                nombre: nombre,
                fecha: fecha,
                anioNacimiento: anioNacimiento,
                telefono: telefono,
                mensaje: mensaje,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CumplesTable, Cumple>(table),
                  BaseReferences<_$AppDatabase, $CumplesTable, Cumple>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CumplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CumplesTable,
      Cumple,
      $$CumplesTableFilterComposer,
      $$CumplesTableOrderingComposer,
      $$CumplesTableAnnotationComposer,
      $$CumplesTableCreateCompanionBuilder,
      $$CumplesTableUpdateCompanionBuilder,
      (Cumple, BaseReferences<_$AppDatabase, $CumplesTable, Cumple>),
      Cumple,
      PrefetchHooks Function()
    >;
typedef $$CiclosTableCreateCompanionBuilder =
    CiclosCompanion Function({
      Value<int> id,
      required String fechaInicio,
      Value<String> observacion,
      Value<int?> diasSangrado,
    });
typedef $$CiclosTableUpdateCompanionBuilder =
    CiclosCompanion Function({
      Value<int> id,
      Value<String> fechaInicio,
      Value<String> observacion,
      Value<int?> diasSangrado,
    });

class $$CiclosTableFilterComposer
    extends Composer<_$AppDatabase, $CiclosTable> {
  $$CiclosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observacion => $composableBuilder(
    column: $table.observacion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasSangrado => $composableBuilder(
    column: $table.diasSangrado,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CiclosTableOrderingComposer
    extends Composer<_$AppDatabase, $CiclosTable> {
  $$CiclosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observacion => $composableBuilder(
    column: $table.observacion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasSangrado => $composableBuilder(
    column: $table.diasSangrado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CiclosTableAnnotationComposer
    extends Composer<_$AppDatabase, $CiclosTable> {
  $$CiclosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get observacion => $composableBuilder(
    column: $table.observacion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diasSangrado => $composableBuilder(
    column: $table.diasSangrado,
    builder: (column) => column,
  );
}

class $$CiclosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CiclosTable,
          Ciclo,
          $$CiclosTableFilterComposer,
          $$CiclosTableOrderingComposer,
          $$CiclosTableAnnotationComposer,
          $$CiclosTableCreateCompanionBuilder,
          $$CiclosTableUpdateCompanionBuilder,
          (Ciclo, BaseReferences<_$AppDatabase, $CiclosTable, Ciclo>),
          Ciclo,
          PrefetchHooks Function()
        > {
  $$CiclosTableTableManager(_$AppDatabase db, $CiclosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CiclosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CiclosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CiclosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fechaInicio = const Value.absent(),
                Value<String> observacion = const Value.absent(),
                Value<int?> diasSangrado = const Value.absent(),
              }) => CiclosCompanion(
                id: id,
                fechaInicio: fechaInicio,
                observacion: observacion,
                diasSangrado: diasSangrado,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fechaInicio,
                Value<String> observacion = const Value.absent(),
                Value<int?> diasSangrado = const Value.absent(),
              }) => CiclosCompanion.insert(
                id: id,
                fechaInicio: fechaInicio,
                observacion: observacion,
                diasSangrado: diasSangrado,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CiclosTable, Ciclo>(table),
                  BaseReferences<_$AppDatabase, $CiclosTable, Ciclo>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CiclosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CiclosTable,
      Ciclo,
      $$CiclosTableFilterComposer,
      $$CiclosTableOrderingComposer,
      $$CiclosTableAnnotationComposer,
      $$CiclosTableCreateCompanionBuilder,
      $$CiclosTableUpdateCompanionBuilder,
      (Ciclo, BaseReferences<_$AppDatabase, $CiclosTable, Ciclo>),
      Ciclo,
      PrefetchHooks Function()
    >;
typedef $$RegistrosDiaTableCreateCompanionBuilder =
    RegistrosDiaCompanion Function({
      Value<int> id,
      required String fecha,
      Value<int> flujo,
      Value<String?> animo,
      Value<String> sintomas,
      Value<String> nota,
    });
typedef $$RegistrosDiaTableUpdateCompanionBuilder =
    RegistrosDiaCompanion Function({
      Value<int> id,
      Value<String> fecha,
      Value<int> flujo,
      Value<String?> animo,
      Value<String> sintomas,
      Value<String> nota,
    });

class $$RegistrosDiaTableFilterComposer
    extends Composer<_$AppDatabase, $RegistrosDiaTable> {
  $$RegistrosDiaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get flujo => $composableBuilder(
    column: $table.flujo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get animo => $composableBuilder(
    column: $table.animo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sintomas => $composableBuilder(
    column: $table.sintomas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RegistrosDiaTableOrderingComposer
    extends Composer<_$AppDatabase, $RegistrosDiaTable> {
  $$RegistrosDiaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get flujo => $composableBuilder(
    column: $table.flujo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get animo => $composableBuilder(
    column: $table.animo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sintomas => $composableBuilder(
    column: $table.sintomas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nota => $composableBuilder(
    column: $table.nota,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RegistrosDiaTableAnnotationComposer
    extends Composer<_$AppDatabase, $RegistrosDiaTable> {
  $$RegistrosDiaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<int> get flujo =>
      $composableBuilder(column: $table.flujo, builder: (column) => column);

  GeneratedColumn<String> get animo =>
      $composableBuilder(column: $table.animo, builder: (column) => column);

  GeneratedColumn<String> get sintomas =>
      $composableBuilder(column: $table.sintomas, builder: (column) => column);

  GeneratedColumn<String> get nota =>
      $composableBuilder(column: $table.nota, builder: (column) => column);
}

class $$RegistrosDiaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RegistrosDiaTable,
          RegistroDia,
          $$RegistrosDiaTableFilterComposer,
          $$RegistrosDiaTableOrderingComposer,
          $$RegistrosDiaTableAnnotationComposer,
          $$RegistrosDiaTableCreateCompanionBuilder,
          $$RegistrosDiaTableUpdateCompanionBuilder,
          (
            RegistroDia,
            BaseReferences<_$AppDatabase, $RegistrosDiaTable, RegistroDia>,
          ),
          RegistroDia,
          PrefetchHooks Function()
        > {
  $$RegistrosDiaTableTableManager(_$AppDatabase db, $RegistrosDiaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RegistrosDiaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RegistrosDiaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RegistrosDiaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<int> flujo = const Value.absent(),
                Value<String?> animo = const Value.absent(),
                Value<String> sintomas = const Value.absent(),
                Value<String> nota = const Value.absent(),
              }) => RegistrosDiaCompanion(
                id: id,
                fecha: fecha,
                flujo: flujo,
                animo: animo,
                sintomas: sintomas,
                nota: nota,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fecha,
                Value<int> flujo = const Value.absent(),
                Value<String?> animo = const Value.absent(),
                Value<String> sintomas = const Value.absent(),
                Value<String> nota = const Value.absent(),
              }) => RegistrosDiaCompanion.insert(
                id: id,
                fecha: fecha,
                flujo: flujo,
                animo: animo,
                sintomas: sintomas,
                nota: nota,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RegistrosDiaTable, RegistroDia>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RegistrosDiaTable,
                    RegistroDia
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RegistrosDiaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RegistrosDiaTable,
      RegistroDia,
      $$RegistrosDiaTableFilterComposer,
      $$RegistrosDiaTableOrderingComposer,
      $$RegistrosDiaTableAnnotationComposer,
      $$RegistrosDiaTableCreateCompanionBuilder,
      $$RegistrosDiaTableUpdateCompanionBuilder,
      (
        RegistroDia,
        BaseReferences<_$AppDatabase, $RegistrosDiaTable, RegistroDia>,
      ),
      RegistroDia,
      PrefetchHooks Function()
    >;
typedef $$CuentasTableCreateCompanionBuilder =
    CuentasCompanion Function({
      Value<int> id,
      required String nombre,
      required String tipo,
      Value<double> saldo,
      Value<double> limite,
      Value<double> interesTasa,
      Value<String?> fechaInicio,
      Value<int> plazoDias,
      Value<int?> diaCorte,
      Value<DateTime> creadoEn,
    });
typedef $$CuentasTableUpdateCompanionBuilder =
    CuentasCompanion Function({
      Value<int> id,
      Value<String> nombre,
      Value<String> tipo,
      Value<double> saldo,
      Value<double> limite,
      Value<double> interesTasa,
      Value<String?> fechaInicio,
      Value<int> plazoDias,
      Value<int?> diaCorte,
      Value<DateTime> creadoEn,
    });

class $$CuentasTableFilterComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saldo => $composableBuilder(
    column: $table.saldo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limite => $composableBuilder(
    column: $table.limite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get interesTasa => $composableBuilder(
    column: $table.interesTasa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plazoDias => $composableBuilder(
    column: $table.plazoDias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaCorte => $composableBuilder(
    column: $table.diaCorte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CuentasTableOrderingComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saldo => $composableBuilder(
    column: $table.saldo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limite => $composableBuilder(
    column: $table.limite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get interesTasa => $composableBuilder(
    column: $table.interesTasa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plazoDias => $composableBuilder(
    column: $table.plazoDias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaCorte => $composableBuilder(
    column: $table.diaCorte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CuentasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<double> get saldo =>
      $composableBuilder(column: $table.saldo, builder: (column) => column);

  GeneratedColumn<double> get limite =>
      $composableBuilder(column: $table.limite, builder: (column) => column);

  GeneratedColumn<double> get interesTasa => $composableBuilder(
    column: $table.interesTasa,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plazoDias =>
      $composableBuilder(column: $table.plazoDias, builder: (column) => column);

  GeneratedColumn<int> get diaCorte =>
      $composableBuilder(column: $table.diaCorte, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);
}

class $$CuentasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuentasTable,
          Cuenta,
          $$CuentasTableFilterComposer,
          $$CuentasTableOrderingComposer,
          $$CuentasTableAnnotationComposer,
          $$CuentasTableCreateCompanionBuilder,
          $$CuentasTableUpdateCompanionBuilder,
          (Cuenta, BaseReferences<_$AppDatabase, $CuentasTable, Cuenta>),
          Cuenta,
          PrefetchHooks Function()
        > {
  $$CuentasTableTableManager(_$AppDatabase db, $CuentasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuentasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuentasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CuentasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<double> saldo = const Value.absent(),
                Value<double> limite = const Value.absent(),
                Value<double> interesTasa = const Value.absent(),
                Value<String?> fechaInicio = const Value.absent(),
                Value<int> plazoDias = const Value.absent(),
                Value<int?> diaCorte = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => CuentasCompanion(
                id: id,
                nombre: nombre,
                tipo: tipo,
                saldo: saldo,
                limite: limite,
                interesTasa: interesTasa,
                fechaInicio: fechaInicio,
                plazoDias: plazoDias,
                diaCorte: diaCorte,
                creadoEn: creadoEn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nombre,
                required String tipo,
                Value<double> saldo = const Value.absent(),
                Value<double> limite = const Value.absent(),
                Value<double> interesTasa = const Value.absent(),
                Value<String?> fechaInicio = const Value.absent(),
                Value<int> plazoDias = const Value.absent(),
                Value<int?> diaCorte = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => CuentasCompanion.insert(
                id: id,
                nombre: nombre,
                tipo: tipo,
                saldo: saldo,
                limite: limite,
                interesTasa: interesTasa,
                fechaInicio: fechaInicio,
                plazoDias: plazoDias,
                diaCorte: diaCorte,
                creadoEn: creadoEn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CuentasTable, Cuenta>(table),
                  BaseReferences<_$AppDatabase, $CuentasTable, Cuenta>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CuentasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuentasTable,
      Cuenta,
      $$CuentasTableFilterComposer,
      $$CuentasTableOrderingComposer,
      $$CuentasTableAnnotationComposer,
      $$CuentasTableCreateCompanionBuilder,
      $$CuentasTableUpdateCompanionBuilder,
      (Cuenta, BaseReferences<_$AppDatabase, $CuentasTable, Cuenta>),
      Cuenta,
      PrefetchHooks Function()
    >;
typedef $$TransaccionesTableCreateCompanionBuilder =
    TransaccionesCompanion Function({
      Value<int> id,
      Value<int?> cuentaId,
      required String tipo,
      required double monto,
      required String descripcion,
      required String fecha,
      Value<String> categoria,
      Value<int> cuotas,
      Value<int?> ingresoPlanificadoId,
      Value<int?> metaId,
      Value<DateTime> creadoEn,
    });
typedef $$TransaccionesTableUpdateCompanionBuilder =
    TransaccionesCompanion Function({
      Value<int> id,
      Value<int?> cuentaId,
      Value<String> tipo,
      Value<double> monto,
      Value<String> descripcion,
      Value<String> fecha,
      Value<String> categoria,
      Value<int> cuotas,
      Value<int?> ingresoPlanificadoId,
      Value<int?> metaId,
      Value<DateTime> creadoEn,
    });

class $$TransaccionesTableFilterComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cuotas => $composableBuilder(
    column: $table.cuotas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransaccionesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cuotas => $composableBuilder(
    column: $table.cuotas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metaId => $composableBuilder(
    column: $table.metaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransaccionesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cuentaId =>
      $composableBuilder(column: $table.cuentaId, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get cuotas =>
      $composableBuilder(column: $table.cuotas, builder: (column) => column);

  GeneratedColumn<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get metaId =>
      $composableBuilder(column: $table.metaId, builder: (column) => column);

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);
}

class $$TransaccionesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransaccionesTable,
          Transaccion,
          $$TransaccionesTableFilterComposer,
          $$TransaccionesTableOrderingComposer,
          $$TransaccionesTableAnnotationComposer,
          $$TransaccionesTableCreateCompanionBuilder,
          $$TransaccionesTableUpdateCompanionBuilder,
          (
            Transaccion,
            BaseReferences<_$AppDatabase, $TransaccionesTable, Transaccion>,
          ),
          Transaccion,
          PrefetchHooks Function()
        > {
  $$TransaccionesTableTableManager(_$AppDatabase db, $TransaccionesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransaccionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransaccionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransaccionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cuentaId = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<double> monto = const Value.absent(),
                Value<String> descripcion = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<int> cuotas = const Value.absent(),
                Value<int?> ingresoPlanificadoId = const Value.absent(),
                Value<int?> metaId = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => TransaccionesCompanion(
                id: id,
                cuentaId: cuentaId,
                tipo: tipo,
                monto: monto,
                descripcion: descripcion,
                fecha: fecha,
                categoria: categoria,
                cuotas: cuotas,
                ingresoPlanificadoId: ingresoPlanificadoId,
                metaId: metaId,
                creadoEn: creadoEn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cuentaId = const Value.absent(),
                required String tipo,
                required double monto,
                required String descripcion,
                required String fecha,
                Value<String> categoria = const Value.absent(),
                Value<int> cuotas = const Value.absent(),
                Value<int?> ingresoPlanificadoId = const Value.absent(),
                Value<int?> metaId = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => TransaccionesCompanion.insert(
                id: id,
                cuentaId: cuentaId,
                tipo: tipo,
                monto: monto,
                descripcion: descripcion,
                fecha: fecha,
                categoria: categoria,
                cuotas: cuotas,
                ingresoPlanificadoId: ingresoPlanificadoId,
                metaId: metaId,
                creadoEn: creadoEn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransaccionesTable, Transaccion>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TransaccionesTable,
                    Transaccion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransaccionesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransaccionesTable,
      Transaccion,
      $$TransaccionesTableFilterComposer,
      $$TransaccionesTableOrderingComposer,
      $$TransaccionesTableAnnotationComposer,
      $$TransaccionesTableCreateCompanionBuilder,
      $$TransaccionesTableUpdateCompanionBuilder,
      (
        Transaccion,
        BaseReferences<_$AppDatabase, $TransaccionesTable, Transaccion>,
      ),
      Transaccion,
      PrefetchHooks Function()
    >;
typedef $$TransferenciasTableCreateCompanionBuilder =
    TransferenciasCompanion Function({
      Value<int> id,
      required int cuentaOrigenId,
      required int cuentaDestinoId,
      required double monto,
      Value<String> descripcion,
      required String fecha,
    });
typedef $$TransferenciasTableUpdateCompanionBuilder =
    TransferenciasCompanion Function({
      Value<int> id,
      Value<int> cuentaOrigenId,
      Value<int> cuentaDestinoId,
      Value<double> monto,
      Value<String> descripcion,
      Value<String> fecha,
    });

class $$TransferenciasTableFilterComposer
    extends Composer<_$AppDatabase, $TransferenciasTable> {
  $$TransferenciasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cuentaOrigenId => $composableBuilder(
    column: $table.cuentaOrigenId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cuentaDestinoId => $composableBuilder(
    column: $table.cuentaDestinoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransferenciasTableOrderingComposer
    extends Composer<_$AppDatabase, $TransferenciasTable> {
  $$TransferenciasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cuentaOrigenId => $composableBuilder(
    column: $table.cuentaOrigenId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cuentaDestinoId => $composableBuilder(
    column: $table.cuentaDestinoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransferenciasTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransferenciasTable> {
  $$TransferenciasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cuentaOrigenId => $composableBuilder(
    column: $table.cuentaOrigenId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cuentaDestinoId => $composableBuilder(
    column: $table.cuentaDestinoId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);
}

class $$TransferenciasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransferenciasTable,
          Transferencia,
          $$TransferenciasTableFilterComposer,
          $$TransferenciasTableOrderingComposer,
          $$TransferenciasTableAnnotationComposer,
          $$TransferenciasTableCreateCompanionBuilder,
          $$TransferenciasTableUpdateCompanionBuilder,
          (
            Transferencia,
            BaseReferences<_$AppDatabase, $TransferenciasTable, Transferencia>,
          ),
          Transferencia,
          PrefetchHooks Function()
        > {
  $$TransferenciasTableTableManager(
    _$AppDatabase db,
    $TransferenciasTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransferenciasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransferenciasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransferenciasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cuentaOrigenId = const Value.absent(),
                Value<int> cuentaDestinoId = const Value.absent(),
                Value<double> monto = const Value.absent(),
                Value<String> descripcion = const Value.absent(),
                Value<String> fecha = const Value.absent(),
              }) => TransferenciasCompanion(
                id: id,
                cuentaOrigenId: cuentaOrigenId,
                cuentaDestinoId: cuentaDestinoId,
                monto: monto,
                descripcion: descripcion,
                fecha: fecha,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cuentaOrigenId,
                required int cuentaDestinoId,
                required double monto,
                Value<String> descripcion = const Value.absent(),
                required String fecha,
              }) => TransferenciasCompanion.insert(
                id: id,
                cuentaOrigenId: cuentaOrigenId,
                cuentaDestinoId: cuentaDestinoId,
                monto: monto,
                descripcion: descripcion,
                fecha: fecha,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TransferenciasTable, Transferencia>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $TransferenciasTable,
                    Transferencia
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransferenciasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransferenciasTable,
      Transferencia,
      $$TransferenciasTableFilterComposer,
      $$TransferenciasTableOrderingComposer,
      $$TransferenciasTableAnnotationComposer,
      $$TransferenciasTableCreateCompanionBuilder,
      $$TransferenciasTableUpdateCompanionBuilder,
      (
        Transferencia,
        BaseReferences<_$AppDatabase, $TransferenciasTable, Transferencia>,
      ),
      Transferencia,
      PrefetchHooks Function()
    >;
typedef $$IngresosPlanificadosTableCreateCompanionBuilder =
    IngresosPlanificadosCompanion Function({
      Value<int> id,
      Value<int?> cuentaId,
      required String descripcion,
      required double monto,
      required String frecuencia,
      required String fechaInicio,
      Value<bool> activo,
    });
typedef $$IngresosPlanificadosTableUpdateCompanionBuilder =
    IngresosPlanificadosCompanion Function({
      Value<int> id,
      Value<int?> cuentaId,
      Value<String> descripcion,
      Value<double> monto,
      Value<String> frecuencia,
      Value<String> fechaInicio,
      Value<bool> activo,
    });

class $$IngresosPlanificadosTableFilterComposer
    extends Composer<_$AppDatabase, $IngresosPlanificadosTable> {
  $$IngresosPlanificadosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get activo => $composableBuilder(
    column: $table.activo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IngresosPlanificadosTableOrderingComposer
    extends Composer<_$AppDatabase, $IngresosPlanificadosTable> {
  $$IngresosPlanificadosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get activo => $composableBuilder(
    column: $table.activo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IngresosPlanificadosTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngresosPlanificadosTable> {
  $$IngresosPlanificadosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get cuentaId =>
      $composableBuilder(column: $table.cuentaId, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get frecuencia => $composableBuilder(
    column: $table.frecuencia,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get activo =>
      $composableBuilder(column: $table.activo, builder: (column) => column);
}

class $$IngresosPlanificadosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngresosPlanificadosTable,
          IngresoPlanificado,
          $$IngresosPlanificadosTableFilterComposer,
          $$IngresosPlanificadosTableOrderingComposer,
          $$IngresosPlanificadosTableAnnotationComposer,
          $$IngresosPlanificadosTableCreateCompanionBuilder,
          $$IngresosPlanificadosTableUpdateCompanionBuilder,
          (
            IngresoPlanificado,
            BaseReferences<
              _$AppDatabase,
              $IngresosPlanificadosTable,
              IngresoPlanificado
            >,
          ),
          IngresoPlanificado,
          PrefetchHooks Function()
        > {
  $$IngresosPlanificadosTableTableManager(
    _$AppDatabase db,
    $IngresosPlanificadosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngresosPlanificadosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngresosPlanificadosTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$IngresosPlanificadosTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cuentaId = const Value.absent(),
                Value<String> descripcion = const Value.absent(),
                Value<double> monto = const Value.absent(),
                Value<String> frecuencia = const Value.absent(),
                Value<String> fechaInicio = const Value.absent(),
                Value<bool> activo = const Value.absent(),
              }) => IngresosPlanificadosCompanion(
                id: id,
                cuentaId: cuentaId,
                descripcion: descripcion,
                monto: monto,
                frecuencia: frecuencia,
                fechaInicio: fechaInicio,
                activo: activo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> cuentaId = const Value.absent(),
                required String descripcion,
                required double monto,
                required String frecuencia,
                required String fechaInicio,
                Value<bool> activo = const Value.absent(),
              }) => IngresosPlanificadosCompanion.insert(
                id: id,
                cuentaId: cuentaId,
                descripcion: descripcion,
                monto: monto,
                frecuencia: frecuencia,
                fechaInicio: fechaInicio,
                activo: activo,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IngresosPlanificadosTable, IngresoPlanificado>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $IngresosPlanificadosTable,
                    IngresoPlanificado
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IngresosPlanificadosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngresosPlanificadosTable,
      IngresoPlanificado,
      $$IngresosPlanificadosTableFilterComposer,
      $$IngresosPlanificadosTableOrderingComposer,
      $$IngresosPlanificadosTableAnnotationComposer,
      $$IngresosPlanificadosTableCreateCompanionBuilder,
      $$IngresosPlanificadosTableUpdateCompanionBuilder,
      (
        IngresoPlanificado,
        BaseReferences<
          _$AppDatabase,
          $IngresosPlanificadosTable,
          IngresoPlanificado
        >,
      ),
      IngresoPlanificado,
      PrefetchHooks Function()
    >;
typedef $$VerificacionesTableCreateCompanionBuilder =
    VerificacionesCompanion Function({
      Value<int> id,
      required int ingresoPlanificadoId,
      required String fechaEsperada,
      required String fechaReal,
      required double montoReal,
      Value<int?> transaccionId,
    });
typedef $$VerificacionesTableUpdateCompanionBuilder =
    VerificacionesCompanion Function({
      Value<int> id,
      Value<int> ingresoPlanificadoId,
      Value<String> fechaEsperada,
      Value<String> fechaReal,
      Value<double> montoReal,
      Value<int?> transaccionId,
    });

class $$VerificacionesTableFilterComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaReal => $composableBuilder(
    column: $table.fechaReal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoReal => $composableBuilder(
    column: $table.montoReal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VerificacionesTableOrderingComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaReal => $composableBuilder(
    column: $table.fechaReal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoReal => $composableBuilder(
    column: $table.montoReal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VerificacionesTableAnnotationComposer
    extends Composer<_$AppDatabase, $VerificacionesTable> {
  $$VerificacionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get ingresoPlanificadoId => $composableBuilder(
    column: $table.ingresoPlanificadoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fechaEsperada => $composableBuilder(
    column: $table.fechaEsperada,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fechaReal =>
      $composableBuilder(column: $table.fechaReal, builder: (column) => column);

  GeneratedColumn<double> get montoReal =>
      $composableBuilder(column: $table.montoReal, builder: (column) => column);

  GeneratedColumn<int> get transaccionId => $composableBuilder(
    column: $table.transaccionId,
    builder: (column) => column,
  );
}

class $$VerificacionesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VerificacionesTable,
          Verificacion,
          $$VerificacionesTableFilterComposer,
          $$VerificacionesTableOrderingComposer,
          $$VerificacionesTableAnnotationComposer,
          $$VerificacionesTableCreateCompanionBuilder,
          $$VerificacionesTableUpdateCompanionBuilder,
          (
            Verificacion,
            BaseReferences<_$AppDatabase, $VerificacionesTable, Verificacion>,
          ),
          Verificacion,
          PrefetchHooks Function()
        > {
  $$VerificacionesTableTableManager(
    _$AppDatabase db,
    $VerificacionesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VerificacionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VerificacionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VerificacionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> ingresoPlanificadoId = const Value.absent(),
                Value<String> fechaEsperada = const Value.absent(),
                Value<String> fechaReal = const Value.absent(),
                Value<double> montoReal = const Value.absent(),
                Value<int?> transaccionId = const Value.absent(),
              }) => VerificacionesCompanion(
                id: id,
                ingresoPlanificadoId: ingresoPlanificadoId,
                fechaEsperada: fechaEsperada,
                fechaReal: fechaReal,
                montoReal: montoReal,
                transaccionId: transaccionId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int ingresoPlanificadoId,
                required String fechaEsperada,
                required String fechaReal,
                required double montoReal,
                Value<int?> transaccionId = const Value.absent(),
              }) => VerificacionesCompanion.insert(
                id: id,
                ingresoPlanificadoId: ingresoPlanificadoId,
                fechaEsperada: fechaEsperada,
                fechaReal: fechaReal,
                montoReal: montoReal,
                transaccionId: transaccionId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VerificacionesTable, Verificacion>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $VerificacionesTable,
                    Verificacion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VerificacionesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VerificacionesTable,
      Verificacion,
      $$VerificacionesTableFilterComposer,
      $$VerificacionesTableOrderingComposer,
      $$VerificacionesTableAnnotationComposer,
      $$VerificacionesTableCreateCompanionBuilder,
      $$VerificacionesTableUpdateCompanionBuilder,
      (
        Verificacion,
        BaseReferences<_$AppDatabase, $VerificacionesTable, Verificacion>,
      ),
      Verificacion,
      PrefetchHooks Function()
    >;
typedef $$MetasTableCreateCompanionBuilder =
    MetasCompanion Function({
      Value<int> id,
      required String nombre,
      Value<String> descripcion,
      required double montoObjetivo,
      Value<double> montoActual,
      Value<String?> fechaObjetivo,
      Value<String> icono,
      Value<int> color,
      Value<bool> completada,
      Value<DateTime> creadoEn,
    });
typedef $$MetasTableUpdateCompanionBuilder =
    MetasCompanion Function({
      Value<int> id,
      Value<String> nombre,
      Value<String> descripcion,
      Value<double> montoObjetivo,
      Value<double> montoActual,
      Value<String?> fechaObjetivo,
      Value<String> icono,
      Value<int> color,
      Value<bool> completada,
      Value<DateTime> creadoEn,
    });

class $$MetasTableFilterComposer extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoObjetivo => $composableBuilder(
    column: $table.montoObjetivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoActual => $composableBuilder(
    column: $table.montoActual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fechaObjetivo => $composableBuilder(
    column: $table.fechaObjetivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icono => $composableBuilder(
    column: $table.icono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completada => $composableBuilder(
    column: $table.completada,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetasTableOrderingComposer
    extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoObjetivo => $composableBuilder(
    column: $table.montoObjetivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoActual => $composableBuilder(
    column: $table.montoActual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fechaObjetivo => $composableBuilder(
    column: $table.fechaObjetivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icono => $composableBuilder(
    column: $table.icono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completada => $composableBuilder(
    column: $table.completada,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetasTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoObjetivo => $composableBuilder(
    column: $table.montoObjetivo,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoActual => $composableBuilder(
    column: $table.montoActual,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fechaObjetivo => $composableBuilder(
    column: $table.fechaObjetivo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icono =>
      $composableBuilder(column: $table.icono, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get completada => $composableBuilder(
    column: $table.completada,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);
}

class $$MetasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetasTable,
          Meta,
          $$MetasTableFilterComposer,
          $$MetasTableOrderingComposer,
          $$MetasTableAnnotationComposer,
          $$MetasTableCreateCompanionBuilder,
          $$MetasTableUpdateCompanionBuilder,
          (Meta, BaseReferences<_$AppDatabase, $MetasTable, Meta>),
          Meta,
          PrefetchHooks Function()
        > {
  $$MetasTableTableManager(_$AppDatabase db, $MetasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> descripcion = const Value.absent(),
                Value<double> montoObjetivo = const Value.absent(),
                Value<double> montoActual = const Value.absent(),
                Value<String?> fechaObjetivo = const Value.absent(),
                Value<String> icono = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<bool> completada = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => MetasCompanion(
                id: id,
                nombre: nombre,
                descripcion: descripcion,
                montoObjetivo: montoObjetivo,
                montoActual: montoActual,
                fechaObjetivo: fechaObjetivo,
                icono: icono,
                color: color,
                completada: completada,
                creadoEn: creadoEn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String nombre,
                Value<String> descripcion = const Value.absent(),
                required double montoObjetivo,
                Value<double> montoActual = const Value.absent(),
                Value<String?> fechaObjetivo = const Value.absent(),
                Value<String> icono = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<bool> completada = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => MetasCompanion.insert(
                id: id,
                nombre: nombre,
                descripcion: descripcion,
                montoObjetivo: montoObjetivo,
                montoActual: montoActual,
                fechaObjetivo: fechaObjetivo,
                icono: icono,
                color: color,
                completada: completada,
                creadoEn: creadoEn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetasTable, Meta>(table),
                  BaseReferences<_$AppDatabase, $MetasTable, Meta>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetasTable,
      Meta,
      $$MetasTableFilterComposer,
      $$MetasTableOrderingComposer,
      $$MetasTableAnnotationComposer,
      $$MetasTableCreateCompanionBuilder,
      $$MetasTableUpdateCompanionBuilder,
      (Meta, BaseReferences<_$AppDatabase, $MetasTable, Meta>),
      Meta,
      PrefetchHooks Function()
    >;
typedef $$PresupuestosTableCreateCompanionBuilder =
    PresupuestosCompanion Function({
      Value<int> id,
      required String categoria,
      required double montoLimite,
      required int mes,
      required int anio,
    });
typedef $$PresupuestosTableUpdateCompanionBuilder =
    PresupuestosCompanion Function({
      Value<int> id,
      Value<String> categoria,
      Value<double> montoLimite,
      Value<int> mes,
      Value<int> anio,
    });

class $$PresupuestosTableFilterComposer
    extends Composer<_$AppDatabase, $PresupuestosTable> {
  $$PresupuestosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoLimite => $composableBuilder(
    column: $table.montoLimite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mes => $composableBuilder(
    column: $table.mes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get anio => $composableBuilder(
    column: $table.anio,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PresupuestosTableOrderingComposer
    extends Composer<_$AppDatabase, $PresupuestosTable> {
  $$PresupuestosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoLimite => $composableBuilder(
    column: $table.montoLimite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mes => $composableBuilder(
    column: $table.mes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get anio => $composableBuilder(
    column: $table.anio,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PresupuestosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresupuestosTable> {
  $$PresupuestosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<double> get montoLimite => $composableBuilder(
    column: $table.montoLimite,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mes =>
      $composableBuilder(column: $table.mes, builder: (column) => column);

  GeneratedColumn<int> get anio =>
      $composableBuilder(column: $table.anio, builder: (column) => column);
}

class $$PresupuestosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PresupuestosTable,
          Presupuesto,
          $$PresupuestosTableFilterComposer,
          $$PresupuestosTableOrderingComposer,
          $$PresupuestosTableAnnotationComposer,
          $$PresupuestosTableCreateCompanionBuilder,
          $$PresupuestosTableUpdateCompanionBuilder,
          (
            Presupuesto,
            BaseReferences<_$AppDatabase, $PresupuestosTable, Presupuesto>,
          ),
          Presupuesto,
          PrefetchHooks Function()
        > {
  $$PresupuestosTableTableManager(_$AppDatabase db, $PresupuestosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresupuestosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresupuestosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresupuestosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<double> montoLimite = const Value.absent(),
                Value<int> mes = const Value.absent(),
                Value<int> anio = const Value.absent(),
              }) => PresupuestosCompanion(
                id: id,
                categoria: categoria,
                montoLimite: montoLimite,
                mes: mes,
                anio: anio,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String categoria,
                required double montoLimite,
                required int mes,
                required int anio,
              }) => PresupuestosCompanion.insert(
                id: id,
                categoria: categoria,
                montoLimite: montoLimite,
                mes: mes,
                anio: anio,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PresupuestosTable, Presupuesto>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PresupuestosTable,
                    Presupuesto
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PresupuestosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PresupuestosTable,
      Presupuesto,
      $$PresupuestosTableFilterComposer,
      $$PresupuestosTableOrderingComposer,
      $$PresupuestosTableAnnotationComposer,
      $$PresupuestosTableCreateCompanionBuilder,
      $$PresupuestosTableUpdateCompanionBuilder,
      (
        Presupuesto,
        BaseReferences<_$AppDatabase, $PresupuestosTable, Presupuesto>,
      ),
      Presupuesto,
      PrefetchHooks Function()
    >;
typedef $$CategoriasFinanzasTableCreateCompanionBuilder =
    CategoriasFinanzasCompanion Function({
      Value<int> id,
      required String valor,
      required String label,
      Value<String> icono,
      Value<bool> esDefault,
    });
typedef $$CategoriasFinanzasTableUpdateCompanionBuilder =
    CategoriasFinanzasCompanion Function({
      Value<int> id,
      Value<String> valor,
      Value<String> label,
      Value<String> icono,
      Value<bool> esDefault,
    });

class $$CategoriasFinanzasTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriasFinanzasTable> {
  $$CategoriasFinanzasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icono => $composableBuilder(
    column: $table.icono,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get esDefault => $composableBuilder(
    column: $table.esDefault,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriasFinanzasTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriasFinanzasTable> {
  $$CategoriasFinanzasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icono => $composableBuilder(
    column: $table.icono,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get esDefault => $composableBuilder(
    column: $table.esDefault,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriasFinanzasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriasFinanzasTable> {
  $$CategoriasFinanzasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get icono =>
      $composableBuilder(column: $table.icono, builder: (column) => column);

  GeneratedColumn<bool> get esDefault =>
      $composableBuilder(column: $table.esDefault, builder: (column) => column);
}

class $$CategoriasFinanzasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriasFinanzasTable,
          CategoriaFinanzas,
          $$CategoriasFinanzasTableFilterComposer,
          $$CategoriasFinanzasTableOrderingComposer,
          $$CategoriasFinanzasTableAnnotationComposer,
          $$CategoriasFinanzasTableCreateCompanionBuilder,
          $$CategoriasFinanzasTableUpdateCompanionBuilder,
          (
            CategoriaFinanzas,
            BaseReferences<
              _$AppDatabase,
              $CategoriasFinanzasTable,
              CategoriaFinanzas
            >,
          ),
          CategoriaFinanzas,
          PrefetchHooks Function()
        > {
  $$CategoriasFinanzasTableTableManager(
    _$AppDatabase db,
    $CategoriasFinanzasTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriasFinanzasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriasFinanzasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriasFinanzasTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> valor = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> icono = const Value.absent(),
                Value<bool> esDefault = const Value.absent(),
              }) => CategoriasFinanzasCompanion(
                id: id,
                valor: valor,
                label: label,
                icono: icono,
                esDefault: esDefault,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String valor,
                required String label,
                Value<String> icono = const Value.absent(),
                Value<bool> esDefault = const Value.absent(),
              }) => CategoriasFinanzasCompanion.insert(
                id: id,
                valor: valor,
                label: label,
                icono: icono,
                esDefault: esDefault,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriasFinanzasTable, CategoriaFinanzas>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $CategoriasFinanzasTable,
                    CategoriaFinanzas
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriasFinanzasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriasFinanzasTable,
      CategoriaFinanzas,
      $$CategoriasFinanzasTableFilterComposer,
      $$CategoriasFinanzasTableOrderingComposer,
      $$CategoriasFinanzasTableAnnotationComposer,
      $$CategoriasFinanzasTableCreateCompanionBuilder,
      $$CategoriasFinanzasTableUpdateCompanionBuilder,
      (
        CategoriaFinanzas,
        BaseReferences<
          _$AppDatabase,
          $CategoriasFinanzasTable,
          CategoriaFinanzas
        >,
      ),
      CategoriaFinanzas,
      PrefetchHooks Function()
    >;
typedef $$AjustesTableCreateCompanionBuilder =
    AjustesCompanion Function({
      required String clave,
      required String valor,
      Value<int> rowid,
    });
typedef $$AjustesTableUpdateCompanionBuilder =
    AjustesCompanion Function({
      Value<String> clave,
      Value<String> valor,
      Value<int> rowid,
    });

class $$AjustesTableFilterComposer
    extends Composer<_$AppDatabase, $AjustesTable> {
  $$AjustesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clave => $composableBuilder(
    column: $table.clave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AjustesTableOrderingComposer
    extends Composer<_$AppDatabase, $AjustesTable> {
  $$AjustesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clave => $composableBuilder(
    column: $table.clave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AjustesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AjustesTable> {
  $$AjustesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);
}

class $$AjustesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AjustesTable,
          Ajuste,
          $$AjustesTableFilterComposer,
          $$AjustesTableOrderingComposer,
          $$AjustesTableAnnotationComposer,
          $$AjustesTableCreateCompanionBuilder,
          $$AjustesTableUpdateCompanionBuilder,
          (Ajuste, BaseReferences<_$AppDatabase, $AjustesTable, Ajuste>),
          Ajuste,
          PrefetchHooks Function()
        > {
  $$AjustesTableTableManager(_$AppDatabase db, $AjustesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AjustesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AjustesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AjustesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clave = const Value.absent(),
                Value<String> valor = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AjustesCompanion(clave: clave, valor: valor, rowid: rowid),
          createCompanionCallback:
              ({
                required String clave,
                required String valor,
                Value<int> rowid = const Value.absent(),
              }) => AjustesCompanion.insert(
                clave: clave,
                valor: valor,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AjustesTable, Ajuste>(table),
                  BaseReferences<_$AppDatabase, $AjustesTable, Ajuste>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AjustesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AjustesTable,
      Ajuste,
      $$AjustesTableFilterComposer,
      $$AjustesTableOrderingComposer,
      $$AjustesTableAnnotationComposer,
      $$AjustesTableCreateCompanionBuilder,
      $$AjustesTableUpdateCompanionBuilder,
      (Ajuste, BaseReferences<_$AppDatabase, $AjustesTable, Ajuste>),
      Ajuste,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventosTableTableManager get eventos =>
      $$EventosTableTableManager(_db, _db.eventos);
  $$CumplesTableTableManager get cumples =>
      $$CumplesTableTableManager(_db, _db.cumples);
  $$CiclosTableTableManager get ciclos =>
      $$CiclosTableTableManager(_db, _db.ciclos);
  $$RegistrosDiaTableTableManager get registrosDia =>
      $$RegistrosDiaTableTableManager(_db, _db.registrosDia);
  $$CuentasTableTableManager get cuentas =>
      $$CuentasTableTableManager(_db, _db.cuentas);
  $$TransaccionesTableTableManager get transacciones =>
      $$TransaccionesTableTableManager(_db, _db.transacciones);
  $$TransferenciasTableTableManager get transferencias =>
      $$TransferenciasTableTableManager(_db, _db.transferencias);
  $$IngresosPlanificadosTableTableManager get ingresosPlanificados =>
      $$IngresosPlanificadosTableTableManager(_db, _db.ingresosPlanificados);
  $$VerificacionesTableTableManager get verificaciones =>
      $$VerificacionesTableTableManager(_db, _db.verificaciones);
  $$MetasTableTableManager get metas =>
      $$MetasTableTableManager(_db, _db.metas);
  $$PresupuestosTableTableManager get presupuestos =>
      $$PresupuestosTableTableManager(_db, _db.presupuestos);
  $$CategoriasFinanzasTableTableManager get categoriasFinanzas =>
      $$CategoriasFinanzasTableTableManager(_db, _db.categoriasFinanzas);
  $$AjustesTableTableManager get ajustes =>
      $$AjustesTableTableManager(_db, _db.ajustes);
}
