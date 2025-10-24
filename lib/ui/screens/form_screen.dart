import 'package:flutter/material.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _instrumento;
  String? _lectura;
  String? _observaciones;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Planilla')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Instrumento'),
                onSaved: (value) => _instrumento = value,
                validator: (value) =>
                    value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Lectura'),
                keyboardType: TextInputType.number,
                onSaved: (value) => _lectura = value,
                validator: (value) =>
                    value!.isEmpty ? 'Campo requerido' : null,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Observaciones'),
                onSaved: (value) => _observaciones = value,
                maxLines: 3,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _guardarPlanilla,
                icon: const Icon(Icons.save),
                label: const Text('Guardar localmente'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _guardarPlanilla() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Planilla guardada localmente ✅')),
      );
      Navigator.pop(context);
    }
  }
}
