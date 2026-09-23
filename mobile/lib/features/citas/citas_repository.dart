import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/api_client.dart';
import '../../core/net/api_exception.dart';
import '../../core/net/json.dart';
import '../../core/providers.dart';
import '../../core/session.dart';
import '../../data/sync.dart';
import 'citas_models.dart';

// ─────────────────────── Configuración del negocio ───────────────────────

class ConfigAgendaNotifier extends AsyncNotifier<ConfigAgenda> with CacheRed<ConfigAgenda> {
  @override
  String get claveCache => 'agenda:config';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/agenda');

  @override
  ConfigAgenda parsear(Object? json) => json == null ? ConfigAgenda.vacia : ConfigAgenda.fromJson(asMap(json));

  @override
  Object? serializar(ConfigAgenda v) => v.toJson();

  @override
  Future<ConfigAgenda> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }

  /// Las rutas de configuración devuelven la configuración completa.
  Future<void> aplicar(Object? json) async {
    final v = parsear(json);
    state = AsyncData(v);
    await ref.read(databaseProvider).escribirCache('u${ref.read(usuarioIdProvider)}:$claveCache', jsonEncode(v.toJson()));
  }
}

final configAgendaProvider = AsyncNotifierProvider<ConfigAgendaNotifier, ConfigAgenda>(ConfigAgendaNotifier.new, retry: sinReintento);

// ─────────────────────── Citas del negocio ───────────────────────

class CitasNotifier extends AsyncNotifier<List<CitaAgenda>> with CacheRed<List<CitaAgenda>> {
  @override
  String get claveCache => 'agenda:citas';

  @override
  Future<Object?> pedir() {
    final hoy = hoyYmd();
    return ref.read(apiProvider).get('/api/agenda/citas', query: {'desde': sumarDiasYmd(hoy, -60), 'hasta': sumarDiasYmd(hoy, 120)});
  }

  @override
  List<CitaAgenda> parsear(Object? json) => parseList(json, CitaAgenda.fromJson);

  @override
  Object? serializar(List<CitaAgenda> v) => [for (final c in v) c.toJson()];

  @override
  Future<List<CitaAgenda>> build() {
    ref.watch(usuarioIdProvider);
    listenSelf((_, next) => _programarVencimiento(next.value));
    ref.onDispose(() => _vence?.cancel());
    return cargar();
  }

  Timer? _vence;

  /// Una reserva sin confirmar aparta el turno 15 minutos. Cuando vence, la
  /// lista se actualiza sola (el servidor no avisa de esto: es solo el tiempo).
  void _programarVencimiento(List<CitaAgenda>? citas) {
    _vence?.cancel();
    final proximo = citas?.map((c) => c.vence).nonNulls.fold<DateTime?>(null, (m, v) => m == null || v.isBefore(m) ? v : m);
    if (proximo == null) return;
    final espera = proximo.difference(DateTime.now().toUtc()) + const Duration(seconds: 1);
    _vence = Timer(espera.isNegative ? Duration.zero : espera, () {
      final l = state.value;
      if (l != null && ref.mounted) fijar([for (final c in l) c.vigente()]);
    });
  }

  void reemplazar(CitaAgenda c) => fijar(_conCita(state.value, c, (a, b) => '${a.fecha}${a.horaInicio}'.compareTo('${b.fecha}${b.horaInicio}')));
}

/// Inserta o actualiza una cita en la lista, conservando el orden.
List<CitaAgenda> _conCita(List<CitaAgenda>? lista, CitaAgenda c, int Function(CitaAgenda, CitaAgenda) orden) {
  final nueva = [...?lista];
  final i = nueva.indexWhere((x) => x.id == c.id);
  if (i >= 0) {
    nueva[i] = c;
  } else {
    nueva.add(c);
  }
  return nueva..sort(orden);
}

final citasAgendaProvider = AsyncNotifierProvider<CitasNotifier, List<CitaAgenda>>(CitasNotifier.new, retry: sinReintento);

/// Citas que el usuario reservó como cliente (desde la app).
class MisReservasNotifier extends AsyncNotifier<List<CitaAgenda>> with CacheRed<List<CitaAgenda>> {
  @override
  String get claveCache => 'agenda:mis-reservas';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/agenda/mis-reservas');

  @override
  List<CitaAgenda> parsear(Object? json) => parseList(json, CitaAgenda.fromJson);

