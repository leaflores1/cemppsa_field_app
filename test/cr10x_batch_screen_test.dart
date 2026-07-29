import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/data/models/schema_model.dart';
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
    test(
      'usa parametros backend-safe cuando mobile schema no esta disponible',
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
          cr10xPrimaryParameterFallbackForTesting(
            TipoPlanilla.cr10xLimnimetros,
          ),
          'NIVEL_EMBALSE',
        );
        expect(
          cr10xPrimaryUnitFallbackForTesting(TipoPlanilla.cr10xLimnimetros),
          'msnm',
        );
      },
    );
  });

  group('CR10X variables activas por instrumento', () {
    final schema = MobileSchema(
      familia: 'ASENTIMETRO',
      instruments: [
        SchemaInstrument(
          id: 237,
          codigo: 'AE171',
          nombre: 'AE171',
          activeVariableCodes: const ['TEMPERATURA'],
        ),
      ],
      variables: const [],
      payloadFormat: 'PIVOT',
    );

    test('AE171 muestra T y oculta/rechaza LU segun el schema', () {
      expect(
        cr10xVariableIsActiveForTesting(schema, 'AE171', 'TEMPERATURA'),
        isTrue,
      );
      expect(
        cr10xVariableIsActiveForTesting(schema, 'AE171', 'LECTURA_LU'),
        isFalse,
      );
    });

    test('mantiene compatibilidad si el backend aun no informa canales', () {
      final legacySchema = MobileSchema(
        familia: 'ASENTIMETRO',
        instruments: [
          SchemaInstrument(id: 237, codigo: 'AE171', nombre: 'AE171'),
        ],
        variables: const [],
        payloadFormat: 'PIVOT',
      );

      expect(
        cr10xVariableIsActiveForTesting(legacySchema, 'AE171', 'LECTURA_LU'),
        isTrue,
      );
    });

    test('resuelve el alias PE11-C contra el codigo fisico PE11', () {
      final peSchema = MobileSchema(
        familia: 'PIEZOMETRO',
        instruments: [SchemaInstrument(id: 48, codigo: 'PE11', nombre: 'PE11')],
        variables: const [],
        payloadFormat: 'PIVOT',
      );

      expect(
        cr10xVariableIsActiveForTesting(peSchema, 'PE11-C', 'PERIODO'),
        isTrue,
      );
    });
  });
}
