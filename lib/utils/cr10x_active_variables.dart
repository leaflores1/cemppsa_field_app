import '../data/models/lectura.dart';
import '../data/models/schema_model.dart';

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
  return configuredCodes
      .map((code) => code.trim().toUpperCase())
      .where(familyCodes.contains)
      .toSet();
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
