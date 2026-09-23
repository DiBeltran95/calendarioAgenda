part of 'fake_backend.dart';

// Agendamiento de citas en el backend falso: imita backend/lib/agenda/rutas.ts
// (formas de respuesta, código por WhatsApp "123456", turnos sin choques).

class FakeAgenda {
  FakeAgenda(this._b);
  final FakeBackend _b;

  final negocios = <int, Map<String, dynamic>>{}; // por user_id
  final profesionales = <Map<String, dynamic>>[];
  final servicios = <Map<String, dynamic>>[];
  final bloqueos = <Map<String, dynamic>>[];
  final citas = <Map<String, dynamic>>[];
  final whatsapps = <(String, String)>[];

  static const codigo = '123456';

  String _hora(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  int _min(String h) => int.parse(h.substring(0, 2)) * 60 + int.parse(h.substring(3, 5));

  Map<String, dynamic>? _negocioSlug(String slug) => negocios.values.where((n) => n['slug'] == slug && n['activo'] == 1).firstOrNull;

  Map<String, dynamic> config(int uid) {
    final n = negocios[uid];
    if (n == null) return {'negocio': null};
    final profs = profesionales.where((p) => p['negocio'] == n['id']).toList();
    return {
      'negocio': {...n, 'enlace': 'https://agendaservi.com/agenda/${n['slug']}'},
      'profesionales': [
        for (final p in profs)
          {
            ...p,
            'es_dueno': p['usuario_id'] == uid,
            'servicios': [for (final s in servicios.where((s) => (s['profesionales'] as List).contains(p['id']))) s['id']],
          },
      ],
      'servicios': [for (final s in servicios.where((s) => s['negocio'] == n['id'])) s],
      'bloqueos': [for (final b in bloqueos.where((b) => profs.any((p) => p['id'] == b['profesional_id']))) b],
    };
  }

  Map<String, dynamic> _filaCita(Map<String, dynamic> c, String rol) {
    final p = profesionales.firstWhere((x) => x['id'] == c['profesional_id']);
    final n = negocios.values.firstWhere((x) => x['id'] == c['negocio']);
    return {...c, 'profesional_nombre': p['nombre'], 'profesional_color': p['color'], 'negocio_nombre': n['nombre'], 'slug': n['slug'], 'negocio_color': n['color'], 'rol': rol};
  }

  Map<String, dynamic> _vista(Map<String, dynamic> c) {
    final p = profesionales.firstWhere((x) => x['id'] == c['profesional_id']);
    final n = negocios.values.firstWhere((x) => x['id'] == c['negocio']);
    return {
      'token': c['token'],
      'estado': c['estado'],
      'fecha': c['fecha'],
      'hora_inicio': c['hora_inicio'],
      'hora_fin': c['hora_fin'],
      'servicio': c['servicio_nombre'],
      'duracion_min': c['duracion_min'],
      'precio': double.parse('${c['precio']}'),
      'profesional': {'nombre': p['nombre'], 'color': p['color']},
      'cliente_nombre': c['cliente_nombre'],
      'whatsapp': '+57 311 *** ${(c['cliente_whatsapp'] as String).substring((c['cliente_whatsapp'] as String).length - 4)}',
      'segundos_restantes': c['estado'] == 'pendiente' ? 900 : 0,
      'puede_cancelar': c['estado'] == 'pendiente' || c['estado'] == 'confirmada',
      'negocio': {'nombre': n['nombre'], 'slug': n['slug'], 'color': n['color'], 'direccion': n['direccion']},
    };
  }

  /// Turnos libres de un profesional en una fecha (misma regla que el backend).
  List<String> _libres(Map<String, dynamic> p, String fecha, int duracion, int paso, {int? ignorarCita}) {
    final dia = DateTime.parse(fecha).weekday % 7;
    if (bloqueos.any((b) => b['profesional_id'] == p['id'] && b['fecha'] == fecha && b['inicio'] == null)) return const [];
    final ocupados = [
      for (final c in citas)
        if (c['profesional_id'] == p['id'] && c['fecha'] == fecha && (c['estado'] == 'confirmada' || c['estado'] == 'pendiente') && c['id'] != ignorarCita) (_min(c['hora_inicio']), _min(c['hora_fin'])),
    ];
    final ahora = DateTime.now();
    final hoy = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}-${ahora.day.toString().padLeft(2, '0')}';
    final desde = fecha == hoy ? ahora.hour * 60 + ahora.minute : (fecha.compareTo(hoy) < 0 ? 24 * 60 : 0);
    final out = <String>[];
    for (final h in (p['horarios'] as List).where((h) => h['dia'] == dia)) {
      final ini = _min(h['inicio']);
      final fin = _min(h['fin']);
      for (var t = ini; t + duracion <= fin; t += paso) {
        if (t < desde) continue;
        if (ocupados.any((o) => t < o.$2 && t + duracion > o.$1)) continue;
        out.add(_hora(t));
      }
    }
    return out..sort();
  }

