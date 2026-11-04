import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:cemppsa_field_app/api/api_client.dart';
import 'package:cemppsa_field_app/core/config.dart';
import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/data/models/schema_model.dart';
import 'package:cemppsa_field_app/repositories/catalogo_repository.dart';
import 'package:cemppsa_field_app/services/sync_service.dart';
import 'package:cemppsa_field_app/utils/cr10x_active_variables.dart';
import 'package:cemppsa_field_app/utils/user_facing_error.dart';

/// Regresión: el backend informa `active_variable_codes` con el vocabulario de
/// `cr10x_channel_map` (`LECTURA_CR10X`) mientras el schema móvil usa
/// `PERIODO`. La app interpretaba el cruce vacío como "nada habilitado" y
/// borraba todas las lecturas de celdas, termómetros, uniaxiales, etc.

MobileSchema _periodoSchema(
  String familia,
  Map<String, List<String>?> activeByInstrument, {
  bool withTemperature = false,
}) {
  return MobileSchema(
    familia: familia,
    payloadFormat: 'PIVOT',
    variables: [
      SchemaVariable(
        code: 'PERIODO',
        name: 'Periodo',
        unit: 'us',
        type: 'RAW',
        required: true,
        isDefault: true,
      ),
      if (withTemperature)
        SchemaVariable(
          code: 'TEMPERATURA',
          name: 'Temperatura',
          unit: 'C',
          type: 'RAW',
        ),
    ],
    instruments: [
      for (final entry in activeByInstrument.entries)
        SchemaInstrument(
          id: entry.key.hashCode,
          codigo: entry.key,
          nombre: entry.key,
          activeVariableCodes: entry.value,
        ),
    ],
  );
}

Lectura _reading(int row, String instrument, String parameter) {
  return Lectura.fromForm(
    clientRowId: row,
    instrumentCode: instrument,
    parameter: parameter,
    unit: parameter == 'TEMPERATURA' ? 'C' : 'us',
    rawValue: '${2500 + row}',
    measuredAt: DateTime.utc(2026, 10, 30, 11),
  );
}

class _FakeCatalog extends CatalogRepository {
  final MobileSchema schema;

  _FakeCatalog(this.schema);

  @override
  Future<MobileSchemaLoadResult> loadMobileSchema(String familyId) async {
    return MobileSchemaLoadResult(
      schema: schema,
      source: MobileSchemaSource.cache,
    );
  }
}

void main() {
  group('cruce de variables activas', () {
    test('LECTURA_CR10X del canal equivale a la variable por defecto', () {
      final schema = _periodoSchema('TERMOMETRO', {
        'T1': ['LECTURA_CR10X'],
      });
      expect(cr10xActiveVariableCodesForInstrument(schema, 'T1'), {'PERIODO'});
      expect(cr10xInstrumentAllowsVariable(schema, 'T1', 'PERIODO'), isTrue);
    });

    test('piezometro con canal crudo y temperatura habilita ambas', () {
      final schema = _periodoSchema(
        'PIEZOMETRO',
        {
          'PA48': ['LECTURA_CR10X', 'TEMPERATURA'],
        },
        withTemperature: true,
      );
      expect(
        cr10xActiveVariableCodesForInstrument(schema, 'PA48'),
        {'PERIODO', 'TEMPERATURA'},
      );
    });

    test('vocabulario desconocido no restringe', () {
      final schema = _periodoSchema('CELDA_PRESION', {
        'TE41_1': ['CODIGO_NUEVO'],
      });
      expect(cr10xActiveVariableCodesForInstrument(schema, 'TE41_1'), isNull);
    });

    test('celdas, termometros y uniaxiales conservan todas sus lecturas', () {
      final schema = _periodoSchema('CELDA_PRESION', {
        'TE41_1': ['LECTURA_CR10X'],
        'TE44': ['LECTURA_CR10X'],
      });
      final readings = [
        _reading(1, 'TE41_1', 'PERIODO'),
        _reading(2, 'TE44', 'PERIODO'),
      ];
      final result = sanitizeCr10xReadingsAgainstSchema(readings, schema);
      expect(result.removedReadings, isEmpty);
      expect(result.readings, readings);
    });
  });

  test('el mensaje de bloqueo se muestra tal cual al tecnico', () {
    final message = cr10xBlockedReadingsMessage([
      _reading(1, 'AE171', 'LECTURA_LU'),
    ]);
    expect(message, startsWith('La planilla contiene 1 lectura(s)'));
    expect(userFacingSyncError(message), message);
    expect(
      userFacingSyncError('La planilla no tiene lecturas para enviar. '
          'No se envió nada al servidor.'),
      startsWith('La planilla no tiene lecturas'),
    );
  });

  group('SyncService.sendPlanilla', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cemppsa_no_loss_');
      Hive.init(tempDir.path);
      ApiConfig.authToken = null;
      ApiConfig.refreshToken = null;
      ApiConfig.refreshAuthToken = null;
      ApiConfig.handleSessionExpired = null;
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    SyncService offlineSync() => SyncService(
          apiClient: ApiClient(
            baseUrl: 'http://127.0.0.1:1',
            timeout: const Duration(milliseconds: 250),
          ),
        );

    test('lecturas no habilitadas bloquean el envio sin borrarlas', () async {
      final schema = _periodoSchema('CELDA_PRESION', {
        'TE41_1': const [],
      });
      final planilla = Planilla(
        tipo: TipoPlanilla.cr10xCeldasPresion,
        deviceId: 'android-test',
        technicianId: 'tech-test',
        lecturas: [_reading(1, 'TE41_1', 'PERIODO')],
      );

      final sent = await offlineSync().sendPlanilla(
        planilla,
        catalog: _FakeCatalog(schema),
      );

      expect(sent, isFalse);
      expect(planilla.totalLecturas, 1);
      expect(planilla.errorMessage, startsWith('La planilla contiene'));
    });

    test('desajuste LECTURA_CR10X/PERIODO ya no vacia la planilla', () async {
      final schema = _periodoSchema('TERMOMETRO', {
        'T0': ['LECTURA_CR10X'],
        'T1': ['LECTURA_CR10X'],
      });
      final planilla = Planilla(
        tipo: TipoPlanilla.cr10xTermometros,
        deviceId: 'android-test',
        technicianId: 'tech-test',
        lecturas: [
          _reading(1, 'T0', 'PERIODO'),
          _reading(2, 'T1', 'PERIODO'),
        ],
      );

      final sent = await offlineSync().sendPlanilla(
        planilla,
        catalog: _FakeCatalog(schema),
      );

      // Sin servidor el envío falla por conectividad, pero las lecturas
      // siguen intactas.
      expect(sent, isFalse);
      expect(planilla.totalLecturas, 2);
    });

    test('una planilla vacia no se envia al servidor', () async {
      final planilla = Planilla(
        tipo: TipoPlanilla.cr10xUniaxiales,
        deviceId: 'android-test',
        technicianId: 'tech-test',
      );

      final service = offlineSync();
      final sent = await service.sendPlanilla(planilla);

      expect(sent, isFalse);
      expect(planilla.errorMessage, startsWith('La planilla no tiene lecturas'));
    });
  });
}
