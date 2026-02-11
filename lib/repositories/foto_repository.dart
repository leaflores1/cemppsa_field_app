import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/config.dart';
import '../data/models/foto_inspeccion.dart';

class FotoRepository extends ChangeNotifier {
  late Box _box;
  bool _initialized = false;

  final Map<String, FotoInspeccion> _fotos = {};

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox(StorageConfig.fotosBox);
    await _loadFromCache();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromCache() async {
    for (final value in _box.values) {
      if (value is Map) {
        try {
          final map = _convertToStringDynamic(value);
          final foto = FotoInspeccion.fromJson(map);
          _fotos[foto.localId] = foto;
        } catch (e) {
          debugPrint('Error cargando foto del cache: $e');
        }
      }
    }
  }

  Map<String, dynamic> _convertToStringDynamic(Map map) {
    return map.map((key, value) {
      if (value is Map) {
        return MapEntry(key.toString(), _convertToStringDynamic(value));
      }
      if (value is List) {
        return MapEntry(key.toString(), _convertList(value));
      }
      return MapEntry(key.toString(), value);
    });
  }

  List _convertList(List list) {
    return list.map((item) {
      if (item is Map) return _convertToStringDynamic(item);
      if (item is List) return _convertList(item);
      return item;
    }).toList();
  }

  Future<void> save(FotoInspeccion foto) async {
    _fotos[foto.localId] = foto;
    await _box.put(foto.localId, foto.toJson());
    notifyListeners();
  }

  FotoInspeccion? get(String localId) => _fotos[localId];

  Future<void> delete(String localId) async {
    _fotos.remove(localId);
    await _box.delete(localId);
    notifyListeners();
  }

  List<FotoInspeccion> all() => _fotos.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<FotoInspeccion> get pendientes => _fotos.values
      .where(
        (f) =>
            (f.status == FotoSyncStatus.pendiente ||
                f.status == FotoSyncStatus.error) &&
            f.canRetryNow,
      )
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int get total => _fotos.length;

  int get totalPendientes => _fotos.values
      .where(
        (f) => f.status == FotoSyncStatus.pendiente || f.status == FotoSyncStatus.error,
      )
      .length;
}
