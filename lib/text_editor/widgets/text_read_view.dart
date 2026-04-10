import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';

/// Read-only text view with the popup dictionary active.
class TextReadView extends StatelessWidget {
  /// The text content to display.
  final String text;

  /// Current search query.
  final String searchQuery;

  /// All search matches.
  final List<TextSearchResult> matches;

  /// Active match index in [matches], or -1 when none.
  final int activeMatchIndex;

  /// Scroll controller from parent for state persistence and jump-to-match.
  final ScrollController scrollController;

  /// Key of the active match to scroll into view.
  final GlobalKey? activeMatchKey;

  /// Font size used by the reader content.
  final double fontSize;

  const TextReadView({
    super.key,
    required this.text,
    required this.searchQuery,
    required this.matches,
    required this.activeMatchIndex,
    required this.scrollController,
    required this.fontSize,
    this.activeMatchKey,
  });

  List<InlineSpan> _buildHighlightedSpans(BuildContext context) {
    final spans = <InlineSpan>[];
    final baseStyle = textEditorContentTextStyle(context, fontSize: fontSize);

    if (searchQuery.isEmpty || matches.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
      return spans;
    }

    int cursor = 0;
    for (int i = 0; i < matches.length; i++) {
      final match = matches[i];
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: text.substring(cursor, match.start), style: baseStyle),
        );
      }

      final isActive = i == activeMatchIndex;
      final highlightColor = isActive
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.secondaryContainer;
      final matchText = text.substring(match.start, match.end);
      if (isActive && activeMatchKey != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              key: activeMatchKey,
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(matchText, style: baseStyle),
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle?.copyWith(backgroundColor: highlightColor),
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    if (text.isEmpty) {
      return Center(
        child: Text(
          'No text to display. Switch to edit mode to add text.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > 900
            ? ((constraints.maxWidth - 860) / 2).clamp(24.0, 220.0)
            : 16.0;

        final backgroundSurface = isDark
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow;
        final readerSurface = isDark
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface;

        return ColoredBox(
          color: backgroundSurface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 16),
            child: Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(
                color: readerSurface,
                borderRadius: BorderRadius.circular(textEditorSurfaceRadius),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(textEditorSurfaceRadius),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: textEditorContentPadding,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: math.max(
                        0,
                        constraints.maxHeight -
                            textEditorContentPadding.vertical,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: ChinesePopupDict(
                          text: Text.rich(
                            TextSpan(children: _buildHighlightedSpans(context)),
                            strutStyle: textEditorContentStrutStyle(
                              context,
                              fontSize: fontSize,
                            ),
                            textHeightBehavior:
                                textEditorContentTextHeightBehavior,
                            textWidthBasis: TextWidthBasis.parent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
