import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../data/models/auth_session.dart';

class AuthService extends ChangeNotifier {
  static const String _sessionKey = 'auth_session_v1';
  static const String _lastEmailKey = 'auth_last_email';
  static const String _offlinePinHashKey = 'auth_offline_pin_hash_v1';
  static const String _offlinePinOwnerKey = 'auth_offline_pin_owner_v1';
  static const String _offlineAutoLockKey = 'auth_offline_auto_lock_v1';

  final ApiClient _apiClient;

  late Box _settingsBox;
  AuthSession? _session;
  String? _offlinePinHash;
  String? _offlinePinOwnerId;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isLocallyUnlocked = false;
  bool _offlineAutoLockEnabled = true;
  String? _lastError;

  AuthService({required ApiClient apiClient}) : _apiClient = apiClient;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;
  bool get hasStoredSession => _session != null && _session!.user.id.isNotEmpty;
  bool get hasOfflinePin =>
      (_offlinePinHash?.trim().isNotEmpty ?? false) &&
      (_offlinePinOwnerId?.trim().isNotEmpty ?? false) &&
      _offlinePinOwnerId == _session?.user.id;
  bool get offlineAutoLockEnabled => _offlineAutoLockEnabled;
  bool get requiresLocalUnlock =>
      hasStoredSession && hasOfflinePin && !_isLocallyUnlocked;
  bool get isAuthenticated => hasStoredSession && !requiresLocalUnlock;
  bool get isLocallyUnlocked => _isLocallyUnlocked;
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
    _offlinePinHash = _settingsBox.get(_offlinePinHashKey)?.toString();
    _offlinePinOwnerId = _settingsBox.get(_offlinePinOwnerKey)?.toString();
    final storedAutoLock = _settingsBox.get(_offlineAutoLockKey);
    if (storedAutoLock is bool) {
      _offlineAutoLockEnabled = storedAutoLock;
    }
    final rawSession = _settingsBox.get(_sessionKey);

