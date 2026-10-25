import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';

class TextEditView extends StatelessWidget {
  final QuillController controller;
  final ScrollController scrollController;
  final ScrollPhysics? scrollPhysics;
  final FocusNode focusNode;
  final double fontSize;
  final Future<void> Function() onPaste;
  final Map<ShortcutActivator, Intent> shortcuts;
  final Map<Type, Action<Intent>> actions;

  const TextEditView({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.focusNode,
    required this.fontSize,
    required this.onPaste,
    required this.shortcuts,
    required this.actions,
    this.scrollPhysics,
  });

  @override
  Widget build(BuildContext context) {
    DefaultTextBlockStyle block(int? heading) => DefaultTextBlockStyle(
      textEditorParagraphStyle(context, fontSize: fontSize, heading: heading),
      const HorizontalSpacing(0, 0),
      const VerticalSpacing(0, 0),
      const VerticalSpacing(0, 0),
      null,
    );
    return TextEditorSurface(
      child: QuillEditor(
        controller: controller,
        focusNode: focusNode,
        scrollController: scrollController,
        config: QuillEditorConfig(
          padding: textEditorContentPadding,
          expands: true,
          scrollPhysics: scrollPhysics,
          onTapOutsideEnabled: false,
          customShortcuts: shortcuts,
          customActions: {
            ...actions,
            PasteTextIntent: CallbackAction<PasteTextIntent>(
              onInvoke: (_) {
                onPaste();
                return null;
              },
            ),
          },
          customStyles: DefaultStyles(
            paragraph: block(null),
            h1: block(1),
            h2: block(2),
            h3: block(3),
          ),
          contextMenuBuilder: (context, state) =>
              AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: state.contextMenuButtonItems.map((item) {
                  if (item.type != ContextMenuButtonType.paste) return item;
                  return ContextMenuButtonItem(
                    type: ContextMenuButtonType.paste,
                    onPressed: () {
                      state.hideToolbar();
                      onPaste();
                    },
                  );
                }).toList(),
              ),
        ),
      ),
    );
  }
}
