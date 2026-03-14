import 'package:flutter/material.dart';

class AppTheme {
  // Paleta base (inspirada en tu consola web)
  static const _bgTop = Color(0xFF0B1322); // #0b1322
  static const _bgMid = Color(0xFF0D1A2E); // #0d1a2e
  static const _bgBot = Color(0xFF14233A); // #14233a

  static const _surface = Color(0xFF0F1A2B);
  static const _card = Color(0x1AFFFFFF); // white with ~10% opacity
  static const _border = Color(0x1AFFFFFF);

  static const _primary = Color(0xFF7DE3F7); // cyan-ish
  static const _secondary = Color(0xFF9FB7FF); // blue-ish

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: Color(0xFF07101A),
      secondary: _secondary,
      onSecondary: Color(0xFF0B1322),
      error: Color(0xFFFF6B6B),
      onError: Color(0xFF1A0A0A),
      surface: _surface,
      onSurface: Color(0xFFE7EEF8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _bgTop,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // AppBar tipo “sticky header” pro
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFE7EEF8),
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),

      // Cards translúcidas con borde suave
      cardTheme: CardThemeData(
        color: _card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0x1AFFFFFF),
        thickness: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1A2B).withValues(alpha: 0.95),
        contentTextStyle: const TextStyle(color: Color(0xFFE7EEF8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // Inputs estilo “glass”
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0x14FFFFFF), // ~8%
        labelStyle: const TextStyle(color: Color(0xFFB6C6DA)),
        hintStyle: const TextStyle(color: Color(0xFF8EA3BB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x667DE3F7)),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Color(0xFF07101A),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0x14FFFFFF),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
        labelStyle: const TextStyle(color: Color(0xFFE7EEF8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),

      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: Color(0xFFE7EEF8),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE7EEF8),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Color(0xFFCFDBEA),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: Color(0xFF9FB0C6),
        ),
      ),
    );
  }

  /// Fondo “hero” para usar en pantallas (igual al gradiente de la web)
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_bgTop, _bgMid, _bgBot],
  );
}
