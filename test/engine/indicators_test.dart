/// Tests for indicator computation.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';

const int _oneHour = 60 * 60 * 1000;
const int _t0 = 1700000000000;

List<CandleData> _fromCloses(List<double> closes, {int intervalMs = _oneHour}) {
  return List.generate(
    closes.length,
    (i) => CandleData(
      timestamp: _t0 + i * intervalMs,
      open: closes[i],
      high: closes[i],
      low: closes[i],
      close: closes[i],
      volume: 1,
    ),
  );
}

void main() {
  group('SMA', () {
    test('warm-up region is null, then averages correctly', () {
      final candles = _fromCloses([1, 2, 3, 4, 5]);
      final sma = CandleEngine.computeSma(candles, 3);

      expect(sma[0], isNull);
      expect(sma[1], isNull);
      expect(sma[2], closeTo(2, 1e-9)); // (1+2+3)/3
      expect(sma[3], closeTo(3, 1e-9)); // (2+3+4)/3
      expect(sma[4], closeTo(4, 1e-9)); // (3+4+5)/3
    });

    test('returns all nulls when there are fewer candles than the period', () {
      final sma = CandleEngine.computeSma(_fromCloses([1, 2]), 5);
      expect(sma.length, 2);
      expect(sma.every((v) => v == null), isTrue);
    });

    test('a flat series averages to the same value', () {
      final sma = CandleEngine.computeSma(_fromCloses([7, 7, 7, 7]), 2);
      expect(sma.sublist(1).every((v) => v != null && (v - 7).abs() < 1e-9),
          isTrue);
    });
  });

  group('EMA', () {
    test('seeds on the simple average then applies the smoothing factor', () {
      final candles = _fromCloses([1, 2, 3, 4, 5]);
      final ema = CandleEngine.computeEma(candles, 3);

      expect(ema[0], isNull);
      expect(ema[1], isNull);
      // Seed = (1+2+3)/3 = 2
      expect(ema[2], closeTo(2, 1e-9));
      // k = 2/(3+1) = 0.5 -> 4*0.5 + 2*0.5 = 3
      expect(ema[3], closeTo(3, 1e-9));
      // 5*0.5 + 3*0.5 = 4
      expect(ema[4], closeTo(4, 1e-9));
    });

    test('converges to a constant series', () {
      final ema = CandleEngine.computeEma(
        _fromCloses(List.filled(60, 50.0)),
        10,
      );
      expect(ema.last, closeTo(50, 1e-9));
    });

    test('handles a period of zero without throwing', () {
      final ema = CandleEngine.computeEma(_fromCloses([1, 2, 3]), 0);
      expect(ema.every((v) => v == null), isTrue);
    });
  });

  group('VWAP', () {
    test('is the typical price when a single candle carries all volume', () {
      final candles = [
        CandleData(
          timestamp: _t0,
          open: 10,
          high: 12,
          low: 8,
          close: 10,
          volume: 100,
        ),
      ];
      final vwap = CandleEngine.computeVwap(candles);
      // typical = (12 + 8 + 10) / 3 = 10
      expect(vwap[0], closeTo(10, 1e-9));
    });

    test('resets at a day boundary', () {
      const oneDay = 24 * 60 * 60 * 1000;
      // Two candles far apart, so they land on different local days.
      final candles = [
        CandleData(
          timestamp: _t0,
          open: 10,
          high: 10,
          low: 10,
          close: 10,
          volume: 100,
        ),
        CandleData(
          timestamp: _t0 + oneDay,
          open: 50,
          high: 50,
          low: 50,
          close: 50,
          volume: 1,
        ),
      ];

      final vwap = CandleEngine.computeVwap(candles);
      expect(vwap[0], closeTo(10, 1e-9));
      // If the session had not reset, the tiny volume on day two would leave
      // VWAP near 10 instead of snapping to the new session's price.
      expect(vwap[1], closeTo(50, 1e-9));
    });

    test('yields null while cumulative volume is zero', () {
      final candles = [
        CandleData(
          timestamp: _t0,
          open: 10,
          high: 10,
          low: 10,
          close: 10,
          volume: 0,
        ),
      ];
      expect(CandleEngine.computeVwap(candles)[0], isNull);
    });
  });

  group('MACD', () {
    test('line is the difference of the fast and slow EMAs', () {
      final candles =
          _fromCloses(List.generate(80, (i) => 100 + i.toDouble()));
      final macd = CandleEngine.computeMacd(candles);

      final fast = CandleEngine.computeEma(candles, 12);
      final slow = CandleEngine.computeEma(candles, 26);

      for (var i = 30; i < candles.length; i++) {
        expect(macd.line[i], closeTo(fast[i]! - slow[i]!, 1e-9));
      }
    });

    test('histogram is line minus signal wherever both exist', () {
      final candles =
          _fromCloses(List.generate(90, (i) => 100 + (i % 7).toDouble()));
      final macd = CandleEngine.computeMacd(candles);

      for (var i = 0; i < candles.length; i++) {
        final line = macd.line[i];
        final signal = macd.signal[i];
        if (line != null && signal != null) {
          expect(macd.hist[i], closeTo(line - signal, 1e-9));
        } else {
          expect(macd.hist[i], isNull);
        }
      }
    });

    test('is all nulls for a series shorter than the slow period', () {
      final macd = CandleEngine.computeMacd(_fromCloses([1, 2, 3]));
      expect(macd.line.every((v) => v == null), isTrue);
      expect(macd.signal.every((v) => v == null), isTrue);
    });
  });

  group('computeAll', () {
    test('every series aligns with the candle count', () {
      final candles =
          _fromCloses(List.generate(250, (i) => 100 + (i % 11).toDouble()));
      final all = CandleEngine.computeAll(candles);

      for (final series in [
        all.ema,
        all.sma,
        all.rsi,
        all.vwap,
        all.macdLine,
        all.macdSignal,
        all.macdHist,
        all.bbUpper,
        all.bbMiddle,
        all.bbLower,
        all.atr,
        all.stochK,
        all.stochD,
        all.superTrend,
      ]) {
        expect(series.length, candles.length);
      }
    });

    test('an empty candle list produces empty series', () {
      final all = CandleEngine.computeAll([]);
      expect(all.ema, isEmpty);
    });

    test('seriesFor maps overlay types and returns null for panels', () {
      final all = CandleEngine.computeAll(_fromCloses([1, 2, 3]));
      expect(all.seriesFor(IndicatorType.ema), isNotNull);
      expect(all.seriesFor(IndicatorType.vwap), isNotNull);
      expect(all.seriesFor(IndicatorType.macd), isNull);
      expect(all.seriesFor(IndicatorType.volume), isNull);
    });
  });

  group('IndicatorType', () {
    test('classifies overlays and panels', () {
      expect(IndicatorType.ema.isPriceOverlay, isTrue);
      expect(IndicatorType.macd.isPriceOverlay, isFalse);
      expect(IndicatorType.macd.isSubPanel, isTrue);
      expect(IndicatorType.volume.isPriceOverlay, isFalse);
      expect(IndicatorType.rsi.isSubPanel, isTrue);
      expect(IndicatorType.atr.isSubPanel, isTrue);
      expect(IndicatorType.superTrend.isPriceOverlay, isTrue);
    });

    test('fromName round-trips and rejects unknown names', () {
      for (final t in IndicatorType.values) {
        expect(IndicatorType.fromName(t.name), t);
      }
      expect(IndicatorType.fromName('nope'), isNull);
    });
  });
}
