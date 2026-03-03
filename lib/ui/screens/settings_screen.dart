// ==============================================================================
// CEMPPSA Field App - SettingsScreen
// Pantalla de configuración de la app (desacoplada de SyncService)
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../repositories/planilla_repository.dart';
import '../../repositories/catalogo_repository.dart';
import '../../services/auth_service.dart';
import '../../services/sync_service.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/server_discovery.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDiscoveringServer = false;

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
              Consumer<AuthService>(
                builder: (_, auth, __) {
                  final user = auth.currentUser;
                  return Column(
                    children: [
                      _InfoTile(
                        label: 'Nombre',
                        value: AppConfig.technicianName ??
                            user?.displayName ??
                            'Sin sesión',
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'ID técnico',
                        value:
                            AppConfig.technicianId ?? user?.id ?? 'Sin sesión',
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'Email',
                        value: user?.email ?? 'Sin sesión',
                      ),
                    ],
                  );
                },
              ),
              const Divider(color: Color(0xFF334155)),
              _InfoTile(
                label: 'Device ID',
                value: AppConfig.deviceId ?? 'No generado',
                onCopy: () => _copyToClipboard(AppConfig.deviceId ?? ''),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ),

          const SizedBox(height: 24),

          // =========================
          // SERVIDOR
          // =========================
          const _SectionHeader(title: 'SERVIDOR'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _InfoTile(
                label: 'URL del servidor',
                value: ApiConfig.baseUrl,
                trailing: TextButton(
                  onPressed: _editServerUrl,
                  child: const Text('Editar'),
                ),
              ),
              const Divider(color: Color(0xFF334155)),
              ListTile(
                leading: _isDiscoveringServer
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.radar, color: Colors.blue),
                title: Text(
                  _isDiscoveringServer
                      ? 'Buscando en red local...'
                      : 'Buscar servidor automáticamente',
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: _isDiscoveringServer ? null : _discoverServer,
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

  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: ApiConfig.baseUrl);
    final updated = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Servidor', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'URL o IP:puerto',
            hintText: '192.168.100.112:8000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updated == null) return;

    final normalized = ApiConfig.normalizeBaseUrl(updated);
    if (normalized == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL inválida. Ejemplo: 192.168.100.112:8000'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    ApiConfig.setBaseUrl(normalized);
    final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
    await settingsBox.put(ApiConfig.settingsServerUrlKey, normalized);

    if (!mounted) return;
    context.read<AuthService>().updateApiBaseUrl(normalized);
    final syncService = context.read<SyncService>();
    syncService.updateApiBaseUrl(normalized);
    context.read<CatalogRepository>().setBaseUrl(normalized);
    final connected = await syncService.checkConnection();

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          connected
              ? 'Servidor actualizado: $normalized'
              : 'Servidor guardado, pero sin conexiÃ³n al backend',
        ),
        backgroundColor:
            connected ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
      ),
    );
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

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
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
