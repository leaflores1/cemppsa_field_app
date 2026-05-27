import '../data/models/planilla.dart';

class PlanillaFamilyGroup {
  final String id;
  final String label;
  final int order;

  const PlanillaFamilyGroup({
    required this.id,
    required this.label,
    required this.order,
  });
}

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

PlanillaFamilyGroup planillaFamilyGroupFromTipo(TipoPlanilla tipo) {
  switch (tipo) {
    case TipoPlanilla.casagrande:
      return const PlanillaFamilyGroup(
        id: 'casagrande',
        label: 'Piezometros Casagrande',
        order: 10,
      );
    case TipoPlanilla.freatimetros:
      return const PlanillaFamilyGroup(
        id: 'freatimetros',
        label: 'Freatimetros',
        order: 20,
      );
    case TipoPlanilla.aforadores:
      return const PlanillaFamilyGroup(
        id: 'aforadores',
        label: 'Aforadores',
        order: 30,
      );
    case TipoPlanilla.drenes:
      return const PlanillaFamilyGroup(
        id: 'drenes',
        label: 'Drenes',
        order: 40,
      );
    case TipoPlanilla.cr10xPiezometros:
      return const PlanillaFamilyGroup(
        id: 'piezometros',
        label: 'Piezometros',
        order: 50,
      );
    case TipoPlanilla.cr10xAsentimetros:
      return const PlanillaFamilyGroup(
        id: 'asentimetros',
        label: 'Asentimetros',
        order: 60,
      );
    case TipoPlanilla.triaxiales:
    case TipoPlanilla.cr10xTriaxiales:
      return const PlanillaFamilyGroup(
        id: 'triaxiales',
        label: 'Triaxiales',
        order: 70,
      );
    case TipoPlanilla.cr10xUniaxiales:
      return const PlanillaFamilyGroup(
        id: 'uniaxiales',
        label: 'Uniaxiales',
        order: 80,
      );
    case TipoPlanilla.cr10xTermometros:
      return const PlanillaFamilyGroup(
        id: 'termometros',
        label: 'Termometros',
        order: 90,
      );
    case TipoPlanilla.cr10xClinometros:
      return const PlanillaFamilyGroup(
        id: 'clinometros',
        label: 'Clinometros',
        order: 100,
      );
    case TipoPlanilla.cr10xLimnimetros:
      return const PlanillaFamilyGroup(
        id: 'limnimetros',
        label: 'Limnimetros / Embalse',
        order: 110,
      );
    case TipoPlanilla.cr10xBarometro:
      return const PlanillaFamilyGroup(
        id: 'barometro',
        label: 'Barometro',
        order: 120,
      );
    case TipoPlanilla.cr10xCeldasPresion:
      return const PlanillaFamilyGroup(
        id: 'celdas_presion',
        label: 'Celdas de Presion',
        order: 130,
      );
    case TipoPlanilla.sismos:
      return const PlanillaFamilyGroup(
        id: 'sismos',
        label: 'Sismos',
        order: 140,
      );
    case TipoPlanilla.general:
      return const PlanillaFamilyGroup(
        id: 'sin_familia',
        label: 'Sin familia',
        order: 999,
      );
  }
}
