// Backend falso en memoria que imita a backend/server.ts.
//
// Responde con las mismas formas que MySQL + Fastify: DECIMAL como texto
// ("1500.00"), booleanos 0/1, TIME como "HH:MM:SS", errores `{ message }` y
// 401 de @fastify/jwt. Se conecta a Dio como HttpClientAdapter, así las
// pruebas ejercitan el cliente real sin tocar la red.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:agendaservi/features/events/events_repository.dart' show fechaOcurrencia, maxOcurrencias;
import 'package:agendaservi/features/finance/finance_logic.dart' show cobrosTarjeta, esCredito;
import 'package:agendaservi/core/dates.dart' show sumarDiasYmd;
import 'package:dio/dio.dart';

part 'fake_agenda.dart';

String _dec(num v) => v.toDouble().toStringAsFixed(2);

class _Resp {
  const _Resp(this.status, this.body);
  final int status;
  final Object? body;
}

class FakeBackend implements HttpClientAdapter {
  FakeBackend() {
    // Usuario verificado de ejemplo.
    usuarios.add({'id': 1, 'nombre': 'Diego Beltrán', 'email': 'diego@test.co', 'password': 'secreta', 'whatsapp': '573001234567', 'verificado': 1, 'codigo': null});
    for (final (v, l, i) in const [
      ('comida', 'Comida', 'restaurant'),
      ('transporte', 'Transporte', 'directions_car'),
      ('servicios', 'Servicios/Facturas', 'receipt_long'),
      ('ahorro', 'Ahorro/Inversión', 'savings'),
      ('otros', 'Otros', 'payments'),
    ]) {
      categorias.add({'id': _id(), 'user_id': 1, 'valor': v, 'label': l, 'icono': i, 'es_default': 1});
    }
  }

  // Tablas.
  final usuarios = <Map<String, dynamic>>[];
  final eventos = <Map<String, dynamic>>[];
  final cumples = <Map<String, dynamic>>[];
  final ciclos = <Map<String, dynamic>>[];
  final cuentas = <Map<String, dynamic>>[];
  final transacciones = <Map<String, dynamic>>[];
  final transferencias = <Map<String, dynamic>>[];
  final planes = <Map<String, dynamic>>[];
  final verificaciones = <Map<String, dynamic>>[];
  final metas = <Map<String, dynamic>>[];
  final presupuestos = <Map<String, dynamic>>[];
  final categorias = <Map<String, dynamic>>[];
  final dispositivos = <Map<String, dynamic>>[];
  final capturas = <Map<String, dynamic>>[];
  final clavesAtajo = <int, String>{};

  /// Como POST /api/capturas/atajo (el Atajo de iPhone): guarda y avisa en vivo.
  Map<String, dynamic> pagoApplePay(int uid, {required num monto, String comercio = '', String tarjeta = ''}) {
    final c = {
      'id': _id(), 'user_id': uid, 'origen': 'apple_pay', 'tipo': 'gasto', 'monto': monto, 'moneda': 'COP', 'comercio': comercio, 'tarjeta': tarjeta,
      'app': '', 'texto': '', 'fecha': DateTime.now().toUtc().toIso8601String(), 'estado': 'pendiente', 'transaccion_id': null, 'categoria': null, 'cuenta_id': null,
    };
    capturas.add(c);
    emitir(uid, 'captura', {'captura': c});
    return c;
  }

  final inversiones = <Map<String, dynamic>>[];

  /// Servidor sin desplegar: la ruta de inversiones aún no existe.
  bool sinInversiones = false;

  /// Como lib/finanzas/inversiones.ts: mover dinero cambia el saldo de la cuenta
  /// sin crear una transacción.
  void _moverCuenta(Map<String, dynamic> mov, int signo) {
    final id = mov['cuenta_id'] as int?;
    if (id == null || mov['tipo'] == 'valoracion') return;
    final credito = esCredito(_cuenta(id)['tipo'] as String);
    final monto = (mov['monto'] as num).toDouble();
    final efecto = (mov['tipo'] == 'aporte') == credito ? monto : -monto;
    _saldo(id, efecto * signo);
  }

  Map<String, dynamic> _movimiento(Map<String, dynamic> b) {
    final cuenta = b['tipo'] == 'valoracion' ? null : b['cuenta_id'] as int?;
    return {
      'id': _id(),
      'tipo': b['tipo'],
      'monto': b['monto'],
      'fecha': b['fecha'],
      'cuenta_id': cuenta,
      'cuenta_nombre': cuenta == null ? null : _cuenta(cuenta)['nombre'],
      'nota': b['nota'] ?? '',
    };
  }

