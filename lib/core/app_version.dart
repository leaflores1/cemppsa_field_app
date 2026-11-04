import 'package:package_info_plus/package_info_plus.dart';

/// Versión instalada de la app.
///
/// Única fuente de verdad: el campo `version:` de `pubspec.yaml`
/// (formato `X.Y.Z+build`), que Flutter embebe en el APK y que también usa
/// `UpdateService` para comparar contra `version.json` del servidor.
/// No hardcodear la versión en ningún otro lugar.
class AppVersionInfo {
  static String _version = '';
  static String _buildNumber = '';

  /// Ej.: `1.1.0+2`. Vacío si todavía no se cargó.
  static String get label =>
      _version.isEmpty ? '' : '$_version+$_buildNumber';

  /// Texto para mostrar en pantalla.
  static String get displayLabel => label.isEmpty ? 'desconocida' : 'v$label';

  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _version = '';
      _buildNumber = '';
    }
  }
}
