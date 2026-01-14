// ==============================================================================
// Connectivity Banner
// Muestra estado de conexión y sincronización
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sync_service.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        if (sync.status == ConnectionStatus.connected &&
            !sync.isSyncing) {
          return const SizedBox.shrink();
        }

        Color color;
        IconData icon;
        String text;

        switch (sync.status) {
          case ConnectionStatus.syncing:
            color = Colors.blue;
            icon = Icons.sync;
            text = 'Sincronizando… (${sync.pendingCount})';
            break;

          case ConnectionStatus.disconnected:
            color = Colors.red;
            icon = Icons.cloud_off;
            text = 'Sin conexión al servidor';
            break;

          default:
            color = Colors.orange;
            icon = Icons.cloud_queue;
            text = 'Conectando…';
        }

        return Material(
          color: color,
          elevation: 4,
          child: SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (sync.status == ConnectionStatus.disconnected)
                    TextButton(
                      onPressed: () => sync.checkConnection(),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
