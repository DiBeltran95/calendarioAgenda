import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dates.dart';
import '../../core/net/json.dart';
import '../../core/net/tiempo_real.dart';
import '../../core/session.dart';
import '../notifications/push_service.dart';
import 'citas_models.dart';
import 'citas_repository.dart';

/// Mantiene la agenda al día sin que nadie tenga que refrescar:
///
/// 1. Eventos en vivo (SSE): la cita nueva o cancelada entra a la lista en el
///    mismo instante y se anuncia con un aviso dentro de la app.
/// 2. Push (FCM) con la app abierta: si el canal en vivo no lo trajo, el push
///    refresca y avisa (nunca los dos: se descartan duplicados por clave).
/// 3. Al reconectar, al volver a la app, al entrar a Citas y (sin canal en
///    vivo) cada 20 s: se piden las citas y se comparan con las que había,
///    así ningún cambio se pierde aunque se haya caído la red.
class CitasEnVivo {
  CitasEnVivo(this._ref, this._uid);
  final Ref _ref;
  final int _uid;

  static const _minEntreRefrescos = Duration(seconds: 3);
  static const _recordarAvisos = Duration(minutes: 10);

  final _mostrados = <String, DateTime>{};
  DateTime _ultimoRefresco = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _enCurso;

  /// Pide al servidor las citas que ya se están mostrando (a lo sumo una vez
  /// cada 3 s) y anuncia lo que haya cambiado mientras tanto.
  Future<void> refrescar({bool forzar = false}) {
    if (_uid == 0) return Future.value();
    final ahora = DateTime.now();
    if (_enCurso != null) return _enCurso!;
    if (!forzar && ahora.difference(_ultimoRefresco) < _minEntreRefrescos) return Future.value();
    _ultimoRefresco = ahora;
    return _enCurso = _refrescar().whenComplete(() => _enCurso = null);
  }

  Future<void> _refrescar() async {
    final hayAgenda = _ref.exists(citasAgendaProvider);
    final antes = hayAgenda ? _ref.read(citasAgendaProvider).value : null;
    await Future.wait([
      if (hayAgenda) _ref.read(citasAgendaProvider.notifier).refrescar(),
      if (_ref.exists(misReservasProvider)) _ref.read(misReservasProvider.notifier).refrescar(),
    ]);
    if (antes == null || !_ref.exists(citasAgendaProvider)) return;
    final despues = _ref.read(citasAgendaProvider).value;
    if (despues != null) _anunciar(cambiosEntre(antes, despues));
  }

  /// Aplica un evento `cita` del canal en vivo.
  void aplicar(EventoVivo e) {
    if (e.tipo != 'cita' || _uid == 0) return;
    final d = e.datos;
    final c = CitaAgenda.fromJson(asMap(d['cita']));
    if (c.id == 0) return;
    if (c.rol == 'cliente') {
      if (_ref.exists(misReservasProvider)) _ref.read(misReservasProvider.notifier).reemplazar(c);
    } else if (_ref.exists(citasAgendaProvider)) {
      _ref.read(citasAgendaProvider.notifier).reemplazar(c);
    }
    // Lo que hice yo (en este u otro dispositivo) no se me anuncia.
    if (asIntOrNull(d['actor']) == _uid) return;
    final aviso = avisoDeEvento(asString(d['tipo']), c);
    if (aviso != null) _anunciar([aviso]);
  }

  /// Push recibido con la app abierta.
  void desdePush(MensajePush m) {
    if (m.tipo != 'cita' || _uid == 0) return;
    // El push confirma que algo cambió: se trae ya, sin esperar.
    unawaited(refrescar(forzar: true));
    final partes = m.clave.split(':');
    _anunciar([
      AvisoVivo(
        clave: m.clave,
        tipo: m.clave.endsWith(':cancelada') ? TipoAvisoVivo.cancelada : TipoAvisoVivo.nueva,
        titulo: m.titulo.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), ''),
        cuerpo: m.cuerpo,
        citaId: partes.length > 1 ? int.tryParse(partes[1]) : null,
      ),
    ]);
  }

  void _anunciar(List<AvisoVivo> avisos) {
    final ahora = DateTime.now();
    _mostrados.removeWhere((_, t) => ahora.difference(t) > _recordarAvisos);
    final nuevos = [
      for (final a in avisos)
        if (!_mostrados.containsKey(a.clave)) a,
    ];
    if (nuevos.isEmpty) return;
    for (final a in nuevos) {
      _mostrados[a.clave] = ahora;
      if (a.tipo == TipoAvisoVivo.nueva && a.citaId != null) _ref.read(citasRecientesProvider.notifier).marcar(a.citaId!);
    }
    final aviso = nuevos.length == 1
        ? nuevos.first
        : AvisoVivo(
            clave: 'varios',
            tipo: nuevos.every((a) => a.tipo == TipoAvisoVivo.cancelada) ? TipoAvisoVivo.cancelada : TipoAvisoVivo.nueva,
            titulo: '${nuevos.length} novedades en tu agenda',
            cuerpo: nuevos.map((a) => a.titulo).join(' · '),
          );
    _ref.read(avisoVivoProvider.notifier).mostrar(aviso);
    unawaited(aviso.tipo == TipoAvisoVivo.cancelada ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact());
  }
}

