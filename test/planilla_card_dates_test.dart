import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/ui/widgets/planilla_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlanillaCard fechas visibles', () {
    testWidgets('muestra medicion y envio desde timestamps reales',
        (tester) async {
      final planilla = _buildPlanilla(
        measuredAt: [DateTime(2026, 6, 11, 8, 15)],
        lastSyncAttempt: DateTime(2026, 6, 17, 9, 32),
      );

      await tester.pumpWidget(_wrap(planilla));

      expect(find.text('Medición:'), findsOneWidget);
      expect(find.text('11 jun 2026'), findsOneWidget);
      expect(find.text('Enviada:'), findsOneWidget);
      expect(find.text('17 jun 2026 · 09:32'), findsOneWidget);
      expect(find.text('Enviada +6 días'), findsOneWidget);
      expect(find.text('Ingreso'), findsNothing);
    });

    testWidgets('muestra rango si el lote tiene mediciones de varios dias',
        (tester) async {
      final planilla = _buildPlanilla(
        measuredAt: [
          DateTime(2026, 6, 11, 8),
          DateTime(2026, 6, 17, 12),
        ],
        lastSyncAttempt: DateTime(2026, 6, 17, 9, 32),
      );

      await tester.pumpWidget(_wrap(planilla));

      expect(find.text('11 jun – 17 jun 2026'), findsOneWidget);
      expect(find.text('Enviada el mismo día'), findsOneWidget);
    });

    testWidgets('usa recibida como fallback si no hay envio especifico',
        (tester) async {
      final planilla = _buildPlanilla(
        measuredAt: [],
        createdAt: DateTime(2026, 6, 17, 9, 32),
      );

      await tester.pumpWidget(_wrap(planilla));

      expect(find.text('sin dato'), findsOneWidget);
      expect(find.text('Recibida:'), findsOneWidget);
      expect(find.text('17 jun 2026 · 09:32'), findsOneWidget);
      expect(find.textContaining('Enviada +'), findsNothing);
    });
  });
}

Widget _wrap(Planilla planilla) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SizedBox(
          width: 420,
          child: PlanillaCard(planilla: planilla),
        ),
      ),
    ),
  );
}

Planilla _buildPlanilla({
  required List<DateTime> measuredAt,
  DateTime? createdAt,
  DateTime? lastSyncAttempt,
}) {
  return Planilla(
    batchUuid: '12345678-1234-1234-1234-1234567890ab',
    tipo: TipoPlanilla.casagrande,
    deviceId: 'device-1',
    technicianId: 'tech-1',
    createdAt: createdAt ?? DateTime(2026, 6, 10, 7),
    estado: PlanillaEstado.enviada,
    lastSyncAttempt: lastSyncAttempt,
    lecturas: [
      for (var i = 0; i < measuredAt.length; i++)
        Lectura(
          clientRowId: i + 1,
          instrumentCode: 'PC${i + 1}',
          value: 1,
          measuredAt: measuredAt[i],
        ),
    ],
  );
}
