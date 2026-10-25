import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill/internal.dart'
    show
        ClipboardServiceProvider,
        PreserveBlockStyleOnInsertRule,
        PreserveLineStyleOnSplitRule,
        ResetLineFormatOnNewLineRule,
        PreserveInlineStylesRule,
        CatchAllInsertRule;
import 'package:hankan_chinese_reader/text_editor/services/document_codec.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';

class EditorClipboardService {
  final _logger = Logger('EditorClipboardService');

  void configure(Document document) {
    // Custom insertion rules run before Quill's autolink rules.
    document.setCustomRules(const [
      PreserveBlockStyleOnInsertRule(),
      PreserveLineStyleOnSplitRule(),
      ResetLineFormatOnNewLineRule(),
      PreserveInlineStylesRule(),
      CatchAllInsertRule(),
    ]);
  }

  Future<void> paste(QuillController controller) async {
    if (controller.readOnly) return;
    final selection = controller.selection;
    final document = controller.document;
    String? source;
    try {
      source = await ClipboardServiceProvider.instance.getHtmlText();
    } catch (error, stackTrace) {
      _logger.fine('HTML clipboard unavailable', error, stackTrace);
    }
    final Delta delta;
    int? finalHeading;
    if (source != null && source.isNotEmpty) {
      final pasted = DocumentCodec().fromHtml(_inlineStyles(source));
      finalHeading = pasted.toDelta().last.attributes?['header'] as int?;
      delta = _supportedDelta(pasted.toDelta().slice(0, pasted.length - 1));
      pasted.close();
    } else {
      final plain = await Clipboard.getData(Clipboard.kTextPlain);
      final text = plain?.text;
      if (text == null) return;
      delta = text.isNotEmpty && text == controller.pastePlainText
          ? _supportedDelta(controller.pasteDelta)
          : (Delta()..insert(text));
    }
    if (delta.isEmpty ||
        controller.readOnly ||
        controller.document != document ||
        controller.selection != selection) {
      return;
    }
    controller.replaceText(
      selection.start,
      selection.end - selection.start,
      delta,
      TextSelection.collapsed(offset: selection.start + delta.length),
    );
    if (finalHeading != null) {
      controller.formatText(
        selection.start + delta.length,
        0,
        Attribute.clone(Attribute.header, finalHeading),
      );
    }
  }

  Delta _supportedDelta(Delta source) {
    final result = Delta();
    for (final operation in source.toList()) {
      final data = operation.data;
      if (data is! String) continue;
      final attributes = operation.attributes ?? const <String, dynamic>{};
      result.insert(data, {
        if (attributes['bold'] == true) 'bold': true,
        if (attributes['italic'] == true) 'italic': true,
        if (attributes['header'] == 1 ||
            attributes['header'] == 2 ||
            attributes['header'] == 3)
          'header': attributes['header'],
      });
    }
    return result;
  }

  String _inlineStyles(String source) {
    final document = html_parser.parse(source);
    for (final sheet in document.querySelectorAll('style')) {
      for (final rule in RegExp(
        r'([^{}]+)\{([^{}]+)\}',
      ).allMatches(sheet.text)) {
        for (final selector in rule.group(1)!.split(',')) {
          try {
            for (final element in document.querySelectorAll(selector.trim())) {
              element.attributes['style'] =
                  '${rule.group(2)};${element.attributes['style'] ?? ''}'
                      .toLowerCase();
            }
          } catch (error, stackTrace) {
            _logger.fine(
              'Unsupported clipboard CSS selector',
              error,
              stackTrace,
            );
          }
        }
      }
    }
    for (final element in document.querySelectorAll('[style]')) {
      element.attributes['style'] = element.attributes['style']!.toLowerCase();
    }
    _normalizeBlocks(document.body);
    return document.body?.innerHtml ?? source;
  }

  void _normalizeBlocks(html.Element? parent) {
    if (parent == null) return;
    const blocks = {'p', 'div', 'h1', 'h2', 'h3', 'li', 'ul', 'ol'};
    if (blocks.contains(parent.localName) &&
        parent.children.length == 1 &&
        parent.children.single.localName == 'br' &&
        parent.text.trim().isEmpty) {
      parent.children.single.remove();
    }
    for (final child in parent.children.toList()) {
      _normalizeBlocks(child);
      final style = child.attributes['style'] ?? '';
      final heading = child.localName == 'p'
          ? RegExp(
                  r'\bmsoheading([123])\b',
                ).firstMatch((child.attributes['class'] ?? '').toLowerCase()) ??
                RegExp(r'mso-outline-level\s*:\s*([123])\b').firstMatch(style)
          : null;
      final normalBoldWrapper =
          child.localName == 'b' &&
          RegExp(r'font-weight\s*:\s*(normal|400)\b').hasMatch(style);
      final blockWrapper =
          child.localName == 'div' &&
          child.children.isNotEmpty &&
          child.nodes.every(
            (node) =>
                node is html.Element &&
                    (blocks.contains(node.localName) ||
                        node.localName == 'span' &&
                            node.querySelector('p,div,h1,h2,h3,li,ul,ol') !=
                                null) ||
                node is html.Text && node.data.trim().isEmpty,
          );
      if (normalBoldWrapper || blockWrapper || heading != null) {
        // Docs' normal-weight b wrappers and block-container divs have no semantic emphasis or extra paragraph.
        final replacement =
            html.Element.tag(heading == null ? 'span' : 'h${heading.group(1)}')
              ..attributes.addAll(child.attributes)
              ..nodes.addAll(child.nodes.toList());
        child.replaceWith(replacement);
      }
    }
    if (parent.querySelector('p,div,h1,h2,h3,li,ul,ol') != null) {
      parent.nodes.removeWhere(
        (node) => node is html.Text && node.data.trim().isEmpty,
      );
    }
  }
}
