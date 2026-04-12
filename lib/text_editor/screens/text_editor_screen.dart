import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:watch_it/watch_it.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';
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
  late final FileService _fileService;
  late final ScrollController _readScrollController;
  late final ScrollController _editScrollController;
  late final FocusNode _editFocusNode;
  late final FocusNode _searchFocusNode;

  bool _showSearch = false;
  String _searchQuery = '';
  List<TextSearchResult> _matches = const <TextSearchResult>[];
  int _currentMatchIndex = -1;
  GlobalKey? _activeMatchKey;
  late double _fontSize;
  bool _isControlPressed = false;

  static const double _zoomStep = 1.1;
  static const double _scrollZoomSensitivity = 0.002;

  /// Convenience accessor to avoid repeated [TabService.findTab] calls
  /// within a single synchronous scope.
  TabModel get _tab => _tabService.findTab(widget.tabId);

  @override
  void initState() {
    super.initState();
    _editorService = TextEditorService();
    _tabService = getIt<TabService>();
    _fileService = getIt<FileService>();

    final tab = _tab;
    _readScrollController = ScrollController(
      initialScrollOffset: tab.textReadScrollOffset,
    );
    _editScrollController = ScrollController(
      initialScrollOffset: tab.textEditScrollOffset,
    );
    _editFocusNode = FocusNode();
    _searchFocusNode = FocusNode();
    _readScrollController.addListener(_persistReadScrollOffset);
    _editScrollController.addListener(_persistEditScrollOffset);

    // Initialize with tab's text content.
    _editorService.initialize(
      tab.textContent ?? '',
      isReadMode: tab.isReadMode,
    );
    _showSearch = tab.showTextSearch;
    _searchQuery = tab.textSearchQuery;
    _fontSize = tab.textFontSize;
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
    _searchFocusNode.dispose();
    _editorService.dispose();
    super.dispose();
  }

  void _persistReadScrollOffset() {
    _tab.textReadScrollOffset = _readScrollController.offset;
  }

  void _persistEditScrollOffset() {
    _tab.textEditScrollOffset = _editScrollController.offset;
  }

  void _onModifiedChanged() {
    _tabService.setModified(
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
    final tab = _tab;
    tab.showTextSearch = show;
    if (!show) {
      tab.textSearchQuery = '';
    }
    _tabService.notifyTabStateChanged();
  }

  void _activateSearch() {
    if (!_showSearch) {
      _setShowSearch(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showSearch) {
        return;
      }
      _searchFocusNode.requestFocus();
    });
  }

  double _clampFontSize(double value) =>
      value.clamp(textEditorMinFontSize, textEditorMaxFontSize).toDouble();

  void _setFontSize(double value) {
    final nextFontSize = _clampFontSize(value);
    if ((nextFontSize - _fontSize).abs() < 0.01) {
      return;
    }

    setState(() => _fontSize = nextFontSize);
    _tab.textFontSize = nextFontSize;
    _tabService.notifyTabStateChanged();
  }

  void _zoomByFactor(double factor, {Offset? localPosition}) {
    _setFontSize(_fontSize * factor);
  }

  void _zoomIn({Offset? localPosition}) =>
      _zoomByFactor(_zoomStep, localPosition: localPosition);

  void _zoomOut({Offset? localPosition}) =>
      _zoomByFactor(1 / _zoomStep, localPosition: localPosition);

  void _resetZoom() {
    _setFontSize(textEditorDefaultFontSize);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }

    final zoomDirection = event.scrollDelta.dy + event.scrollDelta.dx;
    final factor = math.exp(-zoomDirection * _scrollZoomSensitivity);
    _zoomByFactor(factor);
  }

  void _syncModifierState() {
    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    if (_isControlPressed == isControlPressed) {
      return;
    }

    setState(() => _isControlPressed = isControlPressed);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    _syncModifierState();
    return KeyEventResult.ignored;
  }

  ScrollPhysics get _contentScrollPhysics => _isControlPressed
      ? const NeverScrollableScrollPhysics()
      : const ClampingScrollPhysics();

  double _currentScrollProgress({required bool isReadMode}) {
    final controller = isReadMode
        ? _readScrollController
        : _editScrollController;
    if (!controller.hasClients) {
      return 0;
    }

    final maxScrollExtent = controller.position.maxScrollExtent;
    if (maxScrollExtent <= 0) {
      return 0;
    }

    return (controller.offset / maxScrollExtent).clamp(0.0, 1.0);
  }

  void _restoreScrollProgress({
    required bool isReadMode,
    required double progress,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final controller = isReadMode
          ? _readScrollController
          : _editScrollController;
      if (!controller.hasClients) {
        return;
      }

      final maxScrollExtent = controller.position.maxScrollExtent;
      final targetOffset = (progress * maxScrollExtent).clamp(
        0.0,
        maxScrollExtent,
      );
      controller.jumpTo(targetOffset);
      _tab.textReadScrollOffset = targetOffset;
      _tab.textEditScrollOffset = targetOffset;
    });
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final hasScaleGesture = (event.scale - 1.0).abs() > 0.001;
    final isControlZoom = HardwareKeyboard.instance.isControlPressed;
    if (!isControlZoom && !hasScaleGesture) {
      return;
    }

    final scaleFactorFromScroll = isControlZoom
        ? math.exp(
            -(event.panDelta.dy + event.panDelta.dx) * _scrollZoomSensitivity,
          )
        : 1.0;
    final scaleFactorFromGesture = hasScaleGesture ? event.scale : 1.0;
    _zoomByFactor(scaleFactorFromScroll * scaleFactorFromGesture);
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
    _tab.textSearchQuery = query;
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
    final tab = _tab;

    final savedPath = await _fileService.saveTextFile(
      content: _editorService.content.value,
      existingPath: tab.filePath,
    );

    if (savedPath != null) {
      tab.filePath = savedPath;
      tab.textContent = _editorService.content.value;
      final fileName = savedPath.split('/').last.split('\\').last;
      _tabService.setTitle(widget.tabId, fileName);
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
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): () =>
            _editorService.redo(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _activateSearch,
        const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
            _zoomIn,
        const SingleActivator(LogicalKeyboardKey.equal, control: true): _zoomIn,
        const SingleActivator(
          LogicalKeyboardKey.equal,
          control: true,
          shift: true,
        ): _zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
            _zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            _resetZoom,
        const SingleActivator(LogicalKeyboardKey.numpad0, control: true):
            _resetZoom,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_showSearch) {
            _setShowSearch(false);
          }
        },
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event),
        child: Column(
          children: [
            // Toolbar
            _Toolbar(
              isReadMode: isReadMode,
              onToggleMode: _toggleMode,
              onUndo: _editorService.canUndo ? _editorService.undo : null,
              onRedo: _editorService.canRedo ? _editorService.redo : null,
              onSave: _save,
              onSearch: _activateSearch,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              canZoomIn: _fontSize < textEditorMaxFontSize,
              canZoomOut: _fontSize > textEditorMinFontSize,
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
                focusNode: _searchFocusNode,
              ),

            // Editor / Reader content
            Expanded(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
                child: isReadMode
                    ? TextReadView(
                        text: content,
                        searchQuery: _searchQuery,
                        matches: _matches,
                        activeMatchIndex: _currentMatchIndex,
                        scrollController: _readScrollController,
                        scrollPhysics: _contentScrollPhysics,
                        activeMatchKey: _activeMatchKey,
                        fontSize: _fontSize,
                      )
                    : TextEditView(
                        initialText: content,
                        scrollController: _editScrollController,
                        scrollPhysics: _contentScrollPhysics,
                        focusNode: _editFocusNode,
                        highlightedSelection: _activeSelection,
                        fontSize: _fontSize,
                        onChanged: (text) {
                          _editorService.pushUndoState();
                          _editorService.updateContent(text);
                          // Keep tab model in sync.
                          _tab.textContent = text;
                          if (_searchQuery.isNotEmpty) {
                            _recomputeSearchMatches(text, _searchQuery);
                          }
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMode() {
    final nextIsReadMode = !_editorService.isReadMode.value;
    final scrollProgress = _currentScrollProgress(
      isReadMode: _editorService.isReadMode.value,
    );

    _editorService.toggleReadMode();
    _tab.isReadMode = _editorService.isReadMode.value;
    _tabService.notifyTabStateChanged();
    _restoreScrollProgress(
      isReadMode: nextIsReadMode,
      progress: scrollProgress,
    );
    _scrollToActiveMatch();
  }

  @override
  void didUpdateWidget(covariant TextEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) {
      final tab = _tab;
      _showSearch = tab.showTextSearch;
      _searchQuery = tab.textSearchQuery;
      _fontSize = tab.textFontSize;
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
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final bool canZoomOut;
  final bool canZoomIn;

  const _Toolbar({
    required this.isReadMode,
    required this.onToggleMode,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onSearch,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.canZoomOut,
    required this.canZoomIn,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
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
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
          ),
          const VerticalDivider(indent: 10, endIndent: 10),

          if (!isReadMode) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Undo (Ctrl+Z)',
              onPressed: onUndo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'Redo (Ctrl+Shift+Z)',
              onPressed: onRedo,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
            const VerticalDivider(indent: 10, endIndent: 10),
          ],

          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search (Ctrl+F)',
            onPressed: onSearch,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
          ),
          const VerticalDivider(indent: 10, endIndent: 10),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Decrease text size (Ctrl + Minus)',
            onPressed: canZoomOut ? onZoomOut : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Increase text size (Ctrl + Plus)',
            onPressed: canZoomIn ? onZoomIn : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save (Ctrl+S)',
            onPressed: onSave,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
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
