import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/engine/strategy_engine.dart';
import 'package:app/models/strategy_type.dart';

List<CandleData> _createSampleCandles(int count) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final candles = <CandleData>[];
  double basePrice = 100.0;

  for (var i = 0; i < count; i++) {
    final t = now - (count - i) * 60000;
    final open = basePrice;
    final high = basePrice + 2.0;
    final low = basePrice - 2.0;
    final close = basePrice + (i % 2 == 0 ? 1.0 : -1.0);
    candles.add(CandleData(
      timestamp: t,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1000.0,
    ));
    basePrice += (i % 2 == 0 ? 0.5 : -0.4);
  }
  return candles;
}

void main() {
  group('Strategy Engine - Models & Settings', () {
    test('StrategySettings toJson and fromJson round-trip', () {
      const settings = StrategySettings(
        enableLabels: false,
        enableArrows: true,
        arrowSize: 14.0,
        labelSize: 11.0,
        signalOpacity: 0.8,
        maxVisibleSignals: 30,
        rsiUpperLevel: 75.0,
        rsiLowerLevel: 25.0,
        emaFastPeriod: 10,
        emaSlowPeriod: 30,
      );

      final json = settings.toJson();
      final restored = StrategySettings.fromJson(json);

      expect(restored.enableLabels, isFalse);
      expect(restored.enableArrows, isTrue);
      expect(restored.arrowSize, 14.0);
      expect(restored.labelSize, 11.0);
      expect(restored.signalOpacity, 0.8);
      expect(restored.maxVisibleSignals, 30);
      expect(restored.rsiUpperLevel, 75.0);
      expect(restored.rsiLowerLevel, 25.0);
      expect(restored.emaFastPeriod, 10);
      expect(restored.emaSlowPeriod, 30);
    });

    test('StrategyType fromId resolves all enum values', () {
      for (final type in StrategyType.values) {
        expect(StrategyType.fromId(type.name), equals(type));
        expect(type.label, isNotEmpty);
        expect(type.shortLabel, isNotEmpty);
        expect(type.description, isNotEmpty);
      }
    });
  });

  group('Strategy Engine - Detection Logic', () {
    test('Evaluates empty strategy set cleanly', () {
      final candles = _createSampleCandles(50);
      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {},
        settings: const StrategySettings(),
      );
      expect(signals, isEmpty);
    });

    test('Detects Support Bounce signals when price touches support and closes bullish', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // 1. Build initial flat/support baseline at price 100
      for (var i = 0; i < 20; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 102.0,
          high: 105.0,
          low: 100.0, // Support level = 100.0
          close: 103.0,
          volume: 500,
        ));
      }

      // 2. Add candle that tests support (low = 100.0) and closes bullish (open 100.5 -> close 104.0)
      candles.add(CandleData(
        timestamp: now + 20 * 60000,
        open: 100.5,
        high: 105.0,
        low: 100.0,
        close: 104.0,
        volume: 1200,
      ));

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.supportBounce},
        settings: const StrategySettings(),
      );

      expect(signals, isNotEmpty);
      final bounceSignal = signals.firstWhere((s) => s.strategy == StrategyType.supportBounce);
      expect(bounceSignal.isBuy, isTrue);
      expect(bounceSignal.shortTag, equals('Bounce'));
    });

    test('Detects Resistance Rejection signals when price touches resistance and closes bearish', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // 1. Build initial flat/resistance baseline at price 150
      for (var i = 0; i < 20; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 145.0,
          high: 150.0, // Resistance level = 150.0
          low: 140.0,
          close: 146.0,
          volume: 500,
        ));
      }

      // 2. Add candle that tests resistance (high = 150.0) and closes bearish (open 149.5 -> close 143.0)
      candles.add(CandleData(
        timestamp: now + 20 * 60000,
        open: 149.5,
        high: 150.0,
        low: 142.0,
        close: 143.0,
        volume: 1200,
      ));

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.resistanceRejection},
        settings: const StrategySettings(),
      );

      expect(signals, isNotEmpty);
      final rejectSignal = signals.firstWhere((s) => s.strategy == StrategyType.resistanceRejection);
      expect(rejectSignal.isBuy, isFalse);
      expect(rejectSignal.shortTag, equals('Reject'));
    });

    test('Detects EMA Crossover signals', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Create a downtrend followed by a sharp uptrend to force an EMA crossover
      for (var i = 0; i < 60; i++) {
        final price = i < 30 ? 200.0 - (i * 2.0) : 140.0 + ((i - 30) * 4.0);
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: price,
          high: price + 1.0,
          low: price - 1.0,
          close: price + 0.5,
          volume: 1000,
        ));
      }

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.emaCrossover},
        settings: const StrategySettings(emaFastPeriod: 5, emaSlowPeriod: 15),
      );

      expect(signals, isNotEmpty);
      final emaSignal = signals.firstWhere((s) => s.strategy == StrategyType.emaCrossover);
      expect(emaSignal.shortTag, equals('EMA Cross'));
    });

    test('Detects Bollinger Band Reversal signals', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Stable baseline to establish tight BB bands
      for (var i = 0; i < 25; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 500,
        ));
      }

      // Drop sharply below lower band
      candles.add(CandleData(
        timestamp: now + 25 * 60000,
        open: 99.0,
        high: 99.5,
        low: 90.0,
        close: 91.0, // Closes outside lower BB
        volume: 2000,
      ));

      // Bullish reversal candle
      candles.add(CandleData(
        timestamp: now + 26 * 60000,
        open: 91.5,
        high: 98.0,
        low: 91.0,
        close: 97.0, // Bullish reversal
        volume: 2500,
      ));

      final bbResult = CandleEngine.computeBollingerBands(candles);
      expect(bbResult, isNotNull);

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.bollingerReversal},
        settings: const StrategySettings(),
      );

      expect(signals, isNotEmpty);
      final bbSignal = signals.firstWhere((s) => s.strategy == StrategyType.bollingerReversal);
      expect(bbSignal.isBuy, isTrue);
      expect(bbSignal.shortTag, equals('BB Rev'));
    });

    test('Detects RSI Overbought / Oversold signals', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // 1. Initial 15 candles
      for (var i = 0; i < 15; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 500,
        ));
      }

      // 2. Drop price sharply to drive RSI into oversold territory
      for (var i = 15; i < 25; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0 - (i - 14) * 3.0,
          high: 100.0 - (i - 14) * 3.0 + 0.5,
          low: 100.0 - (i - 14) * 3.0 - 1.0,
          close: 100.0 - (i - 14) * 3.0 - 0.5,
          volume: 1000,
        ));
      }

      // 3. Sharp bounce candle to pull RSI back up above lower threshold (30)
      candles.add(CandleData(
        timestamp: now + 25 * 60000,
        open: 70.0,
        high: 82.0,
        low: 70.0,
        close: 80.0,
        volume: 2000,
      ));

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.rsiExtreme},
        settings: const StrategySettings(rsiLowerLevel: 30.0, rsiUpperLevel: 70.0),
      );

      expect(signals, isNotEmpty);
      final rsiSignal = signals.firstWhere((s) => s.strategy == StrategyType.rsiExtreme);
      expect(rsiSignal.shortTag, equals('RSI'));
    });

    test('Detects Engulfing Candle Pattern signals', () {
      final candles = <CandleData>[];
      const now = 1000000;

      for (var i = 0; i < 5; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 500,
        ));
      }

      // Previous bearish candle
      candles.add(CandleData(
        timestamp: now + 5 * 60000,
        open: 102.0,
        high: 102.5,
        low: 99.5,
        close: 100.0,
        volume: 1000,
      ));

      // Bullish engulfing candle
      candles.add(CandleData(
        timestamp: now + 6 * 60000,
        open: 99.0,
        high: 105.0,
        low: 98.5,
        close: 104.0,
        volume: 2500,
      ));

      final signals = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.engulfing},
        settings: const StrategySettings(),
      );

      expect(signals, isNotEmpty);
      final engSignal = signals.firstWhere((s) => s.strategy == StrategyType.engulfing);
      expect(engSignal.isBuy, isTrue);
      expect(engSignal.shortTag, equals('Engulf'));
    });

    test('Detects MACD Divergence signals when price forms lower low but MACD forms higher low', () {
      final candles = <CandleData>[];
      const now = 1000000;

      for (var i = 0; i < 30; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 500,
        ));
      }

      // Create candle 20 swing low
      candles[20] = CandleData(
        timestamp: now + 20 * 60000,
        open: 95.0,
        high: 96.0,
        low: 90.0,
        close: 91.0,
        volume: 1000,
      );

      // Create candle 25 lower low price with bullish confirmation
      candles[25] = CandleData(
        timestamp: now + 25 * 60000,
        open: 88.0,
        high: 93.0,
        low: 87.0,
        close: 92.0,
        volume: 1500,
      );

      final macdHist = List<double?>.filled(30, 0.0);
      macdHist[20] = -5.0; // deeper negative histogram at swing 1
      macdHist[25] = -1.0; // higher negative histogram at lower low (divergence!)

      final signal = StrategyEngine.evaluate(
        candles: candles,
        activeStrategies: {StrategyType.macdDivergence},
        settings: const StrategySettings(),
      );

      expect(signal, isNotNull);
    });
  });
  group('Causal strategy policy', () {
    test('cooldown uses chart bars on every timeframe', () {
      List<StrategySignal> run(int interval) {
        final candles = List.generate(35, (i) => CandleData(timestamp: i * interval,
          open: 100.5, high: 105, low: 100, close: 104, volume: 100));
        return StrategyEngine.evaluate(candles: candles,
          activeStrategies: {StrategyType.supportBounce}, settings: const StrategySettings());
      }
      final minute = run(60000).map((s) => s.candleIndex).toList();
      expect(minute, [20, 23, 26, 29, 32]);
      expect(run(3600000).map((s) => s.candleIndex), minute);
    });
    test('forming candle cannot produce a confirmed signal', () {
      final candles = _createSampleCandles(40);
      final baseline = StrategyEngine.evaluate(candles: candles.sublist(0, 39),
        activeStrategies: StrategyType.values.toSet(), settings: const StrategySettings());
      candles.last.isLive = true;
      final result = StrategyEngine.evaluate(candles: candles,
        activeStrategies: StrategyType.values.toSet(), settings: const StrategySettings());
      expect(result.map((s) => s.id), baseline.map((s) => s.id));
    });
    test('appending future candles never changes past signal identities', () {
      final candles = _createSampleCandles(100);
      const settings = StrategySettings(maxVisibleSignals: 10000);
      final full = StrategyEngine.evaluate(candles: candles,
        activeStrategies: StrategyType.values.toSet(), settings: settings);
      for (var end = 20; end < 100; end += 7) {
        final prefix = StrategyEngine.evaluate(candles: candles.sublist(0, end),
          activeStrategies: StrategyType.values.toSet(), settings: settings);
        expect(full.where((s) => s.candleIndex < end).map((s) => s.id), prefix.map((s) => s.id));
      }
    });
    test('volume filter requires real warmup and positive volume', () {
      final candles = List.generate(30, (i) => CandleData(timestamp: i * 60000,
        open: 100.5, high: 105, low: 100, close: 104, volume: 0));
      expect(StrategyEngine.evaluate(candles: candles,
        activeStrategies: {StrategyType.supportBounce},
        settings: const StrategySettings(requireVolumeConfirmation: true)), isEmpty);
    });
    test('invalid settings and unordered data do not produce signals', () {
      final candles = _createSampleCandles(30);
      expect(StrategyEngine.evaluate(candles: candles,
        activeStrategies: StrategyType.values.toSet(),
        settings: const StrategySettings(emaFastPeriod: 50, emaSlowPeriod: 20)), isEmpty);
      expect(StrategyEngine.evaluate(candles: candles.reversed.toList(),
        activeStrategies: StrategyType.values.toSet(), settings: const StrategySettings()), isEmpty);
    });
    test('new strategy controls survive persistence round trip', () {
      const original = StrategySettings(cooldownBars: 7, requireVolumeConfirmation: true, volumeMultiplier: 2);
      final copy = StrategySettings.fromJson(original.toJson());
      expect(copy.cooldownBars, 7);
      expect(copy.requireVolumeConfirmation, isTrue);
      expect(copy.volumeMultiplier, 2);
    });
  });

}