/// Aviso que corresponde a un evento en vivo (null si no amerita interrumpir).
AvisoVivo? avisoDeEvento(String tipo, CitaAgenda c) {
  final cuando = '${fechaRelativa(c.fecha)} · ${hora12(c.horaInicio)}';
  if (c.rol == 'cliente') {
    if (tipo != 'cancelada') return null;
    return AvisoVivo(
      clave: 'cita:${c.id}:cliente-cancelada',
      tipo: TipoAvisoVivo.cancelada,
      titulo: 'Tu cita en ${c.negocioNombre} fue cancelada',
      cuerpo: '${c.servicioNombre} · $cuando',
      citaId: c.id,
      fecha: c.fecha,
    );
  }
  final equipo = c.rol == 'equipo' ? ' · ${c.negocioNombre}' : '';
  return switch (tipo) {
    'confirmada' || 'nueva' => AvisoVivo(
        clave: 'cita:${c.id}:nueva',
        tipo: TipoAvisoVivo.nueva,
        titulo: 'Nueva cita: ${c.clienteNombre}',
        cuerpo: '${c.servicioNombre} · $cuando$equipo',
        citaId: c.id,
        fecha: c.fecha,
      ),
    'cancelada' => AvisoVivo(
        clave: 'cita:${c.id}:cancelada',
        tipo: TipoAvisoVivo.cancelada,
        titulo: 'Cita cancelada: ${c.clienteNombre}',
        cuerpo: '${c.servicioNombre} · $cuando · el espacio quedó libre',
        citaId: c.id,
        fecha: c.fecha,
      ),
    _ => null,
  };
}

/// Lo que cambió entre dos versiones de la agenda (al sincronizar sin canal en vivo).
List<AvisoVivo> cambiosEntre(List<CitaAgenda> antes, List<CitaAgenda> despues, {String? hoy}) {
  final previo = {for (final c in antes) c.id: c.estado};
  final desde = hoy ?? hoyYmd();
  final avisos = <AvisoVivo>[];
  for (final c in despues) {
    if (c.fecha.compareTo(desde) < 0) continue;
    final p = previo[c.id];
    if (c.estado == EstadoCita.confirmada && (p == null || p == EstadoCita.pendiente || p == EstadoCita.expirada)) {
      // Las que el dueño agenda a mano ya las conoce.
      if (p == null && c.origen == 'negocio' && c.rol == 'dueno') continue;
      avisos.add(avisoDeEvento('confirmada', c)!);
    } else if (c.estado == EstadoCita.cancelada && p != null && p != EstadoCita.cancelada && p != EstadoCita.expirada) {
      avisos.add(avisoDeEvento('cancelada', c)!);
    }
  }
  return avisos;
}

final citasEnVivoProvider = Provider<CitasEnVivo>((ref) {
  final uid = ref.watch(usuarioIdProvider);
  final c = CitasEnVivo(ref, uid);
  if (uid == 0) return c;
  final vivo = ref.read(tiempoRealProvider);
  final subs = [
    vivo.eventos.listen(c.aplicar),
    vivo.sincronizar.listen((_) => c.refrescar()),
    ref.read(servicioPushProvider).recibidos.listen(c.desdePush),
  ];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
  });
  return c;
});

// ─────────────────────── Aviso dentro de la app ───────────────────────

enum TipoAvisoVivo { nueva, cancelada }

class AvisoVivo {
  AvisoVivo({required this.clave, required this.tipo, required this.titulo, required this.cuerpo, this.citaId, this.fecha}) : id = ++_secuencia;
  static int _secuencia = 0;

  final int id;
  final String clave;
  final TipoAvisoVivo tipo;
  final String titulo;
  final String cuerpo;
  final int? citaId;
  final String? fecha;
}

/// Aviso visible en la parte superior (se oculta solo a los 6 s).
class AvisoVivoNotifier extends Notifier<AvisoVivo?> {
  static const duracion = Duration(seconds: 6);
  Timer? _t;

  @override
  AvisoVivo? build() {
    ref.onDispose(() => _t?.cancel());
    return null;
  }

  void mostrar(AvisoVivo a) {
    _t?.cancel();
    state = a;
    _t = Timer(duracion, cerrar);
  }

  /// Mantiene el aviso mientras el usuario lo toca o lo arrastra.
  void sostener() => _t?.cancel();

  void soltar() {
    _t?.cancel();
    if (state != null) _t = Timer(const Duration(seconds: 3), cerrar);
  }

  void cerrar() {
    _t?.cancel();
    state = null;
  }
}

final avisoVivoProvider = NotifierProvider<AvisoVivoNotifier, AvisoVivo?>(AvisoVivoNotifier.new);

/// Citas que acaban de llegar: se resaltan en la agenda durante 2 minutos.
class CitasRecientes extends Notifier<Set<int>> {
  final _timers = <int, Timer>{};

  @override
  Set<int> build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
    });
    return const {};
  }

  void marcar(int id) {
    _timers[id]?.cancel();
    _timers[id] = Timer(const Duration(minutes: 2), () {
      _timers.remove(id);
      state = {...state}..remove(id);
    });
    state = {...state, id};
  }
}

final citasRecientesProvider = NotifierProvider<CitasRecientes, Set<int>>(CitasRecientes.new);

/// Cita que hay que abrir en la agenda (al tocar un aviso).
class CitaPorAbrir extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? id) => state = id;
}

final citaPorAbrirProvider = NotifierProvider<CitaPorAbrir, int?>(CitaPorAbrir.new);
