import 'dart:io' if (dart.library.html) 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logging/logging.dart';

final _log = Logger('FileService');

/// Handles file picking, reading, and saving across platforms.
class FileService {
  /// Shows an open-file dialog filtered to [extensions].
  /// Returns the picked file result, or `null` if cancelled.
  Future<FilePickerResult?> pickFile({
    List<String> extensions = const ['txt', 'pdf'],
  }) async {
    try {
      return await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        withData: kIsWeb,
      );
    } catch (e) {
      _log.warning('File picker error: $e');
      return null;
    }
  }

  /// Reads text content from a file at [path].
  /// On web, use [bytes] from the picker result instead.
  Future<String> readTextFile(String path) async {
    final file = File(path);
    return file.readAsString();
  }

  /// Reads text from raw bytes (for web platform).
  String readTextFromBytes(List<int> bytes) {
    return String.fromCharCodes(bytes);
  }

  /// Saves [content] to a file at [path].
  /// On web, triggers a download instead.
  Future<String?> saveTextFile({
    required String content,
    String? existingPath,
  }) async {
    if (kIsWeb || existingPath == null) {
      // Show save dialog.
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save text file',
        fileName: 'document.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (result == null) return null;

      if (!kIsWeb) {
        final file = File(result);
        await file.writeAsString(content);
      }
      return result;
    }

    // Desktop/mobile: overwrite existing file.
    final file = File(existingPath);
    await file.writeAsString(content);
    return existingPath;
  }
}