  _Resp _inversiones(String m, List<String> seg, Map<String, dynamic> b, int uid) {
    if (sinInversiones) return _err(404, 'Route not found');
    final id = seg.length > 3 ? int.tryParse(seg[3]) : null;
    List<Map<String, dynamic>> movs(Map<String, dynamic> i) => (i['movimientos'] as List).cast<Map<String, dynamic>>();
    if (seg[2] == 'inversion-movimientos') {
      final duena = inversiones.firstWhere((i) => i['user_id'] == uid && movs(i).any((x) => x['id'] == id));
      final viejo = movs(duena).firstWhere((x) => x['id'] == id);
      _moverCuenta(viejo, -1);
      final lugar = movs(duena).indexOf(viejo);
      movs(duena).removeAt(lugar);
      if (m == 'PUT') {
        final nuevo = {..._movimiento(b), 'id': id};
        _moverCuenta(nuevo, 1);
        movs(duena).insert(lugar, nuevo);
      }
      return const _Resp(200, {'ok': true});
    }
    switch (m) {
      case 'GET':
        return _Resp(200, inversiones.where((i) => i['user_id'] == uid).toList().reversed.toList());
      case 'POST' when seg.length > 4:
        final i = inversiones.firstWhere((x) => x['id'] == id && x['user_id'] == uid);
        final mov = _movimiento(b);
        _moverCuenta(mov, 1);
        movs(i).add(mov);
        return _Resp(200, {'id': mov['id']});
      case 'POST':
        final mov = _movimiento({...b, 'tipo': 'aporte'});
        _moverCuenta(mov, 1);
        final i = {'id': _id(), 'user_id': uid, 'nombre': b['nombre'], 'tipo': b['tipo'], 'nota': b['nota'] ?? '', 'movimientos': [mov]};
        inversiones.add(i);
        return _Resp(200, {'id': i['id']});
      case 'PUT':
        final i = inversiones.firstWhere((x) => x['id'] == id && x['user_id'] == uid);
        i.addAll({'nombre': b['nombre'], 'tipo': b['tipo'], 'nota': b['nota'] ?? ''});
        return const _Resp(200, {'ok': true});
      case 'DELETE':
        final i = inversiones.firstWhere((x) => x['id'] == id && x['user_id'] == uid);
        for (final x in movs(i)) {
          _moverCuenta(x, -1);
        }
        inversiones.remove(i);
        return const _Resp(200, {'ok': true});
    }
    return _err(404, 'No existe');
  }

  _Resp _capturas(String m, List<String> seg, Map<String, dynamic> q, Map<String, dynamic> b, int uid) {
    final accion = seg.length > 2 ? seg[2] : '';
    final mias = capturas.where((c) => c['user_id'] == uid);
    switch ((m, accion)) {
      case ('GET', ''):
        final estado = '${q['estado'] ?? 'pendiente'}';
        return _Resp(200, mias.where((c) => c['estado'] == estado).toList()..sort((a, z) => '${z['fecha']}'.compareTo('${a['fecha']}')));
      case ('POST', ''):
        var nuevas = 0;
        final lista = (b['capturas'] as List? ?? const []).cast<Map>();
        for (final x in lista) {
          final dup = mias.any((c) => c['monto'] == x['monto'] && c['comercio'] == x['comercio'] && '${c['fecha']}'.substring(0, 16) == '${x['fecha']}'.substring(0, 16));
          if (dup) continue;
          capturas.add({...Map<String, dynamic>.from(x), 'id': _id(), 'user_id': uid, 'estado': 'pendiente', 'moneda': 'COP'});
          nuevas++;
        }
        return _Resp(200, {'recibidas': lista.length, 'nuevas': nuevas});
      case ('GET', 'preferencias'):
        return _Resp(200, [
          for (final c in mias.where((c) => c['estado'] == 'registrada' && c['categoria'] != null))
            {'comercio': c['comercio'], 'tarjeta': c['tarjeta'], 'categoria': c['categoria'], 'cuenta_id': c['cuenta_id']},
        ]);
      case ('GET', 'clave'):
        return _Resp(200, {'clave': clavesAtajo.putIfAbsent(uid, () => 'a' * 40), 'usado': null});
      case ('POST', 'clave'):
        return _Resp(200, {'clave': clavesAtajo[uid] = 'b' * 40, 'usado': null});
      case ('PUT', _):
        final c = mias.where((c) => '${c['id']}' == accion).firstOrNull;
        if (c == null) return _err(404, 'Pago no encontrado');
        c
          ..['estado'] = b['estado']
          ..['transaccion_id'] = b['transaccion_id']
          ..['categoria'] = b['categoria']
          ..['cuenta_id'] = b['cuenta_id'];
        return _Resp(200, c);
    }
    return _err(404, 'Ruta de capturas no encontrada');
  }
  late final agenda = FakeAgenda(this);

  /// Lo que hace el cron al entregar la notificación de bienvenida.
  void confirmarBienvenidas() {
    for (final d in dispositivos) {
      d['bienvenida_pendiente'] = 0;
      d['confirmado'] = 1;
    }
  }

