import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';
import 'package:cemppsa_field_app/services/auth_service.dart';
import 'package:cemppsa_field_app/ui/screens/login_screen.dart';

void main() {
  tearDown(() {
    ApiConfig.resetBaseUrlToDefault();
  });

  testWidgets('login screen asks only for credentials', (tester) async {
    final authService = AuthService(
      apiClient: ApiClient(baseUrl: ApiConfig.defaultBaseUrl),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: authService,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);

    expect(find.textContaining('Servidor:'), findsNothing);
    expect(find.textContaining('URL o IP'), findsNothing);
    expect(find.textContaining('Autodetectar'), findsNothing);
    expect(find.textContaining('192.168'), findsNothing);
    expect(find.byIcon(Icons.radar), findsNothing);
    expect(find.byIcon(Icons.dns_outlined), findsNothing);
  });
}
