// Textos de los recordatorios, portados de cron/index.js.
//
// La app los usa para (1) mostrar la vista previa exacta del WhatsApp que
// enviará el servidor y (2) las notificaciones locales del teléfono, así el
// usuario recibe lo mismo por los dos canales.

import '../../core/dates.dart';
import '../../core/holidays.dart';
import '../../core/money.dart';
import '../../data/models.dart';
import 'event_categories.dart';

const _diasSemana = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];

/// "martes 23 de septiembre de 2026" (fechaLegible del cron).
String fechaLegibleCron(String fecha) {
  final d = parseYmd(fecha);
  return '${_diasSemana[d.weekday - 1]} ${d.day} de ${mesesLargos[d.month - 1].toLowerCase()} de ${d.year}';
}

/// "2:30 PM" (formatTime12h del cron).
String hora12Cron(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '';
  final p = hhmm.split(':');
  final h = int.parse(p[0]);
  return '${h % 12 == 0 ? 12 : h % 12}:${p[1]} ${h >= 12 ? 'PM' : 'AM'}';
}

/// Mensaje de "¡Es la hora!" (buildTimedExactMsg).
String mensajeExacto(Evento e) {
  final (emoji, nombre) = metaCron(e.categoria);
  final ubic = e.ubicacion.isEmpty ? '' : '\n📍 *Lugar:* ${e.ubicacion}';
  final cuerpo = switch (e.categoria) {
    'reunion' => 'Es momento de tu reunión *${e.titulo}*. ¡Que sea muy productiva!',
    'doctor' || 'dentista' => 'Es la hora de tu cita: *${e.titulo}*. Lleva tus documentos y llega con tiempo. 🩺',
    'medicamentos' => 'Es momento de tomar tu medicamento: *${e.titulo}*. Cuida tu salud. 💊',
    'cita_amor' => 'Llegó la hora de tu cita: *${e.titulo}*. ¡Disfruta cada momento! ❤️',
    'mecanica' || 'moto' || 'carro' => 'Recordatorio: *${e.titulo}*. Dale el mantenimiento que merece. 🔧',
    'matrimonio' => 'Hoy es el gran momento: *${e.titulo}*. 💍',
    _ => 'Tu compromiso *${e.titulo}* es ahora mismo.',
  };
  return '$emoji *$nombre — ¡Es la hora!*\n\n$cuerpo\n\n🕒 *Hora:* ${hora12Cron(e.hora)}$ubic';
}

/// Mensaje de "Faltan 30 minutos" (buildTimedPreMsg).
String mensajePrevio(Evento e) {
  final (emoji, nombre) = metaCron(e.categoria);
  final ubic = e.ubicacion.isEmpty ? '' : '\n📍 *Lugar:* ${e.ubicacion}';
  return '⏰ *Faltan 30 minutos* $emoji\n\nTu ${nombre.toLowerCase()} *${e.titulo}* comienza a las *${hora12Cron(e.hora)}*.$ubic\n\n💡 Te avisaremos de nuevo a la hora exacta.';
}

/// Contenido del resumen de las 7:00 a. m. de un día.
class ResumenDia {
  const ResumenDia({
    required this.fecha,
    this.cumples = const [],
    this.recordatorios = const [],
    this.creditos = const [],
    this.festivo,
    this.puente,
    this.cdtsQueVencen = const [],
  });

  final String fecha;
  final List<Cumple> cumples;
  final List<Evento> recordatorios;
  final List<Evento> creditos;
  final Festivo? festivo;

  /// Festivo del lunes siguiente (se avisa viernes y sábado).
  final Festivo? puente;
  final List<Cuenta> cdtsQueVencen;

  bool get vacio => cumples.isEmpty && recordatorios.isEmpty && creditos.isEmpty && festivo == null && puente == null && cdtsQueVencen.isEmpty;

  int get elementos => cumples.length + recordatorios.length + creditos.length + cdtsQueVencen.length;
}

/// Texto del resumen matutino (construirResumen del cron).
String mensajeResumen(ResumenDia r) {
  final partes = <String>[
    '☀️ *Buenos días* ☀️',
    'Esto es lo que tienes para hoy, ${fechaLegibleCron(r.fecha)}:',
  ];
  if (r.festivo != null) {
    partes.add('\n🇨🇴 *Día festivo*\nHoy es festivo en Colombia: *${r.festivo!.nombre}*. ¡Disfruta de este merecido descanso! 🏖️');
  }
  if (r.cumples.isNotEmpty) {
    final b = StringBuffer('\n🎂 *Cumpleaños de hoy*');
    for (final c in r.cumples) {
      b.write('\n• *${c.nombre}*');
      if (c.telefono.isNotEmpty) b.write(' — 📞 ${c.telefono}');
      if (c.mensaje.isNotEmpty) b.write('\n   _"${c.mensaje}"_');
    }
    b.write('\n¡No olvides felicitarle en su día! 🥳');
    partes.add(b.toString());
  }
  if (r.recordatorios.isNotEmpty) {
    final b = StringBuffer('\n📋 *Recordatorios y pagos de hoy*');
    for (final e in r.recordatorios) {
      b.write('\n• ${metaCron(e.categoria).$1} *${e.titulo}*');
      if (e.costo > 0) b.write(' — ${cop(e.costo)}');
      if (e.ubicacion.isNotEmpty) b.write(' _(${e.ubicacion})_');
    }
    partes.add(b.toString());
  }
  if (r.creditos.isNotEmpty) {
    final b = StringBuffer('\n💳 *Pagos de tarjeta de crédito*');
    var total = 0.0;
    for (final e in r.creditos) {
      total += e.costo;
      b.write('\n• *${e.titulo}*');
      if (e.costo > 0) b.write(' — ${cop(e.costo)}');
    }
    if (r.creditos.length > 1) b.write('\n💰 *Total de hoy:* ${cop(total)}');
    b.write('\n_Paga a tiempo para mantener tu vida crediticia sana y evitar intereses._');
    partes.add(b.toString());
  }
  for (final c in r.cdtsQueVencen) {
    partes.add('\n⏰ *¡Tu CDT "${c.nombre}" vence hoy!*\n💰 *Monto disponible:* ${cop(c.saldo)}');
  }
  if (r.puente != null) {
    partes.add('\n🏖️ *¡Puente festivo a la vista!*\nEste lunes es festivo por *${r.puente!.nombre}*. ¡Prepárate para un fin de semana largo! ✈️');
  }
  partes.add('\n✨ Que tengas un día excelente. Estamos contigo para que no se te escape nada.');
  return partes.join('\n');
}

/// Quita el formato de WhatsApp (*negrita*, _cursiva_) para una notificación.
String textoPlano(String s) =>
    s.replaceAll('*', '').replaceAllMapped(RegExp(r'(^|\s)_([^_\n]+)_', multiLine: true), (m) => '${m[1]}${m[2]}');

/// Cómo se le avisará de un evento (para explicarlo en el formulario).
String descripcionAvisos({required String categoria, required String? hora, int? tarjetaCreditoId}) {
  if (categoria == 'cumpleanos') return 'Te recordaremos el cumpleaños en el resumen de las 7:00 a. m.';
  if (esTodoElDiaCron(categoria: categoria, hora: hora, tarjetaCreditoId: tarjetaCreditoId)) {
    return 'Te llegará en el resumen del día a las 7:00 a. m. por WhatsApp y en tu teléfono.';
  }
  return 'Te avisaremos 30 minutos antes y a la hora exacta (${hora12Cron(hora)}) por WhatsApp y en tu teléfono.';
}
