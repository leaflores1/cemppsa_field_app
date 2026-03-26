import '../data/models/planilla.dart';

String? familiaIdFromTipoPlanilla(
  TipoPlanilla tipo, {
  String? unsupportedFallback,
}) {
  switch (tipo) {
    case TipoPlanilla.casagrande:
      return 'piezometros_casagrande';
    case TipoPlanilla.freatimetros:
      return 'freatimetros';
    case TipoPlanilla.aforadores:
      return 'aforadores';
    case TipoPlanilla.drenes:
      return 'drenes';
    case TipoPlanilla.triaxiales:
      return 'triaxiales';
    default:
      return unsupportedFallback;
  }
}
