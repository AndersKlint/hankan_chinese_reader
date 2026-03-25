import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:flutter/material.dart';

/// Read-only text view with the popup dictionary active.
class TextReadView extends StatelessWidget {
  /// The text content to display.
  final String text;

  const TextReadView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Center(
        child: Text(
          'No text to display. Switch to edit mode to add text.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
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
    );
  }
}
