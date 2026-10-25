import 'package:flutter/material.dart';

import '../services/pdf_highlight_color_service.dart';

class PdfHighlightPaletteResult {
  final Color? color;

  const PdfHighlightPaletteResult(this.color);
}

class PdfHighlightPalette extends StatefulWidget {
  final PdfHighlightColorService colors;
  final Color? initialColor;

  const PdfHighlightPalette({
    super.key,
    required this.colors,
    required this.initialColor,
  });

  @override
  State<PdfHighlightPalette> createState() => _PdfHighlightPaletteState();
}

class _PdfHighlightPaletteState extends State<PdfHighlightPalette> {
  late Color? _color = widget.initialColor;
  late final TextEditingController _hex = TextEditingController(
    text: _hexValue,
  );
  String? _error;

  String get _hexValue => _color == null
      ? ''
      : (_color!.toARGB32() & 0xffffff)
            .toRadixString(16)
            .padLeft(6, '0')
            .toUpperCase();

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _select(Color? color) {
    setState(() {
      _color = color;
      _hex.text = _hexValue;
      _error = null;
    });
  }

  Widget _swatches(List<Color?> colors) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: colors
        .map(
          (color) => Tooltip(
            message: color == null
                ? 'None'
                : '#${(color.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}',
            child: InkWell(
              onTap: () => _select(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color == _color
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: color == _color ? 3 : 1,
                  ),
                ),
                child: color == null
                    ? const Icon(Icons.format_color_reset, size: 22)
                    : null,
              ),
            ),
          ),
        )
        .toList(),
  );

  Widget _slider(String label, int shift) {
    final color = _color;
    final channel = ((color?.toARGB32() ?? 0xff000000) >> shift) & 255;
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Expanded(
          child: Slider(
            value: channel.toDouble(),
            max: 255,
            divisions: 255,
            onChanged: color == null
                ? null
                : (value) {
                    final rgb = color.toARGB32() & ~(255 << shift);
                    _select(Color(rgb | (value.round() << shift)));
                  },
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('$channel', style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Highlight color'),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: ListenableBuilder(
          listenable: widget.colors,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _swatches([...widget.colors.presetColors, null]),
              if (widget.colors.recentColors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Recent', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                _swatches(widget.colors.recentColors),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _hex,
                decoration: InputDecoration(
                  labelText: 'Hex color',
                  prefixText: '#',
                  errorText: _error,
                  suffixIcon: Icon(Icons.circle, color: _color),
                ),
                onChanged: (value) {
                  final text = value.replaceFirst('#', '');
                  final rgb = RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)
                      ? int.tryParse(text, radix: 16)
                      : null;
                  setState(() {
                    _error = rgb == null ? 'Enter six hex digits' : null;
                    if (rgb != null) _color = Color(0xff000000 | rgb);
                  });
                },
              ),
              _slider('R', 16),
              _slider('G', 8),
              _slider('B', 0),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _error == null
            ? () => Navigator.pop(context, PdfHighlightPaletteResult(_color))
            : null,
        child: const Text('Use'),
      ),
    ],
  );
}
