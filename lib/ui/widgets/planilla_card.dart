import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/planilla.dart';
import '../screens/planilla_detail_screen.dart';
import 'estado_chip.dart';

class PlanillaCard extends StatelessWidget {
  final Planilla planilla;
  const PlanillaCard({super.key, required this.planilla});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlanillaDetailScreen(planillaId: planilla.id)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TitleSubtitle(
                title: planilla.tipoMedicion,
                subtitle: 'Téc.: ${planilla.tecnico} • ${df.format(planilla.fecha)}',
              ),
            ),
            const SizedBox(width: 12),
            EstadoChip(estado: planilla.estado),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.55)),
          ],
        ),
      ),
    );
  }
}

class _TitleSubtitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _TitleSubtitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle, style: t.bodySmall),
      ],
    );
  }
}
