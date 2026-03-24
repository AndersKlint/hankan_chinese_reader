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

  TabModel({
    required this.id,
    required this.title,
    required this.type,
    this.filePath,
    this.isModified = false,
    this.textContent,
  });
}
