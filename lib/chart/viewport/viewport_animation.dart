/// Animation helpers for double-tap zoom, return-to-live, and viewport resetting.
library;

import 'package:flutter/animation.dart';

class ViewportAnimationTarget {
  final double candleWidth;
  final double scrollOffset;
  final double priceScaleRatio;
  final double pricePanOffset;

  const ViewportAnimationTarget({
    required this.candleWidth,
    required this.scrollOffset,
    this.priceScaleRatio = 1.0,
    this.pricePanOffset = 0.0,
  });
}

class ViewportAnimation {
  static const Duration kDefaultDuration = Duration(milliseconds: 320);
  static const Curve kDefaultCurve = Curves.easeOutCubic;

  /// Interpolate between start and target animation states given a normalized t (0.0 .. 1.0).
  static ViewportAnimationTarget interpolate({
    required ViewportAnimationTarget start,
    required ViewportAnimationTarget target,
    required double t,
  }) {
    final clampedT = t.clamp(0.0, 1.0);
    return ViewportAnimationTarget(
      candleWidth: start.candleWidth + (target.candleWidth - start.candleWidth) * clampedT,
      scrollOffset: start.scrollOffset + (target.scrollOffset - start.scrollOffset) * clampedT,
      priceScaleRatio: start.priceScaleRatio + (target.priceScaleRatio - start.priceScaleRatio) * clampedT,
      pricePanOffset: start.pricePanOffset + (target.pricePanOffset - start.pricePanOffset) * clampedT,
    );
  }
}
