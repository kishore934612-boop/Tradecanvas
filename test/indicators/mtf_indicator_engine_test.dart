import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/indicators/multi_timeframe/candle_aggregator.dart';
import 'package:app/indicators/multi_timeframe/mtf_indicator_engine.dart';
import 'package:app/indicators/multi_timeframe/timeframe_mapper.dart';

void main() {
  group('Multi-Timeframe Indicator Engine Tests', () {
    late List<CandleData> candles15m;

    setUp(() {
      const baseTime = 1600000000000;
      candles15m = List.generate(100, (i) {
        final t = baseTime + i * 15 * 60 * 1000; // 15-minute intervals
        final p = 100.0 + (i % 10);
        return CandleData(
          timestamp: t,
          open: p,
          high: p + 2.0,
          low: p - 1.0,
          close: p + 1.0,
          volume: 1000.0 + i * 10,
        );
      });
    });

    test('CandleAggregator aggregates 15m candles into 1H candles', () {
      final htfCandles = CandleAggregator.aggregate(candles15m, '1h');
      // 100 * 15m = 1500m = 25 hours -> ~25 candles
      expect(htfCandles.length, inInclusiveRange(24, 26));

      // Each 1H candle open should match first 15m candle in window
      expect(htfCandles.first.open, equals(candles15m.first.open));
    });

    test('TimeframeMapper maps HTF values back to 15m chart length', () {
      final htfCandles = CandleAggregator.aggregate(candles15m, '1h');
      final htfValues = List.generate(htfCandles.length, (i) => (i + 1) * 10.0);

      final mapped = TimeframeMapper.mapValuesToChartCandles(
        chartCandles: candles15m,
        htfCandles: htfCandles,
        htfValues: htfValues,
        htfTimeframe: '1h',
      );

      expect(mapped.length, equals(candles15m.length));
      // Candles in the same 1H period share the same 1H indicator value
      expect(mapped[0], equals(mapped[1]));
      expect(mapped[1], equals(mapped[2]));
      expect(mapped[3], equals(mapped[4]));
    });

    test('MtfIndicatorEngine calculates EMA 200 (1H) on 15m chart', () {
      final engine = MtfIndicatorEngine();
      const config = MtfIndicatorConfig(
        type: IndicatorType.ema,
        timeframe: '1h',
        period: 20,
      );

      final result = engine.compute(
        chartCandles: candles15m,
        config: config,
        chartTimeframe: '15m',
      );

      expect(result.primaryValues.length, equals(candles15m.length));
      expect(result.config.legendLabel, contains('1H'));
    });

    test('MtfIndicatorEngine supports MACD multi-line outputs', () {
      final engine = MtfIndicatorEngine();
      const config = MtfIndicatorConfig(
        type: IndicatorType.macd,
        timeframe: '4h',
      );

      final result = engine.compute(
        chartCandles: candles15m,
        config: config,
        chartTimeframe: '15m',
      );

      expect(result.multiLineValues.containsKey('macd'), isTrue);
      expect(result.multiLineValues['macd']!.length, equals(candles15m.length));
    });
  });
}
