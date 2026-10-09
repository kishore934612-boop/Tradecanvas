/// Smart Money Concepts (SMC) Overlay Painter.
///
/// TradingView-grade rendering for Breakout levels, FVG rectangles, Order Blocks, Liquidity Sweeps, BOS, and CHoCH lines.
/// Features viewport culling, label collision avoidance, priority layering, and adaptive opacity.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/smc_type.dart';

class SmcPainter extends CustomPainter {
  final ChartTransform transform;
  final List<SmcStructure> structures;
  final SmcSettings settings;
  final ThemePalette colors;
  final double plotWidth;

  SmcPainter({
    required this.transform,
    required this.structures,
    required this.settings,
    required this.colors,
    required this.plotWidth,
  });

  static const Color blueColor = Color(0xFF2962FF);
  static const Color purpleColor = Color(0xFFA855F7);
  static const Color yellowColor = Color(0xFFFFD600);
  static const Color greenColor = Color(0xFF26A69A);
  static const Color redColor = Color(0xFFEF5350);

  final List<Rect> _labelRects = [];

  @override
  void paint(Canvas canvas, Size size) {
    if (structures.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotWidth, transform.priceHeight));

    _labelRects.clear();

    // Priority Layering:
    // 1. Order Blocks
    // 2. Fair Value Gaps
    // 3. Liquidity Sweeps
    // 4. Breakouts
    // 5. BOS / CHoCH Structure Lines
    final sorted = List<SmcStructure>.from(structures);
    sorted.sort((a, b) => _priority(a.type).compareTo(_priority(b.type)));

    final latestSweepId = _findLatestSweepId(structures);

    for (var idx = 0; idx < sorted.length; idx++) {
      final s = sorted[idx];
      final startX = transform.xForTimestamp(s.timestamp);
      final endX = s.endTimestamp != null
          ? transform.xForTimestamp(s.endTimestamp!)
          : plotWidth;

      // 1. Viewport Culling: skip off-screen rendering
      final minX = math.min(startX, endX);
      final maxX = math.max(startX, endX);
      if (maxX < -100 || minX > plotWidth + 100) continue;

      final y = transform.yForPrice(s.price);
      if (y < -150 || y > size.height + 150) continue;

      final ageRank = sorted.length - 1 - idx;

      switch (s.type) {
        case SmcType.orderBlock:
          _drawOrderBlock(canvas, s, startX, ageRank);
          break;
        case SmcType.fvg:
          _drawFvg(canvas, s, startX, endX, ageRank);
          break;
        case SmcType.liquiditySweep:
          _drawLiquiditySweep(canvas, s, startX, isNewest: s.id == latestSweepId);
          break;
        case SmcType.breakout:
          _drawBreakout(canvas, s, startX, ageRank);
          break;
        case SmcType.bos:
          _drawStructureLine(canvas, s, startX, endX, isChoch: false);
          break;
        case SmcType.choch:
          _drawStructureLine(canvas, s, startX, endX, isChoch: true);
          break;
        case SmcType.equalLevel:
          _drawEqualLevel(canvas, s, startX, endX);
          break;
      }
    }

