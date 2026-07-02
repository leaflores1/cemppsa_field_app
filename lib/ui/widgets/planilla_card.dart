// ==============================================================================
// CEMPPSA Field App - PlanillaCard
// Card para mostrar resumen de una planilla en listas
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/planilla.dart';
import '../../repositories/catalogo_repository.dart';
import '../../utils/planilla_axis.dart';
import 'estado_chip.dart';

class PlanillaCard extends StatelessWidget {
  final Planilla planilla;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRetry;

  const PlanillaCard({
    super.key,
    required this.planilla,
    this.onTap,
    this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dateSummary = _PlanillaDateSummary.fromPlanilla(planilla);
    final catalog = context.watch<CatalogRepository>();
    final title = planillaTitleWithEje(planilla, catalog);
    final observaciones = planilla.observaciones?.trim();

    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _getBorderColor(),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Tipo y Estado
              Row(
                children: [
                  _TipoIcon(tipo: planilla.tipo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${planilla.totalLecturas} lecturas',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  EstadoChip(estado: planilla.estado, compact: true),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(color: Color(0xFF334155), height: 1),
              const SizedBox(height: 12),

              // Info: fechas principales y trazabilidad
              _DateLine(
                icon: Icons.event_available_outlined,
                label: 'Medición:',
                value: dateSummary.measurementLabel,
              ),
              const SizedBox(height: 8),
              _DateLine(
                icon: dateSummary.sentFromApp
                    ? Icons.cloud_done_outlined
                    : Icons.inventory_2_outlined,
                label: dateSummary.sentLabel,
                value: _formatDateTime(dateSummary.sentOrReceivedAt),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (dateSummary.delayBadge != null)
                    _DelayBadge(info: dateSummary.delayBadge!),
                  _BatchBadge(batchUuid: planilla.batchUuid),
                ],
              ),

              if (observaciones != null && observaciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined,
                        size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        observaciones,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Error message si existe
              if (planilla.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          planilla.errorMessage!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Acciones
              if (onDelete != null || onRetry != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onRetry != null)
                      TextButton.icon(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF59E0B),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reintentar',
                            style: TextStyle(fontSize: 12)),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Eliminar',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (planilla.estado) {
      case PlanillaEstado.rechazada:
      case PlanillaEstado.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.3);
      case PlanillaEstado.enviada:
        return const Color(0xFF22C55E).withValues(alpha: 0.3);
      case PlanillaEstado.pendiente:
      case PlanillaEstado.enviando:
        return const Color(0xFFF59E0B).withValues(alpha: 0.3);
      default:
        return const Color(0xFF334155);
    }
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    return '${_formatFullDate(_DateOnly.fromDateTime(local))} · '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
}

// =============================================================================
// Fechas visibles de la card
// =============================================================================

class _PlanillaDateSummary {
  final String measurementLabel;
  final DateTime sentOrReceivedAt;
  final bool sentFromApp;
  final _DelayBadgeInfo? delayBadge;

  const _PlanillaDateSummary({
    required this.measurementLabel,
    required this.sentOrReceivedAt,
    required this.sentFromApp,
    required this.delayBadge,
  });

  String get sentLabel => sentFromApp ? 'Enviada:' : 'Recibida:';

  factory _PlanillaDateSummary.fromPlanilla(Planilla planilla) {
    final sentOrReceivedAt = planilla.lastSyncAttempt ?? planilla.createdAt;
    final measurementDates = planilla.lecturas
        .map((lectura) => _DateOnly.fromDateTime(lectura.measuredAt))
        .toList()
      ..sort();

    if (measurementDates.isEmpty) {
      return _PlanillaDateSummary(
        measurementLabel: 'sin dato',
        sentOrReceivedAt: sentOrReceivedAt,
        sentFromApp: planilla.lastSyncAttempt != null,
        delayBadge: null,
      );
    }

    final first = measurementDates.first;
    final last = measurementDates.last;
    final sentDate = _DateOnly.fromDateTime(sentOrReceivedAt);

    return _PlanillaDateSummary(
      measurementLabel: first == last
          ? _formatFullDate(first)
          : _formatDateRange(first, last),
      sentOrReceivedAt: sentOrReceivedAt,
      sentFromApp: planilla.lastSyncAttempt != null,
      delayBadge: _DelayBadgeInfo.fromDates(
        measurementDate: last,
        sentDate: sentDate,
      ),
    );
  }
}

class _DateOnly implements Comparable<_DateOnly> {
  final int year;
  final int month;
  final int day;

  const _DateOnly(this.year, this.month, this.day);

  factory _DateOnly.fromDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return _DateOnly(local.year, local.month, local.day);
  }

  DateTime get asDateTime => DateTime(year, month, day);

  @override
  int compareTo(_DateOnly other) => asDateTime.compareTo(other.asDateTime);

  @override
  bool operator ==(Object other) =>
      other is _DateOnly &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class _DelayBadgeInfo {
  final String label;
  final Color color;

  const _DelayBadgeInfo({
    required this.label,
    required this.color,
  });

  factory _DelayBadgeInfo.fromDates({
    required _DateOnly measurementDate,
    required _DateOnly sentDate,
  }) {
    final days =
        sentDate.asDateTime.difference(measurementDate.asDateTime).inDays;
    if (days <= 0) {
      return const _DelayBadgeInfo(
        label: 'Enviada el mismo día',
        color: Color(0xFF22C55E),
      );
    }
    if (days <= 3) {
      return _DelayBadgeInfo(
        label: 'Enviada +$days días',
        color: const Color(0xFFF59E0B),
      );
    }
    return _DelayBadgeInfo(
      label: 'Enviada +$days días',
      color: const Color(0xFFEF4444),
    );
  }
}

class _DateLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DateLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFFCBD5E1),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DelayBadge extends StatelessWidget {
  final _DelayBadgeInfo info;

  const _DelayBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          color: info.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BatchBadge extends StatelessWidget {
  final String batchUuid;

  const _BatchBadge({required this.batchUuid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.fingerprint,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 5),
          Text(
            batchUuid.substring(0, 8).toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatFullDate(_DateOnly date) {
  return '${_twoDigits(date.day)} ${_monthLabels[date.month - 1]} ${date.year}';
}

String _formatDateRange(_DateOnly first, _DateOnly last) {
  if (first.year == last.year) {
    return '${_twoDigits(first.day)} ${_monthLabels[first.month - 1]} – '
        '${_twoDigits(last.day)} ${_monthLabels[last.month - 1]} ${last.year}';
  }
  return '${_formatFullDate(first)} – ${_formatFullDate(last)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

const _monthLabels = [
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

// =============================================================================
// Icono de tipo de planilla
// =============================================================================

class _TipoIcon extends StatelessWidget {
  final TipoPlanilla tipo;

  const _TipoIcon({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(tipo);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(config.icon, color: config.color, size: 22),
    );
  }

  _TipoConfig _getConfig(TipoPlanilla tipo) {
    switch (tipo) {
      case TipoPlanilla.casagrande:
        return _TipoConfig(
          icon: Icons.speed_rounded,
          color: const Color(0xFF3B82F6),
        );
      case TipoPlanilla.freatimetros:
        return _TipoConfig(
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF06B6D4),
        );
      case TipoPlanilla.aforadores:
        return _TipoConfig(
          icon: Icons.waves_rounded,
          color: const Color(0xFF22C55E),
        );
      case TipoPlanilla.drenes:
        return _TipoConfig(
          icon: Icons.filter_alt_rounded,
          color: const Color(0xFF22C55E),
        );
      case TipoPlanilla.cr10xPiezometros:
        return _TipoConfig(
          icon: Icons.speed_rounded,
          color: const Color(0xFF8B5CF6),
        );
      case TipoPlanilla.cr10xAsentimetros:
        return _TipoConfig(
          icon: Icons.straighten_rounded,
          color: const Color(0xFFEC4899),
        );
      case TipoPlanilla.cr10xTriaxiales:
        return _TipoConfig(
          icon: Icons.view_in_ar_rounded,
          color: const Color(0xFF14B8A6),
        );
      case TipoPlanilla.cr10xUniaxiales:
        return _TipoConfig(
          icon: Icons.linear_scale_rounded,
          color: const Color(0xFF06B6D4),
        );
      case TipoPlanilla.cr10xTermometros:
        return _TipoConfig(
          icon: Icons.thermostat_rounded,
          color: const Color(0xFFF97316),
        );
      case TipoPlanilla.cr10xClinometros:
        return _TipoConfig(
          icon: Icons.rotate_right_rounded,
          color: const Color(0xFF6366F1),
        );
      case TipoPlanilla.cr10xLimnimetros:
        return _TipoConfig(
          icon: Icons.water_rounded,
          color: const Color(0xFF06B6D4),
        );
      case TipoPlanilla.cr10xBarometro:
        return _TipoConfig(
          icon: Icons.air_rounded,
          color: const Color(0xFF0EA5E9),
        );
      case TipoPlanilla.cr10xCeldasPresion:
        return _TipoConfig(
          icon: Icons.compress_rounded,
          color: const Color(0xFF10B981),
        );
      case TipoPlanilla.sismos:
        return _TipoConfig(
          icon: Icons.vibration_rounded,
          color: const Color(0xFFE11D48),
        );
      case TipoPlanilla.triaxiales:
        return _TipoConfig(
          icon: Icons.view_in_ar_rounded,
          color: const Color(0xFF14B8A6),
        );
      case TipoPlanilla.general:
        return _TipoConfig(
          icon: Icons.description_outlined,
          color: const Color(0xFF94A3B8),
        );
    }
  }
}

class _TipoConfig {
  final IconData icon;
  final Color color;

  _TipoConfig({required this.icon, required this.color});
}
