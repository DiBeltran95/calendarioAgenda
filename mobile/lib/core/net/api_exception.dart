import 'package:dio/dio.dart';

/// Error de la API ya traducido a un mensaje que se le puede mostrar al
/// usuario (el backend manda `{ message }` en casi todos sus errores).
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;

  /// Cuerpo completo de la respuesta de error (p. ej. `verification_required`).
  final Map<String, dynamic>? data;

  bool get isUnauthorized => statusCode == 401;

  /// Sin respuesta: sin red, tiempo agotado o servidor caído.
  bool get isNetwork => statusCode == null;

  bool get requiereVerificacion => data?['verification_required'] == true;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final r = error.response;
      if (r != null) {
        final map = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
        var msg = map?['message']?.toString() ?? _porCodigo(r.statusCode);
        // Los 401 de @fastify/jwt vienen en inglés: se traducen.
        if (r.statusCode == 401 && (map?['code']?.toString().startsWith('FST_JWT') ?? false)) {
          msg = 'Tu sesión expiró. Vuelve a iniciar sesión.';
        }
        return ApiException(msg, statusCode: r.statusCode, data: map);
      }
      return ApiException(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'El servidor tardó demasiado en responder. Revisa tu conexión.',
        DioExceptionType.connectionError => 'Sin conexión con el servidor. Revisa tu internet.',
        DioExceptionType.cancel => 'Solicitud cancelada.',
        _ => 'Ocurrió un error de conexión. Inténtalo de nuevo.',
      });
    }
    return const ApiException('Ocurrió un error inesperado. Inténtalo de nuevo.');
  }

  static String _porCodigo(int? c) => switch (c) {
        400 => 'Los datos enviados no son válidos.',
        401 => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        403 => 'No tienes permiso para esta acción.',
        404 => 'No se encontró lo que buscabas.',
        409 => 'Ya existe un registro igual.',
        _ => 'El servidor tuvo un problema. Inténtalo en un momento.',
      };

  @override
  String toString() => message;
}
