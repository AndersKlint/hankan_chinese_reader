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
  final bool showOcrProgress;

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
    this.showOcrProgress = false,
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
      child: LayoutBuilder(builder: (context, constraints) {
        const double minDesktopWidth = 380;
        if (constraints.maxWidth >= minDesktopWidth) {
          return _buildDesktopToolbar(context);
        }
        return _buildMobileToolbar(context);
      }),
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

        const Spacer(),

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
    return _buildMobileNormalBar(context);
  }

  Widget _buildMobileNormalBar(BuildContext context) {
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
          tooltip: 'Search in document',
          onPressed: textSearcher != null ? onActivateSearch : null,
          visualDensity: VisualDensity.compact,
        ),

        const VerticalDivider(width: 1, indent: 8, endIndent: 8),

        IconButton(
          icon: const Icon(Icons.remove, size: 18),
          tooltip: 'Zoom out',
          onPressed: canZoom ? onZoomOut : null,
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.add, size: 18),
          tooltip: 'Zoom in',
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

        const Spacer(),

        _PageInput(
          currentPage: currentPage,
          pageCount: pageCount,
          onPageSubmitted: onPageSubmitted,
        ),

        const SizedBox(width: 6),
      ],
    );
  }

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
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600);

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
