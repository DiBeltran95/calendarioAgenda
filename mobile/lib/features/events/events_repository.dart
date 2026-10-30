import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/api_client.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../data/models.dart';
import '../../data/sync.dart';

/// Datos de un evento tal como los edita el formulario.
class EventoInput {
  const EventoInput({
    required this.titulo,
    required this.fecha,
    this.hora,
    this.categoria = 'reunion',
    this.ubicacion = '',
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
  final String frecuencia;
  final double costo;
  final String tipoTransaccion;
  final String estadoPago;

  factory EventoInput.desde(Evento e, {String? frecuencia}) => EventoInput(
        titulo: e.titulo,
        fecha: e.fecha,
        hora: e.hora,
        categoria: e.categoria,
        ubicacion: e.ubicacion,
        frecuencia: frecuencia ?? e.frecuencia,
        costo: e.costo,
        tipoTransaccion: e.tipoTransaccion,
        estadoPago: e.estadoPago,
      );

  /// Cuerpo que espera `POST/PUT /api/events` (igual que la web).
  Map<String, dynamic> toBody() => {
        'titulo': titulo.trim(),
        'fecha': fecha,
        'hora': (hora == null || hora!.isEmpty) ? null : hora,
        'categoria': categoria,
        'ubicacion': ubicacion.trim(),
        'repeticion': frecuencia,
        'frecuencia': frecuencia,
        'costo': tipoTransaccion == 'ninguno' ? 0 : costo,
        'tipo_transaccion': tipoTransaccion,
        'estado_pago': estadoPago,
      };
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

  Map<String, dynamic> toBody() => {
        'nombre': nombre.trim(),
        'fecha': fecha,
        'anio_nacimiento': anioNacimiento,
        'mensaje': mensaje.trim().isEmpty ? null : mensaje.trim(),
        'telefono': telefono.trim().isEmpty ? null : telefono.trim(),
      };
}

/// Cuántas ocurrencias materializa el servidor por frecuencia.
int maxOcurrencias(String frecuencia) => switch (frecuencia) {
      'diaria' => 90,
      'quincenal' => 48,
      'mensual' => 24,
      'trimestral' => 8,
      'semestral' => 4,
      'anual' => 5,
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

/// Eventos y cumpleaños contra `/api/events` y `/api/cumpleanos`.
class EventsRepository {
  EventsRepository(this._api, this._sync, this._ref);
  final ApiClient _api;
  final Sincronizador _sync;
  final Ref _ref;

  bool esSerie(Evento e) => e.frecuencia != 'unica' || e.parentId != null;

  /// Crea el evento; el servidor materializa las ocurrencias si se repite.
  Future<int> crear(EventoInput i) async {
    final r = asMap(await _api.post('/api/events', body: i.toBody()));
    await _sync.despuesDeCambio(bootstrap: false);
    return asInt(r['id']);
  }

  Future<void> actualizar(Evento original, EventoInput i, AlcanceSerie alcance) async {
    await _api.put('/api/events/${original.id}', body: i.toBody(), query: {
      'editMode': alcance == AlcanceSerie.esteYFuturos ? 'future' : 'instance',
    });
    await _sync.despuesDeCambio(bootstrap: false);
  }

  Future<void> eliminar(Evento e, AlcanceSerie alcance) async {
    await _api.delete('/api/events/${e.id}', query: {
      'deleteMode': alcance == AlcanceSerie.esteYFuturos ? 'future' : 'instance',
    });
    await _sync.despuesDeCambio(bootstrap: false);
  }

  /// "Deshacer": se vuelve a crear con los mismos datos. Si se repite, el
  /// servidor genera de nuevo las repeticiones desde esa fecha.
  Future<void> restaurar(Evento e) => crear(EventoInput.desde(e));

  /// "Deshacer" de una sola repetición: vuelve esa fecha, sin regenerar la serie.
  Future<void> restaurarOcurrencia(Evento e) => crear(EventoInput.desde(e, frecuencia: 'unica'));

  /// Marca pagado/pendiente. Se aplica al instante en pantalla (optimista) y
  /// se revierte si el servidor falla.
  Future<void> alternarPago(Evento e) async {
    final nuevo = e.pagado ? 'pendiente' : 'pagado';
    final k = (parseYmd(e.fecha).year, parseYmd(e.fecha).month);
    final mes = _ref.read(monthProvider(k).notifier);
    mes.reemplazarEvento(e.copyWith(estadoPago: nuevo));
    try {
      await _api.put('/api/events/${e.id}/toggle-pago', body: {'estado_pago': nuevo});
    } catch (_) {
      mes.reemplazarEvento(e);
      rethrow;
    }
  }

  /// Todos los eventos del usuario (para la búsqueda).
  Future<List<Evento>> todos() async => parseList(await _api.get('/api/events'), Evento.fromJson);

  Future<List<Evento>> buscar(String texto) async {
    final q = texto.trim().toLowerCase();
    if (q.length < 2) return const [];
    final lista = await todos();
    return lista.where((e) => e.titulo.toLowerCase().contains(q) || e.ubicacion.toLowerCase().contains(q)).take(60).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  // ─────────────── Cumpleaños ───────────────

  Future<void> crearCumple(CumpleInput c) async {
    await _api.post('/api/cumpleanos', body: c.toBody());
    await _sync.despuesDeCambio(meses: false);
  }

  Future<void> actualizarCumple(int id, CumpleInput c) async {
    await _api.put('/api/cumpleanos/$id', body: c.toBody());
    await _sync.despuesDeCambio(meses: false);
  }

  Future<void> eliminarCumple(int id) async {
    await _api.delete('/api/cumpleanos/$id');
    await _sync.despuesDeCambio(meses: false);
  }

  Future<void> restaurarCumple(Cumple c) => crearCumple(CumpleInput(
        nombre: c.nombre,
        fecha: c.fecha,
        anioNacimiento: c.anioNacimiento,
        telefono: c.telefono,
        mensaje: c.mensaje,
      ));
}

final eventsRepoProvider = Provider((ref) => EventsRepository(ref.watch(apiProvider), ref.watch(sincronizadorProvider), ref));

/// Eventos del mes (clave: (año, mes 1..12)).
final eventosMesProvider = Provider.autoDispose.family<AsyncValue<List<Evento>>, (int, int)>((ref, k) {
  return ref.watch(monthProvider(k)).whenData((d) => d.eventos);
});

final cumplesProvider = Provider<AsyncValue<List<Cumple>>>((ref) => ref.watch(bootstrapProvider).whenData((b) => b.cumples));
