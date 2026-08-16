/// Drawing toolbar — tool palette, colour picker and edit actions.
///
/// Collapsed to a single button until the user opens it, so it costs almost no
/// vertical space on a phone.
library;

import 'package:flutter/material.dart';

import 'package:app/components/chart/quick_action_toolbar.dart' show kDrawingToolIcons;
import 'package:app/constants/colors.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/magnetic_snap.dart';
import 'package:app/models/drawing.dart';
import 'package:app/utils/haptics.dart';

class DrawingToolbar extends StatefulWidget {
  final DrawingController controller;

  const DrawingToolbar({super.key, required this.controller});

  @override
  State<DrawingToolbar> createState() => _DrawingToolbarState();
}

class _DrawingToolbarState extends State<DrawingToolbar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;

        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            border: Border(
              top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_expanded) _tools(c, colors),
              if (_expanded && c.selected != null) _colorRow(c, colors),
              _mainRow(c, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _mainRow(DrawingController c, ThemePalette colors) {
    final selected = c.selected;

    return SizedBox(
      height: 46,
      child: Row(
        children: [
          const SizedBox(width: 6),
          _Action(
            icon: _expanded
                ? Icons.keyboard_arrow_down_rounded
                : Icons.edit_outlined,
            label: _expanded ? 'Close' : 'Draw',
            active: c.isDrawing,
            onTap: () {
              Haptics.selection();
              setState(() => _expanded = !_expanded);
              if (_expanded == false) c.setActiveTool(null);
            },
            colors: colors,
          ),

          const Spacer(),

          // Magnetic mode toggle.
          _Action(
            icon: Icons.gps_fixed_rounded,
            label: c.magneticMode == MagneticMode.off
                ? 'Magnet'
                : c.magneticMode.label,
            active: c.magneticMode != MagneticMode.off,
            onTap: () {
              Haptics.selection();
              c.cycleMagneticMode();
            },
            colors: colors,
          ),

          if (c.isDrawing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _hintFor(c.activeTool!),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          if (selected != null) ...[
            if (selected.tool == DrawingTool.text)
              _Action(
                icon: Icons.edit_note_rounded,
                label: 'Edit Text',
                onTap: () => _editText(c, selected),
                colors: colors,
              ),
            _Action(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () {
                Haptics.medium();
                c.deleteSelected();
              },
              colors: colors,
              danger: true,
            ),
          ],

          if (c.canUndo)
            _Action(
              icon: Icons.undo_rounded,
              label: 'Undo',
              tooltip: c.undoDescription,
              onTap: () {
                Haptics.light();
                c.undo();
              },
              colors: colors,
            ),

          if (c.canRedo)
            _Action(
              icon: Icons.redo_rounded,
              label: 'Redo',
              tooltip: c.redoDescription,
              onTap: () {
                Haptics.light();
                c.redo();
              },
              colors: colors,
            ),

          if (c.hasDrawings)
            _Action(
              icon: Icons.layers_clear_rounded,
              label: 'Clear',
              onTap: () => _confirmClear(c),
              colors: colors,
            ),

          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _tools(DrawingController c, ThemePalette colors) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (final tool in DrawingTool.values) ...[
            _ToolButton(
              icon: kDrawingToolIcons[tool]!,
              label: tool.label,
              active: c.activeTool == tool,
              onTap: () {
                Haptics.selection();
                c.setActiveTool(tool);
              },
              colors: colors,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _colorRow(DrawingController c, ThemePalette colors) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          for (final argb in kDrawingColors) ...[
            InkWell(
              onTap: () {
                Haptics.light();
                c.setColor(argb);
              },
              customBorder: const CircleBorder(),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Color(argb),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c.selected?.colorValue == argb
                        ? colors.foreground
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          // Stroke width steps, coarse on purpose — fine control is fiddly here.
          for (final w in const [1.0, 1.5, 2.5]) ...[
            InkWell(
              onTap: () {
                Haptics.light();
                c.setStrokeWidth(w);
              },
              child: Container(
                width: 28,
                height: 24,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: c.selected?.strokeWidth == w
                        ? colors.primary
                        : colors.border,
                  ),
                ),
                child: Container(
                  width: 14,
                  height: w,
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _hintFor(DrawingTool tool) {
    return tool.anchorCount == 1
        ? 'Tap to place ${tool.label.toLowerCase()}'
        : 'Drag to draw ${tool.label.toLowerCase()}';
  }

  Future<void> _editText(DrawingController c, Drawing d) async {
    final colors = AppColors.of(context);
    final controller = TextEditingController(text: d.text ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Edit Text',
            style: TextStyle(color: colors.foreground, fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: colors.foreground),
          decoration: InputDecoration(
            hintText: 'Enter chart note text...',
            hintStyle: TextStyle(color: colors.mutedForeground),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Save', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
    if (newText != null && newText.isNotEmpty) {
      Haptics.light();
      await c.updateText(d.id, newText);
    }
  }

  Future<void> _confirmClear(DrawingController c) async {
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        title: Text('Clear drawings?',
            style: TextStyle(color: colors.foreground, fontSize: 16)),
        content: Text(
          'This removes every drawing on ${c.symbol}. You can undo it afterwards.',
          style: TextStyle(color: colors.mutedForeground, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Clear', style: TextStyle(color: colors.negative)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Haptics.medium();
      await c.clearSymbol();
    }
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final ThemePalette colors;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.primary.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? colors.primary : colors.border,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? colors.primary : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  final ThemePalette colors;
  final String? tooltip;

  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colors,
    this.active = false,
    this.danger = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? colors.negative
        : active
            ? colors.primary
            : colors.mutedForeground;

    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip == null) return content;
    return Tooltip(message: tooltip!, child: content);
  }
}