  /// Como `emitirCita` del backend: avisa en vivo al dueño y al cliente con app.
  void _emitir(Map<String, dynamic> c, String tipo, int? actor) {
    final dueno = negocios.entries.where((e) => e.value['id'] == c['negocio']).firstOrNull?.key;
    _b.emitir(dueno, 'cita', {'tipo': tipo, 'actor': actor, 'cita': _filaCita(c, 'dueno')});
    final cliente = c['cliente_usuario_id'] as int?;
    if (cliente != null) _b.emitir(cliente, 'cita', {'tipo': tipo, 'actor': actor, 'cita': _filaCita(c, 'cliente')});
  }

  _Resp _publica(String m, List<String> seg, Map<String, dynamic> q, Map<String, dynamic> b, int? uid) {
    // seg: api, public, agenda, <slug|citas>, ...
    if (seg.length >= 5 && seg[3] == 'citas') {
      final c = citas.where((x) => x['token'] == seg[4]).firstOrNull;
      if (c == null) return _b._err(404, 'Cita no encontrada');
      final accion = seg.length > 5 ? seg[5] : '';
      if (m == 'POST' && accion == 'confirmar') {
        if (c['estado'] == 'confirmada') return _Resp(200, _vista(c));
        if ('${b['codigo']}' != codigo) return _b._err(400, 'Código incorrecto. Te quedan 4 intentos.');
        c['estado'] = 'confirmada';
        whatsapps.add((c['cliente_whatsapp'] as String, '✅ *¡Cita confirmada!*'));
        _emitir(c, 'confirmada', c['cliente_usuario_id'] as int?);
        return _Resp(200, _vista(c));
      }
      if (m == 'POST' && accion == 'reenviar') return const _Resp(200, {'ok': true});
      if (m == 'POST' && accion == 'cancelar') {
        c['estado'] = 'cancelada';
        _emitir(c, 'cancelada', c['cliente_usuario_id'] as int?);
        return _Resp(200, _vista(c));
      }
      return _Resp(200, _vista(c));
    }
    final n = _negocioSlug(seg[3]);
    if (n == null) return _b._err(404, 'Esta página de citas no existe o está pausada');
    final profs = profesionales.where((p) => p['negocio'] == n['id'] && p['activo'] == 1).toList();
    final accion = seg.length > 4 ? seg[4] : '';
    if (m == 'GET' && accion.isEmpty) {
      return _Resp(200, {
        'negocio': {...n, 'iniciales': 'X'},
        'servicios': [
          for (final s in servicios.where((s) => s['negocio'] == n['id'] && s['activo'] == 1))
            {...s, 'precio': double.parse('${s['precio']}'), 'profesionales': [for (final id in s['profesionales'] as List) if (profs.any((p) => p['id'] == id)) id]},
        ],
        'profesionales': [for (final p in profs) {'id': p['id'], 'nombre': p['nombre'], 'cargo': p['cargo'], 'color': p['color']}],
      });
    }
    final srv = servicios.where((s) => s['id'] == (m == 'GET' ? int.parse('${q['servicio']}') : b['servicio_id'])).firstOrNull;
    if (srv == null) return _b._err(404, 'Servicio no encontrado');
    final pedido = m == 'GET' ? int.parse('${q['profesional'] ?? 0}') : (b['profesional_id'] as int? ?? 0);
    final candidatos = profs.where((p) => (srv['profesionales'] as List).contains(p['id']) && (pedido == 0 || p['id'] == pedido)).toList();
    if (m == 'GET' && accion == 'disponibilidad') {
      final desde = '${q['desde']}';
      final dias = int.parse('${q['dias'] ?? 14}');
      return _Resp(200, {
        'desde': desde,
        'dias': [
          for (var i = 0; i < dias; i++)
            () {
              final f = sumarDiasYmd(desde, i);
              final porHora = <String, List<int>>{};
              for (final p in candidatos) {
                for (final h in _libres(p, f, srv['duracion_min'] as int, n['intervalo_min'] as int)) {
                  (porHora[h] ??= []).add(p['id'] as int);
                }
              }
              return {
                'fecha': f,
                'turnos': [for (final e in (porHora.entries.toList()..sort((a, z) => a.key.compareTo(z.key)))) {'hora': e.key, 'profesionales': e.value}],
              };
            }(),
        ],
      });
    }
    if (m == 'POST' && accion == 'reservas') {
      final libre = candidatos.where((p) => _libres(p, b['fecha'] as String, srv['duracion_min'] as int, n['intervalo_min'] as int).contains(b['hora'])).firstOrNull;
      if (libre == null) return _b._err(409, 'Ese horario acaba de ocuparse. Elige otro, por favor.', {'codigo': 'ocupado'});
      final wa = '${b['whatsapp']}'.replaceAll(RegExp(r'\D'), '');
      final c = {
        'id': _b._id(),
        'token': 'tk${_b._id()}'.padRight(32, '0'),
        'negocio': n['id'],
        'profesional_id': libre['id'],
        'servicio_id': srv['id'],
        'servicio_nombre': srv['nombre'],
        'duracion_min': srv['duracion_min'],
        'precio': srv['precio'],
        'fecha': b['fecha'],
        'hora_inicio': b['hora'],
        'hora_fin': _hora(_min(b['hora'] as String) + (srv['duracion_min'] as int)),
        'cliente_nombre': b['nombre'],
        'cliente_whatsapp': wa,
        'cliente_usuario_id': uid,
        'nota': b['nota'],
        'estado': 'pendiente',
        'origen': uid == null ? 'web' : 'app',
        'creado': DateTime.now().toUtc().toIso8601String(),
      };
      citas.add(c);
      _emitir(c, 'pendiente', uid);
      whatsapps.add((wa, 'Tu código de confirmación es:\n*$codigo*'));
      return _Resp(200, _vista(c));
    }
    return _b._err(404, 'Ruta pública de agenda no encontrada');
  }