  /// Peticiones recibidas ("GET /api/...") para verificar en las pruebas.
  final log = <String>[];

  /// Simula que el servidor no responde (error de conexión).
  bool caido = false;

  // ── Tiempo real (imita backend/lib/tiempoReal.ts) ──

  /// Conexiones abiertas a /api/tiempo-real por usuario.
  final vivos = <int, List<StreamController<Uint8List>>>{};

  /// Simula un servidor sin la ruta de tiempo real (404).
  bool sinTiempoReal = false;

  int conexionesVivas([int? uid]) => uid == null ? vivos.values.fold(0, (n, l) => n + l.length) : (vivos[uid]?.length ?? 0);

  /// Envía un evento SSE a las conexiones abiertas del usuario.
  void emitir(int? uid, String evento, Object datos) {
    for (final c in [...?vivos[uid]]) {
      c.add(Uint8List.fromList(utf8.encode('id: ${_id()}\nevent: $evento\ndata: ${jsonEncode(datos)}\n\n')));
    }
  }

  /// Envía un latido (comentario SSE).
  void latido() {
    for (final l in vivos.values) {
      for (final c in [...l]) {
        c.add(Uint8List.fromList(utf8.encode(': latido\n\n')));
      }
    }
  }

  /// Corta todas las conexiones en vivo (como una caída de la red).
  Future<void> cortarVivos() async {
    final todas = [for (final l in vivos.values) ...l];
    vivos.clear();
    for (final c in todas) {
      await c.close();
    }
  }

  ResponseBody _tiempoReal(RequestOptions o, Future<void>? cancelFuture) {
    final uid = _usuario(o.headers['Authorization']?.toString());
    if (uid == null || sinTiempoReal) {
      return ResponseBody.fromString(jsonEncode({'message': uid == null ? 'Unauthorized' : 'Route GET:/api/tiempo-real not found'}), uid == null ? 401 : 404,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
    }
    final c = StreamController<Uint8List>();
    (vivos[uid] ??= []).add(c);
    void quitar() => vivos[uid]?.remove(c);
    c.onCancel = quitar;
    cancelFuture?.whenComplete(() {
      quitar();
      unawaited(c.close());
    });
    c.add(Uint8List.fromList(utf8.encode('retry: 5000\n\nevent: hola\ndata: {"latido":25000}\n\n')));
    return ResponseBody(c.stream, 200, headers: {Headers.contentTypeHeader: ['text/event-stream; charset=utf-8']});
  }

  int _seq = 100;
  int _id() => ++_seq;

  String tokenDe(int userId) => 'tok-$userId';

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (caido) {
      throw DioException.connectionError(requestOptions: o, reason: 'servidor caído');
    }
    log.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == '/api/tiempo-real') return _tiempoReal(o, cancelFuture);
    final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
    final r = _rutear(o.method, o.path, o.queryParameters, body, o.headers['Authorization']?.toString());
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  _Resp _err(int s, String m, [Map<String, dynamic> extra = const {}]) => _Resp(s, {'message': m, ...extra});

  int? _usuario(String? auth) {
    if (auth == null || !auth.startsWith('Bearer tok-')) return null;
    return int.tryParse(auth.substring('Bearer tok-'.length));
  }