    if (rawSession is Map) {
      try {
        final map = _toStringDynamicMap(rawSession);
        final parsed = AuthSession.fromJson(map);
        if (parsed.accessToken.isNotEmpty && parsed.user.id.isNotEmpty) {
          _session = parsed;
          _applySession(parsed);
          _syncLocalUnlockState();
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

      await _reconcileOfflinePinOwner(session.user.id);
      _session = session;
      _applySession(session);
      _isLocallyUnlocked = true;
      await _settingsBox.put(_sessionKey, session.toJson());
      await _settingsBox.put(_lastEmailKey, normalizedEmail);

      _lastError = null;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error de conexion: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _clearSession();
  }

  Future<bool> refreshSession() async {
    final currentSession = _session;
    final refreshToken = currentSession?.refreshToken.trim();
    if (currentSession == null || refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await _apiClient.post(
        ApiConfig.mobileAuthRefreshEndpoint,
        body: {
          'refresh_token': refreshToken,
        },
      );

      if (!response.isSuccess || response.data is! Map) {
        debugPrint('AuthService: mobile refresh failed: ${response.statusCode}');
        return false;
      }

      final payload = _toStringDynamicMap(response.data as Map);
      final newAccessToken = (payload['access_token'] ?? '').toString().trim();
      if (newAccessToken.isEmpty) {
        debugPrint('AuthService: mobile refresh returned empty token');
        return false;
      }

      final updatedSession = currentSession.copyWith(
        accessToken: newAccessToken,
        tokenType: (payload['token_type'] ?? currentSession.tokenType)
            .toString()
            .trim(),
      );

      _session = updatedSession;
      _applySession(updatedSession);
      _isLocallyUnlocked = true;
      _lastError = null;
      await _settingsBox.put(_sessionKey, updatedSession.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: error refreshing mobile session: $e');
      return false;
    }
  }

  Future<void> handleSessionExpired() async {
    await _clearSession(
      errorMessage: 'Sesion expirada. Volve a iniciar sesion.',
    );
  }

  Future<bool> setOfflinePin(String pin) async {
    final normalizedPin = pin.trim();
    if (!_isValidPin(normalizedPin) || _session == null) {
      return false;
    }

    final userId = _session!.user.id;
    final hash = _hashPin(normalizedPin, userId);
    _offlinePinHash = hash;
    _offlinePinOwnerId = userId;
    _isLocallyUnlocked = true;

    await _settingsBox.put(_offlinePinHashKey, hash);
    await _settingsBox.put(_offlinePinOwnerKey, userId);
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithPin(String pin) async {
    final normalizedPin = pin.trim();
    if (!hasStoredSession || !hasOfflinePin || !_isValidPin(normalizedPin)) {
      return false;
    }

    final expectedHash = _hashPin(normalizedPin, _session!.user.id);
    if (expectedHash != _offlinePinHash) {
      return false;
    }

    _isLocallyUnlocked = true;
    _lastError = null;
    notifyListeners();
    return true;
  }

  Future<void> clearOfflinePin() async {
    _offlinePinHash = null;
    _offlinePinOwnerId = null;
    _isLocallyUnlocked = true;
    await _settingsBox.delete(_offlinePinHashKey);
    await _settingsBox.delete(_offlinePinOwnerKey);
    notifyListeners();
  }

  void lockLocally() {
    if (!hasStoredSession || !hasOfflinePin) {
      return;
    }
    _isLocallyUnlocked = false;
    notifyListeners();
  }

  bool lockLocallyIfNeeded() {
    if (!hasStoredSession || !hasOfflinePin || !_offlineAutoLockEnabled) {
      return false;
    }
    if (!_isLocallyUnlocked) {
      return false;
    }
    _isLocallyUnlocked = false;
    notifyListeners();
    return true;
  }

  Future<void> setOfflineAutoLockEnabled(bool value) async {
    if (_offlineAutoLockEnabled == value) {
      return;
    }
    _offlineAutoLockEnabled = value;
    await _settingsBox.put(_offlineAutoLockKey, value);
    notifyListeners();
  }

  void updateApiBaseUrl(String baseUrl) {
    _apiClient.setBaseUrl(baseUrl);
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
    ApiConfig.refreshToken = session?.refreshToken;

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

  void _syncLocalUnlockState() {
    if (!hasStoredSession) {
      _isLocallyUnlocked = false;
      return;
    }

    if (!hasOfflinePin) {
      _isLocallyUnlocked = true;
      return;
    }

    _isLocallyUnlocked = false;
  }

  Future<void> _reconcileOfflinePinOwner(String newUserId) async {
    final currentOwner = _offlinePinOwnerId?.trim();
    if (currentOwner == null || currentOwner.isEmpty || currentOwner == newUserId) {
      return;
    }

    _offlinePinHash = null;
    _offlinePinOwnerId = null;
    await _settingsBox.delete(_offlinePinHashKey);
    await _settingsBox.delete(_offlinePinOwnerKey);
  }

  bool _isValidPin(String value) {
    return RegExp(r'^\d{4,8}$').hasMatch(value);
  }

  String _hashPin(String pin, String userId) {
    final digest = sha256.convert(utf8.encode('$userId::$pin'));
    return digest.toString();
  }

  Map<String, dynamic> _toStringDynamicMap(Map raw) {
    final encoded = jsonEncode(raw);
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  Future<void> _clearSession({String? errorMessage}) async {
    _session = null;
    _applySession(null);
    _offlinePinHash = null;
    _offlinePinOwnerId = null;
    _isLocallyUnlocked = false;
    _lastError = errorMessage;
    await _settingsBox.delete(_sessionKey);
    await _settingsBox.delete(_offlinePinHashKey);
    await _settingsBox.delete(_offlinePinOwnerKey);
    notifyListeners();
  }
}
