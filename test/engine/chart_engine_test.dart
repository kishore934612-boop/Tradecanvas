/// Unit tests for Chart Engine (ChartController + CandleEngine)
///
/// Tests run in complete isolation from Flutter, Provider, and network.
library;

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/chart_controller.dart';
import 'package:app/constants/markets.dart';

// ============================================================
// FIXTURES
// ============================================================

List<ChartCandle> _makeCandles({
  int count = 50,
  double startPrice = 100.0,
  double step = 1.0,
  int startMs = 0,
  int intervalMs = 60000, // 1-minute candles
}) {
  final candles = <ChartCandle>[];
  double price = startPrice;
  for (int i = 0; i < count; i++) {
    final open  = price;
    final close = price + step;
    candles.add(ChartCandle(
      timestamp: startMs + i * intervalMs,
      open:   open,
      high:   close + 0.5,
      low:    open  - 0.5,
      close:  close,
      volume: 100.0,
    ));
    price = close;
  }
  return candles;
}

final _btc = getAssetBySymbol('BTC')!;

// ============================================================
// CANDLE ENGINE — INDICATORS
// ============================================================

void main() {
  // ────────────────────────────────────────────────────────────
  // ChartCandle
  // ────────────────────────────────────────────────────────────
  group('ChartCandle', () {
    test('isBullish when close >= open', () {
      final c = ChartCandle(
        timestamp: 0, open: 100, high: 110, low: 95, close: 105, volume: 1,
      );
      expect(c.isBullish, isTrue);
    });

    test('isBullish false when close < open', () {
      final c = ChartCandle(
        timestamp: 0, open: 105, high: 110, low: 95, close: 100, volume: 1,
      );
      expect(c.isBullish, isFalse);
    });

    test('applyTick updates close / high / low / volume', () {
      final c = ChartCandle(
        timestamp: 0, open: 100, high: 105, low: 98, close: 102, volume: 10,
      );
      c.applyTick(110, tickVolume: 5);
      expect(c.close,  equals(110));
      expect(c.high,   equals(110));
      expect(c.low,    equals(98));   // unchanged
      expect(c.volume, equals(15));
    });

    test('applyTick updates low when price drops', () {
      final c = ChartCandle(
        timestamp: 0, open: 100, high: 105, low: 98, close: 102, volume: 0,
      );
      c.applyTick(90);
      expect(c.low,   equals(90));
      expect(c.close, equals(90));
    });

    test('copyWith preserves data, only changes isLive', () {
      final c = ChartCandle(
        timestamp: 1000, open: 50, high: 60, low: 40, close: 55, volume: 200, isLive: false,
      );
      final copy = c.copyWith(isLive: true);
      expect(copy.isLive,    isTrue);
      expect(copy.open,      equals(50));
      expect(copy.timestamp, equals(1000));
    });
  });

  // ────────────────────────────────────────────────────────────
  // CandleEngine — EMA
  // ────────────────────────────────────────────────────────────
  group('CandleEngine.computeEma', () {
    test('returns all nulls when fewer candles than period', () {
      final candles = _makeCandles(count: 5);
      final ema = CandleEngine.computeEma(candles, 9);
      expect(ema, hasLength(5));
      expect(ema.every((v) => v == null), isTrue);
    });

    test('first non-null appears at index period-1', () {
      final candles = _makeCandles(count: 20);
      final ema = CandleEngine.computeEma(candles, 9);
      expect(ema[8], isNotNull);
      for (int i = 0; i < 8; i++) {
        expect(ema[i], isNull);
      }
    });

    test('EMA9 for a linearly rising series is close to the close price', () {
      // For a steady rising series EMA lags slightly but should be close
      final candles = _makeCandles(count: 50, startPrice: 100.0, step: 1.0);
      final ema = CandleEngine.computeEma(candles, 9);
      final lastEma   = ema.last!;
      final lastClose = candles.last.close;
      expect(lastEma, closeTo(lastClose, 5.0)); // within 5 price units
    });

    test('EMA200 uses correct length output', () {
      final candles = _makeCandles(count: 300);
      final ema = CandleEngine.computeEma(candles, 200);
      expect(ema, hasLength(300));
      expect(ema[199], isNotNull);
      expect(ema[198], isNull);
    });
  });

  // ────────────────────────────────────────────────────────────
  // CandleEngine — SMA
  // ────────────────────────────────────────────────────────────
  group('CandleEngine.computeSma', () {
    test('SMA50 first non-null at index 49', () {
      final candles = _makeCandles(count: 100);
      final sma = CandleEngine.computeSma(candles, 50);
      expect(sma[49], isNotNull);
      expect(sma[48], isNull);
    });

    test('SMA of constant series equals that constant', () {
      final candles = _makeCandles(count: 20, startPrice: 100, step: 0);
      final sma = CandleEngine.computeSma(candles, 10);
      // Every non-null SMA value should equal the close price (101 = open + step=1)
      // with step=0 close = open = 100.0 + 0 = 100.0 after first
      // Actually open=100 close=100 (step=0 means close=open+step=open+0=open)
      for (final v in sma.where((x) => x != null)) {
        expect(v!, closeTo(100.0, 0.01));
      }
    });
  });

  // ────────────────────────────────────────────────────────────
  // CandleEngine — VWAP
  // ────────────────────────────────────────────────────────────
  group('CandleEngine.computeVwap', () {
    test('VWAP returns same length as input', () {
      final candles = _makeCandles(count: 30);
      final vwap = CandleEngine.computeVwap(candles);
      expect(vwap, hasLength(30));
    });

    test('VWAP with zero volume returns null', () {
      final candles = List.generate(5, (i) => ChartCandle(
        timestamp: i * 60000,
        open: 100, high: 101, low: 99, close: 100, volume: 0,
      ));
      final vwap = CandleEngine.computeVwap(candles);
      expect(vwap.every((v) => v == null), isTrue);
    });

    test('VWAP resets at day boundaries', () {
      // Two candles on different days
      final day1 = DateTime(2024, 1, 1, 12).millisecondsSinceEpoch;
      final day2 = DateTime(2024, 1, 2, 12).millisecondsSinceEpoch;
      final candles = [
        ChartCandle(timestamp: day1, open: 100, high: 105, low: 95, close: 100, volume: 1000),
        ChartCandle(timestamp: day2, open: 200, high: 210, low: 190, close: 200, volume: 1000),
      ];
      final vwap = CandleEngine.computeVwap(candles);
      expect(vwap[0], isNotNull);
      expect(vwap[1], isNotNull);
      // After reset, VWAP at day2 should equal day2 typical price
      final typical2 = (210.0 + 190.0 + 200.0) / 3.0;
      expect(vwap[1]!, closeTo(typical2, 0.01));
    });
  });

  // ────────────────────────────────────────────────────────────
  // CandleEngine — MACD
  // ────────────────────────────────────────────────────────────
  group('CandleEngine.computeMacd', () {
    test('MACD returns correct output length', () {
      final candles = _makeCandles(count: 100);
      final macd = CandleEngine.computeMacd(candles);
      expect(macd.line,   hasLength(100));
      expect(macd.signal, hasLength(100));
      expect(macd.hist,   hasLength(100));
    });

    test('MACD line non-null starts at or after index 25 (EMA26-1)', () {
      final candles = _makeCandles(count: 100);
      final macd = CandleEngine.computeMacd(candles);
      // EMA26 first value at index 25, so MACD line first at 25
      for (int i = 0; i < 25; i++) {
        expect(macd.line[i], isNull);
      }
      expect(macd.line[25], isNotNull);
    });

    test('histogram = MACD line - signal where both non-null', () {
      final candles = _makeCandles(count: 100);
      final macd = CandleEngine.computeMacd(candles);
      for (int i = 0; i < 100; i++) {
        if (macd.line[i] != null && macd.signal[i] != null) {
          expect(
            macd.hist[i]!,
            closeTo(macd.line[i]! - macd.signal[i]!, 0.0001),
          );
        }
      }
    });
  });

  // ────────────────────────────────────────────────────────────
  // CandleEngine — computeAll
  // ────────────────────────────────────────────────────────────
  group('CandleEngine.computeAll', () {
    test('all series have correct length', () {
      final candles = _makeCandles(count: 250);
      final ind = CandleEngine.computeAll(candles);
      expect(ind.ema9,       hasLength(250));
      expect(ind.ema21,      hasLength(250));
      expect(ind.ema50,      hasLength(250));
      expect(ind.ema200,     hasLength(250));
      expect(ind.sma50,      hasLength(250));
      expect(ind.sma200,     hasLength(250));
      expect(ind.vwap,       hasLength(250));
      expect(ind.macdLine,   hasLength(250));
      expect(ind.macdSignal, hasLength(250));
      expect(ind.macdHist,   hasLength(250));
    });

    test('empty candles returns empty indicators', () {
      final ind = CandleEngine.computeAll([]);
      expect(ind.ema9,   isEmpty);
      expect(ind.macdLine, isEmpty);
    });
  });

  // ────────────────────────────────────────────────────────────
  // ChartController
  // ────────────────────────────────────────────────────────────
  group('ChartController', () {
    late ChartController controller;

    setUp(() {
      controller = ChartController(
        asset: _btc,
        initialTimeframe: '1m',
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is loading with no candles', () {
      expect(controller.isLoading, isTrue);
      expect(controller.candles,   isEmpty);
      expect(controller.lastPrice, equals(0.0));
    });

    test('loadCandles stores candles and computes indicators', () {
      final candles = _makeCandles(count: 50);
      controller.loadCandles(candles);
      expect(controller.candles,             hasLength(50));
      expect(controller.isLoading,           isFalse);
      expect(controller.indicators.ema9,     hasLength(50));
      expect(controller.indicators.macdLine, hasLength(50));
    });

    test('hasData is true after loading', () {
      controller.loadCandles(_makeCandles(count: 10));
      expect(controller.currentState.hasData, isTrue);
    });

    test('hasData is false with empty candles', () {
      expect(controller.currentState.hasData, isFalse);
    });

    test('setLoading publishes state', () async {
      final states  = <ChartState>[];
      final sub = controller.stateStream.listen(states.add);
      controller.setLoading(false);
      // Allow the broadcast stream to deliver
      await Future.delayed(Duration.zero);
      expect(states, isNotEmpty);
      await sub.cancel();
    });

    test('setTimeframe clears candles and marks loading', () {
      controller.loadCandles(_makeCandles(count: 20));
      controller.setTimeframe('1h');
      expect(controller.timeframe,  equals('1h'));
      expect(controller.candles,    isEmpty);
      expect(controller.isLoading,  isTrue);
    });

    test('applyPriceTick updates live candle close price', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      // Align start to current 1-minute boundary
      final interval = 60000;
      final slot     = (now ~/ interval) * interval;
      final candles  = [
        ChartCandle(
          timestamp: slot,
          open: 50000, high: 50100, low: 49900, close: 50050,
          volume: 1.0, isLive: true,
        ),
      ];
      controller.loadCandles(candles);
      controller.applyPriceTick(50500, now);
      expect(controller.lastPrice, equals(50500));
      expect(controller.candles.last.close, equals(50500));
      expect(controller.candles.last.high,  greaterThanOrEqualTo(50500));
    });

    test('applyPriceTick creates new candle on interval boundary', () {
      final interval = 60000; // 1m
      final slot0    = 1_000_000 * interval; // arbitrary aligned slot
      final slot1    = slot0 + interval;

      final candles = [
        ChartCandle(
          timestamp: slot0,
          open: 100, high: 105, low: 95, close: 102,
          volume: 10, isLive: true,
        ),
      ];
      controller.loadCandles(candles);

      // Tick arrives in next interval
      controller.applyPriceTick(110.0, slot1 + 100);

      expect(controller.candles.length, equals(2));
      expect(controller.candles.last.timestamp, equals(slot1));
      expect(controller.candles.first.isLive,   isFalse);
      expect(controller.candles.last.isLive,    isTrue);
      expect(controller.candles.last.open,      equals(102)); // bridged from prior close
      expect(controller.candles.last.close,     equals(110.0));
    });

    test('stateStream emits on loadCandles', () async {
      final completer = Completer<ChartState>();
      controller.stateStream.first.then(completer.complete);
      controller.loadCandles(_makeCandles(count: 5));
      final state = await completer.future.timeout(const Duration(seconds: 2));
      expect(state.candles, hasLength(5));
      expect(state.isLoading, isFalse);
    });

    test('applyPriceTick ignored when candles empty', () {
      controller.applyPriceTick(50000, DateTime.now().millisecondsSinceEpoch);
      expect(controller.candles, isEmpty);
      expect(controller.lastPrice, equals(0.0));
    });

    test('dispose closes stateStream', () async {
      final ctrl = ChartController(asset: _btc, initialTimeframe: '1h');
      final events = <ChartState>[];
      ctrl.stateStream.listen(events.add, onDone: () {});
      ctrl.loadCandles(_makeCandles(count: 5));
      ctrl.dispose();
      // After dispose, further publishes should not throw
    });
  });

  // ────────────────────────────────────────────────────────────
  // ChartController — price stream integration
  // ────────────────────────────────────────────────────────────
  group('ChartController with priceStream', () {
    test('auto-applies ticks from stream', () async {
      final streamCtrl = StreamController<double>.broadcast();
      final now      = DateTime.now().millisecondsSinceEpoch;
      final interval = 60000;
      final slot     = (now ~/ interval) * interval;

      final controller = ChartController(
        asset: _btc,
        initialTimeframe: '1m',
        priceStream: streamCtrl.stream,
      );

      controller.loadCandles([
        ChartCandle(
          timestamp: slot,
          open: 100, high: 110, low: 90, close: 105,
          volume: 5, isLive: true,
        ),
      ]);

      // Emit a price tick via stream
      streamCtrl.add(120.0);

      // Allow microtask to process
      await Future.delayed(Duration.zero);

      expect(controller.lastPrice, equals(120.0));
      expect(controller.candles.last.close, equals(120.0));

      controller.dispose();
      await streamCtrl.close();
    });
  });

  // ────────────────────────────────────────────────────────────
  // ChartIndicators.empty
  // ────────────────────────────────────────────────────────────
  group('ChartIndicators.empty', () {
    test('creates all-null series of given length', () {
      final ind = ChartIndicators.empty(10);
      expect(ind.ema9.length,   equals(10));
      expect(ind.macdLine.length, equals(10));
      expect(ind.ema9.every((v) => v == null), isTrue);
    });

    test('length 0 gives empty lists', () {
      final ind = ChartIndicators.empty(0);
      expect(ind.ema9,     isEmpty);
      expect(ind.macdLine, isEmpty);
    });
  });
}
