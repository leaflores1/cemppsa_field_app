// ==============================================================================
// CEMPPSA Field App - Sync Service
// Usa ApiClient + endpoints de ingesta (NO /sync)
// ==============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../data/models/instrumento.dart';
import '../data/models/planilla.dart';
import '../repositories/catalogo_repository.dart';
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

  Future<bool> sendPlanilla(
    Planilla planilla, {
    CatalogRepository? catalog,
  }) async {
    final requestBody = planilla.toSyncRequest();
    if (catalog != null) {
      final preflightError = _applyCatalogOverrides(
        requestBody: requestBody,
        catalog: catalog,
      );
      if (preflightError != null) {
        _lastError = preflightError;
        planilla.errorMessage = preflightError;
        return false;
      }
    }
    _normalizeAforadoresPayload(planilla, requestBody);
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

  Future<SyncResult> syncAll(
    PlanillaRepository repository, {
    CatalogRepository? catalog,
  }) async {
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

    if (catalog != null) {
      await catalog.syncFromBackend();
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

      final success = await sendPlanilla(planilla, catalog: catalog);

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

  static const Map<String, String> _aforadorAliases = {
    'AFCIZQ': 'CAV-IZQ',
    'CAVIZQ': 'CAV-IZQ',
    'AFCDER': 'CAV-DER',
    'CAVDER': 'CAV-DER',
  };

  void _normalizeAforadoresPayload(
    Planilla planilla,
    Map<String, dynamic> body,
  ) {
    if (planilla.tipo != TipoPlanilla.aforadores) {
      return;
    }
    final readings = body['readings'];
    if (readings is! List) {
      return;
    }
    for (final entry in readings) {
      if (entry is! Map) {
        continue;
      }
      final instrumentCode = entry['instrument_code'];
      if (instrumentCode is String) {
        entry['instrument_code'] = _normalizeAforadorInstrumentCode(
          instrumentCode,
        );
      }
      final parameter = entry['parameter'];
      if (parameter is String) {
        final normalized = parameter.trim().toLowerCase();
        if (normalized == 'altura' ||
            normalized == 'nivel' ||
            normalized == 'nivel_msnm' ||
            normalized == 'nivel-msnm') {
          entry['parameter'] = 'ALTURA_MM';
        } else if (normalized == 'caudal' || normalized == 'q') {
          entry['parameter'] = 'CAUDAL_LS';
        } else if (normalized == 'tiempo' ||
            normalized == 'seg' ||
            normalized == 'segundos' ||
            normalized == 'tiempo_s') {
          entry['parameter'] = 'TIEMPO_S';
        }
      }
      final parameterValue = entry['parameter'];
      if (parameterValue is String) {
        switch (parameterValue.trim().toUpperCase()) {
          case 'ALTURA_MM':
            entry['unit'] = 'mm';
            break;
          case 'CAUDAL_LS':
            entry['unit'] = 'l/s';
            break;
          case 'TIEMPO_S':
            entry['unit'] = 's';
            break;
          default:
            break;
        }
      }
    }
  }

  String? _applyCatalogOverrides({
    required Map<String, dynamic> requestBody,
    required CatalogRepository catalog,
  }) {
    final readings = requestBody['readings'];
    if (readings is! List) {
      return null;
    }

    final missing = <String>{};

    for (final entry in readings) {
      if (entry is! Map) continue;
      final code = entry['instrument_code'];
      if (code is! String) continue;

      final catalogInst = catalog.byCode(code);
      if (catalogInst == null) {
        missing.add(code);
      }
      final inst = catalogInst ?? Instrumento.fromCode(code);

      final parameter = inst.ingestaParameter ?? inst.defaultParameter;
      if (parameter.isNotEmpty) {
        entry['parameter'] = parameter;
      }

      final unit =
          inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit;
      if (unit == null || unit.trim().isEmpty) {
        entry.remove('unit');
      } else {
        entry['unit'] = unit;
      }
    }

    if (missing.isNotEmpty) {
      final list = missing.toList()..sort();
      debugPrint(
        'SyncService: instrumentos no encontrados en catálogo (se envían igual): '
        '${list.join(', ')}',
      );
    }

    return null;
  }

  String _normalizeAforadorInstrumentCode(String code) {
    final trimmed = code.trim().toUpperCase();
    final normalizedKey = trimmed.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final alias = _aforadorAliases[normalizedKey];
    if (alias != null) {
      return alias;
    }
    return trimmed.replaceAll(RegExp(r'[_\s]'), '');
  }
}
