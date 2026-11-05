import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/instrumento.dart';

/// TRAMO-2 (cemppsa-sistema DEC-0002): la variable que la app manda por
/// defecto debe coincidir con el contrato móvil del backend.
///
/// `test/fixtures/mobile_input_contract_v1.json` es una COPIA de
/// `cemppsa-sistema/backend/app/config/mobile_input_contract_v1.json`.
/// Si el backend cambia el contrato, copiar el archivo y correr este test.
void main() {
  final contract = jsonDecode(
    File('test/fixtures/mobile_input_contract_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  Map<String, dynamic> familyEntry(String family) {
    final families = contract['families'] as Map<String, dynamic>;
    final publication = contract['publication_families'] as Map<String, dynamic>;
    return (families[family] ?? publication[family]) as Map<String, dynamic>;
  }

  Map<String, dynamic> defaultCapture(String family) =>
      (familyEntry(family)['captures'] as List).first as Map<String, dynamic>;

  Instrumento instrument(String codigo, FamiliaInstrumento familia, {String? nombre}) =>
      Instrumento(
        codigo: codigo,
        nombre: nombre,
        familia: familia,
        defaultParameter: 'x',
        defaultUnit: 'x',
      );

  final cases = <String, Instrumento>{
    'PIEZOMETRO': instrument('PA48', FamiliaInstrumento.piezometro),
    'CELDA_PRESION': instrument('TE41_1', FamiliaInstrumento.celdaPresion),
    'TERMOMETRO': instrument('T0', FamiliaInstrumento.termometro),
    'TRIAXIAL': instrument('J1X', FamiliaInstrumento.triaxial),
    'UNIAXIAL': instrument('JP1', FamiliaInstrumento.uniaxial),
    'CLINOMETRO': instrument('CPB1', FamiliaInstrumento.clinometro),
    'ASENTIMETRO': instrument('AE141', FamiliaInstrumento.asentimetro),
    'CASAGRANDE': instrument('PC07', FamiliaInstrumento.casagrande),
    'FREATIMETRO': instrument('PP1', FamiliaInstrumento.freatimetro),
    'AFORADOR': instrument('AFPP', FamiliaInstrumento.aforador),
    'BAROMETRO': instrument('BARO', FamiliaInstrumento.barometro),
    'LIMNIMETRO': instrument('LIMNI', FamiliaInstrumento.limnimetro),
  };

  cases.forEach((family, inst) {
    test('$family: ingestaParameter/unit = captura default del contrato', () {
      final capture = defaultCapture(family);
      expect(inst.ingestaParameter, capture['variable']);
      expect(inst.ingestaUnit, capture['unit']);
    });
  });

  test('nunca se manda vocabulario de canal del datalogger', () {
    const channelOnly = {'LECTURA', 'LECTURA_CR10X', 'PERIODO_X', 'PERIODO_Y', 'PERIODO_Z'};
    for (final inst in cases.values) {
      expect(channelOnly.contains(inst.ingestaParameter), isFalse, reason: inst.codigo);
    }
  });

  test('regla de aliviadero igual al backend: codigo ALIV o nombre', () {
    final rule = familyEntry('AFORADOR')['aliviadero'] as Map<String, dynamic>;
    expect(rule['codes'], contains('ALIV'));
    expect(rule['name_contains'], contains('aliviadero'));

    expect(instrument('ALIV', FamiliaInstrumento.aforador).ingestaParameter, 'TIEMPO_S');
    expect(
      instrument('AF-ALV2', FamiliaInstrumento.aforador, nombre: 'Aforador del Aliviadero norte')
          .ingestaParameter,
      'TIEMPO_S',
    );
    expect(
      instrument('DC_03', FamiliaInstrumento.aforador, nombre: 'Dren aliviadero').ingestaParameter,
      'ALTURA_MM',
    );
  });
}
