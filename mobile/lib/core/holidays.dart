import 'dates.dart';

/// Festivo nacional de Colombia.
class Festivo {
  const Festivo(this.fecha, this.nombre, {this.trasladado = false});
  final String fecha;
  final String nombre;

  /// true si se movió al lunes siguiente por la Ley Emiliani (Ley 51 de 1983).
  final bool trasladado;
}

/// Día especial (no festivo): Día de la Madre, Amor y Amistad, etc.
class DiaEspecial {
  const DiaEspecial(this.fecha, this.nombre, this.categoria, this.descripcion);
  final String fecha;
  final String nombre;
  final String categoria;
  final String descripcion;
}

/// Domingo de Pascua (algoritmo de Meeus/Jones/Butcher, calendario gregoriano).
DateTime domingoDePascua(int anio) {
  final a = anio % 19;
  final b = anio ~/ 100;
  final c = anio % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final mes = (h + l - 7 * m + 114) ~/ 31;
  final dia = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(anio, mes, dia);
}

DateTime _siguienteLunes(DateTime d) {
  final faltan = (DateTime.monday - d.weekday + 7) % 7;
  return DateTime(d.year, d.month, d.day + faltan);
}

final Map<int, List<Festivo>> _cacheFestivos = {};
final Map<int, List<DiaEspecial>> _cacheEspeciales = {};

/// Festivos de Colombia para un año, calculados en el dispositivo.
///
/// La versión web los pedía a date.nager.at; aquí se calculan localmente con
/// las mismas reglas, así el calendario funciona sin conexión y al instante.
List<Festivo> festivosColombia(int anio) {
  return _cacheFestivos.putIfAbsent(anio, () {
    final lista = <Festivo>[];
    void fijo(int mes, int dia, String nombre) =>
        lista.add(Festivo(ymd(DateTime(anio, mes, dia)), nombre));
    void emiliani(DateTime original, String nombre) {
      final lunes = _siguienteLunes(original);
      lista.add(Festivo(ymd(lunes), nombre, trasladado: lunes != original));
    }

    // Fijos (no se trasladan).
    fijo(1, 1, 'Año Nuevo');
    fijo(5, 1, 'Día del Trabajo');
    fijo(7, 20, 'Día de la Independencia');
    fijo(8, 7, 'Batalla de Boyacá');
    fijo(12, 8, 'Inmaculada Concepción');
    fijo(12, 25, 'Navidad');

    // Trasladables al lunes siguiente (Ley Emiliani).
    emiliani(DateTime(anio, 1, 6), 'Día de los Reyes Magos');
    emiliani(DateTime(anio, 3, 19), 'Día de San José');
    emiliani(DateTime(anio, 6, 29), 'San Pedro y San Pablo');
    emiliani(DateTime(anio, 8, 15), 'Asunción de la Virgen');
    emiliani(DateTime(anio, 10, 12), 'Día de la Raza');
    emiliani(DateTime(anio, 11, 1), 'Todos los Santos');
    emiliani(DateTime(anio, 11, 11), 'Independencia de Cartagena');

    // Dependientes de la Pascua.
    final pascua = domingoDePascua(anio);
    DateTime desdePascua(int dias) => DateTime(pascua.year, pascua.month, pascua.day + dias);
    lista.add(Festivo(ymd(desdePascua(-3)), 'Jueves Santo'));
    lista.add(Festivo(ymd(desdePascua(-2)), 'Viernes Santo'));
    emiliani(desdePascua(39), 'Ascensión del Señor');
    emiliani(desdePascua(60), 'Corpus Christi');
    emiliani(desdePascua(68), 'Sagrado Corazón de Jesús');

    lista.sort((a, b) => a.fecha.compareTo(b.fecha));
    return List.unmodifiable(lista);
  });
}

/// n-ésimo [weekday] (1=lunes … 7=domingo) de un mes; n = -1 → el último.
DateTime _nEsimoDiaSemana(int anio, int mes, int weekday, int n) {
  if (n == -1) {
    var d = DateTime(anio, mes + 1, 0);
    while (d.weekday != weekday) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return d;
  }
  var d = DateTime(anio, mes, 1);
  while (d.weekday != weekday) {
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return DateTime(d.year, d.month, d.day + 7 * (n - 1));
}

/// Días especiales de Colombia (celebraciones comerciales y culturales).
List<DiaEspecial> diasEspeciales(int anio) {
  return _cacheEspeciales.putIfAbsent(anio, () {
    String f(int m, int d) => ymd(DateTime(anio, m, d));
    final lista = [
      DiaEspecial(f(2, 14), 'San Valentín', 'Celebración', 'Día de los enamorados a nivel internacional.'),
      DiaEspecial(f(3, 8), 'Día de la Mujer', 'Conmemoración', 'Día Internacional de la Mujer.'),
      DiaEspecial(f(4, 26), 'Día de la Secretaria', 'Profesional', 'Reconocimiento al personal administrativo.'),
      DiaEspecial(ymd(_nEsimoDiaSemana(anio, 4, DateTime.saturday, -1)), 'Día del Niño', 'Familia', 'Último sábado de abril.'),
      DiaEspecial(ymd(_nEsimoDiaSemana(anio, 5, DateTime.sunday, 2)), 'Día de la Madre', 'Familia', 'Segundo domingo de mayo.'),
      DiaEspecial(f(5, 15), 'Día del Maestro', 'Profesional', 'Reconocimiento a los docentes.'),
      DiaEspecial(ymd(_nEsimoDiaSemana(anio, 6, DateTime.sunday, 3)), 'Día del Padre', 'Familia', 'Tercer domingo de junio.'),
      DiaEspecial(ymd(_nEsimoDiaSemana(anio, 9, DateTime.saturday, 3)), 'Amor y Amistad', 'Celebración', 'Tercer sábado de septiembre.'),
      DiaEspecial(f(10, 31), 'Halloween', 'Celebración', 'Día de los niños y los disfraces.'),
      DiaEspecial(f(12, 7), 'Día de las Velitas', 'Tradición', 'Noche de velitas en honor a la Inmaculada Concepción.'),
      DiaEspecial(f(12, 24), 'Nochebuena', 'Tradición', 'Víspera de Navidad.'),
      DiaEspecial(f(12, 31), 'Fin de Año', 'Tradición', 'Última noche del año.'),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return List.unmodifiable(lista);
  });
}

Festivo? festivoEn(String fecha) {
  final anio = int.parse(fecha.substring(0, 4));
  for (final f in festivosColombia(anio)) {
    if (f.fecha == fecha) return f;
  }
  return null;
}

DiaEspecial? diaEspecialEn(String fecha) {
  final anio = int.parse(fecha.substring(0, 4));
  for (final d in diasEspeciales(anio)) {
    if (d.fecha == fecha) return d;
  }
  return null;
}
