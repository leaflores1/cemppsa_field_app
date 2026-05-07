import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
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
    await server.close(force: true);
  });

  String baseUrl() => 'http://${server.address.address}:${server.port}';

  void serve(FutureOr<void> Function(HttpRequest request) handler) {
    unawaited(() async {
      await for (final request in server) {
        await handler(request);
      }
    }());
  }

  Future<void> writeJson(
    HttpRequest request,
    int statusCode,
    Map<String, dynamic> body,
  ) async {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
    await request.response.close();
  }

  test('renews token and retries when backend returns 403 invalid credentials',
      () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final authHeaders = <String?>[];

    serve((request) async {
      expect(request.uri.path, '/api/v1/operaciones/planillas/confirm');
      protectedCalls++;
      authHeaders.add(request.headers.value(HttpHeaders.authorizationHeader));

      if (protectedCalls == 1) {
        await writeJson(
          request,
          403,
          {'detail': 'Could not validate credentials'},
        );
        return;
      }

      await writeJson(request, 201, {'status': 'accepted'});
    });

    ApiConfig.authToken = 'old-token';
    ApiConfig.refreshAuthToken = () async {
      refreshCalls++;
      ApiConfig.authToken = 'new-token';
      return true;
    };

    final client = ApiClient(baseUrl: baseUrl());
    final response = await client.post(
      '/api/v1/operaciones/planillas/confirm',
      body: {'lote_uuid': 'batch-1'},
    );

    expect(response.statusCode, 201);
    expect(response.isSuccess, isTrue);
    expect(protectedCalls, 2);
    expect(refreshCalls, 1);
    expect(authHeaders, ['Bearer old-token', 'Bearer new-token']);
  });

  test('does not refresh permission 403 responses', () async {
    var refreshCalls = 0;

    serve((request) async {
      await writeJson(
        request,
        403,
        {'detail': 'User is not enabled for mobile platform.'},
      );
    });

    ApiConfig.authToken = 'valid-token-without-mobile-platform';
    ApiConfig.refreshAuthToken = () async {
      refreshCalls++;
      return true;
    };

    final client = ApiClient(baseUrl: baseUrl());
    final response = await client.post(
      '/api/v1/operaciones/planillas/confirm',
      body: {'lote_uuid': 'batch-1'},
    );

    expect(response.statusCode, 403);
    expect(response.isSuccess, isFalse);
    expect(refreshCalls, 0);
  });

  test('clears session when refresh fails after invalid credentials', () async {
    var expiredHandlerCalls = 0;

    serve((request) async {
      await writeJson(
        request,
        403,
        {'detail': 'Could not validate credentials'},
      );
    });

    ApiConfig.authToken = 'expired-token';
    ApiConfig.refreshAuthToken = () async => false;
    ApiConfig.handleSessionExpired = () async {
      expiredHandlerCalls++;
    };

    final client = ApiClient(baseUrl: baseUrl());
    final response = await client.post(
      '/api/v1/operaciones/planillas/confirm',
      body: {'lote_uuid': 'batch-1'},
    );

    expect(response.statusCode, 403);
    expect(response.error, ApiClient.sessionExpiredMessage);
    expect(expiredHandlerCalls, 1);
  });
}
