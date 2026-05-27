import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';
import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/repositories/planilla_repository.dart';
import 'package:cemppsa_field_app/services/sync_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cemppsa_sync_test_');
    Hive.init(tempDir.path);
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

  test('sin conexion deja la planilla pendiente para reintento', () async {
    final repository = PlanillaRepository();
    await repository.init();

    final planilla = Planilla(
      tipo: TipoPlanilla.freatimetros,
      deviceId: 'android-test',
      technicianId: 'tech-test',
      lecturas: [
        Lectura.fromForm(
          clientRowId: 1,
          instrumentCode: 'PP1',
          parameter: 'PROFUNDIDAD_M',
          unit: 'm',
          rawValue: '2.45',
          measuredAt: DateTime.utc(2026, 5, 20, 9),
        ),
      ],
    )..marcarPendiente();
    await repository.save(planilla);

    final syncService = SyncService(
      apiClient: ApiClient(
        baseUrl: 'http://127.0.0.1:1',
        timeout: const Duration(milliseconds: 250),
      ),
    );

    final result = await syncService.retrySingle(
      planilla.batchUuid,
      repository: repository,
    );

    final stored = repository.get(planilla.batchUuid);
    expect(result['success'], isFalse);
    expect(result['queued_offline'], isTrue);
    expect(stored?.estado, PlanillaEstado.pendiente);
    expect(stored?.totalLecturas, 1);
  });
}
