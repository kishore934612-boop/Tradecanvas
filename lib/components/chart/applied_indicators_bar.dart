/// Applied Indicators Legend Overlay Bar on Chart.
///
/// Displays active applied indicators (EMA, RSI, MACD, BB, SuperTrend, etc.) as
/// interactive chips at the top-left of the chart surface.
/// Tapping an applied indicator chip opens a customization tray for that indicator.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/indicator_style.dart';
import 'package:app/utils/haptics.dart';

class AppliedIndicatorsBar extends StatelessWidget {
  final Set<IndicatorType> enabledIndicators;
  final Map<IndicatorType, IndicatorStyle>? indicatorStyles;
  final ValueChanged<IndicatorType> onTapIndicator;
  final ValueChanged<IndicatorType>? onRemoveIndicator;

  const AppliedIndicatorsBar({
    super.key,
    required this.enabledIndicators,
    this.indicatorStyles,
    required this.onTapIndicator,
    this.onRemoveIndicator,
  });

  @override
  Widget build(BuildContext context) {
    if (enabledIndicators.isEmpty) return const SizedBox.shrink();

    final colors = AppColors.of(context);
    final sortedIndicators = enabledIndicators.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Container(
      margin: const EdgeInsets.only(left: 8, top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: sortedIndicators.map((type) {
            final style = indicatorStyles?[type] ?? IndicatorStyle.defaultStyle(type);
            final indicatorColor = style.color;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Haptics.selection();
                    onTapIndicator(type);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.card.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: indicatorColor.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Color Pill Indicator
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: indicatorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.tune_rounded,
                          size: 13,
                          color: colors.mutedForeground,
                        ),
                        if (onRemoveIndicator != null) ...[
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () {
                              Haptics.light();
                              onRemoveIndicator!(type);
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
