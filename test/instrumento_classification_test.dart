import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/instrumento.dart';

void main() {
  group('Clasificacion de instrumentos', () {
    test('PC05 se clasifica como Casagrande manual', () {
      expect(
        FamiliaInstrumento.inferFromCode('PC05'),
        FamiliaInstrumento.casagrande,
      );
      expect(Subfamilia.inferFromCode('PC05'), Subfamilia.casagrande);
    });

    test('PC31 se clasifica como piezometro del Eje C', () {
      expect(
        FamiliaInstrumento.inferFromCode('PC31'),
        FamiliaInstrumento.piezometro,
      );
      expect(Subfamilia.inferFromCode('PC31'), Subfamilia.ejeC);
    });

    test('PC-05 se clasifica como piezometro del Eje C', () {
      expect(
        FamiliaInstrumento.inferFromCode('PC-05'),
        FamiliaInstrumento.piezometro,
      );
      expect(Subfamilia.inferFromCode('PC-05'), Subfamilia.ejeC);
    });

    test('PE11 y PE11-C son el mismo piezometro fisico del Eje E', () {
      expect(CodigoHelper.canonicalize('PE11'), 'PE11');
      expect(CodigoHelper.canonicalize('PE11-C'), 'PE11');
      expect(Subfamilia.inferFromCode('PE11'), Subfamilia.ejeE);
      expect(Subfamilia.inferFromCode('PE11-C'), Subfamilia.ejeE);
      expect(Subfamilia.inferFromCode('PE112'), Subfamilia.ejeE1);
    });

    test('Instrumento.fromJson corrige familia generica para PC05', () {
      final instrumento = Instrumento.fromJson({
        'codigo': 'PC05',
        'familia': 'PIEZOMETRO',
        'subfamilia': null,
      });

      expect(instrumento.familia, FamiliaInstrumento.casagrande);
      expect(instrumento.subfamilia, Subfamilia.casagrande);
      expect(instrumento.esManual, isTrue);
      expect(instrumento.esCR10X, isFalse);
    });

    test('Instrumento.fromJson mantiene Eje C para PC31', () {
      final instrumento = Instrumento.fromJson({
        'codigo': 'PC31',
        'familia': 'PIEZOMETRO',
        'subfamilia': null,
      });

      expect(instrumento.familia, FamiliaInstrumento.piezometro);
      expect(instrumento.subfamilia, Subfamilia.ejeC);
      expect(instrumento.esManual, isFalse);
      expect(instrumento.esCR10X, isTrue);
    });

    test('EMBALSE queda disponible para lecturas de nivel desde CR10X', () {
      final limni = Instrumento.fromJson({
        'codigo': 'LIMNI',
        'nombre': 'Limnimetro',
        'familia': 'EMBALSE',
      });

      expect(limni.familia, FamiliaInstrumento.embalse);
      expect(limni.ingestaParameter, 'NIVEL_EMBALSE');
      expect(limni.ingestaUnit, 'msnm');
    });

    test('BAROMETRO usa contrato backend de presion en mbar', () {
      final barometro = Instrumento.fromJson({
        'codigo': 'BARO',
        'nombre': 'Barometro',
        'familia': 'BAROMETRO',
      });

      expect(barometro.familia, FamiliaInstrumento.barometro);
      expect(barometro.ingestaParameter, 'PRESION_MBAR');
      expect(barometro.ingestaUnit, 'mbar');
    });
  });
}
