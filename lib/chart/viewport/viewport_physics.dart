/// Physics engine for chart pan momentum, friction decay, edge springs, and focal zooming.
library;

import 'dart:math' as math;
import 'package:app/chart/viewport/viewport_bounds.dart';

class ViewportPhysics {
  /// Friction coefficient for natural exponential fling deceleration.
  static const double kDefaultFriction = 4.2;

  /// Velocity threshold below which momentum stops.
  static const double kStopVelocityThreshold = 10.0;

  final double friction;
  final ViewportBounds bounds;

  const ViewportPhysics({
    this.friction = kDefaultFriction,
    this.bounds = const ViewportBounds(),
  });

  /// Calculate total momentum displacement given initial velocity (px/sec).
  double computeFlingDistance(double initialVelocityX) {
    if (initialVelocityX.abs() < kStopVelocityThreshold) return 0.0;
    return initialVelocityX / friction;
  }

  /// Calculate velocity at elapsed time t (seconds).
  double velocityAtTime(double initialVelocityX, double timeSeconds) {
    return initialVelocityX * math.exp(-friction * timeSeconds);
  }

  /// Calculate displacement at elapsed time t (seconds).
  double displacementAtTime(double initialVelocityX, double timeSeconds) {
    return (initialVelocityX / friction) * (1.0 - math.exp(-friction * timeSeconds));
  }

  /// Total duration (seconds) required for momentum to decay below threshold.
  double flingDuration(double initialVelocityX) {
    final absV = initialVelocityX.abs();
    if (absV < kStopVelocityThreshold) return 0.0;
    return math.log(absV / kStopVelocityThreshold) / friction;
  }

  /// Compute focal zoom scrollOffset adjustment so focalPointX remains anchored.
  ///
  /// Keeps the candle index directly under the user's finger invariant when candleWidth changes.
  double computeFocalZoomScrollOffset({
    required double oldScrollOffset,
    required double oldCandleWidth,
    required double newCandleWidth,
    required double focalPointX,
    required double chartWidth,
    required int candleCount,
    double? futureOffsetFraction,
  }) {
    if (oldCandleWidth <= 0 || newCandleWidth <= 0 || candleCount <= 0) {
      return oldScrollOffset;
    }

    final rightAnchorOld = bounds.getRightAnchor(chartWidth, oldCandleWidth, futureOffsetFraction);
    final rightAnchorNew = bounds.getRightAnchor(chartWidth, newCandleWidth, futureOffsetFraction);

    // Candle index at focalPointX under old geometry
    final fromNewestOld = (rightAnchorOld + oldScrollOffset - focalPointX) / oldCandleWidth;

    // New scroll offset required to keep that same candle index at focalPointX
    final newScrollOffset = focalPointX - rightAnchorNew + (fromNewestOld * newCandleWidth);
    return newScrollOffset;
  }

  /// Clamp velocity if initial fling is excessive.
  double clampVelocity(double velocityX, {double maxVelocity = 4000.0}) {
    return velocityX.clamp(-maxVelocity, maxVelocity);
  }
}
