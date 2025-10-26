import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import '../../data/models/planilla.dart';
import '../widgets/planilla_card.dart';

class PlanillasHubScreen extends StatelessWidget {
  const PlanillasHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis planillas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Borradores'),
              Tab(text: 'Enviando'),
              Tab(text: 'Enviadas'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _EstadoList(estado: PlanillaEstado.draft),
            _EstadoList(estado: PlanillaEstado.sending),
            _EstadoList(estado: PlanillaEstado.sent),
          ],
        ),
      ),
    );
  }
}

class _EstadoList extends StatelessWidget {
  final PlanillaEstado estado;
  const _EstadoList({required this.estado});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanillasRepository>(
      builder: (_, repo, __) {
        final items = repo.byEstado(estado);
        if (items.isEmpty) {
          final vacio = switch (estado) {
            PlanillaEstado.draft => 'No hay borradores.',
            PlanillaEstado.sending => 'Nada enviándose ahora.',
            PlanillaEstado.sent => 'Aún no hay planillas enviadas.',
          };
          return Center(child: Text(vacio));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (_, i) => PlanillaCard(planilla: items[i]),
        );
      },
    );
  }
}
