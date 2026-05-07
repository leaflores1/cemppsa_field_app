import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';
import 'package:cemppsa_field_app/services/auth_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cemppsa_auth_test_');
    Hive.init(tempDir.path);
    AppConfig.deviceId = 'android_test_device';
    ApiConfig.authToken = null;
    ApiConfig.refreshToken = null;
    ApiConfig.refreshAuthToken = null;
    ApiConfig.handleSessionExpired = null;
  });

  tearDown(() async {
    ApiConfig.authToken = null;
    ApiConfig.refreshToken = null;
    ApiConfig.refreshAuthToken = null;
    ApiConfig.handleSessionExpired = null;
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('primer login sin red y sin cache exige conexion inicial', () async {
    final auth = AuthService(
      apiClient: ApiClient(
        baseUrl: 'http://127.0.0.1:1',
        timeout: const Duration(milliseconds: 300),
      ),
      hasNoNetworkConnection: () async => true,
    );
    await auth.init();

    final ok = await auth.login(
      email: 'moviluno@cemppsa.com',
      password: 'valid-password',
    );

    expect(ok, isFalse);
    expect(auth.hasStoredSession, isFalse);
    expect(
      auth.lastError,
      'Necesitas conectarte al servidor al menos una vez para habilitar este usuario en el dispositivo.',
    );
  });

  test('login online habilita login offline posterior en el dispositivo',
      () async {
    final server = await _AuthTestServer.start();
    addTearDown(server.close);
    var noNetwork = false;

    final auth = AuthService(
      apiClient: ApiClient(
        baseUrl: server.baseUrl,
        timeout: const Duration(milliseconds: 500),
      ),
      hasNoNetworkConnection: () async => noNetwork,
    );
    await auth.init();

    final onlineOk = await auth.login(
      email: 'moviluno@cemppsa.com',
      password: 'valid-password',
    );
    expect(onlineOk, isTrue);
    expect(auth.isOfflineAuthenticated, isFalse);
    expect(auth.currentSession?.accessToken, 'online-token');

    await auth.logout();
    await server.close();
    noNetwork = true;

    final offlineOk = await auth.login(
      email: 'moviluno@cemppsa.com',
      password: 'valid-password',
    );

    expect(offlineOk, isTrue);
    expect(auth.hasStoredSession, isTrue);
    expect(auth.isOfflineAuthenticated, isTrue);
    expect(auth.lastLoginWasOffline, isTrue);
    expect(auth.currentUser?.id, '11');
    expect(auth.currentSession?.accessToken, isEmpty);
  });

  test('login offline rechaza password incorrecta', () async {
    final server = await _AuthTestServer.start();
    addTearDown(server.close);
    var noNetwork = false;

    final auth = AuthService(
      apiClient: ApiClient(
        baseUrl: server.baseUrl,
        timeout: const Duration(milliseconds: 500),
      ),
      hasNoNetworkConnection: () async => noNetwork,
    );
    await auth.init();

    expect(
      await auth.login(
        email: 'moviluno@cemppsa.com',
        password: 'valid-password',
      ),
      isTrue,
    );

    await auth.logout();
    await server.close();
    noNetwork = true;

    final offlineOk = await auth.login(
      email: 'moviluno@cemppsa.com',
      password: 'wrong-password',
    );

    expect(offlineOk, isFalse);
    expect(auth.hasStoredSession, isFalse);
    expect(auth.lastError, 'Credenciales offline invalidas.');
  });

  test('cierre completo borra autorizacion offline y exige red otra vez',
      () async {
    final server = await _AuthTestServer.start();
    addTearDown(server.close);
    var noNetwork = false;

    final auth = AuthService(
      apiClient: ApiClient(
        baseUrl: server.baseUrl,
        timeout: const Duration(milliseconds: 500),
      ),
      hasNoNetworkConnection: () async => noNetwork,
    );
    await auth.init();

    expect(
      await auth.login(
        email: 'moviluno@cemppsa.com',
        password: 'valid-password',
      ),
      isTrue,
    );

    await auth.logoutCompletely();
    await server.close();
    noNetwork = true;

    final offlineOk = await auth.login(
      email: 'moviluno@cemppsa.com',
      password: 'valid-password',
    );

    expect(offlineOk, isFalse);
    expect(auth.hasStoredSession, isFalse);
    expect(
      auth.lastError,
      'Necesitas conectarte al servidor al menos una vez para habilitar este usuario en el dispositivo.',
    );
  });
}

class _AuthTestServer {
  final HttpServer _server;
  StreamSubscription<HttpRequest>? _subscription;
  bool _closed = false;

  _AuthTestServer._(this._server);

  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  static Future<_AuthTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wrapper = _AuthTestServer._(server);
    wrapper._subscription = server.listen(wrapper._handleRequest);
    return wrapper;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    await _server.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'POST' ||
        request.uri.path != ApiConfig.mobileAuthLoginEndpoint) {
      await _writeJson(request, 404, {'detail': 'not found'});
      return;
    }

    final rawBody = await utf8.decoder.bind(request).join();
    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    if (body['email'] != 'moviluno@cemppsa.com' ||
        body['password'] != 'valid-password') {
      await _writeJson(request, 401, {'detail': 'Invalid credentials'});
      return;
    }

    await _writeJson(request, 200, {
      'access_token': 'online-token',
      'refresh_token': 'refresh-token',
      'token_type': 'bearer',
      'user': {
        'id': '11',
        'email': 'moviluno@cemppsa.com',
        'display_name': 'movil uno',
        'role': 'TECNICO',
        'platform_access': 'APP_MOVIL',
      },
    });
  }

  Future<void> _writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }
}
