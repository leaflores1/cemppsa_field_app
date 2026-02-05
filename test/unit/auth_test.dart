import 'package:flutter_test/flutter_test.dart';
import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/repositories/auth_repository.dart';
import 'package:cemppsa_field_app/core/storage/secure_storage_service.dart';
import 'package:cemppsa_field_app/core/config.dart';

class MockStorage extends SecureStorageService {
  // Override methods to avoid platform channel calls
  @override
  Future<void> saveRefreshToken(String token) async {}
  @override
  Future<String?> getRefreshToken() async => null;
}

class MockApiClient extends ApiClient {
  MockApiClient() : super(baseUrl: 'http://test', storage: MockStorage());

  @override
  Future<ApiResponse> post(String path, {Map<String, String>? headers, Map<String, dynamic>? body}) async {
     if (path == ApiConfig.loginEndpoint) {
       if (body?['email'] == 'test@test.com' && body?['password'] == '123456') {
         return ApiResponse(statusCode: 200, data: {
           'access_token': 'fake_access',
           'refresh_token': 'fake_refresh',
           'user': {'id': '1', 'email': 'test@test.com', 'full_name': 'Test User', 'role': 'user'}
         });
       }
       return ApiResponse.error('Credenciales inválidas', statusCode: 401);
     }
     return ApiResponse.error('Not found', statusCode: 404);
  }
}

void main() {
  test('AuthRepository login success', () async {
    final api = MockApiClient();
    final repo = AuthRepository(api);

    final response = await repo.login('test@test.com', '123456');

    expect(response.accessToken, 'fake_access');
    expect(response.user.email, 'test@test.com');
    expect(response.user.role.name, 'user');
  });

  test('AuthRepository login failure', () async {
    final api = MockApiClient();
    final repo = AuthRepository(api);

    expect(() => repo.login('wrong', 'wrong'), throwsException);
  });
}
