import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:logging/logging.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import '../models/pdf_highlight.dart';
import 'pdf_annotation_mutation_exception.dart';

class PdfAnnotationRepository {
  Future<T> _execute<T>(PdfDocument document, _AnnotationTask task) async {
    late Future<_AnnotationResult> pending;
    await document.useNativeDocumentHandle((address) {
      // Awaiting here deadlocks the suspended PDFium worker.
      pending = PdfrxEntryFunctions.instance.compute(_executeAnnotationTask, (
        address,
        task,
      ));
    });
    final result = await pending;
    final failure = result.failure;
    if (failure != null) throw failure;
    return result.value as T;
  }

  Future<bool> isSupported(PdfDocument document) =>
      _execute(document, const _AnnotationTask(_AnnotationOperation.support));

  Future<List<PdfHighlight>> load(PdfDocument document) =>
      _execute(document, const _AnnotationTask(_AnnotationOperation.load));

  Future<void> add(
    PdfDocument document,
    Map<int, List<List<PdfRect>>> pages,
    Color color,
  ) => _execute(
    document,
    _AnnotationTask(
      _AnnotationOperation.add,
      pages: pages,
      color: color.toARGB32(),
    ),
  );

  Future<void> recolor(
    PdfDocument document,
    PdfHighlight highlight,
    Color color,
  ) => _execute(
    document,
    _AnnotationTask(
      _AnnotationOperation.recolor,
      highlight: highlight,
      color: color.toARGB32(),
    ),
  );

  Future<void> delete(PdfDocument document, PdfHighlight highlight) => _execute(
    document,
    _AnnotationTask(_AnnotationOperation.delete, highlight: highlight),
  );

  Future<void> replaceGeometry(
    PdfDocument document,
    PdfHighlight highlight,
    List<PdfRect> rects,
  ) => _execute(
    document,
    _AnnotationTask(
      _AnnotationOperation.geometry,
      highlight: highlight,
      rects: rects,
    ),
  );

  Future<Uint8List> read(String path) => XFile(path).readAsBytes();

  Future<String?> persist(
    Uint8List bytes, {
    String? existingPath,
    required String title,
  }) => _persist(bytes, existingPath: existingPath, title: title);
}

enum _AnnotationOperation { support, load, add, recolor, delete, geometry }

class _AnnotationTask {
  final _AnnotationOperation operation;
  final Map<int, List<List<PdfRect>>>? pages;
  final PdfHighlight? highlight;
  final int? color;
  final List<PdfRect>? rects;

  const _AnnotationTask(
    this.operation, {
    this.pages,
    this.highlight,
    this.color,
    this.rects,
  });
}

class _AnnotationResult {
  final Object? value;
  final PdfAnnotationMutationException? failure;

  const _AnnotationResult(this.value, [this.failure]);
}

_AnnotationResult _executeAnnotationTask((int, _AnnotationTask) message) {
  final (address, task) = message;
  final annotations = _NativeAnnotations();
  try {
    switch (task.operation) {
      case _AnnotationOperation.support:
        return _AnnotationResult(annotations.isSupported(address));
      case _AnnotationOperation.load:
        return _AnnotationResult(annotations.load(address));
      case _AnnotationOperation.add:
        annotations.add(address, task.pages!, Color(task.color!));
      case _AnnotationOperation.recolor:
        annotations.recolor(address, task.highlight!, Color(task.color!));
      case _AnnotationOperation.delete:
        annotations.delete(address, task.highlight!);
      case _AnnotationOperation.geometry:
        annotations.replaceGeometry(address, task.highlight!, task.rects!);
    }
    return const _AnnotationResult(null);
  } on PdfAnnotationMutationException catch (error) {
    // Worker exceptions otherwise lose their type during transport.
    return _AnnotationResult(
      null,
      PdfAnnotationMutationException(
        error.cause.toString(),
        error.rollbackError.toString(),
      ),
    );
  }
}

class _NativeAnnotations {
  PDFium? _pdfium;
  PDFium get _api => _pdfium ??= getPdfium(modulePath: Pdfrx.pdfiumModulePath);

  bool isSupported(int address) {
    final handle = Pointer<fpdf_document_t__>.fromAddress(address);
    final api = _api;
    final permissions = api.FPDF_GetDocPermissions(handle);
    // Signed documents require incremental signature-aware editing.
    return (permissions & 32) != 0 && api.FPDF_GetSignatureCount(handle) == 0;
  }

