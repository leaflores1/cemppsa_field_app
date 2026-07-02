import 'dart:io';

import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/repositories/planilla_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cemppsa_planillas_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('encuentra borradores CR10X por tipo y eje sin mezclar batchUuid',
      () async {
    final repository = PlanillaRepository();
    await repository.init();

    final ejeA = Planilla(
      tipo: TipoPlanilla.cr10xPiezometros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      eje: 'A',
    );
    final ejeB = Planilla(
      tipo: TipoPlanilla.cr10xPiezometros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      eje: 'B',
    );

    await repository.save(ejeA);
    await repository.save(ejeB);

    expect(
      repository
          .borradorPorTipoEje(TipoPlanilla.cr10xPiezometros, 'A')
          ?.batchUuid,
      ejeA.batchUuid,
    );
    expect(
      repository
          .borradorPorTipoEje(TipoPlanilla.cr10xPiezometros, 'B')
          ?.batchUuid,
      ejeB.batchUuid,
    );
    expect(ejeA.batchUuid, isNot(ejeB.batchUuid));
  });

  test('guarda y recarga borradores de todos los tipos de planilla', () async {
    final repository = PlanillaRepository();
    await repository.init();

    final savedByTipo = <TipoPlanilla, Planilla>{};

    for (final tipo in TipoPlanilla.values) {
      final index = TipoPlanilla.values.indexOf(tipo) + 1;
      final planilla = Planilla(
        tipo: tipo,
        deviceId: 'device-1',
        technicianId: 'tech-1',
        eje: _defaultEjeForTipo(tipo),
        lecturas: [
          Lectura.fromForm(
            clientRowId: 1,
            instrumentCode: 'TEST$index',
            parameter: 'LECTURA',
            unit: 'u',
            rawValue: index.toString(),
            measuredAt: DateTime.utc(2026, 7, 2, 12, index),
          ),
        ],
      );
      savedByTipo[tipo] = planilla;
      await repository.save(planilla);
    }

    expect(repository.borradores.length, TipoPlanilla.values.length);

    await Hive.close();
    Hive.init(tempDir.path);

    final reloaded = PlanillaRepository();
    await reloaded.init();

    expect(reloaded.borradores.length, TipoPlanilla.values.length);

    for (final tipo in TipoPlanilla.values) {
      final original = savedByTipo[tipo]!;
      final stored = reloaded.get(original.batchUuid);

      expect(stored, isNotNull, reason: tipo.codigo);
      expect(stored!.tipo, tipo);
      expect(stored.estado, PlanillaEstado.borrador);
      expect(stored.totalLecturas, 1);
      expect(stored.lecturas.single.instrumentCode,
          original.lecturas.single.instrumentCode);
      expect(stored.eje, original.eje);
    }
  });

  test('lookup por tipo y eje solo retorna borradores del mismo tipo',
      () async {
    final repository = PlanillaRepository();
    await repository.init();

    final borrador = Planilla(
      tipo: TipoPlanilla.cr10xPiezometros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      eje: 'A',
    );
    final pendienteMismoEje = Planilla(
      tipo: TipoPlanilla.cr10xPiezometros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      eje: 'B',
    )..marcarPendiente();
    final otroTipoMismoEje = Planilla(
      tipo: TipoPlanilla.cr10xAsentimetros,
      deviceId: 'device-1',
      technicianId: 'tech-1',
      eje: 'A',
    );

    await repository.save(borrador);
    await repository.save(pendienteMismoEje);
    await repository.save(otroTipoMismoEje);

    expect(
      repository
          .borradorPorTipoEje(TipoPlanilla.cr10xPiezometros, ' a ')
          ?.batchUuid,
      borrador.batchUuid,
    );
    expect(
      repository.borradorPorTipoEje(TipoPlanilla.cr10xPiezometros, 'B'),
      isNull,
    );
    expect(
      repository
          .borradorPorTipoEje(TipoPlanilla.cr10xAsentimetros, 'A')
          ?.batchUuid,
      otroTipoMismoEje.batchUuid,
    );
  });
}

String? _defaultEjeForTipo(TipoPlanilla tipo) {
  switch (tipo) {
    case TipoPlanilla.cr10xPiezometros:
      return 'A';
    case TipoPlanilla.cr10xAsentimetros:
      return 'D';
    default:
      return null;
  }
}
