import '../data/models/planilla.dart';
import '../repositories/catalogo_repository.dart';

bool planillaUsesSelectableEje(TipoPlanilla? tipo) =>
    tipo == TipoPlanilla.cr10xPiezometros ||
    tipo == TipoPlanilla.cr10xAsentimetros;

String planillaTitleWithEje(Planilla planilla, CatalogRepository catalog) {
  final eje = effectiveEjeForPlanilla(planilla, catalog);
  if (eje == null || eje.trim().isEmpty) {
    return planilla.tipo.displayName;
  }
  return '${planilla.tipo.displayName} · Eje ${eje.trim()}';
}

String? effectiveEjeForPlanilla(
  Planilla planilla,
  CatalogRepository catalog,
) {
  final stored = planilla.eje?.trim();
  if (stored != null && stored.isNotEmpty) {
    return stored;
  }
  if (!planillaUsesSelectableEje(planilla.tipo) || planilla.lecturas.isEmpty) {
    return null;
  }

  final code = planilla.lecturas.first.instrumentCode;
  final inst = catalog.byCode(code);
  final subfamilia = inst?.subfamilia;
  if (subfamilia != null && subfamilia.startsWith('EJE_')) {
    return subfamilia.split('_').last;
  }

  if (planilla.tipo == TipoPlanilla.cr10xPiezometros &&
      code.toUpperCase().startsWith('PC')) {
    return 'C';
  }

  return null;
}
