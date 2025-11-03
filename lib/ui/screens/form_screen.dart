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
  final _valorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  String _parametro = 'nivel';
  String _unidad = 'm';

  @override
  void dispose() {
    _instCtrl.dispose();
    _valorCtrl.dispose();
    _notasCtrl.dispose();
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
      appBar: AppBar(title: Text('Lecturas (${p.tipoMedicion})')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Técnico: ${p.tecnico}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Fecha: ${p.fecha}'),
              const SizedBox(height: 16),

              TextFormField(
                controller: _instCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código del instrumento (instrument_code)',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _parametro,
                decoration: const InputDecoration(labelText: 'Parámetro'),
                items: const [
                  DropdownMenuItem(value: 'nivel', child: Text('nivel')),
                  DropdownMenuItem(value: 'presion', child: Text('presion')),
                  DropdownMenuItem(value: 'caudal', child: Text('caudal')),
                  DropdownMenuItem(value: 'temperatura', child: Text('temperatura')),
                ],
                onChanged: (v) => setState(() => _parametro = v ?? 'nivel'),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _unidad,
                decoration: const InputDecoration(labelText: 'Unidad'),
                items: const [
                  DropdownMenuItem(value: 'm', child: Text('m')),
                  DropdownMenuItem(value: 'cm', child: Text('cm')),
                  DropdownMenuItem(value: 'mm', child: Text('mm')),
                  DropdownMenuItem(value: '°C', child: Text('°C')),
                  DropdownMenuItem(value: 'm3/s', child: Text('m3/s')),
                ],
                onChanged: (v) => setState(() => _unidad = v ?? 'm'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _valorCtrl,
                decoration: const InputDecoration(labelText: 'Valor'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final x = double.tryParse(v.replaceAll(',', '.'));
                  if (x == null) return 'Número inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
              ),
              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final valorNum =
                      double.parse(_valorCtrl.text.replaceAll(',', '.'));

                  repo.addLectura(
                    widget.planillaId,
                    Lectura(
                      instrumento: _instCtrl.text.trim(),
                      parametro: _parametro,
                      unidad: _unidad,
                      valor: valorNum,
                      fecha: DateTime.now(), // measured_at
                      notas: _notasCtrl.text.trim().isEmpty
                          ? null
                          : _notasCtrl.text.trim(),
                    ),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lectura guardada ✅')),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Guardar lectura'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
