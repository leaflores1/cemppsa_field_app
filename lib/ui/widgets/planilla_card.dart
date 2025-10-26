import 'package:flutter/material.dart';
import '../../data/models/planilla.dart';

class PlanillaCard extends StatelessWidget {
  final Planilla planilla;
  final String estado;
  final VoidCallback onTap;

  const PlanillaCard({
    super.key,
    required this.planilla,
    required this.estado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fechaStr = '${planilla.fecha.day}/${planilla.fecha.month}/${planilla.fecha.year}';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    planilla.tipoMedicion,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _EstadoChip(estado: estado),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Téc.: ${planilla.tecnico}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Fecha: $fechaStr',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${planilla.lecturas.length} lecturas',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.blueGrey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  Color _colorPorEstado() {
    switch (estado.toLowerCase()) {
      case 'borrador':
        return Colors.grey.shade400;
      case 'enviando':
        return Colors.orange.shade400;
      case 'enviada':
      case 'enviadas':
        return Colors.green.shade400;
      default:
        return Colors.blueGrey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(estado),
      backgroundColor: _colorPorEstado(),
      visualDensity: VisualDensity.compact,
    );
  }
}
