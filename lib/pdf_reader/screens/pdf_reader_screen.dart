import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:hankan_chinese_reader/core/services/document_history_service.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/pdf_reader/services/pdf_ocr_service.dart';
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
  final GlobalKey _pdfViewerKey = GlobalKey();
  PdfTextSearcher? _textSearcher;
  late final TabService _tabService;
  late final DocumentHistoryService _documentHistoryService;
  late final PdfOcrService _pdfOcrService;

  String? _filePath;
  int _currentPage = 1;
  int _pageCount = 0;

  bool _showThumbnails = false;
  bool _showSearchBar = false;
  bool? _ocrEnabled;
  final Map<int, bool> _pageHasTextLayer = {};
  bool _isPerformingOcrLookup = false;
  bool _hasRequestedOcrWarmUp = false;
  bool _canPersistPdfViewState = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _saveViewStateDebounce;

  static const double _zoomStep = 1.1;
  static const double _scrollZoomSensitivity = 0.002;

  @override
  void initState() {
    super.initState();
    _tabService = getIt<TabService>();
    _documentHistoryService = getIt<DocumentHistoryService>();
    _pdfOcrService = getIt<PdfOcrService>();
    final tab = _tabService.findTab(widget.tabId);
    _filePath = tab.filePath;
    _currentPage = tab.pdfCurrentPage;
    _showThumbnails = tab.showPdfThumbnails;
    _showSearchBar = tab.showPdfSearch;
    _ocrEnabled = tab.pdfOcrEnabled;
    _searchController.text = tab.pdfSearchQuery;

    _pdfController.addListener(_onPdfStateChanged);
  }

  @override
  void dispose() {
    _saveViewStateDebounce?.cancel();
    _savePdfViewStateNow();
    _pdfController.removeListener(_onPdfStateChanged);
    _textSearcher?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        _tabService.findTab(widget.tabId).pdfCurrentPage = pageNumber;
      }
      _schedulePdfViewStateSave();
    }
  }

  void _schedulePdfViewStateSave() {
    if (!_canPersistPdfViewState || _filePath == null) {
      return;
    }

    _saveViewStateDebounce?.cancel();
    _saveViewStateDebounce = Timer(
      const Duration(milliseconds: 350),
      _savePdfViewStateNow,
    );
  }

  void _savePdfViewStateNow() {
    if (!_canPersistPdfViewState ||
        _filePath == null ||
        !_pdfController.isReady) {
      return;
    }

    final pageNumber = _pdfController.pageNumber;
    if (pageNumber == null) {
      return;
    }

    unawaited(
      _documentHistoryService.savePdfViewState(
        path: _filePath!,
        title: _tabService.findTab(widget.tabId).title,
        pageNumber: pageNumber,
        zoom: _pdfController.currentZoom,
        centerPosition: _pdfController.centerPosition,
      ),
    );
  }

  Future<void> _restoreSavedPdfView(PdfDocument document) async {
    if (_filePath == null) {
      _canPersistPdfViewState = true;
      return;
    }

    final savedState = _documentHistoryService.getPdfViewState(_filePath!);
    if (savedState == null) {
      _canPersistPdfViewState = true;
      return;
    }

    final clampedZoom = savedState.zoom
        .clamp(_pdfController.minScale, _pdfController.params.maxScale)
        .toDouble();
    final hasUsableCenter =
        savedState.centerDx.isFinite &&
        savedState.centerDy.isFinite &&
        savedState.zoom > 0;

    if (hasUsableCenter) {
      final matrix = _pdfController.calcMatrixFor(
        savedState.centerPosition,
        zoom: clampedZoom,
      );
      await _pdfController.goTo(matrix, duration: Duration.zero);
    } else {
      final targetPage = savedState.pageNumber.clamp(1, document.pages.length);
      await _pdfController.goToPage(
        pageNumber: targetPage,
        duration: Duration.zero,
      );
    }

    _canPersistPdfViewState = true;
  }

  void _jumpToPage(int pageNumber) {
    if (pageNumber > 0 && pageNumber <= _pageCount) {
      _pdfController.goToPage(pageNumber: pageNumber);
      _tabService.findTab(widget.tabId).pdfCurrentPage = pageNumber;
    }
  }

  void _setShowSearch(bool show) {
    setState(() {
      _showSearchBar = show;
      if (!_showSearchBar) {
        _searchController.clear();
        _textSearcher?.resetTextSearch();
      }
    });

    final tab = _tabService.findTab(widget.tabId);
    tab.showPdfSearch = _showSearchBar;
    tab.pdfSearchQuery = _showSearchBar ? _searchController.text : '';
    _tabService.notifyTabStateChanged();
  }

  bool get _isCurrentPageMissingTextLayer =>
      _pageHasTextLayer[_currentPage] == false;

  bool get _isOcrEnabled =>
      _ocrEnabled ??
      (_pdfOcrService.isSupported && _isCurrentPageMissingTextLayer);

  void _handleOcrToggleRequested(bool enabled) {
    if (kIsWeb) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'OCR not available on web. Use the desktop/mobile version instead.',
            ),
          ),
        );
      return;
    }

    _setOcrEnabled(enabled);
  }

  void _setOcrEnabled(bool enabled) {
    setState(() {
      _ocrEnabled = enabled;
    });

    if (enabled) {
      _warmUpOcr();
    }

    final tab = _tabService.findTab(widget.tabId);
    tab.pdfOcrEnabled = enabled;
    _tabService.notifyTabStateChanged();
  }

  void _warmUpOcr() {
    if (_hasRequestedOcrWarmUp || !_pdfOcrService.isSupported) {
      return;
    }
    _hasRequestedOcrWarmUp = true;
    _pdfOcrService.warmUp();
  }

  void _onPageTextLayerDetected(int pageNumber, bool hasTextLayer) {
    final previous = _pageHasTextLayer[pageNumber];
    if (previous == hasTextLayer) {
      return;
    }

    _pageHasTextLayer[pageNumber] = hasTextLayer;
    if (_ocrEnabled == null && !hasTextLayer) {
      _warmUpOcr();
    }
    if (_ocrEnabled == null && mounted && pageNumber == _currentPage) {
      setState(() {});
    }
  }

  Future<void> _handlePdfTap(
    BuildContext context,
    PdfPageHitTestResult hit,
  ) async {
    if (!_pdfOcrService.isSupported ||
        !_isOcrEnabled ||
        _isPerformingOcrLookup) {
      return;
    }

    setState(() {
      _isPerformingOcrLookup = true;
    });
    try {
      ChinesePopupDict.hideActivePopup();

      final lookup = await _pdfOcrService.lookupAtPoint(
        page: hit.page,
        pagePoint: hit.offset,
      );
      if (!mounted || !context.mounted || lookup == null) {
        return;
      }

      final anchorRectInDocument = _pdfController.calcRectForRectInsidePage(
        pageNumber: hit.page.pageNumber,
        rect: lookup.targetRectOnPage,
      );
      final globalTopLeft = _pdfController.documentToGlobal(
        anchorRectInDocument.topLeft,
      );
      final globalBottomRight = _pdfController.documentToGlobal(
        anchorRectInDocument.bottomRight,
      );
      if (globalTopLeft == null || globalBottomRight == null) {
        return;
      }

      ChinesePopupDict.showPopupForText(
        context: context,
        text: lookup.text,
        charIndex: lookup.charIndex,
        globalTargetRect: Rect.fromPoints(globalTopLeft, globalBottomRight),
      );
    } finally {
      if (!mounted) {
        _isPerformingOcrLookup = false;
      } else {
        setState(() {
          _isPerformingOcrLookup = false;
        });
      }
    }
  }

  void _activateSearch() {
    if (!_showSearchBar) {
      _setShowSearch(true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showSearchBar) {
        return;
      }
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
  }

  Offset _viewerCenterLocalPosition() {
    final renderObject = _pdfViewerKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.size.center(Offset.zero);
    }
    return Offset.zero;
  }

  Future<void> _zoomByFactor(double factor, {Offset? localPosition}) async {
    if (!_pdfController.isReady) {
      return;
    }
    final position = localPosition ?? _viewerCenterLocalPosition();
    final targetZoom = (_pdfController.currentZoom * factor).clamp(
      _pdfController.minScale,
      _pdfController.params.maxScale,
    );
    await _pdfController.zoomOnLocalPosition(
      localPosition: position,
      newZoom: targetZoom,
      duration: const Duration(milliseconds: 120),
    );
  }

  Future<void> _zoomIn({Offset? localPosition}) =>
      _zoomByFactor(_zoomStep, localPosition: localPosition);

  Future<void> _zoomOut({Offset? localPosition}) async {
    await _zoomByFactor(1 / _zoomStep, localPosition: localPosition);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_pdfController.isReady) {
      return;
    }

    final renderObject = _pdfViewerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final localPosition = renderObject.globalToLocal(event.position);
    if (HardwareKeyboard.instance.isControlPressed) {
      final zoomDirection = event.scrollDelta.dy + event.scrollDelta.dx;
      final factor = math.exp(-zoomDirection * _scrollZoomSensitivity);
      final targetZoom = _pdfController.currentZoom * factor;
      final clampedZoom = targetZoom.clamp(
        _pdfController.minScale,
        _pdfController.params.maxScale,
      );

      _pdfController.zoomOnLocalPosition(
        localPosition: localPosition,
        newZoom: clampedZoom,
        duration: Duration.zero,
      );
      return;
    }

    if (event.kind == PointerDeviceKind.trackpad) {
      return;
    }

    final dx = -event.scrollDelta.dx / _pdfController.currentZoom;
    final dy = -event.scrollDelta.dy / _pdfController.currentZoom;
    final matrix = _pdfController.value.clone()
      ..translateByDouble(dx, dy, 0, 1);
    _pdfController.value = _pdfController.makeMatrixInSafeRange(
      matrix,
      forceClamp: true,
    );
  }

  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_pdfController.isReady ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }

    final scrollDelta = event.panDelta.dy + event.panDelta.dx;
    final scaleFactorFromScroll = math.exp(
      -scrollDelta * _scrollZoomSensitivity,
    );
    final scaleFactorFromGesture = (event.scale - 1.0).abs() > 0.001
        ? event.scale
        : 1.0;
    final targetZoom =
        _pdfController.currentZoom *
        scaleFactorFromScroll *
        scaleFactorFromGesture;
    final clampedZoom = targetZoom.clamp(
      _pdfController.minScale,
      _pdfController.params.maxScale,
    );

    _pdfController.zoomOnLocalPosition(
      localPosition: event.localPosition,
      newZoom: clampedZoom,
      duration: Duration.zero,
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _showSearchBar) {
      _setShowSearch(false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (_filePath == null) {
      return const Center(child: Text('No PDF file specified.'));
    }

    return CallbackShortcuts(
      bindings: {
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
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (_, event) => _handleKeyEvent(event),
        child: MouseRegion(
          cursor: _isPerformingOcrLookup
              ? SystemMouseCursors.progress
              : MouseCursor.defer,
          child: Stack(
            children: [
              Column(
                children: [
                  PdfToolbar(
                    showThumbnails: _showThumbnails,
                    onToggleThumbnails: () {
                      setState(() => _showThumbnails = !_showThumbnails);
                      _tabService.findTab(widget.tabId).showPdfThumbnails =
                          _showThumbnails;
                      _tabService.notifyTabStateChanged();
                    },
                    showSearchBar: _showSearchBar,
                    onActivateSearch: _activateSearch,
                    onCloseSearch: () => _setShowSearch(false),
                    searchController: _searchController,
                    searchFocusNode: _searchFocusNode,
                    textSearcher: _textSearcher,
                    currentPage: _currentPage,
                    pageCount: _pageCount,
                    onPageSubmitted: _jumpToPage,
                    onZoomIn: _zoomIn,
                    onZoomOut: _zoomOut,
                    canZoom: _pdfController.isReady,
                    ocrEnabled: _isOcrEnabled,
                    canToggleOcr: _pdfOcrService.isSupported || kIsWeb,
                    onOcrChanged: _handleOcrToggleRequested,
                    showOcrProgress: _isPerformingOcrLookup,
                    onSearchChanged: (value) {
                      _tabService.findTab(widget.tabId).pdfSearchQuery = value;
                    },
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        if (_showThumbnails)
                          PdfThumbnailSidebar(
                            filePath: _filePath!,
                            currentPage: _currentPage,
                            onPageTapped: _jumpToPage,
                          ),
                        Expanded(
                          child: Listener(
                            onPointerSignal: _onPointerSignal,
                            onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
                            child: RepaintBoundary(
                              key: _pdfViewerKey,
                              child: PdfViewer.file(
                                _filePath!,
                                controller: _pdfController,
                                params: PdfViewerParams(
                                  scrollByMouseWheel: 0.1,
                                  maxImageBytesCachedOnMemory: 50 * 1024 * 1024,
                                  horizontalCacheExtent: 0.5,
                                  verticalCacheExtent: 0.5,
                                  onViewerReady: (document, controller) {
                                    setState(() {
                                      _textSearcher = PdfTextSearcher(
                                        _pdfController,
                                      );
                                    });

                                    final tab = _tabService.findTab(
                                      widget.tabId,
                                    );
                                    unawaited(() async {
                                      final savedState = _filePath == null
                                          ? null
                                          : _documentHistoryService
                                                .getPdfViewState(_filePath!);
                                      await _restoreSavedPdfView(document);

                                      final targetPage = tab.pdfCurrentPage
                                          .clamp(1, document.pages.length);
                                      if (_pdfController.pageNumber == 1 &&
                                          targetPage != 1 &&
                                          savedState == null) {
                                        await _pdfController.goToPage(
                                          pageNumber: targetPage,
                                          duration: Duration.zero,
                                        );
                                      }
                                      if (_showSearchBar &&
                                          tab.pdfSearchQuery.isNotEmpty) {
                                        _textSearcher?.startTextSearch(
                                          tab.pdfSearchQuery,
                                        );
                                        _activateSearch();
                                      }
                                    }());
                                  },
                                  onPageChanged: (pageNumber) {
                                    if (pageNumber != null &&
                                        pageNumber != _currentPage) {
                                      setState(() => _currentPage = pageNumber);
                                      _tabService
                                              .findTab(widget.tabId)
                                              .pdfCurrentPage =
                                          pageNumber;
                                    }
                                  },
                                  textSelectionParams:
                                      const PdfTextSelectionParams(
                                        enabled: true,
                                      ),
                                  onGeneralTap: (context, controller, details) {
                                    if (details.type !=
                                        PdfViewerGeneralTapType.tap) {
                                      return false;
                                    }
                                    if (!_isOcrEnabled) {
                                      return false;
                                    }
                                    if (details.tapOn ==
                                        PdfViewerPart.selectedText) {
                                      return false;
                                    }

                                    final hit = _pdfController
                                        .getPdfPageHitTestResult(
                                          details.documentPosition,
                                          useDocumentLayoutCoordinates: true,
                                        );
                                    if (hit == null) {
                                      return false;
                                    }

                                    _handlePdfTap(context, hit);
                                    return true;
                                  },
                                  pageOverlaysBuilder:
                                      (context, pageRect, page) {
                                        return [
                                          PdfTextOverlay(
                                            page: page,
                                            pageRect: pageRect,
                                            enabled: !_isOcrEnabled,
                                            onTextLayerDetected:
                                                (hasTextLayer) {
                                                  _onPageTextLayerDetected(
                                                    page.pageNumber,
                                                    hasTextLayer,
                                                  );
                                                },
                                          ),
                                        ];
                                      },
                                  viewerOverlayBuilder:
                                      (context, size, handleLinkTap) => [
                                        PdfViewerScrollThumb(
                                          controller: _pdfController,
                                          orientation:
                                              ScrollbarOrientation.right,
                                          margin: 6,
                                          thumbSize: const Size(10, 64),
                                          thumbBuilder:
                                              (
                                                context,
                                                thumbSize,
                                                pageNumber,
                                                controller,
                                              ) {
                                                return DecoratedBox(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          thumbSize.width / 2,
                                                        ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ],
                                  pagePaintCallbacks: [
                                    if (_textSearcher != null)
                                      _textSearcher!.pageTextMatchPaintCallback,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _isPerformingOcrLookup ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: const SizedBox(
                      height: 3,
                      child: LinearProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
