import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/planilla.dart';
import '../screens/planilla_detail_screen.dart';

class PlanillaCard extends StatelessWidget {
  final Planilla planilla;
  const PlanillaCard({super.key, required this.planilla});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final (bg, fg, label) = switch (planilla.estado) {
      PlanillaEstado.draft => (Colors.grey.shade100, Colors.grey.shade800, 'Borrador'),
      PlanillaEstado.sending => (Colors.orange.shade100, Colors.orange.shade800, 'Enviando'),
      PlanillaEstado.sent => (Colors.green.shade100, Colors.green.shade800, 'Enviada'),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(subtitle),
      ],
    );
  }
}
