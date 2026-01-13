class AppConfig {
  static const candidateBaseUrls = [
    'http://192.168.113.188:8000',
    'http://192.168.100.112:8000',
  ];

  static const healthPath = '/health';  // ✅ FastAPI lo tiene y responde 200
  static const apiSyncPath = '/api/v1/sync';
  static const httpTimeout = Duration(seconds: 5);
}
