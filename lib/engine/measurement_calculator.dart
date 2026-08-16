/// Measurement statistics calculator.
///
/// Pure computation, no Flutter dependency. Takes anchor timestamps/prices and
/// the underlying candle data to produce every metric shown in the floating
/// measurement card.
library;

import 'dart:math' as math;

import 'package:app/domain/entities/candle_data.dart';

class MeasurementStats {
  final double priceChange;
  final double percentChange;
  final double absoluteChange;
  final double highestPrice;
  final double lowestPrice;
  final int candleCount;
  final Duration duration;
  final double averageVolume;
  final double highestVolume;
  final double lowestVolume;
  final double averageCandleRangePercent;
  final double atrMultiple;
  final double maxDrawdownPercent;
  final double maxRunupPercent;
  final double? riskRewardRatio;

  const MeasurementStats({
    required this.priceChange,
    required this.percentChange,
    required this.absoluteChange,
    required this.highestPrice,
    required this.lowestPrice,
    required this.candleCount,
    required this.duration,
    required this.averageVolume,
    required this.highestVolume,
    required this.lowestVolume,
    required this.averageCandleRangePercent,
    required this.atrMultiple,
    required this.maxDrawdownPercent,
    required this.maxRunupPercent,
    this.riskRewardRatio,
  });
}

class MeasurementCalculator {
  MeasurementCalculator._();

  /// Compute measurement stats between two timestamps across candle data.
  ///
  /// [startTimestamp] and [endTimestamp] are in milliseconds since epoch.
  /// [startPrice] and [endPrice] are the anchor prices.
  static MeasurementStats compute({
    required int startTimestamp,
    required int endTimestamp,
    required double startPrice,
    required double endPrice,
    required List<CandleData> candles,
  }) {
    // Ensure start is before end for range iteration.
    final tMin = math.min(startTimestamp, endTimestamp);
    final tMax = math.max(startTimestamp, endTimestamp);

    // Find candles within the measurement range.
    final subset = <CandleData>[];
    for (final c in candles) {
      if (c.timestamp >= tMin && c.timestamp <= tMax) {
        subset.add(c);
      }
    }

    // Basic price metrics.
    final priceChange = endPrice - startPrice;
    final percentChange =
        startPrice.abs() > 1e-12 ? (priceChange / startPrice) * 100.0 : 0.0;
    final absoluteChange = priceChange.abs();

    if (subset.isEmpty) {
      return MeasurementStats(
        priceChange: priceChange,
        percentChange: percentChange,
        absoluteChange: absoluteChange,
        highestPrice: math.max(startPrice, endPrice),
        lowestPrice: math.min(startPrice, endPrice),
        candleCount: 0,
        duration: Duration(milliseconds: (tMax - tMin).abs()),
        averageVolume: 0,
        highestVolume: 0,
        lowestVolume: 0,
        averageCandleRangePercent: 0,
        atrMultiple: 0,
        maxDrawdownPercent: 0,
        maxRunupPercent: 0,
      );
    }

    // Price extremes across actual candle data.
    var highestPrice = subset.first.high;
    var lowestPrice = subset.first.low;
    var highestVolume = subset.first.volume;
    var lowestVolume = subset.first.volume;
    var totalVolume = 0.0;
    var totalRangePercent = 0.0;
    var totalTrueRange = 0.0;

    // Drawdown / run-up tracking.
    var peakPrice = subset.first.high;
    var troughPrice = subset.first.low;
    var maxDrawdown = 0.0;
    var maxRunup = 0.0;

    for (var i = 0; i < subset.length; i++) {
      final c = subset[i];
      highestPrice = math.max(highestPrice, c.high);
      lowestPrice = math.min(lowestPrice, c.low);
      highestVolume = math.max(highestVolume, c.volume);
      lowestVolume = math.min(lowestVolume, c.volume);
      totalVolume += c.volume;

      // Candle range as percent of candle midpoint.
      final mid = (c.high + c.low) / 2.0;
      if (mid > 1e-12) {
        totalRangePercent += (c.range / mid) * 100.0;
      }

      // True Range (ATR component).
      if (i == 0) {
        totalTrueRange += c.range;
      } else {
        final prevClose = subset[i - 1].close;
        final tr = [
          c.high - c.low,
          (c.high - prevClose).abs(),
          (c.low - prevClose).abs(),
        ].reduce(math.max);
        totalTrueRange += tr;
      }

      // Max drawdown from peak.
      peakPrice = math.max(peakPrice, c.high);
      final dd = peakPrice > 1e-12 ? (peakPrice - c.low) / peakPrice : 0.0;
      maxDrawdown = math.max(maxDrawdown, dd);

      // Max run-up from trough.
      troughPrice = math.min(troughPrice, c.low);
      final ru =
          troughPrice > 1e-12 ? (c.high - troughPrice) / troughPrice : 0.0;
      maxRunup = math.max(maxRunup, ru);
    }

    final candleCount = subset.length;
    final averageVolume = totalVolume / candleCount;
    final averageCandleRangePercent = totalRangePercent / candleCount;
    final atr = totalTrueRange / candleCount;
    final atrMultiple = atr > 1e-12 ? absoluteChange / atr : 0.0;

    // Risk/reward: ratio of run-up to drawdown.
    final riskRewardRatio =
        maxDrawdown > 1e-12 ? maxRunup / maxDrawdown : null;

    final durationMs = (tMax - tMin).abs();

    return MeasurementStats(
      priceChange: priceChange,
      percentChange: percentChange,
      absoluteChange: absoluteChange,
      highestPrice: highestPrice,
      lowestPrice: lowestPrice,
      candleCount: candleCount,
      duration: Duration(milliseconds: durationMs),
      averageVolume: averageVolume,
      highestVolume: highestVolume,
      lowestVolume: lowestVolume,
      averageCandleRangePercent: averageCandleRangePercent,
      atrMultiple: atrMultiple,
      maxDrawdownPercent: maxDrawdown * 100.0,
      maxRunupPercent: maxRunup * 100.0,
      riskRewardRatio: riskRewardRatio,
    );
  }

  /// Format a volume value to a human-readable string (e.g. 2.3B, 450M).
  static String formatVolume(double vol) {
    if (vol >= 1e12) return '${(vol / 1e12).toStringAsFixed(2)}T';
    if (vol >= 1e9) return '${(vol / 1e9).toStringAsFixed(1)}B';
    if (vol >= 1e6) return '${(vol / 1e6).toStringAsFixed(1)}M';
    if (vol >= 1e3) return '${(vol / 1e3).toStringAsFixed(1)}K';
    return vol.toStringAsFixed(0);
  }

  /// Format a duration to a human-readable string.
  static String formatDuration(Duration d) {
    if (d.inDays >= 365) {
      final years = d.inDays ~/ 365;
      final days = d.inDays % 365;
      return days > 0 ? '${years}Y ${days}D' : '${years}Y';
    }
    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      return hours > 0 ? '${d.inDays}D ${hours}H' : '${d.inDays} Days';
    }
    if (d.inHours > 0) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours}H ${mins}M' : '${d.inHours} Hours';
    }
    if (d.inMinutes > 0) return '${d.inMinutes} Min';
    return '${d.inSeconds}s';
  }
}
