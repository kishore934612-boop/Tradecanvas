/// Quick Action Toolbar — floating, user-configurable shortcuts to the top 3
/// favorite drawing tools.
///
/// Sits over the chart (not in the scroll/gesture area) so a tool is one tap
/// away without opening the full drawing toolbar's tool picker. Long-press
/// any slot, or tap "Customize", to reassign it via [FavoriteToolsSheet].
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/models/drawing.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/utils/haptics.dart';

const Map<DrawingTool, IconData> kDrawingToolIcons = {
  DrawingTool.trendline: Icons.show_chart_rounded,
  DrawingTool.arrow: Icons.north_east_rounded,
  DrawingTool.horizontalLine: Icons.horizontal_rule_rounded,
  DrawingTool.verticalLine: Icons.more_vert_rounded,
  DrawingTool.rectangle: Icons.crop_square_rounded,
  DrawingTool.fibRetracement: Icons.format_line_spacing_rounded,
  DrawingTool.text: Icons.title_rounded,
  DrawingTool.measurement: Icons.straighten_rounded,
  DrawingTool.triangle: Icons.change_history_rounded,
  DrawingTool.fibExtension: Icons.timeline_rounded,
  DrawingTool.brush: Icons.brush_rounded,
  DrawingTool.callout: Icons.mark_chat_read_rounded,
};

class QuickActionToolbar extends StatelessWidget {
  final DrawingController drawings;
  final AppState appState;

  const QuickActionToolbar({
    super.key,
    required this.drawings,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final favorites = appState.profile.favoriteDrawingTools
        .map(DrawingTool.fromId)
        .toList();

    return AnimatedBuilder(
      animation: drawings,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: colors.card.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tool in favorites) ...[
                _QuickButton(
                  tool: tool,
                  active: drawings.activeTool == tool,
                  onTap: () {
                    Haptics.selection();
                    drawings.setActiveTool(tool);
                  },
                  onLongPress: () => _customize(context),
                  colors: colors,
                ),
                const SizedBox(width: 2),
              ],
              _QuickIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Customize quick actions',
                onTap: () => _customize(context),
                colors: colors,
              ),
            ],
          ),
        );
      },
    );
  }

  void _customize(BuildContext context) {
    Haptics.light();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FavoriteToolsSheet(appState: appState),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final DrawingTool tool;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ThemePalette colors;

  const _QuickButton({
    required this.tool,
    required this.active,
    required this.onTap,
    required this.onLongPress,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${tool.label} (long-press to customize)',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? colors.primary.withValues(alpha: 0.18) : null,
          ),
          child: Icon(
            kDrawingToolIcons[tool] ?? Icons.edit_rounded,
            size: 19,
            color: active ? colors.primary : colors.foreground,
          ),
        ),
      ),
    );
  }
}

class _QuickIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ThemePalette colors;

  const _QuickIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: colors.mutedForeground),
        ),
      ),
    );
  }
}

// ============================================================
// CUSTOMIZE SHEET
// ============================================================

/// Bottom sheet letting the user pick up to 3 tools, in order, for the quick
/// action toolbar. Tapping a tool toggles membership; order follows tap order.
class FavoriteToolsSheet extends StatefulWidget {
  final AppState appState;

  const FavoriteToolsSheet({super.key, required this.appState});

  @override
  State<FavoriteToolsSheet> createState() => _FavoriteToolsSheetState();
}

class _FavoriteToolsSheetState extends State<FavoriteToolsSheet> {
  late List<DrawingTool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.appState.profile.favoriteDrawingTools
        .map(DrawingTool.fromId)
        .toList();
  }

  void _toggle(DrawingTool tool) {
    Haptics.selection();
    setState(() {
      if (_selected.contains(tool)) {
        _selected.remove(tool);
      } else if (_selected.length < 3) {
        _selected.add(tool);
      }
    });
  }

  void _save() {
    widget.appState.setFavoriteDrawingTools(_selected.map((t) => t.name).toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  'Quick actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selected.length}/3 selected',
                  style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              'Pick up to 3 tools for one-tap access on the chart.',
              style: TextStyle(fontSize: 12, color: colors.mutedForeground),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tool in DrawingTool.values)
                  _pickTile(tool, colors),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selected.isEmpty ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _pickTile(DrawingTool tool, ThemePalette colors) {
    final selected = _selected.contains(tool);
    final order = selected ? _selected.indexOf(tool) + 1 : null;

    return InkWell(
      onTap: () => _toggle(tool),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? colors.primary.withValues(alpha: 0.12) : colors.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.primary : colors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  kDrawingToolIcons[tool] ?? Icons.edit_rounded,
                  size: 22,
                  color: selected ? colors.primary : colors.mutedForeground,
                ),
                if (order != null)
                  Positioned(
                    right: -10,
                    top: -6,
                    child: Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.primary,
                      ),
                      child: Text(
                        '$order',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: colors.brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tool.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: selected ? colors.primary : colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
