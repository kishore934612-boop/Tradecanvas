import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';

List<CandleData> _createTestCandles(List<double> closes) {
  const startTime = 1000000;
  return List.generate(closes.length, (i) {
    final close = closes[i];
    return CandleData(
      timestamp: startTime + i * 60000,
      open: close - 0.5,
      high: close + 1.0,
      low: close - 1.0,
      close: close,
      volume: 1000.0,
    );
  });
}

void main() {
  group('Indicator Engine - Mathematical Formula Validation', () {
    test('EMA matches official formula: Price * K + PrevEMA * (1 - K)', () {
      final closes = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0];
      final candles = _createTestCandles(closes);
      const period = 3;

      final ema = CandleEngine.computeEma(candles, period);

      // Seed SMA for first 3 items: (10 + 11 + 12) / 3 = 11.0
      expect(ema[0], isNull);
      expect(ema[1], isNull);
      expect(ema[2], closeTo(11.0, 0.0001));

      // k = 2 / (3 + 1) = 0.5
      // item 3 (close 13.0): 13.0 * 0.5 + 11.0 * 0.5 = 12.0
      expect(ema[3], closeTo(12.0, 0.0001));

      // item 4 (close 14.0): 14.0 * 0.5 + 12.0 * 0.5 = 13.0
      expect(ema[4], closeTo(13.0, 0.0001));
    });

    test('SMA matches simple moving average', () {
      final closes = [10.0, 20.0, 30.0, 40.0, 50.0];
      final candles = _createTestCandles(closes);
      const period = 3;

      final sma = CandleEngine.computeSma(candles, period);

      expect(sma[0], isNull);
      expect(sma[1], isNull);
      expect(sma[2], closeTo(20.0, 0.0001)); // (10+20+30)/3
      expect(sma[3], closeTo(30.0, 0.0001)); // (20+30+40)/3
      expect(sma[4], closeTo(40.0, 0.0001)); // (30+40+50)/3
    });

    test('Bollinger Bands matches Middle SMA +/- Multiplier * StdDev', () {
      final closes = [10.0, 12.0, 14.0, 16.0, 18.0];
      final candles = _createTestCandles(closes);
      const period = 3;
      const multiplier = 2.0;

      final bb = CandleEngine.computeBollingerBands(
        candles,
        period: period,
        multiplier: multiplier,
      );

      // At index 2: values [10, 12, 14], mean = 12.0
      // variance = ((10-12)^2 + (12-12)^2 + (14-12)^2) / 3 = (4 + 0 + 4)/3 = 2.666666
      // stdDev = sqrt(8/3) ~ 1.63299
      const expectedMean = 12.0;
      final expectedStd = math.sqrt(8.0 / 3.0);
      final expectedUpper = expectedMean + 2.0 * expectedStd;
      final expectedLower = expectedMean - 2.0 * expectedStd;

      expect(bb.middle[2], closeTo(expectedMean, 0.0001));
      expect(bb.upper[2], closeTo(expectedUpper, 0.0001));
      expect(bb.lower[2], closeTo(expectedLower, 0.0001));
    });

    test('VWAP calculates cumulative Volume Weighted Average Price', () {
      const now = 1000000;
      final candles = [
        CandleData(timestamp: now, open: 10, high: 12, low: 8, close: 10, volume: 100), // TP = 10, PV = 1000
        CandleData(timestamp: now + 60000, open: 10, high: 22, low: 18, close: 20, volume: 200), // TP = 20, PV = 4000
      ];

      final vwap = CandleEngine.computeVwap(candles);

      // Bar 0: PV = 1000, Vol = 100 -> VWAP = 10.0
      expect(vwap[0], closeTo(10.0, 0.0001));

      // Bar 1: CumPV = 1000 + 4000 = 5000, CumVol = 300 -> VWAP = 5000 / 300 = 16.6666
      expect(vwap[1], closeTo(16.66666, 0.001));
    });

    test('Wilder ATR calculates true range and smoothing', () {
      const now = 1000000;
      final candles = [
        CandleData(timestamp: now, open: 100, high: 110, low: 90, close: 105), // TR unused (index 0)
        CandleData(timestamp: now + 60000, open: 105, high: 115, low: 100, close: 110), // TR = max(15, 10, 5) = 15
        CandleData(timestamp: now + 120000, open: 110, high: 120, low: 105, close: 115), // TR = max(15, 10, 5) = 15
      ];

      final atr = CandleEngine.computeAtr(candles, period: 2);
      expect(atr[0], isNull);
      expect(atr[1], isNull);
      expect(atr[2], closeTo(15.0, 0.0001));
    });
  });
}
