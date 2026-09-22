import 'package:flutter/material.dart';

/// Iconos disponibles para categorías de finanzas y metas, guardados en la base
/// por su nombre Material (igual que en la web). Nombre → [IconData].
const iconosCategoria = <(String, String, IconData)>[
  ('sell', 'Etiqueta', Icons.sell_rounded),
  ('shopping_cart', 'Carrito', Icons.shopping_cart_rounded),
  ('restaurant', 'Restaurante', Icons.restaurant_rounded),
  ('fastfood', 'Comida rápida', Icons.fastfood_rounded),
  ('local_cafe', 'Café', Icons.local_cafe_rounded),
  ('directions_car', 'Carro', Icons.directions_car_rounded),
  ('two_wheeler', 'Moto', Icons.two_wheeler_rounded),
  ('local_gas_station', 'Gasolina', Icons.local_gas_station_rounded),
  ('flight', 'Vuelo', Icons.flight_rounded),
  ('home', 'Hogar', Icons.home_rounded),
  ('real_estate_agent', 'Arriendo', Icons.real_estate_agent_rounded),
  ('receipt_long', 'Factura', Icons.receipt_long_rounded),
  ('bolt', 'Electricidad', Icons.bolt_rounded),
  ('water_drop', 'Agua', Icons.water_drop_rounded),
  ('wifi', 'Internet', Icons.wifi_rounded),
  ('phone_iphone', 'Celular', Icons.phone_iphone_rounded),
  ('sports_esports', 'Videojuegos', Icons.sports_esports_rounded),
  ('movie', 'Cine', Icons.movie_rounded),
  ('fitness_center', 'Gimnasio', Icons.fitness_center_rounded),
  ('medication', 'Salud', Icons.medication_rounded),
  ('school', 'Educación', Icons.school_rounded),
  ('savings', 'Ahorro', Icons.savings_rounded),
  ('pets', 'Mascotas', Icons.pets_rounded),
  ('child_care', 'Niños', Icons.child_care_rounded),
  ('checkroom', 'Ropa', Icons.checkroom_rounded),
  ('card_giftcard', 'Regalo', Icons.card_giftcard_rounded),
  ('volunteer_activism', 'Donación', Icons.volunteer_activism_rounded),
  ('build', 'Reparación', Icons.build_rounded),
  ('payments', 'Pago', Icons.payments_rounded),
  ('attach_money', 'Dinero', Icons.attach_money_rounded),
  ('work', 'Trabajo', Icons.work_rounded),
  ('celebration', 'Celebración', Icons.celebration_rounded),
  ('beach_access', 'Vacaciones', Icons.beach_access_rounded),
  ('laptop', 'Tecnología', Icons.laptop_mac_rounded),
];

final Map<String, IconData> _porNombre = {for (final (n, _, i) in iconosCategoria) n: i};

IconData iconoPorNombre(String? nombre) => _porNombre[nombre] ?? Icons.sell_rounded;
