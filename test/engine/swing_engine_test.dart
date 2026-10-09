import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/swing_engine.dart';

void main() {
  group('Swing Engine - Pivot High & Pivot Low Detection', () {
    test('Detects clear pivot high and pivot low in wave dataset', () {
      const now = 1000000;
      final candles = <CandleData>[];

      // Build 15 candles with clear peak high at index 5 and trough low at index 10
      for (var i = 0; i < 15; i++) {
        double highPrice = 105.0;
        double lowPrice = 95.0;

        if (i == 5) highPrice = 130.0; // Peak high
        if (i == 10) lowPrice = 70.0; // Trough low

        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: highPrice,
          low: lowPrice,
          close: 100.0,
          volume: 500,
        ));
      }

      final swings = SwingEngine.detectSwings(candles, sensitivity: 3);

      expect(swings, isNotEmpty);
      final highSwing = swings.firstWhere((s) => s.isHigh);
      final lowSwing = swings.firstWhere((s) => s.isLow);

      expect(highSwing.index, equals(5));
      expect(highSwing.price, equals(130.0));

      expect(lowSwing.index, equals(10));
      expect(lowSwing.price, equals(70.0));
    });

    test('Is 100% deterministic (same input produces identical output)', () {
      const now = 1000000;
      final candles = List.generate(
        20,
        (i) => CandleData(
          timestamp: now + i * 60000,
          open: 100.0 + (i % 3),
          high: 105.0 + (i % 4),
          low: 95.0 - (i % 3),
          close: 101.0,
        ),
      );

      final run1 = SwingEngine.detectSwings(candles, sensitivity: 2);
      final run2 = SwingEngine.detectSwings(candles, sensitivity: 2);

      expect(run1.length, equals(run2.length));
      for (var i = 0; i < run1.length; i++) {
        expect(run1[i], equals(run2[i]));
      }
    });
  });
}
