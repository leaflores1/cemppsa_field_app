import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../data/models/auth_session.dart';
import '../utils/network_errors.dart';

class AuthService extends ChangeNotifier {
  static const String _sessionKey = 'auth_session_v1';
  static const String _lastEmailKey = 'auth_last_email';
  static const String _offlinePinHashKey = 'auth_offline_pin_hash_v1';
  static const String _offlinePinOwnerKey = 'auth_offline_pin_owner_v1';
  static const String _offlineAutoLockKey = 'auth_offline_auto_lock_v1';
  static const String _offlineAuthCacheKey = 'auth_offline_cache_v1';
  static const String _offlineAuthVersion = '1';
  static const int _offlineAuthIterations = 20000;
  static const int _offlineAuthHashBytes = 32;

  final ApiClient _apiClient;
  final Future<bool> Function()? _hasNoNetworkConnectionOverride;

  late Box _settingsBox;
  AuthSession? _session;
  String? _offlinePinHash;
  String? _offlinePinOwnerId;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isLocallyUnlocked = false;
  bool _isOfflineAuthenticated = false;
  bool _lastLoginWasOffline = false;
  bool _offlineAutoLockEnabled = true;
  String? _lastError;

  AuthService({
    required ApiClient apiClient,
    Future<bool> Function()? hasNoNetworkConnection,
  })  : _apiClient = apiClient,
        _hasNoNetworkConnectionOverride = hasNoNetworkConnection;

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
  bool get isOfflineAuthenticated => _isOfflineAuthenticated;
  bool get lastLoginWasOffline => _lastLoginWasOffline;
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
        if (parsed.user.id.isNotEmpty) {
          _session = parsed;
          _applySession(parsed);
          _isOfflineAuthenticated = parsed.accessToken.trim().isEmpty;
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
    _lastLoginWasOffline = false;

    try {
      if (await _hasNoNetworkConnection()) {
        return _tryOfflineLogin(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      }

      final response = await _apiClient.post(
        ApiConfig.mobileAuthLoginEndpoint,
        body: {
          'email': normalizedEmail,
          'password': normalizedPassword,
        },
      );

      if (!response.isSuccess) {
        if (_isOfflineLoginCandidate(response)) {
          return _tryOfflineLogin(
            email: normalizedEmail,
            password: normalizedPassword,
          );
        }
        _lastError = _extractErrorMessage(response);
        await _maybeDisableOfflineAuthForBackendRejection(
          normalizedEmail,
          _lastError,
        );
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
      await _storeOfflineAuth(
        email: normalizedEmail,
        password: normalizedPassword,
        session: session,
      );
      _session = session;
      _applySession(session);
      _isLocallyUnlocked = true;
      _isOfflineAuthenticated = false;
      await _settingsBox.put(_sessionKey, session.toJson());
      await _settingsBox.put(_lastEmailKey, normalizedEmail);

      _lastError = null;
      _lastLoginWasOffline = false;
      notifyListeners();
      return true;
    } catch (e) {
      return _tryOfflineLogin(
        email: normalizedEmail,
        password: normalizedPassword,
      );
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _clearSession();
  }

  Future<void> logoutCompletely() async {
    await _clearSession(clearOfflineAuth: true);
  }

  Future<bool> refreshSession() async {
    final currentSession = _session;
    final refreshToken = currentSession?.refreshToken.trim();
    if (currentSession == null ||
        refreshToken == null ||
        refreshToken.isEmpty) {
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
        debugPrint(
            'AuthService: mobile refresh failed: ${response.statusCode}');
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
      _isOfflineAuthenticated = false;
      _lastLoginWasOffline = false;
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

  bool _isOfflineLoginCandidate(ApiResponse response) {
    return response.statusCode == null &&
        isConnectivityFailure(
          statusCode: response.statusCode,
          message: response.error,
        );
  }

  Future<bool> _hasNoNetworkConnection() async {
    final override = _hasNoNetworkConnectionOverride;
    if (override != null) {
      return override();
    }

    try {
      final result = await Connectivity().checkConnectivity();
      return result.every((value) => value == ConnectivityResult.none);
    } catch (e) {
      debugPrint('AuthService: connectivity precheck unavailable: $e');
    }
    return false;
  }

  Future<bool> _tryOfflineLogin({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final record = _offlineAuthRecordFor(normalizedEmail);

    if (record == null) {
      _lastError =
          'Necesitas conectarte al servidor al menos una vez para habilitar este usuario en el dispositivo.';
      notifyListeners();
      return false;
    }

    final offlineEnabled = record['offline_auth_enabled'] is bool
        ? record['offline_auth_enabled'] as bool
        : record['offline_auth_enabled']?.toString() != 'false';
    if (!offlineEnabled) {
      _lastError =
          'Este usuario requiere revalidacion online antes de volver a ingresar offline.';
      notifyListeners();
      return false;
    }

    final salt = (record['password_salt'] ?? '').toString();
    final expectedHash = (record['password_hash_local'] ?? '').toString();
    final userId = (record['user_id'] ?? '').toString();
    if (salt.isEmpty || expectedHash.isEmpty || userId.isEmpty) {
      _lastError =
          'La autorizacion offline local esta incompleta. Inicia sesion con conexion.';
      notifyListeners();
      return false;
    }

    final enteredHash = _hashOfflinePassword(
      email: normalizedEmail,
      password: password,
      salt: salt,
      userId: userId,
    );

    if (!_constantTimeEquals(enteredHash, expectedHash)) {
      _lastError = 'Credenciales offline invalidas.';
      notifyListeners();
      return false;
    }

    final user = AuthUser(
      id: userId,
      email: (record['email'] ?? normalizedEmail).toString(),
      displayName: (record['display_name'] ?? normalizedEmail).toString(),
      role: record['role']?.toString(),
      platformAccess: record['platform_access']?.toString(),
    );
    final session = AuthSession(
      accessToken: '',
      refreshToken: '',
      tokenType: 'offline',
      user: user,
    );

    await _reconcileOfflinePinOwner(session.user.id);
    _session = session;
    _applySession(session);
    _isLocallyUnlocked = true;
    _isOfflineAuthenticated = true;
    _lastLoginWasOffline = true;
    _lastError = null;
    await _settingsBox.put(_sessionKey, session.toJson());
    await _settingsBox.put(_lastEmailKey, email.trim());
    notifyListeners();
    return true;
  }

  Future<void> _storeOfflineAuth({
    required String email,
    required String password,
    required AuthSession session,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    final cache = _offlineAuthCache();
    final existing = _offlineAuthRecordFor(normalizedEmail, cache: cache);
    final salt = (existing?['password_salt'] ?? '').toString().isNotEmpty
        ? existing!['password_salt'].toString()
        : _newSalt();
    final passwordHash = _hashOfflinePassword(
      email: normalizedEmail,
      password: password,
      salt: salt,
      userId: session.user.id,
    );

    cache[normalizedEmail] = {
      'email': session.user.email.trim().isNotEmpty
          ? session.user.email.trim()
          : normalizedEmail,
      'user_id': session.user.id,
      'display_name': session.user.displayName,
      'role': session.user.role,
      'platform_access': session.user.platformAccess,
      'password_hash_local': passwordHash,
      'password_salt': salt,
      'last_successful_online_login_at': DateTime.now().toIso8601String(),
      'offline_auth_enabled': true,
      'device_id': AppConfig.deviceId,
      'offline_auth_version': _offlineAuthVersion,
      'hash_iterations': _offlineAuthIterations,
    };

    await _settingsBox.put(_offlineAuthCacheKey, cache);
  }

  Future<void> _maybeDisableOfflineAuthForBackendRejection(
    String email,
    String? message,
  ) async {
    final text = (message ?? '').toLowerCase();
    final shouldDisable = text.contains('inactive') ||
        text.contains('disabled') ||
        text.contains('not enabled for mobile') ||
        text.contains('platform') ||
        text.contains('sin permiso') ||
        text.contains('permiso');
    if (!shouldDisable) return;

    final normalizedEmail = _normalizeEmail(email);
    final cache = _offlineAuthCache();
    final record = _offlineAuthRecordFor(normalizedEmail, cache: cache);
    if (record == null) return;
    record['offline_auth_enabled'] = false;
    record['disabled_reason'] = message;
    record['disabled_at'] = DateTime.now().toIso8601String();
    cache[normalizedEmail] = record;
    await _settingsBox.put(_offlineAuthCacheKey, cache);
  }

  Map<String, dynamic> _offlineAuthCache() {
    final raw = _settingsBox.get(_offlineAuthCacheKey);
    if (raw is Map) {
      return _toStringDynamicMap(raw);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _offlineAuthRecordFor(
    String email, {
    Map<String, dynamic>? cache,
  }) {
    final raw = (cache ?? _offlineAuthCache())[_normalizeEmail(email)];
    if (raw is Map) {
      return _toStringDynamicMap(raw);
    }
    return null;
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashOfflinePassword({
    required String email,
    required String password,
    required String salt,
    required String userId,
  }) {
    final passwordBytes = utf8.encode(
      '${_normalizeEmail(email)}::$userId::${AppConfig.deviceId ?? ''}::$password',
    );
    final saltBytes = utf8.encode(salt);
    final derived = _pbkdf2(
      passwordBytes: passwordBytes,
      saltBytes: saltBytes,
      iterations: _offlineAuthIterations,
      outputBytes: _offlineAuthHashBytes,
    );
    return base64UrlEncode(derived);
  }

  List<int> _pbkdf2({
    required List<int> passwordBytes,
    required List<int> saltBytes,
    required int iterations,
    required int outputBytes,
  }) {
    final hmac = Hmac(sha256, passwordBytes);
    final digestBytes = sha256.convert(const <int>[]).bytes.length;
    final blockCount = (outputBytes + digestBytes - 1) ~/ digestBytes;
    final result = <int>[];

    for (var block = 1; block <= blockCount; block++) {
      final blockBytes = <int>[
        ...saltBytes,
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];

      var u = hmac.convert(blockBytes).bytes;
      final t = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }

      result.addAll(t);
    }

    return result.take(outputBytes).toList(growable: false);
  }

  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;
    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
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
    if (currentOwner == null ||
        currentOwner.isEmpty ||
        currentOwner == newUserId) {
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

  Future<void> _clearSession({
    String? errorMessage,
    bool clearOfflineAuth = false,
  }) async {
    _session = null;
    _applySession(null);
    _offlinePinHash = null;
    _offlinePinOwnerId = null;
    _isLocallyUnlocked = false;
    _isOfflineAuthenticated = false;
    _lastLoginWasOffline = false;
    _lastError = errorMessage;
    await _settingsBox.delete(_sessionKey);
    await _settingsBox.delete(_offlinePinHashKey);
    await _settingsBox.delete(_offlinePinOwnerKey);
    if (clearOfflineAuth) {
      await _settingsBox.delete(_offlineAuthCacheKey);
      await _settingsBox.delete(_lastEmailKey);
    }
    notifyListeners();
  }
}
