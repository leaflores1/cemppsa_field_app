import 'package:flutter/material.dart';
import 'export_csv_screen.dart';

class IngestHubScreen extends StatelessWidget {
  const IngestHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar desde otra fuente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportCsvScreen()),
              ),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Exportar CSV'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _soon(context),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Subir captura/foto'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _soon(context),
              icon: const Icon(Icons.email_outlined),
              label: const Text('Enviar por mail'),
            ),
          ],
        ),
      ),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Funcionalidad próximamente')),
    );
  }
}
