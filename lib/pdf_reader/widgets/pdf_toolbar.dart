import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// Top toolbar for the PDF reader with search, thumbnail toggle, and page nav.
class PdfToolbar extends StatelessWidget {
  final bool showThumbnails;
  final VoidCallback onToggleThumbnails;
  final bool showSearchBar;
  final VoidCallback onActivateSearch;
  final VoidCallback onCloseSearch;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final PdfTextSearcher? textSearcher;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSubmitted;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final bool canZoom;
  final bool ocrEnabled;
  final bool canToggleOcr;
  final ValueChanged<bool> onOcrChanged;
  final bool showOcrProgress;

  const PdfToolbar({
    super.key,
    required this.showThumbnails,
    required this.onToggleThumbnails,
    required this.showSearchBar,
    required this.onActivateSearch,
    required this.onCloseSearch,
    required this.searchController,
    required this.searchFocusNode,
    required this.textSearcher,
    required this.currentPage,
    required this.pageCount,
    required this.onPageSubmitted,
    required this.onZoomOut,
    required this.onZoomIn,
    this.canZoom = false,
    required this.ocrEnabled,
    required this.canToggleOcr,
    required this.onOcrChanged,
    this.showOcrProgress = false,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveOcrColor = colorScheme.onSurfaceVariant;
    final activeOcrColor = colorScheme.onSurface;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail sidebar toggle
          IconButton(
            icon: Icon(
              showThumbnails ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 18,
            ),
            tooltip: 'Toggle page thumbnails',
            onPressed: onToggleThumbnails,
            visualDensity: VisualDensity.compact,
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          // Search toggle / bar
          if (showSearchBar && textSearcher != null) ...[
            _SearchBar(
              controller: searchController,
              focusNode: searchFocusNode,
              textSearcher: textSearcher!,
              onClose: onCloseSearch,
              onSearchChanged: onSearchChanged,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.search, size: 18),
              tooltip: 'Search in document (Ctrl+F)',
              onPressed: textSearcher != null ? onActivateSearch : null,
              visualDensity: VisualDensity.compact,
            ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            tooltip: 'Zoom out (Ctrl + Minus)',
            onPressed: canZoom ? onZoomOut : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            tooltip: 'Zoom in (Ctrl + Plus)',
            onPressed: canZoom ? onZoomIn : null,
            visualDensity: VisualDensity.compact,
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          Tooltip(
            message: 'Toggle OCR dictionary lookup',
            child: TextButton(
              onPressed: canToggleOcr ? () => onOcrChanged(!ocrEnabled) : null,
              style: TextButton.styleFrom(
                foregroundColor: ocrEnabled ? activeOcrColor : inactiveOcrColor,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: ocrEnabled ? FontWeight.w600 : FontWeight.w400,
                ),
                minimumSize: const Size(48, 30),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('OCR'),
            ),
          ),

          const Spacer(),

          // Page number input
          _PageInput(
            currentPage: currentPage,
            pageCount: pageCount,
            onPageSubmitted: onPageSubmitted,
          ),

          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

/// Inline search bar with prev/next/close and match count.
class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final PdfTextSearcher textSearcher;
  final VoidCallback onClose;
  final ValueChanged<String>? onSearchChanged;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.textSearcher,
    required this.onClose,
    this.onSearchChanged,
  });

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  Future<void> _goToNextMatch() async {
    await widget.textSearcher.goToNextMatch();
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.focusNode.requestFocus();
  }

  Future<void> _goToPreviousMatch() async {
    await widget.textSearcher.goToPrevMatch();
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter):
                        _goToNextMatch,
                    const SingleActivator(
                      LogicalKeyboardKey.enter,
                      shift: true,
                    ): _goToPreviousMatch,
                    const SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _goToNextMatch,
                    const SingleActivator(
                      LogicalKeyboardKey.numpadEnter,
                      shift: true,
                    ): _goToPreviousMatch,
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    autofocus: true,
                    style: Theme.of(context).textTheme.bodySmall,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerLow,
                    ),
                    onChanged: (value) {
                      widget.textSearcher.startTextSearch(value);
                      widget.onSearchChanged?.call(value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Match count indicator
            ListenableBuilder(
              listenable: widget.textSearcher,
              builder: (context, _) {
                final matchCount = widget.textSearcher.matches.length;
                final currentIndex = widget.textSearcher.currentIndex;
                final text = matchCount > 0
                    ? '${(currentIndex ?? 0) + 1}/$matchCount'
                    : widget.textSearcher.isSearching
                    ? '...'
                    : '0/0';
                return SizedBox(
                  width: 60,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up, size: 18),
              tooltip: 'Previous match',
              onPressed: _goToPreviousMatch,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              tooltip: 'Next match',
              onPressed: _goToNextMatch,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Close search',
              onPressed: widget.onClose,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable page number input with total page count.
class _PageInput extends StatefulWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSubmitted;

  const _PageInput({
    required this.currentPage,
    required this.pageCount,
    required this.onPageSubmitted,
  });

  @override
  State<_PageInput> createState() => _PageInputState();
}

class _PageInputState extends State<_PageInput> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage.toString());
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
        _controller.text = widget.currentPage.toString();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.currentPage != oldWidget.currentPage) {
      _controller.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text);
    if (n != null && n > 0 && n <= widget.pageCount) {
      widget.onPageSubmitted(n);
    }
    setState(() => _isEditing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 26,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: textStyle,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 4),
          Text('/ ${widget.pageCount}', style: textStyle),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        setState(() => _isEditing = true);
        _controller.text = widget.currentPage.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${widget.currentPage} / ${widget.pageCount}',
          style: textStyle,
        ),
      ),
    );
  }
}
