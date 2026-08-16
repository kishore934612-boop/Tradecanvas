/// Indicator selection sheet — toggle EMA, SMA, RSI, Volume, MACD, VWAP, Bollinger Bands, ATR, Stoch RSI, SuperTrend.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/utils/haptics.dart';

class IndicatorSheet extends StatelessWidget {
  final Set<IndicatorType> enabled;
  final ValueChanged<IndicatorType> onToggle;

  const IndicatorSheet({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Technical Indicators',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: colors.mutedForeground, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: IndicatorType.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final type = IndicatorType.values[index];
                final active = enabled.contains(type);
                final color = Color(type.colorValue);

                return InkWell(
                  onTap: () {
                    Haptics.selection();
                    onToggle(type);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? color.withValues(alpha: 0.12)
                          : colors.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? color
                            : colors.border.withValues(alpha: 0.4),
                        width: active ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            type.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.border.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            type.isSubPanel ? 'Sub-Panel' : 'Overlay',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                        if (!active)
                          Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                            color: colors.mutedForeground,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
