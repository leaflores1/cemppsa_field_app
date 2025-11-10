import 'package:flutter/foundation.dart';

@immutable
class Instrument {
  final String code;         // "PP01"
  final String name;         // "Piezómetro 01 — Galería A"
  final String defaultParam; // "nivel"
  final String defaultUnit;  // "m"
  final String family;       // "piezometro" | "freatimetro" | "acelerometro" | ...

  const Instrument({
    required this.code,
    required this.name,
    required this.defaultParam,
    required this.defaultUnit,
    required this.family,
  });

  factory Instrument.fromJson(Map<String, dynamic> j) {
    final code = j['code'] as String;
    final fam = (j['family'] ?? j['type'] ?? _inferFamily(code)) as String;
    return Instrument(
      code: code,
      name: (j['name'] ?? j['description'] ?? '') as String,
      defaultParam: (j['default_param'] ?? 'nivel') as String,
      defaultUnit: (j['default_unit'] ?? 'm') as String,
      family: fam,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'default_param': defaultParam,
        'default_unit': defaultUnit,
        'family': family,
      };

  static String _inferFamily(String code) {
    // Prefijos de conveniencia Off-line
    if (code.toUpperCase().startsWith('PP')) return 'piezometro';
    if (code.toUpperCase().startsWith('FR')) return 'freatimetro';
    if (code.toUpperCase().startsWith('AC')) return 'acelerometro';
    return 'generico';
  }

  @override
  String toString() => '$code — $name';
}
