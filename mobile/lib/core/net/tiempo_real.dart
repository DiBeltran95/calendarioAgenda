import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session.dart';

/// Cambios en vivo desde el backend con Server-Sent Events (`GET /api/tiempo-real`).
///
/// Mientras la app está en pantalla mantiene UNA conexión HTTP abierta por la
/// que el servidor empuja cada cambio en el instante en que ocurre (una cita
/// nueva, una cancelación…). Es el mismo mecanismo de los tableros en vivo de
/// muchas apps: sin servicios de terceros, sin costo y casi sin batería (un
/// latido de pocos bytes cada 25 s).
///
/// Robustez:
/// * Vigía: si pasan 60 s sin datos (red móvil que cortó en silencio), reconecta.
/// * Reintentos con espera exponencial y aleatoria (no satura el servidor).
/// * Cada (re)conexión emite [sincronizar] para recuperar lo que se perdió.
/// * Si el canal no llega a funcionar (un proxy que lo bloquea, un servidor
///   sin la ruta), pasa a modo respaldo: pide los datos cada 20 s.
/// * En segundo plano se desconecta; allí avisan las notificaciones push.
class TiempoReal {
  TiempoReal(this._dio, {Random? azar}) : _azar = azar ?? Random();

  final Dio Function() _dio;
  final Random _azar;

  static const ruta = '/api/tiempo-real';
  static const esperaSaludo = Duration(seconds: 15);
  static const latidoMaximo = Duration(seconds: 60);
  static const intervaloRespaldo = Duration(seconds: 20);
  static const graciaSegundoPlano = Duration(seconds: 10);
  static const fallosParaRespaldo = 3;

  final estado = ValueNotifier(EstadoVivo.apagado);
  final _eventos = StreamController<EventoVivo>.broadcast();
  final _sincronizar = StreamController<void>.broadcast();

  /// Eventos del servidor (p. ej. `cita`).
  Stream<EventoVivo> get eventos => _eventos.stream;

  /// Momentos en que conviene volver a pedir los datos: al (re)conectar y,
  /// en modo respaldo, cada [intervaloRespaldo].
  Stream<void> get sincronizar => _sincronizar.stream;

  bool _activo = false;
  bool _pausado = false;
  bool _sinCanal = false;
  int _fallos = 0;
  int _generacion = 0;
  DateTime _ultimoDato = DateTime.fromMillisecondsSinceEpoch(0);
  void Function()? _cortar;
  Timer? _reintento;
  Timer? _respaldo;
  Timer? _gracia;

  bool get conectado => estado.value == EstadoVivo.enVivo;

  /// Abre el canal (al iniciar sesión).
  void iniciar() {
    if (_activo) return;
    _activo = true;
    _pausado = false;
    _sinCanal = kIsWeb; // En web el navegador no entrega el flujo por partes: respaldo.
    _fallos = 0;
    _conectar();
  }

  /// Cierra todo (al cerrar sesión).
  void detener() {
    _activo = false;
    _desconectar();
    _poner(EstadoVivo.apagado);
  }

  /// La app pasó a segundo plano: tras una breve gracia (cambiar de app un
  /// momento no cuesta una reconexión) se suelta la conexión.
  void pausar() {
    if (!_activo || _pausado) return;
    _gracia?.cancel();
    _gracia = Timer(graciaSegundoPlano, () {
      _pausado = true;
      _desconectar();
      _poner(EstadoVivo.apagado);
    });
  }

  /// La app volvió a primer plano: reconecta si hace falta y sincroniza.
  void reanudar() {
    _gracia?.cancel();
    if (!_activo) return;
    _pausado = false;
    // Tras una suspensión la conexión puede verse "abierta" sin estarlo.
    final fresca = _cortar != null && DateTime.now().difference(_ultimoDato) < const Duration(seconds: 35);
    if (!fresca) {
      _desconectar();
      _fallos = 0;
      _conectar();
    }
    _sincronizar.add(null);
  }

  void _desconectar() {
    _generacion++; // Un intento en curso ya no reprograma nada.
    _reintento?.cancel();
    _respaldo?.cancel();
    _respaldo = null;
    final c = _cortar;
    _cortar = null;
    c?.call();
  }

  void _poner(EstadoVivo e) {
    if (estado.value != e) estado.value = e;
  }

