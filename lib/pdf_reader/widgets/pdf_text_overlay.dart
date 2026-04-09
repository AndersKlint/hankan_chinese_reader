import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:chinese_popup_dict/chinese_popup_dict.dart';

/// Overlays tappable dictionary lookups on top of PDF text fragments.
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

  Rect _fragmentRect(PdfPageTextFragment fragment) {
    final charBounds = _tightCharBounds(fragment);
    return charBounds.toRect(
      page: widget.page,
      scaledPageSize: widget.pageRect.size,
    );
  }

  PdfRect _tightCharBounds(PdfPageTextFragment fragment) {
    final rects = fragment.charRects;
    if (rects.isEmpty) {
      return fragment.bounds;
    }

    var left = rects.first.left;
    var top = rects.first.top;
    var right = rects.first.right;
    var bottom = rects.first.bottom;

    for (final rect in rects.skip(1)) {
      if (rect.left < left) {
        left = rect.left;
      }
      if (rect.top > top) {
        top = rect.top;
      }
      if (rect.right > right) {
        right = rect.right;
      }
      if (rect.bottom < bottom) {
        bottom = rect.bottom;
      }
    }

    return PdfRect(left, top, right, bottom);
  }

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
        final rect = _fragmentRect(fragment);

        return Positioned(
          left: rect.left,
          top: rect.top - 1, // Adjust for pdf layout inaccuracies
          width: rect.width,
          height: rect.height * 1.15, // Adjust for pdf layout inaccuracies
          child: _PassThroughPointer(
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: ChinesePopupDict(
                enableSelection: false,
                contextText: _pageText!.fullText,
                contextOffset: fragment.index,
                text: Text(
                  fragment.text,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.transparent,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                  strutStyle: const StrutStyle(
                    fontSize: 20,
                    forceStrutHeight: true,
                    height: 1.0,
                    leading: 0,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Used to let scroll and drag events pass through the popupdict text to pdf layer underneath,
/// allowing scrolling while pointer is on the popup text and selecting text over the in the invisible text layer.
class _PassThroughPointer extends SingleChildRenderObjectWidget {
  const _PassThroughPointer({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderPassThroughPointer();
  }
}

class _RenderPassThroughPointer extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || child == null) {
      return false;
    }

    child!.hitTest(result, position: position);
    return false;
  }
}
