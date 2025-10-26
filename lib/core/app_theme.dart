import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData theme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.indigo,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
