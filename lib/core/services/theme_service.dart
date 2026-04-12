import 'package:flutter/material.dart';

/// Controls the application-wide [ThemeMode].
///
/// Extends [ValueNotifier] so the root [MaterialApp] can rebuild reactively
/// when the theme changes.
class ThemeService extends ValueNotifier<ThemeMode> {
  /// Creates a [ThemeService] with the initial [ThemeMode.system].
  ThemeService() : super(ThemeMode.system);

  /// Sets the theme to a specific [mode].
  void setThemeMode(ThemeMode mode) {
    value = mode;
  }

  /// Toggles between light and dark themes.
  void toggleTheme() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }
}
