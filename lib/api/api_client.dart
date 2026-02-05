// ==============================================================================
// CEMPPSA Field App - API Client
// Responsabilidad única: comunicación HTTP con el backend (usando Dio)
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/storage/secure_storage_service.dart';
import 'auth_interceptor.dart';

/// Cliente HTTP base para la app.
/// 
/// - Centraliza baseUrl, headers y timeout
/// - Maneja Auth (Bearer Token + Refresh)
/// - Usa Dio en lugar de http
class ApiClient {
  late final Dio _dio;
  late final AuthInterceptor _authInterceptor;

  ApiClient({
    required String baseUrl,
    required SecureStorageService storage,
    Duration timeout = ApiConfig.connectionTimeout,
    Map<String, String>? defaultHeaders,
  }) {
    final validBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    _dio = Dio(BaseOptions(
      baseUrl: validBaseUrl,
      connectTimeout: timeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        ...?defaultHeaders,
      },
    ));

    _authInterceptor = AuthInterceptor(storage: storage, dio: _dio);
    _dio.interceptors.add(_authInterceptor);

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }
  }

  /// Establece el Access Token en el interceptor
  void setAccessToken(String? token) {
    _authInterceptor.setAccessToken(token);
  }

  // ===========================================================================
  // HTTP METHODS
  // ===========================================================================

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
  }) async {
    return _request(
      () => _dio.get(
        path,
        queryParameters: queryParams,
        options: Options(headers: headers),
      ),
    );
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      () => _dio.post(
        path,
        data: body,
        options: Options(headers: headers),
      ),
    );
  }

  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      () => _dio.put(
        path,
        data: body,
        options: Options(headers: headers),
      ),
    );
  }

  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _request(
      () => _dio.delete(
        path,
        options: Options(headers: headers),
      ),
    );
  }

  // ===========================================================================
  // CORE REQUEST HANDLER
  // ===========================================================================

  Future<ApiResponse> _request(Future<Response> Function() request) async {
    try {
      final response = await request();
      return ApiResponse.fromDio(response);
    } on DioException catch (e) {
      // Si el error fue resuelto por el interceptor (ej: retry exitoso) devuelve response
      if (e.response != null) {
        return ApiResponse.fromDio(e.response!);
      }
      return ApiResponse.error(
        e.message ?? 'Error de conexión',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }
}

// ==============================================================================
// API RESPONSE
// ==============================================================================

class ApiResponse {
  final int? statusCode;
  final dynamic data;
  final String? error;

  ApiResponse({
    this.statusCode,
    this.data,
    this.error,
  });

  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  factory ApiResponse.fromDio(Response response) {
    return ApiResponse(
      statusCode: response.statusCode,
      data: response.data,
    );
  }

  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse(
      statusCode: statusCode,
      data: null,
      error: message,
    );
  }
}
