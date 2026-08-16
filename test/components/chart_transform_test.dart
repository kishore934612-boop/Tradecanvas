/// Tests for the data↔pixel transform.
///
/// This is the invariant that makes drawings work: a drawing is stored as
/// (timestamp, price), so if projection is not stable and invertible across
/// zoom and pan, drawings drift off the candles they were anchored to.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/domain/entities/candle_data.dart';

const int _oneHour = 60 * 60 * 1000;
const int _t0 = 1700000000000;

List<CandleData> _candles(int count, {int intervalMs = _oneHour}) {
  return List.generate(
    count,
    (i) => CandleData(
      timestamp: _t0 + i * intervalMs,
      open: 100 + i.toDouble(),
      high: 105 + i.toDouble(),
      low: 95 + i.toDouble(),
      close: 102 + i.toDouble(),
      volume: 10,
    ),
  );
}

ChartTransform _transform({
  int count = 100,
  double candleWidth = 8,
  double scrollOffset = 0,
  double chartWidth = 400,
  double priceHeight = 300,
  double minPrice = 90,
  double maxPrice = 220,
  double rightOffsetFraction = 0.0,
}) {
  return ChartTransform(
    candles: _candles(count),
    candleWidth: candleWidth,
    scrollOffset: scrollOffset,
    chartWidth: chartWidth,
    priceHeight: priceHeight,
    minPrice: minPrice,
    maxPrice: maxPrice,
    intervalMs: _oneHour,
    rightOffsetFraction: rightOffsetFraction,
  );
}

