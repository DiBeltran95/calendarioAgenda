/// Convierte una frase en español colombiano en un registro de la app:
/// "almuerzo 25 mil", "me pagaron 2 millones", "cita con Ana mañana 3pm",
/// "cumpleaños de mamá 12 de marzo". No usa red ni servicios externos.
library;

sealed class Interpretacion {
  const Interpretacion();
}

class MovimientoCapturado extends Interpretacion {
  const MovimientoCapturado({required this.ingreso, required this.monto, required this.descripcion, required this.fecha});
  final bool ingreso;
  final double monto;
  final String descripcion;
  final String fecha;
}

class EventoCapturado extends Interpretacion {
  const EventoCapturado({required this.titulo, required this.fecha, this.hora, required this.categoria, this.monto});
  final String titulo;
  final String fecha;

  /// HH:mm, o null si es de todo el día.
  final String? hora;
  final String categoria;
  final double? monto;
}

class CumpleCapturado extends Interpretacion {
  const CumpleCapturado({required this.nombre, required this.fecha});
  final String nombre;
  final String fecha;
}

/// Interpreta [frase] a partir del instante [ahora]. Devuelve null si no hay
/// nada que registrar.
Interpretacion? interpretarFrase(String frase, DateTime ahora) {
  final t = _Texto(frase);
  if (t.vacio) return null;
  final hora = _extraerHora(t);
  final fecha = _extraerFecha(t, ahora);
  final monto = _extraerMonto(t);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);

  // Cumpleaños.
  if (RegExp(r'\bcumple(anos)?\b').hasMatch(t.norm) && fecha != null) {
    final nombre = t.limpio(quitarAlInicio: _inicioEvento)
        .replaceFirst(RegExp(r'^(el\s+)?cumple(años|anos)?(\s+de)?\s*', caseSensitive: false), '')
        .trim();
    if (nombre.isNotEmpty) return CumpleCapturado(nombre: _capital(nombre), fecha: _ymd(fecha.dia(hoy, futuro: true)));
  }

  // Dinero sin hora: es un movimiento.
  if (monto != null && hora == null) {
    final ingreso = _palabrasIngreso.hasMatch(t.norm);
    final desc = ingreso ? t.limpio() : t.limpio(quitarAlInicio: _inicioGasto);
    return MovimientoCapturado(
      ingreso: ingreso,
      monto: monto,
      descripcion: desc.isEmpty ? (ingreso ? 'Ingreso' : 'Gasto') : _capital(desc),
      fecha: _ymd(fecha?.dia(hoy, futuro: false) ?? hoy),
    );
  }

  final titulo = t.limpio(quitarAlInicio: _inicioEvento);
  if (titulo.isEmpty) return null;
  return EventoCapturado(
    titulo: _capital(titulo),
    fecha: _ymd(fecha?.dia(hoy, futuro: true) ?? hoy),
    hora: hora,
    categoria: _categoriaEvento(t.norm),
    monto: monto,
  );
}

final _palabrasIngreso = RegExp(r'\b(me pagaron|me consignaron|me transfirieron|me depositaron|me enviaron|me llego|recibi|cobre|ingreso|salario|sueldo|nomina|vendi)\b');
final _inicioGasto = RegExp(r'^((me\s+)?(gaste|pague|compre|costo|valio|salio)|gasto|pago|compra|en|de|del|por|un|una|el|la|los|las|para|y)\b\s*', caseSensitive: false);
final _inicioEvento = RegExp(r'^(tengo|agendar|agenda|agendame|crear|crea|nuevo|nueva|recuerdame|recordarme|recordar|evento|para|el|la|que)\b\s*', caseSensitive: false);

String _categoriaEvento(String n) {
  for (final (patron, categoria) in const [
    (r'\b(dentista|odontolog\w*|muela)\b', 'dentista'),
    (r'\b(doctor|doctora|medico|medica|eps|examen(es)?)\b', 'doctor'),
    (r'\b(pastilla|medicamento|medicina)s?\b', 'medicamentos'),
    (r'\baceite\b', 'aceite_moto'),
    (r'\b(mecanico|mecanica|taller)\b', 'mecanica'),
    (r'\bmoto\b', 'moto'),
    (r'\b(carro|tecnomecanica)\b', 'carro'),
    (r'\barriendo\b', 'arriendo'),
    (r'\b(servicios|luz|agua|internet)\b', 'servicios'),
    (r'\baniversario\b', 'aniversario'),
    (r'\bmatrimonio\b', 'matrimonio'),
    (r'\bmesiversario\b', 'mesiversario'),
  ]) {
    if (RegExp(patron).hasMatch(n)) return categoria;
  }
  return 'reunion';
}

