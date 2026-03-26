import 'package:flutter_test/flutter_test.dart';

import 'package:cemppsa_field_app/data/models/planilla.dart';
import 'package:cemppsa_field_app/utils/network_errors.dart';
import 'package:cemppsa_field_app/utils/planilla_family.dart';

void main() {
  group('Shared helpers', () {
    test('familiaIdFromTipoPlanilla centraliza familias manuales', () {
      expect(
        familiaIdFromTipoPlanilla(TipoPlanilla.casagrande),
        'piezometros_casagrande',
      );
      expect(
        familiaIdFromTipoPlanilla(
          TipoPlanilla.cr10xPiezometros,
          unsupportedFallback: 'general_app',
        ),
        'general_app',
      );
    });

    test('isConnectivityFailure detecta errores de red conocidos', () {
      expect(
        isConnectivityFailure(
          statusCode: 500,
          message: 'SocketException: Connection refused',
        ),
        isTrue,
      );
      expect(
        isConnectivityFailure(
          statusCode: 422,
          message: 'validation error',
        ),
        isFalse,
      );
    });
  });
}
