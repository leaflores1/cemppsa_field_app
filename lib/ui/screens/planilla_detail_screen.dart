import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/planillas_repository.dart';
import 'form_screen.dart';

class PlanillaDetailScreen extends StatelessWidget {
  final String planillaId;
  const PlanillaDetailScreen({super.key, required this.planillaId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final p = repo.findById(planillaId);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planilla')),
        body: const Center(child: Text('Planilla no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(p.tipoMedicion)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(p.tecnico),
            subtitle: Text('Fecha: ${p.fecha.toLocal()}'),
          ),
          const Divider(),
          ...List.generate(p.lecturas.length, (i) {
            final l = p.lecturas[i];
            return ListTile(
              dense: true,
              title: Text(l.instrumento),
              trailing: Text(l.valor),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FormScreen(planillaId: p.id),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar lectura'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => repo.enviarPlanilla(p.id),
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );
  }
}
