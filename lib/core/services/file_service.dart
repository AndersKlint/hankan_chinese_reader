import 'dart:convert' show utf8;
import 'dart:io' if (dart.library.html) 'dart:io';
import 'dart:typed_data' show Uint8List;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Handles file picking, reading, and saving across platforms.
class FileService {
  /// Shows an open-file dialog filtered to [extensions].
  /// Returns the picked file result, or `null` if cancelled.
  Future<PlatformFile?> pickFile({
    List<String> extensions = const ['txt', 'pdf'],
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
  }) async {
    final isContentUri = Uri.tryParse(existingPath ?? '')?.scheme == 'content';
    if (kIsWeb || existingPath == null || isContentUri) {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save text file',
        fileName: 'document.txt',
        mimeType: 'text/plain',
        bytes: bytes,
      );
      if (uri == null) return null;
      return uri.scheme == 'file' ? uri.toFilePath() : uri.toString();
    }

    final file = File(existingPath);
    await file.writeAsString(content);
    return existingPath;
  }
}
