import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../data/models/auth_session.dart';

class AuthService extends ChangeNotifier {
  static const String _sessionKey = 'auth_session_v1';
  static const String _lastEmailKey = 'auth_last_email';

  final ApiClient _apiClient;

  late Box _settingsBox;
  AuthSession? _session;
  bool _initialized = false;
  bool _isLoading = false;
  String? _lastError;

  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  bool get isAuthenticated =>
      _session != null && _session!.accessToken.trim().isNotEmpty;
  String? get lastError => _lastError;
  AuthUser? get currentUser => _session?.user;
  AuthSession? get currentSession => _session;
  String? get lastEmail {
    if (!_initialized) return null;
    return _settingsBox.get(_lastEmailKey)?.toString();
  }

  Future<void> init() async {
    if (_initialized) return;

    _settingsBox = await Hive.openBox(StorageConfig.settingsBox);
    final rawSession = _settingsBox.get(_sessionKey);

    if (rawSession is Map) {
      try {
        final map = _toStringDynamicMap(rawSession);
        final parsed = AuthSession.fromJson(map);
        if (parsed.accessToken.isNotEmpty && parsed.user.id.isNotEmpty) {
          _session = parsed;
          _applySession(parsed);
        }
      } catch (e) {
        debugPrint('AuthService: failed to restore session: $e');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      _lastError = 'Email y password son obligatorios';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _lastError = null;

    try {
      final response = await _apiClient.post(
        ApiConfig.mobileAuthLoginEndpoint,
        body: {
          'email': normalizedEmail,
          'password': normalizedPassword,
        },
      );

      if (!response.isSuccess) {
        _lastError = _extractErrorMessage(response);
        return false;
      }

      if (response.data is! Map) {
        _lastError = 'Respuesta de login invalida';
        return false;
      }

      final payload = _toStringDynamicMap(response.data as Map);
      final session = AuthSession.fromJson(payload);

      if (session.accessToken.isEmpty || session.user.id.isEmpty) {
        _lastError = 'Respuesta de login incompleta';
        return false;
      }

      _session = session;
      _applySession(session);
      await _settingsBox.put(_sessionKey, session.toJson());
      await _settingsBox.put(_lastEmailKey, normalizedEmail);

      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Error de conexion: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _session = null;
    _applySession(null);
    _lastError = null;
    await _settingsBox.delete(_sessionKey);
    notifyListeners();
  }

  String _extractErrorMessage(ApiResponse response) {
    if (response.data is Map) {
      final detail = (response.data as Map)['detail'];
      if (detail != null) {
        final message = detail.toString().trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }
    return response.error ?? 'No se pudo iniciar sesion';
  }

  void _applySession(AuthSession? session) {
    ApiConfig.authToken = session?.accessToken;

    if (session == null) {
      AppConfig.technicianId = null;
      AppConfig.technicianName = null;
      return;
    }

    AppConfig.technicianId = session.user.id;
    AppConfig.technicianName = session.user.displayName.trim().isNotEmpty
        ? session.user.displayName.trim()
        : session.user.email.trim();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  Map<String, dynamic> _toStringDynamicMap(Map raw) {
    final encoded = jsonEncode(raw);
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }
}
