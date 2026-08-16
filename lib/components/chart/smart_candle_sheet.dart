/// Smart Candle Statistics — modern bottom sheet displaying detailed analytics
/// for a single candle, with a visual candle preview at the top.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/engine/candle_analytics.dart';
import 'package:app/engine/candle_story.dart';
import 'package:app/engine/measurement_calculator.dart';

class SmartCandleSheet extends StatelessWidget {
  final CandleAnalytics analytics;
  final CandleStory story;
  final String Function(double) formatPrice;

  const SmartCandleSheet({
    super.key,
    required this.analytics,
    required this.story,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final a = analytics;
    final up = a.isBullish;
    final accent = up ? colors.positive : colors.negative;
    final sign = a.priceChange >= 0 ? '+' : '';

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: colors.border),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Title row.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  'Candle Statistics',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    up ? 'Bullish' : 'Bearish',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Date.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatDate(a.date),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Visual candle preview.
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: _CandlePreviewPainter(
                open: a.open,
                high: a.high,
                low: a.low,
                close: a.close,
                isBullish: up,
                bullishColor: colors.positive,
                bearishColor: colors.negative,
                bgColor: colors.muted,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Scrollable metrics.
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  // OHLCV.
                  _SectionHeader(label: 'Price', colors: colors),
                  _Grid(children: [
                    _Cell(label: 'Open', value: formatPrice(a.open), colors: colors),
                    _Cell(label: 'High', value: formatPrice(a.high), colors: colors, valueColor: colors.positive),
                    _Cell(label: 'Low', value: formatPrice(a.low), colors: colors, valueColor: colors.negative),
                    _Cell(label: 'Close', value: formatPrice(a.close), colors: colors),
                    _Cell(label: 'Volume', value: MeasurementCalculator.formatVolume(a.volume), colors: colors),
                    _Cell(label: 'Change', value: '$sign${a.percentChange.toStringAsFixed(2)}%', colors: colors, valueColor: accent),
                  ]),
                  // Detected Patterns.
                  _SectionHeader(label: 'Detected Patterns', colors: colors),
                  if (a.detectedPatterns.isNotEmpty)
                    Column(
                      children: [
                        for (final p in a.detectedPatterns)
                          _PatternCard(pattern: p, colors: colors),
                      ],
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: colors.muted.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No specific single/multi-candle reversal pattern detected for this bar.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.mutedForeground,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Anatomy.
                  _SectionHeader(label: 'Candle Anatomy', colors: colors),
                  _Grid(children: [
                    _Cell(label: 'Body Size', value: formatPrice(a.bodySize), colors: colors),
                    _Cell(label: 'Upper Wick', value: formatPrice(a.upperWick), colors: colors),
                    _Cell(label: 'Lower Wick', value: formatPrice(a.lowerWick), colors: colors),
                    _Cell(label: 'Total Range', value: formatPrice(a.totalRange), colors: colors),
                    _Cell(label: 'Body %', value: '${a.bodyPercent.toStringAsFixed(1)}%', colors: colors),
                    _Cell(label: 'Upper Wick %', value: '${a.upperWickPercent.toStringAsFixed(1)}%', colors: colors),
                    _Cell(label: 'Lower Wick %', value: '${a.lowerWickPercent.toStringAsFixed(1)}%', colors: colors),
                    _Cell(label: 'Range %', value: '${a.rangePercent.toStringAsFixed(2)}%', colors: colors),
                  ]),
                  const SizedBox(height: 10),

                  // Context.
                  _SectionHeader(label: 'Context', colors: colors),
                  _Grid(children: [
                    _Cell(label: 'Close Position', value: '${a.closePosition.toStringAsFixed(0)}%', colors: colors),
                    _Cell(label: 'Vol vs Avg', value: '${a.volumeVsAverage.toStringAsFixed(2)}x', colors: colors,
                      valueColor: a.volumeVsAverage > 1.5 ? colors.positive : null),
                    _Cell(label: 'ATR Ratio', value: '${a.atrRatio.toStringAsFixed(2)}x', colors: colors,
                      valueColor: a.atrRatio > 1.5 ? colors.primary : null),
                    _Cell(label: 'Gap', value: formatPrice(a.gapFromPrevious.abs()), colors: colors),
                  ]),
                  const SizedBox(height: 10),

                  // Candle Story.
                  _CandleStorySection(
                    story: analytics.isBullish ? story : story,
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

// ============================================================
// CANDLE PREVIEW PAINTER
// ============================================================

class _CandlePreviewPainter extends CustomPainter {
  final double open, high, low, close;
  final bool isBullish;
  final Color bullishColor, bearishColor, bgColor;

  _CandlePreviewPainter({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.isBullish,
    required this.bullishColor,
    required this.bearishColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color = isBullish ? bullishColor : bearishColor;
    final range = high - low;
    if (range <= 0) return;

    final cx = size.width / 2;
    const topPad = 8.0;
    const botPad = 8.0;
    final availH = size.height - topPad - botPad;

    double yForPrice(double p) =>
        topPad + (1.0 - (p - low) / range) * availH;

    // Wick.
    canvas.drawLine(
      Offset(cx, yForPrice(high)),
      Offset(cx, yForPrice(low)),
      Paint()
        ..color = color
        ..strokeWidth = 2.0,
    );

    // Body.
    final bodyTop = math.min(yForPrice(open), yForPrice(close));
    final bodyBot = math.max(yForPrice(open), yForPrice(close));
    final bodyH = math.max(2.0, bodyBot - bodyTop);
    const bodyW = 28.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - bodyW / 2, bodyTop, bodyW, bodyH),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );

    // Price labels.
    final labelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      color: color.withValues(alpha: 0.7),
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );

    // High label.
    _drawLabel(canvas, 'H', cx + bodyW / 2 + 6, yForPrice(high), labelStyle);
    // Low label.
    _drawLabel(canvas, 'L', cx + bodyW / 2 + 6, yForPrice(low), labelStyle);
  }

  void _drawLabel(
      Canvas canvas, String text, double x, double y, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _CandlePreviewPainter old) =>
      old.open != open ||
      old.high != high ||
      old.low != low ||
      old.close != close;
}

// ============================================================
// SMALL WIDGETS
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemePalette colors;

  const _SectionHeader({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: colors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Widget> children;

  const _Grid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: children,
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette colors;
  final Color? valueColor;

  const _Cell({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
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

class _CandleStorySection extends StatelessWidget {
  final CandleStory story;
  final ThemePalette colors;

  const _CandleStorySection({
    required this.story,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final directionColor = switch (story.direction) {
      'bullish' => colors.positive,
      'bearish' => colors.negative,
      _ => const Color(0xFFEAB308),
    };
    final directionIcon = switch (story.direction) {
      'bullish' => '🟢',
      'bearish' => '🔴',
      _ => '🟡',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header.
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Text('🕯️ ', style: TextStyle(fontSize: 13)),
              Text(
                'Candle Story',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        // Story card.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: directionColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: directionColor.withValues(alpha: 0.20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headline.
              Text(
                '$directionIcon  ${story.headline}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: directionColor,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),

              // Narrative.
              Text(
                story.narrative,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.foreground.withValues(alpha: 0.85),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Metadata chips.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetadataChip(
              label: 'Character',
              value: story.character.label,
              colors: colors,
            ),
            _MetadataChip(
              label: 'Momentum',
              value: story.momentum.label,
              valueColor: story.momentum == MomentumLevel.strong
                  ? colors.positive
                  : story.momentum == MomentumLevel.weak
                      ? colors.negative
                      : null,
              colors: colors,
            ),
            if (story.upperRejection != RejectionLevel.none)
              _MetadataChip(
                label: 'Upper Rejection',
                value: story.upperRejection.label,
                valueColor: colors.negative,
                colors: colors,
              ),
            if (story.lowerRejection != RejectionLevel.none)
              _MetadataChip(
                label: 'Lower Rejection',
                value: story.lowerRejection.label,
                valueColor: colors.positive,
                colors: colors,
              ),
            _MetadataChip(
              label: 'Volume',
              value: story.volumeContext.label,
              valueColor: story.volumeContext == VolumeContext.veryHigh ||
                      story.volumeContext == VolumeContext.high
                  ? colors.primary
                  : null,
              colors: colors,
            ),
            if (story.trendContext != TrendContext.unknown)
              _MetadataChip(
                label: 'Context',
                value: story.trendContext.label,
                colors: colors,
              ),
          ],
        ),
      ],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final ThemePalette colors;

  const _MetadataChip({
    required this.label,
    required this.value,
    required this.colors,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  final CandlePattern pattern;
  final ThemePalette colors;

  const _PatternCard({required this.pattern, required this.colors});

  @override
  Widget build(BuildContext context) {
    Color tagColor;
    String tagLabel;

    switch (pattern.sentiment) {
      case PatternSentiment.bullish:
        tagColor = colors.positive;
        tagLabel = 'Bullish';
        break;
      case PatternSentiment.bearish:
        tagColor = colors.negative;
        tagLabel = 'Bearish';
        break;
      case PatternSentiment.neutral:
        tagColor = const Color(0xFFEAB308);
        tagLabel = 'Neutral';
        break;
    }

    final rel = (pattern.reliabilityScore * 100).toStringAsFixed(0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tagColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                pattern.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$tagLabel • $rel% Reliability',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            pattern.description,
            style: TextStyle(
              fontSize: 11,
              color: colors.mutedForeground,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
