import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/indicator_style.dart';
import 'package:app/utils/haptics.dart';

class IndicatorStyleSheet extends StatefulWidget {
  final IndicatorType type;
  final IndicatorStyle currentStyle;
  final ValueChanged<IndicatorStyle> onChanged;

  const IndicatorStyleSheet({
    super.key,
    required this.type,
    required this.currentStyle,
    required this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required IndicatorType type,
    required IndicatorStyle currentStyle,
    required ValueChanged<IndicatorStyle> onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IndicatorStyleSheet(
        type: type,
        currentStyle: currentStyle,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<IndicatorStyleSheet> createState() => _IndicatorStyleSheetState();
}

class _IndicatorStyleSheetState extends State<IndicatorStyleSheet> {
  late int _selectedColor;
  late double _strokeWidth;

  static const List<int> _palette = [
    0xFFF59E0B, // Amber
    0xFF38BDF8, // Sky Blue
    0xFFA78BFA, // Purple
    0xFF10B981, // Emerald
    0xFFFFD700, // Gold
    0xFF34D399, // Mint
    0xFFFF7096, // Rose
    0xFFC77DFF, // Violet
    0xFF22D3EE, // Cyan
    0xFFEF4444, // Red
    0xFFFFFFFF, // White
    0xFF6366F1, // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentStyle.colorValue;
    _strokeWidth = widget.currentStyle.strokeWidth;
  }

  void _update() {
    final style = IndicatorStyle(
      colorValue: _selectedColor,
      strokeWidth: _strokeWidth,
    );
    widget.onChanged(style);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.mutedForeground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header: Title & Reset Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customize ${widget.type.label}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Adjust line color and boldness',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  Haptics.selection();
                  final def = IndicatorStyle.defaultStyle(widget.type);
                  setState(() {
                    _selectedColor = def.colorValue;
                    _strokeWidth = def.strokeWidth;
                  });
                  _update();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Live Preview Line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 20),
                    painter: _LinePreviewPainter(
                      color: Color(_selectedColor),
                      strokeWidth: _strokeWidth,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_strokeWidth.toStringAsFixed(1)}px',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Color Palette Swatches
          Text(
            'Line Color',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _palette.map((colorHex) {
              final isSelected = _selectedColor == colorHex;
              final color = Color(colorHex);
              return GestureDetector(
                onTap: () {
                  Haptics.selection();
                  setState(() => _selectedColor = colorHex);
                  _update();
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: isSelected ? 3 : 0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: isSelected ? 8 : 2,
                        spreadRadius: isSelected ? 1 : 0,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Line Boldness / Thickness Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line Boldness',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              Text(
                '${_strokeWidth.toStringAsFixed(1)} px',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.border,
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _strokeWidth,
              min: 1.0,
              max: 5.0,
              divisions: 8, // 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0
              label: '${_strokeWidth.toStringAsFixed(1)} px',
              onChanged: (val) {
                setState(() => _strokeWidth = val);
                _update();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePreviewPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _LinePreviewPainter({
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()
      ..moveTo(0, y)
      ..cubicTo(size.width * 0.25, y - 8, size.width * 0.75, y + 8, size.width, y);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePreviewPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
