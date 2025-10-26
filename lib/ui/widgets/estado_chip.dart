import 'package:flutter/material.dart';
import '../../data/models/planilla.dart';

class EstadoChip extends StatelessWidget {
  final PlanillaEstado estado;
  const EstadoChip({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (estado) {
      PlanillaEstado.draft => ('Borrador', Colors.grey),
      PlanillaEstado.sending => ('Enviando', Colors.orange),
      PlanillaEstado.sent => ('Enviada', Colors.green),
    };

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withOpacity(.1),
      side: BorderSide(color: color.withOpacity(.4)),
      labelStyle: TextStyle(color: color.shade700),
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
    );
  }
}