  _Resp _rutear(String m, String path, Map<String, dynamic> q, Map<String, dynamic> b, String? auth) {
    // ── Públicas ──
    if (m == 'POST' && path == '/api/login') return _login(b);
    if (m == 'POST' && path == '/api/register') return _registrar(b);
    if (m == 'POST' && path == '/api/register/verify') return _verificar(b);
    if (m == 'POST' && path == '/api/register/resend-code') return const _Resp(200, {'message': 'Nuevo código de verificación enviado'});

    final segPub = path.split('/').where((s) => s.isNotEmpty).toList();
    if (path.startsWith('/api/public/agenda/')) return agenda._publica(m, segPub, q, b, _usuario(auth));

    final uid = _usuario(auth);
    if (uid == null) {
      return const _Resp(401, {'statusCode': 401, 'code': 'FST_JWT_NO_AUTHORIZATION_IN_HEADER', 'error': 'Unauthorized', 'message': 'No Authorization was found in request.headers'});
    }
    final seg = path.split('/').where((s) => s.isNotEmpty).toList(); // api, ...
    int? idEn(int i) => seg.length > i ? int.tryParse(seg[i]) : null;
    List<Map<String, dynamic>> de(List<Map<String, dynamic>> t) => t.where((r) => r['user_id'] == uid).toList();

    if (seg.length > 1 && seg[1] == 'agenda') return agenda._privada(m, seg, q, b, uid);
    if (seg.length > 1 && seg[1] == 'capturas') return _capturas(m, seg, q, b, uid);
    if (seg.length > 2 && seg[1] == 'finanzas' && (seg[2] == 'inversiones' || seg[2] == 'inversion-movimientos')) return _inversiones(m, seg, b, uid);
    switch ((m, seg.length > 1 ? seg[1] : '')) {
      case ('GET', 'dashboard') when seg[2] == 'bootstrap':
        return _Resp(200, {
          'cumpleanos': de(cumples),
          'cycles': de(ciclos)..sort((a, b) => (b['fecha_inicio'] as String).compareTo(a['fecha_inicio'] as String)),
          'habits': [],
          'categoriasUsadas': {...de(transacciones).map((t) => t['categoria']), ...de(presupuestos).map((p) => p['categoria'])}.toList(),
          'finanzas': {
            'cuentas': de(cuentas),
            'ingresosPlanificados': de(planes),
            'verificaciones': de(verificaciones),
            'metas': de(metas),
            'categorias': de(categorias),
          },
        });
      case ('GET', 'dashboard') when seg[2] == 'month':
        final mes = int.parse('${q['mes']}');
        final anio = int.parse('${q['anio']}');
        final p = '$anio-${mes.toString().padLeft(2, '0')}';
        bool enMes(Map<String, dynamic> r) => (r['fecha'] as String).startsWith(p);
        return _Resp(200, {
          'events': de(eventos).where(enMes).toList()..sort((a, b) => '${a['fecha']}${a['hora']}'.compareTo('${b['fecha']}${b['hora']}')),
          'transacciones': de(transacciones).where(enMes).toList(),
          'notes': [],
          'habitLogs': [],
          'presupuestos': de(presupuestos).where((x) => x['mes'] == mes && x['anio'] == anio).toList(),
          'transferencias': de(transferencias).where(enMes).toList(),
        });
      case ('GET', 'events'):
        return _Resp(200, de(eventos));
      case ('POST', 'events'):
        return _crearEvento(uid, b);
      case ('PUT', 'events') when seg.length == 4 && seg[3] == 'toggle-pago':
        final e = eventos.firstWhere((x) => x['id'] == idEn(2) && x['user_id'] == uid);
        e['estado_pago'] = b['estado_pago'];
        return const _Resp(200, {'message': 'Estado de pago actualizado'});
      case ('PUT', 'events'):
        return _editarEvento(uid, idEn(2)!, b, '${q['editMode'] ?? 'instance'}');
      case ('DELETE', 'events'):
        return _borrarEvento(uid, idEn(2)!, '${q['deleteMode'] ?? 'instance'}');
      case ('POST', 'dispositivos') when seg.length == 3 && seg[2] == 'baja':
        dispositivos.removeWhere((d) => d['token'] == b['token'] && d['user_id'] == uid);
        return const _Resp(200, {'ok': true});
      case ('POST', 'dispositivos'):
        final token = '${b['token'] ?? ''}';
        if (token.length < 20) return _err(400, 'Token de notificaciones inválido');
        if (b['plataforma'] != 'android' && b['plataforma'] != 'ios') return _err(400, 'Plataforma no soportada');
        final d = dispositivos.where((x) => x['token'] == token).firstOrNull;
        final datos = {
          'user_id': uid,
          'token': token,
          'plataforma': b['plataforma'],
          'avisos': b['avisos'] == false ? 0 : 1,
          'aviso_30m': b['aviso_30m'] == false ? 0 : 1,
          'resumen': b['resumen'] == false ? 0 : 1,
        };
        if (d == null) {
          dispositivos.add({...datos, 'id': _id(), 'bienvenida_pendiente': 1, 'confirmado': 0});
        } else {
          if (d['user_id'] != uid) d.addAll({'bienvenida_pendiente': 1, 'confirmado': 0});
          d.addAll(datos);
        }
        final r = dispositivos.firstWhere((x) => x['token'] == token);
        return _Resp(200, {'ok': true, 'pendiente': r['bienvenida_pendiente'] == 1, 'confirmado': r['confirmado'] == 1});
      case ('GET', 'important-days'):
        final y = q['year'];
        return _Resp(200, [
          {'id': 1, 'nombre': 'Día del Programador', 'categoria': 'Profesional', 'descripcion': 'Día 256 del año', 'regla': 'fixed:09-13', 'date': '$y-09-13'},
        ]);
      case ('POST', 'cumpleanos'):
        cumples.add({'id': _id(), 'user_id': uid, ...b});
        return const _Resp(200, {'message': 'Cumpleaños creado'});
      case ('PUT', 'cumpleanos'):
        cumples.firstWhere((c) => c['id'] == idEn(2)).addAll(b);
        return const _Resp(200, {'message': 'ok'});
      case ('DELETE', 'cumpleanos'):
        cumples.removeWhere((c) => c['id'] == idEn(2));
        return const _Resp(200, {'message': 'ok'});
      case ('POST', 'cycles'):
        if (de(ciclos).any((c) => c['fecha_inicio'] == b['fecha_inicio'])) return _err(409, 'Ya tienes un ciclo registrado en esa fecha');
        final prev = de(ciclos).where((c) => (c['fecha_inicio'] as String).compareTo(b['fecha_inicio'] as String) < 0).toList()
          ..sort((a, c) => (c['fecha_inicio'] as String).compareTo(a['fecha_inicio'] as String));
        ciclos.add({'id': _id(), 'user_id': uid, 'fecha_inicio': b['fecha_inicio'], 'observacion': b['observacion'] ?? '', 'dias_sangrado': b['dias_sangrado']});
        String? adv;
        if (prev.isNotEmpty) {
          final d = DateTime.parse(b['fecha_inicio'] as String).difference(DateTime.parse(prev.first['fecha_inicio'] as String)).inDays;
          if (d < 10) adv = 'El ciclo anterior empezó hace solo $d día(s). Si fue un registro por error, puedes eliminarlo desde el historial.';
        }
        return _Resp(200, {'message': 'Ciclo registrado', 'advertencia': adv});
      case ('PUT', 'cycles'):
        ciclos.firstWhere((c) => c['id'] == idEn(2)).addAll(b);
        return const _Resp(200, {'message': 'Ciclo actualizado'});
      case ('DELETE', 'cycles'):
        ciclos.removeWhere((c) => c['id'] == idEn(2));
        return const _Resp(200, {'message': 'Ciclo eliminado'});
      case (_, 'finanzas'):
        return _finanzas(m, seg, q, b, uid);
    }
    return _err(404, 'Ruta no encontrada: $m $path');
  }

