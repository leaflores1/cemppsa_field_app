import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../repositories/planillas_repository.dart';
import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../utils/csv_exporter.dart';
import '../widgets/instrument_quick_list.dart';

class PlanillaDetailScreen extends StatelessWidget {
  final String planillaId;
  const PlanillaDetailScreen({super.key, required this.planillaId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<PlanillasRepository>();
    final p = repo.findById(planillaId);

    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Planilla')),
        body: const Center(child: Text('Planilla no encontrada')),
      );
    }

    final readOnly = p.estado != PlanillaEstado.draft;
    final df = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de planilla'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Eliminar planilla',
            onPressed: () async {
              final ok = await _confirm(
                context,
                'Eliminar planilla',
                '¿Seguro que querés eliminar esta planilla del historial?',
              );
              if (ok) {
                repo.deletePlanilla(p.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderTile(
            title: p.tipoMedicion,
            subtitle: 'Téc.: ${p.tecnico}  •  ${df.format(p.fecha)}',
            estado: p.estado,
          ),
          const SizedBox(height: 16),

          // Carga rápida por catálogo (solo en borrador)
          if (!readOnly) ...[
            Text(
              'Cargar lecturas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            InstrumentQuickList(planilla: p),
            const SizedBox(height: 16),
          ],

          // Listado de lecturas ya cargadas
          Text(
            'Lecturas cargadas',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          if (p.lecturas.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _boxDecoration(context),
              child: const Text('No hay lecturas cargadas.'),
            )
          else
            Container(
              decoration: _boxDecoration(context),
              child: Column(
                children: [
                  for (var i = 0; i < p.lecturas.length; i++)
                    _LecturaTile(
                      index: i,
                      lectura: p.lecturas[i],
                      readOnly: readOnly,
                      onEdit: readOnly
                          ? null
                          : () async {
                              final edited = await showDialog<Lectura>(
                                context: context,
                                builder: (_) => _LecturaDialog(
                                  title: 'Editar lectura',
                                  initial: p.lecturas[i],
                                ),
                              );
                              if (edited != null) {
                                repo.updateLectura(p.id, i, edited);
                              }
                            },
                      onDelete: readOnly
                          ? null
                          : () async {
                              final ok = await _confirm(
                                context,
                                'Eliminar lectura',
                                '¿Seguro que querés eliminar esta lectura?',
                              );
                              if (ok) repo.deleteLectura(p.id, i);
                            },
                    ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Acciones según estado (ocultamos "Agregar lectura" manual)
          if (!readOnly)
            FilledButton.icon(
              onPressed: p.lecturas.isEmpty
                  ? null
                  : () async {
                      await repo.enviarPlanilla(p.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Planilla enviada')),
                        );
                      }
                    },
              icon: const Icon(Icons.send),
              label: const Text('Enviar'),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: _boxDecoration(context),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta planilla es de solo lectura (enviada).',
                    ),
                  ),
                ],
              ),
            ),

          // Exportar CSV (siempre visible)
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final uri = await CsvExporter.exportPlanilla(p);
              if (context.mounted) {
                final loc = uri?.toString() ?? 'ubicación desconocida';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('CSV exportado en: $loc')),
                );
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Exportar CSV'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _confirm(
    BuildContext context,
    String title,
    String msg,
  ) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  static BoxDecoration _boxDecoration(BuildContext context) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      );
}

class _HeaderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final PlanillaEstado estado;
  const _HeaderTile({
    required this.title,
    required this.subtitle,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (estado) {
      PlanillaEstado.draft =>
        (Colors.grey.shade100, Colors.grey.shade800, 'Borrador'),
      PlanillaEstado.sending =>
        (Colors.orange.shade100, Colors.orange.shade800, 'Enviando'),
      PlanillaEstado.sent =>
        (Colors.green.shade100, Colors.green.shade800, 'Enviada'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PlanillaDetailScreen._boxDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LecturaTile extends StatelessWidget {
  final int index;
  final Lectura lectura;
  final bool readOnly;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _LecturaTile({
    required this.index,
    required this.lectura,
    required this.readOnly,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return ListTile(
      title: Text(
        '${lectura.instrumento}  •  ${lectura.parametro} (${lectura.unidad})',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Valor: ${lectura.valor}   •   Medido: ${df.format(lectura.fecha)}'
        '${(lectura.notas == null || lectura.notas!.isEmpty) ? '' : '   •   Notas: ${lectura.notas}'}',
      ),
      trailing: readOnly
          ? const Icon(Icons.lock_outline)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
    );
  }
}

class _LecturaDialog extends StatefulWidget {
  final String title;
  final Lectura? initial;
  const _LecturaDialog({required this.title, this.initial});

  @override
  State<_LecturaDialog> createState() => _LecturaDialogState();
}

class _LecturaDialogState extends State<_LecturaDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _instCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _notasCtrl;
  String _parametro = 'nivel';
  String _unidad = 'm';

  @override
  void initState() {
    super.initState();
    _instCtrl = TextEditingController(text: widget.initial?.instrumento ?? '');
    _valorCtrl = TextEditingController(
      text: widget.initial?.valor == null
          ? ''
          : widget.initial!.valor.toString(),
    );
    _notasCtrl = TextEditingController(text: widget.initial?.notas ?? '');
    _parametro = widget.initial?.parametro ?? 'nivel';
    _unidad = widget.initial?.unidad ?? 'm';
  }

  @override
  void dispose() {
    _instCtrl.dispose();
    _valorCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Código solo lectura (no se tilda a mano)
              TextFormField(
                controller: _instCtrl,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Código del instrumento',
                  helperText: 'Viene del catálogo',
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _parametro,
                decoration: const InputDecoration(labelText: 'Parámetro'),
                items: const [
                  DropdownMenuItem(value: 'nivel', child: Text('nivel')),
                  DropdownMenuItem(value: 'presion', child: Text('presión')),
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
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              ),
            ],
          ),
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
            final valorNum =
                double.parse(_valorCtrl.text.replaceAll(',', '.'));
            Navigator.pop(
              context,
              Lectura(
                id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch,
                instrumento: _instCtrl.text.trim(),
                parametro: _parametro,
                unidad: _unidad,
                valor: valorNum,
                fecha: widget.initial?.fecha ?? DateTime.now(),
                notas: _notasCtrl.text.trim().isEmpty
                    ? null
                    : _notasCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