  @override
  Object? serializar(List<CitaAgenda> v) => [for (final c in v) c.toJson()];

  @override
  Future<List<CitaAgenda>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }

  void reemplazar(CitaAgenda c) => fijar(_conCita(state.value, c, (a, b) => '${b.fecha}${b.horaInicio}'.compareTo('${a.fecha}${a.horaInicio}')));
}

final misReservasProvider = AsyncNotifierProvider<MisReservasNotifier, List<CitaAgenda>>(MisReservasNotifier.new, retry: sinReintento);

// ─────────────────────── Operaciones ───────────────────────

/// Error de negocio con el mensaje del servidor (y si el turno se ocupó).
class AgendaError implements Exception {
  AgendaError(this.mensaje, {this.ocupado = false, this.status});
  final String mensaje;
  final bool ocupado;
  final int? status;
  @override
  String toString() => mensaje;

  static AgendaError desde(Object e) {
    if (e is ApiException) {
      return AgendaError(e.message, ocupado: e.data?['codigo'] == 'ocupado', status: e.statusCode);
    }
    return AgendaError('Algo salió mal. Inténtalo de nuevo.');
  }
}

class AgendaRepository {
  AgendaRepository(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiProvider);
  ConfigAgendaNotifier get _config => _ref.read(configAgendaProvider.notifier);

  Future<T> _intentar<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw AgendaError.desde(e);
    }
  }

  /// ¿El enlace está libre? Devuelve también una sugerencia.
  Future<({bool disponible, bool valido, String sugerido})> verificarSlug(String slug) => _intentar(() async {
        final r = asMap(await _api.get('/api/agenda/slug', query: {'slug': slug}));
        return (disponible: asBool(r['disponible']), valido: asBool(r['valido']), sugerido: asString(r['sugerido']));
      });

  Future<void> guardarNegocio(Map<String, dynamic> datos) => _intentar(() async => _config.aplicar(await _api.put('/api/agenda/negocio', body: datos)));

  Future<void> guardarProfesional(Map<String, dynamic> datos, {int? id}) => _intentar(() async {
        final r = id == null ? await _api.post('/api/agenda/profesionales', body: datos) : await _api.put('/api/agenda/profesionales/$id', body: datos);
        await _config.aplicar(r);
      });

  Future<void> eliminarProfesional(int id) => _intentar(() async => _config.aplicar(await _api.delete('/api/agenda/profesionales/$id')));

  Future<void> guardarServicio(Map<String, dynamic> datos, {int? id}) => _intentar(() async {
        final r = id == null ? await _api.post('/api/agenda/servicios', body: datos) : await _api.put('/api/agenda/servicios/$id', body: datos);
        await _config.aplicar(r);
      });

  Future<void> eliminarServicio(int id) => _intentar(() async => _config.aplicar(await _api.delete('/api/agenda/servicios/$id')));

  Future<void> crearBloqueo(Map<String, dynamic> datos) => _intentar(() async => _config.aplicar(await _api.post('/api/agenda/bloqueos', body: datos)));

  Future<void> eliminarBloqueo(int id) => _intentar(() async => _config.aplicar(await _api.delete('/api/agenda/bloqueos/$id')));

  /// Cita agendada por el negocio (cliente que llama o llega): queda confirmada.
  Future<CitaAgenda> crearCita(Map<String, dynamic> datos) => _intentar(() async {
        final c = CitaAgenda.fromJson(asMap(await _api.post('/api/agenda/citas', body: datos)));
        _ref.read(citasAgendaProvider.notifier).reemplazar(c);
        _despues();
        return c;
      });

  /// Completar, marcar inasistencia o cancelar (optimista: se ve al instante).
  Future<CitaAgenda> cambiarEstado(CitaAgenda cita, EstadoCita estado, {String? motivo}) async {
    final citas = _ref.read(citasAgendaProvider.notifier);
    citas.reemplazar(cita.copyWith(estado: estado));
    try {
      final c = CitaAgenda.fromJson(asMap(await _api.put('/api/agenda/citas/${cita.id}', body: {'estado': estado.api, 'motivo': ?motivo})));
      citas.reemplazar(c);
      if (estado == EstadoCita.cancelada) _despues();
      return c;
    } catch (e) {
      citas.reemplazar(cita);
      throw AgendaError.desde(e);
    }
  }

  /// Las citas confirmadas crean eventos en el calendario: se refrescan.
  void _despues() {
    // En segundo plano: un fallo al refrescar no debe afectar a la cita.
    unawaited(_ref.read(sincronizadorProvider).despuesDeCambio(bootstrap: false).catchError((Object _) {}));
  }

  Future<void> refrescar() async {
    await Future.wait([
      _ref.read(configAgendaProvider.notifier).refrescar(),
      _ref.read(citasAgendaProvider.notifier).refrescar(),
      _ref.read(misReservasProvider.notifier).refrescar(),
    ]);
  }

  // ─────────── Reservar como cliente (rutas públicas) ───────────

  Future<PaginaAgenda> pagina(String slug) => _intentar(() async => PaginaAgenda.fromJson(asMap(await _api.get('/api/public/agenda/$slug', publico: true))));

  Future<List<DiaTurnos>> disponibilidad(String slug, {required int servicio, int profesional = 0, required String desde, int dias = 14}) => _intentar(() async {
        final r = asMap(await _api.get(
          '/api/public/agenda/$slug/disponibilidad',
          query: {'servicio': servicio, 'profesional': profesional, 'desde': desde, 'dias': dias},
          publico: true,
        ));
        return parseList(r['dias'], DiaTurnos.fromJson);
      });

  /// Con sesión: la reserva queda en "Mis reservas" y el aviso llega a la app.
  Future<ReservaPublica> reservar(String slug, Map<String, dynamic> datos) =>
      _intentar(() async => ReservaPublica.fromJson(asMap(await _api.post('/api/public/agenda/$slug/reservas', body: datos))));

  Future<ReservaPublica> confirmar(String token, String codigo) => _intentar(() async {
        final r = ReservaPublica.fromJson(asMap(await _api.post('/api/public/agenda/citas/$token/confirmar', body: {'codigo': codigo}, publico: true)));
        unawaited(_ref.read(misReservasProvider.notifier).refrescar());
        return r;
      });

  Future<void> reenviar(String token) => _intentar(() async => _api.post('/api/public/agenda/citas/$token/reenviar', publico: true));
}

