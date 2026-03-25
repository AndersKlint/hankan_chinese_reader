import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Application theme configuration using Material 3.
class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF1A73E8);

  /// Light theme.
  static ThemeData get light {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    final colorScheme = baseColorScheme.copyWith(
      surfaceContainerLowest: baseColorScheme.surfaceContainerHighest,
    );
    return _buildTheme(colorScheme);
  }

  /// Dark theme.
  static ThemeData get dark {
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
    final textTheme = GoogleFonts.notoSansScTextTheme(
      TextTheme(
        displayLarge: TextStyle(color: colorScheme.onSurface),
        displayMedium: TextStyle(color: colorScheme.onSurface),
        displaySmall: TextStyle(color: colorScheme.onSurface),
        headlineLarge: TextStyle(color: colorScheme.onSurface),
        headlineMedium: TextStyle(color: colorScheme.onSurface),
        headlineSmall: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(color: colorScheme.onSurface),
        titleMedium: TextStyle(color: colorScheme.onSurface),
        titleSmall: TextStyle(color: colorScheme.onSurface),
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(color: colorScheme.onSurfaceVariant),
        labelLarge: TextStyle(color: colorScheme.onSurface),
        labelMedium: TextStyle(color: colorScheme.onSurface),
        labelSmall: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
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
