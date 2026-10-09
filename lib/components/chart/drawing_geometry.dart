/// Geometry helpers for drawings: projection and hit-testing.
///
/// Kept separate from painting so gesture code can hit-test without a Canvas.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/models/drawing.dart';

/// Tap radius for grabbing a resize handle.
const double kHandleHitRadius = 32.0;

/// Tap distance for selecting a line or edge.
const double kLineHitTolerance = 24.0;

/// Drawn radius of an anchor handle.
const double kHandleDrawRadius = 7.0;

class DrawingGeometry {
  DrawingGeometry._();

  /// Project a drawing's anchors into pixel space.
  static List<Offset> project(Drawing drawing, ChartTransform t) {
    return drawing.anchors
        .map((a) => Offset(t.xForTimestamp(a.timestamp), t.yForPrice(a.price)))
        .toList();
  }

  /// All projected handle positions for dragging (including rectangle corners).
  static List<Offset> handles(Drawing drawing, ChartTransform t) {
    final pts = project(drawing, t);
    if (pts.isEmpty) return const [];

    if (drawing.tool == DrawingTool.rectangle && pts.length >= 2) {
      // 4 corners: topLeft/Anchor0, bottomRight/Anchor1, topRight, bottomLeft
      return [
        pts[0],
        pts[1],
        Offset(pts[1].dx, pts[0].dy),
        Offset(pts[0].dx, pts[1].dy),
      ];
    }
    return pts;
  }

