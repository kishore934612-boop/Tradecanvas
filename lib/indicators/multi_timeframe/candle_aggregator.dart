/// Aggregates lower-timeframe candles into higher-timeframe candles.
library;

import 'package:app/domain/entities/candle_data.dart';

class CandleAggregator {
  /// Convert timeframe string (e.g. '1m', '5m', '15m', '30m', '1h', '4h', '1d') to milliseconds.
  static int timeframeToMs(String timeframeStr) {
    final tf = timeframeStr.toLowerCase();
    if (tf == '1m') return 60 * 1000;
    if (tf == '3m') return 3 * 60 * 1000;
    if (tf == '5m') return 5 * 60 * 1000;
    if (tf == '15m') return 15 * 60 * 1000;
    if (tf == '30m') return 30 * 60 * 1000;
    if (tf == '1h' || tf == '1h') return 60 * 60 * 1000;
    if (tf == '2h') return 2 * 60 * 60 * 1000;
    if (tf == '4h') return 4 * 60 * 60 * 1000;
    if (tf == '6h') return 6 * 60 * 60 * 1000;
    if (tf == '8h') return 8 * 60 * 60 * 1000;
    if (tf == '12h') return 12 * 60 * 60 * 1000;
    if (tf == '1d' || tf == '1d') return 24 * 60 * 60 * 1000;
    if (tf == '1w') return 7 * 24 * 60 * 60 * 1000;
    return 60 * 60 * 1000; // default 1h
  }

  /// Align timestamp to the start of the timeframe period.
  static int alignTimestamp(int timestampMs, int periodMs) {
    return (timestampMs ~/ periodMs) * periodMs;
  }

  /// Aggregate lower-timeframe candles into higher-timeframe candles.
  static List<CandleData> aggregate(List<CandleData> candles, String targetTimeframe) {
    if (candles.isEmpty) return const [];

    final periodMs = timeframeToMs(targetTimeframe);
    final List<CandleData> aggregated = [];

    CandleData? currentPeriod;

    for (final c in candles) {
      final periodStart = alignTimestamp(c.timestamp, periodMs);

      if (currentPeriod == null || currentPeriod.timestamp != periodStart) {
        if (currentPeriod != null) {
          aggregated.add(currentPeriod);
        }
        currentPeriod = CandleData(
          timestamp: periodStart,
          open: c.open,
          high: c.high,
          low: c.low,
          close: c.close,
          volume: c.volume,
          isLive: c.isLive,
        );
      } else {
        if (c.high > currentPeriod.high) currentPeriod.high = c.high;
        if (c.low < currentPeriod.low) currentPeriod.low = c.low;
        currentPeriod.close = c.close;
        currentPeriod.volume += c.volume;
        if (c.isLive) currentPeriod.isLive = true;
      }
    }

    if (currentPeriod != null) {
      aggregated.add(currentPeriod);
    }

    return aggregated;
  }
}
