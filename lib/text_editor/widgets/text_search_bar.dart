import 'package:flutter/material.dart';

/// A search bar that highlights and navigates through matches in text.
class TextSearchBar extends StatefulWidget {
  /// Current match label text (for example: "2/8" or "No results").
  final String matchLabel;

  /// Initial query shown in the search box.
  final String initialQuery;

  /// Whether navigation actions should be enabled.
  final bool hasMatches;

  /// Called when the query changes.
  final ValueChanged<String> onQueryChanged;

  /// Navigate to previous match.
  final VoidCallback onPreviousMatch;

  /// Navigate to next match.
  final VoidCallback onNextMatch;

  /// Called when the search bar is closed.
  final VoidCallback onClose;

  const TextSearchBar({
    super.key,
    required this.matchLabel,
    required this.initialQuery,
    required this.hasMatches,
    required this.onQueryChanged,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onClose,
  });

  @override
  State<TextSearchBar> createState() => _TextSearchBarState();
}

class _TextSearchBarState extends State<TextSearchBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
              ),
              onChanged: widget.onQueryChanged,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.matchLabel,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            onPressed: widget.hasMatches ? widget.onPreviousMatch : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            onPressed: widget.hasMatches ? widget.onNextMatch : null,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close search',
            onPressed: widget.onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
