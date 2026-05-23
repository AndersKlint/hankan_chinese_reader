import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

/// Search bar for PDF documents with prev/next navigation and match count.
class PdfSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final PdfTextSearcher textSearcher;
  final VoidCallback onClose;
  final ValueChanged<String>? onSearchChanged;
  final bool showCloseButton;

  const PdfSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.textSearcher,
    required this.onClose,
    this.onSearchChanged,
    this.showCloseButton = true,
  });

  @override
  State<PdfSearchBar> createState() => _PdfSearchBarState();
}

class _PdfSearchBarState extends State<PdfSearchBar> {
  Future<void> _goToNextMatch() async {
    await widget.textSearcher.goToNextMatch();
    if (!mounted) return;
    setState(() {});
    widget.focusNode.requestFocus();
  }

  Future<void> _goToPreviousMatch() async {
    await widget.textSearcher.goToPrevMatch();
    if (!mounted) return;
    setState(() {});
    widget.focusNode.requestFocus();
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
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _goToNextMatch,
                const SingleActivator(
                  LogicalKeyboardKey.enter,
                  shift: true,
                ): _goToPreviousMatch,
                const SingleActivator(LogicalKeyboardKey.numpadEnter):
                    _goToNextMatch,
                const SingleActivator(
                  LogicalKeyboardKey.numpadEnter,
                  shift: true,
                ): _goToPreviousMatch,
              },
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  filled: false,
                ),
                onChanged: (value) {
                  widget.textSearcher.startTextSearch(value);
                  widget.onSearchChanged?.call(value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: widget.textSearcher,
            builder: (context, _) {
              final matchCount = widget.textSearcher.matches.length;
              final currentIndex = widget.textSearcher.currentIndex;
              final text = matchCount > 0
                  ? '${(currentIndex ?? 0) + 1}/$matchCount'
                  : widget.textSearcher.isSearching
                      ? '...'
                      : '0/0';
              return Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            onPressed: _goToPreviousMatch,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            onPressed: _goToNextMatch,
            visualDensity: VisualDensity.compact,
          ),
          if (widget.showCloseButton)
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
