// ==============================================================================
// CEMPPSA Field App - API Client
// Responsabilidad única: comunicación HTTP con el backend
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Cliente HTTP base para la app.
///
/// - Centraliza baseUrl, headers y timeout
/// - No contiene lógica de negocio
/// - Usado por servicios (SyncService, AuthService, etc.)
class ApiClient {
  String _baseUrl;
  final Duration _timeout;
  final Map<String, String> _defaultHeaders;

  ApiClient({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? defaultHeaders,
  })  : _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout,
        _defaultHeaders = {
          'Content-Type': 'application/json',
          ...?defaultHeaders,
        };

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
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
      method: 'GET',
      path: path,
      headers: headers,
      queryParams: queryParams,
    );
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      method: 'POST',
      path: path,
      headers: headers,
      body: body,
    );
  }

  Future<ApiResponse> put(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    return _request(
      method: 'PUT',
      path: path,
      headers: headers,
      body: body,
    );
  }

  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    return _request(
      method: 'DELETE',
      path: path,
      headers: headers,
    );
  }

  // ===========================================================================
  // CORE REQUEST HANDLER
  // ===========================================================================

  Future<ApiResponse> _request({
    required String method,
    required String path,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path, queryParams);
    final mergedHeaders = {..._defaultHeaders, ...?headers};
    final token = ApiConfig.authToken?.trim();
    if (token != null &&
        token.isNotEmpty &&
        !mergedHeaders.containsKey('Authorization')) {
      mergedHeaders['Authorization'] = 'Bearer $token';
    }

    debugPrint('API [$method] $uri');
    if (body != null) {
      final bodyForLog = path.contains('/auth/mobile/login')
          ? {...body, 'password': '***'}
          : body;
      debugPrint('API Body: ${jsonEncode(bodyForLog)}');
    }

    try {
      http.Response response;

      switch (method) {
        case 'GET':
          response =
              await http.get(uri, headers: mergedHeaders).timeout(_timeout);
          break;

        case 'POST':
          response = await http
              .post(
                uri,
                headers: mergedHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;

        case 'PUT':
          response = await http
              .put(
                uri,
                headers: mergedHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;

        case 'DELETE':
          response =
              await http.delete(uri, headers: mergedHeaders).timeout(_timeout);
          break;

        default:
          throw UnsupportedError('HTTP method not supported: $method');
      }

      debugPrint('API Response ${response.statusCode}');
      debugPrint('API Body: ${response.body}');

      return ApiResponse.fromHttp(response);
    } catch (e) {
      debugPrint('API ERROR [$method] $path → $e');
      return ApiResponse.error(e.toString());
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  Uri _buildUri(String path, Map<String, dynamic>? queryParams) {
    final fullPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$_baseUrl$fullPath').replace(
      queryParameters: queryParams?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
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

  factory ApiResponse.fromHttp(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      decoded = response.body;
    }

    return ApiResponse(
      statusCode: response.statusCode,
      data: decoded,
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse(
      statusCode: null,
      data: null,
      error: message,
    );
  }
}
