import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Manages text content and undo/redo state for a text editor tab.
class TextEditorService {
  /// The current text content.
  final ValueNotifier<String> content = ValueNotifier<String>('');

  /// Whether the document has been modified since last save.
  final ValueNotifier<bool> isModified = ValueNotifier<bool>(false);

  /// Whether the editor is in read mode (popup dict active).
  final ValueNotifier<bool> isReadMode = ValueNotifier<bool>(false);

  final Queue<String> _undoStack = Queue<String>();
  final Queue<String> _redoStack = Queue<String>();

  String _savedContent = '';

  static const int _maxUndoHistory = 100;

  /// Initializes the service with the given [text].
  void initialize(String text, {required bool isReadMode}) {
    _savedContent = text;
    content.value = text;
    isModified.value = false;
    this.isReadMode.value = isReadMode;
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Records a text change. Call before updating content for undo support.
  void pushUndoState() {
    _undoStack.addLast(content.value);
    if (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeFirst();
    }
    _redoStack.clear();
  }

  /// Updates the current text content and marks as modified.
  void updateContent(String text) {
    content.value = text;
    isModified.value = text != _savedContent;
  }

  /// Whether undo is available.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether redo is available.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Undoes the last change.
  void undo() {
    if (!canUndo) return;
    _redoStack.addLast(content.value);
    content.value = _undoStack.removeLast();
    isModified.value = content.value != _savedContent;
  }

  /// Redoes the previously undone change.
  void redo() {
    if (!canRedo) return;
    _undoStack.addLast(content.value);
    content.value = _redoStack.removeLast();
    isModified.value = content.value != _savedContent;
  }

  /// Marks the content as saved.
  void markSaved() {
    _savedContent = content.value;
    isModified.value = false;
  }

  /// Toggles between edit and read mode.
  void toggleReadMode() {
    isReadMode.value = !isReadMode.value;
  }

  /// Releases resources held by this service.
  ///
  /// Must be called when the owning widget is disposed to prevent
  /// [ValueNotifier] listener leaks.
  void dispose() {
    content.dispose();
    isModified.dispose();
    isReadMode.dispose();
  }
}
