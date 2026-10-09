/// Immutable Viewport State snapshot representing the chart coordinate frame.
library;

import 'package:flutter/material.dart';
import 'package:app/chart/viewport/viewport_bounds.dart';

@immutable
class ViewportState {
  final double candleWidth;
  final double scrollOffset;
  final double priceScaleRatio;
  final double pricePanOffset;
  final double rightOffsetFraction;
  final bool isScrolledAway;
  final bool isAnimating;
  final double velocityX;
  final Size chartSize;
  final int candleCount;
  final double minPrice;
  final double maxPrice;

  const ViewportState({
    this.candleWidth = ViewportBounds.kDefaultCandleWidth,
    this.scrollOffset = 0.0,
    this.priceScaleRatio = 1.0,
    this.pricePanOffset = 0.0,
    this.rightOffsetFraction = ViewportBounds.kDefaultFutureOffsetFraction,
    this.isScrolledAway = false,
    this.isAnimating = false,
    this.velocityX = 0.0,
    this.chartSize = Size.zero,
    this.candleCount = 0,
    this.minPrice = 0.0,
    this.maxPrice = 1.0,
  });

  /// Compute first visible candle index for viewport culling.
  int getFirstVisibleIndex(ViewportBounds bounds) {
    if (candleCount <= 0 || candleWidth <= 0 || chartSize.width <= 0) return 0;
    final rightAnchor = bounds.getRightAnchor(chartSize.width, candleWidth, rightOffsetFraction);
    final fromNewest = (rightAnchor + scrollOffset) / candleWidth;
    final index = (candleCount - 1) - fromNewest.floor();
    return index.clamp(0, candleCount - 1);
  }

  /// Compute last visible candle index for viewport culling.
  int getLastVisibleIndex(ViewportBounds bounds) {
    if (candleCount <= 0 || candleWidth <= 0 || chartSize.width <= 0) return 0;
    final rightAnchor = bounds.getRightAnchor(chartSize.width, candleWidth, rightOffsetFraction);
    final fromNewest = (rightAnchor + scrollOffset - chartSize.width) / candleWidth;
    final index = (candleCount - 1) - fromNewest.ceil();
    return index.clamp(0, candleCount - 1);
  }

  /// Count of candles fitting visible width.
  int get visibleCandleCount =>
      candleWidth <= 0 || chartSize.width <= 0 ? 0 : (chartSize.width / candleWidth).ceil();

  ViewportState copyWith({
    double? candleWidth,
    double? scrollOffset,
    double? priceScaleRatio,
    double? pricePanOffset,
    double? rightOffsetFraction,
    bool? isScrolledAway,
    bool? isAnimating,
    double? velocityX,
    Size? chartSize,
    int? candleCount,
    double? minPrice,
    double? maxPrice,
  }) {
    return ViewportState(
      candleWidth: candleWidth ?? this.candleWidth,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      priceScaleRatio: priceScaleRatio ?? this.priceScaleRatio,
      pricePanOffset: pricePanOffset ?? this.pricePanOffset,
      rightOffsetFraction: rightOffsetFraction ?? this.rightOffsetFraction,
      isScrolledAway: isScrolledAway ?? this.isScrolledAway,
      isAnimating: isAnimating ?? this.isAnimating,
      velocityX: velocityX ?? this.velocityX,
      chartSize: chartSize ?? this.chartSize,
      candleCount: candleCount ?? this.candleCount,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewportState &&
          runtimeType == other.runtimeType &&
          candleWidth == other.candleWidth &&
          scrollOffset == other.scrollOffset &&
          priceScaleRatio == other.priceScaleRatio &&
          pricePanOffset == other.pricePanOffset &&
          rightOffsetFraction == other.rightOffsetFraction &&
          isScrolledAway == other.isScrolledAway &&
          isAnimating == other.isAnimating &&
          velocityX == other.velocityX &&
          chartSize == other.chartSize &&
          candleCount == other.candleCount &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice;

  @override
  int get hashCode => Object.hash(
        candleWidth,
        scrollOffset,
        priceScaleRatio,
        pricePanOffset,
        rightOffsetFraction,
        isScrolledAway,
        isAnimating,
        velocityX,
        chartSize,
        candleCount,
        minPrice,
        maxPrice,
      );
}
