import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityStatus extends ChangeNotifier {
  bool _online = true;
  bool get online => _online;

  // Soporta tanto Stream<ConnectivityResult> como Stream<List<ConnectivityResult>>
  StreamSubscription<dynamic>? _sub;

  void init() {
    _seedInitial();

    _sub = Connectivity().onConnectivityChanged.listen((event) {
      final newOnline = _mapToOnline(event);
      if (newOnline != _online) {
        _online = newOnline;
        notifyListeners();
      }
    });
  }

  Future<void> _seedInitial() async {
    try {
      final result = await Connectivity().checkConnectivity(); // suele ser ConnectivityResult
      final initialOnline = _mapToOnline(result);
      if (initialOnline != _online) {
        _online = initialOnline;
        notifyListeners();
      }
    } catch (_) {
      // si falla, no cambiamos estado
    }
  }

  bool _mapToOnline(dynamic value) {
    if (value is List<ConnectivityResult>) {
      return value.any((e) => e != ConnectivityResult.none);
    }
    if (value is ConnectivityResult) {
      return value != ConnectivityResult.none;
    }
    return _online; // desconocido -> mantené estado actual
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
