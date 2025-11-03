import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Mantiene el estado de conectividad y resuelve la mejor baseUrl disponible.
class NetworkManager extends ChangeNotifier {
  bool _online = true;
  String? _currentBaseUrl;
  // Hacemos el subscription dinámico para ser compatibles con v5 (single)
  // y v6 (lista) de connectivity_plus.
  StreamSubscription<dynamic>? _sub;

  bool get isOnline => _online;
  String? get currentBaseUrl => _currentBaseUrl;

  Future<void> start() async {
    // Estado inicial (compatible con ambas firmas)
    final initial = await Connectivity().checkConnectivity();
    _online = _asOnline(initial);

    if (_online) {
      await _refreshBaseUrl();
    }

    _sub = Connectivity().onConnectivityChanged.listen((event) async {
      final newOnline = _asOnline(event);
      if (newOnline != _online) {
        _online = newOnline;
        notifyListeners();
      }
      if (_online) {
        await _refreshBaseUrl();
      }
    });
  }

  bool _asOnline(Object? event) {
    if (event is ConnectivityResult) {
      return event != ConnectivityResult.none;
    } else if (event is List<ConnectivityResult>) {
      // Consideramos online si hay al menos una interfaz distinta de NONE
      return event.any((e) => e != ConnectivityResult.none);
    }
    return false;
    }

  Future<void> _refreshBaseUrl() async {
    for (final base in AppConfig.candidateBaseUrls) {
      if (await _isReachable('$base${AppConfig.healthPath}')) {
        if (_currentBaseUrl != base) {
          _currentBaseUrl = base;
          notifyListeners();
        }
        return;
      }
    }
    // Si ninguna respondió: dejamos la actual (si había) o null
    if (_currentBaseUrl == null) {
      notifyListeners();
    }
  }

 Future<bool> _isReachable(String url) async {
  try {
    final res = await http.get(Uri.parse(url)).timeout(AppConfig.httpTimeout);
    return res.statusCode >= 200 && res.statusCode < 500;
  } catch (_) {
    try {
      final res = await http.head(Uri.parse(url)).timeout(AppConfig.httpTimeout);
      return res.statusCode >= 200 && res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}



  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
