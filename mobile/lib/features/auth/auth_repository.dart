import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/api_client.dart';
import '../../core/net/api_exception.dart';
import '../../core/net/json.dart';
import '../../core/session.dart';
import '../../data/models.dart';

/// Resultado de intentar entrar: sesión lista o verificación pendiente.
sealed class ResultadoAuth {
  const ResultadoAuth();
}

class AuthOk extends ResultadoAuth {
  const AuthOk(this.sesion);
  final Sesion sesion;
}

/// La cuenta existe pero falta confirmar el código enviado por WhatsApp.
class AuthVerificar extends ResultadoAuth {
  const AuthVerificar({required this.email, this.whatsapp = '', this.mensaje});
  final String email;
  final String whatsapp;
  final String? mensaje;
}

class AuthError implements Exception {
  const AuthError(this.mensaje, {this.deRed = false});
  final String mensaje;
  final bool deRed;
  @override
  String toString() => mensaje;
}

/// Registro, verificación por WhatsApp e inicio de sesión contra el mismo
/// backend de la web (`/api/register`, `/api/register/verify`, `/api/login`).
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<T> _llamar<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiException catch (e) {
      throw AuthError(e.message, deRed: e.isNetwork);
    }
  }

  Sesion _sesion(Object? r) {
    final m = asMap(r);
    final token = asStringOrNull(m['token']);
    if (token == null) throw const AuthError('El servidor no devolvió una sesión válida.');
    return Sesion(token: token, usuario: Usuario.fromJson(asMap(m['user'])));
  }

  Future<ResultadoAuth> iniciarSesion(String email, String password) async {
    try {
      final r = await _api.post('/api/login', body: {'email': email.trim(), 'password': password}, publico: true);
      return AuthOk(_sesion(r));
    } on ApiException catch (e) {
      // 403 + verification_required: el servidor ya reenvió un código.
      if (e.requiereVerificacion) {
        return AuthVerificar(
          email: asStringOrNull(e.data?['email']) ?? email.trim(),
          whatsapp: asString(e.data?['whatsapp']),
          mensaje: e.message,
        );
      }
      throw AuthError(e.message, deRed: e.isNetwork);
    }
  }

  /// Crea la cuenta (o actualiza una sin verificar) y envía el código.
  Future<AuthVerificar> registrar({required String nombre, required String email, required String password, required String whatsapp}) =>
      _llamar(() async {
        final r = asMap(await _api.post('/api/register',
            body: {'nombre': nombre.trim(), 'email': email.trim(), 'password': password, 'whatsapp': whatsapp},
            publico: true));
        return AuthVerificar(email: asStringOrNull(r['email']) ?? email.trim(), whatsapp: whatsapp, mensaje: asStringOrNull(r['message']));
      });

  Future<Sesion> verificar(String email, String codigo) =>
      _llamar(() async => _sesion(await _api.post('/api/register/verify', body: {'email': email, 'code': codigo.trim()}, publico: true)));

  Future<void> reenviarCodigo(String email) => _llamar(() => _api.post('/api/register/resend-code', body: {'email': email}, publico: true));
}

final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(apiProvider)));
