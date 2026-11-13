// ==============================================================================
// CEMPPSA Field App - UpdateService
// Servicio de actualización OTA (descarga e instalación de APK)
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../core/config.dart';
import 'version_compare.dart';

// ==============================================================================
// Modelo de versión remota
// ==============================================================================

class AppVersion {
  final String version;
  final int buildNumber;
  final String apkUrl;
  final String changelog;
  final bool forceUpdate;
  final String minVersion;
  final String? sha256;
  final String? releasedAt;

  AppVersion({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
    required this.minVersion,
    this.sha256,
    this.releasedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      version: json['version'] ?? '0.0.0',
      buildNumber: parseBuildNumber(json['build_number']),
      apkUrl: json['apk_url'] ?? '',
      changelog: json['changelog'] ?? '',
      forceUpdate: json['force_update'] ?? false,
      minVersion: json['min_version'] ?? '0.0.0',
      sha256: json['sha256'],
      releasedAt: json['released_at'],
    );
  }
}

// ==============================================================================
// UpdateService
// ==============================================================================

class UpdateService {
  /// Consulta el servidor por la versión disponible
  static Future<AppVersion?> checkForUpdate() async {
    try {
      final url = '${ApiConfig.baseUrl}${ApiConfig.appVersionEndpoint}';
      debugPrint('UpdateService: Consultando $url');
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('UpdateService: Versión remota=${data['version']}');
        return AppVersion.fromJson(data);
      }
      debugPrint('UpdateService: Respuesta ${response.statusCode}');
    } catch (e) {
      debugPrint('UpdateService: Error al verificar actualización: $e');
    }
    return null;
  }

  /// Retorna true si hay una actualización disponible: versión remota mayor,
  /// o misma versión con build remoto mayor (ver [isRemoteNewer]).
  static Future<bool> isUpdateAvailable(AppVersion remote) async {
    final info = await PackageInfo.fromPlatform();
    debugPrint('UpdateService: Local=${info.version}+${info.buildNumber} '
        'Remote=${remote.version}+${remote.buildNumber}');
    return isRemoteNewer(
      remoteVersion: remote.version,
      remoteBuild: remote.buildNumber,
      localVersion: info.version,
      localBuild: info.buildNumber,
    );
  }

  /// Retorna true si la actualización es obligatoria: `force_update`, o la
  /// app instalada está por debajo de `min_version` (ver [isBelowMinimum]).
  static Future<bool> isForceRequired(AppVersion remote) async {
    if (remote.forceUpdate) return true;
    final info = await PackageInfo.fromPlatform();
    return isBelowMinimum(
      minVersion: remote.minVersion,
      localVersion: info.version,
      localBuild: info.buildNumber,
    );
  }

  /// Descarga el APK, verifica SHA256 si disponible, y lo abre para instalar
  static Future<void> downloadAndInstall(
    AppVersion remote, {
    void Function(double progress)? onProgress,
  }) async {
    final apkUrl = remote.apkUrl;
    debugPrint('UpdateService: Descargando APK desde $apkUrl');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Error descargando APK: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cemppsa_update.apk');
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(received / contentLength);
        }
      }
      await sink.close();

      debugPrint('UpdateService: APK descargado (${file.lengthSync()} bytes)');

      // Verificar SHA256 si el servidor lo proporcionó
      if (remote.sha256 != null && remote.sha256!.isNotEmpty) {
        debugPrint('UpdateService: Verificando SHA256...');
        final fileBytes = await file.readAsBytes();
        final digest = sha256.convert(fileBytes);
        final localHash = digest.toString();

        if (localHash != remote.sha256) {
          await file.delete();
          throw Exception(
            'Verificación SHA256 falló.\n'
            'Esperado: ${remote.sha256}\n'
            'Obtenido: $localHash',
          );
        }
        debugPrint('UpdateService: SHA256 verificado ✓');
      }

      // Abrir APK para instalación
      final result = await OpenFilex.open(file.path);
      debugPrint('UpdateService: OpenFilex result: ${result.message}');
    } finally {
      client.close();
    }
  }
}
