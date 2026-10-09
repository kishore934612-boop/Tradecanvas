/// Data ↔ pixel projection for the chart.
///
/// Single source of truth for the mapping, shared by the candle painter, the
/// drawing painter and the gesture handlers. Because drawings are stored as
/// (timestamp, price) and projected through this on every frame, they stay
/// pinned to the data under zoom, pan, resize and timeframe changes.
///
/// Time is projected on the candle *index* axis, not linear wall-clock, so
/// candles are evenly spaced. Timestamps outside the loaded range extrapolate
/// using the interval, which keeps drawings anchored off-screen correct.
library;

import 'dart:math' as math;

import 'package:app/chart/viewport/viewport_state.dart';
import 'package:app/domain/entities/candle_data.dart';

class ChartTransform {
  final List<CandleData> candles;

  /// Horizontal pixels per candle, including the gap.
  final double candleWidth;

  /// Pixels panned back from the newest candle. 0 pins the newest to the right.
  final double scrollOffset;

  /// Width of the plot area, excluding the price axis gutter.
  final double chartWidth;

  /// Height of the price panel only.
  final double priceHeight;

  final double minPrice;
  final double maxPrice;

  /// Candle duration in ms, used to extrapolate beyond the loaded range.
  final int intervalMs;

  final double pricePanOffset;

  /// Fraction of chart width reserved for empty space after the latest candle (e.g. 0.20 for 20%).
  final double rightOffsetFraction;

  const ChartTransform({
    required this.candles,
    required this.candleWidth,
    required this.scrollOffset,
    required this.chartWidth,
    required this.priceHeight,
    required this.minPrice,
    required this.maxPrice,
    required this.intervalMs,
    this.pricePanOffset = 0.0,
    this.rightOffsetFraction = 0.20,
  });

  factory ChartTransform.fromViewportState({
    required ViewportState viewport,
    required List<CandleData> candles,
    required double priceHeight,
    required int intervalMs,
  }) {
    return ChartTransform(
      candles: candles,
      candleWidth: viewport.candleWidth,
      scrollOffset: viewport.scrollOffset,
      chartWidth: viewport.chartSize.width,
      priceHeight: priceHeight,
      minPrice: viewport.minPrice,
      maxPrice: viewport.maxPrice,
      intervalMs: intervalMs,
      pricePanOffset: viewport.pricePanOffset,
      rightOffsetFraction: viewport.rightOffsetFraction,
    );
  }

  bool get isEmpty => candles.isEmpty || chartWidth <= 0 || priceHeight <= 0;

  double get priceSpan {
    final span = maxPrice - minPrice;
    return span.abs() < 1e-12 ? 1.0 : span;
  }

  /// Empty space margin on the right of the latest candle in pixels.
  double get rightOffsetPx =>
      (chartWidth * rightOffsetFraction).clamp(0.0, chartWidth * 0.8);

  /// X of the newest candle's centre when not scrolled.
  double get _rightAnchor => chartWidth - rightOffsetPx - candleWidth / 2;

  // ==========================================================
  // TIME AXIS
  // ==========================================================

  /// Centre X for a candle index. Accepts fractional indices for smooth
  /// projection of timestamps that fall between candles.
  ///
  /// `scrollOffset` is added, not subtracted: increasing it shifts the whole
  /// strip to the right, which is what brings older (lower-index) candles —
  /// sitting at negative x by default — into view from the left edge.
  double xForIndex(num index) {
    final fromNewest = (candles.length - 1) - index;
    return _rightAnchor - fromNewest * candleWidth + scrollOffset;
  }

  /// Fractional candle index at pixel X. May fall outside the list bounds.
  double indexForX(double x) {
    final fromNewest = (_rightAnchor + scrollOffset - x) / candleWidth;
    return (candles.length - 1) - fromNewest;
  }

  /// Nearest real candle index at X, clamped to the loaded range.
  int nearestIndexForX(double x) {
    if (candles.isEmpty) return 0;
    return indexForX(x).round().clamp(0, candles.length - 1);
  }

  /// X for an arbitrary timestamp, extrapolating past either end.
  double xForTimestamp(int timestampMs) {
    if (candles.isEmpty || intervalMs <= 0) return 0;
    return xForIndex(_fractionalIndexForTimestamp(timestampMs));
  }

