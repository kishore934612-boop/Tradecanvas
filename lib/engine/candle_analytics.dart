/// Candle analytics — comprehensive statistics for a single candle.
///
/// Pure computation, no Flutter dependency. Takes a target candle, its index,
/// and the surrounding candle list to produce all metrics shown in the Smart
/// Candle Statistics panel.
library;

import 'dart:math' as math;

import 'package:app/domain/entities/candle_data.dart';

enum PatternSentiment { bullish, bearish, neutral }

class CandlePattern {
  final String name;
  final PatternSentiment sentiment;
  final String description;
  final double reliabilityScore; // 0.0 to 1.0

  const CandlePattern({
    required this.name,
    required this.sentiment,
    required this.description,
    required this.reliabilityScore,
  });
}

class CandleAnalytics {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  // Anatomy.
  final double bodySize;
  final double upperWick;
  final double lowerWick;
  final double totalRange;

  // Proportions.
  final double bodyPercent;
  final double upperWickPercent;
  final double lowerWickPercent;
  final bool isBullish;

  // Context.
  final double rangePercent;
  final double closePosition;
  final double volumeVsAverage;
  final double atrRatio;

  // Pressure.
  final double buyingPressure;
  final double sellingPressure;

  // Change.
  final double gapFromPrevious;
  final double priceChange;
  final double percentChange;

  // Automatically detected patterns.
  final List<CandlePattern> detectedPatterns;

  const CandleAnalytics({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.bodySize,
    required this.upperWick,
    required this.lowerWick,
    required this.totalRange,
    required this.bodyPercent,
    required this.upperWickPercent,
    required this.lowerWickPercent,
    required this.isBullish,
    required this.rangePercent,
    required this.closePosition,
    required this.volumeVsAverage,
    required this.atrRatio,
    required this.buyingPressure,
    required this.sellingPressure,
    required this.gapFromPrevious,
    required this.priceChange,
    required this.percentChange,
    required this.detectedPatterns,
  });

  /// Compute analytics for the candle at [index] within [candles].
  static CandleAnalytics compute(List<CandleData> candles, int index) {
    final c = candles[index];
    final date = DateTime.fromMillisecondsSinceEpoch(c.timestamp).toLocal();

    final bodySize = c.body;
    final upperWick = c.upperWick;
    final lowerWick = c.lowerWick;
    final totalRange = c.range;

    // Proportions.
    final bodyPercent = totalRange > 1e-12 ? (bodySize / totalRange) * 100 : 0.0;
    final upperWickPercent =
        totalRange > 1e-12 ? (upperWick / totalRange) * 100 : 0.0;
    final lowerWickPercent =
        totalRange > 1e-12 ? (lowerWick / totalRange) * 100 : 0.0;

    // Range as % of midpoint.
    final mid = (c.high + c.low) / 2.0;
    final rangePercent = mid > 1e-12 ? (totalRange / mid) * 100 : 0.0;

    // Close position within the candle's high-low range (0% = low, 100% = high).
    final closePosition =
        totalRange > 1e-12 ? ((c.close - c.low) / totalRange) * 100 : 50.0;

    // Volume vs 20-period average volume.
    double volumeVsAverage = 1.0;
    {
      const period = 20;
      final start = math.max(0, index - period + 1);
      var sum = 0.0;
      var count = 0;
      for (var i = start; i <= index; i++) {
        sum += candles[i].volume;
        count++;
      }
      final avg = count > 0 ? sum / count : 0.0;
      volumeVsAverage = avg > 1e-12 ? c.volume / avg : 1.0;
    }

    // ATR ratio: this candle's range vs 14-period ATR.
    double atrRatio = 1.0;
    {
      const period = 14;
      if (index >= 1) {
        final start = math.max(0, index - period + 1);
        var trSum = 0.0;
        var count = 0;
        for (var i = start; i <= index; i++) {
          if (i == 0) {
            trSum += candles[i].range;
          } else {
            final prev = candles[i - 1].close;
            final tr = [
              candles[i].high - candles[i].low,
              (candles[i].high - prev).abs(),
              (candles[i].low - prev).abs(),
            ].reduce(math.max);
            trSum += tr;
          }
          count++;
        }
        final atr = count > 0 ? trSum / count : 0.0;
        atrRatio = atr > 1e-12 ? totalRange / atr : 1.0;
      }
    }

    // Buying/selling pressure.
    // Buying pressure = (close - low) / range.
    // Selling pressure = (high - close) / range.
    final buyingPressure =
        totalRange > 1e-12 ? ((c.close - c.low) / totalRange) * 100 : 50.0;
    final sellingPressure =
        totalRange > 1e-12 ? ((c.high - c.close) / totalRange) * 100 : 50.0;

    // Gap from previous candle.
    double gapFromPrevious = 0.0;
    if (index > 0) {
      gapFromPrevious = c.open - candles[index - 1].close;
    }

    // Price change.
    final priceChange = c.close - c.open;
    final percentChange =
        c.open.abs() > 1e-12 ? (priceChange / c.open) * 100 : 0.0;

    final detectedPatterns = _detectPatterns(
      candles,
      index,
      bodySize,
      upperWick,
      lowerWick,
      totalRange,
      bodyPercent,
      upperWickPercent,
      lowerWickPercent,
      closePosition,
    );

    return CandleAnalytics(
      date: date,
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      volume: c.volume,
      bodySize: bodySize,
      upperWick: upperWick,
      lowerWick: lowerWick,
      totalRange: totalRange,
      bodyPercent: bodyPercent,
      upperWickPercent: upperWickPercent,
      lowerWickPercent: lowerWickPercent,
      isBullish: c.isBullish,
      rangePercent: rangePercent,
      closePosition: closePosition,
      volumeVsAverage: volumeVsAverage,
      atrRatio: atrRatio,
      buyingPressure: buyingPressure,
      sellingPressure: sellingPressure,
      gapFromPrevious: gapFromPrevious,
      priceChange: priceChange,
      percentChange: percentChange,
      detectedPatterns: detectedPatterns,
    );
  }

