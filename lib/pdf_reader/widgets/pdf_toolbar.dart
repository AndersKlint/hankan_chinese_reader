import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// Top toolbar for the PDF reader with search, thumbnail toggle, and page nav.
class PdfToolbar extends StatelessWidget {
  final bool showThumbnails;
  final VoidCallback onToggleThumbnails;
  final VoidCallback onActivateSearch;
  final PdfTextSearcher? textSearcher;
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSubmitted;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final bool canZoom;
  final bool ocrEnabled;
  final bool canToggleOcr;
  final ValueChanged<bool> onOcrChanged;
  final bool popupDictEnabled;
  final ValueChanged<bool> onPopupDictChanged;
  final bool showOcrProgress;
  final bool canEdit;
  final bool hasSelection;
  final Color? highlightColor;
  final VoidCallback onHighlight;
  final VoidCallback onChooseColor;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;

  const PdfToolbar({
    super.key,
    required this.showThumbnails,
    required this.onToggleThumbnails,
    required this.onActivateSearch,
    required this.textSearcher,
    required this.currentPage,
    required this.pageCount,
    required this.onPageSubmitted,
    required this.onZoomOut,
    required this.onZoomIn,
    this.canZoom = false,
    required this.ocrEnabled,
    required this.canToggleOcr,
    required this.onOcrChanged,
    required this.popupDictEnabled,
    required this.onPopupDictChanged,
    this.showOcrProgress = false,
    required this.canEdit,
    required this.hasSelection,
    required this.highlightColor,
    required this.onHighlight,
    required this.onChooseColor,
    required this.onSave,
    required this.onSaveAs,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minDesktopWidth = 720;
          if (constraints.maxWidth >= minDesktopWidth) {
            return _buildDesktopToolbar(context);
          }
          return _buildMobileToolbar(context);
        },
      ),
    );
  }

  Widget _buildDesktopToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveOcrColor = colorScheme.onSurfaceVariant;
    final activeOcrColor = colorScheme.onSurface;

    return Row(
      children: [
        IconButton(
          icon: Icon(
            showThumbnails ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            size: 18,
          ),
          tooltip: 'Toggle page thumbnails',
          onPressed: onToggleThumbnails,
          visualDensity: VisualDensity.compact,
        ),

        const VerticalDivider(width: 1, indent: 8, endIndent: 8),

        IconButton(
          icon: const Icon(Icons.search, size: 18),
          tooltip: 'Search in document (Ctrl+F)',
          onPressed: textSearcher != null ? onActivateSearch : null,
          visualDensity: VisualDensity.compact,
        ),

        const VerticalDivider(width: 1, indent: 8, endIndent: 8),

        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          tooltip: 'Zoom out (Ctrl + Minus)',
          onPressed: canZoom ? onZoomOut : null,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Zoom in (Ctrl + Plus)',
          onPressed: canZoom ? onZoomIn : null,
          visualDensity: VisualDensity.compact,
        ),

        const VerticalDivider(width: 1, indent: 8, endIndent: 8),

        Tooltip(
          message: 'Toggle OCR dictionary lookup',
          child: TextButton(
            onPressed: canToggleOcr ? () => onOcrChanged(!ocrEnabled) : null,
            style: TextButton.styleFrom(
              foregroundColor: ocrEnabled ? activeOcrColor : inactiveOcrColor,
              textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: ocrEnabled ? FontWeight.w600 : FontWeight.w400,
              ),
              minimumSize: const Size(48, 30),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('OCR'),
          ),
        ),
        Tooltip(
          message: 'Toggle popup dictionary',
          child: TextButton(
            onPressed: () => onPopupDictChanged(!popupDictEnabled),
            style: TextButton.styleFrom(
              foregroundColor: popupDictEnabled
                  ? activeOcrColor
                  : inactiveOcrColor,
              textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: popupDictEnabled
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              minimumSize: const Size(48, 30),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Dict'),
          ),
        ),

        const Spacer(),

        IconButton(
          tooltip: highlightColor == null
              ? 'Clear selected highlighting'
              : 'Highlight selected text',
          icon: Icon(
            highlightColor == null ? Icons.format_color_reset : Icons.highlight,
            color: canEdit ? highlightColor : null,
          ),
          onPressed: canEdit && hasSelection ? onHighlight : null,
        ),
        IconButton(
          tooltip: 'Highlight color',
          icon: const Icon(Icons.palette_outlined, size: 18),
          onPressed: canEdit ? onChooseColor : null,
        ),
        IconButton(
          tooltip: 'Save (Ctrl/Cmd+S)',
          icon: const Icon(Icons.save_outlined, size: 18),
          onPressed: canEdit ? onSave : null,
        ),
        _overflowMenu(),

        _PageInput(
          currentPage: currentPage,
          pageCount: pageCount,
          onPageSubmitted: onPageSubmitted,
        ),

        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Search in document',
          icon: const Icon(Icons.search, size: 18),
          onPressed: textSearcher != null ? onActivateSearch : null,
        ),
        IconButton(
          tooltip: highlightColor == null
              ? 'Clear selected highlighting'
              : 'Highlight selected text',
          icon: Icon(
            highlightColor == null ? Icons.format_color_reset : Icons.highlight,
            color: canEdit ? highlightColor : null,
          ),
          onPressed: canEdit && hasSelection ? onHighlight : null,
        ),
        const Spacer(),
        _PageInput(
          currentPage: currentPage,
          pageCount: pageCount,
          onPageSubmitted: onPageSubmitted,
        ),
        _overflowMenu(),
      ],
    );
  }

  Widget _overflowMenu() => PopupMenuButton<VoidCallback>(
    tooltip: 'PDF actions',
    onSelected: (action) => action(),
    itemBuilder: (context) => [
      PopupMenuItem(value: onSave, enabled: canEdit, child: const Text('Save')),
      PopupMenuItem(
        value: onSaveAs,
        enabled: canEdit,
        child: const Text('Save As…'),
      ),
      PopupMenuItem(
        value: onChooseColor,
        enabled: canEdit,
        child: const Text('Highlight color…'),
      ),
      PopupMenuItem(
        value: onToggleThumbnails,
        child: const Text('Toggle thumbnails'),
      ),
      PopupMenuItem(
        value: onZoomIn,
        enabled: canZoom,
        child: const Text('Zoom in'),
      ),
      PopupMenuItem(
        value: onZoomOut,
        enabled: canZoom,
        child: const Text('Zoom out'),
      ),
      PopupMenuItem(
        value: () => onOcrChanged(!ocrEnabled),
        enabled: canToggleOcr,
        child: Text(ocrEnabled ? 'Disable OCR' : 'Enable OCR'),
      ),
      PopupMenuItem(
        value: () => onPopupDictChanged(!popupDictEnabled),
        child: Text(
          popupDictEnabled
              ? 'Disable popup dictionary'
              : 'Enable popup dictionary',
        ),
      ),
    ],
  );
}

/// Editable page number input with total page count.
class _PageInput extends StatefulWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onPageSubmitted;

  const _PageInput({
    required this.currentPage,
    required this.pageCount,
    required this.onPageSubmitted,
  });

  @override
  State<_PageInput> createState() => _PageInputState();
}

class _PageInputState extends State<_PageInput> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage.toString());
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        setState(() => _isEditing = false);
        _controller.text = widget.currentPage.toString();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _PageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.currentPage != oldWidget.currentPage) {
      _controller.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_controller.text);
    if (n != null && n > 0 && n <= widget.pageCount) {
      widget.onPageSubmitted(n);
    }
    setState(() => _isEditing = false);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall
        ?.copyWith(fontWeight: FontWeight.w600);

    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 26,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: textStyle,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(width: 4),
          Text('/ ${widget.pageCount}', style: textStyle),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        setState(() => _isEditing = true);
        _controller.text = widget.currentPage.toString();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _focusNode.requestFocus();
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '${widget.currentPage} / ${widget.pageCount}',
          style: textStyle,
        ),
      ),
    );
  }
}
