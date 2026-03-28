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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > 900
            ? ((constraints.maxWidth - 860) / 2).clamp(24.0, 220.0)
            : 16.0;

        final isDark = colorScheme.brightness == Brightness.dark;
        final backgroundSurface = isDark
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow;
        final editorSurface = isDark
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface;

        return ColoredBox(
          color: backgroundSurface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 16),
            child: Container(
              decoration: BoxDecoration(
                color: editorSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: colorScheme.primary,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    height: 1.8,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: 'Enter Chinese text here...',
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.8,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    contentPadding: const EdgeInsets.all(20),
                    filled: true,
                    fillColor: editorSurface,
                    hoverColor: editorSurface,
                    focusColor: editorSurface,
                  ),
                  onChanged: (text) {
                    if (!_ignoreChange) {
                      widget.onChanged(text);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
