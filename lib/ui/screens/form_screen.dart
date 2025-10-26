import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/planillas_repository.dart';
import '../../data/models/lectura.dart';

class FormScreen extends StatefulWidget {
  final String planillaId;
  const FormScreen({super.key, required this.planillaId});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instCtrl = TextEditingController();
  final _lectCtrl = TextEditingController();

  @override
  void dispose() {
    _instCtrl.dispose();
    _lectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();

    final p = repo.findById(widget.planillaId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva planilla')),
        body: const Center(child: Text('Planilla no encontrada')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Nueva lectura (${p.tipoMedicion})')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _instCtrl,
                decoration: const InputDecoration(labelText: 'Instrumento'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              TextFormField(
                controller: _lectCtrl,
                decoration: const InputDecoration(labelText: 'Lectura'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  repo.addLectura(
                    widget.planillaId,
                    Lectura(instrumento: _instCtrl.text.trim(), valor: _lectCtrl.text.trim()),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lectura guardada en borrador ✅')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
