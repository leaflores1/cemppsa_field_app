import 'package:flutter/material.dart';
import '../../data/models/planilla.dart';

class EstadoChip extends StatelessWidget {
  final PlanillaEstado estado;
  const EstadoChip({super.key, required this.estado});

  (String label, Color tone) _tone() {
    return switch (estado) {
      PlanillaEstado.draft => ('Borrador', const Color(0xFF94A3B8)), // slate
      PlanillaEstado.sending => ('Enviando', const Color(0xFFFBBF24)), // amber
      PlanillaEstado.sent => ('Enviada', const Color(0xFF34D399)), // emerald
    };
  }

  @override
  Widget build(BuildContext context) {
    final (label, tone) = _tone();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tone.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 8,
            width: 8,
            decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
