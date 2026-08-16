import 'package:flutter_test/flutter_test.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/candle_analytics.dart';
import 'package:app/engine/candle_story.dart';

/// Helper: create a candle list with a single candle at index 0.
List<CandleData> _single(CandleData c) => [c];

/// Helper: build a list of [count] candles with a base price, then append
/// the target candle at the end. Returns (candles, targetIndex).
(List<CandleData>, int) _withHistory({
  required int count,
  required double basePrice,
  required double priceStep,
  required CandleData target,
}) {
  final list = <CandleData>[];
  final startTime = 1000000;
  for (var i = 0; i < count; i++) {
    final price = basePrice + priceStep * i;
    list.add(CandleData(
      timestamp: startTime + i * 60000,
      open: price,
      high: price + 1,
      low: price - 1,
      close: price + priceStep.sign * 0.5,
      volume: 100,
    ));
  }
  list.add(target.copyWith(
    timestamp: startTime + count * 60000,
  ));
  return (list, list.length - 1);
}

/// Generate a story for a single candle (no history).
CandleStory _storyFor(CandleData c) {
  final candles = _single(c);
  final analytics = CandleAnalytics.compute(candles, 0);
  return CandleStoryGenerator.generate(analytics, candles, 0);
}

/// Generate a story for the last candle in a list with history.
CandleStory _storyWithHistory(List<CandleData> candles, int index) {
  final analytics = CandleAnalytics.compute(candles, index);
  return CandleStoryGenerator.generate(analytics, candles, index);
}

