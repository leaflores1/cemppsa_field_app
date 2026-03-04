// ==============================================================================
// CEMPPSA Field App - RangeService
// Obtiene rangos esperados desde el backend con un ÚNICO request bulk por familia
// ==============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

// ==============================================================================
// Modelo de rango
// ==============================================================================

class InstrumentRange {
  final String variableCodigo;
  final double? min;
  final double? max;
  final String? metodo;
  final int? nMuestras;
  final int? version;

  InstrumentRange({
    required this.variableCodigo,
    this.min,
    this.max,
    this.metodo,
    this.nMuestras,
    this.version,
  });

  factory InstrumentRange.fromJson(Map<String, dynamic> json) {
    return InstrumentRange(
      variableCodigo: json['variable_codigo'] ?? '',
      min: (json['min_val'] as num?)?.toDouble(),
      max: (json['max_val'] as num?)?.toDouble(),
      metodo: json['metodo'],
      nMuestras: json['n_muestras'],
      version: json['version'],
    );
  }

  bool get hasRange => min != null && max != null;

  /// Retorna true si el valor está fuera de rango
  bool isOutOfRange(double value) {
    if (!hasRange) return false;
    return value < min! || value > max!;
  }

  String get rangeLabel {
    if (!hasRange) return 'Sin rango disponible';
    return '${min!.toStringAsFixed(2)} — ${max!.toStringAsFixed(2)}';
  }

  /// Label para mostrar en el hint del campo (incluye variable Silver)
  String get fullLabel {
    if (!hasRange) return '';
    // Mapa de nombres cortos para las variables Silver
    const names = {
      'DELTA_P_MCA': 'ΔP (mca)',
      'NIVEL_MCA': 'Nivel (mca)',
      'NIVEL_MSNM': 'Nivel (msnm)',
      'NIVEL_FREATICO': 'Nivel freat.',
      'CAUDAL': 'Caudal',
      'LECTURA_LU': 'Lectura LU',
      'INCLINACION': 'Inclinación',
      'DX': 'ΔX', 'DY': 'ΔY', 'DZ': 'ΔZ',
    };
    final name = names[variableCodigo] ?? variableCodigo;
    return '$name: ${min!.toStringAsFixed(2)} — ${max!.toStringAsFixed(2)}';
  }
}

// ==============================================================================
// RangeService — un solo request bulk por familia
// ==============================================================================

class RangeService {
  /// Cache: { codigo_instrumento -> [rangos] }
  static final Map<String, List<InstrumentRange>> _cache = {};

  /// Pre-carga rangos para una lista de instrumentos con UN SOLO request.
  /// Debe llamarse al seleccionar familia, antes de renderizar el grid.
  static Future<void> prefetchBulk(List<String> codigos) async {
    // Filtrar los que ya están en cache
    final missing = codigos.where((c) => !_cache.containsKey(c)).toList();
    if (missing.isEmpty) return;

    try {
      final codigosParam = missing.join(',');
      final url = '${ApiConfig.baseUrl}/api/v1/rangos/bulk?codigos=${Uri.encodeQueryComponent(codigosParam)}';
      debugPrint('RangeService: bulk fetch ${missing.length} instrumentos → $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        for (final entry in data.entries) {
          final codigo = entry.key;
          final List<dynamic> rangosList = entry.value as List<dynamic>;
          _cache[codigo] = rangosList
              .map((r) => InstrumentRange.fromJson(r as Map<String, dynamic>))
              .toList();
        }
        debugPrint('RangeService: cargados ${data.length} instrumentos con rangos');
      } else {
        debugPrint('RangeService: bulk error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('RangeService: Error en bulk fetch: $e');
    }
  }

  /// Obtiene el rango para un instrumento+variable desde cache.
  /// Si no encuentra el código exacto, devuelve el primer rango disponible
  /// (útil cuando la app busca la variable Bronze pero los rangos están en Silver).
  static InstrumentRange? getFromCache(String codigo, String variableCodigo) {
    final ranges = _cache[codigo];
    if (ranges == null || ranges.isEmpty) return null;

    // Búsqueda exacta
    try {
      return ranges.firstWhere((r) => r.variableCodigo == variableCodigo);
    } catch (_) {
      // No encontró exacto → devuelve el primer rango disponible
      // Prioriza variables significativas sobre PERIODO/timestamps
      const preferred = ['DELTA_P_MCA', 'NIVEL_MCA', 'NIVEL_FREATICO',
        'CAUDAL', 'LECTURA_LU', 'DX', 'DY', 'DZ', 'INCLINACION'];
      for (final pref in preferred) {
        try {
          return ranges.firstWhere((r) => r.variableCodigo == pref);
        } catch (_) {}
      }
      // Fallback: primero que no sea PERIODO
      try {
        return ranges.firstWhere((r) => r.variableCodigo != 'PERIODO');
      } catch (_) {
        return ranges.first;
      }
    }
  }

  /// Retorna todos los rangos en cache para un instrumento
  static List<InstrumentRange> getAllFromCache(String codigo) {
    return _cache[codigo] ?? [];
  }

  /// Limpia el cache (llamar al cambiar de familia)
  static void clearCache() {
    _cache.clear();
    debugPrint('RangeService: cache limpiado');
  }
}
