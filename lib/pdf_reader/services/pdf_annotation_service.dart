import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:logging/logging.dart';

import '../../core/models/tab_model.dart';
import '../../core/services/tab_service.dart';
import '../../core/services/document_history_service.dart';
import '../models/pdf_highlight.dart';
import '../repositories/pdf_annotation_repository.dart';
import '../repositories/pdf_annotation_mutation_exception.dart';

class PdfAnnotationService extends ChangeNotifier {
  final PdfAnnotationRepository _repository;
  final TabService _tabs;
  final DocumentHistoryService _history;
  PdfDocument? _document;
  PdfDocumentRef? _documentRef;
  String? _tabId;
  String? _filePath;
  String _title = 'document.pdf';
  bool _supported = false;
  bool _busy = false;
  bool _disposed = false;
  int _contentRevision = 0;
  List<PdfHighlight> _highlights = const [];

  PdfAnnotationService(
    this._repository, {
    required TabService tabService,
    required DocumentHistoryService historyService,
  }) : _tabs = tabService,
       _history = historyService;

  bool get isSupported => _supported;
  bool get isBusy => _busy;
  int get contentRevision => _contentRevision;
  List<PdfHighlight> get highlights => _highlights;
  String? get filePath => _filePath;

  void initialize(String tabId) {
    if (_tabId != null) {
      throw StateError('Annotation service already initialized.');
    }
    final tab = _tabs.findTab(tabId);
    _tabId = tabId;
    _filePath = tab.filePath;
    _title = tab.title;
  }

  Future<void> attachDocument(
    PdfDocument document,
    PdfDocumentRef documentRef,
  ) => _run(
    () async {
      if (_tabId == null) {
        throw StateError('Initialize the annotation service first.');
      }
      _document = document;
      _documentRef = documentRef;
      _supported = false;
      final supported = await _repository.isSupported(document);
      _highlights = List.unmodifiable(await _repository.load(document));
      _supported = supported;
    },
    documentRef: documentRef,
    expectedDocument: document,
  );

  Future<void> applyHighlightColor(
    List<PdfPageTextRange> ranges,
    Color? color,
  ) async {
    final pages = <int, List<List<PdfRect>>>{};
    final selections = <int, Set<int>>{};
    final texts = <int, PdfPageText>{};
    for (final range in ranges) {
      final rects = _selectionRects(range);
      if (rects.isNotEmpty) (pages[range.pageNumber] ??= []).add(rects);
      texts[range.pageNumber] = range.pageText;
      (selections[range.pageNumber] ??= {}).addAll([
        for (var index = range.start; index < range.end; index++) index,
      ]);
    }
    if (pages.isEmpty) return;
    for (final page in pages.keys) {
      pages[page] = [_textRects(texts[page]!, selections[page]!.contains)];
    }
    final edits = <(PdfHighlight, List<PdfRect>)>[];
    for (final highlight in _highlights) {
      final text = texts[highlight.pageNumber];
      final selected = selections[highlight.pageNumber];
      if (text == null || selected == null) continue;
      final remaining = <PdfRect>[];
      var changed = false;
      for (final quad in highlight.rects) {
        final covered = <int>{
          for (var index = 0; index < text.charRects.length; index++)
            if (_coversCharacter(quad, text.charRects[index])) index,
        };
        if (!covered.any(selected.contains)) {
          remaining.add(quad);
          continue;
        }
        changed = true;
        remaining.addAll(
          _textRects(
            text,
            (index) => covered.contains(index) && !selected.contains(index),
          ),
        );
      }
      if (!changed) continue;
      if (highlight.isLocked) throw StateError('This annotation is locked.');
      edits.add((highlight, remaining));
    }
    if (edits.isEmpty && color == null) return;
    edits.sort((first, second) {
      final page = first.$1.pageNumber.compareTo(second.$1.pageNumber);
      return page != 0
          ? page
          : second.$1.annotationIndex.compareTo(first.$1.annotationIndex);
    });
    var completed = 0;
    await _mutate(pages.keys.toList(), (document) async {
      for (final (highlight, rects) in edits) {
        if (rects.isEmpty) {
          await _repository.delete(document, highlight);
        } else {
          await _repository.replaceGeometry(document, highlight, rects);
        }
        completed++;
      }
      if (color != null) await _repository.add(document, pages, color);
    }, hasPartialChanges: () => completed > 0);
  }

  bool _coversCharacter(PdfRect quad, PdfRect character) =>
      character.isNotEmpty &&
      character.center.x >= quad.left &&
      character.center.x <= quad.right &&
      character.center.y >= quad.bottom &&
      character.center.y <= quad.top;

