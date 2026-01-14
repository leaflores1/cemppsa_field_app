// ==============================================================================
// CEMPPSA Field App - Catalog Repository
// Backend: /api/v1/catalog/instruments
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/instrumento.dart';

class CatalogRepository extends ChangeNotifier {
  static const String _boxName = 'catalog_v3';
  static const String _lastSyncKey = '__last_sync__';
  static const Duration _syncInterval = Duration(hours: 24);

  late Box _box;
  bool _initialized = false;
  bool _syncing = false;
  String? _lastError;

  /// Índice principal por código
  final Map<String, Instrumento> _byCode = {};

  /// Índice secundario por familia
  final Map<FamiliaInstrumento, List<Instrumento>> _byFamilia = {};

  String? _baseUrl;

  CatalogRepository({String? baseUrl}) : _baseUrl = baseUrl;

  // ===========================================================================
  // Getters
  // ===========================================================================

  bool get isInitialized => _initialized;
  bool get isSyncing => _syncing;
  String? get lastError => _lastError;
  int get totalInstrumentos => _byCode.length;
  bool get isEmpty => _byCode.isEmpty;

  // ===========================================================================
  // Inicialización
  // ===========================================================================

  Future<void> init() async {
    if (_initialized) return;

    _box = await Hive.openBox(_boxName);
    await _loadFromCache();

    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadFromCache() async {
    _clearIndexes();

    for (final key in _box.keys) {
      if (key == _lastSyncKey) continue;

      final raw = _box.get(key);
      if (raw is Map) {
        try {
          final inst = Instrumento.fromJson(
            Map<String, dynamic>.from(raw),
          );
          _index(inst);
        } catch (e) {
          debugPrint('CatalogRepository cache error: $e');
        }
      }
    }

    debugPrint('Catálogo cargado desde cache: ${_byCode.length}');
  }

  void _index(Instrumento inst) {
    _byCode[inst.codigo] = inst;
    _byFamilia.putIfAbsent(inst.familia, () => []).add(inst);
  }

  void _clearIndexes() {
    _byCode.clear();
    _byFamilia.clear();
  }

  // ===========================================================================
  // Backend Sync
  // ===========================================================================

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
  }

  bool get needsSync {
    if (_byCode.isEmpty) return true;

    final raw = _box.get(_lastSyncKey) as String?;
    if (raw == null) return true;

    final last = DateTime.tryParse(raw);
    if (last == null) return true;

    return DateTime.now().difference(last) > _syncInterval;
  }

  Future<bool> syncFromBackend() async {
    if (_baseUrl == null) {
      _lastError = 'Backend URL no configurada';
      return false;
    }

    if (_syncing) return false;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/catalog-app/instruments');
      debugPrint('CatalogRepository GET $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _lastError = 'HTTP ${response.statusCode}';
        return false;
      }

      final List<dynamic> items = jsonDecode(response.body);

      _clearIndexes();
      await _box.clear();

      for (final item in items) {
        try {
          final inst = Instrumento.fromJson(
            Map<String, dynamic>.from(item),
          );
          _index(inst);
          await _box.put(inst.codigo, inst.toJson());
        } catch (e) {
          debugPrint('Error parseando instrumento: $e');
        }
      }

      await _box.put(
        _lastSyncKey,
        DateTime.now().toIso8601String(),
      );

      debugPrint('Catálogo sincronizado: ${_byCode.length}');
      return true;
    } catch (e) {
      _lastError = 'Error de conexión: $e';
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // Consultas
  // ===========================================================================

  List<Instrumento> all() =>
      _byCode.values.toList()
        ..sort((a, b) => a.codigo.compareTo(b.codigo));

  Instrumento? byCode(String code) =>
      _byCode[code.toUpperCase()];

  List<Instrumento> byFamilia(FamiliaInstrumento familia) =>
      List.unmodifiable(_byFamilia[familia] ?? []);

  List<Instrumento> activos() =>
      _byCode.values.where((i) => i.activo).toList();

  List<Instrumento> manuales() =>
      _byCode.values.where((i) => i.esManual).toList();

  /// Casagrande = piezómetro + subfamilia CASAGRANDE
  List<Instrumento> casagrande() =>
      _byCode.values.where((i) =>
          i.familia == FamiliaInstrumento.piezometro &&
          i.subfamilia == 'CASAGRANDE'
      ).toList();

  List<Instrumento> freatimetros() =>
      byFamilia(FamiliaInstrumento.freatimetro);

  List<Instrumento> aforadores() =>
      byFamilia(FamiliaInstrumento.aforador);

  List<Instrumento> cr10x() =>
      _byCode.values.where((i) => !i.esManual).toList();

  List<Instrumento> buscar(String texto) {
    final q = texto.toLowerCase();
    return _byCode.values.where((i) =>
      i.codigo.toLowerCase().contains(q) ||
      (i.nombre?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  List<FamiliaInstrumento> get familias =>
      _byFamilia.keys.toList();

  Map<FamiliaInstrumento, int> get conteoPorFamilia {
    final map = <FamiliaInstrumento, int>{};
    for (final f in _byFamilia.keys) {
      map[f] = _byFamilia[f]!.length;
    }
    return map;
  }

  // ===========================================================================
  // Utilidades para UI
  // ===========================================================================

  int get casagrandeCount => casagrande().length;
  int get freatimetrosCount => freatimetros().length;
  int get aforadoresCount => aforadores().length;
  int get manualesCount => manuales().length;

  /// 🔑 Método que necesitaba CR10XBatchScreen
  List<String> codigosPorSubfamilia(String subfamilia) {
    return _byCode.values
        .where((i) => i.subfamilia == subfamilia)
        .map((i) => i.codigo)
        .toList();
  }
}
