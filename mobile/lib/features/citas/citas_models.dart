// Modelos del agendamiento de citas (backend: lib/agenda/rutas.ts).

import '../../core/net/json.dart';

/// Rubros con su nombre visible (mismos valores que acepta el backend).
const rubrosAgenda = <String, String>{
  'psicologia': 'Psicología',
  'salud': 'Salud',
  'odontologia': 'Odontología',
  'peluqueria': 'Peluquería',
  'barberia': 'Barbería',
  'estetica': 'Estética',
  'spa': 'Spa y bienestar',
  'unas': 'Uñas',
  'fitness': 'Entrenamiento',
  'consultoria': 'Consultoría',
  'educacion': 'Clases y tutorías',
  'mascotas': 'Mascotas',
  'otro': 'Otro',
};

String iniciales(String nombre) {
  final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
  return partes.map((p) => p[0].toUpperCase()).join();
}

class HorarioDia {
  const HorarioDia({required this.dia, required this.inicio, required this.fin});

  /// 0 = domingo … 6 = sábado (igual que el backend).
  final int dia;
  final String inicio;
  final String fin;

  factory HorarioDia.fromJson(Map<String, dynamic> j) =>
      HorarioDia(dia: asInt(j['dia']), inicio: asHora(j['inicio']) ?? '08:00', fin: asHora(j['fin']) ?? '12:00');
  Map<String, dynamic> toJson() => {'dia': dia, 'inicio': inicio, 'fin': fin};

  @override
  bool operator ==(Object other) => other is HorarioDia && other.dia == dia && other.inicio == inicio && other.fin == fin;
  @override
  int get hashCode => Object.hash(dia, inicio, fin);
}

class NegocioAgenda {
  const NegocioAgenda({
    required this.id,
    required this.slug,
    required this.tipo,
    required this.nombre,
    required this.rubro,
    this.descripcion,
    this.direccion,
    this.whatsapp,
    required this.color,
    this.anticipacionMin = 60,
    this.ventanaDias = 30,
    this.intervaloMin = 15,
    this.usarCalendario = true,
    this.activo = true,
    required this.enlace,
  });

  final int id;
  final String slug;

  /// 'profesional' (una persona) o 'empresa' (equipo).
  final String tipo;
  final String nombre;
  final String rubro;
  final String? descripcion;
  final String? direccion;
  final String? whatsapp;
  final int color;
  final int anticipacionMin;
  final int ventanaDias;
  final int intervaloMin;
  final bool usarCalendario;
  final bool activo;
  final String enlace;

  bool get esEmpresa => tipo == 'empresa';

  factory NegocioAgenda.fromJson(Map<String, dynamic> j) => NegocioAgenda(
        id: asInt(j['id']),
        slug: asString(j['slug']),
        tipo: asString(j['tipo'], fallback: 'profesional'),
        nombre: asString(j['nombre']),
        rubro: asString(j['rubro'], fallback: 'otro'),
        descripcion: asStringOrNull(j['descripcion']),
        direccion: asStringOrNull(j['direccion']),
        whatsapp: asStringOrNull(j['whatsapp']),
        color: colorDesdeHex(j['color'], fallback: 0xFF2563EB),
        anticipacionMin: asInt(j['anticipacion_min'], fallback: 60),
        ventanaDias: asInt(j['ventana_dias'], fallback: 30),
        intervaloMin: asInt(j['intervalo_min'], fallback: 15),
        usarCalendario: asBool(j['usar_calendario'], fallback: true),
        activo: asBool(j['activo'], fallback: true),
        enlace: asString(j['enlace']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'tipo': tipo,
        'nombre': nombre,
        'rubro': rubro,
        'descripcion': descripcion,
        'direccion': direccion,
        'whatsapp': whatsapp,
        'color': colorAHex(color),
        'anticipacion_min': anticipacionMin,
        'ventana_dias': ventanaDias,
        'intervalo_min': intervaloMin,
        'usar_calendario': usarCalendario,
        'activo': activo,
        'enlace': enlace,
      };
}

class ProfesionalAgenda {
  const ProfesionalAgenda({
    required this.id,
    required this.nombre,
    this.cargo,
    this.whatsapp,
    required this.color,
    this.activo = true,
    this.usuarioId,
    this.usuarioNombre,
    this.usuarioEmail,
    this.esDueno = false,
    this.horarios = const [],
    this.servicios = const [],
  });

  final int id;
  final String nombre;
  final String? cargo;
  final String? whatsapp;
  final int color;
  final bool activo;