  List<PdfHighlight> load(int address) {
    final api = _api;
    final handle = Pointer<fpdf_document_t__>.fromAddress(address);
    final result = <PdfHighlight>[];
    for (var number = 1; number <= api.FPDF_GetPageCount(handle); number++) {
      _withPage(api, handle, number, (page) {
        for (var index = 0; index < api.FPDFPage_GetAnnotCount(page); index++) {
          final annotation = api.FPDFPage_GetAnnot(page, index);
          if (annotation == nullptr) {
            throw StateError('Cannot read PDF annotation.');
          }
          try {
            if (api.FPDFAnnot_GetSubtype(annotation) != FPDF_ANNOT_HIGHLIGHT) {
              continue;
            }
            final rects = _rects(api, annotation);
            if (rects.isEmpty) continue;
            result.add(
              PdfHighlight(
                pageNumber: number,
                annotationIndex: index,
                color: _color(api, annotation),
                rects: rects,
                isLocked: _isLocked(api.FPDFAnnot_GetFlags(annotation)),
              ),
            );
          } finally {
            api.FPDFPage_CloseAnnot(annotation);
          }
        }
      });
    }
    return result;
  }

  void add(int address, Map<int, List<List<PdfRect>>> pages, Color color) {
    final api = _api;
    final handle = Pointer<fpdf_document_t__>.fromAddress(address);
    final added = <(int, int)>[];
    try {
      for (final entry in pages.entries) {
        _withPage(api, handle, entry.key, (page) {
          for (final rects in entry.value) {
            final index = api.FPDFPage_GetAnnotCount(page);
            final annotation = api.FPDFPage_CreateAnnot(
              page,
              FPDF_ANNOT_HIGHLIGHT,
            );
            if (annotation == nullptr) {
              throw StateError('Cannot create highlight.');
            }
            added.add((entry.key, index));
            try {
              _check(api.FPDFAnnot_SetFlags(annotation, FPDF_ANNOT_FLAG_PRINT));
              _setColor(api, annotation, color.withValues(alpha: 1));
              _setRects(api, annotation, rects);
            } finally {
              api.FPDFPage_CloseAnnot(annotation);
            }
          }
        });
      }
    } catch (error) {
      try {
        for (final (number, index) in added.reversed) {
          _withPage(
            api,
            handle,
            number,
            (page) => _check(api.FPDFPage_RemoveAnnot(page, index)),
          );
        }
      } catch (rollbackError) {
        throw PdfAnnotationMutationException(error, rollbackError);
      }
      rethrow;
    }
  }

  void recolor(int document, PdfHighlight highlight, Color color) => _edit(
    document,
    highlight,
    (api, page, annotation) {
      final oldColor = _color(api, annotation);
      final appearances = <int, Pointer<UnsignedShort>>{};
      try {
        for (var mode = 0; mode < FPDF_ANNOT_APPEARANCEMODE_COUNT; mode++) {
          final length = api.FPDFAnnot_GetAP(annotation, mode, nullptr, 0);
          if (length == 0) {
            throw StateError('Cannot preserve annotation appearance.');
          }
          if (length <= 2) continue;
          final buffer = calloc<UnsignedShort>((length + 1) ~/ 2);
          appearances[mode] = buffer;
          if (api.FPDFAnnot_GetAP(annotation, mode, buffer, length) != length) {
            throw StateError('Cannot preserve annotation appearance.');
          }
        }
        // PDFium rejects color changes until the old appearance is removed.
        _check(
          api.FPDFAnnot_SetAP(
            annotation,
            FPDF_ANNOT_APPEARANCEMODE_NORMAL,
            nullptr,
          ),
        );
        try {
          _setColor(api, annotation, color.withValues(alpha: oldColor.a));
        } catch (error) {
          try {
            for (final entry in appearances.entries) {
              _check(api.FPDFAnnot_SetAP(annotation, entry.key, entry.value));
            }
          } catch (rollbackError) {
            throw PdfAnnotationMutationException(error, rollbackError);
          }
          rethrow;
        }
      } finally {
        for (final buffer in appearances.values) {
          calloc.free(buffer);
        }
      }
    },
  );

  void delete(int document, PdfHighlight highlight) =>
      _edit(document, highlight, (api, page, annotation) {
        _check(api.FPDFPage_RemoveAnnot(page, highlight.annotationIndex));
      });

