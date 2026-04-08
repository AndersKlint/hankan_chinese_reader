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
  late final TabService _tabService;

  String? _filePath;
  int _currentPage = 1;
  int _pageCount = 0;

  bool _showThumbnails = false;
  bool _showSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabService = getIt<TabService>();
    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    _filePath = tab.filePath;
    _currentPage = tab.pdfCurrentPage;
    _showThumbnails = tab.showPdfThumbnails;
    _showSearchBar = tab.showPdfSearch;
    _searchController.text = tab.pdfSearchQuery;

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
        final tab = _tabService.tabs.value.firstWhere(
          (t) => t.id == widget.tabId,
        );
        tab.pdfCurrentPage = pageNumber;
      }
    }
  }

  void _jumpToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _pageCount) {
      _pdfController.goToPage(pageNumber: pageNumber);
      final tab = _tabService.tabs.value.firstWhere(
        (t) => t.id == widget.tabId,
      );
      tab.pdfCurrentPage = pageNumber;
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

    final tab = _tabService.tabs.value.firstWhere((t) => t.id == widget.tabId);
    tab.showPdfSearch = _showSearchBar;
    tab.pdfSearchQuery = _showSearchBar ? _searchController.text : '';
    _tabService.notifyTabStateChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (_filePath == null) {
      return const Center(child: Text('No PDF file specified.'));
    }

    return Column(
      children: [
        // Top Toolbar
        PdfToolbar(
          showThumbnails: _showThumbnails,
          onToggleThumbnails: () {
            setState(() => _showThumbnails = !_showThumbnails);
            final tab = _tabService.tabs.value.firstWhere(
              (t) => t.id == widget.tabId,
            );
            tab.showPdfThumbnails = _showThumbnails;
            _tabService.notifyTabStateChanged();
          },
          showSearchBar: _showSearchBar,
          onToggleSearch: _toggleSearch,
          searchController: _searchController,
          textSearcher: _textSearcher,
          currentPage: _currentPage,
          pageCount: _pageCount,
          onPageSubmitted: _jumpToPage,
          onSearchChanged: (value) {
            final tab = _tabService.tabs.value.firstWhere(
              (t) => t.id == widget.tabId,
            );
            tab.pdfSearchQuery = value;
          },
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
                    scrollPhysics: const ClampingScrollPhysics(),
                    scrollByMouseWheel: 1,
                    onViewerReady: (document, controller) {
                      setState(() {
                        _textSearcher = PdfTextSearcher(_pdfController);
                      });

                      final tab = _tabService.tabs.value.firstWhere(
                        (t) => t.id == widget.tabId,
                      );
                      final targetPage = tab.pdfCurrentPage.clamp(
                        1,
                        document.pages.length,
                      );
                      if (targetPage != 1) {
                        _pdfController.goToPage(
                          pageNumber: targetPage,
                          duration: Duration.zero,
                        );
                      }
                      if (_showSearchBar && tab.pdfSearchQuery.isNotEmpty) {
                        _textSearcher?.startTextSearch(tab.pdfSearchQuery);
                      }
                    },
                    onPageChanged: (pageNumber) {
                      if (pageNumber != null && pageNumber != _currentPage) {
                        setState(() => _currentPage = pageNumber);
                        final tab = _tabService.tabs.value.firstWhere(
                          (t) => t.id == widget.tabId,
                        );
                        tab.pdfCurrentPage = pageNumber;
                      }
                    },
                    textSelectionParams: const PdfTextSelectionParams(
                      enabled: true,
                    ),
                    pageOverlaysBuilder: (context, pageRect, page) {
                      return [PdfTextOverlay(page: page, pageRect: pageRect)];
                    },
                    // Add vertical scrollbar
                    viewerOverlayBuilder: (context, size, handleLinkTap) => [
                      PdfViewerScrollThumb(
                        controller: _pdfController,
                        orientation: ScrollbarOrientation.right,
                        margin: 6,
                        thumbSize: const Size(10, 64),
                        thumbBuilder:
                            (context, thumbSize, pageNumber, controller) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(
                                    thumbSize.width / 2,
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
