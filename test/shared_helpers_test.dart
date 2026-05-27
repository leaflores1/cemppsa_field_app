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

    test('planillaFamilyGroupFromTipo agrupa enviadas por familia estable', () {
      expect(
        planillaFamilyGroupFromTipo(TipoPlanilla.drenes).label,
        'Drenes',
      );
      expect(
        planillaFamilyGroupFromTipo(TipoPlanilla.cr10xPiezometros).id,
        'piezometros',
      );
      expect(
        planillaFamilyGroupFromTipo(TipoPlanilla.general).label,
        'Sin familia',
      );
      expect(
        planillaFamilyGroupFromTipo(TipoPlanilla.cr10xPiezometros).order <
            planillaFamilyGroupFromTipo(TipoPlanilla.cr10xClinometros).order,
        isTrue,
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
