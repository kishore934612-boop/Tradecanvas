/// Long-press / Context menu modal sheet for Smart Analysis objects.
library;

import 'package:flutter/material.dart';

import 'package:app/analysis_tools/models/analysis_object.dart';
import 'package:app/analysis_tools/widgets/analysis_style_sheet.dart';
import 'package:app/constants/colors.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/utils/haptics.dart';

class AnalysisContextMenu extends StatelessWidget {
  final AnalysisObject object;
  final DrawingController controller;

  const AnalysisContextMenu({
    super.key,
    required this.object,
    required this.controller,
  });

  static Future<void> show(
    BuildContext context, {
    required AnalysisObject object,
    required DrawingController controller,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AnalysisContextMenu(
        object: object,
        controller: controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final meta = object.metadata;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.mutedForeground.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    meta.analysisType.iconSymbol,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meta.label,
                        style: TextStyle(
                          color: colors.foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        meta.analysisType.displayName,
                        style: TextStyle(
                          color: colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            _Item(
              icon: Icons.palette_outlined,
              label: 'Edit Style',
              onTap: () {
                Navigator.of(context).pop();
                AnalysisStyleSheet.show(context, object: object, controller: controller);
              },
              colors: colors,
            ),
            _Item(
              icon: Icons.note_alt_outlined,
              label: 'Notes',
              onTap: () => _editNotes(context),
              colors: colors,
            ),
            _Item(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              danger: true,
              onTap: () {
                Navigator.of(context).pop();
                Haptics.medium();
                controller.delete(object.id);
              },
              colors: colors,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }



  Future<void> _editNotes(BuildContext context) async {
    final colors = AppColors.of(context);
    final c = TextEditingController(text: object.metadata.notes ?? '');
    final newNotes = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Analysis Notes', style: TextStyle(color: colors.foreground, fontSize: 16)),
        content: TextField(
          controller: c,
          maxLines: 3,
          autofocus: true,
          style: TextStyle(color: colors.foreground),
          decoration: InputDecoration(
            hintText: 'Enter notes or trade thesis...',
            hintStyle: TextStyle(color: colors.mutedForeground),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
            child: Text('Save', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );

    if (newNotes != null && context.mounted) {
      Navigator.of(context).pop();
      Haptics.light();
      final updatedMeta = object.metadata.copyWith(notes: newNotes);
      final updatedDrawing = object.copyWith(metadata: updatedMeta).toDrawing();
      controller.updateDrawing(updatedDrawing);
    }
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemePalette colors;
  final bool danger;

  const _Item({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? colors.negative : colors.foreground;

    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
