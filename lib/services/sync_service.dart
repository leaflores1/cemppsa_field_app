// ==============================================================================
// CEMPPSA Field App - Sync Service
// Usa ApiClient + endpoints de ingesta (NO /sync)
// ==============================================================================

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../core/config.dart';
import '../data/models/instrumento.dart';
import '../data/models/planilla.dart';
import '../repositories/catalogo_repository.dart';
import '../repositories/planilla_repository.dart';

/// Estado de conexiÃ³n con el backend
enum ConnectionStatus {
  unknown,
  connected,
  disconnected,
  syncing,
}

/// Resultado de sincronizaciÃ³n
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

class RejectedPlanillaNotice {
  final String batchUuid;
  final String? motivoPrincipal;
  final List<String> motivos;

  const RejectedPlanillaNotice({
    required this.batchUuid,
    required this.motivoPrincipal,
    required this.motivos,
  });
}

/// Servicio de sincronizaciÃ³n principal
class SyncService extends ChangeNotifier {
  final ApiClient _api;

  ConnectionStatus _status = ConnectionStatus.unknown;
  String? _lastError;
  bool _lastWasConnectivityIssue = false;
  DateTime? _lastSync;
  int _pendingCount = 0;

  SyncService({required ApiClient apiClient}) : _api = apiClient;

  // ===========================================================================
  // GETTERS
  // ===========================================================================

  ConnectionStatus get status => _status;
  String? get lastError => _lastError;
  bool get lastWasConnectivityIssue => _lastWasConnectivityIssue;
  DateTime? get lastSync => _lastSync;
  int get pendingCount => _pendingCount;

  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isSyncing => _status == ConnectionStatus.syncing;

  // ===========================================================================
  // HEALTH CHECK
  // ===========================================================================

  Future<bool> checkConnection() async {
    debugPrint('SyncService: Verificando conexiÃ³n...');
    final response = await _api.get('/health');

    debugPrint('SyncService: Response isSuccess=${response.isSuccess}');
    debugPrint('SyncService: Response data=${response.data}');
    debugPrint('SyncService: Response error=${response.error}');

    if (response.isSuccess) {
      // El backend puede devolver: {"status": "ok"} o {"database": "ok"}
      final status = response.data?['status'];
      final db = response.data?['database'];

      if (status == 'ok' || db == 'ok') {
        debugPrint('SyncService: âœ“ Conectado');
        _status = ConnectionStatus.connected;
        _lastError = null;
        notifyListeners();
        return true;
      }
    }

    debugPrint('SyncService: âœ— Desconectado');
    _status = ConnectionStatus.disconnected;
    _lastError = response.error ?? 'Servidor no disponible';
    notifyListeners();
    return false;
  }

  // ===========================================================================
  // ENVÃO DE PLANILLA
  // ===========================================================================

  Future<bool> sendPlanilla(
    Planilla planilla, {
    CatalogRepository? catalog,
  }) async {
    _lastWasConnectivityIssue = false;
    final requestBody = planilla.toSyncRequest();
    _injectSenderMetadata(planilla, requestBody);
    if (catalog != null) {
      final preflightError = _applyCatalogOverrides(
        requestBody: requestBody,
        catalog: catalog,
      );
      if (preflightError != null) {
        _lastError = preflightError;
        _lastWasConnectivityIssue = false;
        planilla.errorMessage = preflightError;
        return false;
      }
    }

    // [MODIFIED] Check for Manual Types to use "Operaciones" flow
    if (_isManualPlanilla(planilla.tipo)) {
      return _sendManualPlanilla(planilla);
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
        _lastWasConnectivityIssue = false;
        return true;
      }

      final errorMessage = _buildPlanillaError(
        planilla: planilla,
        response: response,
        responseBody: responseBody,
        extra: 'unexpected_status=$status',
      );
      _lastError = errorMessage;
      _lastWasConnectivityIssue =
          _isConnectivityFailure(response: response, message: errorMessage);
      if (!_lastWasConnectivityIssue) {
        planilla.errorMessage = errorMessage;
      }
      return false;
    }

