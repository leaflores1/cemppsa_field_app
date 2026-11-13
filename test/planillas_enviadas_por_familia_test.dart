import 'dart:io';

import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/repositories/catalogo_repository.dart';
import 'package:cemppsa_field_app/repositories/planilla_repository.dart';
import 'package:cemppsa_field_app/ui/screens/planillas_hub_screen.dart';
import 'package:cemppsa_field_app/utils/planillas_enviadas_grouping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

void main() {
  group('agrupación de enviadas (lógica pura)', () {
    test('resume por familia con cantidad y última fecha de medición', () {
      final familias = resumirPorFamilia([
        _planilla(TipoPlanilla.freatimetros, DateTime(2026, 10, 2)),
        _planilla(TipoPlanilla.casagrande, DateTime(2026, 9, 1)),
        _planilla(TipoPlanilla.casagrande, DateTime(2026, 10, 29)),
        _planilla(TipoPlanilla.casagrande, DateTime(2026, 10, 15)),
      ]);

      expect(familias.map((f) => f.group.id), ['casagrande', 'freatimetros']);
      expect(familias.first.count, 3);
      expect(familias.first.ultimaFecha, DateTime(2026, 10, 29));
      expect(formatFechaCorta(familias.first.ultimaFecha), '29 oct 2026');
    });

    test('sin lecturas usa la fecha de creación como referencia', () {
      final planilla = Planilla(
        tipo: TipoPlanilla.drenes,
        deviceId: 'd',
        technicianId: 't',
        createdAt: DateTime(2026, 8, 3, 10),
      );
      expect(fechaReferenciaPlanilla(planilla), DateTime(2026, 8, 3, 10));
    });

    test('agrupa por mes de más reciente a más antiguo', () {
      final meses = agruparPorMes([
        _planilla(TipoPlanilla.aforadores, DateTime(2026, 9, 10)),
        _planilla(TipoPlanilla.aforadores, DateTime(2026, 11, 2)),
        _planilla(TipoPlanilla.aforadores, DateTime(2026, 9, 24)),
        _planilla(TipoPlanilla.aforadores, DateTime(2025, 11, 5)),
      ]);

      expect(meses.map((m) => m.label),
          ['Noviembre 2026', 'Septiembre 2026', 'Noviembre 2025']);
      expect(
        meses[1].planillas.map(fechaReferenciaPlanilla),
        [DateTime(2026, 9, 24), DateTime(2026, 9, 10)],
      );
    });

    test('ofrece filtro de eje solo si hay más de un eje', () {
      expect(
        ejesDisponibles([
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 1),
              eje: 'A'),
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 2),
              eje: 'A'),
        ]),
        isEmpty,
      );
      expect(
        ejesDisponibles([
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 1),
              eje: 'E1'),
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 2)),
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 3),
              eje: 'A'),
        ]),
        ['A', 'E1', sinEjeKey],
      );
    });
  });

  group('pestaña Enviada de Mis Planillas', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cemppsa_enviadas_test_');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('muestra tarjetas por familia y entra a la lista por mes',
        (tester) async {
      final repo = PlanillaRepository();
      await tester.runAsync(() async {
        await repo.init();
        for (final p in [
          _planilla(TipoPlanilla.casagrande, DateTime(2026, 10, 29)),
          _planilla(TipoPlanilla.casagrande, DateTime(2026, 9, 3)),
          _planilla(TipoPlanilla.freatimetros, DateTime(2026, 10, 30)),
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 20),
              eje: 'A'),
          _planilla(TipoPlanilla.cr10xPiezometros, DateTime(2026, 9, 18),
              eje: 'B'),
          _planilla(TipoPlanilla.casagrande, DateTime(2026, 11, 5),
              estado: PlanillaEstado.borrador),
        ]) {
          await repo.save(p);
        }
      });

      await tester.pumpWidget(_wrap(repo));
      await tester.tap(find.text('Enviada'));
      await tester.pumpAndSettle();

      // Nivel 1: una tarjeta por familia, sin listar planillas sueltas.
      expect(find.byKey(const ValueKey('familia-enviadas-casagrande')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('familia-enviadas-freatimetros')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('familia-enviadas-piezometros')),
          findsOneWidget);
      // El borrador no cuenta como enviada.
      expect(find.text('2 planillas · Última: 29 oct 2026'), findsOneWidget);
      expect(find.text('1 planilla · Última: 30 oct 2026'), findsOneWidget);
      expect(find.text('Septiembre 2026'), findsNothing);

      // Nivel 2: familia Casagrande agrupada por mes, reciente primero.
      await tester
          .tap(find.byKey(const ValueKey('familia-enviadas-casagrande')));
      await tester.pumpAndSettle();

      expect(find.text('Piezometros Casagrande'), findsOneWidget);
      final octubre = find.text('Octubre 2026');
      final septiembre = find.text('Septiembre 2026');
      expect(octubre, findsOneWidget);
      expect(septiembre, findsOneWidget);
      expect(tester.getTopLeft(octubre).dy,
          lessThan(tester.getTopLeft(septiembre).dy));
      expect(find.text('Todos'), findsNothing);

      // Volver al nivel 1.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('familia-enviadas-casagrande')),
          findsOneWidget);
    });

    testWidgets('piezómetros CR10X se filtran por eje', (tester) async {
      final repo = PlanillaRepository();
      await tester.runAsync(() async {
        await repo.init();
        await repo.save(_planilla(
            TipoPlanilla.cr10xPiezometros, DateTime(2026, 10, 20),
            eje: 'A'));
        await repo.save(_planilla(
            TipoPlanilla.cr10xPiezometros, DateTime(2026, 9, 18),
            eje: 'B'));
      });

      await tester.pumpWidget(_wrap(repo));
      await tester.tap(find.text('Enviada'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('familia-enviadas-piezometros')));
      await tester.pumpAndSettle();

      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('Octubre 2026'), findsOneWidget);
      expect(find.text('Septiembre 2026'), findsOneWidget);

      await tester.tap(find.text('Eje B'));
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsNothing);
      expect(find.text('Septiembre 2026'), findsOneWidget);

      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();
      expect(find.text('Octubre 2026'), findsOneWidget);
    });

    testWidgets('sin enviadas muestra el estado vacío', (tester) async {
      final repo = PlanillaRepository();
      await tester.runAsync(repo.init);

      await tester.pumpWidget(_wrap(repo));
      await tester.tap(find.text('Enviada'));
      await tester.pumpAndSettle();

      expect(find.text('Sin enviadas'), findsOneWidget);
    });
  });
}

Widget _wrap(PlanillaRepository repo) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PlanillaRepository>.value(value: repo),
      ChangeNotifierProvider<CatalogRepository>.value(
          value: CatalogRepository()),
    ],
    child: const MaterialApp(home: PlanillasHubScreen()),
  );
}

var _seq = 0;

Planilla _planilla(
  TipoPlanilla tipo,
  DateTime measuredAt, {
  String? eje,
  PlanillaEstado estado = PlanillaEstado.enviada,
}) {
  _seq++;
  return Planilla(
    tipo: tipo,
    deviceId: 'device-1',
    technicianId: 'tech-1',
    createdAt: measuredAt.add(const Duration(hours: 2)),
    estado: estado,
    eje: eje,
    lastSyncAttempt: measuredAt.add(const Duration(hours: 3)),
    lecturas: [
      Lectura(
        clientRowId: _seq,
        instrumentCode: 'INS$_seq',
        value: 1,
        measuredAt: measuredAt,
      ),
    ],
  );
}
