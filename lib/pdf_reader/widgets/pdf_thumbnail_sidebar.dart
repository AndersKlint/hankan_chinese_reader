import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Left sidebar showing page thumbnails for quick navigation.
class PdfThumbnailSidebar extends StatefulWidget {
  /// Path to the PDF file.
  final String filePath;

  /// Currently visible page number (1-indexed).
  final int currentPage;

  /// Callback when a thumbnail is tapped.
  final ValueChanged<int> onPageTapped;

  /// Width of the sidebar.
  final double width;

  const PdfThumbnailSidebar({
    super.key,
    required this.filePath,
    required this.currentPage,
    required this.onPageTapped,
    this.width = 160,
  });

  @override
  State<PdfThumbnailSidebar> createState() => _PdfThumbnailSidebarState();
}

class _PdfThumbnailSidebarState extends State<PdfThumbnailSidebar> {
  static const double _itemExtent = 196;
  static const int _bufferPages = 3;
  final ScrollController _scrollController = ScrollController();
  int _firstVisibleIndex = 0;
  int _lastVisibleIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _updateVisibleRange();
      }
      _scrollToCurrentPage();
    });
    _scrollController.addListener(_onScroll);
  }

  void _updateVisibleRange() {
    if (!_scrollController.hasClients) return;
    final viewportStart = _scrollController.offset;
    final viewportEnd =
        viewportStart + _scrollController.position.viewportDimension;
    _firstVisibleIndex = (viewportStart / _itemExtent).floor().clamp(0, 9999);
    _lastVisibleIndex = ((viewportEnd / _itemExtent).ceil() + _bufferPages)
        .clamp(0, 9999);
  }

  @override
  void didUpdateWidget(covariant PdfThumbnailSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _scrollToCurrentPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final viewportStart = _scrollController.offset;
    final viewportEnd =
        viewportStart + _scrollController.position.viewportDimension;
    final newFirstIndex = (viewportStart / _itemExtent).floor().clamp(0, 9999);
    final newLastIndex = ((viewportEnd / _itemExtent).ceil() + _bufferPages)
        .clamp(0, 9999);
    if (newFirstIndex != _firstVisibleIndex ||
        newLastIndex != _lastVisibleIndex) {
      setState(() {
        _firstVisibleIndex = newFirstIndex;
        _lastVisibleIndex = newLastIndex;
      });
    }
  }

  void _scrollToCurrentPage() {
    if (!_scrollController.hasClients) {
      return;
    }

    final targetOffset =
        ((widget.currentPage - 1) * _itemExtent) -
        ((_scrollController.position.viewportDimension - _itemExtent) / 2);
    final clampedOffset = targetOffset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: PdfDocumentViewBuilder.file(
        widget.filePath,
        builder: (context, document) {
          if (document == null) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemExtent: _itemExtent,
            itemCount: document.pages.length,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final isActive = pageNumber == widget.currentPage;
              final isVisible =
                  index >= _firstVisibleIndex && index <= _lastVisibleIndex;

              return GestureDetector(
                onTap: () => widget.onPageTapped(pageNumber),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isActive ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: isVisible
                            ? PdfPageView(
                                document: document,
                                pageNumber: pageNumber,
                                maximumDpi: 50,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                ),
                              )
                            : const SizedBox.expand(),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
                        child: Text(
                          '$pageNumber',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