void main() {
  group('price axis', () {
    test('yForPrice and priceForY round-trip', () {
      final t = _transform();
      for (final price in [90.0, 120.5, 175.0, 220.0]) {
        final y = t.yForPrice(price);
        expect(t.priceForY(y), closeTo(price, 1e-9));
      }
    });

    test('min price sits at the bottom, max at the top', () {
      final t = _transform(minPrice: 100, maxPrice: 200, priceHeight: 300);
      expect(t.yForPrice(100), closeTo(300, 1e-9));
      expect(t.yForPrice(200), closeTo(0, 1e-9));
      expect(t.yForPrice(150), closeTo(150, 1e-9));
    });

    test('a zero-width price span does not divide by zero', () {
      final t = _transform(minPrice: 150, maxPrice: 150);
      expect(t.yForPrice(150).isFinite, isTrue);
      expect(t.priceSpan, greaterThan(0));
    });
  });

  group('time axis', () {
    test('newest candle is pinned to the right edge when not scrolled', () {
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      expect(t.xForIndex(99), closeTo(400 - 8 / 2, 1e-9));
    });

    test('xForIndex and indexForX round-trip', () {
      final t = _transform();
      for (final index in [0, 25, 60, 99]) {
        final x = t.xForIndex(index);
        expect(t.indexForX(x), closeTo(index, 1e-9));
      }
    });

    test('xForTimestamp and timestampForX round-trip inside the range', () {
      final t = _transform();
      for (final index in [1, 40, 98]) {
        final ts = _t0 + index * _oneHour;
        final x = t.xForTimestamp(ts);
        expect(t.timestampForX(x), closeTo(ts, 1));
      }
    });

    test('timestamps before the first candle extrapolate backwards', () {
      final t = _transform();
      const before = _t0 - 5 * _oneHour;
      final x = t.xForTimestamp(before);

      // Five intervals to the left of index 0.
      expect(x, closeTo(t.xForIndex(-5), 1e-6));
      expect(t.timestampForX(x), closeTo(before, 1));
    });

    test('timestamps after the last candle extrapolate forwards', () {
      final t = _transform();
      const after = _t0 + 104 * _oneHour;
      final x = t.xForTimestamp(after);

      expect(x, closeTo(t.xForIndex(104), 1e-6));
      expect(t.timestampForX(x), closeTo(after, 1));
    });
  });

  group('drawing anchor stability', () {
    test('an anchor keeps its candle alignment across zoom levels', () {
      // A drawing anchored to candle 40 must stay on candle 40 at any zoom.
      const anchorTs = _t0 + 40 * _oneHour;

      for (final width in [2.0, 5.0, 8.0, 20.0, 40.0]) {
        final t = _transform(candleWidth: width);
        final x = t.xForTimestamp(anchorTs);
        expect(
          t.indexForX(x),
          closeTo(40, 1e-6),
          reason: 'anchor drifted at candleWidth=$width',
        );
      }
    });

    test('an anchor keeps its candle alignment across scroll offsets', () {
      const anchorTs = _t0 + 40 * _oneHour;

      for (final offset in [0.0, 50.0, 200.0, 400.0]) {
        final t = _transform(scrollOffset: offset);
        final x = t.xForTimestamp(anchorTs);
        expect(
          t.indexForX(x),
          closeTo(40, 1e-6),
          reason: 'anchor drifted at scrollOffset=$offset',
        );
      }
    });

    test('an anchor keeps its price across price-range changes', () {
      const anchorPrice = 160.0;

      for (final range in [
        (min: 90.0, max: 220.0),
        (min: 150.0, max: 170.0),
        (min: 0.0, max: 500.0),
      ]) {
        final t = _transform(minPrice: range.min, maxPrice: range.max);
        final y = t.yForPrice(anchorPrice);
        expect(t.priceForY(y), closeTo(anchorPrice, 1e-9));
      }
    });
  });

  group('pan direction (regression: scrolling into history)', () {
    test('increasing scrollOffset moves the newest candle rightward', () {
      // If this decreases instead, panning pushes content away from the
      // visible window rather than revealing older candles from the left.
      final at0 = _transform(scrollOffset: 0);
      final at50 = _transform(scrollOffset: 50);

      const newestIndex = 99;
      expect(
        at50.xForIndex(newestIndex),
        greaterThan(at0.xForIndex(newestIndex)),
      );
      expect(
        at50.xForIndex(newestIndex) - at0.xForIndex(newestIndex),
        closeTo(50, 1e-9),
      );
    });

    test('increasing scrollOffset brings earlier indices into the visible window', () {
      // firstVisibleIndex should fall as scrollOffset grows, i.e. older
      // (lower-index) candles become reachable, not less reachable.
      final unscrolled = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      final scrolled = _transform(
        count: 100,
        candleWidth: 8,
        chartWidth: 400,
        scrollOffset: 200,
      );

      expect(scrolled.firstVisibleIndex, lessThan(unscrolled.firstVisibleIndex));
    });

    test('a candle at the oldest edge becomes visible once scrolled far enough', () {
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      // Fully scrolled to the left: the oldest candle (index 0) should be
      // reachable at or near the left edge of the plot.
      final fullyScrolled = t.copyWith(scrollOffset: t.maxScrollOffset);
      expect(fullyScrolled.firstVisibleIndex, 0);
    });
  });

  group('visible window', () {
    test('reports the indices actually on screen', () {
      // 400px wide, 8px candles -> 50 candles visible, ending at index 99.
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      expect(t.lastVisibleIndex, 99);
      expect(t.firstVisibleIndex, lessThanOrEqualTo(50));
      expect(t.visibleCandleCount, 50);
    });

    test('clamps to the loaded range rather than going negative', () {
      final t = _transform(count: 10, candleWidth: 8, chartWidth: 400);
      expect(t.firstVisibleIndex, 0);
      expect(t.lastVisibleIndex, 9);
    });

    test('maxScrollOffset accounts for total content width', () {
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      expect(t.maxScrollOffset, closeTo(100 * 8 - 400, 1e-9));
    });

    test('maxScrollOffset is zero when content fits', () {
      final t = _transform(count: 10, candleWidth: 8, chartWidth: 400);
      expect(t.maxScrollOffset, 0);
    });

    test('isNearLeftEdge triggers pagination close to the oldest candle', () {
      final full = _transform(count: 100, candleWidth: 8, chartWidth: 400);
      expect(full.isNearLeftEdge(), isFalse);

      final panned = _transform(
        count: 100,
        candleWidth: 8,
        chartWidth: 400,
        scrollOffset: full.maxScrollOffset - 10,
      );
      expect(panned.isNearLeftEdge(), isTrue);
    });
  });

  group('right offset (future space)', () {
    test('reserves specified fraction of chart width as empty space on right', () {
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400, rightOffsetFraction: 0.20);
      expect(t.rightOffsetPx, closeTo(80.0, 1e-9));
      expect(t.xForIndex(99), closeTo(400 - 80 - 4, 1e-9));
    });

    test('allows negative scroll offset to pan further into future space', () {
      final t = _transform(count: 100, candleWidth: 8, chartWidth: 400, rightOffsetFraction: 0.20);
      expect(t.minScrollOffset, lessThan(0));
    });
  });

  test('an empty candle set is reported as empty and does not throw', () {
    const t = ChartTransform(
      candles: [],
      candleWidth: 8,
      scrollOffset: 0,
      chartWidth: 400,
      priceHeight: 300,
      minPrice: 0,
      maxPrice: 1,
      intervalMs: _oneHour,
    );

    expect(t.isEmpty, isTrue);
    expect(t.xForTimestamp(_t0), 0);
    expect(t.nearestIndexForX(100), 0);
  });
}
