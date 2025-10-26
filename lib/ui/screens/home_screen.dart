import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import 'form_screen.dart';
import 'planillas_hub_screen.dart';
import 'ingest_hub_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();

    Future<void> _crearPlanillaFlow() async {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const _NuevaPlanillaDialog(),
      );

      if (result == null) return;

      final newId = context.read<PlanillasRepository>().createDraft(
            tipoMedicion: result['instrumento']!,
            tecnico: result['tecnico']!,
          );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FormScreen(planillaId: newId)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],

      // --- APP BAR solo con el logo centrado ---
appBar: AppBar(
  centerTitle: true,
  automaticallyImplyLeading: false, // oculta la flecha atrás si no la querés
  title: Padding(
    padding: const EdgeInsets.only(top: 12), // ajustá este valor para bajarlo
    child: Image.asset(
      'assets/images/cemppsa_logo.png',
      height: 90, // ajustá el tamaño del logo
      fit: BoxFit.contain,
    ),
  ),
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
                    onPressed: _crearPlanillaFlow,
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
                    icon: Icons.upload_file,
                    label: 'Exportar CSV',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const IngestHubScreen()),
                    ),
                  ),
                  _QuickButton(
                    icon: Icons.camera_alt,
                    label: 'Subir captura',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Función "Subir captura" próximamente'),
                      ),
                    ),
                  ),
                  _QuickButton(
                    icon: Icons.email,
                    label: 'Enviar por mail',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Función "Enviar por mail" próximamente'),
                      ),
                    ),
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

      floatingActionButton: FloatingActionButton(
        onPressed: _crearPlanillaFlow,
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
  final MaterialColor color;

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

  const _QuickButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

// ---------- Diálogo de nueva planilla ----------

class _NuevaPlanillaDialog extends StatefulWidget {
  const _NuevaPlanillaDialog();

  @override
  State<_NuevaPlanillaDialog> createState() => _NuevaPlanillaDialogState();
}

class _NuevaPlanillaDialogState extends State<_NuevaPlanillaDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _instrumento;
  final _tecnicoCtrl = TextEditingController();

  final _instrumentos = const [
    'Piezómetros',
    'Freatímetro',
    'Acelerómetro',
    'Aforadores',
    'Caudalímetro',
  ];

  @override
  void dispose() {
    _tecnicoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva Planilla'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Instrumento'),
              items: _instrumentos
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              value: _instrumento,
              onChanged: (v) => setState(() => _instrumento = v),
              validator: (v) =>
                  v == null ? 'Seleccione un instrumento' : null,
            ),
            TextFormField(
              controller: _tecnicoCtrl,
              decoration:
                  const InputDecoration(labelText: 'Nombre del técnico'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(context, {
              'instrumento': _instrumento!,
              'tecnico': _tecnicoCtrl.text.trim(),
            });
          },
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
