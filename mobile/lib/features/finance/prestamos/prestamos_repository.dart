import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/api_client.dart';
import '../../../core/net/api_exception.dart';
import '../../../core/net/json.dart';
import '../../../core/session.dart';
import '../../../data/sync.dart';
import '../finance_repository.dart';
import 'prestamos_logica.dart';

class PrestamosNotifier extends AsyncNotifier<List<Prestamo>> with CacheRed<List<Prestamo>> {
  @override
  String get claveCache => 'prestamos';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/finanzas/prestamos');

  @override
  List<Prestamo> parsear(Object? json) => parseList(json, Prestamo.fromJson);

  @override
  Object? serializar(List<Prestamo> v) => [for (final p in v) p.toJson()];

  @override
  Future<List<Prestamo>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final prestamosProvider = AsyncNotifierProvider<PrestamosNotifier, List<Prestamo>>(PrestamosNotifier.new, retry: sinReintento);

/// Lo que le deben, para el patrimonio. Si aún no se pudo cargar cuenta como 0: el
/// resto de Finanzas sigue funcionando.
final porCobrarProvider = Provider<double>((ref) => porCobrarTotal(ref.watch(prestamosProvider).value ?? const []));

class PrestamosRepository {
  PrestamosRepository(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiProvider);

  Future<T> _op<T>(Future<T> Function() f) async {
    try {
      final r = await f();
      await Future.wait([
        _ref.read(prestamosProvider.notifier).refrescar(),
        // Cambian saldos e ingresos: los intereses de cada día son movimientos del mes.
        _ref.read(sincronizadorProvider).despuesDeCambio(),
      ]);
      return r;
    } on ApiException catch (e) {
      // El servidor todavía no tiene esta función: no mostrar el mensaje técnico.
      if (e.statusCode == 404 && e.message.startsWith('Route')) {
        throw const FinanzasError('Los préstamos aún no están activos en el servidor.');
      }
      throw FinanzasError(e.message);
    }
  }

  /// Registra el préstamo con su primer desembolso.
  Future<int> crear({
    required String persona,
    required double monto,
    required String fecha,
    int? cuentaId,
    double tasaMensual = 0,
    String? interesDesde,
    String? vencimiento,
    String nota = '',
  }) {
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() async => asInt(asMap(await _api.post('/api/finanzas/prestamos', body: {
          'persona': persona.trim(),
          'capital': monto,
          'fecha': fecha,
          'cuenta_id': cuentaId,
          'tasa_mensual': tasaMensual,
          'interes_desde': tasaMensual > 0 ? (interesDesde ?? fecha) : null,
          'vencimiento': vencimiento,
          'nota': nota.trim(),
        }))['id']));
  }

  /// Cambiar la tasa o la fecha rehace todos los intereses.
  Future<void> actualizar(int id, {required String persona, double tasaMensual = 0, String? interesDesde, String? vencimiento, String nota = ''}) =>
      _op(() => _api.put('/api/finanzas/prestamos/$id', body: {
            'persona': persona.trim(),
            'tasa_mensual': tasaMensual,
            'interes_desde': tasaMensual > 0 ? interesDesde : null,
            'vencimiento': vencimiento,
            'nota': nota.trim(),
          }));

  /// Borra el préstamo: las cuentas vuelven a como estaban y sus ganancias se van.
  Future<void> eliminar(int id) => _op(() => _api.delete('/api/finanzas/prestamos/$id'));

  Future<void> cerrar(int id, {required String fecha}) => _op(() => _api.post('/api/finanzas/prestamos/$id/cerrar', body: {'cerrado': true, 'fecha': fecha}));

  Future<void> reabrir(int id) => _op(() => _api.post('/api/finanzas/prestamos/$id/cerrar', body: {'cerrado': false}));

  Map<String, dynamic> _cuerpo(String tipo, double capital, double interes, String fecha, int? cuentaId, String nota) => {
        'tipo': tipo,
        'capital': capital,
        'interes': interes,
        'fecha': fecha,
        'cuenta_id': cuentaId,
        'nota': nota.trim(),
      };

  Future<void> agregarMovimiento(int prestamoId, {required String tipo, required double capital, double interes = 0, required String fecha, int? cuentaId, String nota = ''}) =>
      _op(() => _api.post('/api/finanzas/prestamos/$prestamoId/movimientos', body: _cuerpo(tipo, capital, interes, fecha, cuentaId, nota)));

  Future<void> actualizarMovimiento(int id, {required String tipo, required double capital, double interes = 0, required String fecha, int? cuentaId, String nota = ''}) =>
      _op(() => _api.put('/api/finanzas/prestamo-movimientos/$id', body: _cuerpo(tipo, capital, interes, fecha, cuentaId, nota)));

  Future<void> eliminarMovimiento(int id) => _op(() => _api.delete('/api/finanzas/prestamo-movimientos/$id'));
}

final prestamosRepoProvider = Provider(PrestamosRepository.new);
