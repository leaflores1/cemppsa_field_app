// ==============================================================================
// CEMPPSA Field App - Sync Service
// Usa ApiClient + endpoints de ingesta (NO /sync)
// ==============================================================================

import 'dart:convert';

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
    final requestBody = planilla.toSyncRequest();
    debugPrint(
      'SyncService.sendPlanilla: batch_uuid=${planilla.batchUuid} '
      'planilla_nombre=${planilla.tipo.codigo} readings_count=${planilla.totalLecturas}',
    );

    final response = await _api.post(
      '/api/v1/ingesta/planillas',
      headers: {
        'X-Request-ID': planilla.batchUuid,
      },
      body: requestBody,
    );

    final responseBody = _stringifyResponse(response.data);
    debugPrint(
      'SyncService.sendPlanilla: batch_uuid=${planilla.batchUuid} '
      'statusCode=${response.statusCode} isSuccess=${response.isSuccess}',
    );
    debugPrint(
      'SyncService.sendPlanilla: batch_uuid=${planilla.batchUuid} '
      'responseBody=$responseBody',
    );
    if (response.error != null) {
      debugPrint(
        'SyncService.sendPlanilla: batch_uuid=${planilla.batchUuid} '
        'error=${response.error}',
      );
    }

    if (response.isSuccess) {
      final status =
          response.data is Map ? response.data['status']?.toString() : null;
      if (status == 'accepted' || status == 'duplicate') {
        return true;
      }

      final errorMessage = _buildPlanillaError(
        planilla: planilla,
        response: response,
        responseBody: responseBody,
        extra: 'unexpected_status=$status',
      );
      _lastError = errorMessage;
      planilla.errorMessage = errorMessage;
      return false;
    }

    final errorMessage = _buildPlanillaError(
      planilla: planilla,
      response: response,
      responseBody: responseBody,
    );
    _lastError = errorMessage;
    planilla.errorMessage = errorMessage;
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

    final pendientes = List<Planilla>.from(repository.pendientes);
    debugPrint(
      'SyncService.syncAll: status=$_status total_planillas=${repository.count} '
      'pendientes=${pendientes.length}',
    );

    final connected = await checkConnection();
    if (!connected) {
      return SyncResult(
        sent: 0,
        failed: 0,
        message: 'Sin conexión al servidor',
      );
    }

    _status = ConnectionStatus.syncing;

    _pendingCount = pendientes.length;
    notifyListeners();

    int sent = 0;
    int failed = 0;

    for (final planilla in pendientes) {
      debugPrint(
        'SyncService.syncAll: planilla batch_uuid=${planilla.batchUuid} '
        'planilla_nombre=${planilla.tipo.codigo} estado=${planilla.estado.name} '
        'lecturas_count=${planilla.totalLecturas}',
      );
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

  String _stringifyResponse(dynamic value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return value;
    }
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _buildPlanillaError({
    required Planilla planilla,
    required ApiResponse response,
    required String responseBody,
    String? extra,
  }) {
    final statusCode = response.statusCode?.toString() ?? 'null';
    final error = response.error;
    final extraPart = (extra != null && extra.isNotEmpty) ? ' $extra' : '';
    if (error != null && error.isNotEmpty) {
      return 'batch_uuid=${planilla.batchUuid} statusCode=$statusCode '
          'error=$error$extraPart body=$responseBody';
    }
    return 'batch_uuid=${planilla.batchUuid} statusCode=$statusCode'
        '$extraPart body=$responseBody';
  }
}
