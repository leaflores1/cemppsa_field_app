import 'package:flutter_test/flutter_test.dart';

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
}
