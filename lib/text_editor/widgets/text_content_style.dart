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
