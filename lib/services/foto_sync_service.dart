import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../data/models/foto_inspeccion.dart';
import '../repositories/foto_repository.dart';

class FotoSyncService extends ChangeNotifier {
  final FotoRepository _repository;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySub;

  bool _isSyncing = false;
  bool _isOnline = false;
  String? _lastError;
  DateTime? _lastSyncAt;

  FotoSyncService({required FotoRepository repository})
      : _repository = repository {
    _initConnectivity();
  }

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;

  int get pendingCount => _repository.totalPendientes;

  Future<void> _initConnectivity() async {
    _isOnline = await _checkOnline();
    _connectivitySub =
        _connectivity.onConnectivityChanged.listen((result) async {
      final nowOnline = _isConnectedResult(result);
      _isOnline = nowOnline;
      notifyListeners();

      if (nowOnline && !_isSyncing) {
        await syncPending();
      }
    });
    notifyListeners();
  }

  Future<void> disposeService() async {
    await _connectivitySub?.cancel();
  }

  Future<bool> _checkOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnectedResult(result);
  }

  bool _isConnectedResult(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((value) => value != ConnectivityResult.none);
    }
    return false;
  }

  Future<void> syncPending() async {
    if (_isSyncing) return;

    final online = await _checkOnline();
    _isOnline = online;
    if (!online) {
      _lastError = 'Sin conexión';
      notifyListeners();
      return;
    }

    final pendientes = List<FotoInspeccion>.from(_repository.pendientes);
    if (pendientes.isEmpty) {
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    for (final foto in pendientes) {
      await _syncOneInternal(foto);
    }

    _isSyncing = false;
    _lastSyncAt = DateTime.now();
    notifyListeners();
  }

  Future<void> retrySingle(String localId) async {
    final foto = _repository.get(localId);
    if (foto == null) return;
    if (_isSyncing) return;

    final online = await _checkOnline();
    _isOnline = online;
    if (!online) {
      _lastError = 'Sin conexión';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    notifyListeners();
    await _syncOneInternal(foto);
    _isSyncing = false;
    _lastSyncAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _syncOneInternal(FotoInspeccion foto) async {
    final file = File(foto.localPath);
    if (!file.existsSync()) {
      final missing = foto.copyWith(
        status: FotoSyncStatus.error,
        lastError: 'Archivo local no encontrado',
        retries: foto.retries + 1,
        nextRetryAt: DateTime.now().add(const Duration(minutes: 15)),
      );
      await _repository.save(missing);
      _lastError = missing.lastError;
      return;
    }

    await _repository.save(
      foto.copyWith(
        status: FotoSyncStatus.sincronizando,
        lastError: null,
        nextRetryAt: null,
      ),
    );

    try {
      final authed = await _ensureAuthToken();
      if (!authed) {
        final retryCount = foto.retries + 1;
        final waitSeconds = min(1800, 30 * pow(2, min(retryCount, 6)).toInt());
        const message =
            'No se pudo autenticar contra backend para subir fotos (revisá credenciales).';
        await _repository.save(
          foto.copyWith(
            status: FotoSyncStatus.error,
            retries: retryCount,
            nextRetryAt: DateTime.now().add(Duration(seconds: waitSeconds)),
            lastError: message,
          ),
        );
        _lastError = message;
        return;
      }

      final streamed = await _uploadMultipart(foto, file);
      var response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
            'FotoSyncService: token rechazado (${response.statusCode}), renovando...');
        final reauthed = await _ensureAuthToken(force: true);
        if (reauthed) {
          final retryStreamed = await _uploadMultipart(foto, file);
          response = await http.Response.fromStream(retryStreamed);
        } else {
          final onExpired = ApiConfig.handleSessionExpired;
          if (onExpired != null) {
            await onExpired();
          }
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = _decodeBody(response.body);
        final synced = foto.copyWith(
          status: FotoSyncStatus.sincronizada,
          retries: 0,
          nextRetryAt: null,
          lastError: null,
          remoteId: body['id'] is int ? body['id'] as int : null,
          remotePublicUuid: body['public_uuid']?.toString(),
        );
        await _repository.save(synced);
        return;
      }

      if (response.statusCode == 409) {
        final body = _decodeBody(response.body);
        int? existingId;
        final detail = body['detail'];
        if (detail is Map && detail['existing_id'] is int) {
          existingId = detail['existing_id'] as int;
        }

        await _repository.save(
          foto.copyWith(
            status: FotoSyncStatus.sincronizada,
            retries: 0,
            nextRetryAt: null,
            lastError: null,
            remoteId: existingId,
          ),
        );
        return;
      }

      final retryCount = foto.retries + 1;
      final waitSeconds = min(3600, 30 * pow(2, min(retryCount, 7)).toInt());
      final errorMessage = _extractErrorMessage(response.body) ??
          'Error HTTP ${response.statusCode} en sincronización de foto';

      await _repository.save(
        foto.copyWith(
          status: FotoSyncStatus.error,
          retries: retryCount,
          nextRetryAt: DateTime.now().add(Duration(seconds: waitSeconds)),
          lastError: errorMessage,
        ),
      );
      _lastError = errorMessage;
    } catch (e) {
      final retryCount = foto.retries + 1;
      final waitSeconds = min(3600, 30 * pow(2, min(retryCount, 7)).toInt());
      final message = 'Error de red en foto: $e';
      await _repository.save(
        foto.copyWith(
          status: FotoSyncStatus.error,
          retries: retryCount,
          nextRetryAt: DateTime.now().add(Duration(seconds: waitSeconds)),
          lastError: message,
        ),
      );
      _lastError = message;
    }
  }

  Future<http.StreamedResponse> _uploadMultipart(
    FotoInspeccion foto,
    File file,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.fotosEndpoint}');
    final request = http.MultipartRequest('POST', uri);

    request.fields['mes_operativo'] = foto.mesOperativo;
    request.fields['taken_at'] = foto.takenAt.toUtc().toIso8601String();
    if (foto.loteUuid != null && foto.loteUuid!.trim().isNotEmpty) {
      request.fields['lote_uuid'] = foto.loteUuid!.trim();
    }
    if (foto.eventoCodigo != null && foto.eventoCodigo!.trim().isNotEmpty) {
      request.fields['evento_codigo'] = foto.eventoCodigo!.trim();
    }
    if (foto.eventoNombre != null && foto.eventoNombre!.trim().isNotEmpty) {
      request.fields['evento_nombre'] = foto.eventoNombre!.trim();
    }
    if (foto.ubicacion != null && foto.ubicacion!.trim().isNotEmpty) {
      request.fields['ubicacion'] = foto.ubicacion!.trim();
    }
    if (foto.comentario != null && foto.comentario!.trim().isNotEmpty) {
      request.fields['comentario'] = foto.comentario!.trim();
    }
    request.fields['meta_json'] = jsonEncode({
      'source': 'mobile_app',
      'local_id': foto.localId,
    });

    if (ApiConfig.authToken != null && ApiConfig.authToken!.trim().isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer ${ApiConfig.authToken!.trim()}';
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'foto.jpg',
      ),
    );

    return request.send().timeout(const Duration(seconds: 45));
  }

  Future<bool> _ensureAuthToken({bool force = false}) async {
    final existing = ApiConfig.authToken?.trim();
    if (!force && existing != null && existing.isNotEmpty) {
      return true;
    }

    final refreshFn = ApiConfig.refreshAuthToken;
    if (refreshFn != null) {
      final refreshed = await refreshFn();
      final renewed = ApiConfig.authToken?.trim();
      if (refreshed && renewed != null && renewed.isNotEmpty) {
        return true;
      }
    }

    debugPrint(
      'FotoSyncService: no hay token de sesion. Requiere login en la app.',
    );
    return false;
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  String? _extractErrorMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
      return body;
    } catch (_) {
      return body;
    }
  }
}
