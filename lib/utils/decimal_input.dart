String normalizeDecimalInput(String rawValue) => rawValue.trim();

const String decimalInputFormatHelp = 'Usa coma o punto como decimal';

final RegExp _decimalValuePattern = RegExp(
  r'^[+-]?(?:\d+(?:[.,]\d+)?|[.,]\d+)$',
);

double? parseDecimalInput(String rawValue) {
  final normalized = normalizeDecimalInput(rawValue);
  if (normalized.isEmpty || !_decimalValuePattern.hasMatch(normalized)) {
    return null;
  }

  final canonical = (normalized.startsWith(',') || normalized.startsWith('.'))
      ? '0$normalized'
      : normalized;
  final parsedValue = double.tryParse(canonical.replaceAll(',', '.'));
  if (parsedValue == null || !parsedValue.isFinite) {
    return null;
  }

  return parsedValue;
}

bool isInvalidDecimalInput(String rawValue) {
  final normalized = normalizeDecimalInput(rawValue);
  if (normalized.isEmpty) {
    return false;
  }
  return parseDecimalInput(normalized) == null;
}
