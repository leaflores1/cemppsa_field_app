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
  final double? value;

  /// Valor raw escrito por el técnico, incluso si no se pudo parsear.
  final String? valorRaw;

  /// True si el valor ingresado no pudo convertirse a número válido.
  final bool? valorInvalido;

  /// Snapshot del rango aplicado al momento de tomar la lectura.
  final bool? fueraDeRango;
  final double? rangoMin;
  final double? rangoMax;
  final int? rangoVersion;

  /// True si el técnico confirmó explícitamente enviar una lectura fuera de rango.
  final bool? advertenciaConfirmada;

  /// Fecha y hora de la medición (ISO 8601)
  final DateTime measuredAt;

  /// Observaciones opcionales del técnico
  final String? notes;

  Lectura({
    required this.clientRowId,
    required this.instrumentCode,
    this.parameter,
    this.unit,
    this.value,
    required this.measuredAt,
    this.notes,
    this.valorRaw,
    this.valorInvalido,
    this.fueraDeRango,
    this.rangoMin,
    this.rangoMax,
    this.rangoVersion,
    this.advertenciaConfirmada,
  });

  static String normalizeRawValue(String rawValue) => rawValue.trim();

  static double? parseRawValue(String rawValue) {
    final normalized = normalizeRawValue(rawValue);
    if (normalized.isEmpty || normalized.contains(',')) {
      return null;
    }

    final parsedValue = double.tryParse(normalized);
    if (parsedValue == null || !parsedValue.isFinite) {
      return null;
    }

    return parsedValue;
  }

  static bool isInvalidRawValue(String rawValue) {
    final normalized = normalizeRawValue(rawValue);
    if (normalized.isEmpty) {
      return false;
    }

    return parseRawValue(normalized) == null;
  }

  /// Constructor desde formulario con manejo de decimales con coma
  factory Lectura.fromForm({
    required int clientRowId,
    required String instrumentCode,
    String? parameter,
    String? unit,
    required String rawValue,
    required DateTime measuredAt,
    String? notes,
    bool? fueraDeRango,
    double? rangoMin,
    double? rangoMax,
    int? rangoVersion,
    bool? advertenciaConfirmada,
  }) {
    final normalizedValue = normalizeRawValue(rawValue);
    final parsedValue = parseRawValue(normalizedValue);
    final invalidValue = normalizedValue.isNotEmpty && parsedValue == null;

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
      valorRaw: normalizedValue.isEmpty ? null : normalizedValue,
      valorInvalido: invalidValue ? true : null,
      fueraDeRango: invalidValue ? null : fueraDeRango,
      rangoMin: invalidValue ? null : rangoMin,
      rangoMax: invalidValue ? null : rangoMax,
      rangoVersion: invalidValue ? null : rangoVersion,
      advertenciaConfirmada:
          invalidValue ? null : advertenciaConfirmada,
    );
  }

  /// Serializa para cache local (Hive)
  Map<String, dynamic> toJson() {
    return {
      'client_row_id': clientRowId,
      'instrument_code': instrumentCode, // Ya canonicalizado en constructor
      if (parameter != null) 'parameter': parameter,
      if (unit != null) 'unit': unit,
      'value': value,
      'measured_at': measuredAt.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (valorRaw != null) 'valor_raw': valorRaw,
      if (valorInvalido != null) 'valor_invalido': valorInvalido,
      if (fueraDeRango != null) 'fuera_de_rango': fueraDeRango,
      if (rangoMin != null) 'rango_min': rangoMin,
      if (rangoMax != null) 'rango_max': rangoMax,
      if (rangoVersion != null) 'rango_version': rangoVersion,
      if (advertenciaConfirmada != null)
        'advertencia_confirmada': advertenciaConfirmada,
    };
  }

  /// Serializa para envío al backend.
  Map<String, dynamic> toSyncJson() {
    return {
      'client_row_id': clientRowId,
      'instrument_code': instrumentCode,
      if (parameter != null) 'parameter': parameter,
      if (unit != null) 'unit': unit,
      if (value != null) 'value': value,
      'measured_at': measuredAt.toIso8601String(),
      if (notes != null) 'notes': notes,
      if (fueraDeRango != null) 'fuera_de_rango': fueraDeRango,
      if (rangoMin != null) 'rango_min': rangoMin,
      if (rangoMax != null) 'rango_max': rangoMax,
      if (rangoVersion != null) 'rango_version': rangoVersion,
      if (advertenciaConfirmada != null)
        'advertencia_confirmada': advertenciaConfirmada,
    };
  }

  /// Deserializa desde JSON (respuesta del servidor o cache)
  factory Lectura.fromJson(Map<String, dynamic> json) {
    return Lectura(
      clientRowId: json['client_row_id'] as int,
      instrumentCode: json['instrument_code'] as String,
      parameter: json['parameter'] as String?,
      unit: json['unit'] as String?,
      value: _readDouble(json['value']),
      measuredAt: DateTime.parse(json['measured_at'] as String),
      notes: json['notes'] as String?,
      valorRaw: json['valor_raw'] as String?,
      valorInvalido: _readBool(json['valor_invalido']),
      fueraDeRango: _readBool(json['fuera_de_rango']),
      rangoMin: _readDouble(json['rango_min']),
      rangoMax: _readDouble(json['rango_max']),
      rangoVersion: json['rango_version'] as int?,
      advertenciaConfirmada: _readBool(json['advertencia_confirmada']),
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
    String? valorRaw,
    bool? valorInvalido,
    bool? fueraDeRango,
    double? rangoMin,
    double? rangoMax,
    int? rangoVersion,
    bool? advertenciaConfirmada,
  }) {
    return Lectura(
      clientRowId: clientRowId ?? this.clientRowId,
      instrumentCode: instrumentCode ?? this.instrumentCode,
      parameter: parameter ?? this.parameter,
      unit: unit ?? this.unit,
      value: value ?? this.value,
      measuredAt: measuredAt ?? this.measuredAt,
      notes: notes ?? this.notes,
      valorRaw: valorRaw ?? this.valorRaw,
      valorInvalido: valorInvalido ?? this.valorInvalido,
      fueraDeRango: fueraDeRango ?? this.fueraDeRango,
      rangoMin: rangoMin ?? this.rangoMin,
      rangoMax: rangoMax ?? this.rangoMax,
      rangoVersion: rangoVersion ?? this.rangoVersion,
      advertenciaConfirmada:
          advertenciaConfirmada ?? this.advertenciaConfirmada,
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

double? _readDouble(dynamic raw) {
  if (raw is num) {
    return raw.toDouble();
  }
  if (raw == null) {
    return null;
  }
  return double.tryParse(raw.toString());
}

bool? _readBool(dynamic raw) {
  if (raw is bool) {
    return raw;
  }
  if (raw is num) {
    return raw != 0;
  }
  if (raw == null) {
    return null;
  }
  final normalized = raw.toString().trim().toLowerCase();
  if (normalized == 'true') {
    return true;
  }
  if (normalized == 'false') {
    return false;
  }
  return null;
}
