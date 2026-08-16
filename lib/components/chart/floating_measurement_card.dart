/// Floating measurement card — modern overlay displaying computed measurement
/// statistics when a measurement drawing is selected or being placed.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/measurement_calculator.dart';

class FloatingMeasurementCard extends StatelessWidget {
  final MeasurementStats stats;
  final String Function(double) formatPrice;

  const FloatingMeasurementCard({
    super.key,
    required this.stats,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = stats.priceChange >= 0;
    final accent = up ? colors.positive : colors.negative;
    final sign = up ? '+' : '';

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 14, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'Measurement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Price change hero.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Price Change',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$sign${stats.percentChange.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  '$sign${formatPrice(stats.absoluteChange)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.8),
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Metrics grid.
          _MetricRow(
            label: 'Duration',
            value: MeasurementCalculator.formatDuration(stats.duration),
            colors: colors,
          ),
          _MetricRow(
            label: 'Candles',
            value: '${stats.candleCount}',
            colors: colors,
          ),
          _MetricRow(
            label: 'Highest',
            value: formatPrice(stats.highestPrice),
            colors: colors,
            valueColor: colors.positive,
          ),
          _MetricRow(
            label: 'Lowest',
            value: formatPrice(stats.lowestPrice),
            colors: colors,
            valueColor: colors.negative,
          ),
          _divider(colors),
          _MetricRow(
            label: 'Avg Volume',
            value: MeasurementCalculator.formatVolume(stats.averageVolume),
            colors: colors,
          ),
          _MetricRow(
            label: 'High Volume',
            value: MeasurementCalculator.formatVolume(stats.highestVolume),
            colors: colors,
          ),
          _MetricRow(
            label: 'Low Volume',
            value: MeasurementCalculator.formatVolume(stats.lowestVolume),
            colors: colors,
          ),
          _divider(colors),
          _MetricRow(
            label: 'Avg Range',
            value: '${stats.averageCandleRangePercent.toStringAsFixed(2)}%',
            colors: colors,
          ),
          _MetricRow(
            label: 'ATR Multiple',
            value: '${stats.atrMultiple.toStringAsFixed(1)}x',
            colors: colors,
          ),
          _MetricRow(
            label: 'Max Drawdown',
            value: '-${stats.maxDrawdownPercent.toStringAsFixed(2)}%',
            colors: colors,
            valueColor: colors.negative,
          ),
          _MetricRow(
            label: 'Max Run-up',
            value: '+${stats.maxRunupPercent.toStringAsFixed(2)}%',
            colors: colors,
            valueColor: colors.positive,
          ),
          if (stats.riskRewardRatio != null)
            _MetricRow(
              label: 'R:R Ratio',
              value: '1:${stats.riskRewardRatio!.toStringAsFixed(2)}',
              colors: colors,
            ),
        ],
      ),
    );
  }

  static Widget _divider(ThemePalette colors) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 1, color: colors.border.withValues(alpha: 0.4)),
      );
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette colors;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.mutedForeground,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: valueColor ?? colors.foreground,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