  _Resp _privada(String m, List<String> seg, Map<String, dynamic> q, Map<String, dynamic> b, int uid) {
    final recurso = seg.length > 2 ? seg[2] : '';
    final id = seg.length > 3 ? int.tryParse(seg[3]) : null;
    final n = negocios[uid];
    switch ((m, recurso)) {
      case ('GET', ''):
        return _Resp(200, config(uid));
      case ('GET', 'slug'):
        final s = '${q['slug']}';
        final valido = RegExp(r'^[a-z0-9](?:[a-z0-9-]{1,48}[a-z0-9])$').hasMatch(s);
        final ocupado = negocios.entries.any((e) => e.value['slug'] == s && e.key != uid);
        return _Resp(200, {'slug': s, 'disponible': valido && !ocupado, 'valido': valido, 'sugerido': ocupado ? '$s-2' : s});
      case ('PUT', 'negocio'):
        final slug = '${b['slug'] ?? n?['slug']}';
        if (negocios.entries.any((e) => e.value['slug'] == slug && e.key != uid)) return _b._err(409, 'Ese enlace ya está en uso. Prueba con otro.');
        final nuevo = n == null;
        final datos = <String, dynamic>{
          'id': n?['id'] ?? _b._id(),
          'slug': slug,
          'tipo': b['tipo'] ?? n?['tipo'] ?? 'profesional',
          'nombre': b['nombre'] ?? n?['nombre'],
          'rubro': b['rubro'] ?? n?['rubro'] ?? 'otro',
          'descripcion': b['descripcion'] ?? n?['descripcion'],
          'direccion': b['direccion'] ?? n?['direccion'],
          'whatsapp': b['whatsapp'] ?? n?['whatsapp'],
          'color': b['color'] ?? n?['color'] ?? '#2563EB',
          'anticipacion_min': b['anticipacion_min'] ?? n?['anticipacion_min'] ?? 60,
          'ventana_dias': b['ventana_dias'] ?? n?['ventana_dias'] ?? 30,
          'intervalo_min': b['intervalo_min'] ?? n?['intervalo_min'] ?? 15,
          'usar_calendario': (b['usar_calendario'] ?? true) == true ? 1 : 0,
          'activo': (b['activo'] ?? true) == true ? 1 : 0,
        };
        negocios[uid] = datos;
        if (nuevo && (datos['tipo'] == 'profesional' || b['dueno_atiende'] == true)) {
          final u = _b.usuarios.firstWhere((x) => x['id'] == uid);
          profesionales.add({
            'id': _b._id(),
            'negocio': datos['id'],
            'usuario_id': uid,
            'nombre': u['nombre'],
            'whatsapp': u['whatsapp'],
            'color': datos['color'],
            'activo': 1,
            'horarios': b['horarios'] ?? [for (final d in [1, 2, 3, 4, 5]) ...[{'dia': d, 'inicio': '08:00', 'fin': '12:00'}, {'dia': d, 'inicio': '14:00', 'fin': '18:00'}]],
          });
        }
        return _Resp(200, config(uid));
    }
    if (n == null) return _b._err(404, 'Primero crea tu página de citas');
    switch ((m, recurso)) {
      case ('POST', 'servicios') || ('PUT', 'servicios'):
        final todos = [for (final p in profesionales.where((p) => p['negocio'] == n['id'])) p['id']];
        final datos = {
          'negocio': n['id'],
          'nombre': b['nombre'],
          'descripcion': b['descripcion'],
          'duracion_min': b['duracion_min'],
          'precio': _dec((b['precio'] as num?) ?? 0),
          'color': b['color'] ?? n['color'],
          'activo': (b['activo'] ?? true) == true ? 1 : 0,
          'profesionales': b['profesionales'] ?? todos,
        };
        if (id == null) {
          servicios.add({'id': _b._id(), ...datos});
        } else {
          servicios.firstWhere((s) => s['id'] == id).addAll(datos);
        }
        return _Resp(200, config(uid));
      case ('DELETE', 'servicios'):
        servicios.removeWhere((s) => s['id'] == id);
        return _Resp(200, config(uid));
      case ('POST', 'profesionales') || ('PUT', 'profesionales'):
        int? vinculado;
        if ((b['vincular'] ?? '').toString().isNotEmpty) {
          final u = _b.usuarios.where((x) => x['email'] == b['vincular']).firstOrNull;
          if (u == null) return _b._err(404, 'No encontramos una cuenta de Agendaservi con ese correo o WhatsApp');
          vinculado = u['id'] as int;
        }
        final datos = {
          'negocio': n['id'],
          'nombre': b['nombre'],
          'cargo': b['cargo'],
          'whatsapp': b['whatsapp'],
          'color': b['color'] ?? n['color'],
          'activo': (b['activo'] ?? true) == true ? 1 : 0,
          if (b['horarios'] != null) 'horarios': b['horarios'],
          'usuario_id': ?vinculado,
        };
        final pid = id ?? _b._id();
        if (id == null) {
          profesionales.add({'id': pid, 'horarios': [], ...datos});
        } else {
          profesionales.firstWhere((p) => p['id'] == id).addAll(datos);
        }
        if (b['servicios'] is List) {
          for (final s in servicios.where((s) => s['negocio'] == n['id'])) {
            final l = (s['profesionales'] as List).toList()..remove(pid);
            if ((b['servicios'] as List).contains(s['id'])) l.add(pid);
            s['profesionales'] = l;
          }
        }
        return _Resp(200, config(uid));
      case ('DELETE', 'profesionales'):
        profesionales.removeWhere((p) => p['id'] == id);
        return _Resp(200, config(uid));
      case ('POST', 'bloqueos'):
        final profs = profesionales.where((p) => p['negocio'] == n['id'] && (b['profesional_id'] == null || p['id'] == b['profesional_id']));
        for (final p in profs) {
          bloqueos.add({'id': _b._id(), 'profesional_id': p['id'], 'fecha': b['fecha'], 'inicio': b['inicio'], 'fin': b['fin'], 'motivo': b['motivo']});
        }
        return _Resp(200, config(uid));
      case ('DELETE', 'bloqueos'):
        bloqueos.removeWhere((x) => x['id'] == id);
        return _Resp(200, config(uid));
      case ('GET', 'citas'):
        return _Resp(200, [for (final c in citas.where((c) => c['negocio'] == n['id'])) _filaCita(c, 'dueno')]);
      case ('GET', 'mis-reservas'):
        return _Resp(200, [for (final c in citas.where((c) => c['cliente_usuario_id'] == uid)) _filaCita(c, 'cliente')]);
      case ('POST', 'citas'):
        final srv = servicios.firstWhere((s) => s['id'] == b['servicio_id']);
        final p = profesionales.firstWhere((x) => x['id'] == b['profesional_id']);
        if (b['forzar'] != true && !_libres(p, b['fecha'] as String, srv['duracion_min'] as int, n['intervalo_min'] as int).contains(b['hora'])) {
          return _b._err(409, 'Ese horario no está libre para este profesional. ¿Agendar de todas formas?', {'codigo': 'ocupado'});
        }
        final c = {
          'id': _b._id(),
          'token': 'tk${_b._id()}'.padRight(32, '0'),
          'negocio': n['id'],
          'profesional_id': p['id'],
          'servicio_id': srv['id'],
          'servicio_nombre': srv['nombre'],
          'duracion_min': srv['duracion_min'],
          'precio': srv['precio'],
          'fecha': b['fecha'],
          'hora_inicio': b['hora'],
          'hora_fin': _hora(_min(b['hora'] as String) + (srv['duracion_min'] as int)),
          'cliente_nombre': b['cliente_nombre'],
          'cliente_whatsapp': b['cliente_whatsapp'],
          'nota': b['nota'],
          'estado': 'confirmada',
          'origen': 'negocio',
          'creado': DateTime.now().toUtc().toIso8601String(),
        };
        citas.add(c);
        _emitir(c, 'nueva', uid);
        return _Resp(200, _filaCita(c, 'dueno'));
      case ('PUT', 'citas'):
        final c = citas.firstWhere((x) => x['id'] == id);
        c['estado'] = b['estado'];
        if (b['motivo'] != null) c['motivo_cancelacion'] = b['motivo'];
        _emitir(c, b['estado'] == 'cancelada' ? 'cancelada' : 'actualizada', uid);
        return _Resp(200, _filaCita(c, 'dueno'));
    }
    return _b._err(404, 'Ruta de agenda no encontrada: $m ${seg.join('/')}');
  }
}
