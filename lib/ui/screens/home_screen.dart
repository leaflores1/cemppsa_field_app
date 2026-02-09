// ==============================================================================
// CEMPPSA Field App - HomeScreen
// Pantalla principal desacoplada de SyncService
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/catalogo_repository.dart';
import '../../repositories/planilla_repository.dart';
import '../../services/sync_service.dart';
import '../widgets/connectivity_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Verificar conexión al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncService>().checkConnection();
    });
  }

  Future<void> _syncPendientes() async {
    final syncService = context.read<SyncService>();
    final planillaRepo = context.read<PlanillaRepository>();

    if (syncService.isSyncing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya hay una sincronización en curso'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    if (planillaRepo.pendientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay planillas pendientes'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Sincronizando ${planillaRepo.pendientes.length} planillas...'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );

    final result = await syncService.syncAll(
      planillaRepo,
      catalog: context.read<CatalogRepository>(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.hasErrors
              ? const Color(0xFFEF4444)
              : const Color(0xFF22C55E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // slate-900
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),

            // Banner de conectividad (fuente única de verdad)
            const SliverToBoxAdapter(
              child: ConnectivityBanner(),
            ),

            // ===============================
            // CARGA DE DATOS
            // ===============================
            SliverToBoxAdapter(
              child: _sectionTitle('CARGAR DATOS'),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _FlowCard(
                      title: 'Lecturas Manuales',
                      subtitle: 'Casagrande · Freatímetros · Aforadores',
                      description: 'Carga manual de instrumentos',
                      icon: Icons.edit_note_rounded,
                      color: const Color(0xFF3B82F6),
                      onTap: () =>
                          Navigator.pushNamed(context, '/manual-reading'),
                    ),
                    const SizedBox(height: 12),
                    _FlowCard(
                      title: 'CR10X',
                      subtitle: 'Piezómetros · Asentímetros · Clinometros',
                      description: 'Inspección manual del datalogger CR10X',
                      icon: Icons.backup_table_rounded,
                      color: const Color(0xFFF59E0B),
                      isSecondary: true,
                      onTap: () => Navigator.pushNamed(context, '/cr10x-batch'),
                    ),
                  ],
                ),
              ),
            ),

            // ===============================
            // PLANILLAS
            // ===============================
            SliverToBoxAdapter(
              child: _sectionTitleWithAction(
                context,
                title: 'MIS PLANILLAS',
                actionLabel: 'Ver todas →',
                route: '/planillas',
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _buildPlanillasResumen(),
              ),
            ),

            // ===============================
            // ACCIONES
            // ===============================
            SliverToBoxAdapter(
              child: _sectionTitle('ACCIONES'),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.sync_outlined,
                        label: 'Sincronizar',
                        onTap: _syncPendientes,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.file_download_outlined,
                        label: 'Exportar',
                        onTap: () => Navigator.pushNamed(context, '/export'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.settings_outlined,
                        label: 'Ajustes',
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(child: _buildFooter()),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // UI SECTIONS
  // ============================================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'C',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CEMPPSA Field',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Sistema de Auscultación',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanillasResumen() {
    return Consumer<PlanillaRepository>(
      builder: (_, repo, __) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            children: [
              _StatTile(
                label: 'Borradores',
                value: repo.borradores.length.toString(),
                icon: Icons.edit_outlined,
                color: const Color(0xFF94A3B8),
                onTap: () => Navigator.pushNamed(context, '/drafts'),
              ),
              _divider(),
              _StatTile(
                label: 'Pendientes',
                value: repo.pendientes.length.toString(),
                icon: Icons.schedule_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => Navigator.pushNamed(context, '/pending'),
              ),
              _divider(),
              _StatTile(
                label: 'Enviadas',
                value: repo.enviadas.length.toString(),
                icon: Icons.check_circle_outline,
                color: const Color(0xFF22C55E),
                onTap: () => Navigator.pushNamed(context, '/sent'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          Divider(color: Color(0xFF334155)),
          SizedBox(height: 8),
          Text(
            'CEMPPSA · Potrerillos · v2.0.0',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _sectionTitleWithAction(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, route),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3B82F6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 50, color: const Color(0xFF334155));
}

// ==============================================================================
// COMPONENTES
// ==============================================================================

class _FlowCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSecondary;

  const _FlowCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSecondary
                  ? const Color(0xFF334155)
                  : color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: color, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(description,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: 16),
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: Colors.grey),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
