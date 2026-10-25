import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';

TextSpan textDocumentSpans(
  BuildContext context, {
  required Document document,
  required String text,
  required double fontSize,
  required List<TextSearchResult> matches,
  required int activeMatchIndex,
}) {
  final base = textEditorParagraphStyle(context, fontSize: fontSize);
  if (text.isEmpty) return TextSpan(text: '', style: base);
  final runs = <({int end, Map<String, dynamic> attributes})>[];
  final headings = <({int start, int end, int level})>[];
  final boundaries = <int>{0, text.length};
  var offset = 0;
  var lineStart = 0;
  for (final operation in document.toDelta().toList()) {
    final data = operation.data;
    if (data is! String) continue;
    final attributes = operation.attributes ?? const <String, dynamic>{};
    if (offset < text.length) {
      boundaries.add(offset);
      boundaries.add((offset + data.length).clamp(0, text.length));
      runs.add((end: offset + data.length, attributes: attributes));
    }
    var newline = data.indexOf('\n');
    while (newline >= 0) {
      final end = offset + newline + 1;
      final heading = attributes['header'];
      if (heading == 1 || heading == 2 || heading == 3) {
        headings.add((start: lineStart, end: end, level: heading as int));
        boundaries.add(lineStart.clamp(0, text.length));
        boundaries.add(end.clamp(0, text.length));
      }
      lineStart = end;
      newline = data.indexOf('\n', newline + 1);
    }
    offset += data.length;
  }
  for (final match in matches) {
    boundaries.add(match.start.clamp(0, text.length));
    boundaries.add(match.end.clamp(0, text.length));
  }
  final points = boundaries.toList()..sort();
  final colors = Theme.of(context).colorScheme;
  var runIndex = 0;
  var headingIndex = 0;
  return TextSpan(
    style: base,
    children: List.generate(points.length - 1, (index) {
      final start = points[index];
      while (runIndex < runs.length - 1 && runs[runIndex].end <= start) {
        runIndex++;
      }
      while (headingIndex < headings.length &&
          headings[headingIndex].end <= start) {
        headingIndex++;
      }
      final heading =
          headingIndex < headings.length &&
              headings[headingIndex].start <= start
          ? headings[headingIndex].level
          : null;
      final attributes = runs[runIndex].attributes;
      final active =
          activeMatchIndex >= 0 &&
          activeMatchIndex < matches.length &&
          start >= matches[activeMatchIndex].start &&
          start < matches[activeMatchIndex].end;
      final highlighted = matches.any(
        (match) => start >= match.start && start < match.end,
      );
      return TextSpan(
        text: text.substring(start, points[index + 1]),
        style:
            textEditorParagraphStyle(
              context,
              fontSize: fontSize,
              heading: heading,
            ).copyWith(
              fontWeight: attributes['bold'] == true || heading != null
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontStyle: attributes['italic'] == true
                  ? FontStyle.italic
                  : FontStyle.normal,
              backgroundColor: active
                  ? colors.primaryContainer
                  : highlighted
                  ? colors.secondaryContainer
                  : null,
            ),
      );
    }),
  );
}
