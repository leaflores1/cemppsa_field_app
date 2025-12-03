import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/models/planilla.dart';
import 'network_manager.dart';

class OfflineStorage {
  static const String _boxName = 'outbox_v1';
  late final Box _box;

  Future<void> init() async {
    // Hive ya se inicializa en main.dart
    _box = await Hive.openBox(_boxName);
  }

  Future<void> enqueue(Planilla p) async {
    await _box.add(p.toJson()); // guarda el payload con batch_uuid
  }

  Future<void> clear() async => _box.clear();

  int get count => _box.length;

  /// Devuelve los batch_uuid enviados con éxito.
  Future<List<String>> flushIfPossible(NetworkManager net) async {
    final sentIds = <String>[];
    if (!net.isOnline || net.currentBaseUrl == null) return sentIds;
    if (_box.isEmpty) return sentIds;

    final keys = _box.keys.toList(growable: false);
    final values = _box.values.cast<Map>().toList(growable: false);

    for (var i = 0; i < values.length; i++) {
      final json = Map<String, dynamic>.from(values[i]);
      final uri = Uri.parse('${net.currentBaseUrl}${AppConfig.apiSyncPath}');
      try {
        final res = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(json),
            )
            .timeout(AppConfig.httpTimeout);

        if (res.statusCode == 200 || res.statusCode == 201) {
          final sentId = (json['batch_uuid'] ?? json['id'])?.toString();
          if (sentId != null) sentIds.add(sentId);
          await _box.delete(keys[i]);
        } else {
          debugPrint('Reintento falló (${res.statusCode}): ${res.body}');
          break; // corto para reintentar luego
        }
      } catch (e) {
        debugPrint('Reintento error: $e');
        break;
      }
    }
    return sentIds;
  }
}
