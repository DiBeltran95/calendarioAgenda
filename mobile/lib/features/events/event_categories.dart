import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import '../../app/theme/tokens.dart';

/// Categoría de evento: la misma lista que la web, con un color propio para
/// que cada tipo se reconozca en el calendario sin leer.
class EventCategory {
  const EventCategory(this.value, this.label, this.icon, this.par);
  final String value;
  final String label;
  final IconData icon;
  final ColorPar par;

  Color colorDe(BuildContext context) => context.par(par);
}

const eventCategories = <EventCategory>[
  EventCategory('reunion', 'Reunión', Icons.groups_rounded, ColorPar(Color(0xFF0369A1), Color(0xFF38BDF8))),
  EventCategory('cumpleanos', 'Cumpleaños', Icons.cake_rounded, ColorPar(Color(0xFFBE185D), Color(0xFFF472B6))),
  EventCategory('moto', 'Moto', Icons.two_wheeler_rounded, ColorPar(Color(0xFFB83D0B), Color(0xFFFB923C))),
  EventCategory('carro', 'Carro', Icons.directions_car_rounded, ColorPar(Color(0xFF1D4ED8), Color(0xFF60A5FA))),
  EventCategory('casa', 'Casa', Icons.home_rounded, ColorPar(Color(0xFF047857), Color(0xFF34D399))),
  EventCategory('arriendo', 'Arriendo', Icons.real_estate_agent_rounded, ColorPar(Color(0xFF6D28D9), Color(0xFFA78BFA))),
  EventCategory('aceite_moto', 'Aceite (Moto)', Icons.water_drop_rounded, ColorPar(Color(0xFF8F5706), Color(0xFFFBBF24))),
  EventCategory('mecanica', 'Mecánica', Icons.handyman_rounded, ColorPar(Color(0xFF475569), Color(0xFF94A3B8))),
  EventCategory('servicios', 'Servicios', Icons.receipt_long_rounded, ColorPar(Color(0xFF0F766E), Color(0xFF2DD4BF))),
  EventCategory('doctor', 'Doctor', Icons.local_hospital_rounded, ColorPar(Color(0xFFB91C1C), Color(0xFFF87171))),
  EventCategory('medicamentos', 'Medicamentos', Icons.medication_rounded, ColorPar(Color(0xFFBE123C), Color(0xFFFB7185))),
  EventCategory('dentista', 'Dentista', Icons.health_and_safety_rounded, ColorPar(Color(0xFF0E7490), Color(0xFF22D3EE))),
  EventCategory('cita_amor', 'Cita amor', Icons.favorite_rounded, ColorPar(Color(0xFFBE123C), Color(0xFFFB7185))),
  EventCategory('aniversario', 'Aniversario', Icons.celebration_rounded, ColorPar(Color(0xFFA21CAF), Color(0xFFE879F9))),
  EventCategory('matrimonio', 'Matrimonio', Icons.diversity_1_rounded, ColorPar(Color(0xFF7E22CE), Color(0xFFC084FC))),
  EventCategory('mesiversario', 'Mesiversario', Icons.favorite_border_rounded, ColorPar(Color(0xFFBE185D), Color(0xFFFDA4AF))),
];

final Map<String, EventCategory> _porValor = {for (final c in eventCategories) c.value: c};

EventCategory categoriaEvento(String? value) =>
    _porValor[value] ?? const EventCategory('general', 'General', Icons.event_rounded, ColorPar(Color(0xFF475569), Color(0xFF94A3B8)));

/// Frecuencias que ofrece el formulario.
const frecuenciasEvento = <(String, String)>[
  ('unica', 'Una vez'),
  ('quincenal', 'Quincenal'),
  ('mensual', 'Mensual'),
  ('trimestral', 'Trimestral'),
  ('semestral', 'Semestral'),
  ('anual', 'Anual'),
];

/// Todas las que entiende el servidor (incluye "diaria", creada desde la web).
const _todasFrecuencias = <String, String>{
  'unica': 'Una vez',
  'diaria': 'Diaria',
  'quincenal': 'Quincenal',
  'mensual': 'Mensual',
  'trimestral': 'Trimestral',
  'semestral': 'Semestral',
  'anual': 'Anual',
};

String frecuenciaLabel(String? v) => _todasFrecuencias[v] ?? 'Una vez';

/// Explicación corta de la repetición, para el formulario.
String frecuenciaDetalle(String v) => switch (v) {
      'quincenal' => 'Cada 15 días',
      'mensual' => 'Cada mes, el mismo día',
      'trimestral' => 'Cada 3 meses',
      'semestral' => 'Cada 6 meses',
      'anual' => 'Cada año, la misma fecha',
      'diaria' => 'Todos los días',
      _ => 'Solo en la fecha elegida',
    };

// ─────────────── Reglas de notificación (idénticas al cron) ───────────────

/// Categorías que se avisan en el resumen de las 7:00 a. m. y no con el patrón
/// "30 minutos antes + a la hora" (cron/index.js · CATEGORIAS_TODO_EL_DIA).
const categoriasTodoElDia = {'arriendo', 'aceite_moto', 'servicios', 'aniversario', 'mesiversario'};

/// Emoji y nombre con que el cron presenta cada categoría en WhatsApp.
const metaCategoriaCron = <String, (String, String)>{
  'reunion': ('📅', 'Reunión'),
  'cumpleanos': ('🎂', 'Cumpleaños'),
  'moto': ('🏍️', 'Moto'),
  'carro': ('🚗', 'Carro'),
  'casa': ('🏠', 'Casa'),
  'arriendo': ('🏠', 'Arriendo'),
  'aceite_moto': ('🛢️', 'Cambio de aceite'),
  'mecanica': ('🔧', 'Mecánica'),
  'servicios': ('🧾', 'Servicios públicos'),
  'doctor': ('🩺', 'Cita médica'),
  'medicamentos': ('💊', 'Medicamentos'),
  'dentista': ('🦷', 'Odontología'),
  'cita_amor': ('❤️', 'Cita romántica'),
  'aniversario': ('💑', 'Aniversario'),
  'matrimonio': ('💍', 'Matrimonio'),
  'mesiversario': ('🌹', 'Mesiversario'),
};

(String, String) metaCron(String categoria) => metaCategoriaCron[categoria] ?? ('📌', 'Recordatorio');

/// true si el evento se avisa en el resumen matutino (sin hora, cobro de
/// tarjeta o categoría "de todo el día").
bool esTodoElDiaCron({required String categoria, required String? hora, int? tarjetaCreditoId}) {
  if (tarjetaCreditoId != null) return true;
  if (hora == null || hora.isEmpty) return true;
  return categoriasTodoElDia.contains(categoria);
}

bool esAnual(String? frecuencia) => frecuencia == 'anual';
