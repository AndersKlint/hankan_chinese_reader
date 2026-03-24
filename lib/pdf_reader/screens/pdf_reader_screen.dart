import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/pdf_reader/widgets/pdf_text_overlay.dart';

/// Screen for reading a PDF document with popup dictionary support.
class PdfReaderScreen extends StatefulWidget {
  final String tabId;

  const PdfReaderScreen({super.key, required this.tabId});

  @override
  State<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends State<PdfReaderScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  String? _filePath;
  int _currentPage = 1;
  int _pageCount = 0;

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

  Future<void> _jumpToPage() async {
    final controller = TextEditingController(text: _currentPage.toString());
    final number = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 - $_pageCount'),
          onSubmitted: (value) {
            final n = int.tryParse(value);
            Navigator.pop(context, n);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              Navigator.pop(context, n);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (number != null && number > 0 && number <= _pageCount) {
      _pdfController.goToPage(pageNumber: number);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_filePath == null) {
      return const Center(child: Text('No PDF file specified.'));
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        PdfViewer.file(
          _filePath!,
          controller: _pdfController,
          params: PdfViewerParams(
            // Setup custom page rendering to include the text overlay.
            pagePaintCallbacks: [
              (canvas, pageRect, page) {
                // Return nothing as it's a void function.
              }
            ],
            pageOverlaysBuilder: (context, pageRect, page) {
              return [
                PdfTextOverlay(
                  page: page,
                  pageRect: pageRect,
                ),
              ];
            },
          ),
        ),

        // Page Indicator & Jump
        if (_pageCount > 0)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _jumpToPage,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '$_currentPage / $_pageCount',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
