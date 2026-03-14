import 'package:flutter/material.dart';

import '../../repositories/catalogo_repository.dart';

enum CatalogFreshnessLevel {
  fresh,
  aging,
  stale,
}

class CatalogFreshnessInfo {
  final DateTime? lastSyncAt;
  final int? ageDays;
  final int? catalogVersion;
  final int totalInstrumentos;
  final String? lastError;

  const CatalogFreshnessInfo({
    required this.lastSyncAt,
    required this.ageDays,
    required this.catalogVersion,
    required this.totalInstrumentos,
    required this.lastError,
  });

  factory CatalogFreshnessInfo.fromRepository(CatalogRepository repository) {
    return CatalogFreshnessInfo(
      lastSyncAt: repository.lastSyncAt,
      ageDays: repository.catalogAgeDays,
      catalogVersion: repository.catalogVersion,
      totalInstrumentos: repository.totalInstrumentos,
      lastError: repository.lastError,
    );
  }

  CatalogFreshnessLevel get level {
    if (lastSyncAt == null || ageDays == null || ageDays! > 30) {
      return CatalogFreshnessLevel.stale;
    }
    if (ageDays! >= 7) {
      return CatalogFreshnessLevel.aging;
    }
    return CatalogFreshnessLevel.fresh;
  }

  String get summary {
    switch (level) {
      case CatalogFreshnessLevel.fresh:
        return 'Rangos actualizados hace ${ageDays ?? 0} dias';
      case CatalogFreshnessLevel.aging:
        return 'Rangos con ${ageDays ?? 0} dias. Actualiza cuando tengas red.';
      case CatalogFreshnessLevel.stale:
        return 'Rangos desactualizados. Actualiza antes de salir a campo.';
    }
  }

  String get lastSyncLabel {
    final lastSync = lastSyncAt;
    if (lastSync == null) {
      return 'Sin sincronizacion registrada';
    }
    final day = lastSync.day.toString().padLeft(2, '0');
    final month = lastSync.month.toString().padLeft(2, '0');
    final minute = lastSync.minute.toString().padLeft(2, '0');
    return '$day/$month/${lastSync.year} ${lastSync.hour}:$minute';
  }

  String get versionLabel => catalogVersion?.toString() ?? 'N/D';

  IconData get icon {
    switch (level) {
      case CatalogFreshnessLevel.fresh:
        return Icons.check_circle_outline;
      case CatalogFreshnessLevel.aging:
        return Icons.warning_amber_rounded;
      case CatalogFreshnessLevel.stale:
        return Icons.error_outline;
    }
  }

  Color get accentColor {
    switch (level) {
      case CatalogFreshnessLevel.fresh:
        return const Color(0xFF22C55E);
      case CatalogFreshnessLevel.aging:
        return const Color(0xFFF59E0B);
      case CatalogFreshnessLevel.stale:
        return const Color(0xFFEF4444);
    }
  }

  Color get backgroundColor {
    switch (level) {
      case CatalogFreshnessLevel.fresh:
        return const Color(0xFF11261A);
      case CatalogFreshnessLevel.aging:
        return const Color(0xFF2C1E0A);
      case CatalogFreshnessLevel.stale:
        return const Color(0xFF31181A);
    }
  }

  Color get borderColor {
    switch (level) {
      case CatalogFreshnessLevel.fresh:
        return const Color(0xFF166534);
      case CatalogFreshnessLevel.aging:
        return const Color(0xFFB45309);
      case CatalogFreshnessLevel.stale:
        return const Color(0xFFB91C1C);
    }
  }
}

class CatalogFreshnessBanner extends StatelessWidget {
  final CatalogFreshnessInfo info;
  final VoidCallback onTap;

  const CatalogFreshnessBanner({
    super.key,
    required this.info,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: info.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: info.borderColor),
          ),
          child: Row(
            children: [
              Icon(info.icon, color: info.accentColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showCatalogFreshnessDetailsSheet(
  BuildContext context, {
  required CatalogFreshnessInfo info,
  required Future<bool> Function() checkConnection,
  required bool initialIsConnected,
  required bool isRefreshing,
  required Future<void> Function()? onRefreshRequested,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E293B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<bool>? connectivityFuture;
          bool? latestConnectivity = initialIsConnected;

          Future<bool> resolveConnection() {
            connectivityFuture ??= checkConnection().then((value) {
              latestConnectivity = value;
              return value;
            });
            return connectivityFuture!;
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(info.icon, color: info.accentColor),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Estado del catalogo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CatalogInfoLine(
                  label: 'Ultima sincronizacion',
                  value: info.lastSyncLabel,
                ),
                _CatalogInfoLine(
                  label: 'Version del catalogo',
                  value: info.versionLabel,
                ),
                _CatalogInfoLine(
                  label: 'Instrumentos cacheados',
                  value: info.totalInstrumentos.toString(),
                ),
                if (info.lastError != null && info.lastError!.trim().isNotEmpty)
                  _CatalogInfoLine(
                    label: 'Ultimo error',
                    value: info.lastError!,
                  ),
                const SizedBox(height: 16),
                FutureBuilder<bool>(
                  future: resolveConnection(),
                  builder: (context, snapshot) {
                    final hasConnection = snapshot.data ?? latestConnectivity ?? false;
                    final checking = snapshot.connectionState == ConnectionState.waiting;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (checking)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Verificando red...',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          )
                        else if (!hasConnection)
                          const Text(
                            'Sin red disponible',
                            style: TextStyle(
                              color: Color(0xFFFBBF24),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                child: const Text('Cerrar'),
                              ),
                            ),
                            if (!checking && hasConnection && onRefreshRequested != null)
                              const SizedBox(width: 12),
                            if (!checking && hasConnection && onRefreshRequested != null)
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isRefreshing
                                      ? null
                                      : () async {
                                          await onRefreshRequested();
                                          if (sheetContext.mounted) {
                                            Navigator.pop(sheetContext);
                                          }
                                        },
                                  child: Text(
                                    isRefreshing
                                        ? 'Actualizando...'
                                        : 'Actualizar ahora',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _CatalogInfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _CatalogInfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
