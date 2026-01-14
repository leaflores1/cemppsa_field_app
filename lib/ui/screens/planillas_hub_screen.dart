// ==============================================================================
// CEMPPSA Field App - PlanillasHubScreen
// Hub central de gestión de planillas (borradores, pendientes, enviadas)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/planilla.dart';
import '../../repositories/planilla_repository.dart';
import '../widgets/planilla_card.dart';

class PlanillasHubScreen extends StatefulWidget {
  const PlanillasHubScreen({super.key});

  @override
  State<PlanillasHubScreen> createState() => _PlanillasHubScreenState();
}

class _PlanillasHubScreenState extends State<PlanillasHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Mis Planillas'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Consumer<PlanillaRepository>(
            builder: (context, repo, _) {
              return TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[500],
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: [
                  _buildTab('Borrador', repo.borradores.length, const Color(0xFF94A3B8)),
                  _buildTab('Pendiente', repo.pendientes.length, const Color(0xFFF59E0B)),
                  _buildTab('Enviada', repo.enviadas.length, const Color(0xFF22C55E)),
                ],
              );
            },
          ),
        ),
      ),
      body: Consumer<PlanillaRepository>(
        builder: (context, repo, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _PlanillasList(
                planillas: repo.borradores,
                emptyIcon: Icons.edit_note_outlined,
                emptyTitle: 'Sin borradores',
                emptySubtitle: 'Las planillas en edición aparecerán aquí',
                onTap: (p) => _openDetail(p, editable: true),
                onDelete: (p) => _confirmDelete(p),
              ),
              _PlanillasList(
                planillas: repo.pendientes,
                emptyIcon: Icons.schedule_outlined,
                emptyTitle: 'Sin pendientes',
                emptySubtitle: 'Las planillas listas para enviar aparecerán aquí',
                onTap: (p) => _openDetail(p, editable: false),
                onRetry: (p) => _retrySend(p),
              ),
              _PlanillasList(
                planillas: repo.enviadas,
                emptyIcon: Icons.check_circle_outline,
                emptyTitle: 'Sin enviadas',
                emptySubtitle: 'Las planillas sincronizadas aparecerán aquí',
                onTap: (p) => _openDetail(p, editable: false),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/manual-reading'),
        backgroundColor: const Color(0xFF3B82F6),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nueva Planilla',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count, Color color) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: Color.fromRGBO(color.red, color.green, color.blue, 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDetail(Planilla planilla, {required bool editable}) {
    Navigator.pushNamed(
      context,
      '/planilla-detail',
      arguments: {'planilla': planilla, 'editable': editable},
    );
  }

  void _confirmDelete(Planilla planilla) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Eliminar planilla?', style: TextStyle(color: Colors.white)),
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
              await context.read<PlanillaRepository>().delete(planilla.batchUuid);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Planilla eliminada'),
                    backgroundColor: Color(0xFFEF4444),
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  void _retrySend(Planilla planilla) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Usá el botón Sincronizar en el inicio para reintentar'),
      ),
    );
  }
}

// =============================================================================
// Lista de planillas con estado vacío
// =============================================================================

class _PlanillasList extends StatelessWidget {
  final List<Planilla> planillas;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final void Function(Planilla) onTap;
  final void Function(Planilla)? onDelete;
  final void Function(Planilla)? onRetry;

  const _PlanillasList({
    required this.planillas,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onTap,
    this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (planillas.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: planillas.length,
      itemBuilder: (ctx, index) {
        final planilla = planillas[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PlanillaCard(
            planilla: planilla,
            onTap: () => onTap(planilla),
            onDelete: onDelete != null ? () => onDelete!(planilla) : null,
            onRetry: onRetry != null && planilla.estado == PlanillaEstado.error
                ? () => onRetry!(planilla)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: const Color(0xFF334155)),
          const SizedBox(height: 16),
          Text(
            emptyTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              emptySubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