  /// Cuenta de Agendaservi vinculada (recibe sus citas en la app).
  final int? usuarioId;
  final String? usuarioNombre;
  final String? usuarioEmail;
  final bool esDueno;
  final List<HorarioDia> horarios;
  final List<int> servicios;

  String get iniciales => _ini(nombre);

  factory ProfesionalAgenda.fromJson(Map<String, dynamic> j) => ProfesionalAgenda(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        cargo: asStringOrNull(j['cargo']),
        whatsapp: asStringOrNull(j['whatsapp']),
        color: colorDesdeHex(j['color'], fallback: 0xFF2563EB),
        activo: asBool(j['activo'], fallback: true),
        usuarioId: asIntOrNull(j['usuario_id']),
        usuarioNombre: asStringOrNull(j['usuario_nombre']),
        usuarioEmail: asStringOrNull(j['usuario_email']),
        esDueno: asBool(j['es_dueno']),
        horarios: parseList(j['horarios'], HorarioDia.fromJson),
        servicios: [for (final s in (j['servicios'] as List? ?? const [])) asInt(s)],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'cargo': cargo,
        'whatsapp': whatsapp,
        'color': colorAHex(color),
        'activo': activo,
        'usuario_id': usuarioId,
        'usuario_nombre': usuarioNombre,
        'usuario_email': usuarioEmail,
        'es_dueno': esDueno,
        'horarios': [for (final h in horarios) h.toJson()],
        'servicios': servicios,
      };
}

String _ini(String n) => iniciales(n);

class ServicioAgenda {
  const ServicioAgenda({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.duracionMin,
    required this.precio,
    required this.color,
    this.activo = true,
    this.profesionales = const [],
  });

  final int id;
  final String nombre;
  final String? descripcion;
  final int duracionMin;
  final double precio;
  final int color;
  final bool activo;
  final List<int> profesionales;

  factory ServicioAgenda.fromJson(Map<String, dynamic> j) => ServicioAgenda(
        id: asInt(j['id']),
        nombre: asString(j['nombre']),
        descripcion: asStringOrNull(j['descripcion']),
        duracionMin: asInt(j['duracion_min'], fallback: 30),
        precio: asDouble(j['precio']),
        color: colorDesdeHex(j['color'], fallback: 0xFF2563EB),
        activo: asBool(j['activo'], fallback: true),
        profesionales: [for (final p in (j['profesionales'] as List? ?? const [])) asInt(p)],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'duracion_min': duracionMin,
        'precio': precio,
        'color': colorAHex(color),
        'activo': activo,
        'profesionales': profesionales,
      };
}

class BloqueoAgenda {
  const BloqueoAgenda({required this.id, required this.profesionalId, required this.fecha, this.inicio, this.fin, this.motivo});
  final int id;
  final int profesionalId;
  final String fecha;
  final String? inicio;
  final String? fin;
  final String? motivo;

  bool get diaCompleto => inicio == null || fin == null;

  factory BloqueoAgenda.fromJson(Map<String, dynamic> j) => BloqueoAgenda(
        id: asInt(j['id']),
        profesionalId: asInt(j['profesional_id']),
        fecha: asFecha(j['fecha']),
        inicio: asHora(j['inicio']),
        fin: asHora(j['fin']),
        motivo: asStringOrNull(j['motivo']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'profesional_id': profesionalId, 'fecha': fecha, 'inicio': inicio, 'fin': fin, 'motivo': motivo};
}

/// Configuración completa del negocio del usuario (GET /api/agenda).
class ConfigAgenda {
  const ConfigAgenda({this.negocio, this.profesionales = const [], this.servicios = const [], this.bloqueos = const []});
  final NegocioAgenda? negocio;
  final List<ProfesionalAgenda> profesionales;
  final List<ServicioAgenda> servicios;
  final List<BloqueoAgenda> bloqueos;

  static const vacia = ConfigAgenda();

  bool get tieneNegocio => negocio != null;
  List<ProfesionalAgenda> get equipoActivo => [for (final p in profesionales) if (p.activo) p];
  List<ServicioAgenda> get serviciosActivos => [for (final s in servicios) if (s.activo) s];
  ProfesionalAgenda? profesional(int id) => profesionales.where((p) => p.id == id).firstOrNull;
  ServicioAgenda? servicio(int id) => servicios.where((s) => s.id == id).firstOrNull;

