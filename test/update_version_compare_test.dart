import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cemppsa_field_app/services/update_service.dart';
import 'package:cemppsa_field_app/services/version_compare.dart';

void main() {
  group('parseBuildNumber', () {
    test('acepta int, num y String numérico', () {
      expect(parseBuildNumber(3), 3);
      expect(parseBuildNumber(3.0), 3);
      expect(parseBuildNumber('3'), 3);
      expect(parseBuildNumber(' 12 '), 12);
    });

    test('ausente, ilegible o negativo vale 0 sin lanzar', () {
      expect(parseBuildNumber(null), 0);
      expect(parseBuildNumber(''), 0);
      expect(parseBuildNumber('abc'), 0);
      expect(parseBuildNumber('3a'), 0);
      expect(parseBuildNumber(-4), 0);
      expect(parseBuildNumber('-4'), 0);
      expect(parseBuildNumber(double.nan), 0);
      expect(parseBuildNumber(true), 0);
    });
  });

  group('isRemoteNewer', () {
    test('versión remota mayor: ofrece aunque el build remoto sea menor', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.2.0',
          remoteBuild: 1,
          localVersion: '1.1.0',
          localBuild: '9',
        ),
        isTrue,
      );
    });

    test('compara componentes como números, no como texto', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.10.0',
          remoteBuild: 1,
          localVersion: '1.9.0',
          localBuild: '1',
        ),
        isTrue,
      );
    });

    test('misma versión y build remoto mayor: ofrece', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 3,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isTrue,
      );
    });

    test('misma versión y mismo build: no ofrece', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 2,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });

    test('misma versión y build remoto menor: no ofrece', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 1,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });

    test('versión remota menor y build mayor: no ofrece', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.0.9',
          remoteBuild: 99,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });

    test('build remoto ausente (version.json viejo): igual que antes', () {
      // Misma versión: no ofrece, como hacía el comparador viejo.
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: null,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
      // Versión mayor: ofrece, como hacía el comparador viejo.
      expect(
        isRemoteNewer(
          remoteVersion: '1.2.0',
          remoteBuild: null,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isTrue,
      );
    });

    test('build remoto ilegible vale 0', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 'x',
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });

    test('build local ilegible vale 0 y no rompe', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 3,
          localVersion: '1.1.0',
          localBuild: 'no-numero',
        ),
        isTrue,
      );
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0',
          remoteBuild: 0,
          localVersion: '1.1.0',
          localBuild: '',
        ),
        isFalse,
      );
    });

    test('sin build_number, usa el +N de la versión remota si lo trae', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0+3',
          remoteBuild: null,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isTrue,
      );
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0+2',
          remoteBuild: null,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });

    test('build_number explícito tiene prioridad sobre el +N', () {
      expect(
        isRemoteNewer(
          remoteVersion: '1.1.0+9',
          remoteBuild: 2,
          localVersion: '1.1.0',
          localBuild: '2',
        ),
        isFalse,
      );
    });
  });

  group('isBelowMinimum', () {
    test('min_version sin build: solo cuenta X.Y.Z (comportamiento previo)',
        () {
      expect(
        isBelowMinimum(
            minVersion: '1.1.0', localVersion: '1.0.9', localBuild: '50'),
        isTrue,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.1.0', localVersion: '1.1.0', localBuild: '1'),
        isFalse,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.1.0', localVersion: '1.1.0', localBuild: 'x'),
        isFalse,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.0.0', localVersion: '1.1.0', localBuild: '2'),
        isFalse,
      );
    });

    test('min_version con +N: exige ese build en la misma versión', () {
      expect(
        isBelowMinimum(
            minVersion: '1.1.0+3', localVersion: '1.1.0', localBuild: '2'),
        isTrue,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.1.0+3', localVersion: '1.1.0', localBuild: '3'),
        isFalse,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.1.0+3', localVersion: '1.2.0', localBuild: '1'),
        isFalse,
      );
      expect(
        isBelowMinimum(
            minVersion: '1.1.0+3', localVersion: '1.1.0', localBuild: 'x'),
        isTrue,
      );
    });
  });

  group('AppVersion.fromJson', () {
    test('version.json viejo sin build_number no rompe', () {
      final remote = AppVersion.fromJson({
        'version': '1.1.0',
        'apk_url': 'https://example.invalid/app.apk',
        'min_version': '1.0.0',
      });
      expect(remote.buildNumber, 0);
    });

    test('build_number como String o int', () {
      expect(AppVersion.fromJson({'build_number': '4'}).buildNumber, 4);
      expect(AppVersion.fromJson({'build_number': 4}).buildNumber, 4);
      expect(AppVersion.fromJson({'build_number': 'x'}).buildNumber, 0);
    });
  });

  group('UpdateService con PackageInfo', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    void mockLocal(String version, String build) {
      PackageInfo.setMockInitialValues(
        appName: 'EDISON',
        packageName: 'com.example.cemppsa_field_app',
        version: version,
        buildNumber: build,
        buildSignature: '',
      );
    }

    AppVersion remote(String version, Object? build,
            {String minVersion = '1.0.0', bool force = false}) =>
        AppVersion.fromJson({
          'version': version,
          'build_number': build,
          'apk_url': 'https://example.invalid/app.apk',
          'min_version': minVersion,
          'force_update': force,
        });

    test('1.1.0+3 publicado sobre un teléfono 1.1.0+2 se ofrece', () async {
      mockLocal('1.1.0', '2');
      expect(await UpdateService.isUpdateAvailable(remote('1.1.0', 3)), isTrue);
      expect(await UpdateService.isForceRequired(remote('1.1.0', 3)), isFalse);
    });

    test('mismo build no se ofrece', () async {
      mockLocal('1.1.0', '2');
      expect(
          await UpdateService.isUpdateAvailable(remote('1.1.0', 2)), isFalse);
    });

    test('force_update y min_version siguen forzando', () async {
      mockLocal('1.1.0', '2');
      expect(
        await UpdateService.isForceRequired(remote('1.1.0', 3, force: true)),
        isTrue,
      );
      expect(
        await UpdateService.isForceRequired(
            remote('1.2.0', 1, minVersion: '1.2.0')),
        isTrue,
      );
    });
  });
}
