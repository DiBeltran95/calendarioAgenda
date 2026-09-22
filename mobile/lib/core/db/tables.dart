import 'package:drift/drift.dart';

// Todas las fechas "solo día" se guardan como texto YYYY-MM-DD (igual que el
// backend web): comparaciones lexicográficas, sin desfases de zona horaria.

// ─────────────────────────── Eventos ───────────────────────────

@DataClassName('Evento')
class Eventos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get titulo => text()();
  TextColumn get fecha => text()();

  /// HH:mm; null = todo el día.
  TextColumn get hora => text().nullable()();
  TextColumn get categoria => text().withDefault(const Constant('reunion'))();
  TextColumn get ubicacion => text().withDefault(const Constant(''))();
  TextColumn get notas => text().withDefault(const Constant(''))();

  /// unica · diaria · quincenal · mensual · trimestral · semestral · anual
  TextColumn get frecuencia => text().withDefault(const Constant('unica'))();
  RealColumn get costo => real().withDefault(const Constant(0))();

  /// ninguno · gasto · ingreso
  TextColumn get tipoTransaccion => text().withDefault(const Constant('ninguno'))();

  /// pendiente · pagado
  TextColumn get estadoPago => text().withDefault(const Constant('pendiente'))();

  /// Evento maestro de la serie (null en el propio maestro y en los únicos).
  IntColumn get parentId => integer().nullable()();

  /// Cobros de tarjeta generados por una compra a cuotas.
  IntColumn get tarjetaCreditoId => integer().nullable()();
  IntColumn get transaccionId => integer().nullable()();

  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Cumple')
class Cumples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();

  /// Fecha de referencia; solo importan mes y día (se repite cada año).
  TextColumn get fecha => text()();
  IntColumn get anioNacimiento => integer().nullable()();
  TextColumn get telefono => text().withDefault(const Constant(''))();
  TextColumn get mensaje => text().withDefault(const Constant(''))();
}

// ─────────────────────────── Ciclo ───────────────────────────

@DataClassName('Ciclo')
class Ciclos extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Día 1 del ciclo (primer día de sangrado).
  TextColumn get fechaInicio => text().unique()();
  TextColumn get observacion => text().withDefault(const Constant(''))();

  /// Días de sangrado de ese ciclo; null = sin especificar (se usa el promedio).
  IntColumn get diasSangrado => integer().nullable()();
}

/// Registro diario opcional: flujo, ánimo y síntomas (mejora sobre la web).
@DataClassName('RegistroDia')
class RegistrosDia extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fecha => text().unique()();

  /// 0 ninguno · 1 ligero · 2 medio · 3 abundante
  IntColumn get flujo => integer().withDefault(const Constant(0))();
  TextColumn get animo => text().nullable()();

  /// Claves de síntomas separadas por coma.
  TextColumn get sintomas => text().withDefault(const Constant(''))();
  TextColumn get nota => text().withDefault(const Constant(''))();
}

// ─────────────────────────── Finanzas ───────────────────────────

@DataClassName('Cuenta')
class Cuentas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();

  /// ahorros · corriente · tarjeta_credito · cdt · efectivo · otro
  TextColumn get tipo => text()();

  /// En tarjetas de crédito el saldo es la DEUDA.
  RealColumn get saldo => real().withDefault(const Constant(0))();
  RealColumn get limite => real().withDefault(const Constant(0))();

  /// Tasa efectiva anual (%) de CDT / cajitas.
  RealColumn get interesTasa => real().withDefault(const Constant(0))();
  TextColumn get fechaInicio => text().nullable()();
  IntColumn get plazoDias => integer().withDefault(const Constant(0))();

  /// Día de corte de la tarjeta de crédito (1..31).
  IntColumn get diaCorte => integer().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Transaccion')
class Transacciones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cuentaId => integer().nullable()();

  /// gasto · ingreso
  TextColumn get tipo => text()();
  RealColumn get monto => real()();
  TextColumn get descripcion => text()();
  TextColumn get fecha => text()();
  TextColumn get categoria => text().withDefault(const Constant('otros'))();
  IntColumn get cuotas => integer().withDefault(const Constant(1))();
  IntColumn get ingresoPlanificadoId => integer().nullable()();

  /// Aporte a una meta de ahorro (al borrarlo se descuenta de la meta).
  IntColumn get metaId => integer().nullable()();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Transferencia')
class Transferencias extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cuentaOrigenId => integer()();
  IntColumn get cuentaDestinoId => integer()();
  RealColumn get monto => real()();
  TextColumn get descripcion => text().withDefault(const Constant(''))();
  TextColumn get fecha => text()();
}

@DataClassName('IngresoPlanificado')
class IngresosPlanificados extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cuentaId => integer().nullable()();
  TextColumn get descripcion => text()();
  RealColumn get monto => real()();

  /// diario · semanal · quincenal · mensual · unica
  TextColumn get frecuencia => text()();
  TextColumn get fechaInicio => text()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
}

@DataClassName('Verificacion')
class Verificaciones extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get ingresoPlanificadoId => integer()();
  TextColumn get fechaEsperada => text()();
  TextColumn get fechaReal => text()();
  RealColumn get montoReal => real()();
  IntColumn get transaccionId => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {ingresoPlanificadoId, fechaEsperada},
      ];
}

@DataClassName('Meta')
class Metas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().withDefault(const Constant(''))();
  RealColumn get montoObjetivo => real()();
  RealColumn get montoActual => real().withDefault(const Constant(0))();
  TextColumn get fechaObjetivo => text().nullable()();
  TextColumn get icono => text().withDefault(const Constant('savings'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF34E47E))();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
  DateTimeColumn get creadoEn => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Presupuesto')
class Presupuestos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get categoria => text()();
  RealColumn get montoLimite => real()();

  /// 1..12
  IntColumn get mes => integer()();
  IntColumn get anio => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {categoria, mes, anio},
      ];
}

@DataClassName('CategoriaFinanzas')
class CategoriasFinanzas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get valor => text().unique()();
  TextColumn get label => text()();
  TextColumn get icono => text().withDefault(const Constant('sell'))();
  BoolColumn get esDefault => boolean().withDefault(const Constant(false))();
}

// ─────────────────────────── Ajustes ───────────────────────────

@DataClassName('Ajuste')
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}
