import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/planillas_repository.dart';
import '../../data/models/planilla.dart';

class SendingListScreen extends StatelessWidget {
  const SendingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final items = repo.byEstado(PlanillaEstado.sending);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviando')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = items[i];
          return ListTile(
            title: Text(p.tipoMedicion),
            subtitle: Text('Téc.: ${p.tecnico}  •  Lecturas: ${p.lecturas.length}'),
            trailing: TextButton.icon(
              onPressed: () => repo.enviarPlanilla(p.id),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          );
        },
      ),
    );
  }
}
