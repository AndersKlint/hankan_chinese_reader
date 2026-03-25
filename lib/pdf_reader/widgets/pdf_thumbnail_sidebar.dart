import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Left sidebar showing page thumbnails for quick navigation.
class PdfThumbnailSidebar extends StatelessWidget {
  /// Path to the PDF file.
  final String filePath;

  /// Currently visible page number (1-indexed).
  final int currentPage;

  /// Callback when a thumbnail is tapped.
  final ValueChanged<int> onPageTapped;

  /// Width of the sidebar.
  final double width;

  const PdfThumbnailSidebar({
    super.key,
    required this.filePath,
    required this.currentPage,
    required this.onPageTapped,
    this.width = 160,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: PdfDocumentViewBuilder.file(
        filePath,
        builder: (context, document) {
          if (document == null) {
            return const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: document.pages.length,
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              final isActive = pageNumber == currentPage;

              return GestureDetector(
                onTap: () => onPageTapped(pageNumber),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isActive ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 180,
                        child: PdfPageView(
                          document: document,
                          pageNumber: pageNumber,
                          maximumDpi: 72,
                          decoration: const BoxDecoration(color: Colors.white),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '$pageNumber',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
