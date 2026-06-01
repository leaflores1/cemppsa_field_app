// ==============================================================================
// CEMPPSA Field App - Catalog Repository
// Backend: /api/v1/catalog/instruments
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';

import '../data/models/instrumento.dart';
import '../data/models/schema_model.dart';

enum MobileSchemaSource {
  backend,
  cache,
  unavailable,
}

class MobileSchemaLoadResult {
  final MobileSchema? schema;
  final MobileSchemaSource source;

  const MobileSchemaLoadResult({
    required this.schema,
    required this.source,
  });

  bool get hasSchema => schema != null;
}

class CatalogFreshness {
  final String catalogRevision;
  final String? rangosUpdatedAt;
  final int? rangosVersionMax;

  const CatalogFreshness({
    required this.catalogRevision,
    this.rangosUpdatedAt,
    this.rangosVersionMax,
  });

  factory CatalogFreshness.fromJson(Map<String, dynamic> json) {
    return CatalogFreshness(
      catalogRevision: json['catalog_revision']?.toString() ?? '',
      rangosUpdatedAt: json['rangos_updated_at']?.toString(),
      rangosVersionMax: _toNullableInt(json['rangos_version_max']),
    );
  }
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse(value.toString());
}

class CatalogRepository extends ChangeNotifier {
  static const String _boxName = 'catalog_v3';
  static const String _lastSyncKey = '__last_sync__';
  static const String _freshnessKey = '__catalog_revision__';
  static const Duration _syncInterval = Duration(hours: 24);

  late Box _box;
  bool _initialized = false;
  bool _syncing = false;
  String? _lastError;

  /// Índice principal por código
  final Map<String, Instrumento> _byCode = {};

  /// Índice secundario por familia
  final Map<FamiliaInstrumento, List<Instrumento>> _byFamilia = {};
  final Set<String> _loggedRangeMisses = {};

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
  DateTime? get lastSyncAt {
    if (!_initialized) return null;
    final raw = _box.get(_lastSyncKey) as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String? get catalogRevision {
    if (!_initialized) return null;
    return _box.get(_freshnessKey) as String?;
  }

  int? get catalogVersion {
    int? highestVersion;
    for (final instrumento in _byCode.values) {
      for (final range in instrumento.rangos) {
        final version = range.version;
        if (version == null) continue;
        if (highestVersion == null || version > highestVersion) {
          highestVersion = version;
        }
      }
    }
    return highestVersion;
  }

  int? get catalogAgeDays {
    final lastSync = lastSyncAt;
    if (lastSync == null) return null;
    return DateTime.now().difference(lastSync).inDays;
  }

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
      if (key == _lastSyncKey || key == _freshnessKey) continue;

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
    _loggedRangeMisses.clear();
  }

  // ===========================================================================
  // Backend Sync
  // ===========================================================================

  void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<void> clearLocalCache() async {
    if (!_initialized) {
      _box = await Hive.openBox(_boxName);
      _initialized = true;
    }
    _clearIndexes();
    _lastError = null;
    await _box.clear();
    notifyListeners();
  }

  bool get needsSync {
    if (_byCode.isEmpty) return true;

    final raw = _box.get(_lastSyncKey) as String?;
    if (raw == null) return true;

    final last = DateTime.tryParse(raw);
    if (last == null) return true;

    return DateTime.now().difference(last) > _syncInterval;
  }

