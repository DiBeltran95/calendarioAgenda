import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import 'cycle_engine.dart';

class CicloError implements Exception {
  const CicloError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Resultado de guardar un periodo: puede traer un aviso no bloqueante.
class GuardadoCiclo {
  const GuardadoCiclo({this.advertencia});
  final String? advertencia;
}

/// Síntomas del registro diario (clave, etiqueta).
const sintomasDisponibles = <(String, String)>[
  ('colicos', 'Cólicos'),
  ('dolor_cabeza', 'Dolor de cabeza'),
  ('hinchazon', 'Hinchazón'),
  ('sensibilidad', 'Senos sensibles'),
  ('acne', 'Acné'),
  ('cansancio', 'Cansancio'),
  ('antojos', 'Antojos'),
  ('insomnio', 'Insomnio'),
  ('nauseas', 'Náuseas'),
  ('dolor_espalda', 'Dolor de espalda'),
];

/// Estados de ánimo (clave, etiqueta).
const animosDisponibles = <(String, String)>[
  ('feliz', 'Feliz'),
  ('tranquila', 'Tranquila'),
  ('energica', 'Enérgica'),
  ('sensible', 'Sensible'),
  ('irritable', 'Irritable'),
  ('triste', 'Triste'),
  ('ansiosa', 'Ansiosa'),
];

const nivelesFlujo = ['Sin flujo', 'Ligero', 'Medio', 'Abundante'];

class CycleRepository {
  CycleRepository(this._db);
  final AppDatabase _db;

  Stream<List<Ciclo>> watchCiclos() =>
      (_db.select(_db.ciclos)..orderBy([(c) => OrderingTerm(expression: c.fechaInicio, mode: OrderingMode.desc)])).watch();

  Stream<List<RegistroDia>> watchRegistros() => _db.select(_db.registrosDia).watch();

  /// Registra (o edita, si [id] no es null) el día 1 de un ciclo. Aplica las
  /// mismas validaciones que el backend: sin fechas futuras ni duplicadas.
  Future<GuardadoCiclo> guardarPeriodo({int? id, required String fecha, int? diasSangrado, String observacion = ''}) async {
    final error = validarFechaCiclo(fecha);
    if (error != null) throw CicloError(error);
    if (diasSangrado != null && (diasSangrado < minSangrado || diasSangrado > maxSangrado)) {
      throw const CicloError('Los días de sangrado deben estar entre $minSangrado y $maxSangrado');
    }

    return _db.transaction(() async {
      final dup = await (_db.select(_db.ciclos)..where((c) => c.fechaInicio.equals(fecha))).getSingleOrNull();
      if (dup != null && dup.id != id) {
        throw CicloError(id == null ? 'Ya tienes un ciclo registrado en esa fecha' : 'Ya tienes otro ciclo registrado en esa fecha');
      }

      final datos = CiclosCompanion(
        fechaInicio: Value(fecha),
        diasSangrado: Value(diasSangrado),
        observacion: Value(observacion.trim()),
      );
      if (id == null) {
        await _db.into(_db.ciclos).insert(datos);
      } else {
        await (_db.update(_db.ciclos)..where((c) => c.id.equals(id))).write(datos);
      }

      // Aviso no bloqueante: dos inicios muy seguidos suelen ser un error.
      final anterior = await (_db.select(_db.ciclos)
            ..where((c) => c.fechaInicio.isSmallerThanValue(fecha))
            ..orderBy([(c) => OrderingTerm(expression: c.fechaInicio, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();
      if (anterior != null) {
        final dias = diffDias(fecha, anterior.fechaInicio);
        if (dias < 10) {
          return GuardadoCiclo(
            advertencia: 'El ciclo anterior empezó hace solo $dias día(s). Si fue un registro por error, puedes eliminarlo desde el historial.',
          );
        }
      }
      return const GuardadoCiclo();
    });
  }

  Future<void> eliminarPeriodo(int id) => (_db.delete(_db.ciclos)..where((c) => c.id.equals(id))).go();

  Future<void> restaurarPeriodo(Ciclo c) => _db.into(_db.ciclos).insert(c, mode: InsertMode.insertOrReplace);

  Future<void> guardarRegistroDia({required String fecha, required int flujo, String? animo, required Set<String> sintomas, String nota = ''}) {
    final vacio = flujo == 0 && animo == null && sintomas.isEmpty && nota.trim().isEmpty;
    if (vacio) return (_db.delete(_db.registrosDia)..where((r) => r.fecha.equals(fecha))).go();
    return _db.into(_db.registrosDia).insert(
          RegistrosDiaCompanion.insert(
            fecha: fecha,
            flujo: Value(flujo),
            animo: Value(animo),
            sintomas: Value(sintomas.join(',')),
            nota: Value(nota.trim()),
          ),
          onConflict: DoUpdate(
            (_) => RegistrosDiaCompanion(
              flujo: Value(flujo),
              animo: Value(animo),
              sintomas: Value(sintomas.join(',')),
              nota: Value(nota.trim()),
            ),
            target: [_db.registrosDia.fecha],
          ),
        );
  }
}

final cycleRepoProvider = Provider((ref) => CycleRepository(ref.watch(databaseProvider)));

final ciclosProvider = StreamProvider<List<Ciclo>>((ref) => ref.watch(cycleRepoProvider).watchCiclos());

/// Estadísticas del ciclo, calculadas una vez por cambio en los registros.
final cycleStatsProvider = Provider<CycleStats>((ref) {
  final ciclos = ref.watch(ciclosProvider).value ?? const <Ciclo>[];
  return buildCycleStats(ciclos.map((c) => RegistroCiclo(
        id: c.id,
        fechaInicio: c.fechaInicio,
        diasSangrado: c.diasSangrado,
        observacion: c.observacion,
      )));
});

final registrosDiaProvider = StreamProvider<Map<String, RegistroDia>>((ref) {
  return ref.watch(cycleRepoProvider).watchRegistros().map((l) => {for (final r in l) r.fecha: r});
});
