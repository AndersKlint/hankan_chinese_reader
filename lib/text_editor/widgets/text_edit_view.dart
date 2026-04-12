import 'package:flutter/material.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';

/// Text editing view with a multi-line text field.
class TextEditView extends StatefulWidget {
  /// Initial text content.
  final String initialText;

  /// Called when text changes.
  final ValueChanged<String> onChanged;

  /// Persisted editor scroll controller.
  final ScrollController scrollController;

  /// Scroll physics used by the inner editable scroll view.
  final ScrollPhysics? scrollPhysics;

  /// Focus node used to reveal active search hit in view.
  final FocusNode focusNode;

  /// Current highlighted match selection.
  final TextSelection? highlightedSelection;

  /// Font size used by the editor content.
  final double fontSize;

  const TextEditView({
    super.key,
    required this.initialText,
    required this.onChanged,
    required this.scrollController,
    this.scrollPhysics,
    required this.focusNode,
    required this.fontSize,
    this.highlightedSelection,
  });

  @override
  State<TextEditView> createState() => _TextEditViewState();
}

class _TextEditViewState extends State<TextEditView> {
  late final TextEditingController _controller;
  bool _ignoreChange = false;

  TextStyle _textStyle(BuildContext context) {
    return textEditorContentTextStyle(context, fontSize: widget.fontSize) ??
        DefaultTextStyle.of(context).style.copyWith(fontSize: widget.fontSize);
  }

  StrutStyle _strutStyle(BuildContext context) {
    final strutStyle = textEditorContentStrutStyle(
      context,
      fontSize: widget.fontSize,
    );
    return strutStyle ?? StrutStyle.fromTextStyle(_textStyle(context));
  }

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

    final selection = widget.highlightedSelection;
    if (selection != null && selection != _controller.selection) {
      final maxOffset = _controller.text.length;
      final safeSelection = TextSelection(
        baseOffset: selection.baseOffset.clamp(0, maxOffset),
        extentOffset: selection.extentOffset.clamp(0, maxOffset),
      );
      _controller.selection = safeSelection;
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

    return TextEditorSurface(
      child: Padding(
        padding: textEditorContentPadding,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, child) {
            return Stack(
              fit: StackFit.expand,
              children: [
                if (value.text.isEmpty)
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        'Enter Chinese text here...',
                        style: textEditorContentTextStyle(
                          context,
                          fontSize: widget.fontSize,
                        )?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: EditableText(
            controller: _controller,
            focusNode: widget.focusNode,
            scrollController: widget.scrollController,
            scrollPhysics: widget.scrollPhysics,
            maxLines: null,
            expands: true,
            cursorColor: colorScheme.primary,
            backgroundCursorColor: colorScheme.onSurface,
            style: _textStyle(context),
            strutStyle: _strutStyle(context),
            textAlign: TextAlign.start,
            textDirection: Directionality.of(context),
            textHeightBehavior: textEditorContentTextHeightBehavior,
            selectionColor: colorScheme.primary.withValues(alpha: 0.24),
            onChanged: (text) {
              if (!_ignoreChange) {
                widget.onChanged(text);
              }
            },
          ),
        ),
      ),
    );
  }
}
