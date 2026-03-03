// ==============================================================================
// CEMPPSA Field App - Modelo Lectura
// Alineado con: backend LecturaAppRequest (POST /api/v1/ingesta/planillas)
// ==============================================================================

import 'instrumento.dart';

/// Lectura individual cruda para Bronze.
///
/// Este modelo representa UNA medición tal como se envía al backend.
/// Mapea exactamente al tipo `LecturaAppRequest` del endpoint de ingesta.
///
/// Contrato backend esperado:
/// ```json
/// {
///   "client_row_id": 1,
///   "instrument_code": "PC01",
///   "parameter": null,       // opcional - backend infiere de familia
///   "unit": "mca",           // opcional
///   "value": 12.5,
///   "measured_at": "2025-01-13T10:30:00",
///   "notes": "..."           // opcional
/// }
/// ```
class Lectura {
  /// ID único generado en el cliente para trazabilidad
  final int clientRowId;

  /// Código del instrumento (ej: PC01, PP5, AFPP)
  /// Backend resuelve código → id_instrumento
  final String instrumentCode;

  /// Parámetro medido (ej: presion, nivel, altura, caudal, frecuencia)
  /// Opcional: si es null, el backend lo infiere de la familia del instrumento
  final String? parameter;

  /// Unidad de medida (ej: mca, m.s.n.m., mm, l/s, Hz²)
  final String? unit;

  /// Valor numérico de la medición
  final double value;

  /// Fecha y hora de la medición (ISO 8601)
  final DateTime measuredAt;

  /// Observaciones opcionales del técnico
  final String? notes;

  Lectura({
    required this.clientRowId,
    required this.instrumentCode,
    this.parameter,
    this.unit,
    required this.value,
    required this.measuredAt,
    this.notes,
  });

  /// Constructor desde formulario con manejo de decimales con coma
  factory Lectura.fromForm({
    required int clientRowId,
    required String instrumentCode,
    String? parameter,
    String? unit,
    required String rawValue,
    required DateTime measuredAt,
    String? notes,
  }) {
    // Normalizar valor: coma → punto
    final normalizedValue = rawValue.replaceAll(',', '.').trim();
    final parsedValue = double.tryParse(normalizedValue) ?? 0.0;

    // Canonicalizar código del instrumento (PC-05 → PC05)
    final canonicalCode =
        CodigoHelper.canonicalize(instrumentCode.toUpperCase().trim());

    return Lectura(
      clientRowId: clientRowId,
      instrumentCode: canonicalCode,
      parameter: parameter?.toLowerCase().trim(),
      unit: unit?.trim(),
      value: parsedValue,
      measuredAt: measuredAt,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );
  }

  /// Serializa para envío al backend (POST /api/v1/ingesta/planillas)
  Map<String, dynamic> toJson() {
    return {
      'client_row_id': clientRowId,
      'instrument_code': instrumentCode, // Ya canonicalizado en constructor
      if (parameter != null) 'parameter': parameter,
      if (unit != null) 'unit': unit,
      'value': value,
      'measured_at': measuredAt.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }

  /// Deserializa desde JSON (respuesta del servidor o cache)
  factory Lectura.fromJson(Map<String, dynamic> json) {
    return Lectura(
      clientRowId: json['client_row_id'] as int,
      instrumentCode: json['instrument_code'] as String,
      parameter: json['parameter'] as String?,
      unit: json['unit'] as String?,
      value: (json['value'] as num).toDouble(),
      measuredAt: DateTime.parse(json['measured_at'] as String),
      notes: json['notes'] as String?,
    );
  }

  /// Copia con modificaciones
  Lectura copyWith({
    int? clientRowId,
    String? instrumentCode,
    String? parameter,
    String? unit,
    double? value,
    DateTime? measuredAt,
    String? notes,
  }) {
    return Lectura(
      clientRowId: clientRowId ?? this.clientRowId,
      instrumentCode: instrumentCode ?? this.instrumentCode,
      parameter: parameter ?? this.parameter,
      unit: unit ?? this.unit,
      value: value ?? this.value,
      measuredAt: measuredAt ?? this.measuredAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'Lectura(clientRowId: $clientRowId, instrumentCode: $instrumentCode, '
        'parameter: $parameter, value: $value $unit, measuredAt: $measuredAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Lectura &&
        other.clientRowId == clientRowId &&
        other.instrumentCode == instrumentCode;
  }

  @override
  int get hashCode => clientRowId.hashCode ^ instrumentCode.hashCode;
}
