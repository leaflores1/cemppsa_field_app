import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/planillas_repository.dart';
import '../../data/models/planilla.dart';

class SentListScreen extends StatelessWidget {
  const SentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final items = repo.byEstado(PlanillaEstado.sent);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviadas')),
      body: items.isEmpty
          ? const Center(child: Text('Aún no hay planillas enviadas.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = items[i];
                return ListTile(
                  title: Text(p.tipoMedicion),
                  subtitle: Text('Téc.: ${p.tecnico}  •  Lecturas: ${p.lecturas.length}'),
                );
              },
            ),
    );
  }
}
