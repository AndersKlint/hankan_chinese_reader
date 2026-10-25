class PdfAnnotationMutationException implements Exception {
  final Object cause;
  final Object rollbackError;

  const PdfAnnotationMutationException(this.cause, this.rollbackError);

  @override
  String toString() =>
      'PDF mutation failed ($cause); rollback failed ($rollbackError). Review the document before saving.';
}
