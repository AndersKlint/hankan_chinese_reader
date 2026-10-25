import 'package:flutter_quill/flutter_quill.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart' as markdown;

class DocumentCodec {
  Document fromPlainText(String text) => Document.fromJson([
    {'insert': '$text\n'},
  ]);

  Document fromMarkdown(String source) {
    final operations = <Map<String, dynamic>>[];
    for (final line in source.split('\n')) {
      final match = RegExp(r'^(#{1,3}) (.*)$').firstMatch(line);
      final body = match?.group(2) ?? line;
      final nodes = markdown.Document().parseInline(body);
      final fragment = html_parser.parseFragment(markdown.renderToHtml(nodes));
      _appendNodes(fragment.nodes, operations, const {});
      operations.add({
        'insert': '\n',
        if (match != null) 'attributes': {'header': match.group(1)!.length},
      });
    }
    return Document.fromJson(operations);
  }

  Document fromHtml(String source) {
    final operations = <Map<String, dynamic>>[];
    _appendNodes(html_parser.parseFragment(source).nodes, operations, const {});
    if (operations.isEmpty ||
        !(operations.last['insert'] as String).endsWith('\n')) {
      operations.add({'insert': '\n'});
    }
    return Document.fromJson(operations);
  }

  void _appendNodes(
    List<html.Node> nodes,
    List<Map<String, dynamic>> operations,
    Map<String, dynamic> attributes,
  ) {
    for (final node in nodes) {
      if (node is html.Text) {
        if (node.data.isNotEmpty) {
          operations.add({
            'insert': node.data,
            if (attributes.isNotEmpty) 'attributes': attributes,
          });
        }
      } else if (node is html.Element) {
        _appendElement(node, operations, attributes);
      }
    }
  }

  void _appendElement(
    html.Element node,
    List<Map<String, dynamic>> operations,
    Map<String, dynamic> attributes,
  ) {
    final tag = node.localName;
    if (const {'script', 'style', 'meta', 'head'}.contains(tag)) return;
    if (tag == 'br') {
      operations.add({'insert': '\n'});
      return;
    }
    final style = node.attributes['style'] ?? '';
    final next = {...attributes};
    if (tag == 'strong' ||
        tag == 'b' ||
        RegExp(r'font-weight\s*:\s*(bold|[6-9]00)').hasMatch(style)) {
      next['bold'] = true;
    }
    if (tag == 'em' ||
        tag == 'i' ||
        RegExp(r'font-style\s*:\s*italic').hasMatch(style)) {
      next['italic'] = true;
    }
    _appendNodes(node.nodes, operations, next);
    if (const {'p', 'div', 'h1', 'h2', 'h3', 'li'}.contains(tag)) {
      operations.add({
        'insert': '\n',
        if (tag == 'h1' || tag == 'h2' || tag == 'h3')
          'attributes': {'header': int.parse(tag!.substring(1))},
      });
    }
  }

  String toMarkdown(Document document) {
    final lines = <String>[];
    var line = StringBuffer();
    for (final operation in document.toDelta().toList()) {
      final data = operation.data;
      if (data is! String) continue;
      final attributes = operation.attributes ?? const <String, dynamic>{};
      final parts = data.split('\n');
      for (var index = 0; index < parts.length; index++) {
        if (index > 0) {
          final heading = attributes['header'];
          lines.add(
            '${heading == 1
                ? '# '
                : heading == 2
                ? '## '
                : heading == 3
                ? '### '
                : ''}$line',
          );
          line = StringBuffer();
        }
        if (parts[index].isEmpty) continue;
        var text = _escape(parts[index]);
        if (attributes['italic'] == true) text = '<em>$text</em>';
        if (attributes['bold'] == true) text = '<strong>$text</strong>';
        line.write(text);
      }
    }
    return lines.join('\n');
  }

  String _escape(String text) => text.runes.map((rune) {
    if (rune <= 0x7f &&
        (rune <= 0x20 ||
            !RegExp(r'[a-zA-Z0-9]').hasMatch(String.fromCharCode(rune)))) {
      return '&#$rune;';
    }
    return String.fromCharCode(rune);
  }).join();

  bool hasFormatting(Document document) => document.toDelta().toList().any(
    (operation) =>
        operation.attributes?.entries.any(
          (entry) =>
              (entry.key == 'bold' || entry.key == 'italic') &&
                  entry.value == true ||
              entry.key == 'header' &&
                  (entry.value == 1 || entry.value == 2 || entry.value == 3),
        ) ??
        false,
  );
}
