import '../../../core/net/json.dart';
import '../../../data/models.dart';

/// Pago detectado automáticamente (Apple Pay vía Atajos o aviso de un banco
/// en Android) que espera su categoría para quedar registrado en Finanzas.
class CapturaPago {
  const CapturaPago({
    required this.id,
    required this.origen,
    required this.tipo,
    required this.monto,
    required this.comercio,
    required this.tarjeta,
    required this.app,
    required this.fecha,
    this.texto = '',
  });

  final int id;

  /// 'apple_pay', 'android' o 'manual'.
  final String origen;

  /// 'gasto' o 'ingreso'.
  final String tipo;
  final double monto;
  final String comercio;
  final String tarjeta;

  /// Banco o app de donde salió (Android), p. ej. "Bancolombia" o "SMS".
  final String app;

  /// Cuándo ocurrió (UTC).
  final DateTime fecha;
  final String texto;

  /// Nombre para mostrar y para la descripción del movimiento.
  String get titulo => comercio.isNotEmpty ? comercio : (origen == 'apple_pay' ? 'Pago con Apple Pay' : 'Pago en $app');

  factory CapturaPago.fromJson(Map<String, dynamic> j) => CapturaPago(
        id: asInt(j['id']),
        origen: asString(j['origen'], fallback: 'android'),
        tipo: asString(j['tipo'], fallback: 'gasto'),
        monto: asDouble(j['monto']),
        comercio: asString(j['comercio']),
        tarjeta: asString(j['tarjeta']),
        app: asString(j['app']),
        fecha: DateTime.tryParse(asString(j['fecha']))?.toUtc() ?? DateTime.now().toUtc(),
        texto: asString(j['texto']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'origen': origen,
        'tipo': tipo,
        'monto': monto,
        'comercio': comercio,
        'tarjeta': tarjeta,
        'app': app,
        'fecha': fecha.toIso8601String(),
        'texto': texto,
      };
}

/// Categoría y cuenta que el usuario eligió antes para un comercio o tarjeta.
class PreferenciaPago {
  const PreferenciaPago({required this.comercio, required this.tarjeta, required this.categoria, this.cuentaId});
  final String comercio;
  final String tarjeta;
  final String categoria;
  final int? cuentaId;

  factory PreferenciaPago.fromJson(Map<String, dynamic> j) => PreferenciaPago(
        comercio: asString(j['comercio']),
        tarjeta: asString(j['tarjeta']),
        categoria: asString(j['categoria'], fallback: 'otros'),
        cuentaId: asIntOrNull(j['cuenta_id']),
      );
}

// ─────────────────────── Montos ───────────────────────

/// "$25.000", "$ 25.000,50", "COP 1.250.000", "25,000.00" → número
/// (igual que `montoDesdeTexto` del backend).
double? montoDesdeTexto(String v) {
  var s = v.replaceAll(RegExp(r'[^\d.,]'), '');
  if (s.isEmpty) return null;
  final sep = s.lastIndexOf('.') > s.lastIndexOf(',') ? s.lastIndexOf('.') : s.lastIndexOf(',');
  final decimales = sep >= 0 ? s.length - sep - 1 : 0;
  if (sep >= 0 && decimales > 0 && decimales <= 2) {
    s = '${s.substring(0, sep).replaceAll(RegExp(r'[.,]'), '')}.${s.substring(sep + 1)}';
  } else {
    s = s.replaceAll(RegExp(r'[.,]'), '');
  }
  final n = double.tryParse(s);
  return n != null && n > 0 ? n : null;
}

// ─────────────────────── Avisos de bancos (Android) ───────────────────────

/// Pago interpretado a partir de una notificación, listo para subir.
class AvisoInterpretado {
  const AvisoInterpretado({required this.tipo, required this.monto, required this.comercio, required this.tarjeta, required this.app, required this.texto, required this.fecha});
  final String tipo;
  final double monto;
  final String comercio;
  final String tarjeta;
  final String app;
  final String texto;
  final DateTime fecha;

