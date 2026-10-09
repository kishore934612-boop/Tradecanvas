/// Multi-Timeframe (MTF) Indicator Engine.
///
/// Computes indicators for higher target timeframes without altering the chart's
/// active timeframe, synchronizing and caching calculation outputs back to chart
/// candle timestamps.
library;

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/indicators/multi_timeframe/candle_aggregator.dart';
import 'package:app/indicators/multi_timeframe/timeframe_mapper.dart';

class MtfIndicatorConfig {
  final IndicatorType type;
  final String timeframe; // 'current', '1m', '5m', '15m', '30m', '1h', '4h', '1d'
  final int period;
  final Map<String, dynamic> params;

  const MtfIndicatorConfig({
    required this.type,
    this.timeframe = 'current',
    this.period = 14,
    this.params = const {},
  });

  String get legendLabel {
    final tfLabel = timeframe.toUpperCase();
    if (timeframe == 'current') return type.label;
    return '${type.name.toUpperCase()} $period ($tfLabel)';
  }
}

class MtfResult {
  final MtfIndicatorConfig config;
  final List<double?> primaryValues;
  final Map<String, List<double?>> multiLineValues;

  const MtfResult({
    required this.config,
    required this.primaryValues,
    this.multiLineValues = const {},
  });
}

class MtfIndicatorEngine {
  /// Cache of calculated MTF results keyed by config + candle hash
  final Map<String, MtfResult> _cache = {};

  void clearCache() {
    _cache.clear();
  }

  /// Compute MTF indicator values mapped index-by-index to the base chart candles.
  MtfResult compute({
    required List<CandleData> chartCandles,
    required MtfIndicatorConfig config,
    required String chartTimeframe,
  }) {
    if (chartCandles.isEmpty) {
      return MtfResult(
        config: config,
        primaryValues: const [],
      );
    }

    final targetTf = config.timeframe == 'current' ? chartTimeframe : config.timeframe;
    final cacheKey = '${config.type.name}_${config.period}_${targetTf}_${chartCandles.length}_${chartCandles.last.timestamp}_${chartCandles.last.close}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Step 1: Aggregate candles if target timeframe is different
    List<CandleData> htfCandles;
    if (config.timeframe == 'current' || targetTf.toLowerCase() == chartTimeframe.toLowerCase()) {
      htfCandles = chartCandles;
    } else {
      htfCandles = CandleAggregator.aggregate(chartCandles, targetTf);
    }

    // Step 2: Compute indicator on HTF candles
    final htfIndicators = CandleEngine.computeAll(htfCandles);

    // Step 3: Extract indicator series from htfIndicators based on type
    List<double?> htfPrimaryValues = [];
    Map<String, List<double?>> htfMultiLines = {};

    switch (config.type) {
      case IndicatorType.ema:
        htfPrimaryValues = htfIndicators.ema;
        break;
      case IndicatorType.sma:
        htfPrimaryValues = htfIndicators.sma;
        break;
      case IndicatorType.rsi:
        htfPrimaryValues = htfIndicators.rsi;
        break;
      case IndicatorType.vwap:
        htfPrimaryValues = htfIndicators.vwap;
        break;
      case IndicatorType.atr:
        htfPrimaryValues = htfIndicators.atr;
        break;
      case IndicatorType.volume:
        htfPrimaryValues = htfCandles.map((c) => c.volume).toList();
        break;
      case IndicatorType.macd:
        htfPrimaryValues = htfIndicators.macdHist;
        htfMultiLines = {
          'macd': htfIndicators.macdLine,
          'signal': htfIndicators.macdSignal,
          'hist': htfIndicators.macdHist,
        };
        break;
      case IndicatorType.bollingerBands:
        htfPrimaryValues = htfIndicators.bbMiddle;
        htfMultiLines = {
          'upper': htfIndicators.bbUpper,
          'middle': htfIndicators.bbMiddle,
          'lower': htfIndicators.bbLower,
        };
        break;
      case IndicatorType.superTrend:
        htfPrimaryValues = htfIndicators.superTrend;
        break;
      case IndicatorType.stochRsi:
        htfPrimaryValues = htfIndicators.stochK;
        htfMultiLines = {
          'k': htfIndicators.stochK,
          'd': htfIndicators.stochD,
        };
        break;
    }

    // Step 4: Map values back to chart candles
    List<double?> mappedPrimary;
    Map<String, List<double?>> mappedMultiLines = {};

    if (htfCandles == chartCandles) {
      mappedPrimary = htfPrimaryValues;
      mappedMultiLines = htfMultiLines;
    } else {
      mappedPrimary = TimeframeMapper.mapValuesToChartCandles(
        chartCandles: chartCandles,
        htfCandles: htfCandles,
        htfValues: htfPrimaryValues,
        htfTimeframe: targetTf,
      );

      if (htfMultiLines.isNotEmpty) {
        mappedMultiLines = TimeframeMapper.mapMultiLineToChartCandles(
          chartCandles: chartCandles,
          htfCandles: htfCandles,
          htfMultiLineValues: htfMultiLines,
          htfTimeframe: targetTf,
        );
      }
    }

    final result = MtfResult(
      config: config,
      primaryValues: mappedPrimary,
      multiLineValues: mappedMultiLines,
    );

    _cache[cacheKey] = result;
    return result;
  }
}