  void replaceGeometry(
    int document,
    PdfHighlight highlight,
    List<PdfRect> rects,
  ) => _edit(document, highlight, (api, page, annotation) {
    if (rects.isEmpty) throw ArgumentError('Highlight geometry is empty.');
    final color = _color(api, annotation);
    final appearances = <int, Pointer<UnsignedShort>>{};
    try {
      for (var mode = 0; mode < FPDF_ANNOT_APPEARANCEMODE_COUNT; mode++) {
        final length = api.FPDFAnnot_GetAP(annotation, mode, nullptr, 0);
        if (length == 0) {
          throw StateError('Cannot preserve annotation appearance.');
        }
        if (length <= 2) continue;
        final buffer = calloc<UnsignedShort>((length + 1) ~/ 2);
        appearances[mode] = buffer;
        if (api.FPDFAnnot_GetAP(annotation, mode, buffer, length) != length) {
          throw StateError('Cannot preserve annotation appearance.');
        }
      }
      try {
        // Existing appearance streams otherwise keep painting the removed characters.
        _check(
          api.FPDFAnnot_SetAP(
            annotation,
            FPDF_ANNOT_APPEARANCEMODE_NORMAL,
            nullptr,
          ),
        );
        _setColor(api, annotation, color);
        _setRects(api, annotation, rects, replace: true);
      } catch (error) {
        try {
          _setRects(api, annotation, highlight.rects, replace: true);
          _setColor(api, annotation, color);
          for (final entry in appearances.entries) {
            _check(api.FPDFAnnot_SetAP(annotation, entry.key, entry.value));
          }
        } catch (rollbackError) {
          throw PdfAnnotationMutationException(error, rollbackError);
        }
        rethrow;
      }
    } finally {
      for (final buffer in appearances.values) {
        calloc.free(buffer);
      }
    }
  });

  bool _isLocked(int flags) =>
      (flags &
          (FPDF_ANNOT_FLAG_READONLY | FPDF_ANNOT_FLAG_LOCKED | (1 << 9))) !=
      0;

  void _edit(
    int address,
    PdfHighlight highlight,
    void Function(PDFium, FPDF_PAGE, FPDF_ANNOTATION) edit,
  ) {
    final api = _api;
    _withPage(
      api,
      Pointer<fpdf_document_t__>.fromAddress(address),
      highlight.pageNumber,
      (page) {
        final annotation = api.FPDFPage_GetAnnot(
          page,
          highlight.annotationIndex,
        );
        if (annotation == nullptr) {
          throw StateError('Highlight no longer exists.');
        }
        try {
          if (api.FPDFAnnot_GetSubtype(annotation) != FPDF_ANNOT_HIGHLIGHT ||
              !listEquals(_rects(api, annotation), highlight.rects)) {
            throw StateError('Highlight changed; select it again.');
          }
          if (_isLocked(api.FPDFAnnot_GetFlags(annotation))) {
            throw StateError('This annotation is locked.');
          }
          edit(api, page, annotation);
        } finally {
          api.FPDFPage_CloseAnnot(annotation);
        }
      },
    );
  }

  void _withPage(
    PDFium api,
    FPDF_DOCUMENT document,
    int number,
    void Function(FPDF_PAGE) action,
  ) {
    final page = api.FPDF_LoadPage(document, number - 1);
    if (page == nullptr) throw StateError('Cannot load PDF page $number.');
    try {
      action(page);
    } finally {
      api.FPDF_ClosePage(page);
    }
  }

  Color _color(PDFium api, FPDF_ANNOTATION annotation) {
    final values = calloc<UnsignedInt>(4);
    try {
      var found =
          api.FPDFAnnot_GetColor(
            annotation,
            FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
            values,
            values + 1,
            values + 2,
            values + 3,
          ) !=
          0;
      final hasAppearance = !found;
      for (
        var index = 0;
        !found && index < api.FPDFAnnot_GetObjectCount(annotation);
        index++
      ) {
        final object = api.FPDFAnnot_GetObject(annotation, index);
        if (object == nullptr) continue;
        found =
            api.FPDFPageObj_GetFillColor(
              object,
              values,
              values + 1,
              values + 2,
              values + 3,
            ) !=
            0;
      }
      if (!found) throw StateError('Cannot read highlight appearance color.');
      if (hasAppearance) {
        final key = 'CA'.toNativeUtf8();
        final opacity = calloc<Float>();
        try {
          if (api.FPDFAnnot_GetNumberValue(annotation, key.cast(), opacity) !=
              0) {
            values[3] = (opacity.value.clamp(0.0, 1.0) * 255).round();
          }
        } finally {
          malloc.free(key);
          calloc.free(opacity);
        }
      }
      return Color.fromARGB(values[3], values[0], values[1], values[2]);
    } finally {
      calloc.free(values);
    }
  }

  void _setColor(PDFium api, FPDF_ANNOTATION annotation, Color color) {
    final value = color.toARGB32();
    _check(
      api.FPDFAnnot_SetColor(
        annotation,
        FPDFANNOT_COLORTYPE.FPDFANNOT_COLORTYPE_Color,
        (value >> 16) & 255,
        (value >> 8) & 255,
        value & 255,
        (value >> 24) & 255,
      ),
    );
  }

