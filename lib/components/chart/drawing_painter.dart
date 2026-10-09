/// Drawing painter — renders drawings above the candles.
///
/// Runs in its own CustomPaint layer so moving a trendline repaints the overlay
/// without re-rasterising every candle.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/analysis_tools/painters/analysis_painter.dart';
import 'package:app/components/chart/chart_layout.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/components/chart/drawing_geometry.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/drawing.dart';
import 'package:app/models/instrument.dart';

class DrawingPainter extends CustomPainter {
  final ChartTransform transform;
  final ChartLayout layout;
  final List<Drawing> drawings;

  /// Shape currently being placed, drawn with a dashed preview.
  final Drawing? pending;

  final String? selectedId;
  final ThemePalette colors;

  /// Optional active snap position for visual feedback.
  final Offset? snapIndicator;

  /// Price formatter, used for fib and horizontal-line labels.
  final String Function(double) formatPrice;

  /// Instrument for formatting in measurement labels.
  final Instrument? instrument;

  DrawingPainter({
    required this.transform,
    required this.layout,
    required this.drawings,
    required this.pending,
    required this.selectedId,
    required this.colors,
    required this.formatPrice,
    this.snapIndicator,
    this.instrument,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (transform.isEmpty || !layout.isUsable) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, layout.plotWidth, layout.priceHeight));

    final viewport = Rect.fromLTWH(0, 0, layout.plotWidth, layout.priceHeight).inflate(150);

    // Draw unselected drawings first
    for (final d in drawings) {
      if (d.id == selectedId) continue;
      if (_isVisible(d, viewport)) {
        _paintDrawing(canvas, d, isSelected: false);
      }
    }

    // Bring selected drawing to front
    if (selectedId != null) {
      for (final d in drawings) {
        if (d.id == selectedId) {
          _paintDrawing(canvas, d, isSelected: true);
          break;
        }
      }
    }

    final p = pending;
    if (p != null) _paintDrawing(canvas, p, isPreview: true);

    // Render snap indicator dot / ring if magnet snap is active
    if (snapIndicator != null) {
      _paintSnapIndicator(canvas, snapIndicator!);
    }