  /// The polyline/segments a drawing occupies, used for both painting and
  /// hit-testing so the two never disagree.
  static List<ChartSegment> segments(
    Drawing drawing,
    ChartTransform t, {
    required double chartWidth,
  }) {
    final pts = project(drawing, t);
    if (pts.isEmpty) return const [];

    switch (drawing.tool) {
      case DrawingTool.trendline:
        if (pts.length < 2) return const [];
        if (drawing.isInfinite) {
          return [
            ChartSegment(
              _extendLeft(pts[0], pts[1], 0),
              _extendRight(pts[0], pts[1], chartWidth),
            )
          ];
        } else if (drawing.isRay) {
          return [ChartSegment(pts[0], _extendRight(pts[0], pts[1], chartWidth))];
        }
        return [ChartSegment(pts[0], pts[1])];

      case DrawingTool.arrow:
        if (pts.length < 2) return const [];
        return [ChartSegment(pts[0], pts[1])];

      case DrawingTool.horizontalLine:
        final y = pts[0].dy;
        return [ChartSegment(Offset(0, y), Offset(chartWidth, y))];

      case DrawingTool.verticalLine:
        final x = pts[0].dx;
        return [ChartSegment(Offset(x, 0), Offset(x, t.priceHeight))];

      case DrawingTool.rectangle:
        if (pts.length < 2) return const [];
        final r = Rect.fromPoints(pts[0], pts[1]);
        return [
          ChartSegment(r.topLeft, r.topRight),
          ChartSegment(r.topRight, r.bottomRight),
          ChartSegment(r.bottomRight, r.bottomLeft),
          ChartSegment(r.bottomLeft, r.topLeft),
        ];

      case DrawingTool.fibRetracement:
        if (pts.length < 2) return const [];
        final out = <ChartSegment>[];
        for (final level in kFibLevels) {
          final y = pts[0].dy + (pts[1].dy - pts[0].dy) * level;
          out.add(ChartSegment(
            Offset(math.min(pts[0].dx, pts[1].dx), y),
            Offset(chartWidth, y),
          ));
        }
        return out;

      case DrawingTool.text:
        if (pts.isEmpty) return const [];
        return [ChartSegment(pts[0], pts[0] + const Offset(40, 0))];

      case DrawingTool.measurement:
        if (pts.length < 2) return const [];
        return [ChartSegment(pts[0], pts[1])];

      case DrawingTool.flatTopBottom:
        if (pts.length < 2) return const [];
        final minX = math.min(pts[0].dx, pts[1].dx);
        final maxX = math.max(pts[0].dx, pts[1].dx);
        final minY = math.min(pts[0].dy, pts[1].dy);
        final maxY = math.max(pts[0].dy, pts[1].dy);
        return [
          ChartSegment(Offset(minX, minY), Offset(maxX, minY)),
          ChartSegment(Offset(minX, maxY), Offset(maxX, maxY)),
          ChartSegment(Offset(minX, minY), Offset(minX, maxY)),
          ChartSegment(Offset(maxX, minY), Offset(maxX, maxY)),
        ];

      case DrawingTool.triangle:
        if (pts.length < 3) {
          if (pts.length == 2) {
            return [ChartSegment(pts[0], pts[1])];
          }
          return const [];
        }
        return [
          ChartSegment(pts[0], pts[1]),
          ChartSegment(pts[1], pts[2]),
          ChartSegment(pts[2], pts[0]),
        ];

      case DrawingTool.parallelChannel:
        if (pts.length < 2) return const [];
        final a = pts[0];
        final b = pts[1];
        final c = pts.length >= 3 ? pts[2] : pts[1];
        final offset = _parallelOffset(a, b, c);
        final a2 = a + offset;
        final b2 = b + offset;
        final segs = [
          ChartSegment(a, b),
          ChartSegment(a2, b2),
          ChartSegment(a, a2),
          ChartSegment(b, b2),
        ];
        if (drawing.showMidline) {
          final midA = a + offset * 0.5;
          final midB = b + offset * 0.5;
          segs.add(ChartSegment(midA, midB));
        }
        return segs;

      case DrawingTool.fibExtension:
        if (pts.length < 2) return const [];
        final segs = <ChartSegment>[];
        segs.add(ChartSegment(pts[0], pts[1]));
        if (pts.length >= 3) {
          segs.add(ChartSegment(pts[1], pts[2]));
        }
        final minX = pts.map((p) => p.dx).reduce(math.min);
        final maxX = pts.map((p) => p.dx).reduce(math.max);
        final levels = fibExtensionLevels(drawing, t);
        for (final lev in levels) {
          segs.add(ChartSegment(Offset(minX, lev.y), Offset(maxX, lev.y)));
        }
        return segs;

      case DrawingTool.callout:
        if (pts.length < 2) return const [];
        return [ChartSegment(pts[0], pts[1])];

      case DrawingTool.htfOverlay:
        if (pts.isEmpty) return const [];
        final y = pts[0].dy;
        return [ChartSegment(Offset(0, y), Offset(chartWidth, y))];

      case DrawingTool.longPosition:
      case DrawingTool.shortPosition:
        if (pts.length < 2) return const [];
        // Entry line, stop line, target line (all horizontal), plus vertical edges
        final entry = pts[0];
        final stop = pts.length >= 2 ? pts[1] : entry;
        final target = pts.length >= 3 ? pts[2] : entry;
        final minX = math.min(entry.dx, math.min(stop.dx, target.dx));
        final maxX = math.max(entry.dx, math.max(stop.dx, target.dx));
        final w = math.max(maxX - minX, 80.0);
        final left = minX;
        final right = left + w;
        return [
          ChartSegment(Offset(left, entry.dy), Offset(right, entry.dy)),
          ChartSegment(Offset(left, stop.dy), Offset(right, stop.dy)),
          if (pts.length >= 3)
            ChartSegment(Offset(left, target.dy), Offset(right, target.dy)),
        ];
    }
  }

  /// Fib level lines as (level, y) pairs, for labelling.
  static List<({double level, double y})> fibLevels(
    Drawing drawing,
    ChartTransform t,
  ) {
    final pts = project(drawing, t);
    if (pts.length < 2) return const [];
    return kFibLevels
        .map((l) => (level: l, y: pts[0].dy + (pts[1].dy - pts[0].dy) * l))
        .toList();
  }

