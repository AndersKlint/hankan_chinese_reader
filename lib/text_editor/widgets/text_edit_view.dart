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
    final textStyle = _textStyle(context);

    return TextEditorSurface(
      child: Padding(
        padding: textEditorContentPadding,
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          scrollController: widget.scrollController,
          scrollPhysics: widget.scrollPhysics,
          maxLines: null,
          expands: true,
          textAlign: TextAlign.start,
          style: textStyle,
          strutStyle: _strutStyle(context),
          cursorColor: colorScheme.primary,
          cursorWidth: 2.0,
          cursorRadius: Radius.zero,
          decoration: null, // Important: removes default decoration.
          onChanged: (text) {
            if (!_ignoreChange) {
              widget.onChanged(text);
            }
          },
        ),
      ),
    );
  }
}
