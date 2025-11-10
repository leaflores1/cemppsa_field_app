import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/lectura.dart';
import '../../data/models/planilla.dart';
import '../../repositories/planillas_repository.dart';
import '../../repositories/catalog_repository.dart';

class InstrumentQuickList extends StatefulWidget {
  final Planilla planilla;
  const InstrumentQuickList({super.key, required this.planilla});

  @override
  State<InstrumentQuickList> createState() => _InstrumentQuickListState();
}

class _InstrumentQuickListState extends State<InstrumentQuickList> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String code, {String? initial}) {
    if (_controllers.containsKey(code)) return _controllers[code]!;
    final c = TextEditingController(text: initial ?? '');
    _controllers[code] = c;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogRepository>();
    final repo = context.watch<PlanillasRepository>();

    final p = widget.planilla;
    final codes = catalog.codesFor(p.tipoMedicion);

    if (codes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _box(context),
        child: const Text('No hay códigos precargados para este instrumento.'),
      );
    }

    return Container(
      decoration: _box(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, i) {
          final code = codes[i];

          // ¿Existe ya una lectura para este código?
          final idx = p.lecturas.indexWhere((l) => l.instrumento == code);
          final existing = idx >= 0 ? p.lecturas[idx] : null;

          final ctrl = _controllerFor(
            code,
            initial: existing?.valor == null ? '' : existing!.valor.toString(),
          );

          return Row(
            children: [
              // Código
              SizedBox(
                width: 80,
                child: Text(
                  code,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              // Input de valor
              Expanded(
                child: TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Valor',
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Guardar/Actualizar
              IconButton(
                tooltip: existing == null ? 'Agregar' : 'Actualizar',
                icon: const Icon(Icons.save_alt),
                onPressed: () {
                  final text = ctrl.text.trim();
                  final val = double.tryParse(text.replaceAll(',', '.'));
                  if (val == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Número inválido')),
                    );
                    return;
                  }
                  final lectura = Lectura(
                    id: existing?.id ?? DateTime.now().millisecondsSinceEpoch,
                    instrumento: code,
                    parametro: existing?.parametro ?? 'nivel',
                    unidad: existing?.unidad ?? 'm',
                    valor: val,
                    fecha: existing?.fecha ?? DateTime.now(),
                    notas: existing?.notas,
                  );

                  if (existing == null) {
                    repo.addLectura(p.id, lectura);
                  } else {
                    repo.updateLectura(p.id, idx, lectura);
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(existing == null
                          ? 'Lectura $code agregada'
                          : 'Lectura $code actualizada'),
                    ),
                  );
                },
              ),

              // Eliminar (si existe)
              IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: existing == null
                    ? null
                    : () {
                        repo.deleteLectura(p.id, idx);
                        ctrl.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lectura $code eliminada')),
                        );
                      },
              ),
            ],
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemCount: codes.length,
      ),
    );
  }

  BoxDecoration _box(BuildContext context) => BoxDecoration(
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
