import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:cemppsa_field_app/core/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la version visible sale de PackageInfo (pubspec.yaml)', () async {
    PackageInfo.setMockInitialValues(
      appName: 'EDISON',
      packageName: 'com.example.cemppsa_field_app',
      version: '1.1.0',
      buildNumber: '2',
      buildSignature: '',
    );

    await AppVersionInfo.load();

    expect(AppVersionInfo.label, '1.1.0+2');
    expect(AppVersionInfo.displayLabel, 'v1.1.0+2');
  });
}
