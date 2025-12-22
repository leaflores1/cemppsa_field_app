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

    final dot = online ? const Color(0xFF34D399) : const Color(0xFFFB7185); // emerald / rose
    final text = online ? 'Sistema en línea · $base' : 'Sin conexión. Trabajás offline';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(color: dot, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.80),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Icon(
            online ? Icons.wifi : Icons.wifi_off,
            size: 18,
            color: Colors.white.withOpacity(0.65),
          ),
        ],
      ),
    );
  }
}
