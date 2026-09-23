/// Conversores tolerantes para las respuestas del backend.
///
/// El pool de MySQL devuelve `DECIMAL` como **texto** (`"1500.00"`), los
/// booleanos como `0/1`, las fechas `DATE` como `YYYY-MM-DD` y `TIME` como
/// `HH:MM:SS`. La web se salva porque JavaScript convierte todo al vuelo; en
/// Dart un cast directo revienta, así que todo el parseo pasa por aquí.
library;

double asDouble(Object? v, {double fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

int asInt(Object? v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}

bool asBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return fallback;
}

String asString(Object? v, {String fallback = ''}) => v == null ? fallback : v.toString();

String? asStringOrNull(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

final _reYmd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Fecha "solo día". Acepta `2026-09-23` o un ISO con hora (columnas
/// DATETIME serializadas en UTC); en ese caso usa los componentes locales,
/// como hace `toDateOnly` en la web.
String asFecha(Object? v) => asFechaOrNull(v) ?? '';

String? asFechaOrNull(Object? v) {
  final s = asStringOrNull(v);
  if (s == null) return null;
  if (s.length == 10 && _reYmd.hasMatch(s)) return s;
  final d = DateTime.tryParse(s);
  if (d != null) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
  final m = _reYmd.firstMatch(s);
  return m?.group(0);
}

/// `HH:MM:SS` → `HH:mm`; null si no hay hora.
String? asHora(Object? v) {
  final s = asStringOrNull(v);
  if (s == null) return null;
  final p = s.split(':');
  if (p.length < 2) return null;
  return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
}

List<Map<String, dynamic>> asMapList(Object? v) {
  if (v is! List) return const [];
  return [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)];
}

Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<T> parseList<T>(Object? v, T Function(Map<String, dynamic>) parse) => [for (final m in asMapList(v)) parse(m)];

/// `#34E47E` → 0xFF34E47E (color de las metas).
int colorDesdeHex(Object? v, {int fallback = 0xFF34E47E}) {
  final s = asStringOrNull(v)?.replaceAll('#', '');
  if (s == null || (s.length != 6 && s.length != 8)) return fallback;
  final n = int.tryParse(s, radix: 16);
  if (n == null) return fallback;
  return s.length == 6 ? 0xFF000000 | n : n;
}

String colorAHex(int c) => '#${(c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
