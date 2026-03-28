import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:flutter/material.dart';

/// Read-only text view with the popup dictionary active.
class TextReadView extends StatelessWidget {
  /// The text content to display.
  final String text;

  const TextReadView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    if (text.isEmpty) {
      return Center(
        child: Text(
          'No text to display. Switch to edit mode to add text.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > 900
            ? ((constraints.maxWidth - 860) / 2).clamp(24.0, 220.0)
            : 16.0;

        final backgroundSurface = isDark
            ? colorScheme.surfaceContainerLowest
            : colorScheme.surfaceContainerLow;
        final readerSurface = isDark
            ? colorScheme.surfaceContainerLow
            : colorScheme.surface;

        return ColoredBox(
          color: backgroundSurface,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: readerSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              padding: const EdgeInsets.all(20),
              child: TappableTextWrapper(
                showPopupDict: true,
                child: Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontSize: 20, height: 2.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