  Map<String, dynamic> toBody() => {
        'origen': 'android',
        'tipo': tipo,
        'monto': monto,
        'comercio': comercio,
        'tarjeta': tarjeta,
        'app': app,
        'texto': texto,
        'fecha': fecha.toUtc().toIso8601String(),
      };
}

final _monto = RegExp(r'(?:\$|COP|USD)\s?(\d[\d.,]*)', caseSensitive: false);
final _descartar = RegExp(r'c[oó]digo|clave din[aá]mica|\botp\b|token|rechaz|declinad|no exitos|fallid|no fue posible|intento', caseSensitive: false);
final _ingreso = RegExp(r'recibiste|te envi[oó]|te enviaron|te transfiri|abono|consignaci[oó]n a tu|reembolso|devoluci[oó]n|recibi[oó]', caseSensitive: false);
final _tarjeta = RegExp(r'(?:\*|•+\s?|x{2,}|terminad[ao] en\s?|T\.?\s?(?:Cred|Deb)\w*\.?\s?\*?)(\d{4})\b', caseSensitive: false);

/// Palabra que corta el nombre del comercio ("…en ÉXITO el 20/10", "…en D1 con tu tarjeta").
const _cortes = r'(?=\s+(?:el|la|con|desde|a\s+las|por|fecha|hora|T\.?\s?Cred|T\.?\s?Deb|tarjeta|cuenta|valor|de\s+tu|de\s+su|\d{1,2}[/:-])\b|\s+\d{1,2}[/:-]|[.,;:]\s|[.,;]$|$)';
final _comercioEn = RegExp(r'\b(?:en|a)\s+([^\s$].{1,50}?)' + _cortes, caseSensitive: false);
final _remitente = RegExp(r'\bde\s+([^\s$].{1,50}?)' + _cortes, caseSensitive: false);

/// Interpreta el aviso de compra de un banco, Google Wallet o un SMS.
/// Devuelve null si no es un pago (códigos, rechazos, publicidad…).
AvisoInterpretado? interpretarAviso({required String app, required String paquete, required String titulo, required String texto, required DateTime fecha}) {
  final todo = '$titulo. $texto'.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (_descartar.hasMatch(todo)) return null;
  final m = _monto.firstMatch(todo);
  if (m == null) return null;
  final monto = montoDesdeTexto(m.group(1)!);
  if (monto == null) return null;
  final ingreso = _ingreso.hasMatch(todo);

  // El comercio suele ir después del monto: "Compra por $25.000 en EXITO".
  final despues = todo.substring(m.end);
  var comercio = '';
  if (ingreso) {
    comercio = _remitente.firstMatch(despues)?.group(1) ?? _remitente.firstMatch(todo)?.group(1) ?? '';
  } else {
    comercio = _comercioEn.firstMatch(despues)?.group(1) ?? _comercioEn.firstMatch(todo)?.group(1) ?? '';
  }
  // Google Wallet: el título es el comercio y el texto "$25.000 con Visa ••1234".
  if (comercio.isEmpty && paquete == 'com.google.android.apps.walletnfcrel' && !titulo.contains(r'$')) comercio = titulo;
  comercio = _limpiarComercio(comercio);

  final t = _tarjeta.firstMatch(todo)?.group(1);
  return AvisoInterpretado(
    tipo: ingreso ? 'ingreso' : 'gasto',
    monto: monto,
    comercio: comercio,
    tarjeta: t == null ? '' : '•• $t',
    app: app,
    texto: todo.length > 500 ? todo.substring(0, 500) : todo,
    fecha: fecha,
  );
}

String _limpiarComercio(String s) {
  var c = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  c = c.replaceAll(RegExp(r'^(el|la|los|las|comercio|establecimiento)\s+', caseSensitive: false), '');
  if (c.isEmpty) return '';
  // "EXITO CALLE 80" → "Exito Calle 80" (los bancos escriben todo en mayúsculas).
  if (c == c.toUpperCase()) {
    c = c.split(' ').map((w) => w.length <= 2 && RegExp(r'\d').hasMatch(w) ? w : (w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())).join(' ');
  }
  return c.length > 60 ? c.substring(0, 60) : c;
}

// ─────────────────────── Sugerencias ───────────────────────

/// Clave para comparar comercios: sin tildes, números ni sucursal.
String claveComercio(String s) {
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  var t = s.toLowerCase();
  for (var i = 0; i < de.length; i++) {
    t = t.replaceAll(de[i], a[i]);
  }
  final palabras = t.replaceAll(RegExp(r'[^a-z ]'), ' ').split(' ').where((w) => w.length > 1).take(2);
  return palabras.join(' ');
}

const _palabras = <String, List<String>>{
  'comida': [
    'almuerzo', 'desayuno', 'cena', 'comida', 'mercado', 'restaurante', 'tinto', 'cafe', 'domicilio',
    'exito', 'carulla', 'olimpica', 'jumbo', 'ara', 'd1', 'isimo', 'surtimax', 'makro', 'pricesmart', 'oxxo', 'rappi', 'restaurante', 'panader', 'cafe', 'juan valdez',
    'tostao', 'frisby', 'kfc', 'mcdonald', 'burger', 'domino', 'pizza', 'crepes', 'el corral', 'subway', 'starbucks', 'mercado', 'supermercado', 'fruver', 'carniceria', 'ifood',
  ],
  'salud': ['farmacia', 'drogueria', 'medico', 'doctor', 'dentista', 'cita medica', 'eps'],
  'entretenimiento': ['cine', 'concierto', 'fiesta', 'rumba'],
  'educacion': ['universidad', 'colegio', 'matricula', 'curso'],
  'arriendo': ['arriendo', 'alquiler'],
  'transporte': ['taxi', 'bus', 'transmilenio', 'parqueadero', 'peaje', 'gasolina', 'uber', 'didi', 'cabify', 'indriver', 'terpel', 'primax', 'texaco', 'biomax', 'esso', 'mobil', 'gasolin', 'combustible', 'estacion de servicio', 'peaje', 'parqueadero', 'transmilenio', 'tullave', 'civica', 'taxi'],
  'servicios': [
    'luz', 'agua', 'gas', 'celular', 'plan de datos',
    'netflix', 'spotify', 'disney', 'hbo', 'prime video', 'amazon prime', 'youtube', 'apple.com', 'icloud', 'google', 'claro', 'movistar', 'tigo', 'wom', 'etb', 'epm',
    'codensa', 'enel', 'vanti', 'gas natural', 'acueducto', 'internet', 'chatgpt', 'openai',
  ],
};

/// Categoría sugerida para un pago: primero lo que el usuario eligió antes
/// para ese comercio; si no, por palabras clave; si no, "otros".
String sugerirCategoria(CapturaPago c, List<PreferenciaPago> prefs, List<CategoriaFinanzas> categorias) {
  final validas = {for (final x in categorias) x.valor};
  bool existe(String v) => validas.isEmpty || validas.contains(v);
  final clave = claveComercio(c.comercio);
  if (clave.isNotEmpty) {
    for (final p in prefs) {
      if (claveComercio(p.comercio) == clave && existe(p.categoria)) return p.categoria;
    }
  }
  if (c.tipo == 'gasto') {
    final t = c.comercio.toLowerCase();
    for (final e in _palabras.entries) {
      if (existe(e.key) && e.value.any((w) => RegExp('(^|[^a-z0-9])${RegExp.escape(w)}(\$|[^a-z0-9])').hasMatch(t))) return e.key;
    }
  }
  return existe('otros') ? 'otros' : (categorias.isEmpty ? 'otros' : categorias.first.valor);
}

/// Cuenta sugerida: la usada antes con esa tarjeta, o con ese comercio.
int? sugerirCuenta(CapturaPago c, List<PreferenciaPago> prefs, List<Cuenta> cuentas) {
  final ids = {for (final x in cuentas) x.id};
  if (c.tarjeta.isNotEmpty) {
    for (final p in prefs) {
      if (p.cuentaId != null && ids.contains(p.cuentaId) && p.tarjeta.toLowerCase() == c.tarjeta.toLowerCase()) return p.cuentaId;
    }
  }
  final clave = claveComercio(c.comercio);
  for (final p in prefs) {
    if (p.cuentaId != null && ids.contains(p.cuentaId) && clave.isNotEmpty && claveComercio(p.comercio) == clave) return p.cuentaId;
  }
  return null;
}
