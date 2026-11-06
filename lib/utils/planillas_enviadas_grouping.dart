// ==============================================================================
// CEMPPSA Field App - Agrupación de planillas enviadas
// Lógica pura (sin widgets) para la pestaña "Enviada" de Mis Planillas:
// familias con cantidad y última fecha, meses y ejes dentro de una familia.
// ==============================================================================

import '../data/models/planilla.dart';
import 'planilla_family.dart';

/// Fecha de referencia de una planilla para ordenar y agrupar en el
/// repositorio de enviadas: la última fecha de medición de sus lecturas o,
/// si no tiene lecturas, la fecha de creación.
DateTime fechaReferenciaPlanilla(Planilla planilla) {
  DateTime? latest;
  for (final lectura in planilla.lecturas) {
    final measured = lectura.measuredAt.toLocal();
    if (latest == null || measured.isAfter(latest)) latest = measured;
  }
  return latest ?? planilla.createdAt.toLocal();
}

/// Ordena de más reciente a más antigua según [fechaReferenciaPlanilla].
List<Planilla> ordenarPorFechaReferenciaDesc(Iterable<Planilla> planillas) {
  return planillas.toList()
    ..sort((a, b) {
      final byDate =
          fechaReferenciaPlanilla(b).compareTo(fechaReferenciaPlanilla(a));
      if (byDate != 0) return byDate;
      return b.createdAt.compareTo(a.createdAt);
    });
}

class PlanillaFamilySummary {
  final PlanillaFamilyGroup group;

  /// Planillas de la familia, de más reciente a más antigua.
  final List<Planilla> planillas;

  const PlanillaFamilySummary({required this.group, required this.planillas});

  int get count => planillas.length;

  DateTime get ultimaFecha => fechaReferenciaPlanilla(planillas.first);
}

/// Agrupa por familia (orden estable de [PlanillaFamilyGroup.order]).
List<PlanillaFamilySummary> resumirPorFamilia(Iterable<Planilla> planillas) {
  final groups = <String, PlanillaFamilyGroup>{};
  final byGroup = <String, List<Planilla>>{};
  for (final planilla in planillas) {
    final group = planillaFamilyGroupFromTipo(planilla.tipo);
    groups[group.id] = group;
    byGroup.putIfAbsent(group.id, () => []).add(planilla);
  }

  final summaries = [
    for (final id in byGroup.keys)
      PlanillaFamilySummary(
        group: groups[id]!,
        planillas: ordenarPorFechaReferenciaDesc(byGroup[id]!),
      ),
  ];
  summaries.sort((a, b) {
    final byOrder = a.group.order.compareTo(b.group.order);
    if (byOrder != 0) return byOrder;
    return a.group.label.compareTo(b.group.label);
  });
  return summaries;
}

class PlanillasMes {
  final int year;
  final int month;
  final List<Planilla> planillas;

  const PlanillasMes({
    required this.year,
    required this.month,
    required this.planillas,
  });

  String get label => '${mesesLargos[month - 1]} $year';
}

/// Agrupa por mes de la fecha de referencia, meses y planillas de más
/// reciente a más antiguo.
List<PlanillasMes> agruparPorMes(Iterable<Planilla> planillas) {
  final result = <PlanillasMes>[];
  for (final planilla in ordenarPorFechaReferenciaDesc(planillas)) {
    final fecha = fechaReferenciaPlanilla(planilla);
    if (result.isEmpty ||
        result.last.year != fecha.year ||
        result.last.month != fecha.month) {
      result.add(
        PlanillasMes(year: fecha.year, month: fecha.month, planillas: []),
      );
    }
    result.last.planillas.add(planilla);
  }
  return result;
}

/// Valor de filtro para planillas sin eje.
const String sinEjeKey = '';

String ejeKey(Planilla planilla) => planilla.eje?.trim() ?? sinEjeKey;

/// Ejes distintos presentes, ordenados alfabéticamente ("sin eje" al final).
/// Devuelve lista vacía si no hay al menos dos valores distintos (no hace
/// falta filtrar).
List<String> ejesDisponibles(Iterable<Planilla> planillas) {
  final ejes = planillas.map(ejeKey).toSet().toList()
    ..sort((a, b) {
      if (a == sinEjeKey) return 1;
      if (b == sinEjeKey) return -1;
      return a.compareTo(b);
    });
  return ejes.length < 2 ? const [] : ejes;
}

String formatFechaCorta(DateTime fecha) {
  final local = fecha.toLocal();
  return '${local.day.toString().padLeft(2, '0')} '
      '${mesesCortos[local.month - 1]} ${local.year}';
}

const mesesLargos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
