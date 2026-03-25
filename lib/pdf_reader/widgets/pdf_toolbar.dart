import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Top toolbar for the PDF reader with search, thumbnail toggle, and page nav.
class PdfToolbar extends StatelessWidget {
  final bool showThumbnails;
  final VoidCallback onToggleThumbnails;
  final bool showSearchBar;
  final VoidCallback onToggleSearch;
  final TextEditingController searchController;
  final PdfTextSearcher? textSearcher;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSubmitted;

  const PdfToolbar({
    super.key,
    required this.showThumbnails,
    required this.onToggleThumbnails,
    required this.showSearchBar,
    required this.onToggleSearch,
    required this.searchController,
    required this.textSearcher,
    required this.currentPage,
    required this.pageCount,
    required this.onPageSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 44,
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
              size: 20,
            ),
            tooltip: 'Toggle page thumbnails',
            onPressed: onToggleThumbnails,
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          // Search toggle / bar
          if (showSearchBar && textSearcher != null) ...[
            _SearchBar(
              controller: searchController,
              textSearcher: textSearcher!,
              onClose: onToggleSearch,
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: 'Search in document (Ctrl+F)',
              onPressed: textSearcher != null ? onToggleSearch : null,
            ),

          const Spacer(),

          // Page number input
          _PageInput(
            currentPage: currentPage,
            pageCount: pageCount,
            onPageSubmitted: onPageSubmitted,
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Inline search bar with prev/next/close and match count.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final PdfTextSearcher textSearcher;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.textSearcher,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: controller,
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
                    textSearcher.startTextSearch(value);
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Match count indicator
            ListenableBuilder(
              listenable: textSearcher,
              builder: (context, _) {
                final matchCount = textSearcher.matches.length;
                final currentIndex = textSearcher.currentIndex;
                final text = matchCount > 0
                    ? '${(currentIndex ?? 0) + 1}/$matchCount'
                    : textSearcher.isSearching
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
              icon: const Icon(Icons.keyboard_arrow_up, size: 20),
              tooltip: 'Previous match',
              onPressed: () => textSearcher.goToPrevMatch(),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down, size: 20),
              tooltip: 'Next match',
              onPressed: () => textSearcher.goToNextMatch(),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Close search',
              onPressed: onClose,
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
            height: 28,
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
