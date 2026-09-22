import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';

/// Datos de un evento tal como los edita el formulario.
class EventoInput {
  const EventoInput({
    required this.titulo,
    required this.fecha,
    this.hora,
    this.categoria = 'reunion',
    this.ubicacion = '',
    this.notas = '',
    this.frecuencia = 'unica',
    this.costo = 0,
    this.tipoTransaccion = 'ninguno',
    this.estadoPago = 'pendiente',
  });

  final String titulo;
  final String fecha;
  final String? hora;
  final String categoria;
  final String ubicacion;
  final String notas;
  final String frecuencia;
  final double costo;
  final String tipoTransaccion;
  final String estadoPago;

  factory EventoInput.desde(Evento e) => EventoInput(
        titulo: e.titulo,
        fecha: e.fecha,
        hora: e.hora,
        categoria: e.categoria,
        ubicacion: e.ubicacion,
        notas: e.notas,
        frecuencia: e.frecuencia,
        costo: e.costo,
        tipoTransaccion: e.tipoTransaccion,
        estadoPago: e.estadoPago,
      );
}

/// Alcance de una edición o borrado sobre una serie.
enum AlcanceSerie { soloEste, esteYFuturos }

class CumpleInput {
  const CumpleInput({required this.nombre, required this.fecha, this.anioNacimiento, this.telefono = '', this.mensaje = ''});
  final String nombre;
  final String fecha;
  final int? anioNacimiento;
  final String telefono;
  final String mensaje;
}

/// Cuántas ocurrencias se materializan por frecuencia (igual que el backend).
int maxOcurrencias(String frecuencia) => switch (frecuencia) {
      'diaria' => 90, // 3 meses
      'quincenal' => 48, // 2 años
      'mensual' => 24,
      'trimestral' => 8,
      'semestral' => 4,
      'anual' => 5, // 5 años
      _ => 0,
    };

/// Fecha de la ocurrencia i (1-based) de una serie que arranca en [base].
String fechaOcurrencia(String base, String frecuencia, int i) {
  final d = parseYmd(base);
  return switch (frecuencia) {
    'diaria' => ymd(DateTime(d.year, d.month, d.day + i)),
    'quincenal' => ymd(DateTime(d.year, d.month, d.day + 15 * i)),
    'mensual' => ymd(sumarMesesRecortado(d, i)),
    'trimestral' => ymd(sumarMesesRecortado(d, 3 * i)),
    'semestral' => ymd(sumarMesesRecortado(d, 6 * i)),
    'anual' => ymd(sumarMesesRecortado(d, 12 * i)),
    _ => base,
  };
}

class EventsRepository {
  EventsRepository(this._db);
  final AppDatabase _db;

  $EventosTable get _ev => _db.eventos;

  // ─────────────── Lecturas reactivas ───────────────

  /// Eventos entre dos fechas (inclusive), ordenados por fecha y hora.
  Stream<List<Evento>> watchRango(String desde, String hasta) {
    return (_db.select(_ev)
          ..where((e) => e.fecha.isBetweenValues(desde, hasta))
          ..orderBy([(e) => OrderingTerm(expression: e.fecha), (e) => OrderingTerm(expression: e.hora)]))
        .watch();
  }

  Stream<List<Evento>> watchMes(int anio, int mes) {
    final p = prefijoMes(anio, mes);
    return watchRango('$p-01', '$p-31');
  }

  Stream<List<Cumple>> watchCumples() =>
      (_db.select(_db.cumples)..orderBy([(c) => OrderingTerm(expression: c.nombre)])).watch();

  Future<List<Evento>> buscar(String texto) {
    final q = '%${texto.trim()}%';
    return (_db.select(_ev)
          ..where((e) => e.titulo.like(q) | e.ubicacion.like(q) | e.notas.like(q))
          ..orderBy([(e) => OrderingTerm(expression: e.fecha, mode: OrderingMode.desc)])
          ..limit(60))
        .get();
  }

  // ─────────────── Eventos ───────────────

  EventosCompanion _companion(EventoInput i, {int? parentId}) => EventosCompanion.insert(
        titulo: i.titulo.trim(),
        fecha: i.fecha,
        hora: Value(i.hora == null || i.hora!.isEmpty ? null : i.hora),
        categoria: Value(i.categoria),
        ubicacion: Value(i.ubicacion.trim()),
        notas: Value(i.notas.trim()),
        frecuencia: Value(i.frecuencia),
        costo: Value(i.tipoTransaccion == 'ninguno' ? 0 : i.costo),
        tipoTransaccion: Value(i.tipoTransaccion),
        estadoPago: Value(i.estadoPago),
        parentId: Value(parentId),
      );

  /// Crea el evento maestro y, si se repite, materializa sus ocurrencias.
  Future<int> crear(EventoInput i) {
    return _db.transaction(() async {
      final id = await _db.into(_ev).insert(_companion(i));
      await _generarOcurrencias(id, i.fecha, i);
      return id;
    });
  }

