import 'dart:convert' show utf8;
import 'dart:io' if (dart.library.html) 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../pdf_reader/repositories/pdf_annotation_repository.dart';

/// Handles file picking, reading, and saving across platforms.
class FileService {
  Future<String?> savePdfFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    String withExtension(String path) => path.toLowerCase().endsWith('.pdf')
        ? path
        : '${path.replaceFirst(RegExp(r'\.[^./\\]+$'), '')}.pdf';
    var suggestedName = withExtension(fileName);
    if (!kIsWeb &&
        (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      String? initialDirectory;
      while (true) {
        final location = await file_selector.getSaveLocation(
          suggestedName: suggestedName,
          initialDirectory: initialDirectory,
          acceptedTypeGroups: [
            const file_selector.XTypeGroup(label: 'PDF', extensions: ['pdf']),
          ],
        );
        if (location == null) return null;
        final path = withExtension(location.path);
        if (path == location.path) {
          await File(path).writeAsBytes(bytes);
          return path;
        }
        initialDirectory = File(path).parent.path;
        suggestedName = Uri.file(path).pathSegments.last;
      }
    }
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export as PDF',
      fileName: suggestedName,
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    if (uri == null) return null;
    return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
  }

  Future<Uint8List> readPdfFile(String path) =>
      PdfAnnotationRepository().read(path);

  /// Shows an open-file dialog filtered to [extensions].
  /// Returns the picked file result, or `null` if cancelled.
  Future<PlatformFile?> pickFile({
    List<String> extensions = const ['md', 'markdown', 'txt', 'pdf'],
  }) async {
    return FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
  }

  /// Reads text content from a file at [path].
  /// On web, use [bytes] from the picker result instead.
  Future<String> readTextFile(String path) async {
    final file = File(path);
    return file.readAsString();
  }

  /// Reads text from raw bytes (for web platform).
  String readTextFromBytes(List<int> bytes) => utf8.decode(bytes);

  /// Saves [content] to a file at [path].
  /// On web, triggers a download instead.
  Future<String?> saveTextFile({
    required String content,
    String? existingPath,
    String fileName = 'document.md',
    bool asMarkdown = true,
  }) async {
    final isContentUri = Uri.tryParse(existingPath ?? '')?.scheme == 'content';
    if (kIsWeb || existingPath == null || isContentUri) {
      if (!kIsWeb &&
          (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        final path = await _pickDesktopSavePath(
          fileName,
          asMarkdown: asMarkdown,
        );
        if (path == null) return null;
        await File(path).writeAsString(content);
        return path;
      }
      final bytes = Uint8List.fromList(utf8.encode(content));
      final uri = await FilePicker.saveFile(
        dialogTitle: asMarkdown ? 'Save document' : 'Save text file',
        fileName: _withTextExtension(fileName, asMarkdown: asMarkdown),
        mimeType: asMarkdown ? 'text/markdown' : 'text/plain',
        bytes: bytes,
      );
      if (uri == null) return null;
      return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
    }

    final file = File(existingPath);
    await file.writeAsString(content);
    return existingPath;
  }

  Future<String?> _pickDesktopSavePath(
    String fileName, {
    required bool asMarkdown,
  }) async {
    var suggestedName = _withTextExtension(fileName, asMarkdown: asMarkdown);
    String? initialDirectory;
    while (true) {
      final location = await file_selector.getSaveLocation(
        suggestedName: suggestedName,
        initialDirectory: initialDirectory,
        acceptedTypeGroups: [
          file_selector.XTypeGroup(
            label: asMarkdown ? 'Markdown' : 'Text',
            extensions: asMarkdown ? ['md', 'markdown'] : ['txt'],
          ),
        ],
      );
      if (location == null) return null;
      final path = location.path;
      final normalizedPath = _withTextExtension(path, asMarkdown: asMarkdown);
      if (normalizedPath == path) return path;
      initialDirectory = File(normalizedPath).parent.path;
      suggestedName = Uri.file(normalizedPath).pathSegments.last;
    }
  }

  String _withTextExtension(String path, {required bool asMarkdown}) {
    final lowerPath = path.toLowerCase();
    if (asMarkdown &&
        (lowerPath.endsWith('.md') || lowerPath.endsWith('.markdown'))) {
      return path;
    }
    if (!asMarkdown && lowerPath.endsWith('.txt')) return path;
    final extension = asMarkdown ? '.md' : '.txt';
    return path.replaceFirst(RegExp(r'\.[^./\\]+$'), '') + extension;
  }
}
