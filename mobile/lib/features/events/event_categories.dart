import 'package:flutter/material.dart';

/// Categoría de evento: la misma lista que la web, con un color propio para
/// que cada tipo se reconozca en el calendario sin leer.
class EventCategory {
  const EventCategory(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

const eventCategories = <EventCategory>[
  EventCategory('reunion', 'Reunión', Icons.groups_rounded, Color(0xFF38BDF8)),
  EventCategory('cumpleanos', 'Cumpleaños', Icons.cake_rounded, Color(0xFFF472B6)),
  EventCategory('moto', 'Moto', Icons.two_wheeler_rounded, Color(0xFFF97316)),
  EventCategory('carro', 'Carro', Icons.directions_car_rounded, Color(0xFF60A5FA)),
  EventCategory('casa', 'Casa', Icons.home_rounded, Color(0xFF34D399)),
  EventCategory('arriendo', 'Arriendo', Icons.real_estate_agent_rounded, Color(0xFFA78BFA)),
  EventCategory('aceite_moto', 'Aceite (Moto)', Icons.water_drop_rounded, Color(0xFFFBBF24)),
  EventCategory('mecanica', 'Mecánica', Icons.handyman_rounded, Color(0xFF94A3B8)),
  EventCategory('servicios', 'Servicios', Icons.receipt_long_rounded, Color(0xFF2DD4BF)),
  EventCategory('doctor', 'Doctor', Icons.local_hospital_rounded, Color(0xFFF87171)),
  EventCategory('medicamentos', 'Medicamentos', Icons.medication_rounded, Color(0xFFFB7185)),
  EventCategory('dentista', 'Dentista', Icons.health_and_safety_rounded, Color(0xFF22D3EE)),
  EventCategory('cita_amor', 'Cita amor', Icons.favorite_rounded, Color(0xFFF43F5E)),
  EventCategory('aniversario', 'Aniversario', Icons.celebration_rounded, Color(0xFFE879F9)),
  EventCategory('matrimonio', 'Matrimonio', Icons.diversity_1_rounded, Color(0xFFC084FC)),
  EventCategory('mesiversario', 'Mesiversario', Icons.favorite_border_rounded, Color(0xFFFDA4AF)),
];

final Map<String, EventCategory> _porValor = {for (final c in eventCategories) c.value: c};

EventCategory categoriaEvento(String? value) =>
    _porValor[value] ?? const EventCategory('general', 'General', Icons.event_rounded, Color(0xFF94A3B8));

/// Frecuencias de repetición de un evento.
const frecuenciasEvento = <(String, String)>[
  ('unica', 'Única'),
  ('diaria', 'Diaria'),
  ('quincenal', 'Quincenal'),
  ('mensual', 'Mensual'),
  ('trimestral', 'Trimestral'),
  ('semestral', 'Semestral'),
  ('anual', 'Anual'),
];

String frecuenciaLabel(String? v) {
  for (final (k, l) in frecuenciasEvento) {
    if (k == v) return l;
  }
  return 'Única';
}

bool esAnual(String? frecuencia) => frecuencia == 'anual';
