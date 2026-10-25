import 'dart:math' as math;

import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show Document;
import 'package:hankan_chinese_reader/text_editor/models/text_search_result.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_content_style.dart';
import 'package:hankan_chinese_reader/text_editor/widgets/text_document_spans.dart';

class TextReadView extends StatefulWidget {
  final String text;
  final Document document;
  final List<TextSearchResult> matches;
  final int activeMatchIndex;
  final ScrollController scrollController;
  final ScrollPhysics? scrollPhysics;
  final Object? revealToken;
  final double fontSize;

  const TextReadView({
    super.key,
    required this.text,
    required this.document,
    required this.matches,
    required this.activeMatchIndex,
    required this.scrollController,
    required this.fontSize,
    this.scrollPhysics,
    this.revealToken,
  });

  @override
  State<TextReadView> createState() => _TextReadViewState();
}

class _TextReadViewState extends State<TextReadView> {
  Object? _revealedToken;

  void _revealMatch(TextPainter painter) {
    if (_revealedToken == widget.revealToken ||
        widget.activeMatchIndex < 0 ||
        widget.activeMatchIndex >= widget.matches.length) {
      return;
    }
    _revealedToken = widget.revealToken;
    final position = painter.getOffsetForCaret(
      TextPosition(offset: widget.matches[widget.activeMatchIndex].start),
      Rect.zero,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      final scroll = widget.scrollController;
      final target =
          (position.dy +
                  textEditorContentPadding.top -
                  scroll.position.viewportDimension * 0.22)
              .clamp(0.0, scroll.position.maxScrollExtent);
      scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final span = textDocumentSpans(
      context,
      document: widget.document,
      text: widget.text,
      fontSize: widget.fontSize,
      matches: widget.matches,
      activeMatchIndex: widget.activeMatchIndex,
    );
    final strut = textEditorContentStrutStyle(
      context,
      fontSize: widget.fontSize,
    );
    return TextEditorSurface(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          controller: widget.scrollController,
          physics: widget.scrollPhysics,
          padding: textEditorContentPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - textEditorContentPadding.vertical,
              ),
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: double.infinity,
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    if (widget.revealToken != _revealedToken &&
                        widget.activeMatchIndex >= 0) {
                      final painter = TextPainter(
                        text: span,
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        strutStyle: strut,
                        textHeightBehavior: textEditorContentTextHeightBehavior,
                      )..layout(maxWidth: contentConstraints.maxWidth);
                      _revealMatch(painter);
                      painter.dispose();
                    }
                    if (widget.text.isEmpty) {
                      return Text(
                        'No text to display. Switch to edit mode to add text.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                      );
                    }
                    return ChinesePopupDict(
                      text: Text.rich(
                        span,
                        strutStyle: strut,
                        textHeightBehavior: textEditorContentTextHeightBehavior,
                        textWidthBasis: TextWidthBasis.parent,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
