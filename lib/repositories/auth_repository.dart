import '../api/api_client.dart';
import '../core/config.dart';
import '../data/models/user.dart';

class AuthRepository {
  final ApiClient _api;

  AuthRepository(this._api);

  Future<AuthResponse> login(String email, String password) async {
    final response = await _api.post(
      ApiConfig.loginEndpoint,
      body: {
        'email': email,
        'password': password,
      },
    );

    if (response.isSuccess) {
      return AuthResponse.fromJson(response.data);
    } else {
      throw Exception(response.error ?? 'Credenciales inválidas');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _api.post(
      ApiConfig.registerEndpoint,
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
      },
    );

    if (!response.isSuccess) {
      throw Exception(response.error ?? 'Error en el registro');
    }
  }

  Future<User> getMe() async {
    final response = await _api.get(ApiConfig.meEndpoint);

    if (response.isSuccess) {
      // Asumimos que devuelve el User o { "user": ... }
      // Si devuelve user directo:
      try {
        if (response.data is Map && response.data.containsKey('user')) {
             return User.fromJson(response.data['user']);
        }
        return User.fromJson(response.data);
      } catch (e) {
         // Fallback por si la estructura es diferente
         throw Exception('Error parseando usuario: $e');
      }
    } else {
      throw Exception(response.error ?? 'Sesión expirada');
    }
  }

  Future<void> logout() async {
    // Intentamos llamar al backend, pero no bloqueamos si falla
    await _api.post(ApiConfig.logoutEndpoint);
  }
}
