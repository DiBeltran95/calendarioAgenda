/// Utilidades de fecha "solo día".
///
/// Toda la app guarda las fechas como texto `YYYY-MM-DD` (igual que el backend
/// original). Así las comparaciones son lexicográficas, no hay desfases de
/// zona horaria y un evento del 5 de marzo es del 5 de marzo en cualquier país.
library;

const mesesLargos = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

const mesesCortos = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Iniciales de la semana empezando en domingo (como el calendario original).
const diasSemanaIniciales = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

const diasSemanaLargos = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

String _dos(int n) => n.toString().padLeft(2, '0');

/// `DateTime` → `YYYY-MM-DD` usando los componentes locales.
String ymd(DateTime d) => '${d.year}-${_dos(d.month)}-${_dos(d.day)}';

/// `YYYY-MM-DD` → medianoche local.
DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Hoy como `YYYY-MM-DD`.
String hoyYmd([DateTime? ahora]) => ymd(ahora ?? DateTime.now());

/// Medianoche local de hoy.
DateTime hoyDate() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String sumarDiasYmd(String fecha, int dias) {
  final d = parseYmd(fecha);
  return ymd(DateTime(d.year, d.month, d.day + dias));
}

/// Diferencia en días (a - b), robusta ante cambios de horario.
int diffDias(String a, String b) {
  final da = parseYmd(a);
  final db = parseYmd(b);
  return DateTime.utc(da.year, da.month, da.day)
      .difference(DateTime.utc(db.year, db.month, db.day))
      .inDays;
}

int diasDelMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

/// Suma meses conservando el día, recortado al último día del mes destino
/// (31 de enero + 1 mes = 28/29 de febrero), como hace el backend.
DateTime sumarMesesRecortado(DateTime base, int meses) {
  final total = base.year * 12 + base.month - 1 + meses;
  final anio = total ~/ 12;
  final mes = total % 12 + 1;
  final dia = base.day.clamp(1, diasDelMes(anio, mes));
  return DateTime(anio, mes, dia);
}

/// Prefijo `YYYY-MM` de un mes (mes 1..12).
String prefijoMes(int anio, int mes) => '$anio-${_dos(mes)}';

/// "5 de marzo de 2026".
String fechaLarga(String fecha) {
  final d = parseYmd(fecha);
  return '${d.day} de ${mesesLargos[d.month - 1].toLowerCase()} de ${d.year}';
}

/// "Jueves, 5 de marzo".
String fechaConDia(String fecha) {
  final d = parseYmd(fecha);
  return '${diasSemanaLargos[d.weekday - 1]}, ${d.day} de ${mesesLargos[d.month - 1].toLowerCase()}';
}

/// "5 mar".
String fechaCorta(String fecha) {
  final d = parseYmd(fecha);
  return '${d.day} ${mesesCortos[d.month - 1].toLowerCase()}';
}

/// "Hoy", "Mañana", "Ayer", "En 3 días", "Hace 2 días".
String fechaRelativa(String fecha, [String? hoy]) {
  final n = diffDias(fecha, hoy ?? hoyYmd());
  if (n == 0) return 'Hoy';
  if (n == 1) return 'Mañana';
  if (n == -1) return 'Ayer';
  if (n > 1) return 'En $n días';
  return 'Hace ${-n} días';
}

/// "14:30" → "2:30 p. m.".
String hora12(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '';
  final p = hhmm.split(':');
  var h = int.parse(p[0]);
  final m = p.length > 1 ? p[1].padLeft(2, '0').substring(0, 2) : '00';
  final sufijo = h >= 12 ? 'p. m.' : 'a. m.';
  h = h % 12;
  if (h == 0) h = 12;
  return '$h:$m $sufijo';
}

/// "Buenos días, Diego" según la hora local.
String saludo(String nombre) {
  final h = DateTime.now().hour;
  final s = h < 12 ? 'Buenos días' : (h < 19 ? 'Buenas tardes' : 'Buenas noches');
  return nombre.isEmpty ? s : '$s, $nombre';
}
