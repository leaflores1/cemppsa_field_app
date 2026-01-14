// ==============================================================================
// CEMPPSA Field App - EstadoChip
// Chip visual para mostrar el estado de una planilla
// ==============================================================================

import 'package:flutter/material.dart';
import '../../data/models/planilla.dart';

class EstadoChip extends StatelessWidget {
  final PlanillaEstado estado;
  final bool compact;

  const EstadoChip({
    super.key,
    required this.estado,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(estado);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        border: Border.all(
          color: config.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.showSpinner)
            SizedBox(
              width: compact ? 10 : 12,
              height: compact ? 10 : 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(config.color),
              ),
            )
          else
            Icon(
              config.icon,
              size: compact ? 12 : 14,
              color: config.color,
            ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _EstadoConfig _getConfig(PlanillaEstado estado) {
    switch (estado) {
      case PlanillaEstado.borrador:
        return _EstadoConfig(
          label: 'Borrador',
          icon: Icons.edit_outlined,
          color: const Color(0xFF94A3B8), // slate-400
        );
      case PlanillaEstado.pendiente:
        return _EstadoConfig(
          label: 'Pendiente',
          icon: Icons.schedule_outlined,
          color: const Color(0xFFF59E0B), // amber-500
        );
      case PlanillaEstado.enviando:
        return _EstadoConfig(
          label: 'Enviando...',
          icon: Icons.sync,
          color: const Color(0xFF3B82F6), // blue-500
          showSpinner: true,
        );
      case PlanillaEstado.enviada:
        return _EstadoConfig(
          label: 'Enviada',
          icon: Icons.check_circle_outline,
          color: const Color(0xFF22C55E), // green-500
        );
      case PlanillaEstado.error:
        return _EstadoConfig(
          label: 'Error',
          icon: Icons.error_outline,
          color: const Color(0xFFEF4444), // red-500
        );
    }
  }
}

class _EstadoConfig {
  final String label;
  final IconData icon;
  final Color color;
  final bool showSpinner;

  _EstadoConfig({
    required this.label,
    required this.icon,
    required this.color,
    this.showSpinner = false,
  });
}