final agendaRepoProvider = Provider(AgendaRepository.new);

// ─────────────────────── Derivados ───────────────────────

/// Citas vigentes o recientes, agrupadas por fecha (para la agenda).
final citasPorDiaProvider = Provider<Map<String, List<CitaAgenda>>>((ref) {
  final citas = ref.watch(citasAgendaProvider).value ?? const <CitaAgenda>[];
  final out = <String, List<CitaAgenda>>{};
  for (final c in citas) {
    if (c.estado == EstadoCita.expirada) continue;
    (out[c.fecha] ??= []).add(c);
  }
  for (final l in out.values) {
    l.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
  }
  return out;
});

/// Resumen para la cabecera del módulo.
class ResumenCitas {
  const ResumenCitas({required this.hoy, required this.semana, required this.porConfirmar, required this.ingresosSemana, this.proxima});
  final int hoy;
  final int semana;
  final int porConfirmar;
  final double ingresosSemana;
  final CitaAgenda? proxima;
}

final resumenCitasProvider = Provider<ResumenCitas>((ref) {
  final citas = ref.watch(citasAgendaProvider).value ?? const <CitaAgenda>[];
  final hoy = hoyYmd();
  final finSemana = sumarDiasYmd(hoy, 7);
  final ahora = DateTime.now();
  final horaAhora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
  final activas = citas.where((c) => c.estado == EstadoCita.confirmada || c.estado == EstadoCita.completada);
  final futuras = citas
      .where((c) => c.estado == EstadoCita.confirmada && (c.fecha.compareTo(hoy) > 0 || (c.fecha == hoy && c.horaFin.compareTo(horaAhora) > 0)))
      .toList()
    ..sort((a, b) => '${a.fecha}${a.horaInicio}'.compareTo('${b.fecha}${b.horaInicio}'));
  return ResumenCitas(
    hoy: activas.where((c) => c.fecha == hoy).length,
    semana: activas.where((c) => c.fecha.compareTo(hoy) >= 0 && c.fecha.compareTo(finSemana) < 0).length,
    porConfirmar: citas.where((c) => c.estado == EstadoCita.pendiente).length,
    ingresosSemana: activas.where((c) => c.fecha.compareTo(hoy) >= 0 && c.fecha.compareTo(finSemana) < 0).fold(0, (s, c) => s + c.precio),
    proxima: futuras.firstOrNull,
  );
});
