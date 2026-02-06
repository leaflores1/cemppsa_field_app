// ==============================================================================
// CEMPPSA Field App - PlanillaCard
// Card para mostrar resumen de una planilla en listas
// ==============================================================================

import 'package:flutter/material.dart';
import '../../data/models/planilla.dart';
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
                          planilla.tipo.displayName,
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

              // Info: Fecha y UUID
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(planilla.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const Spacer(),
                  Icon(Icons.fingerprint, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    planilla.batchUuid.substring(0, 8).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Error message si existe
              if (planilla.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
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
                        label: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                      ),
                    if (onDelete != null)
                      TextButton.icon(
                        onPressed: onDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Eliminar', style: TextStyle(fontSize: 12)),
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
      case PlanillaEstado.error:
        return const Color(0xFFEF4444).withOpacity(0.3);
      case PlanillaEstado.enviada:
        return const Color(0xFF22C55E).withOpacity(0.3);
      case PlanillaEstado.pendiente:
      case PlanillaEstado.enviando:
        return const Color(0xFFF59E0B).withOpacity(0.3);
      default:
        return const Color(0xFF334155);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

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
        color: config.color.withOpacity(0.15),
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
