// ==============================================================================
// CEMPPSA Field App - Configuration
// Configuración centralizada de la aplicación
// ==============================================================================

/// Configuración de la API del backend
class ApiConfig {
  /// URL base del servidor
  /// Cambiar según el entorno:
  /// - Local: 'http://10.0.2.2:8000' (emulador Android)
  /// - Local: 'http://localhost:8000' (web/desktop)
  /// - Producción: 'https://api.cemppsa.com'
  /// 'http://192.168.113.103:8000'
  /// 'http://192.168.100.112:8000'
  static const String baseUrl = 'http://192.168.100.112:8000'; 

  /// Endpoints de la API
  static const String healthEndpoint = '/health';
  static const String ingestaEndpoint = '/api/v1/ingesta/planillas';
  static const String catalogEndpoint = '/api/v1/catalog-app/instruments';
  static const String batchesEndpoint = '/api/v1/batches';
  static const String fotosEndpoint = '/api/v1/fotos';
  static const String authLoginEndpoint = '/api/v1/auth/login';

  /// Token Bearer opcional para endpoints protegidos
  /// Si no se configura, las requests se envían sin Authorization.
  static String? authToken;

  /// Credenciales para sincronización de fotos (backend protegido).
  /// Recomendado: mover a ajustes/secure storage en próxima iteración.
  static String fieldAppEmail = 'admin@cemppsa.com';
  static String fieldAppPassword = 'admin123';

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
