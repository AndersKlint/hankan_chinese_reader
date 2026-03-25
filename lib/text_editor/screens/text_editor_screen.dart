import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_it/watch_it.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_edit_view.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_read_view.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_search_bar.dart';

/// Screen for editing and reading a text document.
class TextEditorScreen extends WatchingStatefulWidget {
  /// The tab ID this editor belongs to.
  final String tabId;

  const TextEditorScreen({super.key, required this.tabId});

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late final TextEditorService _editorService;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _editorService = TextEditorService();

    // Initialize with tab's text content.
    final tabService = getIt<TabService>();
    final tab = tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    _editorService.initialize(tab.textContent ?? '');

    // Sync modified state back to tab service.
    _editorService.isModified.addListener(_onModifiedChanged);
  }

  @override
  void dispose() {
    _editorService.isModified.removeListener(_onModifiedChanged);
    super.dispose();
  }

  void _onModifiedChanged() {
    final tabService = getIt<TabService>();
    tabService.setModified(
      widget.tabId,
      modified: _editorService.isModified.value,
    );
  }

  Future<void> _save() async {
    final tabService = getIt<TabService>();
    final fileService = getIt<FileService>();
    final tab = tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);

    final savedPath = await fileService.saveTextFile(
      content: _editorService.content.value,
      existingPath: tab.filePath,
    );

    if (savedPath != null) {
      tab.filePath = savedPath;
      tab.textContent = _editorService.content.value;
      final fileName = savedPath.split('/').last.split('\\').last;
      tabService.setTitle(widget.tabId, fileName);
      _editorService.markSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReadMode = watch(_editorService.isReadMode).value;
    final content = watch(_editorService.content).value;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () =>
            _editorService.undo(),
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () =>
            _editorService.redo(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            setState(() => _showSearch = !_showSearch),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // Toolbar
            _Toolbar(
              isReadMode: isReadMode,
              onToggleMode: _editorService.toggleReadMode,
              onUndo: _editorService.canUndo ? _editorService.undo : null,
              onRedo: _editorService.canRedo ? _editorService.redo : null,
              onSave: _save,
              onSearch: () => setState(() => _showSearch = !_showSearch),
            ),

            // Search bar
            if (_showSearch)
              TextSearchBar(
                text: content,
                onClose: () => setState(() => _showSearch = false),
              ),

            // Editor / Reader content
            Expanded(
              child: isReadMode
                  ? TextReadView(text: content)
                  : TextEditView(
                      initialText: content,
                      onChanged: (text) {
                        _editorService.pushUndoState();
                        _editorService.updateContent(text);
                        // Keep tab model in sync.
                        final tabService = getIt<TabService>();
                        final tab = tabService.tabs.value.firstWhere(
                          (t) => t.id == widget.tabId,
                        );
                        tab.textContent = text;
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Toolbar for the text editor.
class _Toolbar extends StatelessWidget {
  final bool isReadMode;
  final VoidCallback onToggleMode;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback onSave;
  final VoidCallback onSearch;

  const _Toolbar({
    required this.isReadMode,
    required this.onToggleMode,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Edit / Read toggle
          TextButton.icon(
            icon: Icon(
              isReadMode ? Icons.edit_outlined : Icons.auto_stories,
              size: 18,
            ),
            label: Text(isReadMode ? 'Edit' : 'Read'),
            onPressed: onToggleMode,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),

          if (!isReadMode) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: onUndo,
              iconSize: 20,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onPressed: onRedo,
              iconSize: 20,
            ),
            const VerticalDivider(indent: 10, endIndent: 10),
          ],

          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search (Ctrl+F)',
            onPressed: onSearch,
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save (Ctrl+S)',
            onPressed: onSave,
            iconSize: 20,
          ),

          const Spacer(),

          // Mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReadMode
                  ? colorScheme.tertiaryContainer
                  : colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isReadMode ? 'Reading' : 'Editing',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isReadMode
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
