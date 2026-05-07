import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/core/config.dart';

void main() {
  tearDown(() {
    ApiConfig.resetBaseUrlToDefault();
  });

  test('production build default points to CEMPPSA LAN backend', () {
    expect(ApiConfig.productionBaseUrl, 'http://192.168.111.112');
    expect(ApiConfig.defaultBaseUrl, ApiConfig.productionBaseUrl);

    ApiConfig.resetBaseUrlToDefault();

    expect(ApiConfig.baseUrl, 'http://192.168.111.112');
    expect(ApiConfig.hasConfiguredBaseUrl, isTrue);
  });

  test('normalizes user-entered base URLs without appending api prefix', () {
    expect(
      ApiConfig.normalizeBaseUrl('192.168.111.112/'),
      'http://192.168.111.112',
    );
    expect(
      ApiConfig.normalizeBaseUrl('http://192.168.111.112:80/'),
      'http://192.168.111.112:80',
    );
  });

  test('replaces only known development and legacy persisted URLs', () {
    expect(ApiConfig.shouldReplacePersistedBaseUrl('http://127.0.0.1:8000'),
        isTrue);
    expect(ApiConfig.shouldReplacePersistedBaseUrl('http://localhost:8000'),
        isTrue);
    expect(
      ApiConfig.shouldReplacePersistedBaseUrl('http://192.168.113.121:8000'),
      isTrue,
    );
    expect(
      ApiConfig.shouldReplacePersistedBaseUrl('http://192.168.111.112'),
      isFalse,
    );
  });
}
