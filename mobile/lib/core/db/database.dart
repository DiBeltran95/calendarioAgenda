import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

/// Categorías de gasto con las que arranca cada instalación (las mismas que
/// sembraba el backend). El usuario puede crear más desde Presupuesto.
const categoriasPorDefecto = [
  ('comida', 'Comida', 'restaurant'),
  ('transporte', 'Transporte', 'directions_car'),
  ('servicios', 'Servicios/Facturas', 'receipt_long'),
  ('entretenimiento', 'Entretenimiento/Ocio', 'sports_esports'),
  ('salud', 'Salud/Bienestar', 'medication'),
  ('educacion', 'Educación', 'school'),
  ('ahorro', 'Ahorro/Inversión', 'savings'),
  ('arriendo', 'Arriendo', 'real_estate_agent'),
  ('otros', 'Otros', 'payments'),
];

@DriftDatabase(tables: [
  Eventos,
  Cumples,
  Ciclos,
  RegistrosDia,
  Cuentas,
  Transacciones,
  Transferencias,
  IngresosPlanificados,
  Verificaciones,
  Metas,
  Presupuestos,
  CategoriasFinanzas,
  Ajustes,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _abrir());

  /// Base en memoria para pruebas.
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _sembrarCategorias();
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _sembrarCategorias() async {
    await batch((b) {
      b.insertAll(
        categoriasFinanzas,
        [
          for (final (valor, label, icono) in categoriasPorDefecto)
            CategoriasFinanzasCompanion.insert(
              valor: valor,
              label: label,
              icono: Value(icono),
              esDefault: const Value(true),
            ),
        ],
        mode: InsertMode.insertOrIgnore,
      );
    });
  }

  /// Borra todos los datos y deja la base como recién instalada.
  Future<void> reiniciar() async {
    await transaction(() async {
      for (final t in allTables) {
        await delete(t).go();
      }
      await _sembrarCategorias();
    });
  }

  static QueryExecutor _abrir() {
    return driftDatabase(
      name: 'agendaservi',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
