import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:logging/logging.dart';
import 'package:mobile_ocr/mobile_ocr.dart';
import 'package:pdfrx/pdfrx.dart';

/// Performs targeted OCR on PDF page crops for tap-driven dictionary lookups.
class PdfOcrService {
  /// Fraction of page width used for the OCR crop area.
  static const double _cropWidthFraction = 0.10;

  /// Divisor for calculating crop height from page width (width / _cropHeightMultiplier).
  static const double _cropHeightMultiplier = 2;

  /// Maximum height of the crop area as a fraction of the page height.
  static const double _maxCropHeightFraction = 0.22;

  /// Scale factor for rendering the crop region (higher = more detail for OCR).
  static const double _renderScale = 1.5;

  final MobileOcr _mobileOcr = MobileOcr();
  final Logger _logger = Logger('PdfOcrService');
  Future<void>? _warmUpFuture;

  bool get isSupported => true;

  Future<void> warmUp() {
    return _warmUpFuture ??= _mobileOcr.prepareModels().then((_) {});
  }

  Future<PdfOcrLookup?> lookupAtPoint({
    required PdfPage page,
    required PdfPoint pagePoint,
  }) async {
    PdfImage? renderedImage;
    try {
      await warmUp();

      final resolvedPage = page.isLoaded ? page : await page.ensureLoaded();

      final pageImageSize = Size(
        resolvedPage.width * _renderScale,
        resolvedPage.height * _renderScale,
      );

      final cropRect = _buildCropRect(page: resolvedPage, pagePoint: pagePoint);
      // Match pdfrx viewer coordinates so OCR crops stay aligned on rotated pages.
      final cropRectInImage = cropRect.toRect(
        page: resolvedPage,
        scaledPageSize: pageImageSize,
      );
      final tapInImage = pagePoint.toOffset(
        page: resolvedPage,
        scaledPageSize: pageImageSize,
      );
      final renderX = cropRectInImage.left.floor();
      final renderY = cropRectInImage.top.floor();
      final renderWidth = cropRectInImage.width.ceil().clamp(
        1,
        pageImageSize.width.ceil(),
      );
      final renderHeight = cropRectInImage.height.ceil().clamp(
        1,
        pageImageSize.height.ceil(),
      );

      renderedImage = await resolvedPage.render(
        x: renderX,
        y: renderY,
        width: renderWidth,
        height: renderHeight,
        fullWidth: pageImageSize.width,
        fullHeight: pageImageSize.height,
        backgroundColor: 0xffffffff,
      );

      if (renderedImage == null) {
        return null;
      }

      final image = img.Image.fromBytes(
        width: renderedImage.width,
        height: renderedImage.height,
        bytes: renderedImage.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );

      final blocks = await _mobileOcr.detectTextFromImage(
        image: image,
        trimRecognitionWhitespace: false,
        enhanceRecognitionCrops: false,
      );
      if (blocks.isEmpty) {
        return null;
      }

      final localTap = tapInImage.translate(
        -renderX.toDouble(),
        -renderY.toDouble(),
      );
      final bestBlock = _pickBestBlock(blocks, localTap);
      if (bestBlock == null || bestBlock.characters.isEmpty) {
        return null;
      }

      final charIndex = _resolveCharacterIndex(bestBlock.characters, localTap);
      if (charIndex == null) {
        return null;
      }

      final normalizedText = bestBlock.characters.map((c) => c.text).join();
      if (normalizedText.isEmpty) {
        return null;
      }

      return PdfOcrLookup(
        text: normalizedText,
        charIndex: charIndex,
        targetRectOnPage: _mapCharacterRectToPage(
          bestBlock.characters[charIndex].boundingBox,
          resolvedPage,
          pageImageSize,
          Offset(renderX.toDouble(), renderY.toDouble()),
        ),
      );
    } catch (error, stackTrace) {
      _logger.warning('OCR lookup failed', error, stackTrace);
      return null;
    } finally {
      renderedImage?.dispose();
    }
  }

  PdfRect _buildCropRect({required PdfPage page, required PdfPoint pagePoint}) {
    final cropWidth = (page.width * _cropWidthFraction).clamp(80.0, page.width);
    final cropHeight = (page.height / _cropHeightMultiplier).clamp(
      36.0,
      page.height * _maxCropHeightFraction,
    );

    final left = (pagePoint.x - cropWidth / 2).clamp(
      0.0,
      page.width - cropWidth,
    );
    final bottom = (pagePoint.y - cropHeight / 2).clamp(
      0.0,
      page.height - cropHeight,
    );

    return PdfRect(left, bottom + cropHeight, left + cropWidth, bottom);
  }

  TextBlock? _pickBestBlock(List<TextBlock> blocks, Offset localTap) {
    TextBlock? bestBlock;
    var bestDistance = double.infinity;

    for (final block in blocks) {
      final distance = _distanceToRect(block.boundingBox, localTap);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestBlock = block;
      }
    }

    return bestBlock;
  }

  int? _resolveCharacterIndex(List<CharacterBox> characters, Offset localTap) {
    var bestDistance = double.infinity;
    int? bestIndex;

    for (var index = 0; index < characters.length; index++) {
      final distance = _distanceToRect(characters[index].boundingBox, localTap);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = index;
      }
    }

    return bestIndex;
  }

  PdfRect _mapCharacterRectToPage(
    Rect imageRect,
    PdfPage page,
    Size pageImageSize,
    Offset cropOriginInImage,
  ) => imageRect
      .shift(cropOriginInImage)
      .toPdfRect(page: page, scaledPageSize: pageImageSize);

  double _distanceToRect(Rect rect, Offset point) {
    if (rect.contains(point)) {
      return 0;
    }

    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return dx * dx + dy * dy;
  }
}

/// OCR lookup result mapped back into page coordinates.
class PdfOcrLookup {
  final String text;
  final int charIndex;
  final PdfRect targetRectOnPage;

  const PdfOcrLookup({
    required this.text,
    required this.charIndex,
    required this.targetRectOnPage,
  });
}
