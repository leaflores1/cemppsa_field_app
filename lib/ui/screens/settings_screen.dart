// ==============================================================================
// CEMPPSA Field App - SettingsScreen
// Pantalla de configuraciÃ³n de la app (desacoplada de SyncService)
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
import '../widgets/catalog_freshness_banner.dart';
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
        title: const Text('ConfiguraciÃ³n'),
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
                            'Sin sesiÃ³n',
                        trailing: TextButton(
                          onPressed: _editTechnicianName,
                          child: const Text('Editar'),
                        ),
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'ID tÃ©cnico',
                        value:
                            AppConfig.technicianId ?? user?.id ?? 'Sin sesiÃ³n',
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'Email',
                        value: user?.email ?? 'Sin sesiÃ³n',
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
              label: const Text('Cerrar sesiÃ³n'),
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
                      : 'Buscar servidor automÃ¡ticamente',
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
              Consumer2<CatalogRepository, SyncService>(
                builder: (_, catalog, syncService, __) {
                  final info = CatalogFreshnessInfo.fromRepository(catalog);
                  final connectionLabel = syncService.isConnected
                      ? 'Red disponible'
                      : 'Sin red disponible';
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: CatalogFreshnessBanner(
                          info: info,
                          onTap: () =>
                              _showCatalogFreshnessPanel(catalog, syncService),
                        ),
                      ),
                      _InfoTile(
                        label: 'Catalogo de instrumentos',
                        value: '${catalog.totalInstrumentos} instrumentos',
                        trailing: TextButton(
                          onPressed: catalog.isSyncing
                              ? null
                              : () => _refreshCatalog(catalog),
                          child: const Text('Actualizar'),
                        ),
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'Ultima sincronizacion',
                        value: info.lastSyncLabel,
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'Version del catalogo',
                        value: info.versionLabel,
                      ),
                      const Divider(color: Color(0xFF334155)),
                      _InfoTile(
                        label: 'Estado de red',
                        value: connectionLabel,
                      ),
                    ],
                  );
                },
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
                subtitle: 'Elimina planillas enviadas hace mas de 30 dias',
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
          const _SettingsCard(
            children: [
              _InfoTile(
                label: 'Aplicacion',
                value: AppConfig.appName,
              ),
              Divider(color: Color(0xFF334155)),
              _InfoTile(
                label: 'Version',
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

  Future<void> _editTechnicianName() async {
    try {
      final controller = TextEditingController(text: AppConfig.technicianName ?? '');
      final updated = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Nombre', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Tu Nombre',
              hintText: 'Ej: Juan PÃ©rez',
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
      // Defer dispose so the dialog exit animation can finish
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

      if (updated == null) return;

      if (updated.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El nombre no puede estar vacÃ­o'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }

      AppConfig.technicianName = updated;
      final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
      await settingsBox.put('technician_name', updated);

      if (!mounted) return;
      // Defer setState to avoid build scope conflict with Consumer
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre actualizado'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (e) {
      debugPrint('_editTechnicianName ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al editar nombre: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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
    // Defer dispose so the dialog exit animation can finish
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (updated == null) return;

    final normalized = ApiConfig.normalizeBaseUrl(updated);
    if (normalized == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL invÃ¡lida. Ejemplo: 192.168.100.112:8000'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    await _applyServerUrlChange(normalized);
  }

  Future<void> _discoverServer() async {
    setState(() => _isDiscoveringServer = true);
    try {
      debugPrint('DiscoverServer: Iniciando bÃºsqueda...');
      final ip = await ServerDiscovery.findServer();
      debugPrint('DiscoverServer: Resultado=$ip');
      if (!mounted) return;

      if (ip != null) {
        final apply = await _showDiscoverySuccessDialog(ip);
        if (apply == true) {
          await _applyServerUrlChange(ip);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se encontrÃ³ ningÃºn servidor en la red local'),
            backgroundColor: Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      debugPrint('DiscoverServer ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en bÃºsqueda: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDiscoveringServer = false);
    }
  }

  Future<bool?> _showDiscoverySuccessDialog(String ip) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Servidor encontrado', style: TextStyle(color: Colors.white)),
        content: Text('Se encontrÃ³ un servidor en $ip.\n\nÂ¿Deseas usar esta direcciÃ³n?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar esta direcciÃ³n'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshCatalog(CatalogRepository catalog) async {
    final ok = await catalog.syncFromBackend();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'CatÃ¡logo actualizado' : 'Error al sincronizar catÃ¡logo',
        ),
        backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _applyServerUrlChange(String normalized) async {
    if (normalized == ApiConfig.baseUrl) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El servidor ya estaba configurado'),
          backgroundColor: Color(0xFF64748B),
        ),
      );
      return;
    }

    ApiConfig.setBaseUrl(normalized);
    final settingsBox = await Hive.openBox(StorageConfig.settingsBox);
    await settingsBox.put(ApiConfig.settingsServerUrlKey, normalized);

    if (!mounted) return;
    context.read<AuthService>().updateApiBaseUrl(normalized);
    context.read<SyncService>().updateApiBaseUrl(normalized);
    final catalog = context.read<CatalogRepository>();
    catalog.setBaseUrl(normalized);
    await catalog.clearLocalCache();

    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Catalogo limpiado. Sincroniza antes de tomar mediciones.'),
        backgroundColor: Color(0xFFF59E0B),
      ),
    );
  }

  Future<void> _showCatalogFreshnessPanel(
    CatalogRepository catalog,
    SyncService syncService,
  ) {
    return showCatalogFreshnessDetailsSheet(
      context,
      info: CatalogFreshnessInfo.fromRepository(catalog),
      checkConnection: syncService.checkConnection,
      initialIsConnected: syncService.isConnected,
      isRefreshing: catalog.isSyncing,
      onRefreshRequested: () => _refreshCatalog(catalog),
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
