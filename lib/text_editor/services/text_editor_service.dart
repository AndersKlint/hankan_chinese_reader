import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/text_editor/services/document_codec.dart';
import 'package:logging/logging.dart';

class TextEditorService {
  final QuillController controller = QuillController.basic();
  final ValueNotifier<String> content = ValueNotifier('');
  final ValueNotifier<bool> isModified = ValueNotifier(false);
  final ValueNotifier<bool> isReadMode = ValueNotifier(false);
  final ValueNotifier<int> revision = ValueNotifier(0);
  final FileService? _fileService;
  final TabService? _tabService;
  final DocumentCodec _codec = DocumentCodec();
  final Logger _logger = Logger('TextEditorService');
  StreamSubscription<DocChange>? _subscription;
  Delta _savedDelta = Delta();
  String? _serializedContent;
  String? _tabId;
  String? _filePath;
  bool _disposed = false;

  TextEditorService({this._fileService, this._tabService});

  String get serializedContent =>
      _serializedContent ??= _codec.toMarkdown(controller.document);
  bool get canUndo => controller.hasUndo;
  bool get canRedo => controller.hasRedo;
  bool get isBold =>
      controller.getSelectionStyle().attributes['bold']?.value == true;
  bool get isItalic =>
      controller.getSelectionStyle().attributes['italic']?.value == true;
  int? get headingLevel {
    final value = controller.getSelectionStyle().attributes['header']?.value;
    return value == 1 || value == 2 || value == 3 ? value as int : null;
  }

  void initialize(
    String text, {
    required bool isReadMode,
    String? tabId,
    String? filePath,
    bool isMarkdown = false,
  }) {
    _subscription?.cancel();
    final previous = controller.document;
    controller.document = isMarkdown
        ? _codec.fromMarkdown(text)
        : _codec.fromPlainText(text);
    previous.close();
    controller.forceToggledStyle(const Style());
    _tabId = tabId;
    _filePath = filePath;
    this.isReadMode.value = isReadMode;
    controller.readOnly = isReadMode;
    _serializedContent = null;
    _savedDelta = Delta.from(controller.document.toDelta());
    isModified.value = false;
    _updatePlainContent();
    _subscription = controller.changes.listen(_documentChanged);
  }

  void _updatePlainContent() {
    final plainText = controller.document.toPlainText();
    content.value = plainText.substring(0, plainText.length - 1);
  }

  void _documentChanged(DocChange change) {
    if (change.change.isEmpty) return;
    _serializedContent = null;
    if (change.change.toList().any((op) => op.isInsert || op.isDelete)) {
      _updatePlainContent();
    }
    isModified.value = controller.document.toDelta() != _savedDelta;
    revision.value++;
    _syncTab();
  }

  void _syncTab({bool retainContent = false}) {
    final tabService = _tabService;
    final tabId = _tabId;
    if (tabService == null || tabId == null) return;
    final tab = tabService.tabs.value
        .where((tab) => tab.id == tabId)
        .firstOrNull;
    if (tab == null) return;
    if (retainContent) {
      final hasFormatting = _codec.hasFormatting(controller.document);
      tab.textContent = hasFormatting ? serializedContent : content.value;
      tab.textIsMarkdown = hasFormatting;
    }
    tabService.setModified(tabId, modified: isModified.value);
  }

  void toggleBold() => controller.formatSelection(
    Attribute.clone(Attribute.bold, isBold ? null : true),
  );
  void toggleItalic() => controller.formatSelection(
    Attribute.clone(Attribute.italic, isItalic ? null : true),
  );
  void setHeading(int? level) {
    if (level != null && level != 1 && level != 2 && level != 3) {
      throw ArgumentError.value(level, 'level');
    }
    controller.formatSelection(Attribute.clone(Attribute.header, level));
  }

  void undo() {
    if (canUndo) controller.undo();
  }

  void redo() {
    if (canRedo) controller.redo();
  }

  void toggleReadMode() {
    isReadMode.value = !isReadMode.value;
    controller.readOnly = isReadMode.value;
  }

  Future<bool> save() async {
    final fileService = _fileService;
    if (fileService == null) return false;
    final document = controller.document;
    final snapshot = Delta.from(document.toDelta());
    final path = _filePath;
    final isText = path?.toLowerCase().endsWith('.txt') ?? false;
    final asMarkdown = !isText || _codec.hasFormatting(document);
    final forceSaveAs = isText && asMarkdown;
    final saveContent = asMarkdown ? serializedContent : content.value;
    final baseName = path?.split(RegExp(r'[/\\]')).last ?? 'document.md';
    try {
      final savedPath = await fileService.saveTextFile(
        content: saveContent,
        existingPath: forceSaveAs ? null : path,
        fileName: forceSaveAs
            ? baseName.replaceFirst(
                RegExp(r'\.txt$', caseSensitive: false),
                '.md',
              )
            : baseName,
        asMarkdown: asMarkdown,
      );
      if (savedPath == null || _disposed || controller.document != document) {
        return false;
      }
      _filePath = savedPath;
      _savedDelta = snapshot;
      isModified.value = document.toDelta() != snapshot;
      final tabService = _tabService;
      final tabId = _tabId;
      if (tabService != null &&
          tabId != null &&
          tabService.tabs.value.any((tab) => tab.id == tabId)) {
        tabService.findTab(tabId).filePath = savedPath;
        tabService.setTitle(tabId, savedPath.split(RegExp(r'[/\\]')).last);
      }
      _syncTab(retainContent: true);
      return true;
    } catch (error, stackTrace) {
      _logger.severe('Could not save document', error, stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _syncTab(retainContent: true);
    _disposed = true;
    _subscription?.cancel();
    controller.dispose();
    content.dispose();
    isModified.dispose();
    isReadMode.dispose();
    revision.dispose();
  }
}
