import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import '../../data/models/planilla.dart';
import '../widgets/planilla_card.dart';

/// Pantalla reutilizable para listar planillas por estado.
/// Acepta [estado] (por defecto: draft) y un callback [onTap] opcional.
class DraftsGridScreen extends StatelessWidget {
  final PlanillaEstado estado;
  final void Function(Planilla)? onTap;

  const DraftsGridScreen({
    super.key,
    this.estado = PlanillaEstado.draft,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = switch (estado) {
      PlanillaEstado.draft => 'Borradores',
      PlanillaEstado.sending => 'Enviando',
      PlanillaEstado.sent => 'Enviadas',
    };

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Consumer<PlanillasRepository>(
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

          // Si querés grid, podés cambiar por GridView.builder con crossAxisCount dinámico.
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              return InkWell(
                onTap: onTap != null ? () => onTap!(p) : null,
                child: PlanillaCard(planilla: p),
              );
            },
          );
        },
      ),
    );
  }
}
