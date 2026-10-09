import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/smc_engine.dart';
import 'package:app/models/smc_type.dart';

List<CandleData> _createSampleCandles(int count) {
  const now = 1000000;
  final candles = <CandleData>[];
  double basePrice = 100.0;

  for (var i = 0; i < count; i++) {
    final t = now + i * 60000;
    final open = basePrice;
    final high = basePrice + 1.5;
    final low = basePrice - 1.5;
    final close = basePrice + (i % 2 == 0 ? 0.8 : -0.8);
    candles.add(CandleData(
      timestamp: t,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: 1000.0,
    ));
    basePrice += (i % 2 == 0 ? 0.3 : -0.2);
  }
  return candles;
}

void main() {
  group('SMC Engine - Models & Settings', () {
    test('SmcSettings toJson and fromJson round-trip', () {
      const settings = SmcSettings(
        opacity: 0.75,
        maxVisibleStructures: 35,
        hideMitigatedFvg: true,
        hideMitigatedOb: true,
        swingSensitivity: 6,
        lookbackBars: 150,
        minBreakoutPct: 0.003,
      );

      final json = settings.toJson();
      final restored = SmcSettings.fromJson(json);

      expect(restored.opacity, 0.75);
      expect(restored.maxVisibleStructures, 35);
      expect(restored.hideMitigatedFvg, isTrue);
      expect(restored.hideMitigatedOb, isTrue);
      expect(restored.swingSensitivity, 6);
      expect(restored.lookbackBars, 150);
      expect(restored.minBreakoutPct, 0.003);
    });

    test('SmcType fromId resolves all enum values', () {
      for (final type in SmcType.values) {
        expect(SmcType.fromId(type.name), equals(type));
        expect(type.label, isNotEmpty);
        expect(type.shortLabel, isNotEmpty);
        expect(type.description, isNotEmpty);
      }
    });
  });

  group('SMC Engine - Detection Logic', () {
    test('Evaluates empty SMC set cleanly', () {
      final candles = _createSampleCandles(50);
      final structures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {},
        settings: const SmcSettings(),
      );
      expect(structures, isEmpty);
    });

    test('Detects Fair Value Gap (FVG) and handles mitigation', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Candle 1: High = 102.0
      candles.add(CandleData(
        timestamp: now,
        open: 100.0,
        high: 102.0,
        low: 99.0,
        close: 101.0,
        volume: 500,
      ));

      // Candle 2: Strong expansion up
      candles.add(CandleData(
        timestamp: now + 60000,
        open: 101.5,
        high: 109.0,
        low: 101.0,
        close: 108.5,
        volume: 2500,
      ));

      // Candle 3: Low = 105.0 -> Gap exists between 102.0 and 105.0
      candles.add(CandleData(
        timestamp: now + 120000,
        open: 108.5,
        high: 112.0,
        low: 105.0,
        close: 111.0,
        volume: 2000,
      ));

      // Pad candles
      for (var i = 3; i < 15; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 111.0 + (i - 3) * 0.5,
          high: 112.0 + (i - 3) * 0.5,
          low: 110.0 + (i - 3) * 0.5,
          close: 111.5 + (i - 3) * 0.5,
          volume: 800,
        ));
      }

      final unmitigatedStructures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.fvg},
        settings: const SmcSettings(),
      );

      expect(unmitigatedStructures, isNotEmpty);
      final fvg = unmitigatedStructures.firstWhere((s) => s.type == SmcType.fvg);
      expect(fvg.isBullish, isTrue);
      expect(fvg.isMitigated, isFalse);

      // Add a retest candle that mitigates the FVG (drops to 101.0)
      candles.add(CandleData(
        timestamp: now + 15 * 60000,
        open: 112.0,
        high: 112.5,
        low: 101.0, // Retests/fills gap below 102.0
        close: 104.0,
        volume: 3000,
      ));

      final mitigatedStructures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.fvg},
        settings: const SmcSettings(),
      );

      expect(mitigatedStructures, isNotEmpty);
      final mitigatedFvg = mitigatedStructures.firstWhere((s) => s.type == SmcType.fvg);
      expect(mitigatedFvg.isMitigated, isTrue);
    });

    test('Detects Order Blocks (OB)', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Base historical candles
      for (var i = 0; i < 10; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 101.0,
          low: 99.0,
          close: 100.0,
          volume: 500,
        ));
      }

      // Bearish candle before displacement
      candles.add(CandleData(
        timestamp: now + 10 * 60000,
        open: 100.0,
        high: 100.5,
        low: 97.0,
        close: 97.5,
        volume: 600,
      ));

      // Strong bullish displacement candle closing above prev high (97.5 -> 106.0)
      candles.add(CandleData(
        timestamp: now + 11 * 60000,
        open: 98.0,
        high: 106.5,
        low: 98.0,
        close: 106.0,
        volume: 3500,
      ));

      // Pad candles
      for (var i = 12; i < 20; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 106.0,
          high: 108.0,
          low: 105.0,
          close: 107.0,
          volume: 800,
        ));
      }

      final structures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.orderBlock},
        settings: const SmcSettings(),
      );

      expect(structures, isNotEmpty);
      final ob = structures.firstWhere((s) => s.type == SmcType.orderBlock && s.isBullish);
      expect(ob.isBullish, isTrue);
    });

    test('Detects Breakouts', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Build consolidation baseline with resistance at 105.0
      for (var i = 0; i < 25; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 100.0,
          high: 105.0,
          low: 98.0,
          close: 101.0,
          volume: 500,
        ));
      }

      // Strong breakout candle closing above 105.0 (close = 112.0)
      candles.add(CandleData(
        timestamp: now + 25 * 60000,
        open: 102.0,
        high: 112.5,
        low: 101.8,
        close: 112.0,
        volume: 3000,
      ));

      final structures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.breakout},
        settings: const SmcSettings(),
      );

      expect(structures, isNotEmpty);
      final breakout = structures.firstWhere((s) => s.type == SmcType.breakout);
      expect(breakout.isBullish, isTrue);
    });

    test('Detects Liquidity Sweeps', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // 1. Establish clear swing low at price 90.0 (index 5)
      for (var i = 0; i < 15; i++) {
        final lowPrice = (i == 5) ? 90.0 : 100.0;
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 102.0,
          high: 105.0,
          low: lowPrice,
          close: 103.0,
          volume: 500,
        ));
      }

      // 2. Candle at index 15 wicks below 90.0 (low = 87.0) but closes back above (close = 92.0)
      candles.add(CandleData(
        timestamp: now + 15 * 60000,
        open: 101.0,
        high: 102.0,
        low: 87.0,
        close: 92.0,
        volume: 2500,
      ));

      final structures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.liquiditySweep},
        settings: const SmcSettings(swingSensitivity: 3),
      );

      expect(structures, isNotEmpty);
      final sweep = structures.firstWhere((s) => s.type == SmcType.liquiditySweep);
      expect(sweep.isBullish, isTrue);
    });

    test('Detects BOS and CHoCH market structure lines', () {
      final candles = <CandleData>[];
      const now = 1000000;

      // Create initial swing low at index 3 (low = 80.0)
      for (var i = 0; i < 6; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 90.0,
          high: 95.0,
          low: (i == 3) ? 80.0 : 88.0,
          close: 91.0,
          volume: 500,
        ));
      }

      // Create swing high at index 9 (high = 110.0)
      for (var i = 6; i < 15; i++) {
        candles.add(CandleData(
          timestamp: now + i * 60000,
          open: 95.0,
          high: (i == 9) ? 110.0 : 100.0,
          low: 90.0,
          close: 96.0,
          volume: 500,
        ));
      }

      // Strong candle close above swing high (close = 115.0)
      candles.add(CandleData(
        timestamp: now + 15 * 60000,
        open: 96.0,
        high: 116.0,
        low: 95.5,
        close: 115.0,
        volume: 3000,
      ));

      final structures = SmcEngine.evaluate(
        candles: candles,
        activeOverlays: {SmcType.bos, SmcType.choch},
        settings: const SmcSettings(swingSensitivity: 2),
      );

      expect(structures, isNotEmpty);
      final hasBosOrChoch = structures.any((s) => s.type == SmcType.bos || s.type == SmcType.choch);
      expect(hasBosOrChoch, isTrue);
    });
  });
}
