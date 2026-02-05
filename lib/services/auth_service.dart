// ==============================================================================
// CEMPPSA Field App - Auth Service
// State Management de la sesión (Provider)
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../core/config.dart';
import '../core/storage/secure_storage_service.dart';
import '../data/models/user.dart';
import '../repositories/auth_repository.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient;
  final SecureStorageService _storage;
  late final AuthRepository _repository;

  User? _currentUser;
  bool _isLoading = true; // Empezamos cargando al inicio
  String? _error;

  AuthService({
    required ApiClient apiClient,
    required SecureStorageService storage,
  })  : _apiClient = apiClient,
        _storage = storage {
    _repository = AuthRepository(_apiClient);
  }

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSupervisor => _currentUser?.isSupervisor ?? false;

  // ===========================================================================
  // AUTH ACTIONS
  // ===========================================================================

  /// Verifica el estado de la sesión al iniciar la app
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Intentamos refrescar el token inicial
      final response = await _apiClient.post(
        ApiConfig.refreshEndpoint,
        body: {'refresh_token': refreshToken},
      );

      if (response.isSuccess) {
        final access = response.data['access_token'];
        final newRefresh = response.data['refresh_token'];

        if (access != null) {
          _apiClient.setAccessToken(access);
          if (newRefresh != null) {
            await _storage.saveRefreshToken(newRefresh);
          }

          // Obtener datos del usuario
          try {
            _currentUser = await _repository.getMe();
            await _storage.saveUserMetadata(jsonEncode(_currentUser!.toJson()));
          } catch (e) {
            debugPrint('Error getting user profile: $e');
            // Si falla getMe pero el refresh funcionó, es raro.
            // Podríamos intentar leer user del storage local si estamos offline?
            // Por ahora asumimos que si hay red para refresh, hay para getMe.
          }
        }
      } else {
        // Refresh falló (token expirado/revocado)
        debugPrint('Refresh token failed on startup: ${response.error}');
        await _clearSession();
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      // Podríamos intentar cargar usuario offline si falla la red
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final authResponse = await _repository.login(email, password);

      _currentUser = authResponse.user;
      _apiClient.setAccessToken(authResponse.accessToken);

      if (authResponse.refreshToken != null) {
        await _storage.saveRefreshToken(authResponse.refreshToken!);
      }

      await _storage.saveUserMetadata(jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _repository.register(
        email: email,
        password: password,
        fullName: fullName,
      );
      // Auto-login podría ir aquí si se desea
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      rethrow; // Para que la UI sepa que falló
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.logout();
    } catch (e) {
      debugPrint('Logout error (ignored): $e');
    } finally {
      await _clearSession();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _currentUser = null;
    _apiClient.setAccessToken(null);
    await _storage.clearAll();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
