import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/net/api_client.dart';
import '../../core/net/api_exception.dart';
import '../../core/net/json.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';
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

/// Periodos contra `/api/cycles` (el servidor valida fechas y duplicados).
/// El registro diario de síntomas es privado y vive solo en el teléfono.
class CycleRepository {
  CycleRepository(this._api, this._sync, this._db, this._usuarioId);
  final ApiClient _api;
  final Sincronizador _sync;
  final AppDatabase _db;
  final int _usuarioId;

  Future<GuardadoCiclo> guardarPeriodo({int? id, required String fecha, int? diasSangrado, String observacion = ''}) async {
    // Las mismas validaciones del servidor, para responder al instante.
    final error = validarFechaCiclo(fecha);
    if (error != null) throw CicloError(error);
    if (diasSangrado != null && (diasSangrado < minSangrado || diasSangrado > maxSangrado)) {
      throw const CicloError('Los días de sangrado deben estar entre $minSangrado y $maxSangrado');
    }
    final body = {'fecha_inicio': fecha, 'observacion': observacion.trim(), 'dias_sangrado': diasSangrado};
    try {
      final r = asMap(id == null ? await _api.post('/api/cycles', body: body) : await _api.put('/api/cycles/$id', body: body));
      await _sync.despuesDeCambio(meses: false);
      return GuardadoCiclo(advertencia: asStringOrNull(r['advertencia']));
    } on ApiException catch (e) {
      if (e.isNetwork) rethrow;
      throw CicloError(e.message);
    }
  }

  Future<void> eliminarPeriodo(int id) async {
    await _api.delete('/api/cycles/$id');
    await _sync.despuesDeCambio(meses: false);
  }

  /// "Deshacer" de un borrado: se vuelve a registrar el mismo ciclo.
  Future<void> restaurarPeriodo(Ciclo c) =>
      guardarPeriodo(fecha: c.fechaInicio, diasSangrado: c.diasSangrado, observacion: c.observacion);

  // ─────────────── Registro diario (local) ───────────────

  Stream<List<RegistroDia>> watchRegistros() =>
      (_db.select(_db.registrosDia)..where((r) => r.usuarioId.equals(_usuarioId))).watch();

  Future<void> guardarRegistroDia({required String fecha, required int flujo, String? animo, required Set<String> sintomas, String nota = ''}) async {
    final vacio = flujo == 0 && animo == null && sintomas.isEmpty && nota.trim().isEmpty;
    await (_db.delete(_db.registrosDia)..where((r) => r.usuarioId.equals(_usuarioId) & r.fecha.equals(fecha))).go();
    if (vacio) return;
    await _db.into(_db.registrosDia).insert(RegistrosDiaCompanion.insert(
          usuarioId: _usuarioId,
          fecha: fecha,
          flujo: Value(flujo),
          animo: Value(animo),
          sintomas: Value(sintomas.join(',')),
          nota: Value(nota.trim()),
        ));
  }
}

final cycleRepoProvider = Provider((ref) => CycleRepository(
      ref.watch(apiProvider),
      ref.watch(sincronizadorProvider),
      ref.watch(databaseProvider),
      ref.watch(usuarioIdProvider),
    ));

final ciclosProvider = Provider<AsyncValue<List<Ciclo>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.ciclos));

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
