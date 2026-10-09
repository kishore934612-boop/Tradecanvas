/// Bottom sheet modal for customizing a selected drawing shape.
library;

import 'dart:async';
import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/models/drawing.dart';
import 'package:app/utils/haptics.dart';

/// Available preset line colors for drawings.
const List<int> kPresetDrawingColors = [
  0xFFF59E0B, // Amber Gold
  0xFF38BDF8, // Sky Blue
  0xFF10B981, // Emerald Green
  0xFFEF4444, // Rose Red
  0xFFA855F7, // Purple
  0xFFFFFFFF, // White
  0xFF94A3B8, // Slate
];

class DrawingCustomizationSheet extends StatelessWidget {
  final Drawing drawing;
  final DrawingController controller;

  const DrawingCustomizationSheet({
    super.key,
    required this.drawing,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final currentColor = controller.colorValue > 0
        ? controller.colorValue
        : drawing.colorValue;
    final currentWidth = controller.strokeWidth;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tool Title & Trash Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${drawing.tool.label.length > 10 ? drawing.tool.shortLabel : drawing.tool.label} Customization',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Delete Drawing',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: colors.destructive,
                  size: 22,
                ),
                onPressed: () {
                  Haptics.medium();
                  controller.deleteSelected();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Color Selection
          Text(
            'Line Color',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final cValue in kPresetDrawingColors)
                InkWell(
                  onTap: () {
                    Haptics.selection();
                    controller.setColor(cValue);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(cValue),
                      border: Border.all(
                        color: currentColor == cValue
                            ? colors.foreground
                            : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: currentColor == cValue
                          ? [
                              BoxShadow(
                                color: Color(cValue).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: currentColor == cValue
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Color(cValue).computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Stroke Thickness Selection
          Text(
            'Line Thickness',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final widthOption in [1.0, 2.0, 3.5]) ...[
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Haptics.selection();
                      controller.setStrokeWidth(widthOption);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: (currentWidth - widthOption).abs() < 0.2
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.border.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (currentWidth - widthOption).abs() < 0.2
                              ? colors.primary
                              : colors.border.withValues(alpha: 0.4),
                          width: (currentWidth - widthOption).abs() < 0.2
                              ? 1.5
                              : 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: widthOption * 2,
                            decoration: BoxDecoration(
                              color: (currentWidth - widthOption).abs() < 0.2
                                  ? colors.primary
                                  : colors.foreground,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widthOption == 1.0
                                ? 'Thin'
                                : (widthOption == 2.0 ? 'Medium' : 'Thick'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  (currentWidth - widthOption).abs() < 0.2
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                              color: colors.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widthOption != 3.5) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Tool Specific Options
          if (drawing.tool == DrawingTool.trendline) ...[
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Ray Extension'),
                    selected: drawing.isRay,
                    onSelected: (v) {
                      Haptics.selection();
                      controller.updateDrawing(drawing.copyWith(isRay: v, isInfinite: false));
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    checkmarkColor: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilterChip(
                    label: const Text('Infinite Line'),
                    selected: drawing.isInfinite,
                    onSelected: (v) {
                      Haptics.selection();
                      controller.updateDrawing(drawing.copyWith(isInfinite: v, isRay: false));
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    checkmarkColor: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (drawing.tool == DrawingTool.text) ...[
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Background Card'),
                    selected: drawing.showBackground,
                    onSelected: (v) {
                      Haptics.selection();
                      controller.updateDrawing(drawing.copyWith(showBackground: v));
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    checkmarkColor: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilterChip(
                    label: const Text('Border'),
                    selected: drawing.showBorder,
                    onSelected: (v) {
                      Haptics.selection();
                      controller.updateDrawing(drawing.copyWith(showBorder: v));
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    checkmarkColor: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (drawing.tool == DrawingTool.flatTopBottom) ...[
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Dashed Line'),
                  selected: drawing.isDashed,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['isDashed'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
                FilterChip(
                  label: const Text('Infinite Line'),
                  selected: drawing.isInfinite,
                  onSelected: (v) {
                    Haptics.selection();
                    controller.updateDrawing(drawing.copyWith(isInfinite: v));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
                FilterChip(
                  label: const Text('Show Label'),
                  selected: drawing.showLabel,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['showLabel'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],


          if (drawing.tool == DrawingTool.parallelChannel) ...[
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Show Midline'),
                  selected: drawing.showMidline,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['showMidline'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
                FilterChip(
                  label: const Text('Dashed Border'),
                  selected: drawing.isDashed,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['isDashed'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fill Opacity',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final op in [0.0, 0.25, 0.50]) ...[
                  Expanded(
                    child: FilterChip(
                      label: Text(op == 0.0 ? 'Transparent' : '${(op * 100).toInt()}%'),
                      selected: (drawing.fillOpacity - op).abs() < 0.05,
                      onSelected: (_) {
                        Haptics.selection();
                        final props = Map<String, dynamic>.from(drawing.properties ?? {});
                        props['fillOpacity'] = op;
                        controller.updateDrawing(drawing.copyWith(properties: props));
                      },
                      selectedColor: colors.primary.withValues(alpha: 0.2),
                      checkmarkColor: colors.primary,
                    ),
                  ),
                  if (op != 0.50) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (drawing.tool == DrawingTool.fibExtension) ...[
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Dashed Levels'),
                  selected: drawing.isDashed,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['isDashed'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
                FilterChip(
                  label: const Text('Show Labels'),
                  selected: drawing.showLabel,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['showLabel'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],



          if (drawing.tool == DrawingTool.callout) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: Text(drawing.text ?? 'Edit Note'),
              onPressed: () async {
                final newText = await _showTextEditDialog(context, drawing.text ?? '');
                if (newText != null && newText.isNotEmpty) {
                  unawaited(controller.updateText(drawing.id, newText));
                }
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Box Opacity',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final op in [0.30, 0.60, 0.90]) ...[
                  Expanded(
                    child: FilterChip(
                      label: Text('${(op * 100).toInt()}%'),
                      selected: (drawing.fillOpacity - op).abs() < 0.1,
                      onSelected: (_) {
                        Haptics.selection();
                        final props = Map<String, dynamic>.from(drawing.properties ?? {});
                        props['fillOpacity'] = op;
                        controller.updateDrawing(drawing.copyWith(properties: props));
                      },
                      selectedColor: colors.primary.withValues(alpha: 0.2),
                      checkmarkColor: colors.primary,
                    ),
                  ),
                  if (op != 0.90) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (drawing.tool == DrawingTool.htfOverlay) ...[
            Text(
              'Level Type',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in ['PDH', 'PDL', 'PWH', 'PWL', 'DOpen']) ...[
                  FilterChip(
                    label: Text(type),
                    selected: drawing.htfLevelType == type,
                    onSelected: (_) {
                      Haptics.selection();
                      final props = Map<String, dynamic>.from(drawing.properties ?? {});
                      props['htfLevelType'] = type;
                      controller.updateDrawing(drawing.copyWith(properties: props));
                    },
                    selectedColor: colors.primary.withValues(alpha: 0.2),
                    checkmarkColor: colors.primary,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (drawing.tool == DrawingTool.triangle) ...[
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('Dashed Border'),
                  selected: drawing.isDashed,
                  onSelected: (v) {
                    Haptics.selection();
                    final props = Map<String, dynamic>.from(drawing.properties ?? {});
                    props['isDashed'] = v;
                    controller.updateDrawing(drawing.copyWith(properties: props));
                  },
                  selectedColor: colors.primary.withValues(alpha: 0.2),
                  checkmarkColor: colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fill Opacity',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final op in [0.0, 0.25, 0.50]) ...[
                  Expanded(
                    child: FilterChip(
                      label: Text(op == 0.0 ? 'Transparent' : '${(op * 100).toInt()}%'),
                      selected: (drawing.fillOpacity - op).abs() < 0.05,
                      onSelected: (_) {
                        Haptics.selection();
                        final props = Map<String, dynamic>.from(drawing.properties ?? {});
                        props['fillOpacity'] = op;
                        controller.updateDrawing(drawing.copyWith(properties: props));
                      },
                      selectedColor: colors.primary.withValues(alpha: 0.2),
                      checkmarkColor: colors.primary,
                    ),
                  ),
                  if (op != 0.50) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Done Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showTextEditDialog(BuildContext context, String initialText) async {
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter text note...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
