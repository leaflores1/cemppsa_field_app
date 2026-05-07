import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';
import 'package:cemppsa_field_app/repositories/catalogo_repository.dart';
import 'package:cemppsa_field_app/repositories/planilla_repository.dart';
import 'package:cemppsa_field_app/services/auth_service.dart';
import 'package:cemppsa_field_app/services/sync_service.dart';
import 'package:cemppsa_field_app/ui/screens/settings_screen.dart';

void main() {
  tearDown(() {
    ApiConfig.resetBaseUrlToDefault();
  });

  Widget buildScreen() {
    final apiClient = ApiClient(baseUrl: ApiConfig.defaultBaseUrl);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
          value: AuthService(apiClient: apiClient),
        ),
        ChangeNotifierProvider<SyncService>.value(
          value: SyncService(apiClient: apiClient),
        ),
        ChangeNotifierProvider<CatalogRepository>.value(
          value: CatalogRepository(baseUrl: ApiConfig.defaultBaseUrl),
        ),
        ChangeNotifierProvider<PlanillaRepository>.value(
          value: PlanillaRepository(),
        ),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('server controls are hidden until diagnostic PIN is entered',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('URL del servidor'), findsNothing);
    expect(find.textContaining('Buscar servidor'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Version'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Version'));
    await tester.pumpAndSettle();

    expect(find.text('PIN de soporte'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField).last, ApiConfig.diagnosticPin);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('URL del servidor'),
      -500,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('URL del servidor'), findsOneWidget);
    expect(find.textContaining('Buscar servidor'), findsOneWidget);
  });
}