  static List<CandlePattern> _detectPatterns(
    List<CandleData> candles,
    int index,
    double bodySize,
    double upperWick,
    double lowerWick,
    double totalRange,
    double bodyPercent,
    double upperWickPercent,
    double lowerWickPercent,
    double closePosition,
  ) {
    final List<CandlePattern> patterns = [];
    final c = candles[index];

    // Single candle patterns
    if (bodyPercent <= 10.0) {
      if (lowerWickPercent >= 60.0 && upperWickPercent <= 15.0) {
        patterns.add(const CandlePattern(
          name: 'Dragonfly Doji',
          sentiment: PatternSentiment.bullish,
          description:
              'Open, high, and close are equal with a long lower wick. Strong bullish rejection of lower prices.',
          reliabilityScore: 0.85,
        ));
      } else if (upperWickPercent >= 60.0 && lowerWickPercent <= 15.0) {
        patterns.add(const CandlePattern(
          name: 'Gravestone Doji',
          sentiment: PatternSentiment.bearish,
          description:
              'Open, low, and close are equal with a long upper wick. Strong bearish rejection of higher prices.',
          reliabilityScore: 0.85,
        ));
      } else {
        patterns.add(const CandlePattern(
          name: 'Doji',
          sentiment: PatternSentiment.neutral,
          description:
              'Open and close are virtually identical. Indicates extreme market indecision.',
          reliabilityScore: 0.70,
        ));
      }
    } else if (lowerWick >= 2.0 * bodySize && upperWick <= 0.15 * totalRange && closePosition >= 65.0) {
      patterns.add(const CandlePattern(
        name: 'Hammer',
        sentiment: PatternSentiment.bullish,
        description:
            'Small upper body with long lower wick. Buyers aggressively stepped in to push price back up.',
        reliabilityScore: 0.82,
      ));
    } else if (upperWick >= 2.0 * bodySize && lowerWick <= 0.15 * totalRange && closePosition <= 35.0) {
      patterns.add(const CandlePattern(
        name: 'Shooting Star',
        sentiment: PatternSentiment.bearish,
        description:
            'Small lower body with long upper wick. Sellers aggressively pushed price down from highs.',
        reliabilityScore: 0.82,
      ));
    } else if (upperWick >= 2.0 * bodySize && lowerWick <= 0.15 * totalRange && c.isBullish) {
      patterns.add(const CandlePattern(
        name: 'Inverted Hammer',
        sentiment: PatternSentiment.bullish,
        description:
            'Bulls attempted to push price higher, indicating emerging buying interest.',
        reliabilityScore: 0.75,
      ));
    } else if (bodyPercent >= 88.0) {
      patterns.add(CandlePattern(
        name: c.isBullish ? 'Bullish Marubozu' : 'Bearish Marubozu',
        sentiment: c.isBullish ? PatternSentiment.bullish : PatternSentiment.bearish,
        description: c.isBullish
            ? 'Full green body with no wicks. Complete buyers dominance from open to close.'
            : 'Full red body with no wicks. Complete sellers dominance from open to close.',
        reliabilityScore: 0.88,
      ));
    } else if (bodyPercent >= 10.0 && bodyPercent <= 30.0 && upperWickPercent >= 25.0 && lowerWickPercent >= 25.0) {
      patterns.add(const CandlePattern(
        name: 'Spinning Top',
        sentiment: PatternSentiment.neutral,
        description:
            'Small real body with upper and lower wicks. Equilibrium between buyers and sellers.',
        reliabilityScore: 0.65,
      ));
    }

    // Two-candle patterns
    if (index > 0) {
      final prev = candles[index - 1];

      // Engulfing
      if (!prev.isBullish && c.isBullish && c.close >= prev.open && c.open <= prev.close) {
        patterns.add(const CandlePattern(
          name: 'Bullish Engulfing',
          sentiment: PatternSentiment.bullish,
          description:
              'Current green body completely engulfs prior red body. Strong bullish momentum reversal.',
          reliabilityScore: 0.89,
        ));
      } else if (prev.isBullish && !c.isBullish && c.open >= prev.close && c.close <= prev.open) {
        patterns.add(const CandlePattern(
          name: 'Bearish Engulfing',
          sentiment: PatternSentiment.bearish,
          description:
              'Current red body completely engulfs prior green body. Strong bearish momentum reversal.',
          reliabilityScore: 0.89,
        ));
      }

      // Harami
      if (!prev.isBullish && c.isBullish && prev.body > 1.5 * bodySize && c.open >= prev.close && c.close <= prev.open) {
        patterns.add(const CandlePattern(
          name: 'Bullish Harami',
          sentiment: PatternSentiment.bullish,
          description:
              'Small green body inside prior large red body. Selling pressure is losing momentum.',
          reliabilityScore: 0.76,
        ));
      } else if (prev.isBullish && !c.isBullish && prev.body > 1.5 * bodySize && c.open <= prev.close && c.close >= prev.open) {
        patterns.add(const CandlePattern(
          name: 'Bearish Harami',
          sentiment: PatternSentiment.bearish,
          description:
              'Small red body inside prior large green body. Buying pressure is losing momentum.',
          reliabilityScore: 0.76,
        ));
      }
    }

    // Three-candle patterns
    if (index >= 2) {
      final c0 = candles[index - 2];
      final c1 = candles[index - 1];

      if (!c0.isBullish && c1.body / c0.range <= 0.25 && c.isBullish && c.close >= (c0.open + c0.close) / 2.0) {
        patterns.add(const CandlePattern(
          name: 'Morning Star',
          sentiment: PatternSentiment.bullish,
          description:
              '3-candle bullish reversal pattern. Strong decline, star indecision, and strong green recovery.',
          reliabilityScore: 0.92,
        ));
      } else if (c0.isBullish && c1.body / c0.range <= 0.25 && !c.isBullish && c.close <= (c0.open + c0.close) / 2.0) {
        patterns.add(const CandlePattern(
          name: 'Evening Star',
          sentiment: PatternSentiment.bearish,
          description:
              '3-candle bearish reversal pattern. Strong rally, star indecision, and strong red reversal.',
          reliabilityScore: 0.92,
        ));
      }
    }

    return patterns;
  }
}