  // ─────────────── Auth ───────────────

  Map<String, dynamic> _publico(Map<String, dynamic> u) => {'id': u['id'], 'nombre': u['nombre'], 'email': u['email'], 'whatsapp': u['whatsapp']};

  _Resp _login(Map<String, dynamic> b) {
    final u = usuarios.where((u) => u['email'] == b['email'] && u['password'] == b['password']).firstOrNull;
    if (u == null) return _err(401, 'Credenciales inválidas');
    if (u['verificado'] != 1) {
      u['codigo'] = '123456';
      return _err(403, 'Tu cuenta no está verificada. Hemos enviado un nuevo código a tu WhatsApp.',
          {'verification_required': true, 'email': u['email'], 'whatsapp': u['whatsapp']});
    }
    return _Resp(200, {'message': 'Login exitoso', 'token': tokenDe(u['id'] as int), 'user': _publico(u)});
  }

  _Resp _registrar(Map<String, dynamic> b) {
    if ([b['nombre'], b['email'], b['password'], b['whatsapp']].any((v) => v == null || '$v'.isEmpty)) {
      return _err(400, 'Todos los campos son obligatorios');
    }
    final wa = '${b['whatsapp']}'.replaceAll(RegExp(r'\D'), '');
    if (wa.length < 10) return _err(400, 'El número de WhatsApp debe tener al menos 10 dígitos (incluyendo código de país)');
    final existe = usuarios.where((u) => u['email'] == b['email']).firstOrNull;
    if (existe != null && existe['verificado'] == 1) return _err(400, 'El correo ya está registrado');
    usuarios.removeWhere((u) => u['email'] == b['email']);
    usuarios.add({'id': _id(), 'nombre': b['nombre'], 'email': b['email'], 'password': b['password'], 'whatsapp': wa, 'verificado': 0, 'codigo': '123456'});
    return _Resp(200, {'message': 'Código de verificación enviado a tu WhatsApp', 'verification_required': true, 'email': b['email']});
  }

  _Resp _verificar(Map<String, dynamic> b) {
    final u = usuarios.where((u) => u['email'] == b['email']).firstOrNull;
    if (u == null) return _err(404, 'Usuario no encontrado');
    if (u['codigo'] != b['code']) return _err(400, 'Código de verificación incorrecto');
    u['verificado'] = 1;
    u['codigo'] = null;
    return _Resp(200, {'message': 'Usuario verificado exitosamente', 'token': tokenDe(u['id'] as int), 'user': _publico(u)});
  }

  // ─────────────── Eventos ───────────────

  Map<String, dynamic> _filaEvento(int uid, Map<String, dynamic> b, String fecha, int? parentId, {String? estado}) => {
        'id': _id(),
        'user_id': uid,
        'titulo': b['titulo'],
        'fecha': fecha,
        'hora': b['hora'] == null ? null : '${b['hora']}:00'.substring(0, 8),
        'categoria': b['categoria'] ?? 'general',
        'descripcion': null,
        'ubicacion': b['ubicacion'] ?? '',
        'repeticion': 'unica',
        'frecuencia': b['frecuencia'] ?? 'unica',
        'costo': _dec((b['costo'] ?? 0) as num),
        'tipo_transaccion': b['tipo_transaccion'] ?? 'ninguno',
        'estado_pago': estado ?? b['estado_pago'] ?? 'pendiente',
        'uuid_confirmacion': 'uuid-${_seq + 1}',
        'parent_id': parentId,
        'tarjeta_credito_id': null,
        'transaccion_id': null,
        'created_at': '2026-09-01T12:00:00.000Z',
      };

