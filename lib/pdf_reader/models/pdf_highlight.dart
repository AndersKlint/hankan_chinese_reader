import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

@immutable
class PdfHighlight {
  final int pageNumber;
  final int annotationIndex;
  final Color color;
  final List<PdfRect> rects;
  final bool isLocked;

  PdfHighlight({
    required this.pageNumber,
    required this.annotationIndex,
    required this.color,
    required List<PdfRect> rects,
    this.isLocked = false,
  }) : rects = List.unmodifiable(rects);
}
