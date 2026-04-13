import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores recently opened documents and persisted PDF viewport state.
class DocumentHistoryService extends ChangeNotifier {
  /// Maximum number of recent documents kept in persistent storage.
  static const int maxEntries = 50;

  static const String _storageKey = 'document_history_entries';

  final SharedPreferences _preferences;
  final Logger _logger = Logger('DocumentHistoryService');
  final List<RecentDocumentEntry> _entries = <RecentDocumentEntry>[];

  /// Creates a document history service backed by [SharedPreferences].
  DocumentHistoryService(this._preferences);

  /// Returns the current recent-document list, newest first.
  List<RecentDocumentEntry> get recentDocuments =>
      List<RecentDocumentEntry>.unmodifiable(_entries);

  /// Loads persisted entries from storage.
  Future<void> load() async {
    final rawValue = _preferences.getString(_storageKey);
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return;
      }

      _entries
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map(
            (item) =>
                RecentDocumentEntry.fromJson(item.cast<String, Object?>()),
          ),
        );
      notifyListeners();
    } catch (error, stackTrace) {
      _logger.warning('Failed to load document history.', error, stackTrace);
    }
  }

  /// Records a document open and moves it to the front of the recent list.
  Future<void> noteDocumentOpened({
    required String path,
    required String title,
    required DocumentType type,
  }) async {
    final existingIndex = _entries.indexWhere((entry) => entry.path == path);
    final existing = existingIndex >= 0
        ? _entries.removeAt(existingIndex)
        : null;
    final entry =
        (existing ??
                RecentDocumentEntry(
                  path: path,
                  title: _displayTitleFor(path, title),
                  type: type,
                  lastOpenedAt: DateTime.now(),
                ))
            .copyWith(
              title: _displayTitleFor(path, title),
              type: type,
              lastOpenedAt: DateTime.now(),
            );

    _entries.insert(0, entry);
    _trimToLimit();
    await _persist();
    notifyListeners();
  }

  /// Returns the saved PDF viewport state for [path], if one exists.
  PdfDocumentViewState? getPdfViewState(String path) {
    final index = _entries.indexWhere((entry) => entry.path == path);
    if (index < 0) {
      return null;
    }
    return _entries[index].pdfViewState;
  }

  /// Saves the latest PDF viewport state without changing recent ordering.
  Future<void> savePdfViewState({
    required String path,
    required String title,
    required int pageNumber,
    required double zoom,
    required Offset centerPosition,
  }) async {
    final viewState = PdfDocumentViewState(
      pageNumber: pageNumber,
      zoom: zoom,
      centerDx: centerPosition.dx,
      centerDy: centerPosition.dy,
    );
    final index = _entries.indexWhere((entry) => entry.path == path);

    if (index < 0) {
      _entries.insert(
        0,
        RecentDocumentEntry(
          path: path,
          title: _displayTitleFor(path, title),
          type: DocumentType.pdf,
          lastOpenedAt: DateTime.now(),
          pdfViewState: viewState,
        ),
      );
      _trimToLimit();
    } else {
      _entries[index] = _entries[index].copyWith(
        title: _displayTitleFor(path, title),
        type: DocumentType.pdf,
        pdfViewState: viewState,
      );
    }

    await _persist();
  }

  String _displayTitleFor(String path, String title) {
    if (title.isNotEmpty) {
      return title;
    }

    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isNotEmpty ? segments.last : path;
  }

  void _trimToLimit() {
    if (_entries.length <= maxEntries) {
      return;
    }
    _entries.removeRange(maxEntries, _entries.length);
  }

  Future<void> _persist() async {
    try {
      await _preferences.setString(
        _storageKey,
        jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
      );
    } catch (error, stackTrace) {
      _logger.warning('Failed to persist document history.', error, stackTrace);
    }
  }
}

/// A recent document entry with optional persisted PDF viewport state.
@immutable
class RecentDocumentEntry {
  /// Absolute path used to reopen the document.
  final String path;

  /// Filename shown in the recents menu.
  final String title;

  /// Document type used to reopen the document correctly.
  final DocumentType type;

  /// Time when the document was last explicitly opened.
  final DateTime lastOpenedAt;

  /// Last saved PDF viewport state for this document, if any.
  final PdfDocumentViewState? pdfViewState;

  /// Creates a recent document entry.
  const RecentDocumentEntry({
    required this.path,
    required this.title,
    required this.type,
    required this.lastOpenedAt,
    this.pdfViewState,
  });

  /// Creates an entry from persisted JSON data.
  factory RecentDocumentEntry.fromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final documentType = DocumentType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => DocumentType.text,
    );
    final lastOpenedMillis = json['lastOpenedAt'];
    final pdfViewStateJson = json['pdfViewState'];

    return RecentDocumentEntry(
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? '',
      type: documentType,
      lastOpenedAt: DateTime.fromMillisecondsSinceEpoch(
        lastOpenedMillis is int ? lastOpenedMillis : 0,
      ),
      pdfViewState: pdfViewStateJson is Map<String, Object?>
          ? PdfDocumentViewState.fromJson(pdfViewStateJson)
          : pdfViewStateJson is Map
          ? PdfDocumentViewState.fromJson(
              pdfViewStateJson.cast<String, Object?>(),
            )
          : null,
    );
  }

  /// Returns a copy with selected fields replaced.
  RecentDocumentEntry copyWith({
    String? path,
    String? title,
    DocumentType? type,
    DateTime? lastOpenedAt,
    PdfDocumentViewState? pdfViewState,
    bool clearPdfViewState = false,
  }) {
    return RecentDocumentEntry(
      path: path ?? this.path,
      title: title ?? this.title,
      type: type ?? this.type,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      pdfViewState: clearPdfViewState
          ? null
          : pdfViewState ?? this.pdfViewState,
    );
  }

  /// Serializes this entry for persistent storage.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'path': path,
      'title': title,
      'type': type.name,
      'lastOpenedAt': lastOpenedAt.millisecondsSinceEpoch,
      'pdfViewState': pdfViewState?.toJson(),
    };
  }
}

/// Persisted PDF viewport information used to restore reading position.
@immutable
class PdfDocumentViewState {
  /// Current page number when the state was saved.
  final int pageNumber;

  /// Current viewer zoom level.
  final double zoom;

  /// Current document-space center X coordinate.
  final double centerDx;

  /// Current document-space center Y coordinate.
  final double centerDy;

  /// Creates a PDF viewport state snapshot.
  const PdfDocumentViewState({
    required this.pageNumber,
    required this.zoom,
    required this.centerDx,
    required this.centerDy,
  });

  /// Creates a state snapshot from persisted JSON data.
  factory PdfDocumentViewState.fromJson(Map<String, Object?> json) {
    double doubleValue(Object? value) {
      if (value is num) {
        return value.toDouble();
      }
      return 0;
    }

    return PdfDocumentViewState(
      pageNumber: json['pageNumber'] as int? ?? 1,
      zoom: doubleValue(json['zoom']),
      centerDx: doubleValue(json['centerDx']),
      centerDy: doubleValue(json['centerDy']),
    );
  }

  /// Returns the saved document-space center point.
  Offset get centerPosition => Offset(centerDx, centerDy);

  /// Serializes this state for persistent storage.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'pageNumber': pageNumber,
      'zoom': zoom,
      'centerDx': centerDx,
      'centerDy': centerDy,
    };
  }
}
