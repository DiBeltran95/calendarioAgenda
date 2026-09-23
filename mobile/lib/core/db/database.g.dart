// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
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

class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _claveMeta = const VerificationMeta('clave');
  @override
  late final GeneratedColumn<String> clave = GeneratedColumn<String>(
    'clave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actualizadoMeta = const VerificationMeta(
    'actualizado',
  );
  @override
  late final GeneratedColumn<DateTime> actualizado = GeneratedColumn<DateTime>(
    'actualizado',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [clave, json, actualizado];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntry> instance, {
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
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('actualizado')) {
      context.handle(
        _actualizadoMeta,
        actualizado.isAcceptableOrUnknown(
          data['actualizado']!,
          _actualizadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualizadoMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clave};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      clave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clave'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      actualizado: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actualizado'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  final String clave;
  final String json;
  final DateTime actualizado;
  const CacheEntry({
    required this.clave,
    required this.json,
    required this.actualizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['clave'] = Variable<String>(clave);
    map['json'] = Variable<String>(json);
    map['actualizado'] = Variable<DateTime>(actualizado);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      clave: Value(clave),
      json: Value(json),
      actualizado: Value(actualizado),
    );
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      clave: serializer.fromJson<String>(json['clave']),
      json: serializer.fromJson<String>(json['json']),
      actualizado: serializer.fromJson<DateTime>(json['actualizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clave': serializer.toJson<String>(clave),
      'json': serializer.toJson<String>(json),
      'actualizado': serializer.toJson<DateTime>(actualizado),
    };
  }

  CacheEntry copyWith({String? clave, String? json, DateTime? actualizado}) =>
      CacheEntry(
        clave: clave ?? this.clave,
        json: json ?? this.json,
        actualizado: actualizado ?? this.actualizado,
      );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      clave: data.clave.present ? data.clave.value : this.clave,
      json: data.json.present ? data.json.value : this.json,
      actualizado: data.actualizado.present
          ? data.actualizado.value
          : this.actualizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('clave: $clave, ')
          ..write('json: $json, ')
          ..write('actualizado: $actualizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clave, json, actualizado);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.clave == this.clave &&
          other.json == this.json &&
          other.actualizado == this.actualizado);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> clave;
  final Value<String> json;
  final Value<DateTime> actualizado;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.clave = const Value.absent(),
    this.json = const Value.absent(),
    this.actualizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String clave,
    required String json,
    required DateTime actualizado,
    this.rowid = const Value.absent(),
  }) : clave = Value(clave),
       json = Value(json),
       actualizado = Value(actualizado);
  static Insertable<CacheEntry> custom({
    Expression<String>? clave,
    Expression<String>? json,
    Expression<DateTime>? actualizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clave != null) 'clave': clave,
      if (json != null) 'json': json,
      if (actualizado != null) 'actualizado': actualizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? clave,
    Value<String>? json,
    Value<DateTime>? actualizado,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      clave: clave ?? this.clave,
      json: json ?? this.json,
      actualizado: actualizado ?? this.actualizado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clave.present) {
      map['clave'] = Variable<String>(clave.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (actualizado.present) {
      map['actualizado'] = Variable<DateTime>(actualizado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('clave: $clave, ')
          ..write('json: $json, ')
          ..write('actualizado: $actualizado, ')
          ..write('rowid: $rowid')
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
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<int> usuarioId = GeneratedColumn<int>(
    'usuario_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    usuarioId,
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
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
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
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {usuarioId, fecha},
  ];
  @override
  RegistroDia map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RegistroDia(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}usuario_id'],
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
  final int usuarioId;
  final String fecha;

  /// 0 ninguno · 1 ligero · 2 medio · 3 abundante
  final int flujo;
  final String? animo;

  /// Claves de síntomas separadas por coma.
  final String sintomas;
  final String nota;
  const RegistroDia({
    required this.id,
    required this.usuarioId,
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
    map['usuario_id'] = Variable<int>(usuarioId);
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
      usuarioId: Value(usuarioId),
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
      usuarioId: serializer.fromJson<int>(json['usuarioId']),
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
      'usuarioId': serializer.toJson<int>(usuarioId),
      'fecha': serializer.toJson<String>(fecha),
      'flujo': serializer.toJson<int>(flujo),
      'animo': serializer.toJson<String?>(animo),
      'sintomas': serializer.toJson<String>(sintomas),
      'nota': serializer.toJson<String>(nota),
    };
  }

  RegistroDia copyWith({
    int? id,
    int? usuarioId,
    String? fecha,
    int? flujo,
    Value<String?> animo = const Value.absent(),
    String? sintomas,
    String? nota,
  }) => RegistroDia(
    id: id ?? this.id,
    usuarioId: usuarioId ?? this.usuarioId,
    fecha: fecha ?? this.fecha,
    flujo: flujo ?? this.flujo,
    animo: animo.present ? animo.value : this.animo,
    sintomas: sintomas ?? this.sintomas,
    nota: nota ?? this.nota,
  );
  RegistroDia copyWithCompanion(RegistrosDiaCompanion data) {
    return RegistroDia(
      id: data.id.present ? data.id.value : this.id,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
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
          ..write('usuarioId: $usuarioId, ')
          ..write('fecha: $fecha, ')
          ..write('flujo: $flujo, ')
          ..write('animo: $animo, ')
          ..write('sintomas: $sintomas, ')
          ..write('nota: $nota')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, usuarioId, fecha, flujo, animo, sintomas, nota);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RegistroDia &&
          other.id == this.id &&
          other.usuarioId == this.usuarioId &&
          other.fecha == this.fecha &&
          other.flujo == this.flujo &&
          other.animo == this.animo &&
          other.sintomas == this.sintomas &&
          other.nota == this.nota);
}

class RegistrosDiaCompanion extends UpdateCompanion<RegistroDia> {
  final Value<int> id;
  final Value<int> usuarioId;
  final Value<String> fecha;
  final Value<int> flujo;
  final Value<String?> animo;
  final Value<String> sintomas;
  final Value<String> nota;
  const RegistrosDiaCompanion({
    this.id = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.fecha = const Value.absent(),
    this.flujo = const Value.absent(),
    this.animo = const Value.absent(),
    this.sintomas = const Value.absent(),
    this.nota = const Value.absent(),
  });
  RegistrosDiaCompanion.insert({
    this.id = const Value.absent(),
    required int usuarioId,
    required String fecha,
    this.flujo = const Value.absent(),
    this.animo = const Value.absent(),
    this.sintomas = const Value.absent(),
    this.nota = const Value.absent(),
  }) : usuarioId = Value(usuarioId),
       fecha = Value(fecha);
  static Insertable<RegistroDia> custom({
    Expression<int>? id,
    Expression<int>? usuarioId,
    Expression<String>? fecha,
    Expression<int>? flujo,
    Expression<String>? animo,
    Expression<String>? sintomas,
    Expression<String>? nota,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (fecha != null) 'fecha': fecha,
      if (flujo != null) 'flujo': flujo,
      if (animo != null) 'animo': animo,
      if (sintomas != null) 'sintomas': sintomas,
      if (nota != null) 'nota': nota,
    });
  }

  RegistrosDiaCompanion copyWith({
    Value<int>? id,
    Value<int>? usuarioId,
    Value<String>? fecha,
    Value<int>? flujo,
    Value<String?>? animo,
    Value<String>? sintomas,
    Value<String>? nota,
  }) {
    return RegistrosDiaCompanion(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
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
    if (usuarioId.present) {
      map['usuario_id'] = Variable<int>(usuarioId.value);
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
          ..write('usuarioId: $usuarioId, ')
          ..write('fecha: $fecha, ')
          ..write('flujo: $flujo, ')
          ..write('animo: $animo, ')
          ..write('sintomas: $sintomas, ')
          ..write('nota: $nota')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AjustesTable ajustes = $AjustesTable(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $RegistrosDiaTable registrosDia = $RegistrosDiaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ajustes,
    cacheEntries,
    registrosDia,
  ];
}

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
typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String clave,
      required String json,
      required DateTime actualizado,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> clave,
      Value<String> json,
      Value<DateTime> actualizado,
      Value<int> rowid,
    });

class $$CacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
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

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualizado => $composableBuilder(
    column: $table.actualizado,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualizado => $composableBuilder(
    column: $table.actualizado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clave =>
      $composableBuilder(column: $table.clave, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get actualizado => $composableBuilder(
    column: $table.actualizado,
    builder: (column) => column,
  );
}

class $$CacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CacheEntriesTable,
          CacheEntry,
          $$CacheEntriesTableFilterComposer,
          $$CacheEntriesTableOrderingComposer,
          $$CacheEntriesTableAnnotationComposer,
          $$CacheEntriesTableCreateCompanionBuilder,
          $$CacheEntriesTableUpdateCompanionBuilder,
          (
            CacheEntry,
            BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
          ),
          CacheEntry,
          PrefetchHooks Function()
        > {
  $$CacheEntriesTableTableManager(_$AppDatabase db, $CacheEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clave = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> actualizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                clave: clave,
                json: json,
                actualizado: actualizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clave,
                required String json,
                required DateTime actualizado,
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                clave: clave,
                json: json,
                actualizado: actualizado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheEntriesTable, CacheEntry>(table),
                  BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>(
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

typedef $$CacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CacheEntriesTable,
      CacheEntry,
      $$CacheEntriesTableFilterComposer,
      $$CacheEntriesTableOrderingComposer,
      $$CacheEntriesTableAnnotationComposer,
      $$CacheEntriesTableCreateCompanionBuilder,
      $$CacheEntriesTableUpdateCompanionBuilder,
      (
        CacheEntry,
        BaseReferences<_$AppDatabase, $CacheEntriesTable, CacheEntry>,
      ),
      CacheEntry,
      PrefetchHooks Function()
    >;
typedef $$RegistrosDiaTableCreateCompanionBuilder =
    RegistrosDiaCompanion Function({
      Value<int> id,
      required int usuarioId,
      required String fecha,
      Value<int> flujo,
      Value<String?> animo,
      Value<String> sintomas,
      Value<String> nota,
    });
typedef $$RegistrosDiaTableUpdateCompanionBuilder =
    RegistrosDiaCompanion Function({
      Value<int> id,
      Value<int> usuarioId,
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

  ColumnFilters<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
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

  ColumnOrderings<int> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
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

  GeneratedColumn<int> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

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
                Value<int> usuarioId = const Value.absent(),
                Value<String> fecha = const Value.absent(),
                Value<int> flujo = const Value.absent(),
                Value<String?> animo = const Value.absent(),
                Value<String> sintomas = const Value.absent(),
                Value<String> nota = const Value.absent(),
              }) => RegistrosDiaCompanion(
                id: id,
                usuarioId: usuarioId,
                fecha: fecha,
                flujo: flujo,
                animo: animo,
                sintomas: sintomas,
                nota: nota,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int usuarioId,
                required String fecha,
                Value<int> flujo = const Value.absent(),
                Value<String?> animo = const Value.absent(),
                Value<String> sintomas = const Value.absent(),
                Value<String> nota = const Value.absent(),
              }) => RegistrosDiaCompanion.insert(
                id: id,
                usuarioId: usuarioId,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AjustesTableTableManager get ajustes =>
      $$AjustesTableTableManager(_db, _db.ajustes);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
  $$RegistrosDiaTableTableManager get registrosDia =>
      $$RegistrosDiaTableTableManager(_db, _db.registrosDia);
}
