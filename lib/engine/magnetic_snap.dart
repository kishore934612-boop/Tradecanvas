/// Magnetic snap engine for drawing tools.
///
/// Finds the nearest snap target (candle OHLC, body center, existing drawing
/// anchors, fib levels) based on the active magnetic mode and returns a
/// snapped anchor if one is within range.
library;

import 'dart:math' as math;

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/models/drawing.dart';

enum MagneticMode {
  off,
  weak,
  strong,
  smart;

  String get label {
    switch (this) {
      case MagneticMode.off:
        return 'Off';
      case MagneticMode.weak:
        return 'Weak';
      case MagneticMode.strong:
        return 'Strong';
      case MagneticMode.smart:
        return 'Smart';
    }
  }

  /// The next mode in the cycle (used by the toolbar toggle).
  MagneticMode get next {
    const values = MagneticMode.values;
    return values[(index + 1) % values.length];
  }
}

/// Result of a snap query.
class SnapResult {
  final DrawingAnchor anchor;

  /// The pixel position of the snapped point (for visual feedback).
  final double pixelX;
  final double pixelY;

  const SnapResult({
    required this.anchor,
    required this.pixelX,
    required this.pixelY,
  });
}

class MagnetSnapEngine {
  MagnetSnapEngine._();

  /// Maximum pixel distance for weak snap mode.
  static const double _weakThreshold = 10.0;

  /// Attempt to snap a screen pixel position to the nearest target.
  ///
  /// Returns a [SnapResult] if snapping succeeds, otherwise `null`.
  static SnapResult? snap({
    required double pixelX,
    required double pixelY,
    required MagneticMode mode,
    required ChartTransform transform,
    required List<CandleData> candles,
    required List<Drawing> existingDrawings,
  }) {
    if (mode == MagneticMode.off) return null;
    if (transform.isEmpty) return null;

    final candidates = <_SnapCandidate>[];

    // --- Candle-based targets ---
    final index = transform.nearestIndexForX(pixelX);
    if (index >= 0 && index < candles.length) {
      final c = candles[index];
      final cx = transform.xForIndex(index);

      _addCandidate(candidates, cx, transform.yForPrice(c.open), c.timestamp,
          c.open, pixelX, pixelY);
      _addCandidate(candidates, cx, transform.yForPrice(c.high), c.timestamp,
          c.high, pixelX, pixelY);
      _addCandidate(candidates, cx, transform.yForPrice(c.low), c.timestamp,
          c.low, pixelX, pixelY);
      _addCandidate(candidates, cx, transform.yForPrice(c.close), c.timestamp,
          c.close, pixelX, pixelY);

      // Body center.
      final bodyCenter = (c.open + c.close) / 2.0;
      _addCandidate(candidates, cx, transform.yForPrice(bodyCenter),
          c.timestamp, bodyCenter, pixelX, pixelY);
    }

    // Also check adjacent candles for better snapping.
    for (final offset in [-1, 1]) {
      final adj = index + offset;
      if (adj >= 0 && adj < candles.length) {
        final c = candles[adj];
        final cx = transform.xForIndex(adj);
        _addCandidate(candidates, cx, transform.yForPrice(c.open), c.timestamp,
            c.open, pixelX, pixelY);
        _addCandidate(candidates, cx, transform.yForPrice(c.high), c.timestamp,
            c.high, pixelX, pixelY);
        _addCandidate(candidates, cx, transform.yForPrice(c.low), c.timestamp,
            c.low, pixelX, pixelY);
        _addCandidate(candidates, cx, transform.yForPrice(c.close), c.timestamp,
            c.close, pixelX, pixelY);
      }
    }

    // --- Existing drawing targets ---
    for (final drawing in existingDrawings) {
      for (final anchor in drawing.anchors) {
        final ax = transform.xForTimestamp(anchor.timestamp);
        final ay = transform.yForPrice(anchor.price);
        _addCandidate(
            candidates, ax, ay, anchor.timestamp, anchor.price, pixelX, pixelY);
      }

      // Fib levels.
      if (drawing.tool == DrawingTool.fibRetracement &&
          drawing.anchors.length >= 2) {
        final a0 = drawing.anchors[0];
        final a1 = drawing.anchors[1];
        for (final level in kFibLevels) {
          final price = a0.price + (a1.price - a0.price) * level;
          final ts = a0.timestamp + ((a1.timestamp - a0.timestamp) * level).round();
          final fx = transform.xForTimestamp(ts);
          final fy = transform.yForPrice(price);
          _addCandidate(candidates, fx, fy, ts, price, pixelX, pixelY);
        }
      }

      // Rectangle corners.
      if (drawing.tool == DrawingTool.rectangle &&
          drawing.anchors.length >= 2) {
        final a0 = drawing.anchors[0];
        final a1 = drawing.anchors[1];
        // The two stored anchors are diagonal corners; add the other two.
        for (final corner in [
          DrawingAnchor(timestamp: a0.timestamp, price: a1.price),
          DrawingAnchor(timestamp: a1.timestamp, price: a0.price),
        ]) {
          final cx = transform.xForTimestamp(corner.timestamp);
          final cy = transform.yForPrice(corner.price);
          _addCandidate(
              candidates, cx, cy, corner.timestamp, corner.price, pixelX, pixelY);
        }
      }
    }

    if (candidates.isEmpty) return null;

    // Sort by pixel distance.
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    final best = candidates.first;

    switch (mode) {
      case MagneticMode.off:
        return null;
      case MagneticMode.weak:
        if (best.distance > _weakThreshold) return null;
        return _toResult(best);
      case MagneticMode.strong:
        return _toResult(best);
      case MagneticMode.smart:
        // Smart mode: always snap to candle OHLC if close, otherwise only snap
        // if within a moderate distance.
        if (best.distance <= _weakThreshold * 2) {
          return _toResult(best);
        }
        return null;
    }
  }

  static void _addCandidate(
    List<_SnapCandidate> list,
    double snapX,
    double snapY,
    int timestamp,
    double price,
    double fromX,
    double fromY,
  ) {
    final dx = snapX - fromX;
    final dy = snapY - fromY;
    list.add(_SnapCandidate(
      pixelX: snapX,
      pixelY: snapY,
      timestamp: timestamp,
      price: price,
      distance: math.sqrt(dx * dx + dy * dy),
    ));
  }

  static SnapResult _toResult(_SnapCandidate c) => SnapResult(
        anchor: DrawingAnchor(timestamp: c.timestamp, price: c.price),
        pixelX: c.pixelX,
        pixelY: c.pixelY,
      );
}

class _SnapCandidate {
  final double pixelX;
  final double pixelY;
  final int timestamp;
  final double price;
  final double distance;

  const _SnapCandidate({
    required this.pixelX,
    required this.pixelY,
    required this.timestamp,
    required this.price,
    required this.distance,
  });
}
