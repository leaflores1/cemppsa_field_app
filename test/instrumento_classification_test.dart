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
  });
}
