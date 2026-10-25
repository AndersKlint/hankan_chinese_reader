import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';

typedef EditorFormattingState = ({
  bool canUndo,
  bool canRedo,
  int heading,
  bool bold,
  bool italic,
});

class EditorFormattingService extends ValueNotifier<EditorFormattingState> {
  final QuillController _controller;
  late final StreamSubscription<DocChange> _changes;
  bool _scheduled = false;
  bool _disposed = false;

  EditorFormattingService(QuillController controller)
    : _controller = controller,
      super(_snapshot(controller)) {
    _controller.addListener(_scheduleRefresh);
    _changes = _controller.changes.listen((_) => _scheduleRefresh());
  }

  static EditorFormattingState _snapshot(QuillController controller) {
    final attributes = controller.getSelectionStyle().attributes;
    final heading = attributes['header']?.value;
    return (
      canUndo: controller.hasUndo,
      canRedo: controller.hasRedo,
      heading: heading == 1 || heading == 2 || heading == 3
          ? heading as int
          : 0,
      bold: attributes['bold']?.value == true,
      italic: attributes['italic']?.value == true,
    );
  }

  void _scheduleRefresh() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    // History records document changes after synchronous controller listeners.
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed) value = _snapshot(_controller);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_scheduleRefresh);
    _changes.cancel();
    super.dispose();
  }
}