  List<PdfRect> _rects(PDFium api, FPDF_ANNOTATION annotation) {
    final quad = calloc<FS_QUADPOINTSF>();
    try {
      return List.generate(api.FPDFAnnot_CountAttachmentPoints(annotation), (
        index,
      ) {
        _check(api.FPDFAnnot_GetAttachmentPoints(annotation, index, quad));
        final q = quad.ref;
        return PdfRect(
          [q.x1, q.x2, q.x3, q.x4].reduce(math.min),
          [q.y1, q.y2, q.y3, q.y4].reduce(math.max),
          [q.x1, q.x2, q.x3, q.x4].reduce(math.max),
          [q.y1, q.y2, q.y3, q.y4].reduce(math.min),
        );
      }).where((rect) => rect.isNotEmpty).toList();
    } finally {
      calloc.free(quad);
    }
  }

  void _setRects(
    PDFium api,
    FPDF_ANNOTATION annotation,
    List<PdfRect> rects, {
    bool replace = false,
  }) {
    final bounds = rects.reduce((a, b) => a.merge(b));
    final rectangle = calloc<FS_RECTF>();
    final quad = calloc<FS_QUADPOINTSF>();
    try {
      rectangle.ref
        ..left = bounds.left
        ..top = bounds.top
        ..right = bounds.right
        ..bottom = bounds.bottom;
      _check(api.FPDFAnnot_SetRect(annotation, rectangle));
      final existing = replace
          ? api.FPDFAnnot_CountAttachmentPoints(annotation)
          : 0;
      for (var index = 0; index < math.max(existing, rects.length); index++) {
        // PDFium cannot truncate QuadPoints; zero-area surplus quads preserve the annotation dictionary.
        final rect = index < rects.length
            ? rects[index]
            : PdfRect(bounds.left, bounds.top, bounds.left, bounds.top);
        // PDFium uses Adobe's Z-order for text-markup quadrilaterals.
        quad.ref
          ..x1 = rect.left
          ..y1 = rect.top
          ..x2 = rect.right
          ..y2 = rect.top
          ..x3 = rect.left
          ..y3 = rect.bottom
          ..x4 = rect.right
          ..y4 = rect.bottom;
        _check(
          index < existing
              ? api.FPDFAnnot_SetAttachmentPoints(annotation, index, quad)
              : api.FPDFAnnot_AppendAttachmentPoints(annotation, quad),
        );
      }
    } finally {
      calloc.free(rectangle);
      calloc.free(quad);
    }
  }

  void _check(int result) {
    if (result == 0) throw StateError('PDFium could not edit this annotation.');
  }
}

Future<String?> _persist(
  Uint8List bytes, {
  String? existingPath,
  required String title,
}) async {
  try {
    return await _persistToDestination(
      bytes,
      existingPath: existingPath,
      title: title,
    );
  } catch (error, stackTrace) {
    _saveLogger.severe(
      'PDF save failed: originalPath=$existingPath, title=$title',
      error,
      stackTrace,
    );
    rethrow;
  }
}

final _saveLogger = Logger('PdfAnnotationRepository');

Future<String?> _persistToDestination(
  Uint8List bytes, {
  String? existingPath,
  required String title,
}) async {
  var path = existingPath;
  if (path == null || Uri.tryParse(path)?.scheme == 'content') {
    final name = title.toLowerCase().endsWith('.pdf') ? title : '$title.pdf';
    if (Platform.isAndroid || Platform.isIOS) {
      _saveLogger.info(
        'Saving PDF through picker: originalPath=$existingPath, fileName=$name',
      );
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save PDF',
        fileName: name,
        mimeType: 'application/pdf',
        bytes: bytes,
      );
      if (uri != null) {
        _saveLogger.info('PDF picker destination=$uri');
      }
      return uri == null
          ? null
          : uri.scheme == 'file'
          ? uri.toFilePath()
          : uri.toString();
    }
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (location == null) return null;
    path = location.path;
  }
  _saveLogger.info('Saving PDF: originalPath=$existingPath, destination=$path');
  final target = File(path);
  final directory = await target.parent.createTemp('.pdf-save-');
  final temporary = File('${directory.path}/document.pdf');
  var keepRecoveryDirectory = false;
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    if (Platform.isWindows && await target.exists()) {
      final backup = '${directory.path}/original.pdf';
      await target.rename(backup);
      try {
        await temporary.rename(target.path);
      } catch (_) {
        try {
          await File(backup).rename(target.path);
        } catch (error) {
          keepRecoveryDirectory = true;
          throw FileSystemException(
            'Replacement failed; original PDF retained at $backup: $error',
            target.path,
          );
        }
        rethrow;
      }
    } else {
      await temporary.rename(target.path);
    }
  } finally {
    if (!keepRecoveryDirectory) await directory.delete(recursive: true);
  }
  return path;
}