  Future<CatalogFreshness?> fetchRemoteFreshness() async {
    if (_baseUrl == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/api/v1/catalog-app/freshness');
      debugPrint('CatalogRepository GET $uri');

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        debugPrint(
          'CatalogRepository freshness unavailable: HTTP ${response.statusCode}',
        );
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) return null;

      final freshness = CatalogFreshness.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (freshness.catalogRevision.isEmpty) return null;
      return freshness;
    } catch (e) {
      debugPrint('CatalogRepository freshness error: $e');
      return null;
    }
  }

  Future<bool> syncIfRemoteChanged() async {
    if (_baseUrl == null) {
      _lastError = 'Backend URL no configurada';
      return false;
    }

    final remoteFreshness = await fetchRemoteFreshness();
    if (remoteFreshness == null) {
      return syncFromBackend();
    }

    final localRevision = catalogRevision;
    if (_byCode.isNotEmpty && localRevision == remoteFreshness.catalogRevision) {
      _lastError = null;
      await _box.put(_lastSyncKey, DateTime.now().toIso8601String());
      notifyListeners();
      debugPrint('CatalogRepository cache vigente: $localRevision');
      return false;
    }

    return syncFromBackend(remoteFreshness: remoteFreshness);
  }

  Future<bool> syncFromBackend({CatalogFreshness? remoteFreshness}) async {
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

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

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
      final freshness = remoteFreshness ?? await fetchRemoteFreshness();
      if (freshness != null) {
        await _box.put(_freshnessKey, freshness.catalogRevision);
      } else {
        await _box.delete(_freshnessKey);
      }

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
      _byCode.values.toList()..sort((a, b) => a.codigo.compareTo(b.codigo));

  Instrumento? byCode(String code) => _byCode[code.toUpperCase()];

  InstrumentRange? rangeForInstrument(String code, String variableCodigo) {
    final rangeKey =
        '${code.toUpperCase().trim()}|${variableCodigo.toUpperCase().trim()}';
    final inst = byCode(code);
    if (inst == null) {
      if (kDebugMode && _loggedRangeMisses.add(rangeKey)) {
        debugPrint(
          'CatalogRepository range miss: instrumento $code no encontrado '
          'para variable $variableCodigo',
        );
      }
      return null;
    }
    final range = inst.rangeForVariable(variableCodigo);
    if (range == null && kDebugMode && _loggedRangeMisses.add(rangeKey)) {
      debugPrint(
          'CatalogRepository range miss: ${inst.rangeDebugInfo(variableCodigo)}');
    }
    return range;
  }

  List<InstrumentRange> rangesForInstrument(String code) {
    final inst = byCode(code);
    if (inst == null) return const [];
    return List.unmodifiable(inst.rangos);
  }

  List<Instrumento> byFamilia(FamiliaInstrumento familia) =>
      List.unmodifiable(_byFamilia[familia] ?? []);

  List<Instrumento> activos() => _byCode.values.where((i) => i.activo).toList();

  List<Instrumento> manuales() =>
      _byCode.values.where((i) => i.esManual).toList();

  /// Casagrande = piezómetro + subfamilia CASAGRANDE
  List<Instrumento> casagrande() => _byCode.values
      .where((i) =>
          i.familia == FamiliaInstrumento.casagrande ||
          (i.familia == FamiliaInstrumento.piezometro &&
              i.subfamilia == 'CASAGRANDE'))
      .toList();

  List<Instrumento> freatimetros() => byFamilia(FamiliaInstrumento.freatimetro);

  List<Instrumento> aforadores() => byFamilia(FamiliaInstrumento.aforador);

  List<Instrumento> cr10x() =>
      _byCode.values.where((i) => !i.esManual).toList();

  List<Instrumento> buscar(String texto) {
    final q = texto.toLowerCase();
    return _byCode.values
        .where((i) =>
            i.codigo.toLowerCase().contains(q) ||
            (i.nombre?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  List<FamiliaInstrumento> get familias => _byFamilia.keys.toList();

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
  // ===========================================================================
  // Mobile Schema (Planillas)
  // ===========================================================================

  Future<MobileSchemaLoadResult> loadMobileSchema(String familyId) async {
    final cacheKey = 'schema_$familyId';

    // 1. Try Online
    if (_baseUrl != null) {
      try {
        final uri = Uri.parse(
            '$_baseUrl/api/v1/catalog/mobile/schema?familia=$familyId');
        debugPrint('Fetching schema: $uri');

        final response =
            await http.get(uri).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          final schema = MobileSchema.fromJson(json);

          // Cache it
          // Store complete JSON object to avoid serialization issues
          await _box.put(cacheKey, json);
          return MobileSchemaLoadResult(
            schema: schema,
            source: MobileSchemaSource.backend,
          );
        } else {
          debugPrint(
              'Error fetching schema ($familyId): ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Network error for schema ($familyId): $e');
      }
    }

    // 2. Fallback to Cache
    if (_box.containsKey(cacheKey)) {
      try {
        final cached = _box.get(cacheKey);
        // Ensure it's a Map<String, dynamic>
        // Hive stores Map<dynamic, dynamic> sometimes
        final Map<String, dynamic> jsonMap = cached is Map
            ? jsonDecode(jsonEncode(cached))
            : Map<String, dynamic>.from(cached);

        debugPrint('Loaded schema from cache: $familyId');
        return MobileSchemaLoadResult(
          schema: MobileSchema.fromJson(jsonMap),
          source: MobileSchemaSource.cache,
        );
      } catch (e) {
        debugPrint('Cache parsing error ($familyId): $e');
      }
    }

    return const MobileSchemaLoadResult(
      schema: null,
      source: MobileSchemaSource.unavailable,
    );
  }

  Future<MobileSchema?> fetchMobileSchema(String familyId) async {
    final result = await loadMobileSchema(familyId);
    return result.schema;
  }
}
