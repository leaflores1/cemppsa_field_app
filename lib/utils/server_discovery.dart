import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class ServerDiscovery {
  static const int _targetPort = 8000;
  static const String _healthPath = '/health';
  static const Duration _timeout = Duration(milliseconds: 1500);

  /// Escanea la red local y devuelve la primera IP que responda al health check
  static Future<String?> findServer() async {
    final ips = await _getLocalIPv4Addresses();
    if (ips.isEmpty) {
      debugPrint('ServerDiscovery: No se encontraron interfaces de red locales.');
      return null;
    }

    debugPrint('ServerDiscovery: IPs locales encontradas: $ips');

    final client = http.Client();
    try {
      for (final ip in ips) {
        final subnet = _getSubnet(ip);
        if (subnet == null) continue;

        debugPrint('ServerDiscovery: Escaneando subred: $subnet.0/24');
        final foundIp = await _scanSubnet(subnet, client);
        if (foundIp != null) {
          return foundIp;
        }
      }
    } finally {
      client.close();
    }

    return null;
  }

  /// Escanea una subred especifica enviando pings HTTP en lotes
  static Future<String?> _scanSubnet(String subnet, http.Client client) async {
    // Escanear IPs de la 1 a la 254 en lotes para no agotar los file descriptors
    final hosts = List.generate(254, (i) => i + 1);
    const batchSize = 32;

    for (var i = 0; i < hosts.length; i += batchSize) {
      final chunk = hosts.sublist(
        i,
        i + batchSize > hosts.length ? hosts.length : i + batchSize,
      );
      
      final futures = chunk.map((host) => _checkIp('$subnet.$host', client));
      final results = await Future.wait(futures);
      
      for (final res in results) {
        if (res != null) {
          return res;
        }
      }
    }

    return null;
  }

  static Future<String?> _checkIp(String ip, http.Client client) async {
    final url = Uri.parse('http://$ip:$_targetPort$_healthPath');
    try {
      final response = await client.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        debugPrint('ServerDiscovery: ✓ Servidor encontrado en $ip');
        return 'http://$ip:$_targetPort';
      }
    } catch (_) {
      // Timeout o error de conexión se ignoran silenciosamente
    }
    return null;
  }

  static Future<List<String>> _getLocalIPv4Addresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list();
      
      // Priorizar interfaces WLAN/Wi-Fi
      interfaces.sort((a, b) {
        final aWlan = a.name.toLowerCase().contains('wlan') || a.name.toLowerCase().contains('wifi');
        final bWlan = b.name.toLowerCase().contains('wlan') || b.name.toLowerCase().contains('wifi');
        if (aWlan && !bWlan) return -1;
        if (!aWlan && bWlan) return 1;
        return 0;
      });

      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Ignorar IPs extrañas
            if (addr.address.startsWith('169.254.')) continue;
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      debugPrint('ServerDiscovery: Error listando interfaces: $e');
    }
    return ips;
  }

  static String? _getSubnet(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}