// ─────────────────────────── Texto ───────────────────────────

/// La frase original y una copia normalizada de la MISMA longitud (minúsculas
/// y sin tildes), para buscar en una y cortar en las dos.
class _Texto {
  _Texto(String frase) : orig = frase.trim().replaceAll(RegExp(r'\s+'), ' '), norm = _normalizar(frase.trim().replaceAll(RegExp(r'\s+'), ' '));

  String orig;
  String norm;

  bool get vacio => orig.isEmpty;

  void quitar(Match m) {
    final hueco = ' ' * (m.end - m.start);
    orig = orig.replaceRange(m.start, m.end, hueco);
    norm = norm.replaceRange(m.start, m.end, hueco);
  }

  /// Lo que queda, sin palabras sueltas al principio o al final.
  String limpio({RegExp? quitarAlInicio}) {
    var s = orig.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceFirst(RegExp(r'\bpesos\b', caseSensitive: false), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (quitarAlInicio != null) {
      for (var i = 0; i < 4; i++) {
        final n = _normalizar(s);
        final m = quitarAlInicio.firstMatch(n);
        if (m == null || m.start != 0) break;
        s = s.substring(m.end).trim();
      }
    }
    final colgantes = RegExp(r'\s+(a las|a la|a|el|la|de|del|en|por|para|con|y|las|los)$', caseSensitive: false);
    while (colgantes.hasMatch(s)) {
      s = s.replaceFirst(colgantes, '').trim();
    }
    return s.replaceAll(RegExp(r'^[,.\-:;\s]+|[,.\-:;\s]+$'), '');
  }
}

String _normalizar(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunaeiouun';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c.toLowerCase());
  }
  return b.toString();
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _dos(int n) => n.toString().padLeft(2, '0');
String _ymd(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

// ─────────────────────────── Hora ───────────────────────────

String? _extraerHora(_Texto t) {
  String armar(int h, int m, String? parte) {
    var hora = h;
    switch (parte) {
      case 'pm' || 'tarde' || 'noche':
        if (h < 12) hora = h + 12;
        if (parte == 'noche' && h == 12) hora = 0;
      case 'am' || 'manana':
        if (h == 12) hora = 0;
      default:
        // Sin indicar: lo habitual es de 8 a. m. a 7 p. m.
        if (h >= 1 && h <= 7) hora = h + 12;
    }
    return '${_dos(hora)}:${_dos(m)}';
  }

  String? parteDe(String? s) {
    if (s == null) return null;
    final x = s.replaceAll(RegExp(r'[.\s]'), '');
    return x == 'am' || x == 'pm' ? x : s;
  }

  // 3pm, 3:30 pm, 3 p. m., a las 3 pm
  var m = RegExp(r'\b(?:a las |a la |las )?(\d{1,2})(?::(\d{2}))?\s*(a\.?\s?m\.?|p\.?\s?m\.?)(?=\s|$|,)').firstMatch(t.norm);
  // 3 de la tarde, a las 10 de la mañana
  m ??= RegExp(r'\b(?:a las |a la |las )?(\d{1,2})(?::(\d{2}))?\s+de la (manana|tarde|noche)\b').firstMatch(t.norm);
  // a las 3, a las 15:30
  m ??= RegExp(r'\b(?:a las |a la )(\d{1,2})(?::(\d{2}))?(?!\d)()').firstMatch(t.norm);
  if (m != null) {
    final h = int.parse(m.group(1)!);
    final min = int.tryParse(m.group(2) ?? '') ?? 0;
    if (h <= 23 && min <= 59) {
      final parte = parteDe(m.groupCount >= 3 && (m.group(3) ?? '').isNotEmpty ? m.group(3) : null);
      final r = h > 12 ? '${_dos(h)}:${_dos(min)}' : armar(h, min, parte);
      t.quitar(m);
      return r;
    }
  }
  final medio = RegExp(r'\b(?:al |a )?medio ?dia\b').firstMatch(t.norm);
  if (medio != null) {
    t.quitar(medio);
    return '12:00';
  }
  return null;
}

// ─────────────────────────── Fecha ───────────────────────────

const _meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const _dias = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

/// Fecha dicha en la frase. Si no trae año, [dia] decide si se refiere a la
/// próxima vez (un evento) o a la más reciente (un gasto ya hecho).
class _Fecha {
  const _Fecha.exacta(DateTime d) : _exacta = d, _mes = null, _dia = null;
  const _Fecha.sinAnio(int mes, int dia) : _exacta = null, _mes = mes, _dia = dia;
  const _Fecha.diaDelMes(int dia) : _exacta = null, _mes = null, _dia = dia;

  final DateTime? _exacta;
  final int? _mes;
  final int? _dia;

  DateTime dia(DateTime hoy, {required bool futuro}) {
    if (_exacta != null) return _exacta;
    if (_mes != null) {
      final d = DateTime(hoy.year, _mes, _dia!);
      if (futuro && d.isBefore(hoy)) return DateTime(hoy.year + 1, _mes, _dia);
      if (!futuro && d.isAfter(hoy)) return DateTime(hoy.year - 1, _mes, _dia);
      return d;
    }
    final d = DateTime(hoy.year, hoy.month, _dia!);
    if (futuro && d.isBefore(hoy)) return DateTime(hoy.year, hoy.month + 1, _dia);
    if (!futuro && d.isAfter(hoy)) return DateTime(hoy.year, hoy.month - 1, _dia);
    return d;
  }
}

_Fecha? _extraerFecha(_Texto t, DateTime ahora) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  _Fecha exacta(Match m, int dias) {
    t.quitar(m);
    return _Fecha.exacta(hoy.add(Duration(days: dias)));
  }

  for (final (patron, dias) in const [
    (r'\bpasado manana\b', 2),
    (r'\b(antes de ayer|anteayer|antier)\b', -2),
    (r'\bmanana\b', 1),
    (r'\bayer\b', -1),
    (r'\bhoy\b', 0),
  ]) {
    final m = RegExp(patron).firstMatch(t.norm);
    if (m != null) return exacta(m, dias);
  }

  final mes = RegExp('\\b(?:el )?(\\d{1,2}) de (${_meses.join('|')})(?: de(?:l)? (\\d{4}))?\\b').firstMatch(t.norm);
  if (mes != null) {
    final d = int.parse(mes.group(1)!);
    final me = _meses.indexOf(mes.group(2)!) + 1;
    final anio = int.tryParse(mes.group(3) ?? '');
    t.quitar(mes);
    return anio != null ? _Fecha.exacta(DateTime(anio, me, d)) : _Fecha.sinAnio(me, d);
  }

  final barra = RegExp(r'\b(?:el )?(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(t.norm);
  if (barra != null) {
    final d = int.parse(barra.group(1)!);
    final me = int.parse(barra.group(2)!);
    var anio = int.tryParse(barra.group(3) ?? '');
    if (anio != null && anio < 100) anio += 2000;
    if (d >= 1 && d <= 31 && me >= 1 && me <= 12) {
      t.quitar(barra);
      return anio != null ? _Fecha.exacta(DateTime(anio, me, d)) : _Fecha.sinAnio(me, d);
    }
  }

  final dia = RegExp('\\b(?:(?:el|este|proximo|el proximo) )?(${_dias.join('|')})\\b').firstMatch(t.norm);
  if (dia != null) {
    final objetivo = _dias.indexOf(dia.group(1)!) + 1;
    final falta = (objetivo - hoy.weekday) % 7;
    return exacta(dia, falta == 0 ? 7 : falta);
  }

  final delMes = RegExp(r'\bel (\d{1,2})(?!\d|[:.,]|\s*(mil|millon|k\b|lucas?|palos?))\b').firstMatch(t.norm);
  if (delMes != null) {
    final d = int.parse(delMes.group(1)!);
    if (d >= 1 && d <= 31) {
      t.quitar(delMes);
      return _Fecha.diaDelMes(d);
    }
  }
  return null;
}

// ─────────────────────────── Dinero ───────────────────────────

double? _extraerMonto(_Texto t) {
  // 2 millones 500 mil
  final compuesto = RegExp(r'\$?\s*(\d+(?:[.,]\d+)?)\s*(?:millon(?:es)?|palos?|barras?)\s*(?:y\s*)?(\d+)\s*(?:mil|lucas?)\b').firstMatch(t.norm);
  if (compuesto != null) {
    final r = _decimal(compuesto.group(1)!) * 1000000 + int.parse(compuesto.group(2)!) * 1000;
    t.quitar(compuesto);
    return r;
  }
  // 25 mil, 2 millones y medio, 1.5 millones, 25k, 30 lucas
  final conEscala = RegExp(r'\$?\s*(\d+(?:[.,]\d+)?)\s*(millon(?:es)?|palos?|barras?|mil|lucas?|k)(\s+y medio)?(?![a-z])').firstMatch(t.norm);
  if (conEscala != null) {
    final millones = !RegExp(r'^(mil$|luca|k)').hasMatch(conEscala.group(2)!);
    final escala = millones ? 1000000 : 1000;
    final r = (_decimal(conEscala.group(1)!) + (conEscala.group(3) != null ? 0.5 : 0)) * escala;
    t.quitar(conEscala);
    return r;
  }
  // $25.000, 25000 pesos, 120000
  final directo = RegExp(r'(\$\s*)?(\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d{1,2})?(\s*pesos)?\b').allMatches(t.norm);
  for (final m in directo) {
    final valor = _digitos(m.group(2)!);
    if (m.group(1) != null || m.group(3) != null || valor >= 100) {
      t.quitar(m);
      return valor.toDouble();
    }
  }
  return _montoEnPalabras(t);
}

double _decimal(String s) => double.parse(s.replaceAll(',', '.'));
int _digitos(String s) => int.parse(s.replaceAll(RegExp(r'[.,]'), ''));

const _numeros = {
  'un': 1, 'una': 1, 'uno': 1, 'dos': 2, 'tres': 3, 'cuatro': 4, 'cinco': 5, 'seis': 6, 'siete': 7, 'ocho': 8, 'nueve': 9,
  'diez': 10, 'once': 11, 'doce': 12, 'trece': 13, 'catorce': 14, 'quince': 15, 'dieciseis': 16, 'diecisiete': 17, 'dieciocho': 18, 'diecinueve': 19,
  'veinte': 20, 'veintiuno': 21, 'veintiun': 21, 'veintidos': 22, 'veintitres': 23, 'veinticuatro': 24, 'veinticinco': 25, 'veintiseis': 26, 'veintisiete': 27, 'veintiocho': 28, 'veintinueve': 29,
  'treinta': 30, 'cuarenta': 40, 'cincuenta': 50, 'sesenta': 60, 'setenta': 70, 'ochenta': 80, 'noventa': 90,
  'cien': 100, 'ciento': 100, 'doscientos': 200, 'trescientos': 300, 'cuatrocientos': 400, 'quinientos': 500, 'seiscientos': 600, 'setecientos': 700, 'ochocientos': 800, 'novecientos': 900,
};

/// "veinticinco mil quinientos", "dos millones", "mil pesos".
double? _montoEnPalabras(_Texto t) {
  final palabras = [..._numeros.keys, 'mil', 'millon', 'millones', 'y'].join('|');
  for (final m in RegExp('\\b(?:(?:$palabras)\\s+)*(?:$palabras)\\b(\\s+pesos)?').allMatches(t.norm)) {
    final tokens = m.group(0)!.split(' ').where((x) => x != 'y' && x != 'pesos' && x.isNotEmpty).toList();
    if (!tokens.any((x) => x == 'mil' || x.startsWith('millon'))) continue;
    var total = 0, actual = 0;
    for (final x in tokens) {
      if (x == 'mil') {
        total += (actual == 0 ? 1 : actual) * 1000;
        actual = 0;
      } else if (x.startsWith('millon')) {
        total = (total + actual) * 1000000;
        actual = 0;
      } else {
        actual += _numeros[x]!;
      }
    }
    t.quitar(m);
    return (total + actual).toDouble();
  }
  return null;
}
