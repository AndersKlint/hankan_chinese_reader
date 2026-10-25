import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/pdf_highlight.dart';

class PdfAnnotationRepository {
  Future<bool> isSupported(PdfDocument document) async => false;
  Future<List<PdfHighlight>> load(PdfDocument document) async => const [];
  Future<void> add(
    PdfDocument document,
    Map<int, List<List<PdfRect>>> pages,
    Color color,
  ) async =>
      throw UnsupportedError('PDF annotations require a native platform.');
  Future<void> recolor(
    PdfDocument document,
    PdfHighlight highlight,
    Color color,
  ) async =>
      throw UnsupportedError('PDF annotations require a native platform.');
  Future<void> delete(PdfDocument document, PdfHighlight highlight) async =>
      throw UnsupportedError('PDF annotations require a native platform.');
  Future<void> replaceGeometry(
    PdfDocument document,
    PdfHighlight highlight,
    List<PdfRect> rects,
  ) async =>
      throw UnsupportedError('PDF annotations require a native platform.');
  Future<String?> persist(
    Uint8List bytes, {
    String? existingPath,
    required String title,
  }) async =>
      throw UnsupportedError('PDF annotations require a native platform.');
  Future<Uint8List> read(String path) async =>
      throw UnsupportedError('PDF file paths require a native platform.');
}
