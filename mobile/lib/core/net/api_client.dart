import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Cliente HTTP del backend Fastify existente (el mismo que usa la web):
/// rutas `/api/...` con el JWT en `Authorization: Bearer`. No requiere ningún
/// cambio en el servidor.
class ApiClient {
  ApiClient({
    required this._token,
    required this._onUnauthorized,
    String baseUrl = defaultBaseUrl,
    HttpClientAdapter? adapter,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
          // Sin contentType fijo: Dio lo deduce (JSON) solo cuando hay cuerpo.
          // Un DELETE con "application/json" y cuerpo vacío lo rechaza Fastify
          // (FST_ERR_CTP_EMPTY_JSON_BODY); la web tampoco lo envía.
          responseType: ResponseType.json,
        )) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['publico'] != true) {
          final t = await _token();
          if (t != null && t.isNotEmpty) options.headers['Authorization'] = 'Bearer $t';
        }
        handler.next(options);
      },
    ));
  }

  /// Backend de producción (el mismo de `frontend/.env.production`).
  static const defaultBaseUrl = 'https://dibeltran05.alwaysdata.net';

  /// Enlace público de confirmación de pagos (lo abre quien recibe el WhatsApp).
  static const confirmacionBaseUrl = 'https://agendaservi.com/confirmar';

  final Dio dio;
  final Future<String?> Function() _token;
  final void Function() _onUnauthorized;

  static final _publico = Options(extra: {'publico': true});

  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool publico = false}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: query, options: publico ? _publico : null), publico: publico);

  Future<dynamic> post(String path, {Object? body, bool publico = false}) => _send(
      () => dio.post<dynamic>(path, data: body ?? const <String, dynamic>{}, options: publico ? _publico : null),
      publico: publico);

  Future<dynamic> put(String path, {Object? body, Map<String, dynamic>? query}) =>
      _send(() => dio.put<dynamic>(path, data: body ?? const <String, dynamic>{}, queryParameters: query));

  Future<dynamic> delete(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.delete<dynamic>(path, queryParameters: query));

  Future<dynamic> _send(Future<Response<dynamic>> Function() req, {bool publico = false}) async {
    try {
      final r = await req();
      return r.data;
    } catch (e) {
      final ex = ApiException.from(e);
      // Un 401 en una ruta pública (login con clave errada) no es una sesión
      // vencida: solo en rutas autenticadas se cierra la sesión.
      if (ex.isUnauthorized && !publico) _onUnauthorized();
      throw ex;
    }
  }
}