void main() {
  group('CandleStoryGenerator', () {
    // ====================================================================
    // 1. Strong Bullish
    // ====================================================================
    test('1. Strong bullish candle', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 110,
        low: 99,
        close: 109.5,
        volume: 500,
      ));

      expect(story.character, CandleCharacter.strongBullish);
      expect(story.direction, 'bullish');
      expect(story.headline, contains('Buyers'));
      expect(story.narrative, contains('Buying pressure'));
      expect(story.narrative, isNot(contains('will rise')));
      expect(story.narrative, isNot(contains('Buy now')));
    });

    // ====================================================================
    // 2. Strong Bearish
    // ====================================================================
    test('2. Strong bearish candle', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 110,
        high: 111,
        low: 100,
        close: 100.5,
        volume: 500,
      ));

      expect(story.character, CandleCharacter.strongBearish);
      expect(story.direction, 'bearish');
      expect(story.headline, contains('Sellers'));
      expect(story.narrative, contains('Selling pressure'));
      expect(story.narrative, isNot(contains('will fall')));
    });

    // ====================================================================
    // 3. Doji
    // ====================================================================
    test('3. Doji candle', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 105,
        low: 95,
        close: 100.2, // body < 10% of range
        volume: 300,
      ));

      expect(story.character, CandleCharacter.doji);
      expect(story.direction, 'neutral');
      expect(story.narrative, contains('indecision'));
    });

    // ====================================================================
    // 4. Hammer
    // ====================================================================
    test('4. Hammer candle', () {
      // Long lower wick, small body at top, tiny upper wick.
      // Body must be > 10% of range to avoid doji classification.
      // Body = 2, Range = 12, Body% = 16.7%, LowerWick = 8 (66.7%)
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 102,
        low: 90,
        close: 102,
        volume: 300,
      ));

      expect(story.character, CandleCharacter.hammer);
      expect(story.narrative, contains('lower'));
      expect(story.narrative, contains('rejection'));
    });

    // ====================================================================
    // 5. Shooting Star
    // ====================================================================
    test('5. Shooting star candle', () {
      // Long upper wick, small body at bottom, tiny lower wick.
      // Body must be > 10% of range to avoid doji classification.
      // Body = 2, Range = 12, Body% = 16.7%, UpperWick = 8 (66.7%)
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 110,
        low: 98,
        close: 98,
        volume: 300,
      ));

      expect(story.character, CandleCharacter.shootingStar);
      expect(story.narrative, contains('upper wick'));
      expect(story.narrative, contains('rejection'));
    });

    // ====================================================================
    // 6. Bullish Rejection
    // ====================================================================
    test('6. Bullish rejection candle', () {
      // Bullish candle with notable upper wick.
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 108,
        low: 99,
        close: 103, // body ~33%, upper wick ~55%
        volume: 300,
      ));

      expect(story.character, CandleCharacter.bullishRejection);
      expect(story.direction, 'bullish');
      expect(story.headline, contains('Resistance'));
    });

    // ====================================================================
    // 7. Bearish Rejection
    // ====================================================================
    test('7. Bearish rejection candle', () {
      // Bearish candle with notable lower wick.
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 108,
        high: 109,
        low: 100,
        close: 105, // body ~33%, lower wick ~55%
        volume: 300,
      ));

      expect(story.character, CandleCharacter.bearishRejection);
      expect(story.direction, 'bearish');
    });

    // ====================================================================
    // 8. Bullish Engulfing
    // ====================================================================
    test('8. Bullish engulfing candle', () {
      final prev = CandleData(
        timestamp: 1000000,
        open: 105,
        high: 106,
        low: 100,
        close: 101,
        volume: 200,
      );
      final curr = CandleData(
        timestamp: 1060000,
        open: 100,
        high: 108,
        low: 99,
        close: 107,
        volume: 400,
      );
      final candles = [prev, curr];
      final story = _storyWithHistory(candles, 1);

      expect(story.character, CandleCharacter.engulfingBullish);
      expect(story.narrative, contains('engulfing'));
    });

    // ====================================================================
    // 9. Bearish Engulfing
    // ====================================================================
    test('9. Bearish engulfing candle', () {
      final prev = CandleData(
        timestamp: 1000000,
        open: 100,
        high: 106,
        low: 99,
        close: 105,
        volume: 200,
      );
      final curr = CandleData(
        timestamp: 1060000,
        open: 106,
        high: 107,
        low: 98,
        close: 99,
        volume: 400,
      );
      final candles = [prev, curr];
      final story = _storyWithHistory(candles, 1);

      expect(story.character, CandleCharacter.engulfingBearish);
      expect(story.narrative, contains('engulfing'));
    });

    // ====================================================================
    // 10. High Volume
    // ====================================================================
    test('10. High volume context', () {
      // Create 20 candles with avg volume ~100, then one with volume 300.
      final (candles, idx) = _withHistory(
        count: 20,
        basePrice: 100,
        priceStep: 0.1,
        target: CandleData(
          timestamp: 0,
          open: 102,
          high: 112,
          low: 101,
          close: 111,
          volume: 300, // 3x average → very high
        ),
      );

      final story = _storyWithHistory(candles, idx);
      expect(
        story.volumeContext,
        anyOf(VolumeContext.high, VolumeContext.veryHigh),
      );
      expect(story.narrative, contains('volume'));
    });

    // ====================================================================
    // 11. Low Volume
    // ====================================================================
    test('11. Low volume context', () {
      final (candles, idx) = _withHistory(
        count: 20,
        basePrice: 100,
        priceStep: 0.1,
        target: CandleData(
          timestamp: 0,
          open: 102,
          high: 112,
          low: 101,
          close: 111,
          volume: 20, // 0.2x average → very low
        ),
      );

      final story = _storyWithHistory(candles, idx);
      expect(
        story.volumeContext,
        anyOf(VolumeContext.low, VolumeContext.veryLow),
      );
      expect(story.narrative.toLowerCase(), contains('volume'));
    });

    // ====================================================================
    // 12. Uptrend Context
    // ====================================================================
    test('12. Uptrend context', () {
      final (candles, idx) = _withHistory(
        count: 25,
        basePrice: 100,
        priceStep: 2.0, // Clearly rising
        target: CandleData(
          timestamp: 0,
          open: 150,
          high: 160,
          low: 149,
          close: 159,
          volume: 100,
        ),
      );

      final story = _storyWithHistory(candles, idx);
      expect(story.trendContext, TrendContext.uptrend);
    });

    // ====================================================================
    // 13. Downtrend Context
    // ====================================================================
    test('13. Downtrend context', () {
      final (candles, idx) = _withHistory(
        count: 25,
        basePrice: 200,
        priceStep: -2.0, // Clearly falling
        target: CandleData(
          timestamp: 0,
          open: 155,
          high: 156,
          low: 145,
          close: 146,
          volume: 100,
        ),
      );

      final story = _storyWithHistory(candles, idx);
      expect(story.trendContext, TrendContext.downtrend);
    });

    // ====================================================================
    // 14. Sideways Context
    // ====================================================================
    test('14. Sideways context', () {
      final (candles, idx) = _withHistory(
        count: 25,
        basePrice: 100,
        priceStep: 0.0, // Flat
        target: CandleData(
          timestamp: 0,
          open: 100,
          high: 103,
          low: 97,
          close: 101,
          volume: 100,
        ),
      );

      final story = _storyWithHistory(candles, idx);
      expect(story.trendContext, TrendContext.sideways);
    });

    // ====================================================================
    // 15. Insufficient Historical Context
    // ====================================================================
    test('15. Insufficient history falls back to unknown trend', () {
      // Only 1 candle — no historical context.
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 110,
        low: 99,
        close: 109,
        volume: 100,
      ));

      expect(story.trendContext, TrendContext.unknown);
    });

    // ====================================================================
    // EDGE CASES
    // ====================================================================

    test('Edge: range is zero does not crash', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 100,
        low: 100,
        close: 100,
        volume: 50,
      ));

      expect(story.headline, isNotEmpty);
      expect(story.narrative, isNotEmpty);
    });

    test('Edge: volume is zero does not crash', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 105,
        low: 95,
        close: 104,
        volume: 0,
      ));

      expect(story.headline, isNotEmpty);
      expect(story.narrative, isNotEmpty);
    });

    test('Edge: no previous candle does not crash', () {
      final story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 110,
        low: 90,
        close: 105,
        volume: 100,
      ));

      expect(story.headline, isNotEmpty);
      expect(story.narrative, isNotEmpty);
    });

    test('Narrative never contains financial advice', () {
      final candles = [
        CandleData(timestamp: 1000000, open: 100, high: 110, low: 90, close: 109, volume: 500),
        CandleData(timestamp: 1060000, open: 109, high: 120, low: 108, close: 119, volume: 600),
      ];

      for (var i = 0; i < candles.length; i++) {
        final analytics = CandleAnalytics.compute(candles, i);
        final story = CandleStoryGenerator.generate(analytics, candles, i);
        final text = '${story.headline} ${story.narrative}'.toLowerCase();

        expect(text, isNot(contains('buy now')));
        expect(text, isNot(contains('sell now')));
        expect(text, isNot(contains('will rise')));
        expect(text, isNot(contains('will fall')));
        expect(text, isNot(contains('should buy')));
        expect(text, isNot(contains('should sell')));
        expect(text, isNot(contains('% buyers')));
        expect(text, isNot(contains('% sellers')));
      }
    });

    // ====================================================================
    // VOLUME CLASSIFICATION
    // ====================================================================

    test('Volume classification thresholds', () {
      // We test via the public generate API with controlled history volumes.
      final candles = <CandleData>[];
      for (var i = 0; i < 21; i++) {
        candles.add(CandleData(
          timestamp: 1000000 + i * 60000,
          open: 100,
          high: 110,
          low: 99,
          close: 109,
          volume: 100, // average = 100
        ));
      }

      // Very low: 0.2x
      candles.last = candles.last.copyWith(volume: 20);
      var a = CandleAnalytics.compute(candles, 20);
      var s = CandleStoryGenerator.generate(a, candles, 20);
      expect(s.volumeContext, VolumeContext.veryLow);

      // Low: 0.6x
      candles.last = candles.last.copyWith(volume: 60);
      a = CandleAnalytics.compute(candles, 20);
      s = CandleStoryGenerator.generate(a, candles, 20);
      expect(s.volumeContext, VolumeContext.low);

      // Average: 1.0x
      candles.last = candles.last.copyWith(volume: 100);
      a = CandleAnalytics.compute(candles, 20);
      s = CandleStoryGenerator.generate(a, candles, 20);
      expect(s.volumeContext, VolumeContext.average);

      // High: 1.5x
      candles.last = candles.last.copyWith(volume: 150);
      a = CandleAnalytics.compute(candles, 20);
      s = CandleStoryGenerator.generate(a, candles, 20);
      expect(s.volumeContext, VolumeContext.high);

      // Very high: 2.5x
      candles.last = candles.last.copyWith(volume: 250);
      a = CandleAnalytics.compute(candles, 20);
      s = CandleStoryGenerator.generate(a, candles, 20);
      expect(s.volumeContext, VolumeContext.veryHigh);
    });

    // ====================================================================
    // MOMENTUM LEVELS
    // ====================================================================

    test('Momentum levels vary with body size', () {
      // Strong: large body, body ~86%
      var story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 107.5,
        low: 100,
        close: 107,
        volume: 100,
      ));
      expect(story.momentum, MomentumLevel.strong);

      // Weak: tiny body (doji-like), body ~2%
      story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 105,
        low: 95,
        close: 100.2,
        volume: 100,
      ));
      expect(story.momentum, MomentumLevel.weak);
    });

    // ====================================================================
    // REJECTION LEVELS
    // ====================================================================

    test('Rejection levels based on wick size', () {
      // Strong upper rejection: upper wick > 50%
      var story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 110,
        low: 99,
        close: 103,
        volume: 100,
      ));
      expect(story.upperRejection, RejectionLevel.strong);

      // No rejection: minimal wicks
      story = _storyFor(CandleData(
        timestamp: 1000000,
        open: 100,
        high: 109,
        low: 99,
        close: 108.5,
        volume: 100,
      ));
      expect(story.upperRejection, RejectionLevel.none);
    });
  });
}