  void _generar(int uid, int master, String base, Map<String, dynamic> b) {
    final f = '${b['frecuencia'] ?? 'unica'}';
    for (var i = 1; i <= maxOcurrencias(f); i++) {
      eventos.add(_filaEvento(uid, b, fechaOcurrencia(base, f, i), master, estado: 'pendiente'));
    }
  }

  _Resp _crearEvento(int uid, Map<String, dynamic> b) {
    final fila = _filaEvento(uid, b, b['fecha'] as String, null);
    eventos.add(fila);
    if ((b['frecuencia'] ?? 'unica') != 'unica') _generar(uid, fila['id'] as int, b['fecha'] as String, b);
    return _Resp(200, {'id': fila['id'], 'uuid_confirmacion': fila['uuid_confirmacion'], 'message': 'Evento creado'});
  }

  _Resp _editarEvento(int uid, int id, Map<String, dynamic> b, String modo) {
    final o = eventos.where((e) => e['id'] == id && e['user_id'] == uid).firstOrNull;
    if (o == null) return _err(404, 'Evento no encontrado');
    final fechaOriginal = o['fecha'] as String;
    final nuevo = _filaEvento(uid, b, b['fecha'] as String, o['parent_id'] as int?)..['id'] = id;
    if (modo == 'future') {
      final parent = (o['parent_id'] ?? o['id']) as int;
      o.addAll(nuevo);
      eventos.removeWhere((e) => e['parent_id'] == parent && e['id'] != id && (e['fecha'] as String).compareTo(fechaOriginal) > 0 && e['estado_pago'] == 'pendiente');
      if ((b['frecuencia'] ?? 'unica') != 'unica') _generar(uid, parent, b['fecha'] as String, b);
    } else {
      o.addAll(nuevo..['parent_id'] = (b['frecuencia'] ?? 'unica') == 'unica' ? null : o['parent_id']);
    }
    return const _Resp(200, {'message': 'Evento actualizado correctamente'});
  }

  _Resp _borrarEvento(int uid, int id, String modo) {
    final e = eventos.where((x) => x['id'] == id && x['user_id'] == uid).firstOrNull;
    if (e == null) return _err(404, 'Evento no encontrado');
    if (modo == 'future') {
      final parent = e['parent_id'] ?? e['id'];
      eventos.removeWhere((x) =>
          (x['id'] == id || x['parent_id'] == parent) && (x['fecha'] as String).compareTo(e['fecha'] as String) >= 0 && x['estado_pago'] == 'pendiente');
    } else {
      eventos.remove(e);
    }
    return const _Resp(200, {'message': 'Evento eliminado'});
  }

  // ─────────────── Finanzas ───────────────

  Map<String, dynamic> _cuenta(int id) => cuentas.firstWhere((c) => c['id'] == id);

  void _saldo(int? cuentaId, double delta) {
    if (cuentaId == null) return;
    final c = _cuenta(cuentaId);
    c['saldo'] = _dec(double.parse(c['saldo'] as String) + delta);
  }

  double _efecto(String tipoTx, int? cuentaId, double monto) {
    if (cuentaId == null) return 0;
    final credito = esCredito(_cuenta(cuentaId)['tipo'] as String);
    if (tipoTx == 'ingreso') return credito ? -monto : monto;
    return credito ? monto : -monto;
  }

