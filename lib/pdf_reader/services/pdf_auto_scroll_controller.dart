import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/gestures.dart';
import 'package:pdfrx/pdfrx.dart';

/// Controls auto-scrolling of a PDF viewer during text selection drag.
///
/// When the user drags to select text and the pointer approaches the top or
/// bottom edge of the viewport, this controller smoothly scrolls the PDF so
/// the selection can continue beyond the visible area.
class PdfAutoScrollController {
  PdfAutoScrollController({
    required PdfViewerController controller,
    required Size Function() getViewportSize,
    this.edgeThreshold = 60.0,
    this.maxScrollSpeed = 500.0,
  })  : _controller = controller,
        _getViewportSize = getViewportSize;

  final PdfViewerController _controller;
  final Size Function() _getViewportSize;
  final double edgeThreshold;
  final double maxScrollSpeed;

  Timer? _scrollTimer;
  Offset? _pointerPosition;
  bool _isDown = false;
  PointerDeviceKind? _deviceKind;

  void handlePointerDown(PointerDownEvent event) {
    _isDown = true;
    _deviceKind = event.kind;
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (!_isDown) return;
    if (_deviceKind != PointerDeviceKind.mouse &&
        _deviceKind != PointerDeviceKind.stylus) {
      return;
    }
    _pointerPosition = event.localPosition;
    _checkEdgeZone();
  }

  void handlePointerUp() {
    _reset();
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _reset();
  }

  void dispose() {
    _stopScroll();
  }

  void _reset() {
    _isDown = false;
    _pointerPosition = null;
    _deviceKind = null;
    _stopScroll();
  }

  void _checkEdgeZone() {
    final position = _pointerPosition;
    if (position == null || !_controller.isReady) {
      _stopScroll();
      return;
    }

    final viewSize = _getViewportSize();
    if (viewSize == Size.zero) {
      _stopScroll();
      return;
    }

    final distanceToTop = position.dy;
    final distanceToBottom = viewSize.height - position.dy;

    if (distanceToTop <= edgeThreshold &&
        distanceToTop < distanceToBottom) {
      _startScroll();
    } else if (distanceToBottom <= edgeThreshold) {
      _startScroll();
    } else {
      _stopScroll();
    }
  }

  void _startScroll() {
    _scrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      _onScrollTick,
    );
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _onScrollTick(Timer timer) {
    if (!_isDown || !_controller.isReady) {
      _stopScroll();
      return;
    }

    final position = _pointerPosition;
    if (position == null) {
      _stopScroll();
      return;
    }

    final viewSize = _getViewportSize();
    if (viewSize == Size.zero) {
      _stopScroll();
      return;
    }

    final distanceToTop = position.dy;
    final distanceToBottom = viewSize.height - position.dy;
    final distanceToEdge = math.min(distanceToTop, distanceToBottom);
    final direction = distanceToTop < distanceToBottom ? 1.0 : -1.0;

    if (distanceToEdge > edgeThreshold) {
      _stopScroll();
      return;
    }

    final fraction = 1.0 - (distanceToEdge / edgeThreshold);
    final speedPxPerSec = maxScrollSpeed * fraction;
    final visualDelta = speedPxPerSec * 16.0 / 1000.0;
    final docDelta = visualDelta / _controller.currentZoom;

    final matrix = _controller.value.clone()
      ..translateByDouble(0, direction * docDelta, 0, 1);
    _controller.value = _controller.makeMatrixInSafeRange(
      matrix,
      forceClamp: true,
    );
  }
}
