/// Maps higher-timeframe calculated indicator values to lower-timeframe chart timestamps.
library;

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/indicators/multi_timeframe/candle_aggregator.dart';

class TimeframeMapper {
  /// Map higher-timeframe values (indexed by higher-timeframe candle timestamp)
  /// back to lower-timeframe candles.
  static List<double?> mapValuesToChartCandles({
    required List<CandleData> chartCandles,
    required List<CandleData> htfCandles,
    required List<double?> htfValues,
    required String htfTimeframe,
  }) {
    if (chartCandles.isEmpty || htfCandles.isEmpty || htfValues.isEmpty) {
      return List<double?>.filled(chartCandles.length, null);
    }

    final periodMs = CandleAggregator.timeframeToMs(htfTimeframe);

    // Build map from HTF period start timestamp to HTF value index
    final Map<int, int> htfIndexByTimestamp = {};
    for (int i = 0; i < htfCandles.length; i++) {
      htfIndexByTimestamp[htfCandles[i].timestamp] = i;
    }

    final List<double?> mapped = List<double?>.filled(chartCandles.length, null);

    int lastKnownHtfIndex = -1;

    for (int i = 0; i < chartCandles.length; i++) {
      final candle = chartCandles[i];
      final periodStart = CandleAggregator.alignTimestamp(candle.timestamp, periodMs);

      if (htfIndexByTimestamp.containsKey(periodStart)) {
        lastKnownHtfIndex = htfIndexByTimestamp[periodStart]!;
      }

      if (lastKnownHtfIndex >= 0 && lastKnownHtfIndex < htfValues.length) {
        mapped[i] = htfValues[lastKnownHtfIndex];
      } else {
        mapped[i] = null;
      }
    }

    return mapped;
  }

  /// Map complex multi-line HTF indicator outputs (e.g. Bollinger Bands, MACD, SuperTrend)
  static Map<String, List<double?>> mapMultiLineToChartCandles({
    required List<CandleData> chartCandles,
    required List<CandleData> htfCandles,
    required Map<String, List<double?>> htfMultiLineValues,
    required String htfTimeframe,
  }) {
    final Map<String, List<double?>> result = {};
    for (final entry in htfMultiLineValues.entries) {
      result[entry.key] = mapValuesToChartCandles(
        chartCandles: chartCandles,
        htfCandles: htfCandles,
        htfValues: entry.value,
        htfTimeframe: htfTimeframe,
      );
    }
    return result;
  }
}