  /// Fib extension levels as (level, price, y) tuples.
  static List<({double level, double price, double y})> fibExtensionLevels(
    Drawing drawing,
    ChartTransform t,
  ) {
    if (drawing.anchors.length < 2) return const [];
    final p0 = drawing.anchors[0].price;
    final p1 = drawing.anchors[1].price;
    final p2 = drawing.anchors.length >= 3 ? drawing.anchors[2].price : p1;
    final deltaP = p1 - p0;

    return kFibExtensionLevels.map((l) {
      final targetPrice = p2 + l * deltaP;
      return (level: l, price: targetPrice, y: t.yForPrice(targetPrice));
    }).toList();
  }

  /// Extend a→b to the right edge, preserving slope.
  static Offset _extendRight(Offset a, Offset b, double chartWidth) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx.abs() < 1e-9) return Offset(b.dx, dy >= 0 ? 1e5 : -1e5);
    final slope = dy / dx;
    final targetX = dx > 0 ? chartWidth : 0.0;
    return Offset(targetX, a.dy + slope * (targetX - a.dx));
  }

  /// Extend a→b to the left edge (x = 0), preserving slope.
  static Offset _extendLeft(Offset a, Offset b, double chartWidth) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx.abs() < 1e-9) return Offset(a.dx, dy >= 0 ? -1e5 : 1e5);
    final slope = dy / dx;
    return Offset(0, a.dy + slope * (0 - a.dx));
  }

  // ==========================================================
  // HIT TESTING
  // ==========================================================

  /// Index of the anchor handle under [point], or null.
  static int? handleAt(Drawing drawing, ChartTransform t, Offset point) {
    final hList = handles(drawing, t);
    for (var i = 0; i < hList.length; i++) {
      if ((hList[i] - point).distance <= kHandleHitRadius) return i;
    }
    return null;
  }

  /// Whether [point] is close enough to select this drawing.
  static bool hitTest(
    Drawing drawing,
    ChartTransform t,
    Offset point, {
    required double chartWidth,
    double tolerance = kLineHitTolerance,
  }) {
    if (handleAt(drawing, t, point) != null) return true;

    final pts = project(drawing, t);
    if (pts.isEmpty) return false;

    if (drawing.tool == DrawingTool.text) {
      final textLen = (drawing.text?.length ?? 4).clamp(4, 30);
      final textWidth = textLen * 8.0 + 16.0;
      final textRect = Rect.fromLTWH(pts[0].dx - 4, pts[0].dy - 14, textWidth, 28);
      if (textRect.inflate(tolerance * 0.5).contains(point)) return true;
    }

    if (drawing.tool == DrawingTool.callout && pts.length >= 2) {
      final textLen = (drawing.text?.length ?? 8).clamp(6, 40);
      final boxW = textLen * 8.0 + 20.0;
      final boxRect = Rect.fromCenter(center: pts[1], width: boxW, height: 32.0);
      if (boxRect.inflate(tolerance).contains(point)) return true;
    }

    if (drawing.tool == DrawingTool.rectangle && pts.length >= 2) {
      final rect = Rect.fromPoints(pts[0], pts[1]);
      // Inside rectangle OR close to borders
      if (rect.inflate(tolerance).contains(point)) return true;
    }

    if (drawing.tool == DrawingTool.horizontalLine || drawing.tool == DrawingTool.htfOverlay) {
      final y = pts[0].dy;
      if ((point.dy - y).abs() <= tolerance) return true;
    }

    if (drawing.tool == DrawingTool.verticalLine) {
      final x = pts[0].dx;
      if ((point.dx - x).abs() <= tolerance) return true;
    }

    if (drawing.tool == DrawingTool.flatTopBottom && pts.length >= 2) {
      final minX = math.min(pts[0].dx, pts[1].dx);
      final maxX = math.max(pts[0].dx, pts[1].dx);
      final minY = math.min(pts[0].dy, pts[1].dy);
      final maxY = math.max(pts[0].dy, pts[1].dy);
      final rect = Rect.fromLTRB(
        minX - tolerance,
        minY - tolerance,
        maxX + tolerance,
        maxY + tolerance,
      );
      if (rect.contains(point)) return true;
    }


    if (drawing.tool == DrawingTool.triangle && pts.length >= 3) {
      if (_isPointInTriangle(point, pts[0], pts[1], pts[2])) return true;
    }

    if (drawing.tool == DrawingTool.parallelChannel && pts.length >= 2) {
      final a = pts[0];
      final b = pts[1];
      final c = pts.length >= 3 ? pts[2] : pts[1];
      final offset = _parallelOffset(a, b, c);
      final a2 = a + offset;
      final b2 = b + offset;
      if (_isPointInTriangle(point, a, b, b2) || _isPointInTriangle(point, a, b2, a2)) {
        return true;
      }
    }

    if (drawing.tool == DrawingTool.longPosition || drawing.tool == DrawingTool.shortPosition) {
      if (pts.length >= 2) {
        final entry = pts[0];
        final stop = pts[1];
        final target = pts.length >= 3 ? pts[2] : entry;
        final minX = math.min(entry.dx, math.min(stop.dx, target.dx));
        final maxX = math.max(entry.dx, math.max(stop.dx, target.dx));
        final w = math.max(maxX - minX, 80.0);
        final left = minX;
        final right = left + w;
        // Stop zone
        final stopRect = Rect.fromLTRB(left, math.min(entry.dy, stop.dy), right, math.max(entry.dy, stop.dy));
        if (stopRect.inflate(tolerance).contains(point)) return true;
        // Target zone
        if (pts.length >= 3) {
          final targetRect = Rect.fromLTRB(left, math.min(entry.dy, target.dy), right, math.max(entry.dy, target.dy));
          if (targetRect.inflate(tolerance).contains(point)) return true;
        }
      }
    }

    for (final seg in segments(drawing, t, chartWidth: chartWidth)) {
      if (_distanceToSegment(point, seg.a, seg.b) <= tolerance) return true;
    }
    return false;
  }

  static bool _isPointInTriangle(Offset p, Offset a, Offset b, Offset c) {
    final d1 = _sign(p, a, b);
    final d2 = _sign(p, b, c);
    final d3 = _sign(p, c, a);

    final hasNeg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    final hasPos = (d1 > 0) || (d2 > 0) || (d3 > 0);

    return !(hasNeg && hasPos);
  }

  static double _sign(Offset p1, Offset p2, Offset p3) {
    return (p1.dx - p3.dx) * (p2.dy - p3.dy) - (p2.dx - p3.dx) * (p1.dy - p3.dy);
  }

  static Offset _parallelOffset(Offset a, Offset b, Offset c) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq < 1e-6) return Offset.zero;
    final tProj = ((c.dx - a.dx) * dx + (c.dy - a.dy) * dy) / lenSq;
    final proj = Offset(a.dx + tProj * dx, a.dy + tProj * dy);
    return c - proj;
  }

  /// Topmost drawing under [point]. Later drawings win, matching paint order.
  static Drawing? topmostAt(
    List<Drawing> drawings,
    ChartTransform t,
    Offset point, {
    required double chartWidth,
  }) {
    for (var i = drawings.length - 1; i >= 0; i--) {
      if (hitTest(drawings[i], t, point, chartWidth: chartWidth)) {
        return drawings[i];
      }
    }
    return null;
  }

  /// Perpendicular distance from [p] to segment a→b.
  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq < 1e-12) return (p - a).distance;

    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return (p - proj).distance;
  }
}

/// A projected line segment in pixel space.
class ChartSegment {
  final Offset a;
  final Offset b;
  const ChartSegment(this.a, this.b);
}
