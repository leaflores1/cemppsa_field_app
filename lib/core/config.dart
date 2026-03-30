// ==============================================================================
// CEMPPSA Field App - Configuration
// Configuración centralizada de la aplicación
// ==============================================================================

/// Configuración de la API del backend
class ApiConfig {
  static const String defaultBaseUrl = String.fromEnvironment(
    'CEMPPSA_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const String settingsServerUrlKey = 'api_base_url';
  static const Set<String> legacyBaseUrls = {
    'http://127.0.0.1:8000',
    'http://localhost:8000',
    'http://192.168.113.121:8000',
  };
  static String _baseUrl = defaultBaseUrl;
  static bool _hasCustomBaseUrl = false;

  /// URL base del servidor
  /// Cambiar según el entorno:
  /// - Local: 'http://10.0.2.2:8000' (emulador Android)
  /// - Local: 'http://localhost:8000' (web/desktop)
  /// - Producción: 'https://api.cemppsa.com'
  /// 'http://192.168.113.103:8000'
  /// 'http://192.168.100.112:8000'
  static String get baseUrl => _baseUrl;
  static bool get hasCustomBaseUrl => _hasCustomBaseUrl;
  static bool get hasConfiguredBaseUrl => !isLoopbackHost(_baseUrl);
  static bool get hasUsableCustomBaseUrl =>
      _hasCustomBaseUrl && !isLoopbackHost(_baseUrl);
  static String get serverLabel =>
      hasConfiguredBaseUrl ? _baseUrl : 'Sin servidor configurado';

  static String? normalizeBaseUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.trim().isEmpty) return null;

    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static bool setBaseUrl(String raw, {bool markAsCustom = true}) {
    final normalized = normalizeBaseUrl(raw);
    if (normalized == null) return false;
    _baseUrl = normalized;
    _hasCustomBaseUrl = markAsCustom;
    return true;
  }

  static void resetBaseUrlToDefault() {
    _baseUrl = defaultBaseUrl;
    _hasCustomBaseUrl = false;
  }

  static bool shouldReplacePersistedBaseUrl(String? raw) {
    final normalized = raw == null ? null : normalizeBaseUrl(raw);
    if (normalized == null) return false;
    return isLoopbackHost(normalized) || legacyBaseUrls.contains(normalized);
  }

  static bool isLoopbackHost(String raw) {
    final uri = Uri.tryParse(raw);
    final host = uri?.host.trim().toLowerCase() ?? '';
    return host == '127.0.0.1' || host == 'localhost';
  }

  /// Endpoints de la API
  static const String healthEndpoint = '/health';
  static const String ingestaEndpoint = '/api/v1/ingesta/planillas';
  static const String catalogEndpoint = '/api/v1/catalog-app/instruments';
  static const String batchesEndpoint = '/api/v1/batches';
  static const String fotosEndpoint = '/api/v1/fotos';
  static const String authLoginEndpoint = '/api/v1/auth/login';
  static const String mobileAuthLoginEndpoint = '/api/v1/auth/mobile/login';
  static const String mobileAuthRefreshEndpoint = '/api/v1/auth/mobile/refresh';
  static const String appVersionEndpoint = '/api/v1/app/version';

  /// Token Bearer opcional para endpoints protegidos.
  /// Si no se configura, las requests se envían sin Authorization.
  static String? authToken;
  static String? refreshToken;
  static Future<bool> Function()? refreshAuthToken;
  static Future<void> Function()? handleSessionExpired;

  /// Timeouts
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

/// Configuración de la aplicación
class AppConfig {
  static const String appName = 'CEMPPSA Field';
  static const String version = '2.0.0';

  /// ID del dispositivo (generado automáticamente)
  static String? deviceId;

  /// ID del técnico (configurado por el usuario)
  static String? technicianId;
  static String? technicianName;

  /// Intervalo de auto-sync en minutos
  static const int autoSyncIntervalMinutes = 15;

  /// Intervalo de actualización del catálogo en horas
  static const int catalogSyncIntervalHours = 24;
}

/// Configuración de almacenamiento local (Hive)
class StorageConfig {
  static const String planillasBox = 'planillas';
  static const String catalogBox = 'catalog';
  static const String settingsBox = 'settings';
  static const String fotosBox = 'fotos_v1';
}
