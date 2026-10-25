import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme configuration using Material 3.
///
/// Theme data is computed once and cached to avoid rebuilding
/// [ColorScheme.fromSeed], [GoogleFonts] text themes, and [ThemeData] on
/// every access.
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF1A73E8);

  /// Light theme (cached).
  static final ThemeData light = _buildLight();

  /// Dark theme (cached).
  static final ThemeData dark = _buildDark();

  static ThemeData _buildLight() {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    final colorScheme = baseColorScheme.copyWith(
      surfaceContainerLowest: baseColorScheme.surfaceContainerHighest,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildDark() {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    final colorScheme = baseColorScheme.copyWith(
      surface: const Color(0xFF252527),
      surfaceContainerHighest: const Color(0xFF3A3A3C),
      surfaceContainerHigh: const Color(0xFF323234),
      surfaceContainer: const Color(0xFF323234),
      surfaceContainerLow: const Color(0xFF2A2A2C),
      surfaceContainerLowest: const Color(0xFF1F1F21),
      onSurface: const Color(0xFFE8E8E8),
      onSurfaceVariant: const Color(0xFF999999),
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final textTheme = TextTheme(
      displayLarge: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      displayMedium: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      displaySmall: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      headlineLarge: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      headlineMedium: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      headlineSmall: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      titleLarge: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      titleMedium: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      titleSmall: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      bodyLarge: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      bodyMedium: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      bodySmall: GoogleFonts.notoSansSc(color: colorScheme.onSurfaceVariant),
      labelLarge: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      labelMedium: GoogleFonts.notoSansSc(color: colorScheme.onSurface),
      labelSmall: GoogleFonts.notoSansSc(color: colorScheme.onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        dividerHeight: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
      ),
    );
  }
}