  _Resp _finanzas(String m, List<String> seg, Map<String, dynamic> q, Map<String, dynamic> b, int uid) {
    final rec = seg[2];
    final id = seg.length > 3 ? int.tryParse(seg[3]) : null;
    switch ((m, rec)) {
      case ('POST', 'cuentas'):
        final c = {
          'id': _id(),
          'user_id': uid,
          'nombre': b['nombre'],
          'tipo': b['tipo'],
          'saldo': _dec((b['saldo'] ?? 0) as num),
          'limite': _dec((b['limite'] ?? 0) as num),
          'interes_tasa': _dec((b['interes_tasa'] ?? 0) as num),
          'fecha_inicio': b['fecha_inicio'],
          'plazo_dias': b['plazo_dias'] ?? 0,
          'dia_corte': b['dia_corte'],
        };
        cuentas.add(c);
        return _Resp(201, {'id': c['id'], 'message': 'Cuenta creada exitosamente'});
      case ('PUT', 'cuentas'):
        _cuenta(id!).addAll({...b, 'saldo': _dec((b['saldo'] ?? 0) as num), 'limite': _dec((b['limite'] ?? 0) as num)});
        return const _Resp(200, {'message': 'ok'});
      case ('DELETE', 'cuentas'):
        cuentas.removeWhere((c) => c['id'] == id);
        return const _Resp(200, {'message': 'ok'});
      case ('POST', 'transacciones'):
        final monto = (b['monto'] as num).toDouble();
        final cuentaId = b['cuenta_id'] as int?;
        final t = {
          'id': _id(),
          'user_id': uid,
          'cuenta_id': cuentaId,
          'tipo': b['tipo'],
          'monto': _dec(monto),
          'descripcion': b['descripcion'],
          'fecha': b['fecha'],
          'categoria': b['categoria'] ?? 'otros',
          'cuotas': b['cuotas'] ?? 1,
          'ingreso_planificado_id': null,
        };
        transacciones.add(t);
        _saldo(cuentaId, _efecto(b['tipo'] as String, cuentaId, monto));
        if (cuentaId != null && esCredito(_cuenta(cuentaId)['tipo'] as String) && b['tipo'] == 'gasto') {
          final cobros = cobrosTarjeta(
              fechaCompra: b['fecha'] as String, monto: monto, cuotas: (b['cuotas'] ?? 1) as int, diaCorte: _cuenta(cuentaId)['dia_corte'] as int?);
          for (final (k, (f, mm)) in cobros.indexed) {
            eventos.add({
              ..._filaEvento(uid, {
                'titulo': '${cobros.length > 1 ? 'Cuota ${k + 1}/${cobros.length}: ' : 'Cobro tarjeta: '}${b['descripcion']}',
                'hora': '08:00',
                'categoria': b['categoria'] ?? 'servicios',
                'costo': mm,
                'tipo_transaccion': 'gasto',
              }, f, null),
              'tarjeta_credito_id': cuentaId,
              'transaccion_id': t['id'],
            });
          }
        }
        return _Resp(200, {'id': t['id'], 'message': 'Transacción registrada'});
      case ('PUT', 'transacciones'):
        final t = transacciones.firstWhere((x) => x['id'] == id);
        _saldo(t['cuenta_id'] as int?, -_efecto(t['tipo'] as String, t['cuenta_id'] as int?, double.parse(t['monto'] as String)));
        t.addAll({...b, 'monto': _dec(b['monto'] as num)});
        _saldo(t['cuenta_id'] as int?, _efecto(t['tipo'] as String, t['cuenta_id'] as int?, double.parse(t['monto'] as String)));
        return const _Resp(200, {'message': 'Transacción actualizada'});
      case ('DELETE', 'transacciones'):
        final t = transacciones.firstWhere((x) => x['id'] == id);
        transacciones.remove(t);
        _saldo(t['cuenta_id'] as int?, -_efecto(t['tipo'] as String, t['cuenta_id'] as int?, double.parse(t['monto'] as String)));
        eventos.removeWhere((e) => e['transaccion_id'] == id && e['estado_pago'] == 'pendiente');
        return const _Resp(200, {'message': 'ok'});
      case ('POST', 'transferencias'):
        final o = b['cuenta_origen_id'] as int, d = b['cuenta_destino_id'] as int;
        if (o == d) return _err(400, 'Las cuentas de origen y destino deben ser diferentes');
        final monto = (b['monto'] as num).toDouble();
        transferencias.add({'id': _id(), 'user_id': uid, 'cuenta_origen_id': o, 'cuenta_destino_id': d, 'monto': _dec(monto), 'descripcion': b['descripcion'] ?? '', 'fecha': b['fecha']});
        _saldo(o, esCredito(_cuenta(o)['tipo'] as String) ? monto : -monto);
        _saldo(d, esCredito(_cuenta(d)['tipo'] as String) ? -monto : monto);
        return const _Resp(200, {'message': 'Transferencia registrada'});
      case ('POST', 'ingresos-planificados') when seg.length > 3 && seg[3] == 'verificar':
        final plan = planes.firstWhere((p) => p['id'] == b['ingreso_planificado_id']);
        if (verificaciones.any((v) => v['ingreso_planificado_id'] == plan['id'] && v['fecha_esperada'] == b['fecha_esperada'])) {
          return _err(400, 'Esta fecha ya fue verificada para este ingreso');
        }
        final cuentaId = (b['cuenta_id'] ?? plan['cuenta_id']) as int?;
        final monto = (b['monto_real'] as num).toDouble();
        final tx = {'id': _id(), 'user_id': uid, 'cuenta_id': cuentaId, 'tipo': 'ingreso', 'monto': _dec(monto), 'descripcion': 'Cobro: ${plan['descripcion']}', 'fecha': b['fecha_real'], 'categoria': 'otros', 'cuotas': 1, 'ingreso_planificado_id': plan['id']};
        transacciones.add(tx);
        verificaciones.add({'id': _id(), 'user_id': uid, 'ingreso_planificado_id': plan['id'], 'fecha_esperada': b['fecha_esperada'], 'fecha_real': b['fecha_real'], 'monto_real': _dec(monto), 'transaccion_id': tx['id']});
        _saldo(cuentaId, monto);
        return const _Resp(201, {'message': 'Ingreso verificado correctamente'});
      case ('POST', 'ingresos-planificados'):
        planes.add({'id': _id(), 'user_id': uid, 'cuenta_id': b['cuenta_id'], 'descripcion': b['descripcion'], 'monto': _dec(b['monto'] as num), 'frecuencia': b['frecuencia'], 'fecha_inicio': b['fecha_inicio'], 'activo': 1});
        return const _Resp(201, {'message': 'Ingreso planificado creado'});
      case ('DELETE', 'ingresos-planificados'):
        planes.removeWhere((p) => p['id'] == id);
        return const _Resp(200, {'message': 'ok'});
      case ('DELETE', 'verificaciones'):
        final v = verificaciones.firstWhere((x) => x['id'] == id);
        final t = transacciones.where((x) => x['id'] == v['transaccion_id']).firstOrNull;
        if (t != null) {
          transacciones.remove(t);
          _saldo(t['cuenta_id'] as int?, -double.parse(t['monto'] as String));
        }
        verificaciones.remove(v);
        return const _Resp(200, {'message': 'ok'});
      case ('POST', 'metas'):
        metas.add({'id': _id(), 'user_id': uid, ...b, 'monto_objetivo': _dec(b['monto_objetivo'] as num), 'monto_actual': _dec((b['monto_actual'] ?? 0) as num), 'completada': 0});
        return const _Resp(201, {'message': 'Meta creada exitosamente'});
      case ('PUT', 'metas'):
        metas.firstWhere((x) => x['id'] == id).addAll({
          ...b,
          'monto_objetivo': _dec(b['monto_objetivo'] as num),
          'monto_actual': _dec((b['monto_actual'] ?? 0) as num),
          'completada': b['completada'] == true ? 1 : 0,
        });
        return const _Resp(200, {'message': 'ok'});
      case ('DELETE', 'metas'):
        metas.removeWhere((x) => x['id'] == id);
        return const _Resp(200, {'message': 'ok'});
      case ('GET', 'presupuestos'):
        return _Resp(200, presupuestos.where((p) => p['user_id'] == uid).toList());
      case ('POST', 'presupuestos'):
        final existente = presupuestos
            .where((p) => p['user_id'] == uid && p['categoria'] == b['categoria'] && p['mes'] == b['mes'] && p['anio'] == b['anio'])
            .firstOrNull;
        if (existente != null) {
          existente['monto_limite'] = _dec(b['monto_limite'] as num);
        } else {
          presupuestos.add({'id': _id(), 'user_id': uid, 'categoria': b['categoria'], 'monto_limite': _dec(b['monto_limite'] as num), 'mes': b['mes'], 'anio': b['anio']});
        }
        return const _Resp(201, {'message': 'Presupuesto guardado exitosamente'});
      case ('DELETE', 'presupuestos'):
        presupuestos.removeWhere((p) => p['id'] == id);
        return const _Resp(200, {'message': 'ok'});
      case ('POST', 'categorias'):
        final valor = '${b['label']}'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
        if (categorias.any((c) => c['user_id'] == uid && c['valor'] == valor)) return _err(409, 'Ya tienes una categoría con ese nombre');
        categorias.add({'id': _id(), 'user_id': uid, 'valor': valor, 'label': b['label'], 'icono': b['icono'] ?? 'sell', 'es_default': 0});
        return const _Resp(201, {'message': 'ok'});
      case ('DELETE', 'categorias'):
        final c = categorias.firstWhere((x) => x['id'] == id);
        final usos = transacciones.where((t) => t['categoria'] == c['valor']).length + presupuestos.where((p) => p['categoria'] == c['valor']).length;
        if (usos > 0) return _err(409, 'No puedes eliminar esta categoría porque tiene $usos registro(s) asociado(s).');
        categorias.remove(c);
        return const _Resp(200, {'message': 'ok'});
      case ('GET', 'analytics'):
        final dias = math.min(int.parse('${q['dias'] ?? 30}'), 366);
        final desde = DateTime.now().subtract(Duration(days: dias));
        return _Resp(200, {
          'transacciones': [
            for (final t in transacciones.where((t) => t['user_id'] == uid && DateTime.parse(t['fecha'] as String).isAfter(desde)))
              {'fecha': t['fecha'], 'tipo': t['tipo'], 'monto': t['monto'], 'categoria': t['categoria']},
          ],
        });
    }
    return _err(404, 'Ruta de finanzas no encontrada: $m ${seg.join('/')}');
  }
}
