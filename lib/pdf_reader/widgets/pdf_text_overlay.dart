import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:chinese_popup_dict/chinese_popup_dict.dart';

/// Overlays TappableTextWrapper widgets on top of PDF text fragments.
class PdfTextOverlay extends StatefulWidget {
  final PdfPage page;
  final Rect pageRect;

  const PdfTextOverlay({super.key, required this.page, required this.pageRect});

  @override
  State<PdfTextOverlay> createState() => _PdfTextOverlayState();
}

class _PdfTextOverlayState extends State<PdfTextOverlay> {
  PdfPageText? _pageText;
  bool _isLoading = true;
  bool _hasCalculatedText = false;

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  @override
  void didUpdateWidget(covariant PdfTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page.pageNumber != widget.page.pageNumber) {
      _loadText();
    }
  }

  int _loadingPageNumber = -1;

  Future<void> _loadText() async {
    final pageNumber = widget.page.pageNumber;
    _loadingPageNumber = pageNumber;

    setState(() {
      _isLoading = true;
      _hasCalculatedText = false;
    });

    try {
      final text = await widget.page.loadStructuredText();
      if (mounted && _loadingPageNumber == pageNumber) {
        setState(() {
          _pageText = text;
          _isLoading = false;
          _hasCalculatedText = true;
        });
      }
    } catch (e) {
      if (mounted && _loadingPageNumber == pageNumber) {
        setState(() {
          _isLoading = false;
          _hasCalculatedText = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink(); // Loading text layer...
    }

    if (_hasCalculatedText &&
        (_pageText == null || _pageText!.fragments.isEmpty)) {
      // Empty text layer or failed to extract.
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Tooltip(
            message:
                'No text layer found on this page. Dictionary lookup unavailable.',
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Colors.orange.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    if (_pageText == null) return const SizedBox.shrink();

    return Stack(
      children: _pageText!.fragments.map((fragment) {
        // Use pdfrx's toRect for correct coordinate conversion
        // This uses uniform scaling based on height, matching the PDF viewer
        final rect = fragment.bounds.toRect(
          page: widget.page,
          scaledPageSize: widget.pageRect.size,
        );

        return Positioned(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
          child: FittedBox(
            fit: BoxFit.fill,
            alignment: Alignment.topLeft,
            child: TappableTextWrapper(
              showPopupDict: true,
              child: Text(
                fragment.text,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.transparent,
                  height: 1.0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
                strutStyle: const StrutStyle(
                  forceStrutHeight: true,
                  height: 1.0,
                  leading: 0,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
