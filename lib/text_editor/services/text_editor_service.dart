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
  DateTime? _typingBurstStartedAt;
  DateTime? _lastTypingEditAt;

  static const int _maxUndoHistory = 500;
  static const Duration _typingUndoMergeWindow = Duration(milliseconds: 800);

  /// Initializes the service with the given [text].
  void initialize(String text, {required bool isReadMode}) {
    _savedContent = text;
    content.value = text;
    isModified.value = false;
    this.isReadMode.value = isReadMode;
    _undoStack.clear();
    _redoStack.clear();
    _resetTypingUndoCoalescing();
  }

  /// Applies a user edit and records undo history.
  ///
  /// Rapid single-character insertions are merged into one undo step so normal
  /// typing behaves more like a desktop editor. Other edits, such as paste,
  /// deletion, or replacement, always create their own undo step.
  void applyUserEdit(String text, {DateTime? timestamp}) {
    final previousText = content.value;
    if (text == previousText) {
      return;
    }

    final editTime = timestamp ?? DateTime.now();
    final isTypingInsertion = _isSingleCharacterInsertion(previousText, text);
    final shouldMergeIntoPreviousTyping =
        isTypingInsertion && _shouldMergeTypingUndo(editTime);

    if (!shouldMergeIntoPreviousTyping) {
      _pushUndoState(previousText);
    } else {
      _redoStack.clear();
    }

    updateContent(text);
    if (isTypingInsertion) {
      if (!shouldMergeIntoPreviousTyping) {
        _typingBurstStartedAt = editTime;
      }
      _lastTypingEditAt = editTime;
    } else {
      _resetTypingUndoCoalescing();
    }
  }

  void _pushUndoState(String text) {
    _undoStack.addLast(text);
    if (_undoStack.length > _maxUndoHistory) {
      _undoStack.removeFirst();
    }
    _redoStack.clear();
  }

  bool _shouldMergeTypingUndo(DateTime editTime) {
    final typingBurstStartedAt = _typingBurstStartedAt;
    final lastTypingEditAt = _lastTypingEditAt;
    if (typingBurstStartedAt == null || lastTypingEditAt == null) {
      return false;
    }
    return editTime.difference(lastTypingEditAt) <= _typingUndoMergeWindow &&
        editTime.difference(typingBurstStartedAt) <= _typingUndoMergeWindow;
  }

  bool _isSingleCharacterInsertion(String previousText, String nextText) {
    if (nextText.length != previousText.length + 1) {
      return false;
    }

    var prefixLength = 0;
    while (prefixLength < previousText.length &&
        previousText.codeUnitAt(prefixLength) ==
            nextText.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    final suffixLength = previousText.length - prefixLength;
    for (var index = 0; index < suffixLength; index++) {
      if (previousText.codeUnitAt(previousText.length - 1 - index) !=
          nextText.codeUnitAt(nextText.length - 1 - index)) {
        return false;
      }
    }

    return true;
  }

  void _resetTypingUndoCoalescing() {
    _typingBurstStartedAt = null;
    _lastTypingEditAt = null;
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
    _resetTypingUndoCoalescing();
    _redoStack.addLast(content.value);
    content.value = _undoStack.removeLast();
    isModified.value = content.value != _savedContent;
  }

  /// Redoes the previously undone change.
  void redo() {
    if (!canRedo) return;
    _resetTypingUndoCoalescing();
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
