import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show ChangeSource;
import 'package:hankan_chinese_reader/text_editor/services/editor_clipboard_service.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_formatting_toolbar.dart';
import 'package:watch_it/watch_it.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service_registry.dart';
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
  late final ScrollController _readScrollController;
  late final ScrollController _editScrollController;
  late final FocusNode _editFocusNode;
  late final FocusNode _searchFocusNode;

  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  List<TextSearchResult> _matches = const <TextSearchResult>[];
  int _currentMatchIndex = -1;
  GlobalKey? _activeMatchKey;
  late double _fontSize;
  bool _isControlPressed = false;
  final _clipboard = EditorClipboardService();

  static const double _zoomStep = 1.1;
  static const double _scrollZoomSensitivity = 0.002;

  /// Convenience accessor to avoid repeated [TabService.findTab] calls
  /// within a single synchronous scope.
  TabModel get _tab => _tabService.findTab(widget.tabId);

  @override
  void initState() {
    super.initState();
    _editorService = getIt<TextEditorService>();
    _tabService = getIt<TabService>();

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
      tabId: widget.tabId,
      filePath: tab.filePath,
      isMarkdown: tab.textIsMarkdown,
    );
    _clipboard.configure(_editorService.controller.document);
    _editorService.content.addListener(_onContentChanged);
    getIt<TextEditorServiceRegistry>().register(widget.tabId, _editorService);
    _showSearch = tab.showTextSearch;
    _searchQuery = tab.textSearchQuery;
    _fontSize = tab.textFontSize;
    if (_searchQuery.isNotEmpty) {
      _recomputeSearchMatches(_editorService.content.value, _searchQuery);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    getIt<TextEditorServiceRegistry>().unregister(widget.tabId);
    _editorService.content.removeListener(_onContentChanged);
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

  void _onContentChanged() {
    _searchDebounce?.cancel();
    if (_searchQuery.isNotEmpty) {
      _searchDebounce = Timer(const Duration(milliseconds: 150), () {
        _searchDebounce = null;
        _recomputeSearchMatches(
          _editorService.content.value,
          _searchQuery,
          reveal: false,
        );
      });
    }
  }

  void _flushSearch() {
    if (!(_searchDebounce?.isActive ?? false)) return;
    _searchDebounce?.cancel();
    _searchDebounce = null;
    _recomputeSearchMatches(
      _editorService.content.value,
      _searchQuery,
      reveal: false,
    );
  }

  void _setShowSearch(bool show) {
    if (!show) _searchDebounce?.cancel();
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

  double _currentScrollOffset({required bool isReadMode}) {
    final controller = isReadMode
        ? _readScrollController
        : _editScrollController;
    if (!controller.hasClients) {
      return 0;
    }

    return controller.offset;
  }

  void _restoreScrollOffset({
    required bool isReadMode,
    required double offset,
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
      final targetOffset = offset.clamp(0.0, maxScrollExtent);
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

  void _recomputeSearchMatches(
    String text,
    String query, {
    bool reveal = true,
  }) {
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
      _currentMatchIndex = matches.isEmpty
          ? -1
          : reveal
          ? 0
          : _currentMatchIndex.clamp(0, matches.length - 1);
    });
    if (reveal) _scrollToActiveMatch();
  }

  void _onSearchQueryChanged(String query) {
    if (_searchQuery == query) {
      _flushSearch();
      return;
    }
    _searchDebounce?.cancel();
    _searchQuery = query;
    _tab.textSearchQuery = query;
    _tabService.notifyTabStateChanged();
    _recomputeSearchMatches(_editorService.content.value, query);
  }

  void _nextMatch() {
    _flushSearch();
    if (_matches.isEmpty) {
      return;
    }
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matches.length;
    });
    _scrollToActiveMatch();
  }

  void _previousMatch() {
    _flushSearch();
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
      setState(() {});
      return;
    }

    final text = _editorService.content.value;
    final selection = _activeSelection;
    if (selection != null) {
      _editorService.controller.updateSelection(selection, ChangeSource.local);
    }
    final target = _matches[_currentMatchIndex].start.clamp(0, text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
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

  Future<void> _save({bool saveAs = false}) async {
    try {
      await _editorService.save(saveAs: saveAs);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    }
  }

  Future<void> _paste() async {
    try {
      await _clipboard.paste(_editorService.controller);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not paste: $error')));
      }
    }
  }

  void _editAction(VoidCallback action) {
    if (!_editorService.isReadMode.value) action();
  }

  late final Map<ShortcutActivator, VoidCallback> _richShortcuts = {
    for (final meta in [false, true]) ...{
      SingleActivator(
        LogicalKeyboardKey.keyB,
        control: !meta,
        meta: meta,
      ): () =>
          _editAction(_editorService.toggleBold),
      SingleActivator(
        LogicalKeyboardKey.keyI,
        control: !meta,
        meta: meta,
      ): () =>
          _editAction(_editorService.toggleItalic),
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !meta,
        meta: meta,
      ): () =>
          _editAction(_editorService.undo),
      SingleActivator(
        LogicalKeyboardKey.keyZ,
        control: !meta,
        meta: meta,
        shift: true,
      ): () =>
          _editAction(_editorService.redo),
      SingleActivator(
        LogicalKeyboardKey.keyY,
        control: !meta,
        meta: meta,
      ): () =>
          _editAction(_editorService.redo),
      SingleActivator(LogicalKeyboardKey.keyS, control: !meta, meta: meta):
          _save,
      SingleActivator(
        LogicalKeyboardKey.keyS,
        control: !meta,
        meta: meta,
        shift: true,
      ): () =>
          _save(saveAs: true),
      SingleActivator(LogicalKeyboardKey.keyF, control: !meta, meta: meta):
          _activateSearch,
      SingleActivator(LogicalKeyboardKey.keyV, control: !meta, meta: meta):
          _paste,
      SingleActivator(LogicalKeyboardKey.digit0, control: !meta, meta: meta):
          _resetZoom,
      for (final key in [
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyO,
      ])
        SingleActivator(key, control: !meta, meta: meta, shift: true): () {},
      for (final key in [
        LogicalKeyboardKey.keyU,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.keyG,
        LogicalKeyboardKey.backquote,
        LogicalKeyboardKey.tilde,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
      ])
        for (final shift in [false, true])
          SingleActivator(key, control: !meta, meta: meta, shift: shift): () {},
    },
  };

  late final Map<ShortcutActivator, Intent> _editorShortcuts = {
    for (final entry in _richShortcuts.entries)
      entry.key: _EditorCommand(entry.value),
  };
  late final Map<Type, Action<Intent>> _editorActions = {
    _EditorCommand: CallbackAction<_EditorCommand>(
      onInvoke: (intent) {
        intent.callback();
        return null;
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    final isReadMode = watch(_editorService.isReadMode).value;

    return CallbackShortcuts(
      bindings: {
        ..._richShortcuts,
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
              onSave: _save,
              onSaveAs: () => _save(saveAs: true),
              onSearch: _activateSearch,
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              canZoomIn: _fontSize < textEditorMaxFontSize,
              canZoomOut: _fontSize > textEditorMinFontSize,
            ),
            TextFormattingToolbar(
              service: _editorService,
              isReadMode: isReadMode,
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
                    ? ListenableBuilder(
                        listenable: Listenable.merge([
                          _editorService.content,
                          _editorService.revision,
                        ]),
                        builder: (context, _) => TextReadView(
                          text: _editorService.content.value,
                          document: _editorService.controller.document,
                          matches: _matches,
                          activeMatchIndex: _currentMatchIndex,
                          scrollController: _readScrollController,
                          scrollPhysics: _contentScrollPhysics,
                          revealToken: _activeMatchKey,
                          fontSize: _fontSize,
                        ),
                      )
                    : TextEditView(
                        controller: _editorService.controller,
                        scrollController: _editScrollController,
                        scrollPhysics: _contentScrollPhysics,
                        focusNode: _editFocusNode,
                        fontSize: _fontSize,
                        onPaste: _paste,
                        shortcuts: _editorShortcuts,
                        actions: _editorActions,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleMode() {
    _flushSearch();
    final nextIsReadMode = !_editorService.isReadMode.value;
    final scrollOffset = _currentScrollOffset(
      isReadMode: _editorService.isReadMode.value,
    );
    _activeMatchKey = null;

    _editorService.toggleReadMode();
    _tab.isReadMode = _editorService.isReadMode.value;
    _tabService.notifyTabStateChanged();
    _restoreScrollOffset(isReadMode: nextIsReadMode, offset: scrollOffset);
  }

  @override
  void didUpdateWidget(covariant TextEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabId != widget.tabId) {
      _searchDebounce?.cancel();
      final tab = _tab;
      _showSearch = tab.showTextSearch;
      _searchQuery = tab.textSearchQuery;
      _fontSize = tab.textFontSize;
      _recomputeSearchMatches(_editorService.content.value, _searchQuery);
    }
  }
}

class _EditorCommand extends Intent {
  final VoidCallback callback;
  const _EditorCommand(this.callback);
}

/// Toolbar for the text editor.
class _Toolbar extends StatelessWidget {
  final bool isReadMode;
  final VoidCallback onToggleMode;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onSearch;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final bool canZoomOut;
  final bool canZoomIn;

  const _Toolbar({
    required this.isReadMode,
    required this.onToggleMode,
    required this.onSave,
    required this.onSaveAs,
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
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _buildBar(showZoom: constraints.maxWidth >= 340),
      ),
    );
  }

  Widget _buildBar({required bool showZoom}) {
    return Row(
      children: [
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

        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search (Ctrl+F)',
          onPressed: onSearch,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
        ),
        if (showZoom) ...[
          const VerticalDivider(indent: 10, endIndent: 10),
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom out (Ctrl + Minus)',
            onPressed: canZoomOut ? onZoomOut : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom in (Ctrl + Plus)',
            onPressed: canZoomIn ? onZoomIn : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: 'Save (Ctrl/Cmd+S)',
          onPressed: onSave,
          iconSize: 18,
          visualDensity: VisualDensity.compact,
        ),

        _overflowMenu(),
      ],
    );
  }

  Widget _overflowMenu() => PopupMenuButton<VoidCallback>(
    icon: const Icon(Icons.more_vert, size: 18),
    tooltip: 'Editor actions',
    onSelected: (action) => action(),
    itemBuilder: (context) => [
      PopupMenuItem(value: onSave, child: const Text('Save')),
      PopupMenuItem(value: onSaveAs, child: const Text('Save As…')),
      PopupMenuItem(value: onSearch, child: const Text('Search')),
      PopupMenuItem(
        value: onToggleMode,
        child: Text(isReadMode ? 'Edit' : 'Read'),
      ),
      PopupMenuItem(
        value: onZoomIn,
        enabled: canZoomIn,
        child: const Text('Zoom in'),
      ),
      PopupMenuItem(
        value: onZoomOut,
        enabled: canZoomOut,
        child: const Text('Zoom out'),
      ),
    ],
  );
}