    canvas.restore();
  }

  bool _isVisible(Drawing d, Rect viewport) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.isEmpty) return false;

    if (d.tool == DrawingTool.horizontalLine ||
        d.tool == DrawingTool.verticalLine ||
        d.tool == DrawingTool.flatTopBottom) {
      return true;
    }

    for (final pt in pts) {
      if (viewport.contains(pt)) return true;
    }
    final bounds = Rect.fromPoints(pts.first, pts.last);
    return viewport.overlaps(bounds.inflate(100));
  }

  void _paintSnapIndicator(Canvas canvas, Offset p) {
    final fill = Paint()..color = colors.primary.withValues(alpha: 0.25);
    final ring = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final dot = Paint()..color = colors.primary;

    canvas.drawCircle(p, 10, fill);
    canvas.drawCircle(p, 10, ring);
    canvas.drawCircle(p, 3.5, dot);
  }

  void _paintDrawing(
    Canvas canvas,
    Drawing d, {
    bool isSelected = false,
    bool isPreview = false,
  }) {
    final paint = Paint()
      ..color = isPreview ? d.color.withValues(alpha: 0.7) : d.color
      ..strokeWidth = isSelected ? d.strokeWidth + 0.8 : d.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // A single anchor placed so far: show a marker, nothing to connect yet.
    if (d.anchors.length < d.tool.anchorCount &&
        d.tool.anchorCount > 1 &&
        d.anchors.length == 1) {
      final pt = DrawingGeometry.project(d, transform).first;
      canvas.drawCircle(pt, kHandleDrawRadius, Paint()..color = d.color);
      return;
    }

    if (d.tool == DrawingTool.rectangle) {
      _paintRectangle(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.arrow) {
      _paintArrow(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.fibRetracement) {
      _paintFib(canvas, d, paint);
    } else if (d.tool == DrawingTool.fibExtension) {
      _paintFibExtension(canvas, d, paint);
    } else if (d.tool == DrawingTool.text) {
      _paintTextAnnotation(canvas, d, isSelected: isSelected, isPreview: isPreview);
    } else if (d.tool == DrawingTool.measurement) {
      _paintMeasurement(canvas, d, paint, isPreview: isPreview, isSelected: isSelected);
    } else if (d.tool == DrawingTool.flatTopBottom) {
      _paintFlatTopBottom(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.triangle) {
      _paintTriangle(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.parallelChannel) {
      _paintParallelChannel(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.callout) {
      _paintCallout(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.htfOverlay) {
      _paintHtfOverlay(canvas, d, paint, isPreview: isPreview);
    } else if (d.tool == DrawingTool.longPosition || d.tool == DrawingTool.shortPosition) {
      _paintPosition(canvas, d, paint, isPreview: isPreview);
    } else {
      final segments =
          DrawingGeometry.segments(d, transform, chartWidth: layout.plotWidth);
      for (final s in segments) {
        if (isPreview) {
          _dashedLine(canvas, s.a, s.b, paint);
        } else {
          canvas.drawLine(s.a, s.b, paint);
        }
      }
      if (d.tool == DrawingTool.horizontalLine) {
        _paintPriceTag(canvas, d);
      } else if (d.tool == DrawingTool.verticalLine) {
        _paintTimeTag(canvas, d);
      } else if (d.tool == DrawingTool.trendline && (isSelected || isPreview)) {
        _paintAngleBadge(canvas, d);
      }
    }

    if (isSelected) _paintHandles(canvas, d);

    AnalysisPainter.paintIfAnalysis(
      canvas,
      d,
      transform,
      layout,
      colors: colors,
      isSelected: isSelected,
      isPreview: isPreview,
    );
  }

  void _paintAngleBadge(Canvas canvas, Drawing d) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;
    final dx = pts[1].dx - pts[0].dx;
    final dy = pts[1].dy - pts[0].dy;
    if (dx.abs() < 1e-6 && dy.abs() < 1e-6) return;

    final angleRad = math.atan2(-dy, dx);
    final angleDeg = (angleRad * 180.0 / math.pi).round();

    final label = '${angleDeg > 0 ? '+' : ''}$angleDeg°';
    final tp = _text(label, Colors.white, 9);

    final mid = Offset((pts[0].dx + pts[1].dx) / 2, (pts[0].dy + pts[1].dy) / 2);
    final bg = Rect.fromCenter(
      center: mid.translate(0, -14),
      width: tp.width + 10,
      height: tp.height + 4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(bg, const Radius.circular(4)),
      Paint()..color = d.color.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(bg.left + 5, bg.top + 2));
  }

  void _paintArrow(Canvas canvas, Drawing d, Paint paint, {bool isPreview = false}) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;
    final a = pts[0];
    final b = pts[1];

    if (isPreview) {
      _dashedLine(canvas, a, b, paint);
    } else {
      canvas.drawLine(a, b, paint);
    }
    _drawArrowHeadAtTip(canvas, a, b, d.color, d.arrowHeadSize);
  }

  void _drawArrowHeadAtTip(Canvas canvas, Offset from, Offset tip, Color color, double arrowSize) {
    final dir = tip - from;
    final dist = dir.distance;
    if (dist < 4) return;

    final unit = dir / dist;
    final perp = Offset(-unit.dy, unit.dx);

    final left = tip - unit * arrowSize + perp * (arrowSize * 0.4);
    final right = tip - unit * arrowSize - perp * (arrowSize * 0.4);

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintTextAnnotation(
    Canvas canvas,
    Drawing d, {
    bool isSelected = false,
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.isEmpty) return;
    final pt = pts[0];
    final textStr = d.text?.isNotEmpty == true ? d.text! : 'Text';

    final tp = _text(textStr, d.color, d.fontSize);
    const paddingH = 8.0;
    const paddingV = 5.0;
    final rect = Rect.fromLTWH(
      pt.dx,
      pt.dy - tp.height / 2 - paddingV,
      tp.width + paddingH * 2,
      tp.height + paddingV * 2,
    );

    if (d.showBackground) {
      final bgPaint = Paint()
        ..color = colors.card.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        bgPaint,
      );
    }

    if (d.showBorder || isSelected) {
      final borderPaint = Paint()
        ..color = isSelected ? d.color : d.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.8 : 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        borderPaint,
      );
    }

    tp.paint(canvas, Offset(rect.left + paddingH, rect.top + paddingV));
  }

  void _paintRectangle(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;
    final rect = Rect.fromPoints(pts[0], pts[1]);

    final fillColor = d.fillColor ?? d.color.withValues(alpha: isPreview ? 0.08 : 0.14);
    canvas.drawRect(
      rect,
      Paint()..color = fillColor,
    );
    canvas.drawRect(rect, paint);
  }

  void _paintFib(Canvas canvas, Drawing d, Paint paint) {
    final levels = DrawingGeometry.fibLevels(d, transform);
    if (levels.isEmpty) return;

    final pts = DrawingGeometry.project(d, transform);
    final startX = math.min(pts[0].dx, pts[1].dx);

    // Shade the bands between adjacent levels.
    for (var i = 0; i < levels.length - 1; i++) {
      final a = levels[i].y;
      final b = levels[i + 1].y;
      canvas.drawRect(
        Rect.fromLTRB(startX, math.min(a, b), layout.plotWidth, math.max(a, b)),
        Paint()..color = d.color.withValues(alpha: i.isEven ? 0.06 : 0.03),
      );
    }

    final priceAtStart = transform.priceForY(pts[0].dy);
    final priceAtEnd = transform.priceForY(pts[1].dy);

    for (final level in levels) {
      canvas.drawLine(
        Offset(startX, level.y),
        Offset(layout.plotWidth, level.y),
        paint,
      );

      final price = priceAtStart + (priceAtEnd - priceAtStart) * level.level;
      final label = '${(level.level * 100).toStringAsFixed(1)}%  ${formatPrice(price)}';
      final tp = _text(label, d.color, 8.5);
      tp.paint(canvas, Offset(startX + 4, level.y - tp.height - 1.5));
    }
  }

  void _paintFibExtension(Canvas canvas, Drawing d, Paint paint) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;

    final trendPaint = Paint()
      ..color = d.color.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _dashedLine(canvas, pts[0], pts[1], trendPaint);
    if (pts.length >= 3) {
      _dashedLine(canvas, pts[1], pts[2], trendPaint);
    }

    final minX = pts.map((p) => p.dx).reduce(math.min);
    final maxX = math.max(layout.plotWidth, pts.map((p) => p.dx).reduce(math.max));

    final levels = DrawingGeometry.fibExtensionLevels(d, transform);

    for (final level in levels) {
      if (d.isDashed) {
        _dashedLine(canvas, Offset(minX, level.y), Offset(maxX, level.y), paint);
      } else {
        canvas.drawLine(Offset(minX, level.y), Offset(maxX, level.y), paint);
      }

      if (d.showLabel) {
        final label = 'Ext ${level.level.toStringAsFixed(3)}  ${formatPrice(level.price)}';
        final tp = _text(label, d.color, 8.5);
        tp.paint(canvas, Offset(minX + 4, level.y - tp.height - 1.5));
      }
    }
  }

  void _paintPriceTag(Canvas canvas, Drawing d) {
    if (d.anchors.isEmpty) return;
    final y = transform.yForPrice(d.anchors.first.price);
    if (y < 0 || y > layout.priceHeight) return;

    final tp = _text(formatPrice(d.anchors.first.price), Colors.white, 9);
    final rect = Rect.fromLTWH(layout.plotWidth - tp.width - 12, y - tp.height / 2 - 3, tp.width + 10, tp.height + 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = d.color,
    );
    tp.paint(canvas, Offset(rect.left + 5, rect.top + 3));
  }

  void _paintTimeTag(Canvas canvas, Drawing d) {
    if (d.anchors.isEmpty) return;
    final x = transform.xForTimestamp(d.anchors.first.price.toInt());
    final dt = DateTime.fromMillisecondsSinceEpoch(d.anchors.first.timestamp);
    final timeStr = '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final tp = _text(timeStr, Colors.white, 8.5);

    final rect = Rect.fromCenter(
      center: Offset(x, layout.priceHeight - 12),
      width: tp.width + 10,
      height: tp.height + 4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = d.color,
    );
    tp.paint(canvas, Offset(rect.left + 5, rect.top + 2));
  }

  void _paintHandles(Canvas canvas, Drawing d) {
    final hList = DrawingGeometry.handles(d, transform);
    final fill = Paint()..color = colors.background;
    final ring = Paint()
      ..color = d.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final pt in hList) {
      canvas.drawCircle(pt, kHandleDrawRadius, fill);
      canvas.drawCircle(pt, kHandleDrawRadius, ring);
    }
  }

  // ==========================================================
  // MEASUREMENT
  // ==========================================================

  void _paintMeasurement(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
    bool isSelected = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;
    final a = pts[0];
    final b = pts[1];

    // Shaded bounding rectangle.
    final rect = Rect.fromPoints(a, b);
    canvas.drawRect(
      rect,
      Paint()..color = d.color.withValues(alpha: isPreview ? 0.06 : 0.10),
    );

    // Main measurement line.
    if (isPreview) {
      _dashedLine(canvas, a, b, paint);
    } else {
      canvas.drawLine(a, b, paint);
    }

    // Arrow heads.
    _drawArrowHeadAtTip(canvas, b, a, d.color, 10.0);
    _drawArrowHeadAtTip(canvas, a, b, d.color, 10.0);

    // Distance label at midpoint.
    if (d.anchors.length >= 2) {
      final priceDiff = d.anchors[1].price - d.anchors[0].price;
      final pctChange = d.anchors[0].price.abs() > 1e-12
          ? (priceDiff / d.anchors[0].price) * 100.0
          : 0.0;

      final sign = priceDiff >= 0 ? '+' : '';
      final priceStr = formatPrice(priceDiff.abs());
      final label = '$sign${pctChange.toStringAsFixed(2)}%  $sign$priceStr';

      final tp = _text(label, Colors.white, 9.5);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final bg = Rect.fromCenter(
        center: mid.translate(0, -tp.height - 6),
        width: tp.width + 14,
        height: tp.height + 8,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(5)),
        Paint()..color = d.color.withValues(alpha: 0.9),
      );
      tp.paint(canvas, Offset(bg.left + 7, bg.top + 4));
    }
  }

  // ==========================================================
  // FLAT TOP / FLAT BOTTOM, VOLUME PROFILE & TRIANGLE
  // ==========================================================

  void _paintFlatTopBottom(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;

    final minX = math.min(pts[0].dx, pts[1].dx);
    final maxX = math.max(pts[0].dx, pts[1].dx);
    final minY = math.min(pts[0].dy, pts[1].dy);
    final maxY = math.max(pts[0].dy, pts[1].dy);

    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);

    final opacity = isPreview ? d.fillOpacity * 0.5 : d.fillOpacity;
    if (opacity > 0) {
      final fillPaint = Paint()
        ..color = (d.fillColor ?? d.color).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);
    }

    final linePaint = Paint()
      ..color = isPreview ? d.color.withValues(alpha: 0.7) : d.color
      ..strokeWidth = d.strokeWidth
      ..style = PaintingStyle.stroke;

    if (d.isDashed || isPreview) {
      _dashedLine(canvas, Offset(minX, minY), Offset(maxX, minY), linePaint);
      _dashedLine(canvas, Offset(minX, maxY), Offset(maxX, maxY), linePaint);
      _dashedLine(canvas, Offset(minX, minY), Offset(minX, maxY), linePaint);
      _dashedLine(canvas, Offset(maxX, minY), Offset(maxX, maxY), linePaint);
    } else {
      canvas.drawRect(rect, linePaint);
    }

    if (d.showLabel) {
      final labelStr = d.labelText.isNotEmpty ? d.labelText : 'Flat Top/Bottom';
      final tp = _text(labelStr, Colors.white, 9.0);
      final midX = (minX + maxX) / 2;
      final badgeY = minY - tp.height - 6;
      final bg = Rect.fromLTWH(
        midX - tp.width / 2 - 5,
        badgeY,
        tp.width + 10,
        tp.height + 4,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(bg, const Radius.circular(4)),
        Paint()..color = d.color.withValues(alpha: 0.9),
      );
      tp.paint(canvas, Offset(bg.left + 5, bg.top + 2));
    }
  }



  void _paintTriangle(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 3) {
      if (pts.length == 2) {
        if (isPreview) {
          _dashedLine(canvas, pts[0], pts[1], paint);
        } else {
          canvas.drawLine(pts[0], pts[1], paint);
        }
      }
      return;
    }

    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..close();

    if (d.fillOpacity > 0) {
      final fillColor = (d.fillColor ?? d.color).withValues(alpha: d.fillOpacity);
      canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    }

    if (d.isDashed || isPreview) {
      _dashedLine(canvas, pts[0], pts[1], paint);
      _dashedLine(canvas, pts[1], pts[2], paint);
      _dashedLine(canvas, pts[2], pts[0], paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void _paintParallelChannel(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.length < 2) return;

    final a = pts[0];
    final b = pts[1];
    final c = pts.length >= 3 ? pts[2] : pts[1];

    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    Offset offset = Offset.zero;
    if (lenSq >= 1e-6) {
      final tProj = ((c.dx - a.dx) * dx + (c.dy - a.dy) * dy) / lenSq;
      final proj = Offset(a.dx + tProj * dx, a.dy + tProj * dy);
      offset = c - proj;
    }

    final a2 = a + offset;
    final b2 = b + offset;

    final opacity = isPreview ? d.fillOpacity * 0.5 : d.fillOpacity;
    if (opacity > 0) {
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b2.dx, b2.dy)
        ..lineTo(a2.dx, a2.dy)
        ..close();
      final fillPaint = Paint()
        ..color = (d.fillColor ?? d.color).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    final linePaint = Paint()
      ..color = isPreview ? d.color.withValues(alpha: 0.7) : d.color
      ..strokeWidth = d.strokeWidth
      ..style = PaintingStyle.stroke;

    if (d.isDashed || isPreview) {
      _dashedLine(canvas, a, b, linePaint);
      _dashedLine(canvas, a2, b2, linePaint);
      _dashedLine(canvas, a, a2, linePaint);
      _dashedLine(canvas, b, b2, linePaint);
    } else {
      canvas.drawLine(a, b, linePaint);
      canvas.drawLine(a2, b2, linePaint);
      canvas.drawLine(a, a2, linePaint);
      canvas.drawLine(b, b2, linePaint);
    }

    if (d.showMidline) {
      final midA = a + offset * 0.5;
      final midB = b + offset * 0.5;
      final midPaint = Paint()
        ..color = d.color.withValues(alpha: 0.7)
        ..strokeWidth = math.max(1.0, d.strokeWidth - 0.5)
        ..style = PaintingStyle.stroke;
      _dashedLine(canvas, midA, midB, midPaint);
    }
  }



  void _paintCallout(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.isEmpty) return;

    final targetTip = pts[0];
    final boxCenter = pts.length >= 2 ? pts[1] : pts[0] + const Offset(60, -50);

    final content = d.text ?? 'Note';
    final tp = _text(content, Colors.white, 11.5);
    final boxW = math.max(80.0, tp.width + 24.0);
    final boxH = math.max(32.0, tp.height + 16.0);
    final rect = Rect.fromCenter(center: boxCenter, width: boxW, height: boxH);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Stem line from target tip to nearest edge of box
    final stemPaint = Paint()
      ..color = isPreview ? d.color.withValues(alpha: 0.6) : d.color
      ..strokeWidth = math.max(1.5, d.strokeWidth)
      ..style = PaintingStyle.stroke;

    // Find the closest point on the box edge to the target tip
    final clampedX = targetTip.dx.clamp(rect.left, rect.right);
    final clampedY = targetTip.dy.clamp(rect.top, rect.bottom);
    final edgePoint = Offset(clampedX, clampedY);

    canvas.drawLine(targetTip, edgePoint, stemPaint);

    // Small triangle arrowhead at the target tip
    final dir = edgePoint - targetTip;
    final len = dir.distance;
    if (len > 1.0) {
      final norm = dir / len;
      final perp = Offset(-norm.dy, norm.dx);
      const arrowSize = 6.0;
      final arrowPath = Path()
        ..moveTo(targetTip.dx, targetTip.dy)
        ..lineTo(
          targetTip.dx + norm.dx * arrowSize * 2 + perp.dx * arrowSize,
          targetTip.dy + norm.dy * arrowSize * 2 + perp.dy * arrowSize,
        )
        ..lineTo(
          targetTip.dx + norm.dx * arrowSize * 2 - perp.dx * arrowSize,
          targetTip.dy + norm.dy * arrowSize * 2 - perp.dy * arrowSize,
        )
        ..close();
      canvas.drawPath(arrowPath, Paint()..color = d.color);
    }

    // Filled rounded box with border
    final bgPaint = Paint()
      ..color = (d.fillColor ?? d.color).withValues(alpha: isPreview ? 0.5 : d.fillOpacity.clamp(0.5, 0.95))
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = d.color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(rrect, borderPaint);

    // Centered text
    tp.paint(
      canvas,
      Offset(boxCenter.dx - tp.width / 2, boxCenter.dy - tp.height / 2),
    );
  }

  void _paintHtfOverlay(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.isEmpty) return;
    final y = pts[0].dy;

    final linePaint = Paint()
      ..color = isPreview ? d.color.withValues(alpha: 0.7) : d.color
      ..strokeWidth = d.strokeWidth
      ..style = PaintingStyle.stroke;

    if (d.isDashed || isPreview) {
      _dashedLine(canvas, Offset(0, y), Offset(layout.plotWidth, y), linePaint);
    } else {
      canvas.drawLine(Offset(0, y), Offset(layout.plotWidth, y), linePaint);
    }

    final price = d.anchors.first.price;
    final badgeText = '[${d.htfLevelType}] ${formatPrice(price)}';
    final tp = _text(badgeText, Colors.white, 9.5);
    final badgeW = tp.width + 12.0;
    final badgeH = tp.height + 6.0;
    final badgeRect = Rect.fromLTWH(
      layout.plotWidth - badgeW - 4.0,
      y - badgeH / 2,
      badgeW,
      badgeH,
    );
    final badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(4));

    canvas.drawRRect(badgeRRect, Paint()..color = d.color);
    tp.paint(canvas, Offset(badgeRect.left + 6.0, badgeRect.top + 3.0));
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  TextPainter _text(String s, Color color, double size, {FontWeight? fontWeight}) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: fontWeight ?? FontWeight.w600,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  void _paintPosition(
    Canvas canvas,
    Drawing d,
    Paint paint, {
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(d, transform);
    if (pts.isEmpty) return;

    final isLong = d.tool == DrawingTool.longPosition;
    final entryY = pts[0].dy;
    final entryPrice = d.anchors[0].price;

    // Determine stop and target Y positions
    final double stopY;
    final double stopPrice;
    final double targetY;
    final double targetPrice;

    if (pts.length >= 2) {
      stopY = pts[1].dy;
      stopPrice = d.anchors[1].price;
    } else {
      stopY = entryY;
      stopPrice = entryPrice;
    }

    if (pts.length >= 3) {
      targetY = pts[2].dy;
      targetPrice = d.anchors[2].price;
    } else {
      targetY = entryY;
      targetPrice = entryPrice;
    }

    // Calculate box width
    final left = pts[0].dx;
    final right = left + 200.0;

    // Colors
    const profitColor = Color(0xFF26A69A); // Teal green
    const lossColor = Color(0xFFEF5350);   // Red
    final entryColor = d.color;


    // Draw target zone (entry to target)
    if (pts.length >= 3) {
      final targetTop = math.min(entryY, targetY);
      final targetBottom = math.max(entryY, targetY);
      final targetZoneColor = (isLong && targetY < entryY) || (!isLong && targetY > entryY)
          ? profitColor
          : lossColor;
      final targetFill = Paint()
        ..color = targetZoneColor.withValues(alpha: isPreview ? 0.12 : 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(left, targetTop, right, targetBottom),
        targetFill,
      );

      // Target border line
      final targetLinePaint = Paint()
        ..color = targetZoneColor.withValues(alpha: 0.9)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      // Dashed target line
      _dashedLine(canvas, Offset(left, targetY), Offset(right, targetY), targetLinePaint, dash: 4, gap: 3);

      // Target price label
      final priceDiff = targetPrice - entryPrice;
      final pctChange = entryPrice != 0 ? (priceDiff / entryPrice * 100) : 0.0;
      final targetLabel = '${priceDiff >= 0 ? "+" : ""}${priceDiff.toStringAsFixed(2)} (${pctChange.toStringAsFixed(1)}%)';
      final tp = _text(targetLabel, targetZoneColor, 10, fontWeight: FontWeight.w600);
      tp.paint(canvas, Offset(right - tp.width - 8, (targetTop + targetBottom) / 2 - tp.height / 2));
    }

    // Draw stop zone (entry to stop)
    if (pts.length >= 2) {
      final stopTop = math.min(entryY, stopY);
      final stopBottom = math.max(entryY, stopY);
      final stopZoneColor = (isLong && stopY > entryY) || (!isLong && stopY < entryY)
          ? lossColor
          : profitColor;
      final stopFill = Paint()
        ..color = stopZoneColor.withValues(alpha: isPreview ? 0.12 : 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(left, stopTop, right, stopBottom),
        stopFill,
      );

      // Stop border line
      final stopLinePaint = Paint()
        ..color = stopZoneColor.withValues(alpha: 0.9)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      _dashedLine(canvas, Offset(left, stopY), Offset(right, stopY), stopLinePaint, dash: 4, gap: 3);

      // Stop price label
      final priceDiff = stopPrice - entryPrice;
      final pctChange = entryPrice != 0 ? (priceDiff / entryPrice * 100) : 0.0;
      final stopLabel = '${priceDiff >= 0 ? "+" : ""}${priceDiff.toStringAsFixed(2)} (${pctChange.toStringAsFixed(1)}%)';
      final tp = _text(stopLabel, stopZoneColor, 10, fontWeight: FontWeight.w600);
      tp.paint(canvas, Offset(right - tp.width - 8, (stopTop + stopBottom) / 2 - tp.height / 2));
    }

    // Entry line (solid)
    final entryLinePaint = Paint()
      ..color = entryColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(left, entryY), Offset(right, entryY), entryLinePaint);

    // Entry label
    final entryLabel = 'Entry ${entryPrice.toStringAsFixed(2)}';
    final entryTp = _text(entryLabel, Colors.white, 10, fontWeight: FontWeight.w700);
    final entryLabelBg = Rect.fromLTWH(
      left + 4,
      entryY - entryTp.height - 4,
      entryTp.width + 10,
      entryTp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(entryLabelBg, const Radius.circular(3)),
      Paint()..color = entryColor.withValues(alpha: 0.85),
    );
    entryTp.paint(canvas, Offset(left + 9, entryY - entryTp.height - 2));

    // Risk/Reward ratio label
    if (pts.length >= 3) {
      final reward = (targetPrice - entryPrice).abs();
      final risk = (stopPrice - entryPrice).abs();
      final rr = risk > 0 ? (reward / risk) : 0.0;
      final rrLabel = 'R:R  1 : ${rr.toStringAsFixed(2)}';
      final rrTp = _text(rrLabel, Colors.white70, 9, fontWeight: FontWeight.w500);

      final rrBg = Rect.fromLTWH(
        left + 4,
        entryY + 4,
        rrTp.width + 10,
        rrTp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rrBg, const Radius.circular(3)),
        Paint()..color = Colors.black54,
      );
      rrTp.paint(canvas, Offset(left + 9, entryY + 6));
    }

    // Position type icon
    final typeLabel = isLong ? '▲ LONG' : '▼ SHORT';
    final typeColor = isLong ? profitColor : lossColor;
    final typeTp = _text(typeLabel, typeColor, 10, fontWeight: FontWeight.w800);
    final typeBg = Rect.fromLTWH(
      right - typeTp.width - 14,
      entryY - typeTp.height - 4,
      typeTp.width + 10,
      typeTp.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(typeBg, const Radius.circular(3)),
      Paint()..color = Colors.black54,
    );
    typeTp.paint(canvas, Offset(right - typeTp.width - 9, entryY - typeTp.height - 2));
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint, {double dash = 5.0, double gap = 4.0}) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final dir = (to - from) / total;
    var drawn = 0.0;
    while (drawn < total) {
      final segment = math.min(dash, total - drawn);
      canvas.drawLine(from + dir * drawn, from + dir * (drawn + segment), paint);
      drawn += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter old) {
    return old.selectedId != selectedId ||
        old.pending != pending ||
        old.snapIndicator != snapIndicator ||
        old.drawings.length != drawings.length ||
        !identical(old.drawings, drawings) ||
        old.transform.scrollOffset != transform.scrollOffset ||
        old.transform.candleWidth != transform.candleWidth ||
        old.transform.minPrice != transform.minPrice ||
        old.transform.maxPrice != transform.maxPrice ||
        old.colors != colors;
  }
}
