import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/services/sync_service.dart';

void main() {
  test('CR10X incluye observacion no vacia en el payload legacy', () {
    final planilla = Planilla(
      tipo: TipoPlanilla.cr10xPiezometros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      observaciones: '  Acceso con lluvia.  ',
    );

    expect(planilla.toSyncRequest()['observacion'], 'Acceso con lluvia.');

    planilla.observaciones = '   ';
    expect(planilla.toSyncRequest().containsKey('observacion'), isFalse);
  });

  test('planilla manual envia observacion al endpoint de operaciones',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final receivedBody = Completer<Map<String, dynamic>>();

    unawaited(() async {
      final request = await server.first;
      receivedBody.complete(
        jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>,
      );
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ok'}));
      await request.response.close();
    }());

    final planilla = Planilla(
      tipo: TipoPlanilla.freatimetros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      observaciones: '  Terreno anegado.  ',
      lecturas: [
        Lectura.fromForm(
          clientRowId: 1,
          instrumentCode: 'PP1',
          parameter: 'PROFUNDIDAD_M',
          unit: 'm',
          rawValue: '2.45',
          measuredAt: DateTime.utc(2026, 6, 22, 10),
        ),
      ],
    );
    final syncService = SyncService(
      apiClient: ApiClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      ),
    );

    expect(await syncService.sendPlanilla(planilla), isTrue);
    expect((await receivedBody.future)['observacion'], 'Terreno anegado.');

    await server.close(force: true);
  });
}
