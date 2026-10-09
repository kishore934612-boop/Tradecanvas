/// Shared chart toolbar: timeframe chips + style/indicator/session/object manager/fullscreen actions.
///
/// Used by both the full Chart tab and the Dashboard's embedded chart panel so
/// the two stay visually and behaviourally identical.
library;

import 'package:flutter/material.dart';

import 'package:app/components/chart/chart_painter.dart' show ChartStyle;
import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';

class ChartToolbar extends StatelessWidget {
  final Timeframe timeframe;
  final ValueChanged<Timeframe> onTimeframe;
  final ChartStyle style;
  final VoidCallback onToggleStyle;
  final VoidCallback onIndicators;
  final bool hasActiveIndicators;
  final VoidCallback? onStrategies;
  final bool hasActiveStrategies;
  final VoidCallback? onSmc;
  final bool hasActiveSmc;
  final VoidCallback? onObjectManager;

  /// Null hides the fullscreen button entirely.
  final VoidCallback? onToggleFullscreen;
  final bool fullscreen;

  const ChartToolbar({
    super.key,
    required this.timeframe,
    required this.onTimeframe,
    required this.style,
    required this.onToggleStyle,
    required this.onIndicators,
    this.hasActiveIndicators = false,
    this.onStrategies,
    this.hasActiveStrategies = false,
    this.onSmc,
    this.hasActiveSmc = false,
    this.onObjectManager,
    this.onToggleFullscreen,
    this.fullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              children: [
                for (final tf in Timeframe.values) ...[
                  TimeframeChip(
                    label: tf.label,
                    active: tf == timeframe,
                    onTap: () => onTimeframe(tf),
                  ),
                  const SizedBox(width: 5),
                ],
              ],
            ),
          ),

          ToolbarIconButton(
            icon: Icons.stacked_line_chart_rounded,
            tooltip: 'Indicators & Overlays',
            onTap: onIndicators,
            active: hasActiveIndicators || hasActiveStrategies || hasActiveSmc,
          ),
          if (onToggleFullscreen != null)
            ToolbarIconButton(
              icon: fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
              tooltip: fullscreen ? 'Exit fullscreen' : 'Fullscreen',
              onTap: onToggleFullscreen!,
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class TimeframeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const TimeframeChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? colors.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: active ? colors.primary : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      constraints: const BoxConstraints(minWidth: 34),
      icon: Icon(
        icon,
        size: 19,
        color: active ? colors.primary : colors.mutedForeground,
      ),
      onPressed: onTap,
    );
  }
}
