import 'package:flutter/material.dart';

/// Text editing view with a multi-line text field.
class TextEditView extends StatefulWidget {
  /// Initial text content.
  final String initialText;

  /// Called when text changes.
  final ValueChanged<String> onChanged;

  const TextEditView({
    super.key,
    required this.initialText,
    required this.onChanged,
  });

  @override
  State<TextEditView> createState() => _TextEditViewState();
}

class _TextEditViewState extends State<TextEditView> {
  late final TextEditingController _controller;
  bool _ignoreChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant TextEditView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller if content changed externally (e.g. undo/redo).
    if (widget.initialText != _controller.text) {
      _ignoreChange = true;
      _controller.text = widget.initialText;
      _ignoreChange = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 18,
              height: 1.8,
            ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Enter Chinese text here...',
          contentPadding: EdgeInsets.all(16),
        ),
        onChanged: (text) {
          if (!_ignoreChange) {
            widget.onChanged(text);
          }
        },
      ),
    );
  }
}
