/// Viewport bounds and limit calculations for TradeCanvas navigation engine.
library;

import 'dart:math' as math;

class ViewportBounds {
  /// Zoom limits (pixels per candle width).
  static const double kMinCandleWidth = 1.5;
  static const double kMaxCandleWidth = 80.0;
  static const double kDefaultCandleWidth = 7.0;

  /// Vertical padding applied to autoscaled price range.
  static const double kDefaultPricePadFraction = 0.08;

  /// Default fraction of chart width reserved for future empty space.
  static const double kDefaultFutureOffsetFraction = 0.20;

  /// Elastic resistance overscroll limit in pixels.
  static const double kMaxOverscrollPx = 120.0;

  final double minCandleWidth;
  final double maxCandleWidth;
  final double defaultCandleWidth;
  final double pricePadFraction;
  final double futureOffsetFraction;

  const ViewportBounds({
    this.minCandleWidth = kMinCandleWidth,
    this.maxCandleWidth = kMaxCandleWidth,
    this.defaultCandleWidth = kDefaultCandleWidth,
    this.pricePadFraction = kDefaultPricePadFraction,
    this.futureOffsetFraction = kDefaultFutureOffsetFraction,
  });

  /// Clamp candle width strictly within [minCandleWidth, maxCandleWidth].
  double clampCandleWidth(double width) {
    return width.clamp(minCandleWidth, maxCandleWidth);
  }

  /// Calculate the right empty margin in pixels for a given chart width.
  double getRightOffsetPx(double chartWidth, [double? customFraction]) {
    final frac = (customFraction ?? futureOffsetFraction).clamp(0.0, 0.50);
    return (chartWidth * frac).clamp(0.0, chartWidth * 0.80);
  }

  /// Right anchor X coordinate (center of newest candle when scrollOffset == 0).
  double getRightAnchor(double chartWidth, double candleWidth, [double? customFraction]) {
    final rightMargin = getRightOffsetPx(chartWidth, customFraction);
    return chartWidth - rightMargin - candleWidth / 2;
  }

  /// Max scroll offset to reach the oldest candle on the left.
  double getMaxScrollOffset(int candleCount, double candleWidth, double chartWidth, [double? customFraction]) {
    if (candleCount <= 0 || candleWidth <= 0 || chartWidth <= 0) return 0.0;
    final totalWidth = candleCount * candleWidth;
    final rightMargin = getRightOffsetPx(chartWidth, customFraction);
    return math.max(0.0, totalWidth - (chartWidth - rightMargin));
  }

  /// Min scroll offset allowing scrolling into future space on the right.
  double getMinScrollOffset(double chartWidth, double candleWidth, [double? customFraction]) {
    return -getRightAnchor(chartWidth, candleWidth, customFraction);
  }

  /// Apply elastic spring clamping for scroll offset when dragging beyond edges.
  double applyScrollElasticity({
    required double scrollOffset,
    required double minScroll,
    required double maxScroll,
  }) {
    if (scrollOffset < minScroll) {
      final overscroll = minScroll - scrollOffset;
      final damped = kMaxOverscrollPx * (1 - math.exp(-overscroll / (kMaxOverscrollPx * 1.5)));
      return minScroll - damped;
    }
    if (scrollOffset > maxScroll) {
      final overscroll = scrollOffset - maxScroll;
      final damped = kMaxOverscrollPx * (1 - math.exp(-overscroll / (kMaxOverscrollPx * 1.5)));
      return maxScroll + damped;
    }
    return scrollOffset;
  }

  /// Strict clamping of scroll offset to prevent out-of-bounds positioning on release.
  double clampScrollOffset({
    required double scrollOffset,
    required double minScroll,
    required double maxScroll,
  }) {
    return scrollOffset.clamp(minScroll, maxScroll);
  }
}
