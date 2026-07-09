import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/ui/screens/cr10x_batch_screen.dart';

void main() {
  group('CR10X reading keys', () {
    test('preserva guion para piezometros Eje C', () {
      expect(cr10xReadingKeyForTesting('PC-05', 'PERIODO'), 'PC-05|PERIODO');
    });

    test('mantiene codigo Casagrande sin guion', () {
      expect(cr10xReadingKeyForTesting('PC05', 'PERIODO'), 'PC05|PERIODO');
    });
  });

  group('CR10X schema fallback', () {
    test('usa parametros backend-safe cuando mobile schema no esta disponible',
        () {
      expect(
        cr10xPrimaryParameterFallbackForTesting(TipoPlanilla.cr10xBarometro),
        'PRESION_MBAR',
      );
      expect(
        cr10xPrimaryUnitFallbackForTesting(TipoPlanilla.cr10xBarometro),
        'mbar',
      );
      expect(
        cr10xPrimaryParameterFallbackForTesting(TipoPlanilla.cr10xLimnimetros),
        'NIVEL_EMBALSE',
      );
      expect(
        cr10xPrimaryUnitFallbackForTesting(TipoPlanilla.cr10xLimnimetros),
        'msnm',
      );
    });
  });
}