  Future<void> _conectar() async {
    _reintento?.cancel();
    if (!_activo || _pausado || _cortar != null) return;
    if (_sinCanal) {
      _modoRespaldo();
      return;
    }
    if (_respaldo == null) _poner(EstadoVivo.conectando);

    final gen = _generacion;
    final cancel = CancelToken();
    final fin = Completer<void>();
    StreamSubscription<String>? sub;
    Timer? vigia;
    var saludo = false;
    var definitivo = false;

    void terminar() {
      if (!fin.isCompleted) fin.complete();
    }

    void cortar() {
      vigia?.cancel();
      if (!cancel.isCancelled) cancel.cancel();
      unawaited(sub?.cancel());
      terminar();
    }

    void vigilar() {
      vigia?.cancel();
      vigia = Timer(saludo ? latidoMaximo : esperaSaludo, cortar);
    }

    _cortar = cortar;
    try {
      final r = await _dio().get<ResponseBody>(
        ruta,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: esperaSaludo,
          headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
        ),
      );
      if (!identical(_cortar, cortar)) return;
      final lector = LectorSse();
      vigilar();
      sub = r.data!.stream
          .map((b) {
            _ultimoDato = DateTime.now();
            vigilar();
            return b;
          })
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (linea) {
              final ev = lector.linea(linea);
              if (ev == null) return;
              if (ev.evento == 'hola') {
                saludo = true;
                _fallos = 0;
                vigilar();
                _respaldo?.cancel();
                _respaldo = null;
                _poner(EstadoVivo.enVivo);
                _sincronizar.add(null);
                return;
              }
              try {
                final datos = jsonDecode(ev.datos);
                if (datos is Map<String, dynamic>) _eventos.add(EventoVivo(ev.evento, datos));
              } catch (_) {
                // Un evento malformado no tumba el canal.
              }
            },
            onError: (Object _) => terminar(),
            onDone: terminar,
            cancelOnError: true,
          );
      await fin.future;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 405) {
        _sinCanal = true; // Servidor sin la ruta: no se insiste.
      } else if (status == 401 || status == 403) {
        definitivo = true; // Sesión vencida: el resto de la app cierra la sesión.
      }
    } catch (_) {
      // Error de red: se reintenta abajo.
    } finally {
      vigia?.cancel();
      if (identical(_cortar, cortar)) _cortar = null;
    }

    if (gen != _generacion || !_activo || _pausado || definitivo) {
      if (definitivo) _poner(EstadoVivo.apagado);
      return;
    }
    if (!saludo) _fallos++;
    if (_sinCanal || _fallos >= fallosParaRespaldo) {
      _modoRespaldo();
    } else if (_respaldo == null) {
      _poner(EstadoVivo.conectando);
    }
    if (_sinCanal) return;
    _reintento = Timer(esperaReintento(_fallos, _azar), _conectar);
  }

  void _modoRespaldo() {
    if (_respaldo != null) return;
    _poner(EstadoVivo.respaldo);
    _sincronizar.add(null);
    _respaldo = Timer.periodic(intervaloRespaldo, (_) {
      if (_activo && !_pausado) _sincronizar.add(null);
    });
  }

  /// 1 s, 2 s, 4 s… hasta 60 s, más hasta 1 s aleatorio para que miles de
  /// teléfonos no reconecten todos a la vez tras un reinicio del servidor.
  @visibleForTesting
  static Duration esperaReintento(int fallos, Random azar) {
    final base = min(60, 1 << min(fallos, 6));
    return Duration(milliseconds: base * 1000 + azar.nextInt(1000));
  }

  void dispose() {
    detener();
    _gracia?.cancel();
    unawaited(_eventos.close());
    unawaited(_sincronizar.close());
    estado.dispose();
  }
}

enum EstadoVivo {
  /// Sin sesión o en segundo plano.
  apagado,
  conectando,

  /// Canal abierto: los cambios llegan al instante.
  enVivo,

  /// El canal no funciona en esta red: se consulta cada 20 s.
  respaldo,
}

class EventoVivo {
  const EventoVivo(this.tipo, this.datos);
  final String tipo;
  final Map<String, dynamic> datos;
}

/// Interpreta un flujo `text/event-stream` línea a línea (especificación WHATWG).
class LectorSse {
  String _evento = '';
  final _datos = <String>[];

  /// Procesa una línea; devuelve el evento completo al llegar la línea vacía.
  ({String evento, String datos})? linea(String l) {
    if (l.isEmpty) {
      if (_datos.isEmpty) {
        _evento = '';
        return null;
      }
      final ev = (evento: _evento.isEmpty ? 'message' : _evento, datos: _datos.join('\n'));
      _evento = '';
      _datos.clear();
      return ev;
    }
    if (l.startsWith(':')) return null; // Comentario (latido).
    final i = l.indexOf(':');
    final campo = i < 0 ? l : l.substring(0, i);
    var valor = i < 0 ? '' : l.substring(i + 1);
    if (valor.startsWith(' ')) valor = valor.substring(1);
    switch (campo) {
      case 'event':
        _evento = valor;
      case 'data':
        _datos.add(valor);
    }
    return null;
  }
}

final tiempoRealProvider = Provider<TiempoReal>((ref) {
  final t = TiempoReal(() => ref.read(apiProvider).dio);
  ref.onDispose(t.dispose);
  return t;
});

/// Mantiene el canal abierto mientras hay sesión (lo observa el shell).
final canalVivoProvider = Provider<void>((ref) {
  final uid = ref.watch(usuarioIdProvider);
  if (uid == 0) return;
  final t = ref.read(tiempoRealProvider);
  t.iniciar();
  ref.onDispose(t.detener);
});
