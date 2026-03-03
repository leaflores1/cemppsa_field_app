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
      debugPrint(
          'ServerDiscovery: No se encontraron interfaces de red locales.');
      return null;
    }

    debugPrint('ServerDiscovery: IPs locales encontradas: $ips');

    for (final ip in ips) {
      final subnet = _getSubnet(ip);
      if (subnet == null) continue;

      debugPrint('ServerDiscovery: Escaneando subred: $subnet.0/24');
      final foundIp = await _scanSubnet(subnet);
      if (foundIp != null) {
        return foundIp;
      }
    }

    return null;
  }

  /// Escanea una subred especÃ­fica enviando pings HTTP en paralelo
  static Future<String?> _scanSubnet(String subnet) async {
    final futures = <Future<String?>>[];

    // Escanear IPs de la 1 a la 254
    for (int i = 1; i < 255; i++) {
      final targetIp = '$subnet.$i';
      futures.add(_checkIp(targetIp));
    }

    // Esperar al primero que responda exitosamente (no null), o esperar todos
    String? foundIp;
    try {
      final results = await Future.wait(futures);
      for (final res in results) {
        if (res != null) {
          foundIp = res;
          break;
        }
      }
    } catch (e) {
      debugPrint('ServerDiscovery: Error en scan: $e');
    }

    return foundIp;
  }

  static Future<String?> _checkIp(String ip) async {
    final url = Uri.parse('http://$ip:$_targetPort$_healthPath');
    try {
      final response = await http.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        debugPrint('ServerDiscovery: âœ“ Servidor encontrado en $ip');
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
