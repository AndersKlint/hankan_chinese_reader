import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:watch_it/watch_it.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
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
  late final TabService _tabService;
  late final ScrollController _readScrollController;
  late final ScrollController _editScrollController;
  late final FocusNode _editFocusNode;

  bool _showSearch = false;
  String _searchQuery = '';
  List<TextSearchResult> _matches = const <TextSearchResult>[];
  int _currentMatchIndex = -1;
  GlobalKey? _activeMatchKey;

  @override
  void initState() {
    super.initState();
    _editorService = TextEditorService();
    _tabService = getIt<TabService>();

    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    _readScrollController = ScrollController(
      initialScrollOffset: tab.textReadScrollOffset,
    );
    _editScrollController = ScrollController(
      initialScrollOffset: tab.textEditScrollOffset,
    );
    _editFocusNode = FocusNode();
    _readScrollController.addListener(_persistReadScrollOffset);
    _editScrollController.addListener(_persistEditScrollOffset);

    // Initialize with tab's text content.
    _editorService.initialize(
      tab.textContent ?? '',
      isReadMode: tab.isReadMode,
    );
    _showSearch = tab.showTextSearch;
    _searchQuery = tab.textSearchQuery;
    if (_searchQuery.isNotEmpty) {
      _recomputeSearchMatches(_editorService.content.value, _searchQuery);
    }

    // Sync modified state back to tab service.
    _editorService.isModified.addListener(_onModifiedChanged);
  }

  @override
  void dispose() {
    _editorService.isModified.removeListener(_onModifiedChanged);
    _readScrollController.removeListener(_persistReadScrollOffset);
    _editScrollController.removeListener(_persistEditScrollOffset);
    _readScrollController.dispose();
    _editScrollController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _persistReadScrollOffset() {
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.textReadScrollOffset = _readScrollController.offset;
  }

  void _persistEditScrollOffset() {
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.textEditScrollOffset = _editScrollController.offset;
  }

  void _onModifiedChanged() {
    final tabService = getIt<TabService>();
    tabService.setModified(
      widget.tabId,
      modified: _editorService.isModified.value,
    );
  }

  void _setShowSearch(bool show) {
    setState(() {
      _showSearch = show;
      if (!show) {
        _searchQuery = '';
        _matches = const <TextSearchResult>[];
        _currentMatchIndex = -1;
        _activeMatchKey = null;
      }
    });
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.showTextSearch = show;
    if (!show) {
      tab.textSearchQuery = '';
    }
    _tabService.notifyTabStateChanged();
  }

  void _recomputeSearchMatches(String text, String query) {
    if (query.isEmpty) {
      setState(() {
        _matches = const <TextSearchResult>[];
        _currentMatchIndex = -1;
        _activeMatchKey = null;
      });
      return;
    }

    final matches = <TextSearchResult>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        break;
      }
      matches.add(TextSearchResult(start: index, end: index + query.length));
      start = index + 1;
    }

    setState(() {
      _matches = matches;
      _currentMatchIndex = matches.isEmpty ? -1 : 0;
    });
    _scrollToActiveMatch();
  }

  void _onSearchQueryChanged(String query) {
    if (_searchQuery == query) {
      return;
    }
    _searchQuery = query;
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.textSearchQuery = query;
    _tabService.notifyTabStateChanged();
    _recomputeSearchMatches(_editorService.content.value, query);
  }

  void _nextMatch() {
    if (_matches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    });
    _scrollToActiveMatch();
  }

  void _previousMatch() {
    if (_matches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matches.length) % _matches.length;
    });
    _scrollToActiveMatch();
  }

  String get _matchLabel {
    if (_searchQuery.isEmpty) {
      return '';
    }
    if (_matches.isEmpty) {
      return 'No results';
    }
    return '${_currentMatchIndex + 1}/${_matches.length}';
  }

  TextSelection? get _activeSelection {
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) {
      return null;
    }
    final match = _matches[_currentMatchIndex];
    return TextSelection(baseOffset: match.start, extentOffset: match.end);
  }

  void _scrollToActiveMatch() {
    final isReadMode = _editorService.isReadMode.value;
    if (_currentMatchIndex < 0 || _currentMatchIndex >= _matches.length) {
      return;
    }

    if (isReadMode) {
      _activeMatchKey = GlobalKey();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _activeMatchKey?.currentContext;
        if (context == null) {
          return;
        }
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.22,
        );
      });
      setState(() {});
      return;
    }

    final text = _editorService.content.value;
    final target = _matches[_currentMatchIndex].start.clamp(0, text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (!_editFocusNode.hasFocus) {
        _editFocusNode.requestFocus();
      }

      if (_editScrollController.hasClients && text.isNotEmpty) {
        final normalized = target / text.length;
        final destination =
            (normalized * _editScrollController.position.maxScrollExtent).clamp(
              0.0,
              _editScrollController.position.maxScrollExtent,
            );
        _editScrollController.animateTo(
          destination,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
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
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _setShowSearch(!_showSearch);
        },
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            // Toolbar
            _Toolbar(
              isReadMode: isReadMode,
              onToggleMode: _toggleMode,
              onUndo: _editorService.canUndo ? _editorService.undo : null,
              onRedo: _editorService.canRedo ? _editorService.redo : null,
              onSave: _save,
              onSearch: () => _setShowSearch(!_showSearch),
            ),

            // Search bar
            if (_showSearch)
              TextSearchBar(
                matchLabel: _matchLabel,
                initialQuery: _searchQuery,
                hasMatches: _matches.isNotEmpty,
                onQueryChanged: _onSearchQueryChanged,
                onPreviousMatch: _previousMatch,
                onNextMatch: _nextMatch,
                onClose: () => _setShowSearch(false),
              ),

            // Editor / Reader content
            Expanded(
              child: isReadMode
                  ? TextReadView(
                      text: content,
                      searchQuery: _searchQuery,
                      matches: _matches,
                      activeMatchIndex: _currentMatchIndex,
                      scrollController: _readScrollController,
                      activeMatchKey: _activeMatchKey,
                    )
                  : TextEditView(
                      initialText: content,
                      scrollController: _editScrollController,
                      focusNode: _editFocusNode,
                      highlightedSelection: _activeSelection,
                      onChanged: (text) {
                        _editorService.pushUndoState();
                        _editorService.updateContent(text);
                        // Keep tab model in sync.
                        final tabService = getIt<TabService>();
                        final tab = tabService.tabs.value.firstWhere(
                          (t) => t.id == widget.tabId,
                        );
                        tab.textContent = text;
                        if (_searchQuery.isNotEmpty) {
                          _recomputeSearchMatches(text, _searchQuery);
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMode() {
    _editorService.toggleReadMode();
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.isReadMode = _editorService.isReadMode.value;
    _tabService.notifyTabStateChanged();
    _scrollToActiveMatch();
  }

  @override
  void didUpdateWidget(covariant TextEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) {
      final tab = _tabService.tabs.value.firstWhere(
        (t) => t.id == widget.tabId,
      );
      _showSearch = tab.showTextSearch;
      _searchQuery = tab.textSearchQuery;
      _recomputeSearchMatches(_editorService.content.value, _searchQuery);
    }
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
