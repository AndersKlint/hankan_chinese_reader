import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/pdf_reader/widgets/pdf_text_overlay.dart';
import 'package:hankan_chinese_reader/pdf_reader/widgets/pdf_toolbar.dart';
import 'package:hankan_chinese_reader/pdf_reader/widgets/pdf_thumbnail_sidebar.dart';

/// Screen for reading a PDF document with popup dictionary support and desktop features.
class PdfReaderScreen extends StatefulWidget {
  final String tabId;

  const PdfReaderScreen({super.key, required this.tabId});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  PdfTextSearcher? _textSearcher;

  String? _filePath;
  int _currentPage = 1;
  int _pageCount = 0;

  bool _showThumbnails = false;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final tabService = getIt<TabService>();
    final tab = tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    _filePath = tab.filePath;

    _pdfController.addListener(_onPdfStateChanged);
  }

  @override
  void dispose() {
    _pdfController.removeListener(_onPdfStateChanged);
    _textSearcher?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPdfStateChanged() {
    if (_pdfController.isReady) {
      if (_pageCount != _pdfController.pageCount) {
        setState(() => _pageCount = _pdfController.pageCount);
      }
      final pageNumber = _pdfController.pageNumber;
      if (pageNumber != null && _currentPage != pageNumber) {
        setState(() => _currentPage = pageNumber);
      }
    }
  }

  void _jumpToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _pageCount) {
      _pdfController.goToPage(pageNumber: pageNumber);
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _textSearcher?.resetTextSearch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_filePath == null) {
      return const Center(child: Text('No PDF file specified.'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top Toolbar
        PdfToolbar(
          showThumbnails: _showThumbnails,
          onToggleThumbnails: () =>
              setState(() => _showThumbnails = !_showThumbnails),
          showSearchBar: _showSearchBar,
          onToggleSearch: _toggleSearch,
          searchController: _searchController,
          textSearcher: _textSearcher,
          currentPage: _currentPage,
          pageCount: _pageCount,
          onPageSubmitted: _jumpToPage,
        ),
        Expanded(
          child: Row(
            children: [
              // Left Thumbnail Sidebar
              if (_showThumbnails)
                PdfThumbnailSidebar(
                  filePath: _filePath!,
                  currentPage: _currentPage,
                  onPageTapped: _jumpToPage,
                ),

              // PDF Viewer
              Expanded(
                child: PdfViewer.file(
                  _filePath!,
                  controller: _pdfController,
                  params: PdfViewerParams(
                    onViewerReady: (document, controller) {
                      setState(() {
                        _textSearcher = PdfTextSearcher(_pdfController);
                      });
                    },
                    // Disable pdfrx's built-in text selection; our PdfTextOverlay
                    // handles text interaction with popup dictionary support.
                    textSelectionParams: const PdfTextSelectionParams(
                      enabled: false,
                    ),
                    pageOverlaysBuilder: (context, pageRect, page) {
                      return [PdfTextOverlay(page: page, pageRect: pageRect)];
                    },
                    // Add vertical scrollbar
                    viewerOverlayBuilder: (context, size, handleLinkTap) => [
                      PdfViewerScrollThumb(
                        controller: _pdfController,
                        orientation: ScrollbarOrientation.right,
                        thumbBuilder:
                            (context, thumbSize, pageNumber, controller) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    thumbSize.width / 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    pageNumber?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                      ),
                    ],
                    // Highlight search matches
                    pagePaintCallbacks: [
                      if (_textSearcher != null)
                        _textSearcher!.pageTextMatchPaintCallback,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
