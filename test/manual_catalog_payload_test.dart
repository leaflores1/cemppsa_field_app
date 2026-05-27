import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/instrumento.dart';
import 'package:cemppsa_field_app/data/models/lectura.dart';
import 'package:cemppsa_field_app/utils/time_input.dart';

void main() {
  test('PP7 asterisco se preserva como instrumento distinto', () {
    expect(CodigoHelper.canonicalize('PP7*'), 'PP7*');
    expect(CodigoHelper.codigoMatch('PP7', 'PP7*'), isFalse);

    final lectura = Lectura.fromForm(
      clientRowId: 1,
      instrumentCode: 'PP7*',
      parameter: 'PROFUNDIDAD_M',
      unit: 'm',
      rawValue: '2.49',
      measuredAt: DateTime.utc(2026, 5, 4, 10),
    );

    expect(lectura.instrumentCode, 'PP7*');
    expect(lectura.toSyncJson()['instrument_code'], 'PP7*');
  });

  test('solo ALIV usa tiempo entre aforadores', () {
    final aliv = Instrumento.fromJson({
      'codigo': 'ALIV',
      'nombre': 'Aforador Aliviadero',
      'familia': 'AFORADOR',
      'default_parameter': 'altura',
      'default_unit': 'mm',
    });

    final afpp = Instrumento(
      codigo: 'AFPP',
      familia: FamiliaInstrumento.aforador,
      defaultParameter: 'altura',
      defaultUnit: 'mm',
      rangos: const [
        InstrumentRange(variableCodigo: 'TIEMPO_S', min: 1, max: 60),
      ],
    );

    expect(aliv.ingestaParameter, 'TIEMPO_S');
    expect(aliv.ingestaUnit, 's');
    expect(afpp.ingestaParameter, 'ALTURA_MM');
    expect(afpp.ingestaUnit, 'mm');
  });

  test('validacion de tiempo manual permite cero y bloquea rangos invalidos',
      () {
    expect(validateManualTimeInput('1', '05').value?.totalSeconds, 65);
    expect(validateManualTimeInput('', '30').value?.minutes, 0);
    expect(validateManualTimeInput('2', '').value?.seconds, 0);
    expect(validateManualTimeInput('0', '0').value?.totalSeconds, 0);
    expect(validateManualTimeInput('', '0').value?.totalSeconds, 0);
    expect(validateManualTimeInput('0', '').value?.totalSeconds, 0);

    expect(validateManualTimeInput('0', '60').isValid, isFalse);
    expect(validateManualTimeInput('-1', '10').isValid, isFalse);
  });

  test('drenes serializa minutos y segundos como variables crudas separadas',
      () {
    final measuredAt = DateTime.utc(2026, 5, 4, 10);
    final minutes = Lectura.fromForm(
      clientRowId: 1,
      instrumentCode: 'DC_01_02',
      parameter: 'DRENES_MIN',
      unit: 'min',
      rawValue: '2',
      measuredAt: measuredAt,
    );
    final seconds = Lectura.fromForm(
      clientRowId: 2,
      instrumentCode: 'DC_01_02',
      parameter: 'DRENES_SEG',
      unit: 's',
      rawValue: '30',
      measuredAt: measuredAt,
    );

    expect(minutes.toSyncJson()['parameter'], 'drenes_min');
    expect(minutes.toSyncJson()['unit'], 'min');
    expect(seconds.toSyncJson()['parameter'], 'drenes_seg');
    expect(seconds.toSyncJson()['unit'], 's');
  });
}
