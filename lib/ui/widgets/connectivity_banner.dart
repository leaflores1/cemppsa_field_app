import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cemppsa_field_app/services/network_manager.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final net = context.watch<NetworkManager>();
    final online = net.isOnline;
    final base = net.currentBaseUrl ?? 'sin servidor';

    final bg = online ? Colors.green.shade100 : Colors.red.shade100;
    final fg = online ? Colors.green.shade800 : Colors.red.shade800;
    final icon = online ? Icons.wifi : Icons.wifi_off;
    final text = online ? 'Conectado · $base' : 'Sin conexión. Trabajás offline';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
