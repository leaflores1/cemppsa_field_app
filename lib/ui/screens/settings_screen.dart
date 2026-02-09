// ==============================================================================
// CEMPPSA Field App - SettingsScreen
// Pantalla de configuración de la app (desacoplada de SyncService)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../repositories/planilla_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../utils/csv_exporter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _technicianController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _technicianController.text = AppConfig.technicianId ?? '';
  }

  @override
  void dispose() {
    _technicianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Configuración'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // =========================
          // USUARIO
          // =========================
          const _SectionHeader(title: 'USUARIO'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _TextFieldTile(
                label: 'ID del Técnico',
                hint: 'Ej: tecnico_juan',
                controller: _technicianController,
                onChanged: (v) => AppConfig.technicianId = v,
              ),
              const Divider(color: Color(0xFF334155)),
              _InfoTile(
                label: 'Device ID',
                value: AppConfig.deviceId ?? 'No generado',
                onCopy: () => _copyToClipboard(AppConfig.deviceId ?? ''),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // =========================
          // SERVIDOR
          // =========================
          const _SectionHeader(title: 'SERVIDOR'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: const [
              _InfoTile(
                label: 'URL del servidor',
                value: ApiConfig.baseUrl,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // =========================
          // DATOS LOCALES
          // =========================
          const _SectionHeader(title: 'DATOS LOCALES'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              Consumer<CatalogRepository>(
                builder: (_, catalog, __) => _InfoTile(
                  label: 'Catálogo de instrumentos',
                  value: '${catalog.totalInstrumentos} instrumentos',
                  trailing: TextButton(
                    onPressed: catalog.isSyncing
                        ? null
                        : () => _refreshCatalog(catalog),
                    child: const Text('Actualizar'),
                  ),
                ),
              ),
              const Divider(color: Color(0xFF334155)),
              Consumer<PlanillaRepository>(
                builder: (_, repo, __) {
                  final total = repo.all().length;
                  return _InfoTile(
                    label: 'Planillas almacenadas',
                    value: '$total total',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // =========================
          // MANTENIMIENTO
          // =========================
          const _SectionHeader(title: 'MANTENIMIENTO'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _ActionTile(
                icon: Icons.cleaning_services_outlined,
                label: 'Limpiar planillas enviadas',
                subtitle: 'Elimina planillas enviadas hace más de 30 días',
                onTap: _cleanOldPlanillas,
              ),
              const Divider(color: Color(0xFF334155)),
              _ActionTile(
                icon: Icons.delete_sweep_outlined,
                label: 'Limpiar exports antiguos',
                subtitle: 'Elimina CSV exportados hace mas de 30 dias',
                onTap: _cleanOldExports,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // =========================
          // ACERCA DE
          // =========================
          const _SectionHeader(title: 'ACERCA DE'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: const [
              _InfoTile(
                label: 'Aplicación',
                value: AppConfig.appName,
              ),
              Divider(color: Color(0xFF334155)),
              _InfoTile(
                label: 'Versión',
                value: AppConfig.version,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ===========================================================================
  // Acciones
  // ===========================================================================

  static void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _refreshCatalog(CatalogRepository catalog) async {
    final ok = await catalog.syncFromBackend();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Catálogo actualizado' : 'Error al sincronizar catálogo',
        ),
        backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _cleanOldPlanillas() async {
    final repo = context.read<PlanillaRepository>();
    final deleted = await repo.limpiarEnviadas(diasAntiguedad: 30);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deleted planillas eliminadas'),
        backgroundColor: const Color(0xFF22C55E),
      ),
    );
  }

  Future<void> _cleanOldExports() async {
    final deleted = await CsvExporter.cleanOldExports(daysOld: 30);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$deleted exports eliminados'),
        backgroundColor: const Color(0xFF22C55E),
      ),
    );
  }
}

// ============================================================================
// Widgets auxiliares
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(children: children),
    );
  }
}

class _TextFieldTile extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _TextFieldTile({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;
  final Widget? trailing;

  const _InfoTile({
    required this.label,
    required this.value,
    this.onCopy,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[500]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
