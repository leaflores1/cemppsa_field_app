import 'package:flutter/foundation.dart';

@immutable
class Lectura {
  final int? id;                 // client_row_id (opcional)
  final String instrumento;      // instrument_code
  final String parametro;        // parameter (ej: "nivel")
  final String unidad;           // unit (ej: "m")
  final double valor;            // value numérico
  final DateTime fecha;          // measured_at
  final String? notas;           // notes

  const Lectura({
    this.id,
    required this.instrumento,
    required this.parametro,
    required this.unidad,
    required this.valor,
    required this.fecha,
    this.notas,
  });

  factory Lectura.fromJson(Map<String, dynamic> json) => Lectura(
        id: json['client_row_id'] as int?,
        instrumento: json['instrument_code'] as String? ?? json['instrumento'] ?? '',
        parametro: json['parameter'] as String? ?? 'nivel',
        unidad: json['unit'] as String? ?? 'm',
        valor: (json['value'] is num)
            ? (json['value'] as num).toDouble()
            : double.tryParse(json['valor']?.toString() ?? '0') ?? 0.0,
        fecha: DateTime.tryParse(json['measured_at'] ?? json['fecha'] ?? '') ?? DateTime.now(),
        notas: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'client_row_id': id,
        'instrument_code': instrumento,
        'parameter': parametro,
        'unit': unidad,
        'value': valor,
        'measured_at': fecha.toIso8601String(),
        'notes': notas ?? '',
      };
}
