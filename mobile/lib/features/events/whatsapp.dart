import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dates.dart';
import '../../core/db/database.dart';
import '../../core/money.dart';

/// Mensaje de recordatorio (mismo formato que el simulador de la web, sin el
/// enlace de confirmación, que dependía del servidor).
String mensajeRecordatorio(Evento e) {
  final hora = e.hora == null ? '' : ' a las ${hora12(e.hora)}';
  final valor = e.tipoTransaccion != 'ninguno' && e.costo > 0 ? '\n💰 Valor: ${cop(e.costo)}' : '';
  final lugar = e.ubicacion.isEmpty ? '' : '\n📍 ${e.ubicacion}';
  return 'Hola! Te recuerdo tu compromiso:\n📌 *${e.titulo}*\n📅 Fecha: ${fechaLarga(e.fecha)}$hora$lugar$valor';
}

String mensajeCumple(Cumple c) {
  if (c.mensaje.trim().isNotEmpty) return c.mensaje.trim();
  return '¡Feliz cumpleaños, ${c.nombre}! 🎂 Que tengas un día increíble.';
}

/// Abre WhatsApp con el texto (y el número si se conoce).
Future<bool> abrirWhatsApp(String texto, {String? telefono}) async {
  var numero = (telefono ?? '').replaceAll(RegExp(r'\D'), '');
  // Números colombianos de 10 dígitos: se antepone el indicativo 57.
  if (numero.length == 10) numero = '57$numero';
  final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> copiar(String texto) => Clipboard.setData(ClipboardData(text: texto));
