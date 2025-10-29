import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/connectivity_status.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityStatus>().online;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: online ? Colors.green[50] : Colors.red[50],
        border: Border.all(color: online ? Colors.green : Colors.red),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.wifi : Icons.wifi_off,
              color: online ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              online
                  ? 'Conectado'
                  : 'Sin conexión. Los envíos quedarán pendientes.',
              style: TextStyle(
                color: online ? Colors.green[900] : Colors.red[900],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