    canvas.restore();
  }

  int _priority(SmcType type) {
    switch (type) {
      case SmcType.orderBlock:
        return 1;
      case SmcType.fvg:
        return 2;
      case SmcType.liquiditySweep:
        return 3;
      case SmcType.breakout:
        return 4;
      case SmcType.bos:
      case SmcType.choch:
        return 5;
      case SmcType.equalLevel:
        return 6;
    }
  }

  String? _findLatestSweepId(List<SmcStructure> list) {
    final sweeps = list.where((s) => s.type == SmcType.liquiditySweep).toList();
    if (sweeps.isEmpty) return null;
    sweeps.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sweeps.last.id;
  }

  // 1. Draw Order Block Zone
  void _drawOrderBlock(Canvas canvas, SmcStructure s, double startX, int ageRank) {
    final topY = transform.yForPrice(math.max(s.price, s.secondaryPrice));
    final bottomY = transform.yForPrice(math.min(s.price, s.secondaryPrice));
    final baseColor = s.isBullish ? greenColor : redColor;

    // Adaptive Opacity: Current OB 30%, Old 15%, Touched/Mitigated 8%
    final baseAlpha = s.isMitigated
        ? 0.08
        : (ageRank == 0 ? 0.30 : 0.15);
    final alpha = (baseAlpha * settings.opacity).clamp(0.05, 0.90);

    final rect = Rect.fromLTRB(startX, topY, plotWidth, bottomY);
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha: alpha * 2.0)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), borderPaint);

    if (!s.isMitigated) {
      final labelPos = Offset(rect.left + 6, rect.top + 3);
      _drawText(
        canvas,
        labelPos,
        s.isBullish ? 'Bullish OB' : 'Bearish OB',
        baseColor.withValues(alpha: settings.opacity),
        fontSize: 9.5,
      );
    }
  }

  // 2. Draw Fair Value Gap (FVG) Imbalance Zone
  void _drawFvg(Canvas canvas, SmcStructure s, double startX, double endX, int ageRank) {
    final topY = transform.yForPrice(math.max(s.price, s.secondaryPrice));
    final bottomY = transform.yForPrice(math.min(s.price, s.secondaryPrice));
    final baseColor = s.isBullish ? greenColor : redColor;

    // Adaptive Opacity: Current FVG 30%, Old 10%
    final baseAlpha = s.isMitigated ? 0.08 : (ageRank == 0 ? 0.30 : 0.10);
    final alpha = (baseAlpha * settings.opacity).clamp(0.05, 0.90);

    final rect = Rect.fromLTRB(startX, topY, math.max(startX + 80, endX), bottomY);
    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = baseColor.withValues(alpha: alpha * 1.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), borderPaint);

    if (!s.isMitigated) {
      _drawText(
        canvas,
        Offset(rect.left + 6, rect.top + 3),
        s.isBullish ? 'Bullish FVG' : 'Bearish FVG',
        baseColor.withValues(alpha: settings.opacity),
        fontSize: 9.0,
      );
    }
  }

  // 3. Draw Liquidity Sweep (Small Icons ▲ / ▼)
  void _drawLiquiditySweep(Canvas canvas, SmcStructure s, double x, {required bool isNewest}) {
    final y = transform.yForPrice(s.price);
    final opacity = settings.opacity;

    // Yellow dashed line
    final linePaint = Paint()
      ..color = yellowColor.withValues(alpha: opacity * 0.7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedLine(canvas, Offset(x - 30, y), Offset(x + 30, y), linePaint);
    _drawArrow(canvas, Offset(x, s.isBullish ? y + 10 : y - 10), s.isBullish, yellowColor.withValues(alpha: opacity));

    // Display text label ONLY for the newest sweep
    if (isNewest) {
      _drawBadge(
        canvas,
        Offset(x, s.isBullish ? y + 24 : y - 24),
        'Liquidity Sweep',
        yellowColor.withValues(alpha: opacity),
        textColor: Colors.black,
      );
    }
  }

  // 4. Draw Breakout Level & Label
  void _drawBreakout(Canvas canvas, SmcStructure s, double x, int ageRank) {
    final y = transform.yForPrice(s.price);

    // Adaptive Opacity: Current 100%, Previous 60%, Old 30%
    final baseAlpha = ageRank == 0 ? 1.0 : (ageRank == 1 ? 0.60 : 0.30);
    final opacity = (baseAlpha * settings.opacity).clamp(0.20, 1.0);

    final linePaint = Paint()
      ..color = blueColor.withValues(alpha: opacity)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(x - 30, y), Offset(plotWidth, y), linePaint);
    _drawBadge(
      canvas,
      Offset(x, s.isBullish ? y - 16 : y + 16),
      s.isBullish ? 'Breakout Bullish' : 'Breakout Bearish',
      blueColor.withValues(alpha: opacity),
    );
  }

  // 5. Draw BOS / 6. Draw CHoCH Line
  void _drawStructureLine(
    Canvas canvas,
    SmcStructure s,
    double startX,
    double endX, {
    required bool isChoch,
  }) {
    final y = transform.yForPrice(s.price);
    final color = isChoch ? purpleColor : blueColor;
    final opacity = settings.opacity;

    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = isChoch ? 1.6 : 1.2
      ..style = PaintingStyle.stroke;

    final minX = math.min(startX, endX);
    final maxX = math.max(startX, endX);

    if (isChoch) {
      _drawDashedLine(canvas, Offset(minX, y), Offset(maxX, y), linePaint);
    } else {
      canvas.drawLine(Offset(minX, y), Offset(maxX, y), linePaint);
    }

    final midX = (minX + maxX) / 2;
    final labelText = isChoch
        ? (s.isBullish ? 'CHoCH Bullish' : 'CHoCH Bearish')
        : (s.isBullish ? 'BOS Bullish' : 'BOS Bearish');

    _drawBadge(
      canvas,
      Offset(midX, y - 12),
      labelText,
      color.withValues(alpha: opacity),
    );
  }

  // 7. Draw Equal Highs / Equal Lows (EQH/EQL)
  void _drawEqualLevel(Canvas canvas, SmcStructure s, double startX, double endX) {
    final y = transform.yForPrice(s.price);
    final opacity = settings.opacity;
    final color = s.isBullish ? greenColor : redColor; // EQL=green, EQH=red

    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity * 0.8)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final minX = math.min(startX, endX);
    final maxX = math.max(startX, endX);

    _drawDashedLine(canvas, Offset(minX, y), Offset(maxX, y), linePaint);

    // Draw small diamond markers at both swing points
    _drawDiamond(canvas, Offset(startX, y), color.withValues(alpha: opacity));
    _drawDiamond(canvas, Offset(endX, y), color.withValues(alpha: opacity));

    final midX = (minX + maxX) / 2;
    _drawBadge(
      canvas,
      Offset(midX, y - 14),
      s.isBullish ? 'EQL' : 'EQH',
      color.withValues(alpha: opacity),
    );
  }

  void _drawDiamond(Canvas canvas, Offset center, Color color) {
    const size = 5.0;
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // Visual Helper Utilities with Label Collision Prevention
  void _drawBadge(Canvas canvas, Offset center, String text, Color color,
      {Color textColor = Colors.white}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 5.0;
    const padV = 2.0;
    var bgRect = Rect.fromCenter(
      center: center,
      width: tp.width + padH * 2,
      height: tp.height + padV * 2,
    );

    // Label Collision Avoidance logic
    if (settings.enableCollisionAvoidance) {
      var collisions = 0;
      while (_hasCollision(bgRect) && collisions < 3) {
        // Shift vertically to avoid overlap
        bgRect = bgRect.shift(const Offset(0, 16));
        collisions++;
      }
      if (collisions >= 3 && _hasCollision(bgRect)) {
        // Hide lowest priority overlapping label if crowded
        return;
      }
    }

    _labelRects.add(bgRect);

    final bgPaint = Paint()..color = color;
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), bgPaint);
    tp.paint(canvas, Offset(bgRect.center.dx - tp.width / 2, bgRect.center.dy - tp.height / 2));
  }

  bool _hasCollision(Rect r) {
    for (final existing in _labelRects) {
      if (existing.overlaps(r)) return true;
    }
    return false;
  }

  void _drawText(Canvas canvas, Offset pos, String text, Color color,
      {double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawArrow(Canvas canvas, Offset center, bool isUp, Color color) {
    final path = Path();
    const size = 9.0;
    const half = size / 2;
    if (isUp) {
      path.moveTo(center.dx, center.dy - half);
      path.lineTo(center.dx - half, center.dy + half);
      path.lineTo(center.dx + half, center.dy + half);
    } else {
      path.moveTo(center.dx, center.dy + half);
      path.lineTo(center.dx - half, center.dy - half);
      path.lineTo(center.dx + half, center.dy - half);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final double distance = (p2 - p1).distance;
    if (distance <= 0) return;
    final double dx = (p2.dx - p1.dx) / distance;
    final double dy = (p2.dy - p1.dy) / distance;
    double current = 0;
    while (current < distance) {
      final start = Offset(p1.dx + dx * current, p1.dy + dy * current);
      current = math.min(current + dashWidth, distance);
      final end = Offset(p1.dx + dx * current, p1.dy + dy * current);
      canvas.drawLine(start, end, paint);
      current += dashSpace;
    }
  }

  /// Hit test a point against active SMC structures on the chart.
  static SmcStructure? hitTestStructure({
    required Offset point,
    required List<SmcStructure> structures,
    required ChartTransform transform,
    required double plotWidth,
  }) {
    for (final s in structures.reversed) {
      final x = transform.xForTimestamp(s.timestamp);
      final y = transform.yForPrice(s.price);

      final hitRect = Rect.fromCenter(
        center: Offset(x, y),
        width: 60.0,
        height: 40.0,
      );

      if (hitRect.contains(point)) return s;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant SmcPainter old) {
    return old.structures != structures ||
        old.settings != settings ||
        old.colors != colors ||
        old.transform.scrollOffset != transform.scrollOffset ||
        old.transform.candleWidth != transform.candleWidth ||
        old.transform.minPrice != transform.minPrice ||
        old.transform.maxPrice != transform.maxPrice;
  }
}
