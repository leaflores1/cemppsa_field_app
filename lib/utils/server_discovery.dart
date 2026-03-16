import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

class ServerDiscovery {
  static const int _defaultPort = 8000;
  static const int _httpFallbackPort = 80;
  static const String _healthPath = '/health';
  static const Duration _timeout = Duration(milliseconds: 2500);
  static const Duration _udpTimeout = Duration(milliseconds: 1200);
  static const int _udpDiscoveryPort = 42100;
  static const String _udpMagicRequest = 'CEMPPSA_DISCOVER_V1';
  static const String _udpMagicResponsePrefix = 'CEMPPSA_API_V1|';

  /// Escanea la red local y devuelve la primera URL base valida.
  static Future<String?> findServer() async {
    final ips = await _getLocalIPv4Addresses();
    if (ips.isEmpty) {
      debugPrint(
          'ServerDiscovery: No se encontraron interfaces de red locales.');
      return null;
    }

    final subnets = ips.map(_getSubnet).whereType<String>().toSet().toList();
    final candidatePorts = _resolveCandidatePorts();
    debugPrint('ServerDiscovery: IPs locales encontradas: $ips');
    debugPrint('ServerDiscovery: Subredes priorizadas: $subnets');
    debugPrint('ServerDiscovery: Puertos objetivo: $candidatePorts');

    final udpResult = await _discoverViaUdp(subnets);
    if (udpResult != null) {
      debugPrint('ServerDiscovery: Servidor encontrado via UDP en $udpResult');
      return udpResult;
    }

    final client = http.Client();
    try {
      final direct = await _probeConfiguredBaseUrl(client);
      if (direct != null) return direct;

      for (final subnet in subnets) {
        for (final port in candidatePorts) {
          debugPrint(
            'ServerDiscovery: Escaneando subred: $subnet.0/24 (puerto $port)',
          );
          final foundBaseUrl = await _scanSubnet(subnet, port, client);
          if (foundBaseUrl != null) return foundBaseUrl;
        }
      }
    } finally {
      client.close();
    }

    return null;
  }

  /// Escanea una subred especifica enviando pings HTTP en lotes.
  static Future<String?> _scanSubnet(
    String subnet,
    int port,
    http.Client client,
  ) async {
    final hosts = List.generate(254, (i) => i + 1);
    const batchSize = 32;

    for (var i = 0; i < hosts.length; i += batchSize) {
      final chunk = hosts.sublist(
        i,
        i + batchSize > hosts.length ? hosts.length : i + batchSize,
      );

      final futures =
          chunk.map((host) => _checkIp('$subnet.$host', port, client));
      final results = await Future.wait(futures);
      for (final res in results) {
        if (res != null) return res;
      }
    }

    return null;
  }

  static Future<String?> _checkIp(
      String ip, int port, http.Client client) async {
    return _checkBaseUrl(
      scheme: 'http',
      host: ip,
      port: port,
      client: client,
    );
  }

  static Future<String?> _checkBaseUrl({
    required String scheme,
    required String host,
    required int port,
    required http.Client client,
  }) async {
    final url = Uri.parse('$scheme://$host:$port$_healthPath');
    try {
      final response = await client.get(url).timeout(_timeout);
      if (response.statusCode == 200) {
        debugPrint(
            'ServerDiscovery: Servidor encontrado en $scheme://$host:$port');
        return '$scheme://$host:$port';
      }
    } catch (_) {
      // Timeout o error de conexion: ignorar y continuar
    }
    return null;
  }

  static Future<List<String>> _getLocalIPv4Addresses() async {
    final ips = <String>[];
    try {
      final interfaces = await NetworkInterface.list();

      // Priorizar interfaces WLAN/Wi-Fi
      interfaces.sort((a, b) {
        final aWlan = a.name.toLowerCase().contains('wlan') ||
            a.name.toLowerCase().contains('wifi');
        final bWlan = b.name.toLowerCase().contains('wlan') ||
            b.name.toLowerCase().contains('wifi');
        if (aWlan && !bWlan) return -1;
        if (!aWlan && bWlan) return 1;
        return 0;
      });

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Ignorar link-local
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

  static List<int> _resolveCandidatePorts() {
    final ports = <int>{_defaultPort, _httpFallbackPort};
    final configured = Uri.tryParse(ApiConfig.baseUrl);

    if (configured != null) {
      if (configured.hasPort) {
        ports.add(configured.port);
      } else if (configured.scheme == 'https') {
        ports.add(443);
      } else if (configured.scheme == 'http') {
        ports.add(_httpFallbackPort);
      }
    }

    return ports.toList()..sort();
  }

  static Future<String?> _probeConfiguredBaseUrl(http.Client client) async {
    if (!ApiConfig.hasConfiguredBaseUrl) {
      return null;
    }

    final configured = Uri.tryParse(ApiConfig.baseUrl);
    if (configured == null || configured.host.trim().isEmpty) return null;
    final host = configured.host.trim();
    if (host == 'localhost' || host == '127.0.0.1') return null;

    final scheme = configured.scheme.isNotEmpty ? configured.scheme : 'http';
    final port = configured.hasPort
        ? configured.port
        : (scheme == 'https' ? 443 : _httpFallbackPort);
    debugPrint(
      'ServerDiscovery: Probando URL guardada como fallback: $scheme://$host:$port',
    );
    return _checkBaseUrl(
      scheme: scheme,
      host: host,
      port: port,
      client: client,
    );
  }

  static Future<String?> _discoverViaUdp(List<String> subnets) async {
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    Timer? timer;

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;

      final completer = Completer<String?>();
      subscription = socket.listen((event) {
        if (event != RawSocketEvent.read || completer.isCompleted) {
          return;
        }

        final packet = socket?.receive();
        if (packet == null) return;

        final message = utf8.decode(packet.data, allowMalformed: true).trim();
        if (!message.startsWith(_udpMagicResponsePrefix)) {
          return;
        }

        final portRaw =
            message.substring(_udpMagicResponsePrefix.length).trim();
        final port = int.tryParse(portRaw);
        if (port == null) {
          debugPrint(
            'ServerDiscovery: Respuesta UDP invalida desde ${packet.address.address}: $message',
          );
          return;
        }

        completer.complete('http://${packet.address.address}:$port');
      });

      final payload = utf8.encode(_udpMagicRequest);
      for (final subnet in subnets) {
        final broadcast = InternetAddress('$subnet.255');
        socket.send(payload, broadcast, _udpDiscoveryPort);
      }
      socket.send(
          payload, InternetAddress('255.255.255.255'), _udpDiscoveryPort);

      timer = Timer(_udpTimeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('ServerDiscovery: Error en descubrimiento UDP: $e');
      return null;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
      socket?.close();
    }
  }
}
