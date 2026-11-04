import '../data/models/lectura.dart';
import '../data/models/schema_model.dart';

/// Códigos con los que `cr10x_channel_map` nombra el canal de lectura cruda
/// principal del datalogger. El schema móvil nombra esa misma lectura con la
/// variable por defecto de la familia (p. ej. `PERIODO`, `LECTURA_LU`).
const Set<String> cr10xRawChannelAliases = {'LECTURA', 'LECTURA_CR10X'};

/// Devuelve las variables de captura habilitadas para [instrumentCode].
///
/// - `null`: sin restricción (no hay configuración por canal, o la
///   configuración usa códigos que el schema de la familia no reconoce).
/// - conjunto vacío: el backend informó todos los canales inactivos.
/// - conjunto no vacío: solo esas variables están habilitadas.
///
/// Un desajuste de nombres entre `active_variable_codes` y las variables del
/// schema nunca debe interpretarse como "ninguna variable habilitada": eso
/// descartaba lecturas válidas de piezómetros, celdas, termómetros,
/// uniaxiales y triaxiales.
Set<String>? cr10xActiveVariableCodesForInstrument(
  MobileSchema? schema,
  String instrumentCode,
) {
  if (schema == null) return null;

  final normalizedInstrumentCode = instrumentCode.trim().toUpperCase();
  SchemaInstrument? schemaInstrument;
  for (final instrument in schema.instruments) {
    if (instrument.codigo.trim().toUpperCase() == normalizedInstrumentCode) {
      schemaInstrument = instrument;
      break;
    }
  }

  final configuredCodes = schemaInstrument?.activeVariableCodes;
  if (configuredCodes == null) return null;

  final familyCodes = schema.variables
      .map((variable) => variable.code.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet();
  final defaultCode = _schemaDefaultVariableCode(schema);

  final active = <String>{};
  for (final rawCode in configuredCodes) {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) continue;
    if (familyCodes.contains(code)) {
      active.add(code);
    } else if (cr10xRawChannelAliases.contains(code) && defaultCode != null) {
      active.add(defaultCode);
    } else {
      // Vocabulario desconocido: no restringir antes que perder lecturas.
      return null;
    }
  }
  return active;
}

String? _schemaDefaultVariableCode(MobileSchema schema) {
  for (final variable in schema.variables) {
    final code = variable.code.trim().toUpperCase();
    if (variable.isDefault && code.isNotEmpty) return code;
  }
  for (final variable in schema.variables) {
    final code = variable.code.trim().toUpperCase();
    if (code.isNotEmpty) return code;
  }
  return null;
}

bool cr10xInstrumentAllowsVariable(
  MobileSchema? schema,
  String instrumentCode,
  String variableCode,
) {
  final activeCodes =
      cr10xActiveVariableCodesForInstrument(schema, instrumentCode);
  return activeCodes == null ||
      activeCodes.contains(variableCode.trim().toUpperCase());
}

/// Mensaje visible para una planilla con lecturas de variables no habilitadas.
/// Empieza con "La planilla contiene" para que `userFacingSyncError` lo
/// muestre tal cual en lugar del mensaje genérico.
String cr10xBlockedReadingsMessage(List<Lectura> blocked) {
  final labels = blocked
      .map((reading) =>
          '${reading.instrumentCode} ${reading.parameter?.toUpperCase() ?? '-'}')
      .toSet()
      .toList()
    ..sort();
  final shown = labels.take(3).join(', ');
  final extra = labels.length > 3 ? ' y ${labels.length - 3} más' : '';
  return 'La planilla contiene ${blocked.length} lectura(s) de variables no '
      'habilitadas ($shown$extra). Abrila en CR10X para revisarlas; '
      'no se envió ni se borró nada.';
}

class Cr10xSanitizationResult {
  final List<Lectura> readings;
  final List<Lectura> removedReadings;

  const Cr10xSanitizationResult({
    required this.readings,
    required this.removedReadings,
  });
}

Cr10xSanitizationResult sanitizeCr10xReadingsAgainstSchema(
  Iterable<Lectura> readings,
  MobileSchema? schema,
) {
  if (schema == null) {
    return Cr10xSanitizationResult(
      readings: List<Lectura>.from(readings),
      removedReadings: const [],
    );
  }

  final kept = <Lectura>[];
  final removed = <Lectura>[];
  for (final reading in readings) {
    final activeCodes = cr10xActiveVariableCodesForInstrument(
      schema,
      reading.instrumentCode,
    );
    if (activeCodes == null) {
      kept.add(reading);
      continue;
    }

    final parameter = reading.parameter?.trim().toUpperCase();
    if (parameter != null && activeCodes.contains(parameter)) {
      kept.add(reading);
    } else {
      removed.add(reading);
    }
  }

  return Cr10xSanitizationResult(
    readings: kept,
    removedReadings: removed,
  );
}
