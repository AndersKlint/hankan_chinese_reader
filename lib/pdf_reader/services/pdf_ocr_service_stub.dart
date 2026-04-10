import 'package:pdfrx/pdfrx.dart';

/// No-op OCR service for unsupported platforms such as web.
class PdfOcrService {
  bool get isSupported => false;

  Future<void> warmUp() async {}

  Future<PdfOcrLookup?> lookupAtPoint({
    required PdfPage page,
    required PdfPoint pagePoint,
  }) async {
    return null;
  }
}

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
