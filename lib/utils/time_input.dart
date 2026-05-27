class ManualTimeValue {
  final int minutes;
  final int seconds;

  const ManualTimeValue({
    required this.minutes,
    required this.seconds,
  });

  int get totalSeconds => minutes * 60 + seconds;
}

class ManualTimeValidation {
  final ManualTimeValue? value;
  final String? errorMessage;

  const ManualTimeValidation({
    this.value,
    this.errorMessage,
  });

  bool get isValid => errorMessage == null;
  bool get hasValue => value != null;
}

ManualTimeValidation validateManualTimeInput(
  String minutesRaw,
  String secondsRaw,
) {
  final minutesText = minutesRaw.trim();
  final secondsText = secondsRaw.trim();

  if (minutesText.isEmpty && secondsText.isEmpty) {
    return const ManualTimeValidation();
  }

  if (!_isUnsignedInteger(minutesText, allowEmpty: true)) {
    return const ManualTimeValidation(
      errorMessage: 'Minutos debe ser entero mayor o igual a 0.',
    );
  }
  if (!_isUnsignedInteger(secondsText, allowEmpty: true)) {
    return const ManualTimeValidation(
      errorMessage: 'Segundos debe ser entero entre 0 y 59.',
    );
  }

  final minutes = minutesText.isEmpty ? 0 : int.parse(minutesText);
  final seconds = secondsText.isEmpty ? 0 : int.parse(secondsText);

  if (seconds > 59) {
    return const ManualTimeValidation(
      errorMessage: 'Segundos debe estar entre 0 y 59.',
    );
  }

  return ManualTimeValidation(
    value: ManualTimeValue(minutes: minutes, seconds: seconds),
  );
}

bool _isUnsignedInteger(String value, {required bool allowEmpty}) {
  if (value.isEmpty) {
    return allowEmpty;
  }
  return RegExp(r'^\d+$').hasMatch(value);
}
