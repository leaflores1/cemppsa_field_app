import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/planilla.dart';
import '../../data/models/lectura.dart';
import '../../repositories/planillas_repository.dart';
import '../screens/form_screen.dart';

class PlanillaCard extends StatelessWidget {
  final Planilla planilla;
  const PlanillaCard({super.key, required this.planilla});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(planilla.tipoMedicion,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              _EstadoChip(estado: planilla.estado),
            ],
          ),
          const SizedBox(height: 4),
          Text('Fecha: ${df.format(planilla.fecha)} — Técnico: ${planilla.tecnico}',
              style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 12),

          // Lecturas
          if (planilla.lecturas.isEmpty)
            Text('Sin lecturas aún',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic))
          else
            Column(
              children: [
                for (var i = 0; i < planilla.lecturas.length; i++)
                  _lecturaTile(context, i, planilla.lecturas[i]),
              ],
            ),

          const Divider(height: 20),

          // Botones de acción
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Agregar lectura'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FormScreen(planillaId: planilla.id),
                    ),
                  );
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modificar lectura'),
                onPressed: () => _editarLecturaDialog(context),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.send),
                label: const Text('Enviar'),
                onPressed: () =>
                    context.read<PlanillasRepository>().enviarPlanilla(planilla.id),
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar planilla'),
                onPressed: () async {
                  final ok = await _confirm(context,
                      '¿Eliminar planilla?', 'Se borrará definitivamente.');
                  if (!ok) return;
                  // ignore: use_build_context_synchronously
                  context.read<PlanillasRepository>().deletePlanilla(planilla.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lecturaTile(BuildContext context, int index, Lectura l) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.analytics),
      title: Text('${l.instrumento}'),
      subtitle: Text('Valor: ${l.valor}'),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          final ok =
              await _confirm(context, 'Eliminar lectura', '¿Eliminar esta lectura?');
          if (!ok) return;
          // ignore: use_build_context_synchronously
          context.read<PlanillasRepository>().deleteLectura(planilla.id, index);
        },
      ),
    );
  }

  Future<void> _editarLecturaDialog(BuildContext context) async {
    final repo = context.read<PlanillasRepository>();
    final p = repo.findById(planilla.id);
    if (p == null || p.lecturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay lecturas para modificar')),
      );
      return;
    }

    int selected = p.lecturas.length - 1; // por defecto, la última
    final instCtrl = TextEditingController(text: p.lecturas[selected].instrumento);
    final valorCtrl = TextEditingController(text: p.lecturas[selected].valor);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modificar lectura'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Seleccionar lectura'),
                  value: selected,
                  items: List.generate(
                    p.lecturas.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text('Lectura #${i + 1} (${p.lecturas[i].instrumento})'),
                    ),
                  ),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      selected = v;
                      instCtrl.text = p.lecturas[v].instrumento;
                      valorCtrl.text = p.lecturas[v].valor;
                    });
                  },
                ),
                TextField(
                  controller: instCtrl,
                  decoration: const InputDecoration(labelText: 'Instrumento'),
                ),
                TextField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(labelText: 'Valor'),
                  keyboardType: TextInputType.number,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              repo.updateLectura(
                planilla.id,
                selected,
                Lectura(instrumento: instCtrl.text.trim(), valor: valorCtrl.text.trim()),
              );
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String msg) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aceptar')),
        ],
      ),
    );
    return ok ?? false;
    }
}

class _EstadoChip extends StatelessWidget {
  final PlanillaEstado estado;
  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color bg;
    String label;
    switch (estado) {
      case PlanillaEstado.draft:
        bg = Colors.grey.shade200;
        label = 'Borrador';
        break;
      case PlanillaEstado.sending:
        bg = Colors.orange.shade200;
        label = 'Enviando';
        break;
      case PlanillaEstado.sent:
        bg = Colors.green.shade200;
        label = 'Enviada';
        break;
    }
    return Chip(
      backgroundColor: bg,
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}
