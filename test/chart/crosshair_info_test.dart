import 'package:flutter_test/flutter_test.dart';
import 'package:app/chart/crosshair/crosshair_info.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';

void main() {
  group('Crosshair Info Calculation Tests', () {
    final timestamp = DateTime(2026, 8, 20, 14, 30).millisecondsSinceEpoch;
    final candle = CandleData(
      timestamp: timestamp,
      open: 100.0,
      high: 110.0,
      low: 95.0,
      close: 105.0,
      volume: 5000.0,
    );

    test('calculates OHLCV, Change %, Body %, and Wick % accurately', () {
      final info = CrosshairInfoData.fromCandle(index: 5, candle: candle);

      expect(info.candleIndex, equals(5));
      expect(info.open, equals(100.0));
      expect(info.high, equals(110.0));
      expect(info.low, equals(95.0));
      expect(info.close, equals(105.0));
      expect(info.volume, equals(5000.0));

      // Change % = (105 - 100) / 100 * 100 = +5%
      expect(info.changePercent, equals(5.0));

      // Range = 110 - 95 = 15
      // Body = |105 - 100| = 5 -> Body % = (5 / 15) * 100 = 33.333%
      expect(info.bodyPercent, closeTo(33.33, 0.1));

      // Upper Wick = 110 - 105 = 5 -> Upper Wick % = (5 / 15) * 100 = 33.333%
      expect(info.upperWickPercent, closeTo(33.33, 0.1));

      // Lower Wick = 100 - 95 = 5 -> Lower Wick % = (5 / 15) * 100 = 33.333%
      expect(info.lowerWickPercent, closeTo(33.33, 0.1));

      // Spread = 110 - 95 = 15
      expect(info.spread, equals(15.0));
    });

    test('binds ATR, RSI, VWAP and MACD from indicators', () {
      final nulls = List<double?>.filled(10, null);
      final atrs = List<double?>.filled(10, 2.5);
      final rsis = List<double?>.filled(10, 65.4);

      final indicators = ChartIndicators(
        ema: nulls,
        sma: nulls,
        rsi: rsis,
        vwap: nulls,
        macdLine: nulls,
        macdSignal: nulls,
        macdHist: nulls,
        bbUpper: nulls,
        bbMiddle: nulls,
        bbLower: nulls,
        atr: atrs,
        stochK: nulls,
        stochD: nulls,
        superTrend: nulls,
        superTrendBullish: List<bool?>.filled(10, null),
      );

      final info = CrosshairInfoData.fromCandle(
        index: 5,
        candle: candle,
        indicators: indicators,
      );

      expect(info.atr, equals(2.5));
      expect(info.rsi, equals(65.4));
    });
  });
}
