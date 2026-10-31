import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/api_client.dart';
import '../../../core/net/api_exception.dart';
import '../../../core/net/json.dart';
import '../../../core/session.dart';
import '../../../data/sync.dart';
import '../finance_repository.dart';
import 'inversiones_logica.dart';

/// Pantalla de inversiones y patrimonio.
const rutaInversiones = '/finanzas/inversiones';

class InversionesNotifier extends AsyncNotifier<List<Inversion>> with CacheRed<List<Inversion>> {
  @override
  String get claveCache => 'inversiones';

  @override
  Future<Object?> pedir() => ref.read(apiProvider).get('/api/finanzas/inversiones');

  @override
  List<Inversion> parsear(Object? json) => parseList(json, Inversion.fromJson);

  @override
  Object? serializar(List<Inversion> v) => [for (final i in v) i.toJson()];

  @override
  Future<List<Inversion>> build() {
    ref.watch(usuarioIdProvider);
    return cargar();
  }
}

final inversionesProvider = AsyncNotifierProvider<InversionesNotifier, List<Inversion>>(InversionesNotifier.new, retry: sinReintento);

/// Valor de todas las inversiones para el patrimonio. Si aún no se pudieron
/// cargar cuenta como 0: el resto de Finanzas sigue funcionando.
final valorInversionesProvider = Provider<double>((ref) => valorTotalInversiones(ref.watch(inversionesProvider).value ?? const []));

class InversionesRepository {
  InversionesRepository(this._ref);
  final Ref _ref;

  ApiClient get _api => _ref.read(apiProvider);

  Future<T> _op<T>(Future<T> Function() f) async {
    try {
      final r = await f();
      await Future.wait([
        _ref.read(inversionesProvider.notifier).refrescar(),
        // Los saldos de las cuentas también pudieron cambiar.
        _ref.read(sincronizadorProvider).despuesDeCambio(meses: false),
      ]);
      return r;
    } on ApiException catch (e) {
      throw FinanzasError(e.message);
    }
  }

  /// Registra la inversión con su primer aporte.
  Future<int> crear({required String nombre, required String tipo, required double monto, double? montoUsd, required String fecha, int? cuentaId, String nota = ''}) {
    if (monto <= 0) throw const FinanzasError('El monto debe ser mayor a 0');
    return _op(() async => asInt(asMap(await _api.post('/api/finanzas/inversiones', body: {
          'nombre': nombre.trim(),
          'tipo': tipo,
          'monto': monto,
          'monto_usd': montoUsd,
          'fecha': fecha,
          'cuenta_id': cuentaId,
          'nota': nota.trim(),
        }))['id']));
  }

  Future<void> actualizar(int id, {required String nombre, required String tipo, String nota = ''}) =>
      _op(() => _api.put('/api/finanzas/inversiones/$id', body: {'nombre': nombre.trim(), 'tipo': tipo, 'nota': nota.trim()}));

  /// Borra la inversión y deshace lo que movió en las cuentas.
  Future<void> eliminar(int id) => _op(() => _api.delete('/api/finanzas/inversiones/$id'));

  Map<String, dynamic> _cuerpo(TipoMovimiento tipo, double monto, double? montoUsd, String fecha, int? cuentaId, String nota) => {
        'tipo': tipo.valor,
        'monto': monto,
        'monto_usd': montoUsd,
        'fecha': fecha,
        'cuenta_id': cuentaId,
        'nota': nota.trim(),
      };

  Future<void> agregarMovimiento(int inversionId, {required TipoMovimiento tipo, required double monto, double? montoUsd, required String fecha, int? cuentaId, String nota = ''}) =>
      _op(() => _api.post('/api/finanzas/inversiones/$inversionId/movimientos', body: _cuerpo(tipo, monto, montoUsd, fecha, cuentaId, nota)));

  Future<void> actualizarMovimiento(int id, {required TipoMovimiento tipo, required double monto, double? montoUsd, required String fecha, int? cuentaId, String nota = ''}) =>
      _op(() => _api.put('/api/finanzas/inversion-movimientos/$id', body: _cuerpo(tipo, monto, montoUsd, fecha, cuentaId, nota)));

  Future<void> eliminarMovimiento(int id) => _op(() => _api.delete('/api/finanzas/inversion-movimientos/$id'));
}

final inversionesRepoProvider = Provider(InversionesRepository.new);
