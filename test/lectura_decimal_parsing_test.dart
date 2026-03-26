import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/lectura.dart';

void main() {
  group('Lectura decimal parsing', () {
    test('acepta punto como separador decimal', () {
      expect(Lectura.parseRawValue('12.5'), 12.5);
    });

    test('acepta coma como separador decimal', () {
      expect(Lectura.parseRawValue('12,5'), 12.5);
    });

    test('rechaza formatos ambiguos o invalidos', () {
      expect(Lectura.parseRawValue('1,234.5'), isNull);
      expect(Lectura.parseRawValue('12..5'), isNull);
      expect(Lectura.isInvalidRawValue('12,5.1'), isTrue);
    });
  });
}
