import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/storage/secure_storage_service.dart';

class AuthInterceptor extends QueuedInterceptor {
  final SecureStorageService _storage;
  final Dio _dio;
  String? _accessToken;

  AuthInterceptor({
    required SecureStorageService storage,
    required Dio dio,
  })  : _storage = storage,
        _dio = dio;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_accessToken != null) {
      options.headers['Authorization'] = 'Bearer $_accessToken';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && _accessToken != null) {
      // Evitar loop si el refresh falla
      if (err.requestOptions.path.contains(ApiConfig.refreshEndpoint)) {
        return handler.next(err);
      }

      debugPrint('AuthInterceptor: 401 detectado. Intentando refresh...');

      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null) {
          debugPrint('AuthInterceptor: No hay refresh token.');
          return handler.next(err);
        }

        // Usar una instancia limpia de Dio para el refresh
        final refreshDio = Dio(BaseOptions(
          baseUrl: _dio.options.baseUrl,
          headers: {'Content-Type': 'application/json'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

        // Llamada al endpoint de refresh
        // Asumimos que el backend espera { "refresh_token": "..." }
        // y devuelve { "access_token": "...", "refresh_token": "..."? }
        final response = await refreshDio.post(
          ApiConfig.refreshEndpoint,
          data: {'refresh_token': refreshToken},
        );

        if (response.statusCode == 200) {
          final newAccess = response.data['access_token'];
          final newRefresh = response.data['refresh_token'];

          if (newAccess != null) {
            _accessToken = newAccess;
            debugPrint('AuthInterceptor: Access Token renovado.');

            if (newRefresh != null) {
              await _storage.saveRefreshToken(newRefresh);
              debugPrint('AuthInterceptor: Refresh Token rotado.');
            }

            // Reintentar la request original
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $newAccess';

            final clonedRequest = await _dio.request(
              opts.path,
              options: Options(
                method: opts.method,
                headers: opts.headers,
                contentType: opts.contentType,
                responseType: opts.responseType,
                followRedirects: opts.followRedirects,
                validateStatus: opts.validateStatus,
                receiveTimeout: opts.receiveTimeout,
                sendTimeout: opts.sendTimeout,
                extra: opts.extra,
              ),
              data: opts.data,
              queryParameters: opts.queryParameters,
            );

            return handler.resolve(clonedRequest);
          }
        }
      } catch (e) {
        debugPrint('AuthInterceptor: Error al refrescar token -> $e');
        // Si falla el refresh, borramos el token guardado para forzar login
        await _storage.deleteRefreshToken();
      }
    }
    handler.next(err);
  }
}
