// ==============================================================================
// CEMPPSA Field App - Sync Service
// Usa ApiClient + endpoints de ingesta (NO /sync)
// ==============================================================================

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../data/models/planilla.dart';
import '../repositories/planilla_repository.dart';

/// Estado de conexión con el backend
enum ConnectionStatus {
  unknown,
  connected,
  disconnected,
  syncing,
}

/// Resultado de sincronización
class SyncResult {
  final int sent;
  final int failed;
  final String message;

  SyncResult({
    required this.sent,
    required this.failed,
    required this.message,
  });

  bool get success => failed == 0 && sent > 0;
  bool get hasErrors => failed > 0;
}

/// Servicio de sincronización principal
class SyncService extends ChangeNotifier {
  final ApiClient _api;

  ConnectionStatus _status = ConnectionStatus.unknown;
  String? _lastError;
  DateTime? _lastSync;
  int _pendingCount = 0;

  SyncService({required ApiClient apiClient}) : _api = apiClient;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  ConnectionStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSync => _lastSync;
  int get pendingCount => _pendingCount;

  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isSyncing => _status == ConnectionStatus.syncing;

  // ===========================================================================
  // HEALTH CHECK
  // ===========================================================================

  Future<bool> checkConnection() async {
    debugPrint('SyncService: Verificando conexión...');
    final response = await _api.get('/health');

    debugPrint('SyncService: Response isSuccess=${response.isSuccess}');
    debugPrint('SyncService: Response data=${response.data}');
    debugPrint('SyncService: Response error=${response.error}');

    if (response.isSuccess) {
      // El backend puede devolver: {"status": "ok"} o {"database": "ok"}
      final status = response.data?['status'];
      final db = response.data?['database'];

      if (status == 'ok' || db == 'ok') {
        debugPrint('SyncService: ✓ Conectado');
        _status = ConnectionStatus.connected;
        _lastError = null;
        notifyListeners();
        return true;
      }
    }

    debugPrint('SyncService: ✗ Desconectado');
    _status = ConnectionStatus.disconnected;
    _lastError = response.error ?? 'Servidor no disponible';
    notifyListeners();
    return false;
  }

  // ===========================================================================
  // ENVÍO DE PLANILLA
  // ===========================================================================

  Future<bool> sendPlanilla(Planilla planilla) async {
    final response = await _api.post(
      '/api/v1/ingesta/planillas',
      body: planilla.toSyncRequest(),
    );

    if (response.isSuccess) {
      final status = response.data?['status'];
      return status == 'accepted' || status == 'duplicate';
    }

    _lastError = response.error ??
        'HTTP ${response.statusCode}: ${response.data}';
    return false;
  }

  // ===========================================================================
  // SYNC MASIVO
  // ===========================================================================

  Future<SyncResult> syncAll(PlanillaRepository repository) async {
    if (_status == ConnectionStatus.syncing) {
      return SyncResult(
        sent: 0,
        failed: 0,
        message: 'Ya hay una sincronización en curso',
      );
    }

    final connected = await checkConnection();
    if (!connected) {
      return SyncResult(
        sent: 0,
        failed: 0,
        message: 'Sin conexión al servidor',
      );
    }

    _status = ConnectionStatus.syncing;

    final pendientes = List<Planilla>.from(repository.pendientes);
    _pendingCount = pendientes.length;
    notifyListeners();

    int sent = 0;
    int failed = 0;

    for (final planilla in pendientes) {
      planilla.marcarEnviando();
      await repository.save(planilla);
      notifyListeners();

      final success = await sendPlanilla(planilla);

      if (success) {
        planilla.marcarEnviada();
        sent++;
      } else {
        planilla.marcarError(_lastError ?? 'Error desconocido');
        failed++;
      }

      await repository.save(planilla);
      _pendingCount--;
      notifyListeners();
    }

    _status = ConnectionStatus.connected;
    _lastSync = DateTime.now();
    _pendingCount = 0;
    notifyListeners();

    return SyncResult(
      sent: sent,
      failed: failed,
      message: failed == 0
          ? 'Sincronización completada ($sent planillas)'
          : '$sent enviadas, $failed con error',
    );
  }

  // ===========================================================================
  // REINTENTO INDIVIDUAL
  // ===========================================================================

  Future<bool> retrySingle(
    Planilla planilla,
    PlanillaRepository repository,
  ) async {
    final connected = await checkConnection();
    if (!connected) {
      planilla.marcarError('Sin conexión');
      await repository.save(planilla);
      return false;
    }

    planilla.marcarEnviando();
    await repository.save(planilla);
    notifyListeners();

    final success = await sendPlanilla(planilla);

    if (success) {
      planilla.marcarEnviada();
    } else {
      planilla.marcarError(_lastError ?? 'Error desconocido');
    }

    await repository.save(planilla);
    notifyListeners();

    return success;
  }
}
