import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:chinese_popup_dict/chinese_popup_dict.dart';

/// Overlays TappableTextWrapper widgets on top of PDF text fragments.
class PdfTextOverlay extends StatefulWidget {
  final PdfPage page;
  final Rect pageRect;

  const PdfTextOverlay({
    super.key,
    required this.page,
    required this.pageRect,
  });

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

    if (_hasCalculatedText && (_pageText == null || _pageText!.fragments.isEmpty)) {
      // Empty text layer or failed to extract.
      return Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Tooltip(
            message: 'No text layer found on this page. Dictionary lookup unavailable.',
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

    // The scale ratio between the PDF native size and the rendered rect size.
    final scaleX = widget.pageRect.width / widget.page.width;
    final scaleY = widget.pageRect.height / widget.page.height;

    return Stack(
      children: _pageText!.fragments.map((fragment) {
        // Calculate the bounding box for this text fragment scaled to the pageRect.
        final left = fragment.bounds.left * scaleX;
        final right = fragment.bounds.right * scaleX;
        
        // PDF coordinates origin is bottom-left, Flutter is top-left.
        // We need to flip the Y axis: FlutterY = (PageHeight - PdfY) * scaleY
        final top = (widget.page.height - fragment.bounds.top) * scaleY;
        final bottom = (widget.page.height - fragment.bounds.bottom) * scaleY;

        final width = (right - left).abs();
        final height = (bottom - top).abs();

        // Ensure we have a valid positive font size
        final fontSize = height > 0 ? height * 0.9 : 1.0;

        return Positioned(
          left: left,
          top: top - (height * 0.1), // Slight visual adjustment
          width: width,
          height: height * 1.2, // Give it a bit more hit area vertically
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: TappableTextWrapper(
              showPopupDict: true,
              child: Text(
                fragment.text,
                style: TextStyle(
                  fontSize: fontSize,
                  color: Colors.transparent, // Invisible, just used for hit testing/popups
                  height: 1.0,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
