// Planificador de notificaciones locales — mismas reglas que cron/index.js.
//
// · Eventos con hora (salvo categorías "de todo el día" y cobros de tarjeta):
//   aviso 30 minutos antes y otro a la hora exacta.
// · Todo lo demás (sin hora, cobros de tarjeta, arriendo, aceite, servicios,
//   aniversario, mesiversario), cumpleaños, festivo, puente festivo y CDT que
//   vencen: UN resumen por día a las 7:00 a. m.
// · Horario de Colombia (UTC−5 fijo, sin horario de verano), igual que el cron,
//   para que el teléfono y el WhatsApp coincidan al minuto.

import '../../core/dates.dart';
import '../../core/holidays.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import '../events/event_categories.dart';
import '../events/mensajes.dart';
import '../finance/finance_logic.dart';

/// Colombia no tiene horario de verano desde 1993.
const _offsetBogota = Duration(hours: -5);

/// Instante (UTC) de una fecha y hora de Bogotá.
DateTime instanteBogota(String fecha, String? hora) {
  final d = parseYmd(fecha);
  final p = (hora ?? '00:00').split(':');
  return DateTime.utc(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1])).subtract(_offsetBogota);
}

/// Fecha (YYYY-MM-DD) en Bogotá de un instante.
String fechaBogota(DateTime instante) => ymd(instante.toUtc().add(_offsetBogota));

enum CanalAviso { evento, resumen }

class AvisoProgramado {
  const AvisoProgramado({required this.id, required this.cuando, required this.titulo, required this.cuerpo, required this.payload, required this.canal});
  final int id;

  /// Instante en UTC.
  final DateTime cuando;
  final String titulo;
  final String cuerpo;

  /// `dia:YYYY-MM-DD` — al tocarla se abre ese día en el calendario.
  final String payload;
  final CanalAviso canal;
}

/// Id estable (31 bits) a partir de una clave: reprogramar no duplica avisos.
int idAviso(String clave) {
  var h = 0x811c9dc5;
  for (final c in clave.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

/// Resumen de las 7:00 a. m. de un día (qué incluiría el WhatsApp del cron).
ResumenDia resumenDelDia(String fecha, {required List<Evento> eventos, required List<Cumple> cumples, required List<Cuenta> cuentas}) {
  final delDia = eventos.where((e) => e.fecha == fecha && esTodoElDiaCron(categoria: e.categoria, hora: e.hora, tarjetaCreditoId: e.tarjetaCreditoId));
  final d = parseYmd(fecha);
  Festivo? puente;
  if (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
    puente = festivoEn(ymd(DateTime(d.year, d.month, d.day + (d.weekday == DateTime.friday ? 3 : 2))));
  }
  return ResumenDia(
    fecha: fecha,
    cumples: [for (final c in cumples) if (c.fecha.length >= 10 && c.fecha.substring(5) == fecha.substring(5)) c],
    recordatorios: [for (final e in delDia) if (e.tarjetaCreditoId == null) e],
    creditos: [for (final e in delDia) if (e.tarjetaCreditoId != null) e],
    festivo: festivoEn(fecha),
    puente: puente,
    cdtsQueVencen: [for (final c in cuentas) if (c.tipo == 'cdt' && fechaVencimiento(c) == fecha) c],
  );
}

String _tituloResumen(ResumenDia r) {
  if (r.festivo != null && r.elementos == 0) return '🇨🇴 Hoy es festivo: ${r.festivo!.nombre}';
  final n = r.elementos;
  if (n == 0) return '☀️ Buenos días';
  return '☀️ Buenos días · $n ${n == 1 ? 'pendiente' : 'pendientes'} hoy';
}

/// Cuerpo corto del resumen para la notificación (el detalle completo se ve
/// al expandirla o al abrir la app).
String _cuerpoResumen(ResumenDia r) {
  final l = <String>[];
  if (r.festivo != null) l.add('🇨🇴 Festivo: ${r.festivo!.nombre}');
  for (final c in r.cumples) {
    l.add('🎂 Cumpleaños de ${c.nombre}');
  }
  for (final e in r.recordatorios) {
    l.add('${metaCron(e.categoria).$1} ${e.titulo}${e.costo > 0 ? ' · ${cop(e.costo)}' : ''}');
  }
  for (final e in r.creditos) {
    l.add('💳 ${e.titulo}');
  }
  for (final c in r.cdtsQueVencen) {
    l.add('⏰ Vence tu CDT ${c.nombre}');
  }
  if (r.puente != null) l.add('🏖️ Puente festivo: el lunes es ${r.puente!.nombre}');
  return l.join('\n');
}

/// Avisos a programar desde [ahora] durante [dias] días, ordenados por hora y
/// recortados a [max] (iOS conserva como máximo 64 notificaciones pendientes).
List<AvisoProgramado> planificarAvisos({
  required List<Evento> eventos,
  required List<Cumple> cumples,
  required List<Cuenta> cuentas,
  required DateTime ahora,
  int dias = 14,
  bool aviso30 = true,
  bool resumen = true,
  int max = 60,
}) {
  final out = <AvisoProgramado>[];
  final hoy = fechaBogota(ahora);
  final fin = sumarDiasYmd(hoy, dias);
  final enRango = eventos.where((e) => e.fecha.compareTo(hoy) >= 0 && e.fecha.compareTo(fin) < 0);

  for (final e in enRango) {
    if (esTodoElDiaCron(categoria: e.categoria, hora: e.hora, tarjetaCreditoId: e.tarjetaCreditoId)) continue;
    final exacto = instanteBogota(e.fecha, e.hora);
    final (emoji, nombre) = metaCron(e.categoria);
    if (exacto.isAfter(ahora)) {
      out.add(AvisoProgramado(
        id: idAviso('ev:${e.id}:exacto'),
        cuando: exacto,
        titulo: '$emoji ${e.titulo}',
        cuerpo: textoPlano(mensajeExacto(e)).replaceFirst(RegExp(r'^.*\n\n'), ''),
        payload: 'dia:${e.fecha}',
        canal: CanalAviso.evento,
      ));
    }
    final previo = exacto.subtract(const Duration(minutes: 30));
    if (aviso30 && previo.isAfter(ahora)) {
      out.add(AvisoProgramado(
        id: idAviso('ev:${e.id}:30m'),
        cuando: previo,
        titulo: '⏰ En 30 minutos: ${e.titulo}',
        cuerpo: 'Tu ${nombre.toLowerCase()} comienza a las ${hora12Cron(e.hora)}${e.ubicacion.isEmpty ? '' : ' · ${e.ubicacion}'}.',
        payload: 'dia:${e.fecha}',
        canal: CanalAviso.evento,
      ));
    }
  }

  if (resumen) {
    for (var i = 0; i < dias; i++) {
      final f = sumarDiasYmd(hoy, i);
      final cuando = instanteBogota(f, '07:00');
      if (!cuando.isAfter(ahora)) continue;
      final r = resumenDelDia(f, eventos: eventos, cumples: cumples, cuentas: cuentas);
      if (r.vacio) continue;
      out.add(AvisoProgramado(
        id: idAviso('resumen:$f'),
        cuando: cuando,
        titulo: _tituloResumen(r),
        cuerpo: _cuerpoResumen(r),
        payload: 'dia:$f',
        canal: CanalAviso.resumen,
      ));
    }
  }

  out.sort((a, b) => a.cuando.compareTo(b.cuando));
  return out.length > max ? out.sublist(0, max) : out;
}
