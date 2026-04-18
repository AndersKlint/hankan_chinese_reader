import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:chinese_popup_dict/chinese_popup_dict.dart';

/// Overlays tappable dictionary lookups on top of PDF text fragments.
///
/// Uses a single Listener with raw pointer events instead of a GestureDetector
/// to avoid gesture arena conflicts with pdfrx's text selection.
/// One handler per page instead of one per fragment — eliminating thousands
/// of compositing layers and global pointer routes.
class PdfTextOverlay extends StatefulWidget {
  final PdfPage page;
  final Rect pageRect;
  final bool enabled;
  final ValueChanged<bool>? onTextLayerDetected;

  const PdfTextOverlay({
    super.key,
    required this.page,
    required this.pageRect,
    this.enabled = true,
    this.onTextLayerDetected,
  });

  @override
  State<PdfTextOverlay> createState() => _PdfTextOverlayState();
}

class _PdfTextOverlayState extends State<PdfTextOverlay> {
  PdfPageText? _pageText;
  bool _isLoading = true;
  bool _hasCalculatedText = false;

  int _loadingPageNumber = -1;

  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _isDragging = false;

  static const double _dragThreshold = 10;
  static const int _tapMaxDurationMs = 500;

  final GlobalKey _overlayKey = GlobalKey();

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
        widget.onTextLayerDetected?.call(text.fragments.isNotEmpty);
      }
    } catch (e) {
      if (mounted && _loadingPageNumber == pageNumber) {
        setState(() {
          _isLoading = false;
          _hasCalculatedText = true;
        });
        widget.onTextLayerDetected?.call(false);
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _isDragging = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerDownPosition == null) return;

    final distance = (event.localPosition - _pointerDownPosition!).distance;
    if (distance > _dragThreshold) {
      _isDragging = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerDownPosition == null || _pointerDownTime == null) {
      _resetPointerInteraction();
      return;
    }

    final pressDuration = DateTime.now()
        .difference(_pointerDownTime!)
        .inMilliseconds;
    final isTap = !_isDragging && pressDuration < _tapMaxDurationMs;

    if (isTap) {
      _handleTap(_pointerDownPosition!);
    }

    _resetPointerInteraction();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _resetPointerInteraction();
  }

  void _resetPointerInteraction() {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _isDragging = false;
  }

  void _handleTap(Offset localOffset) {
    if (!widget.enabled) return;
    if (_pageText == null) return;

    final page = widget.page;
    final scaledPageSize = widget.pageRect.size;
    final charRects = _pageText!.charRects;

    double minDistance = double.infinity;
    int bestCharIndex = -1;
    Rect? bestRect;

    for (int i = 0; i < charRects.length; i++) {
      final charRect = charRects[i].toRect(
        page: page,
        scaledPageSize: scaledPageSize,
      );

      if (charRect.contains(localOffset)) {
        bestCharIndex = i;
        bestRect = charRect;
        minDistance = 0;
        break;
      }

      final distance = _distanceToRect(localOffset, charRect);
      if (distance < minDistance) {
        minDistance = distance;
        bestCharIndex = i;
        bestRect = charRect;
      }
    }

    if (bestCharIndex < 0 || bestRect == null) return;
    if (minDistance > _maxCharDistance) return;

    _showPopupForCharIndex(bestCharIndex, bestRect);
  }

  static const double _maxCharDistance = 12.0;

  double _distanceToRect(Offset point, Rect rect) {
    if (rect.contains(point)) return 0;
    final dx = point.dx.clamp(rect.left, rect.right) - point.dx;
    final dy = point.dy.clamp(rect.top, rect.bottom) - point.dy;
    return sqrt(dx * dx + dy * dy);
  }

  void _showPopupForCharIndex(int charIndex, Rect localRect) {
    final renderBox =
        _overlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final globalRect = Rect.fromLTWH(
      renderBox.localToGlobal(localRect.topLeft).dx,
      renderBox.localToGlobal(localRect.topLeft).dy,
      localRect.width,
      localRect.height,
    );

    ChinesePopupDict.showPopupForText(
      context: context,
      text: _pageText!.fullText,
      charIndex: charIndex,
      globalTargetRect: globalRect,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_hasCalculatedText &&
        (_pageText == null || _pageText!.fragments.isEmpty)) {
      if (!widget.enabled) {
        return const SizedBox.shrink();
      }

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
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: SizedBox(
        key: _overlayKey,
        width: widget.pageRect.width,
        height: widget.pageRect.height,
      ),
    );
  }
}