  Future<void> _generarOcurrencias(int masterId, String base, EventoInput i) async {
    final n = maxOcurrencias(i.frecuencia);
    if (n == 0) return;
    await _db.batch((b) {
      b.insertAll(_ev, [
        for (var k = 1; k <= n; k++)
          // Las ocurrencias futuras arrancan siempre como pendientes.
          _companion(i, parentId: masterId).copyWith(
            fecha: Value(fechaOcurrencia(base, i.frecuencia, k)),
            estadoPago: const Value('pendiente'),
          ),
      ]);
    });
  }

  bool esSerie(Evento e) => e.frecuencia != 'unica' || e.parentId != null;

  Future<void> actualizar(Evento original, EventoInput i, AlcanceSerie alcance) {
    return _db.transaction(() async {
      if (alcance == AlcanceSerie.esteYFuturos) {
        final parentId = original.parentId ?? original.id;
        await (_db.update(_ev)..where((e) => e.id.equals(original.id)))
            .write(_companion(i, parentId: original.parentId));
        // Se borran las ocurrencias futuras pendientes y se regeneran desde la
        // nueva fecha con la nueva frecuencia (las pagadas se conservan).
        // Se excluye la propia instancia editada: si su nueva fecha es
        // posterior a la original, el backend web la borraba por error.
        await (_db.delete(_ev)
              ..where((e) =>
                  e.parentId.equals(parentId) &
                  e.id.equals(original.id).not() &
                  e.fecha.isBiggerThanValue(original.fecha) &
                  e.estadoPago.equals('pendiente')))
            .go();
        await _generarOcurrencias(parentId, i.fecha, i);
      } else {
        final nuevoParent = i.frecuencia == 'unica' ? null : original.parentId;
        await (_db.update(_ev)..where((e) => e.id.equals(original.id)))
            .write(_companion(i, parentId: nuevoParent));
      }
    });
  }

  Future<void> eliminar(Evento e, AlcanceSerie alcance) async {
    if (alcance == AlcanceSerie.esteYFuturos) {
      final parentId = e.parentId ?? e.id;
      await (_db.delete(_ev)
            ..where((x) =>
                (x.id.equals(e.id) | x.parentId.equals(parentId)) &
                x.fecha.isBiggerOrEqualValue(e.fecha) &
                x.estadoPago.equals('pendiente')))
          .go();
    } else {
      await (_db.delete(_ev)..where((x) => x.id.equals(e.id))).go();
    }
  }

  /// Reinsertar un evento borrado (para "Deshacer").
  Future<void> restaurar(List<Evento> eventos) async {
    await _db.batch((b) => b.insertAll(_ev, eventos, mode: InsertMode.insertOrReplace));
  }

  /// Eventos que borraría [eliminar] (para poder deshacer).
  Future<List<Evento>> afectados(Evento e, AlcanceSerie alcance) {
    if (alcance == AlcanceSerie.soloEste) return Future.value([e]);
    final parentId = e.parentId ?? e.id;
    return (_db.select(_ev)
          ..where((x) =>
              (x.id.equals(e.id) | x.parentId.equals(parentId)) &
              x.fecha.isBiggerOrEqualValue(e.fecha) &
              x.estadoPago.equals('pendiente')))
        .get();
  }

  Future<void> alternarPago(Evento e) {
    final nuevo = e.estadoPago == 'pagado' ? 'pendiente' : 'pagado';
    return (_db.update(_ev)..where((x) => x.id.equals(e.id))).write(EventosCompanion(estadoPago: Value(nuevo)));
  }

  // ─────────────── Cumpleaños ───────────────

  Future<int> crearCumple(CumpleInput c) => _db.into(_db.cumples).insert(CumplesCompanion.insert(
        nombre: c.nombre.trim(),
        fecha: c.fecha,
        anioNacimiento: Value(c.anioNacimiento),
        telefono: Value(c.telefono.trim()),
        mensaje: Value(c.mensaje.trim()),
      ));

  Future<void> actualizarCumple(int id, CumpleInput c) =>
      (_db.update(_db.cumples)..where((x) => x.id.equals(id))).write(CumplesCompanion(
        nombre: Value(c.nombre.trim()),
        fecha: Value(c.fecha),
        anioNacimiento: Value(c.anioNacimiento),
        telefono: Value(c.telefono.trim()),
        mensaje: Value(c.mensaje.trim()),
      ));

  Future<void> eliminarCumple(int id) => (_db.delete(_db.cumples)..where((x) => x.id.equals(id))).go();

  Future<void> restaurarCumple(Cumple c) => _db.into(_db.cumples).insert(c, mode: InsertMode.insertOrReplace);
}

final eventsRepoProvider = Provider((ref) => EventsRepository(ref.watch(databaseProvider)));

/// Eventos del mes (clave: (año, mes 1..12)).
final eventosMesProvider = StreamProvider.family<List<Evento>, (int, int)>((ref, k) {
  return ref.watch(eventsRepoProvider).watchMes(k.$1, k.$2);
});

final cumplesProvider = StreamProvider<List<Cumple>>((ref) => ref.watch(eventsRepoProvider).watchCumples());
