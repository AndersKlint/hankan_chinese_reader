import 'package:flutter/material.dart';

/// Default font size used by text editor content.
const double textEditorDefaultFontSize = 18;

/// Minimum supported font size used by text editor content.
const double textEditorMinFontSize = 12;

/// Maximum supported font size used by text editor content.
const double textEditorMaxFontSize = 40;

/// Shared line height for text editor content.
const double textEditorLineHeight = 1.5;

/// Shared border radius for text editor surfaces.
const double textEditorSurfaceRadius = 14;

/// Shared content padding for both edit and read modes.
const EdgeInsets textEditorContentPadding = EdgeInsets.all(20);

/// Shared text height behavior so read and edit layouts align.
const TextHeightBehavior textEditorContentTextHeightBehavior =
    TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even);

/// Returns the shared text style used by both edit and read modes.
TextStyle? textEditorContentTextStyle(
  BuildContext context, {
  required double fontSize,
}) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
    fontSize: fontSize,
    height: textEditorLineHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// Returns the shared strut style for consistent line metrics.
StrutStyle? textEditorContentStrutStyle(
  BuildContext context, {
  required double fontSize,
}) {
  final textStyle = textEditorContentTextStyle(context, fontSize: fontSize);
  if (textStyle == null) {
    return null;
  }

  return StrutStyle.fromTextStyle(textStyle, forceStrutHeight: true);
}

/// Shared responsive surface wrapper used by both edit and read modes.
///
/// Provides consistent responsive side padding, background color, surface
/// card with border and rounded corners. Pass the inner content as [child].
class TextEditorSurface extends StatelessWidget {
  /// The inner content rendered inside the surface card.
  final Widget child;

  const TextEditorSurface({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final backgroundSurface = isDark
        ? colorScheme.surfaceContainerLowest
        : colorScheme.surfaceContainerLow;
    final cardSurface = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surface;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidePadding = constraints.maxWidth > 900
            ? ((constraints.maxWidth - 860) / 2).clamp(24.0, 220.0)
            : 16.0;

        return ColoredBox(
          color: backgroundSurface,
          child: Padding(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 16),
            child: Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(textEditorSurfaceRadius),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(textEditorSurfaceRadius),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
