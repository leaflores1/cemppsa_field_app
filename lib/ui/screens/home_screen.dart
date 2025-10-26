import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import 'planillas_hub_screen.dart';
import 'ingest_hub_screen.dart';
import 'form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('CEMPPSA Field'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HomeCard(
              title: 'Mis planillas',
              subtitle:
                  'Accedé a tus planillas guardadas, enviadas o en progreso.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: 'Borradores',
                        value: repo.countDrafts,
                        color: Colors.grey,
                      ),
                      _StatusChip(
                        label: 'Enviando',
                        value: repo.countSending,
                        color: Colors.orange,
                      ),
                      _StatusChip(
                        label: 'Enviadas',
                        value: repo.countSent,
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final newId =
                          context.read<PlanillasRepository>().createDraft();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormScreen(planillaId: newId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Crear planilla'),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanillasHubScreen()),
                );
              },
            ),
            const SizedBox(height: 24),
            _HomeCard(
              title: 'Enviar desde otra fuente',
              subtitle:
                  'Exportá o enviá datos manualmente: CSV, fotos o email.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _QuickButton(
                    icon: Icons.upload_file, // compat
                    label: 'Exportar CSV',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const IngestHubScreen()),
                      );
                    },
                  ),
                  _QuickButton(
                    icon: Icons.camera_alt, // compat
                    label: 'Subir captura',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función "Subir captura" próximamente'),
                        ),
                      );
                    },
                  ),
                  _QuickButton(
                    icon: Icons.email, // compat
                    label: 'Enviar por mail',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Función "Enviar por mail" próximamente'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IngestHubScreen()),
                );
              },
            ),
          ],
        ),
      ),

      // FAB extra (con la misma acción de crear)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final newId = context.read<PlanillasRepository>().createDraft();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FormScreen(planillaId: newId)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ---------- UI helpers ----------

class _HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int value;
  final MaterialColor color; // usamos MaterialColor para shades

  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.shade100,
      labelStyle: TextStyle(color: color.shade800),
      avatar: CircleAvatar(backgroundColor: color.shade300, radius: 6),
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
