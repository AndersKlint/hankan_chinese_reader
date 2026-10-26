import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:logging/logging.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TextPdfExportService {
  final FileService _fileService;
  final _logger = Logger('TextPdfExportService');
  bool _exporting = false;

  TextPdfExportService(this._fileService);

  Future<void> export(Delta delta, {required String sourceName}) async {
    if (_exporting) return;
    _exporting = true;
    try {
      final snapshot = Delta.from(delta);
      final fonts = await Future.wait([
        for (final name in ['Regular', 'Bold', 'RegularItalic', 'BoldItalic'])
          rootBundle.load('assets/fonts/NotoSansSC-$name.ttf.gz').then((data) {
            final bytes = const GZipDecoder().decodeBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            return ByteData.sublistView(bytes);
          }),
      ]);
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          maxPages: 1000,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(48),
          theme: pw.ThemeData.withFont(
            base: pw.Font.ttf(fonts[0]),
            bold: pw.Font.ttf(fonts[1]),
            italic: pw.Font.ttf(fonts[2]),
            boldItalic: pw.Font.ttf(fonts[3]),
          ),
          build: (_) => _paragraphs(snapshot),
        ),
      );
      final basename = sourceName.split(RegExp(r'[/\\]')).last;
      final stem = basename.replaceFirst(RegExp(r'\.[^./\\]+$'), '');
      await _fileService.savePdfFile(
        bytes: await document.save(),
        fileName: '${stem.isEmpty ? 'document' : stem}.pdf',
      );
    } catch (error, stackTrace) {
      _logger.severe('Could not export PDF', error, stackTrace);
      rethrow;
    } finally {
      _exporting = false;
    }
  }

  List<pw.Widget> _paragraphs(Delta delta) {
    final paragraphs = <pw.Widget>[];
    var spans = <pw.InlineSpan>[];
    for (final operation in delta.toList()) {
      final text = operation.data;
      if (text is! String) {
        throw UnsupportedError('PDF export does not support embedded content');
      }
      final attributes = operation.attributes ?? {};
      final parts = text.split('\n');
      for (var index = 0; index < parts.length; index++) {
        if (parts[index].isNotEmpty) {
          spans.add(
            pw.TextSpan(
              text: parts[index],
              style: pw.TextStyle(
                fontWeight: attributes['bold'] == true
                    ? pw.FontWeight.bold
                    : null,
                fontStyle: attributes['italic'] == true
                    ? pw.FontStyle.italic
                    : null,
              ),
            ),
          );
        }
        if (index == parts.length - 1) continue;
        final heading = attributes['header'];
        paragraphs.add(
          pw.RichText(
            overflow: pw.TextOverflow.span,
            text: pw.TextSpan(
              style: pw.TextStyle(
                fontSize: switch (heading) {
                  1 => 24,
                  2 => 19,
                  3 => 15,
                  _ => 12,
                },
                fontWeight: heading == null
                    ? pw.FontWeight.normal
                    : pw.FontWeight.bold,
                lineSpacing: 4,
              ),
              children: spans.isEmpty ? [const pw.TextSpan(text: ' ')] : spans,
            ),
          ),
        );
        spans = [];
      }
    }
    return paragraphs;
  }
}
