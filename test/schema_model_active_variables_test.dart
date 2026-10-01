import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/schema_model.dart';

void main() {
  group('SchemaInstrument active_variable_codes', () {
    test('parsea y normaliza la lista explicita', () {
      final instrument = SchemaInstrument.fromJson({
        'id': 237,
        'codigo': 'AE171',
        'nombre': 'Asentimetro AE171',
        'active_variable_codes': [' temperatura '],
      });

      expect(instrument.activeVariableCodes, ['TEMPERATURA']);
      expect(instrument.toJson()['active_variable_codes'], ['TEMPERATURA']);
    });

    test('preserva null cuando la clave falta o viene null', () {
      final missing = SchemaInstrument.fromJson({
        'id': 1,
        'codigo': 'AE1',
        'nombre': 'AE1',
      });
      final explicitNull = SchemaInstrument.fromJson({
        'id': 2,
        'codigo': 'AE2',
        'nombre': 'AE2',
        'active_variable_codes': null,
      });

      expect(missing.activeVariableCodes, isNull);
      expect(explicitNull.activeVariableCodes, isNull);
      expect(missing.toJson()['active_variable_codes'], isNull);
    });

    test('preserva lista explicita vacia', () {
      final instrument = SchemaInstrument.fromJson({
        'id': 237,
        'codigo': 'AE171',
        'nombre': 'Asentimetro AE171',
        'active_variable_codes': <String>[],
      });

      expect(instrument.activeVariableCodes, isNotNull);
      expect(instrument.activeVariableCodes, isEmpty);
      expect(instrument.toJson()['active_variable_codes'], isEmpty);
    });
  });
}
