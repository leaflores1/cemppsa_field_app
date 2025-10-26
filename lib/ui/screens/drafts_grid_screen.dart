import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import '../../data/models/planilla.dart';
import '../widgets/planilla_card.dart';
import 'planilla_detail_screen.dart';

class DraftsGridScreen extends StatelessWidget {
  const DraftsGridScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final items = repo.byEstado(PlanillaEstado.draft);

    return Scaffold(
      appBar: AppBar(title: const Text('Borradores')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: items.isEmpty
            ? const Center(
                child: Text('No hay planillas en estado "Borradores".'),
              )
            : GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (context, i) {
                  final p = items[i];
                  return PlanillaCard(
                    planilla: p,
                    estado: 'Borrador', // parámetro agregado correctamente
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlanillaDetailScreen(
                            planillaId: p.id,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
