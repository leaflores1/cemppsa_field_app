import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/data/models/schema_model.dart';
import 'package:cemppsa_field_app/utils/cr10x_active_variables.dart';

void main() {
  final schema = MobileSchema(
    familia: 'ASENTIMETRO',
    payloadFormat: 'PIVOT',
    variables: [
      SchemaVariable(
        code: 'LECTURA_LU',
        name: 'Lectura LU',
        unit: 'LU',
        type: 'RAW',
      ),
      SchemaVariable(
        code: 'TEMPERATURA',
        name: 'Temperatura',
        unit: 'C',
        type: 'RAW',
      ),
    ],
    instruments: [
      SchemaInstrument(
        id: 237,
        codigo: 'AE171',
        nombre: 'AE171',
        activeVariableCodes: const ['TEMPERATURA'],
      ),
      SchemaInstrument(
        id: 238,
        codigo: 'AE172',
        nombre: 'AE172',
        activeVariableCodes: const ['LECTURA_LU', 'TEMPERATURA'],
      ),
      SchemaInstrument(
        id: 239,
        codigo: 'AE173',
        nombre: 'AE173',
      ),
      SchemaInstrument(
        id: 240,
        codigo: 'AE174',
        nombre: 'AE174',
        activeVariableCodes: const [],
      ),
    ],
  );

  Lectura reading(int row, String instrument, String parameter) {
    return Lectura.fromForm(
      clientRowId: row,
      instrumentCode: instrument,
      parameter: parameter,
      unit: parameter == 'TEMPERATURA' ? 'C' : 'LU',
      rawValue: row.toString(),
      measuredAt: DateTime.utc(2026, 10, 1, 10),
    );
  }

  test('AE171 habilita solo temperatura', () {
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE171', 'LECTURA_LU'),
      isFalse,
    );
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE171', 'TEMPERATURA'),
      isTrue,
    );
  });

  test('asentimetro normal conserva LU y temperatura', () {
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE172', 'LECTURA_LU'),
      isTrue,
    );
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE172', 'TEMPERATURA'),
      isTrue,
    );
  });

  test('null mantiene fallback y lista vacia bloquea toda captura', () {
    expect(
      cr10xActiveVariableCodesForInstrument(schema, 'AE173'),
      isNull,
    );
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE173', 'LECTURA_LU'),
      isTrue,
    );
    expect(
      cr10xActiveVariableCodesForInstrument(schema, 'AE174'),
      isEmpty,
    );
    expect(
      cr10xInstrumentAllowsVariable(schema, 'AE174', 'TEMPERATURA'),
      isFalse,
    );
  });

  test('sanitiza AE171/LU y preserva temperatura y lecturas ajenas', () {
    final legacyLu = reading(1, 'AE171', 'LECTURA_LU');
    final ae171Temp = reading(2, 'AE171', 'TEMPERATURA');
    final otherLu = reading(3, 'AE172', 'LECTURA_LU');
    final fallbackLu = reading(4, 'AE173', 'LECTURA_LU');
    final result = sanitizeCr10xReadingsAgainstSchema(
      [legacyLu, ae171Temp, otherLu, fallbackLu],
      schema,
    );

    expect(result.removedReadings, [legacyLu]);
    expect(result.readings, [ae171Temp, otherLu, fallbackLu]);

    final planilla = Planilla(
      tipo: TipoPlanilla.cr10xAsentimetros,
      deviceId: 'test-device',
      technicianId: 'test-tech',
      lecturas: result.readings,
    );
    final payload = planilla.toSyncRequest()['readings'] as List<dynamic>;
    expect(
      payload.where((entry) =>
          entry['instrument_code'] == 'AE171' &&
          entry['parameter'] == 'lectura_lu'),
      isEmpty,
    );
    expect(
      payload.where((entry) =>
          entry['instrument_code'] == 'AE171' &&
          entry['parameter'] == 'temperatura'),
      hasLength(1),
    );
    expect(payload, hasLength(3));
  });
}