  /// Timestamp at pixel X, extrapolating past either end.
  int timestampForX(double x) {
    if (candles.isEmpty || intervalMs <= 0) {
      return DateTime.now().millisecondsSinceEpoch;
    }
    final index = indexForX(x);

    if (index >= 0 && index <= candles.length - 1) {
      final lower = index.floor().clamp(0, candles.length - 1);
      final upper = index.ceil().clamp(0, candles.length - 1);
      if (lower == upper) return candles[lower].timestamp;
      final t = index - lower;
      final a = candles[lower].timestamp;
      final b = candles[upper].timestamp;
      return (a + (b - a) * t).round();
    }

    // Outside the loaded window: step by the interval from the nearest end.
    if (index < 0) {
      return candles.first.timestamp + (index * intervalMs).round();
    }
    final overshoot = index - (candles.length - 1);
    return candles.last.timestamp + (overshoot * intervalMs).round();
  }

  double _fractionalIndexForTimestamp(int ts) {
    final first = candles.first.timestamp;
    final last = candles.last.timestamp;

    if (ts <= first) {
      return (ts - first) / intervalMs;
    }
    if (ts >= last) {
      return (candles.length - 1) + (ts - last) / intervalMs;
    }

    // Binary search the containing candle, then interpolate within it.
    var lo = 0;
    var hi = candles.length - 1;
    while (lo + 1 < hi) {
      final mid = (lo + hi) >> 1;
      if (candles[mid].timestamp <= ts) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = candles[lo].timestamp;
    final b = candles[hi].timestamp;
    if (b == a) return lo.toDouble();
    return lo + (ts - a) / (b - a);
  }

  // ==========================================================
  // PRICE AXIS
  // ==========================================================

  /// Y for a price. Values outside [minPrice, maxPrice] project off-panel,
  /// which callers clip rather than clamp so lines keep their true slope.
  double yForPrice(double price) {
    return priceHeight - ((price - minPrice) / priceSpan) * priceHeight + pricePanOffset;
  }

  double priceForY(double y) {
    return minPrice + ((priceHeight - (y - pricePanOffset)) / priceHeight) * priceSpan;
  }

  // ==========================================================
  // VISIBLE WINDOW
  // ==========================================================

  int get firstVisibleIndex {
    if (candles.isEmpty) return 0;
    return indexForX(0).floor().clamp(0, candles.length - 1);
  }

  int get lastVisibleIndex {
    if (candles.isEmpty) return 0;
    return indexForX(chartWidth).ceil().clamp(0, candles.length - 1);
  }

  /// How many candles fit across the plot area.
  int get visibleCandleCount =>
      candleWidth <= 0 ? 0 : (chartWidth / candleWidth).ceil();

  /// Max scroll offset that still keeps the oldest candle reachable.
  double get maxScrollOffset {
    final total = candles.length * candleWidth;
    return math.max(0.0, total - (chartWidth - rightOffsetPx));
  }

  /// Minimum scroll offset allowing panning into future space.
  double get minScrollOffset => -_rightAnchor;

  /// True when the user has panned to within [threshold] px of the oldest
  /// loaded candle, used to trigger history pagination.
  bool isNearLeftEdge({double threshold = 200}) {
    return scrollOffset >= maxScrollOffset - threshold;
  }

  ChartTransform copyWith({
    List<CandleData>? candles,
    double? candleWidth,
    double? scrollOffset,
    double? chartWidth,
    double? priceHeight,
    double? minPrice,
    double? maxPrice,
    int? intervalMs,
    double? pricePanOffset,
    double? rightOffsetFraction,
  }) {
    return ChartTransform(
      candles: candles ?? this.candles,
      candleWidth: candleWidth ?? this.candleWidth,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      chartWidth: chartWidth ?? this.chartWidth,
      priceHeight: priceHeight ?? this.priceHeight,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      intervalMs: intervalMs ?? this.intervalMs,
      pricePanOffset: pricePanOffset ?? this.pricePanOffset,
      rightOffsetFraction: rightOffsetFraction ?? this.rightOffsetFraction,
    );
  }
}