  factory ConfigAgenda.fromJson(Map<String, dynamic> j) => j['negocio'] == null
      ? vacia
      : ConfigAgenda(
          negocio: NegocioAgenda.fromJson(asMap(j['negocio'])),
          profesionales: parseList(j['profesionales'], ProfesionalAgenda.fromJson),
          servicios: parseList(j['servicios'], ServicioAgenda.fromJson),
          bloqueos: parseList(j['bloqueos'], BloqueoAgenda.fromJson),
        );

  Map<String, dynamic> toJson() => {
        'negocio': negocio?.toJson(),
        'profesionales': [for (final p in profesionales) p.toJson()],
        'servicios': [for (final s in servicios) s.toJson()],
        'bloqueos': [for (final b in bloqueos) b.toJson()],
      };
}

enum EstadoCita {
  pendiente('Por confirmar'),
  confirmada('Confirmada'),
  completada('Completada'),
  noAsistio('No asistió'),
  cancelada('Cancelada'),
  expirada('Sin confirmar');

  const EstadoCita(this.etiqueta);
  final String etiqueta;

  static EstadoCita desde(String v) => switch (v) {
        'confirmada' => confirmada,
        'completada' => completada,
        'no_asistio' => noAsistio,
        'cancelada' => cancelada,
        'expirada' => expirada,
        _ => pendiente,
      };

  String get api => switch (this) {
        noAsistio => 'no_asistio',
        _ => name,
      };

  bool get activa => this == confirmada || this == pendiente;
}

/// Cita vista por el negocio, el profesional o el cliente.
class CitaAgenda {
  const CitaAgenda({
    required this.id,
    required this.token,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    this.servicioId,
    required this.servicioNombre,
    required this.duracionMin,
    required this.precio,
    required this.clienteNombre,
    this.clienteWhatsapp,
    this.nota,
    required this.origen,
    required this.estado,
    required this.profesionalId,
    required this.profesionalNombre,
    required this.profesionalColor,
    required this.negocioNombre,
    required this.slug,
    required this.negocioColor,
    required this.rol,
    this.motivoCancelacion,
  });

  final int id;
  final String token;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final int? servicioId;
  final String servicioNombre;
  final int duracionMin;
  final double precio;
  final String clienteNombre;
  final String? clienteWhatsapp;
  final String? nota;

  /// 'web', 'app' (cliente con la app) o 'negocio' (agendada a mano).
  final String origen;
  final EstadoCita estado;
  final int profesionalId;
  final String profesionalNombre;
  final int profesionalColor;
  final String negocioNombre;
  final String slug;
  final int negocioColor;

  /// 'dueno', 'equipo' (me la asignaron en otro negocio) o 'cliente'.
  final String rol;
  final String? motivoCancelacion;

  CitaAgenda copyWith({EstadoCita? estado}) => CitaAgenda(
        id: id,
        token: token,
        fecha: fecha,
        horaInicio: horaInicio,
        horaFin: horaFin,
        servicioId: servicioId,
        servicioNombre: servicioNombre,
        duracionMin: duracionMin,
        precio: precio,
        clienteNombre: clienteNombre,
        clienteWhatsapp: clienteWhatsapp,
        nota: nota,
        origen: origen,
        estado: estado ?? this.estado,
        profesionalId: profesionalId,
        profesionalNombre: profesionalNombre,
        profesionalColor: profesionalColor,
        negocioNombre: negocioNombre,
        slug: slug,
        negocioColor: negocioColor,
        rol: rol,
        motivoCancelacion: motivoCancelacion,
      );

