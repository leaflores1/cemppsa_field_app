import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/planilla.dart';

void main() {
  group('Planilla interrupted send recovery', () {
    test('vuelve ENVIANDO a PENDIENTE sin perder trazabilidad de intento', () {
      final planilla = Planilla(
        tipo: TipoPlanilla.casagrande,
        deviceId: 'device-1',
        technicianId: 'tech-1',
      );

      planilla.marcarEnviando();
      final lastAttempt = planilla.lastSyncAttempt;
      final retries = planilla.syncRetries;

      planilla.recoverInterruptedSend();

      expect(planilla.estado, PlanillaEstado.pendiente);
      expect(planilla.lastSyncAttempt, lastAttempt);
      expect(planilla.syncRetries, retries);
    });
  });
}
