/// The type of document opened in a tab.
enum DocumentType {
  /// Plain text document.
  text,

  /// PDF document.
  pdf,
}

/// Represents a single open document tab.
class TabModel {
  /// Unique identifier for this tab.
  final String id;

  /// Display title (filename or "Untitled").
  String title;

  /// The type of document.
  final DocumentType type;

  /// The file path on disk, or `null` for untitled documents.
  String? filePath;

  /// Whether the document has unsaved changes.
  bool isModified;

  /// For text documents, the current text content.
  String? textContent;

  /// For text documents, whether read mode is enabled.
  bool isReadMode;

  /// For text documents, whether search bar is visible.
  bool showTextSearch;

  /// For text documents, current search query.
  String textSearchQuery;

  /// For text documents, read mode scroll offset.
  double textReadScrollOffset;

  /// For text documents, edit mode scroll offset.
  double textEditScrollOffset;

  /// For text documents, current content font size.
  double textFontSize;

  /// For PDFs, current page number.
  int pdfCurrentPage;

  /// For PDFs, whether thumbnails sidebar is visible.
  bool showPdfThumbnails;

  /// For PDFs, whether search bar is visible.
  bool showPdfSearch;

  /// For PDFs, current search query.
  String pdfSearchQuery;

  TabModel({
    required this.id,
    required this.title,
    required this.type,
    this.filePath,
    this.isModified = false,
    this.textContent,
    this.isReadMode = false,
    this.showTextSearch = false,
    this.textSearchQuery = '',
    this.textReadScrollOffset = 0,
    this.textEditScrollOffset = 0,
    this.textFontSize = 18,
    this.pdfCurrentPage = 1,
    this.showPdfThumbnails = false,
    this.showPdfSearch = false,
    this.pdfSearchQuery = '',
  });
}