  factory CitaAgenda.fromJson(Map<String, dynamic> j) => CitaAgenda(
        id: asInt(j['id']),
        token: asString(j['token']),
        fecha: asFecha(j['fecha']),
        horaInicio: asHora(j['hora_inicio']) ?? '00:00',
        horaFin: asHora(j['hora_fin']) ?? '00:00',
        servicioId: asIntOrNull(j['servicio_id']),
        servicioNombre: asString(j['servicio_nombre']),
        duracionMin: asInt(j['duracion_min']),
        precio: asDouble(j['precio']),
        clienteNombre: asString(j['cliente_nombre']),
        clienteWhatsapp: asStringOrNull(j['cliente_whatsapp']),
        nota: asStringOrNull(j['nota']),
        origen: asString(j['origen'], fallback: 'web'),
        estado: EstadoCita.desde(asString(j['estado'])),
        profesionalId: asInt(j['profesional_id']),
        profesionalNombre: asString(j['profesional_nombre']),
        profesionalColor: colorDesdeHex(j['profesional_color'], fallback: 0xFF2563EB),
        negocioNombre: asString(j['negocio_nombre']),
        slug: asString(j['slug']),
        negocioColor: colorDesdeHex(j['negocio_color'], fallback: 0xFF2563EB),
        rol: asString(j['rol'], fallback: 'dueno'),
        motivoCancelacion: asStringOrNull(j['motivo_cancelacion']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'token': token,
        'fecha': fecha,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'servicio_id': servicioId,
        'servicio_nombre': servicioNombre,
        'duracion_min': duracionMin,
        'precio': precio,
        'cliente_nombre': clienteNombre,
        'cliente_whatsapp': clienteWhatsapp,
        'nota': nota,
        'origen': origen,
        'estado': estado.api,
        'profesional_id': profesionalId,
        'profesional_nombre': profesionalNombre,
        'profesional_color': colorAHex(profesionalColor),
        'negocio_nombre': negocioNombre,
        'slug': slug,
        'negocio_color': colorAHex(negocioColor),
        'rol': rol,
        'motivo_cancelacion': motivoCancelacion,
      };
}

// ─────────────────────── Página pública (reservar) ───────────────────────

class PaginaAgenda {
  const PaginaAgenda({required this.slug, required this.tipo, required this.nombre, required this.rubro, this.descripcion, this.direccion, this.whatsapp, required this.color, required this.servicios, required this.profesionales});
  final String slug;
  final String tipo;
  final String nombre;
  final String rubro;
  final String? descripcion;
  final String? direccion;
  final String? whatsapp;
  final int color;
  final List<ServicioAgenda> servicios;
  final List<ProfesionalAgenda> profesionales;

  factory PaginaAgenda.fromJson(Map<String, dynamic> j) {
    final n = asMap(j['negocio']);
    return PaginaAgenda(
      slug: asString(n['slug']),
      tipo: asString(n['tipo']),
      nombre: asString(n['nombre']),
      rubro: asString(n['rubro']),
      descripcion: asStringOrNull(n['descripcion']),
      direccion: asStringOrNull(n['direccion']),
      whatsapp: asStringOrNull(n['whatsapp']),
      color: colorDesdeHex(n['color'], fallback: 0xFF2563EB),
      servicios: parseList(j['servicios'], ServicioAgenda.fromJson),
      profesionales: parseList(j['profesionales'], ProfesionalAgenda.fromJson),
    );
  }
}

class Turno {
  const Turno(this.hora, this.profesionales);
  final String hora;
  final List<int> profesionales;
}

class DiaTurnos {
  const DiaTurnos(this.fecha, this.turnos);
  final String fecha;
  final List<Turno> turnos;

  factory DiaTurnos.fromJson(Map<String, dynamic> j) => DiaTurnos(asFecha(j['fecha']), [
        for (final t in asMapList(j['turnos'])) Turno(asHora(t['hora']) ?? '00:00', [for (final p in (t['profesionales'] as List? ?? const [])) asInt(p)]),
      ]);
}

/// Reserva vista por quien la hizo (respuesta de las rutas públicas).
class ReservaPublica {
  const ReservaPublica({
    required this.token,
    required this.estado,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.servicio,
    required this.precio,
    required this.profesional,
    required this.whatsapp,
    required this.segundosRestantes,
    required this.negocio,
    this.direccion,
  });
  final String token;
  final EstadoCita estado;
  final String fecha;
  final String horaInicio;
  final String horaFin;
  final String servicio;
  final double precio;
  final String profesional;
  final String? whatsapp;
  final int segundosRestantes;
  final String negocio;
  final String? direccion;

  factory ReservaPublica.fromJson(Map<String, dynamic> j) {
    final n = asMap(j['negocio']);
    return ReservaPublica(
      token: asString(j['token']),
      estado: EstadoCita.desde(asString(j['estado'])),
      fecha: asFecha(j['fecha']),
      horaInicio: asHora(j['hora_inicio']) ?? '00:00',
      horaFin: asHora(j['hora_fin']) ?? '00:00',
      servicio: asString(j['servicio']),
      precio: asDouble(j['precio']),
      profesional: asString(asMap(j['profesional'])['nombre']),
      whatsapp: asStringOrNull(j['whatsapp']),
      segundosRestantes: asInt(j['segundos_restantes']),
      negocio: asString(n['nombre']),
      direccion: asStringOrNull(n['direccion']),
    );
  }
}
