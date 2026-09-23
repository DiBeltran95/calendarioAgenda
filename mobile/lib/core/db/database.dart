import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Ajustes, CacheEntries, RegistrosDia])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrir());

  /// Base en memoria para pruebas.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ─────────────── Caché de respuestas del servidor ───────────────

  Future<Map<String, Object?>?> leerCache(String clave) async {
    final r = await (select(cacheEntries)..where((c) => c.clave.equals(clave))).getSingleOrNull();
    return r == null ? null : {'json': r.json, 'actualizado': r.actualizado};
  }

  Future<void> escribirCache(String clave, String json) => into(cacheEntries).insertOnConflictUpdate(
        CacheEntriesCompanion.insert(clave: clave, json: json, actualizado: DateTime.now()),
      );

  /// Borra la caché (al cerrar sesión: los datos de un usuario no deben quedar
  /// a la vista del siguiente que inicie sesión en el mismo teléfono).
  Future<void> limpiarCache() => delete(cacheEntries).go();

  static QueryExecutor _abrir() {
    return driftDatabase(
      name: 'agendaservi_v2',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
