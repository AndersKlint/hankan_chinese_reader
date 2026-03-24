import 'package:flutter/material.dart';

/// A search bar that highlights and navigates through matches in text.
class TextSearchBar extends StatefulWidget {
  /// The text to search within.
  final String text;

  /// Called when the search bar is closed.
  final VoidCallback onClose;

  const TextSearchBar({
    super.key,
    required this.text,
    required this.onClose,
  });

  @override
  State<TextSearchBar> createState() => _TextSearchBarState();
}

class _TextSearchBarState extends State<TextSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  List<int> _matchPositions = [];
  int _currentMatchIndex = -1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _matchPositions = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final positions = <int>[];
    final lowerText = widget.text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;
      positions.add(index);
      start = index + 1;
    }

    setState(() {
      _matchPositions = positions;
      _currentMatchIndex = positions.isEmpty ? -1 : 0;
    });
  }

  void _nextMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchPositions.length;
    });
  }

  void _previousMatch() {
    if (_matchPositions.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _matchPositions.length) %
              _matchPositions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final matchText = _matchPositions.isEmpty
        ? 'No results'
        : '${_currentMatchIndex + 1}/${_matchPositions.length}';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
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
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            matchText,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            onPressed: _matchPositions.isEmpty ? null : _previousMatch,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            onPressed: _matchPositions.isEmpty ? null : _nextMatch,
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
