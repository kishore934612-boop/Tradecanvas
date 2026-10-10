import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/strategy_engine.dart';
import 'package:app/models/strategy_type.dart';

void main() {
  group('New Educational Strategies Tests', () {
    late List<CandleData> candles;

    setUp(() {
      const now = 100000;
      candles = List.generate(
        30,
        (i) => CandleData(
          timestamp: now + (i * 60000),
          open: 100.0 + i,
          high: 102.0 + i,
          low: 99.0 + i,
          close: 101.0 + i,
          volume: 1000.0,
        ),
      );
    });

    test('Order Block Retest strategy generates OB Retest signal on demand retest', () {
      // Create Demand OB pattern at index 10-11
      // Candle 10: Bearish (110 open, 105 close, 104 low, 111 high)
      candles[10] = CandleData(
        timestamp: 100000 + 10 * 60000,
        open: 110.0,
        high: 111.0,
        low: 104.0,
        close: 105.0,
        volume: 1000.0,
      );
      // Candle 11: Strong Bullish displacement (105 open, 120 close, 105 low, 121 high)
      candles[11] = CandleData(
        timestamp: 100000 + 11 * 60000,
        open: 105.0,
        high: 121.0,
        low: 105.0,
        close: 120.0,
        volume: 2000.0,
      );

      // Candle 14: Retests Demand OB zone (107 low touches 104-111 range and closes bullish 115)
      candles[14] = CandleData(
        timestamp: 100000 + 14 * 60000,
        open: 108.0,
        high: 116.0,
        low: 107.0,
        close: 115.0,
        volume: 1500.0,
      );

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.orderBlockRetest},
        settings: const StrategySettings(),
      );

      expect(signals.any((s) => s.strategy == StrategyType.orderBlockRetest && s.isBuy), isTrue);
    });

    test('FVG Fill strategy generates FVG Fill signal when price enters gap', () {
      // Create Bullish FVG at index 5-7:
      // Candle 5: high = 100.0
      candles[5] = CandleData(
        timestamp: 100000 + 5 * 60000,
        open: 95.0,
        high: 100.0,
        low: 94.0,
        close: 98.0,
        volume: 1000.0,
      );
      // Candle 6: Big impulse (open 99, close 110, low 98, high 112)
      candles[6] = CandleData(
        timestamp: 100000 + 6 * 60000,
        open: 99.0,
        high: 112.0,
        low: 98.0,
        close: 110.0,
        volume: 3000.0,
      );
      // Candle 7: low = 106.0 (Gap between c5 high 100 and c7 low 106)
      candles[7] = CandleData(
        timestamp: 100000 + 7 * 60000,
        open: 110.0,
        high: 118.0,
        low: 106.0,
        close: 115.0,
        volume: 1500.0,
      );

      // Candle 9: Fills gap (low 102 enters 100-106 gap and closes bullish 110)
      candles[9] = CandleData(
        timestamp: 100000 + 9 * 60000,
        open: 105.0,
        high: 112.0,
        low: 102.0,
        close: 110.0,
        volume: 1200.0,
      );

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.fvgFillRejection},
        settings: const StrategySettings(),
      );

      expect(signals.any((s) => s.strategy == StrategyType.fvgFillRejection && s.isBuy), isTrue);
    });
  });
}
