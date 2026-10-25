import 'package:flutter/material.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';

class TextFormattingToolbar extends StatelessWidget {
  final TextEditorService service;
  final bool isReadMode;

  const TextFormattingToolbar({
    super.key,
    required this.service,
    required this.isReadMode,
  });

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback? callback, {
    bool selected = false,
  }) => IconButton(
    icon: Icon(icon, size: 18),
    tooltip: tooltip,
    onPressed: callback,
    isSelected: selected && !isReadMode,
    visualDensity: VisualDensity.compact,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: service.controller,
    builder: (context, _) => Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _button(
                    Icons.undo,
                    'Undo (Ctrl+Z)',
                    !isReadMode && service.canUndo ? service.undo : null,
                  ),
                  _button(
                    Icons.redo,
                    'Redo (Ctrl+Shift+Z)',
                    !isReadMode && service.canRedo ? service.redo : null,
                  ),
                  const VerticalDivider(indent: 10, endIndent: 10),
                  DropdownButton<int>(
                    value: service.headingLevel ?? 0,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isReadMode
                          ? Theme.of(context).disabledColor
                          : null,
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Normal')),
                      DropdownMenuItem(value: 1, child: Text('Heading 1')),
                      DropdownMenuItem(value: 2, child: Text('Heading 2')),
                      DropdownMenuItem(value: 3, child: Text('Heading 3')),
                    ],
                    onChanged: isReadMode
                        ? null
                        : (level) =>
                              service.setHeading(level == 0 ? null : level),
                  ),
                  const VerticalDivider(indent: 10, endIndent: 10),
                  _button(
                    Icons.format_bold,
                    'Bold (Ctrl+B)',
                    isReadMode ? null : service.toggleBold,
                    selected: service.isBold,
                  ),
                  _button(
                    Icons.format_italic,
                    'Italic (Ctrl+I)',
                    isReadMode ? null : service.toggleItalic,
                    selected: service.isItalic,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
