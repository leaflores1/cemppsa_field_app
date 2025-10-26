import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/planillas_repository.dart';

class ExportCsvScreen extends StatefulWidget {
  const ExportCsvScreen({super.key});

  @override
  State<ExportCsvScreen> createState() => _ExportCsvScreenState();
}

class _ExportCsvScreenState extends State<ExportCsvScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final items = repo.all();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Exportar CSV'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedId,
              decoration: const InputDecoration(labelText: 'Elegir planilla'),
              items: items
                  .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.tipoMedicion} - ${p.tecnico}'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedId = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectedId == null
                  ? null
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('CSV generado (stub)')),
                      );
                    },
              icon: const Icon(Icons.download),
              label: const Text('Generar/Descargar CSV'),
            ),
          ],
        ),
      ),
    );
  }
}