    final errorMessage = _buildPlanillaError(
      planilla: planilla,
      response: response,
      responseBody: responseBody,
    );
    _lastError = errorMessage;
    _lastWasConnectivityIssue =
        _isConnectivityFailure(response: response, message: errorMessage);
    if (!_lastWasConnectivityIssue) {
      planilla.errorMessage = errorMessage;
    }
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
        message: 'Ya hay una sincronizaciÃ³n en curso',
      );
    }

    final pendientes = repository.pendientes
        .where((p) => p.estado != PlanillaEstado.rechazada)
        .toList();
    debugPrint(
      'SyncService.syncAll: status=$_status total_planillas=${repository.count} '
      'pendientes=${pendientes.length}',
    );

    final connected = await checkConnection();
    if (!connected) {
      return SyncResult(
        sent: 0,
        failed: 0,
        message: 'Sin conexiÃ³n al servidor',
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
    bool connectivityInterrupted = false;

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
        if (_lastWasConnectivityIssue) {
          planilla.marcarPendiente();
          connectivityInterrupted = true;
        } else {
          planilla.marcarError(_lastError ?? 'Error desconocido');
          failed++;
        }
      }

      await repository.save(planilla);
      _pendingCount--;
      notifyListeners();

      if (connectivityInterrupted) {
        break;
      }
    }

    _status = connectivityInterrupted
        ? ConnectionStatus.disconnected
        : ConnectionStatus.connected;
    if (connectivityInterrupted) {
      _lastError = null;
    }
    _lastSync = DateTime.now();
    _pendingCount = 0;
    notifyListeners();

    return SyncResult(
      sent: sent,
      failed: failed,
      message: connectivityInterrupted
          ? (sent == 0
              ? 'Sin conexión: las planillas quedaron pendientes'
              : 'Conexión interrumpida: $sent enviadas, resto pendiente')
          : failed == 0
              ? 'Sincronización completada ($sent planillas)'
              : '$sent enviadas, $failed con error',
    );
  }

  // ===========================================================================
  // REINTENTO INDIVIDUAL
  // ===========================================================================

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

  void _injectSenderMetadata(Planilla planilla, Map<String, dynamic> body) {
    final metadata = _resolveSenderMetadata(planilla);
    body['technician_id'] = metadata.technicianId;
    body['device_id'] = metadata.deviceId;
    if (metadata.technicianName != null) {
      body['technician_name'] = metadata.technicianName;
    }
  }

  _SenderMetadata _resolveSenderMetadata(Planilla planilla) {
    String normalizeString(String? raw, String fallback) {
      final value = raw?.trim();
      if (value == null || value.isEmpty) return fallback;
      if (value == 'unknown-tech' ||
          value == 'unknown-device' ||
          value == 'tecnico' ||
          value == 'unknown') {
        return fallback;
      }
      return value;
    }

    final technicianId = normalizeString(
      planilla.technicianId,
      normalizeString(AppConfig.technicianId, 'unknown-tech'),
    );
    final deviceId = normalizeString(
      planilla.deviceId,
      normalizeString(AppConfig.deviceId, 'unknown-device'),
    );
    final technicianNameRaw = planilla.technicianName?.trim().isNotEmpty == true
        ? planilla.technicianName
        : AppConfig.technicianName;
    final technicianName = technicianNameRaw?.trim();

    return _SenderMetadata(
      technicianId: technicianId,
      deviceId: deviceId,
      technicianName: (technicianName != null && technicianName.isNotEmpty)
          ? technicianName
          : null,
    );
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

  bool _isConnectivityFailure({
    ApiResponse? response,
    String? message,
  }) {
    if (response?.statusCode == null) {
      return true;
    }

    final text = (message ?? response?.error ?? '').toLowerCase();
    if (text.isEmpty) {
      return false;
    }

    return text.contains('socketexception') ||
        text.contains('network is unreachable') ||
        text.contains('failed host lookup') ||
        text.contains('connection failed') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('timed out') ||
        text.contains('clientexception');
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
      final currentParameter = (entry['parameter'] as String?)?.trim();
      final currentUnit = (entry['unit'] as String?)?.trim();

      final parameter = inst.ingestaParameter ?? inst.defaultParameter;
      if ((currentParameter == null || currentParameter.isEmpty) &&
          parameter.isNotEmpty) {
        entry['parameter'] = parameter;
      }

      final unit =
          inst.ingestaParameter != null ? inst.ingestaUnit : inst.defaultUnit;
      if (currentUnit == null || currentUnit.isEmpty) {
        if (unit == null || unit.trim().isEmpty) {
          entry.remove('unit');
        } else {
          entry['unit'] = unit;
        }
      }
    }

    if (missing.isNotEmpty) {
      final list = missing.toList()..sort();
      debugPrint(
        'SyncService: instrumentos no encontrados en catÃ¡logo (se envÃ­an igual): '
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
  // ===========================================================================
  // MANUAL IMPORT LOGIC (Alignment)
  // ===========================================================================

  bool _isManualPlanilla(TipoPlanilla tipo) {
    return tipo == TipoPlanilla.casagrande ||
        tipo == TipoPlanilla.freatimetros ||
        tipo == TipoPlanilla.aforadores ||
        tipo == TipoPlanilla.drenes;
  }

  /// Sends payload to /api/v1/operaciones/planillas/confirm
  /// Format:
  /// {
  ///   "lote_uuid": "...",
  ///   "familia_id": "...",
  ///   "archivo_origen": "...",
  ///   "rows": [
  ///      { "fecha": "...", "CODE1": val, "CODE2": val }
  ///   ]
  /// }
  Future<bool> _sendManualPlanilla(Planilla planilla) async {
    _lastWasConnectivityIssue = false;
    final rows = _buildManualRows(planilla);
    if (rows.isEmpty) {
      _lastError = 'Planilla manual sin lecturas vÃ¡lidas';
      _lastWasConnectivityIssue = false;
      planilla.errorMessage = _lastError;
      return false;
    }

    final familiaId = _mapTipoToFamiliaId(planilla.tipo);
    final archivoOrigen =
        'app_${planilla.batchUuid}_${DateTime.now().millisecondsSinceEpoch}.json';
    final metadata = _resolveSenderMetadata(planilla);

    final payload = {
      'lote_uuid': planilla.batchUuid,
      'familia_id': familiaId,
      'archivo_origen': archivoOrigen,
      'planilla_nombre': planilla.tipo.codigo,
      'technician_id': metadata.technicianId,
      'device_id': metadata.deviceId,
      if (metadata.technicianName != null)
        'technician_name': metadata.technicianName,
      'rows': rows,
    };

    debugPrint(
        'SyncService._sendManualPlanilla: Sending to operations/confirm...');

    final response = await _api.post(
      '/api/v1/operaciones/planillas/confirm',
      headers: {
        'X-Request-ID': planilla.batchUuid,
      },
      body: payload,
    );

    final responseBody = _stringifyResponse(response.data);
    debugPrint('SyncService response: $responseBody');

    if (response.isSuccess) {
      _lastWasConnectivityIssue = false;
      return true;
    } else {
      final errorMsg = _buildPlanillaError(
        planilla: planilla,
        response: response,
        responseBody: responseBody,
        extra: 'Manual Flow Error',
      );
      _lastError = errorMsg;
      _lastWasConnectivityIssue =
          _isConnectivityFailure(response: response, message: errorMsg);
      if (!_lastWasConnectivityIssue) {
        planilla.errorMessage = errorMsg;
      }
      return false;
    }
  }

  List<Map<String, dynamic>> _buildManualRows(Planilla planilla) {
    // Group by timestamp (ISO string usually sufficient equality check if consistent)
    final grouped = <String, Map<String, dynamic>>{};

    for (final lectura in planilla.lecturas) {
      final ts = lectura.measuredAt.toIso8601String();
      if (!grouped.containsKey(ts)) {
        grouped[ts] = {'fecha': ts};
      }

      // Add Value
      // Backend expects "CODE": value.
      // Lectura model stores value as double.
      grouped[ts]![lectura.instrumentCode] = lectura.value;
    }

    final rows = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return rows.map((entry) => entry.value).toList();
  }

  String _mapTipoToFamiliaId(TipoPlanilla tipo) {
    switch (tipo) {
      case TipoPlanilla.casagrande:
        return 'piezometros_casagrande';
      case TipoPlanilla.freatimetros:
        return 'freatimetros';
      case TipoPlanilla.aforadores:
        return 'aforadores';
      case TipoPlanilla.drenes:
        return 'drenes';
      case TipoPlanilla.triaxiales:
        return 'triaxiales';
      default:
        // Fallback for generic manual if any
        return 'general_app';
    }
  }

  Future<List<RejectedPlanillaNotice>> refreshRemoteStatuses(
    PlanillaRepository repository,
  ) async {
    final tracked = repository
        .all()
        .where(
          (p) =>
              p.estado == PlanillaEstado.enviada ||
              p.estado == PlanillaEstado.rechazada,
        )
        .toList();

    if (tracked.isEmpty) {
      return <RejectedPlanillaNotice>[];
    }

    final notices = <RejectedPlanillaNotice>[];

    for (final planilla in tracked) {
      final wasRejected = planilla.estado == PlanillaEstado.rechazada;
      try {
        final response =
            await _api.get('/api/v1/ingesta/planillas/${planilla.batchUuid}');
        if (response.statusCode == 404) {
          continue;
        }
        if (!response.isSuccess || response.data is! Map) {
          continue;
        }

        final payload = _toSafeMap(response.data as Map);
        final estado =
            (payload['estado'] ?? '').toString().trim().toLowerCase();
        final rechazadas = _toInt(payload['rechazadas']);
        final motivos = _extractRejectionReasons(payload);
        final motivoPrincipal = payload['motivo_principal']?.toString().trim();

        final isRejected =
            estado == 'rechazado' || (estado == 'parcial' && rechazadas > 0);

        if (isRejected) {
          final message = _buildRejectedMessage(
            motivos: motivos,
            motivoPrincipal: motivoPrincipal,
          );
          planilla.marcarRechazada(message);
          await repository.save(planilla);
          if (!wasRejected) {
            notices.add(
              RejectedPlanillaNotice(
                batchUuid: planilla.batchUuid,
                motivoPrincipal: motivoPrincipal,
                motivos: motivos,
              ),
            );
          }
          continue;
        }

        if (estado == 'aprobado' &&
            planilla.estado == PlanillaEstado.rechazada) {
          planilla.marcarEnviada();
          await repository.save(planilla);
        }
      } catch (e) {
        debugPrint(
          'SyncService.refreshRemoteStatuses: error lote=${planilla.batchUuid}: $e',
        );
      }
    }

    return notices;
  }

  String _buildRejectedMessage({
    required List<String> motivos,
    required String? motivoPrincipal,
  }) {
    if (motivos.isEmpty &&
        (motivoPrincipal == null || motivoPrincipal.isEmpty)) {
      return 'Planilla rechazada por consola.';
    }

    final listed = motivos.isNotEmpty ? motivos : <String>[motivoPrincipal!];
    if (listed.length == 1) {
      return 'Planilla rechazada: ${listed.first}.';
    }
    return 'Planilla rechazada: ${listed.take(3).join(' | ')}.';
  }

  List<String> _extractRejectionReasons(Map<String, dynamic> payload) {
    final reasons = <String>[];
    final rawReasons = payload['motivos_rechazo'];
    if (rawReasons is List) {
      for (final item in rawReasons) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty && !reasons.contains(text)) {
          reasons.add(text);
        }
      }
    }

    final principal = payload['motivo_principal']?.toString().trim() ?? '';
    if (principal.isNotEmpty && !reasons.contains(principal)) {
      reasons.insert(0, principal);
    }
    return reasons;
  }

  int _toInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is double) return raw.round();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _toSafeMap(Map raw) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<Map<String, dynamic>> retrySingle(
    String batchUuid, {
    required PlanillaRepository repository,
    CatalogRepository? catalog,
  }) async {
    final planilla = repository.get(batchUuid);
    if (planilla == null) {
      return {'success': false, 'error': 'Planilla no encontrada'};
    }

    planilla.marcarEnviando();
    await repository.save(planilla);

    final success = await sendPlanilla(planilla, catalog: catalog);

    if (success) {
      planilla.marcarEnviada();
      await repository.save(planilla);
      return {'success': true};
    } else {
      if (_lastWasConnectivityIssue) {
        planilla.marcarPendiente();
        await repository.save(planilla);
        return {
          'success': false,
          'queued_offline': true,
          'planilla': planilla,
        };
      }

      planilla.marcarError(_lastError ?? 'Error desconocido');
      await repository.save(planilla);

      return {'success': false, 'error': _lastError, 'planilla': planilla};
    }
  }
}

class _SenderMetadata {
  final String technicianId;
  final String deviceId;
  final String? technicianName;

  const _SenderMetadata({
    required this.technicianId,
    required this.deviceId,
    required this.technicianName,
  });
}
