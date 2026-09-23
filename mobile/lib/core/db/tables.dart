import 'package:drift/drift.dart';

// La fuente de verdad es el backend (así el cron puede enviar los WhatsApp).
// En el dispositivo solo vive:
//  - las preferencias de la app,
//  - una caché de las respuestas del servidor (para abrir al instante y poder
//    consultar sin conexión),
//  - el registro diario de síntomas del ciclo, que es privado y no existe en
//    el servidor.

@DataClassName('Ajuste')
class Ajustes extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Respuesta JSON cacheada, con clave por usuario (`u12:mes:2026-09`).
@DataClassName('CacheEntry')
class CacheEntries extends Table {
  TextColumn get clave => text()();
  TextColumn get json => text()();
  DateTimeColumn get actualizado => dateTime()();

  @override
  Set<Column> get primaryKey => {clave};
}

/// Registro diario opcional del ciclo: flujo, ánimo y síntomas.
@DataClassName('RegistroDia')
class RegistrosDia extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get usuarioId => integer()();
  TextColumn get fecha => text()();

  /// 0 ninguno · 1 ligero · 2 medio · 3 abundante
  IntColumn get flujo => integer().withDefault(const Constant(0))();
  TextColumn get animo => text().nullable()();

  /// Claves de síntomas separadas por coma.
  TextColumn get sintomas => text().withDefault(const Constant(''))();
  TextColumn get nota => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {usuarioId, fecha},
      ];
}
