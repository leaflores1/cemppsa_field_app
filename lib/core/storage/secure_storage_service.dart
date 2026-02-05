import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // Configuración segura para Android y iOS
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const _keyRefreshToken = 'refresh_token';
  static const _keyUser = 'user_metadata';

  /// Guarda el Refresh Token de forma segura
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _keyRefreshToken, value: token);
  }

  /// Obtiene el Refresh Token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Borra el Refresh Token
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Guarda metadata del usuario (JSON string) para mostrar info básica offline
  Future<void> saveUserMetadata(String json) async {
    await _storage.write(key: _keyUser, value: json);
  }

  /// Obtiene metadata del usuario
  Future<String?> getUserMetadata() async {
    return await _storage.read(key: _keyUser);
  }

  /// Limpia todo el almacenamiento seguro (Logout completo)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
