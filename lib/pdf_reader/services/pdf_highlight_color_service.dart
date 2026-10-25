import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PdfHighlightColorService extends ChangeNotifier {
  static const _key = 'pdf_highlight_colors';
  static const _noneKey = 'pdf_highlight_color_none';
  final SharedPreferences _preferences;
  bool _noneSelected = false;
  final List<Color> _recentColors = [];
  final List<Color> presetColors = const [
    Color(0xFFFFEB3B),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFF06292),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
  ];

  PdfHighlightColorService(this._preferences) {
    _noneSelected = _preferences.getBool(_noneKey) ?? false;
    final values = _preferences.getStringList(_key) ?? [];
    for (final value in values) {
      final number = int.tryParse(value);
      if (number == null) continue;
      final color = Color(number).withValues(alpha: 1);
      if (!_recentColors.contains(color)) _recentColors.add(color);
      if (_recentColors.length == 8) break;
    }
  }

  Color? get selectedColor =>
      _noneSelected ? null : _recentColors.firstOrNull ?? presetColors.first;
  List<Color> get recentColors => List.unmodifiable(_recentColors);

  Future<void> selectColor(Color? color) async {
    _noneSelected = color == null;
    if (color != null) {
      color = color.withValues(alpha: 1);
      _recentColors
        ..remove(color)
        ..insert(0, color);
      if (_recentColors.length > 8) _recentColors.removeLast();
    }
    notifyListeners();
    final saved = await _preferences.setStringList(
      _key,
      _recentColors.map((color) => color.toARGB32().toString()).toList(),
    );
    if (!saved) throw StateError('Could not persist highlight colors.');
    final selectionSaved = await _preferences.setBool(_noneKey, _noneSelected);
    if (!selectionSaved) {
      throw StateError('Could not persist highlight color selection.');
    }
  }
}
