// ==============================================================================
// CEMPPSA Field App - Repositorio de planillas enviadas
// Pestaña "Enviada": tarjetas por familia -> lista de la familia por mes.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/planilla.dart';
import '../../repositories/planilla_repository.dart';
import '../../utils/planilla_family.dart';
import '../../utils/planillas_enviadas_grouping.dart';
import '../widgets/planilla_card.dart';

const _bgColor = Color(0xFF0F172A);
const _surfaceColor = Color(0xFF1E293B);
const _borderColor = Color(0xFF334155);
const _accentColor = Color(0xFF22C55E);

/// Abre el detalle de una planilla en modo lectura.
void abrirDetallePlanilla(BuildContext context, Planilla planilla,
    {required bool editable}) {
  Navigator.pushNamed(
    context,
    '/planilla-detail',
    arguments: {'planilla': planilla, 'editable': editable},
  );
}

/// Diálogo de confirmación y borrado local de una planilla.
void confirmarEliminarPlanilla(BuildContext context, Planilla planilla) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _surfaceColor,
      title: const Text('¿Eliminar planilla?',
          style: TextStyle(color: Colors.white)),
      content: Text(
        '${planilla.tipo.displayName}\n${planilla.totalLecturas} lecturas',
        style: TextStyle(color: Colors.grey[400]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await context.read<PlanillaRepository>().delete(planilla.batchUuid);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Planilla eliminada'),
                backgroundColor: Color(0xFFEF4444),
              ),
            );
          },
          child: const Text('Eliminar',
              style: TextStyle(color: Color(0xFFEF4444))),
        ),
      ],
    ),
  );
}

// =============================================================================
// Nivel 1: tarjetas por familia
// =============================================================================

class EnviadasPorFamiliaView extends StatelessWidget {
  final List<Planilla> planillas;

  const EnviadasPorFamiliaView({super.key, required this.planillas});

  @override
  Widget build(BuildContext context) {
    final familias = resumirPorFamilia(planillas);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: familias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final familia = familias[index];
        return _FamiliaCard(
          familia: familia,
          onTap: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(
              builder: (_) => EnviadasFamiliaScreen(group: familia.group),
            ),
          ),
        );
      },
    );
  }
}

class _FamiliaCard extends StatelessWidget {
  final PlanillaFamilySummary familia;
  final VoidCallback onTap;

  const _FamiliaCard({required this.familia, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = familia.count;
    return Material(
      color: _surfaceColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('familia-enviadas-${familia.group.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.folder_outlined,
                    color: _accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familia.group.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count ${count == 1 ? 'planilla' : 'planillas'} · '
                      'Última: ${formatFechaCorta(familia.ultimaFecha)}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Nivel 2: lista de una familia, agrupada por mes (con filtro por eje)
// =============================================================================

class EnviadasFamiliaScreen extends StatefulWidget {
  final PlanillaFamilyGroup group;

  const EnviadasFamiliaScreen({super.key, required this.group});

  @override
  State<EnviadasFamiliaScreen> createState() => _EnviadasFamiliaScreenState();
}

class _EnviadasFamiliaScreenState extends State<EnviadasFamiliaScreen> {
  /// null = todos los ejes.
  String? _eje;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.group.label),
      ),
      body: Consumer<PlanillaRepository>(
        builder: (context, repo, _) {
          final familia = repo.enviadas
              .where((p) =>
                  planillaFamilyGroupFromTipo(p.tipo).id == widget.group.id)
              .toList();
          if (familia.isEmpty) {
            return const Center(
              child: Text(
                'No quedan planillas enviadas de esta familia',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            );
          }

          final ejes = ejesDisponibles(familia);
          final ejeActivo = ejes.contains(_eje) ? _eje : null;
          final visibles = ejeActivo == null
              ? familia
              : familia.where((p) => ejeKey(p) == ejeActivo).toList();
          final meses = agruparPorMes(visibles);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (ejes.isNotEmpty) _buildEjeChips(ejes, ejeActivo),
              for (final mes in meses) ...[
                _MesHeader(label: mes.label, count: mes.planillas.length),
                for (final planilla in mes.planillas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PlanillaCard(
                      planilla: planilla,
                      onTap: () => abrirDetallePlanilla(context, planilla,
                          editable: false),
                      onDelete: () =>
                          confirmarEliminarPlanilla(context, planilla),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEjeChips(List<String> ejes, String? activo) {
    Widget chip(String label, String? value) {
      final selected = activo == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _eje = value),
          backgroundColor: _surfaceColor,
          selectedColor: const Color(0xFF3B82F6),
          side: const BorderSide(color: _borderColor),
          showCheckmark: false,
          labelStyle: TextStyle(
            color: selected ? Colors.white : const Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('Todos', null),
            for (final eje in ejes)
              chip(eje == sinEjeKey ? 'Sin eje' : 'Eje $eje', eje),
          ],
        ),
      ),
    );
  }
}

class _MesHeader extends StatelessWidget {
  final String label;
  final int count;

  const _MesHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
