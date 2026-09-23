import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/models.dart';
import 'net/api_client.dart';
import 'providers.dart';

/// Sesión iniciada: el JWT del backend y el usuario al que pertenece.
class Sesion {
  const Sesion({required this.token, required this.usuario});
  final String token;
  final Usuario usuario;
}

/// Dónde se guarda la sesión. En el teléfono va cifrada (Keychain en iOS,
/// Keystore en Android); en pruebas se usa una versión en memoria.
abstract class TokenStore {
  Future<Sesion?> leer();
  Future<void> guardar(Sesion s);
  Future<void> borrar();
}

class SecureTokenStore implements TokenStore {
  static const _kToken = 'jwt';
  static const _kUsuario = 'usuario';
  final _s = const FlutterSecureStorage();

  @override
  Future<Sesion?> leer() async {
    try {
      final t = await _s.read(key: _kToken);
      final u = await _s.read(key: _kUsuario);
      if (t == null || t.isEmpty || u == null) return null;
      return Sesion(token: t, usuario: Usuario.fromJson(jsonDecode(u) as Map<String, dynamic>));
    } catch (_) {
      // Si el almacén cifrado falla (p. ej. tras restaurar una copia en otro
      // equipo) es preferible pedir login que dejar la app sin arrancar.
      return null;
    }
  }

  @override
  Future<void> guardar(Sesion s) async {
    await _s.write(key: _kToken, value: s.token);
    await _s.write(key: _kUsuario, value: jsonEncode(s.usuario.toJson()));
  }

  @override
  Future<void> borrar() async {
    try {
      await _s.delete(key: _kToken);
      await _s.delete(key: _kUsuario);
    } catch (_) {}
  }
}

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._s]);
  Sesion? _s;
  @override
  Future<Sesion?> leer() async => _s;
  @override
  Future<void> guardar(Sesion s) async => _s = s;
  @override
  Future<void> borrar() async => _s = null;
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Motivo del último cierre de sesión (para explicarlo en el login).
class AvisoSesion extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

final avisoSesionProvider = NotifierProvider<AvisoSesion, String?>(AvisoSesion.new);

class SesionNotifier extends AsyncNotifier<Sesion?> {
  @override
  Future<Sesion?> build() => ref.read(tokenStoreProvider).leer();

  Future<void> iniciar(Sesion s) async {
    await ref.read(tokenStoreProvider).guardar(s);
    ref.read(avisoSesionProvider.notifier).set(null);
    state = AsyncData(s);
  }

  /// Cierra la sesión y borra los datos en caché del dispositivo.
  Future<void> cerrar({String? motivo}) async {
    if (state.value == null) return;
    await ref.read(tokenStoreProvider).borrar();
    await ref.read(databaseProvider).limpiarCache();
    ref.read(avisoSesionProvider.notifier).set(motivo);
    state = const AsyncData(null);
  }
}

final sesionProvider = AsyncNotifierProvider<SesionNotifier, Sesion?>(SesionNotifier.new);

/// Id del usuario activo (0 sin sesión). Prefijo de las claves de caché.
final usuarioIdProvider = Provider<int>((ref) => ref.watch(sesionProvider).value?.usuario.id ?? 0);

/// Cliente del backend. Adjunta el JWT y, ante un 401, cierra la sesión.
final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    token: () async => ref.read(sesionProvider).value?.token,
    onUnauthorized: () => ref.read(sesionProvider.notifier).cerrar(motivo: 'Tu sesión expiró. Vuelve a iniciar sesión.'),
  );
});