  List<PdfRect> _selectionRects(PdfPageTextRange range) {
    final text = range.pageText;
    if (range.start < 0 ||
        range.end > text.charRects.length ||
        range.end < range.start) {
      throw RangeError('Invalid PDF text selection.');
    }
    return _textRects(
      text,
      (index) => index >= range.start && index < range.end,
    );
  }

  List<PdfRect> _textRects(PdfPageText text, bool Function(int) includes) {
    final result = <PdfRect>[];
    for (final fragment in text.fragments) {
      PdfRect? current;
      for (var index = fragment.index; index < fragment.end; index++) {
        if (!includes(index)) {
          if (current != null) result.add(current);
          current = null;
          continue;
        }
        final rect = text.charRects[index];
        if (rect.isEmpty || text.fullText[index].trim().isEmpty) continue;
        final previous = current;
        final vertical = fragment.direction == PdfTextDirection.vrtl;
        final sameLine =
            previous != null &&
            (vertical
                ? (previous.center.x - rect.center.x).abs() < rect.width * 0.5
                : (previous.center.y - rect.center.y).abs() <
                      rect.height * 0.5);
        final nearby =
            previous != null &&
            (vertical
                ? (previous.bottom - rect.top).abs() < rect.width * 2
                : (rect.left - previous.right).abs() < rect.height * 2);
        if (sameLine && nearby) {
          current = previous.merge(rect);
        } else {
          if (previous != null) result.add(previous);
          current = rect;
        }
      }
      if (current != null) result.add(current);
    }
    return result;
  }

  Future<void> _mutate(
    List<int> pages,
    Future<void> Function(PdfDocument) edit, {
    bool Function()? hasPartialChanges,
  }) => _run(() async {
    final document = _requireDocument();
    if (!await _repository.isSupported(document)) {
      throw StateError('PDF annotations are not permitted.');
    }
    try {
      await edit(document);
    } catch (error) {
      if (error is! PdfAnnotationMutationException &&
          !(hasPartialChanges?.call() ?? false)) {
        rethrow;
      }
      _tabs.setModified(_tabId!, modified: true);
      try {
        try {
          _highlights = List.unmodifiable(await _repository.load(document));
        } finally {
          _contentRevision++;
          await document.reloadPages(pageNumbersToReload: pages);
        }
      } catch (refreshError, stackTrace) {
        Logger('PdfAnnotationService').warning(
          'Could not refresh PDF after partial annotation mutation',
          refreshError,
          stackTrace,
        );
      }
      rethrow;
    }
    _tabs.setModified(_tabId!, modified: true);
    try {
      _highlights = List.unmodifiable(await _repository.load(document));
    } finally {
      _contentRevision++;
      await document.reloadPages(pageNumbersToReload: pages);
    }
  });

  Future<bool> save({bool saveAs = false}) => _run(() async {
    final document = _requireDocument();
    final bytes = await document.encodePdf(removeSecurity: false);
    final path = await _repository.persist(
      bytes,
      existingPath: saveAs ? null : _filePath,
      title: _title,
    );
    if (path == null) return false;
    _filePath = path;
    _title =
        Uri.tryParse(path.replaceAll('\\', '/'))?.pathSegments.lastOrNull ??
        path;
    final tab = _tabs.findTab(_tabId!);
    tab.filePath = path;
    tab.title = _title;
    _tabs.setModified(_tabId!, modified: false);
    _tabs.notifyTabStateChanged();
    await _history.noteDocumentOpened(
      path: path,
      title: _title,
      type: DocumentType.pdf,
    );
    return true;
  });

  PdfDocument _requireDocument() {
    final document = _document;
    if (!_supported || document == null || _disposed) {
      throw StateError('PDF annotations are unavailable.');
    }
    return document;
  }

  Future<T> _run<T>(
    Future<T> Function() action, {
    PdfDocumentRef? documentRef,
    PdfDocument? expectedDocument,
  }) async {
    if (_busy || _disposed) {
      throw StateError('A PDF operation is already in progress.');
    }
    _busy = true;
    notifyListeners();
    try {
      final ref = documentRef ?? _documentRef;
      if (ref == null) throw StateError('PDF document is unavailable.');
      // Keep the lease local so disposal cannot release an in-flight native handle.
      final result = await ref.resolveListenable().useDocument((
        document,
      ) async {
        if (!identical(document, expectedDocument ?? _document)) {
          throw StateError('PDF document has changed.');
        }
        return (value: await action());
      }, ensureLoaded: false);
      if (result == null) throw StateError('PDF document is unavailable.');
      return result.value;
    } catch (error, stackTrace) {
      Logger('PdfAnnotationService')
          .warning('PDF annotation operation failed', error, stackTrace);
      rethrow;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _document = null;
    super.dispose();
  }
}
