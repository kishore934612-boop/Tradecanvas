/// Strategy Overlay Painter — renders educational strategy markers & arrows above candles.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:app/components/chart/chart_transform.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/strategy_type.dart';

class StrategyPainter extends CustomPainter {
  final ChartTransform transform;
  final List<StrategySignal> signals;
  final StrategySettings settings;
  final ThemePalette colors;
  final double plotWidth;

  StrategyPainter({
    required this.transform,
    required this.signals,
    required this.settings,
    required this.colors,
    required this.plotWidth,
  });

  static const Color greenColor = Color(0xFF26A69A);
  static const Color redColor = Color(0xFFEF5350);

  @override
  void paint(Canvas canvas, Size size) {
    if (signals.isEmpty) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plotWidth, transform.priceHeight));

    for (final signal in signals) {
      final x = transform.xForTimestamp(signal.timestamp);
      if (x < -60 || x > plotWidth + 60) continue;

      final y = transform.yForPrice(signal.price);
      final isBuy = signal.isBuy;
      final signalColor = (isBuy ? greenColor : redColor)
          .withValues(alpha: settings.signalOpacity);

      // Offset positioning so arrow/label never covers the candle
      final arrowY = isBuy ? y + 14.0 : y - 14.0;
      final labelY = settings.enableArrows
          ? (isBuy ? arrowY + 14.0 : arrowY - 14.0)
          : (isBuy ? y + 14.0 : y - 14.0);

      // 1. Draw Signal Arrow
      if (settings.enableArrows) {
        _drawArrow(canvas, Offset(x, arrowY), isBuy, signalColor, settings.arrowSize);
      }

      // 2. Draw Strategy Label Badge
      if (settings.enableLabels) {
        _drawLabel(
          canvas,
          Offset(x, labelY),
          signal.shortTag,
          signalColor,
          settings.labelSize,
          opacity: settings.signalOpacity,
        );
      }
    }

    canvas.restore();
  }

  void _drawArrow(
      Canvas canvas, Offset center, bool isBuy, Color color, double size) {
    final path = Path();
    final half = size / 2;

    if (isBuy) {
      // Upward pointing arrow (▲)
      path.moveTo(center.dx, center.dy - half);
      path.lineTo(center.dx - half, center.dy + half);
      path.lineTo(center.dx + half, center.dy + half);
    } else {
      // Downward pointing arrow (▼)
      path.moveTo(center.dx, center.dy + half);
      path.lineTo(center.dx - half, center.dy - half);
      path.lineTo(center.dx + half, center.dy - half);
    }
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Subtle outline
    final strokePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35 * color.a)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    String text,
    Color color,
    double fontSize, {
    double opacity = 1.0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const paddingH = 6.0;
    const paddingV = 3.0;

    final bgRect = Rect.fromCenter(
      center: center,
      width: tp.width + paddingH * 2,
      height: tp.height + paddingV * 2,
    );

    // Background pill
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.90 * opacity)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      bgPaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45 * opacity)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
      borderPaint,
    );

    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  /// Hit test a point against active signals on the chart.
  static StrategySignal? hitTestSignal({
    required Offset point,
    required List<StrategySignal> signals,
    required ChartTransform transform,
    required double plotWidth,
    required StrategySettings settings,
  }) {
    for (final signal in signals.reversed) {
      final x = transform.xForTimestamp(signal.timestamp);
      if (x < -60 || x > plotWidth + 60) continue;

      final y = transform.yForPrice(signal.price);
      final isBuy = signal.isBuy;
      final arrowY = isBuy ? y + 14.0 : y - 14.0;
      final labelY = settings.enableArrows
          ? (isBuy ? arrowY + 14.0 : arrowY - 14.0)
          : (isBuy ? y + 14.0 : y - 14.0);

      final targetY = settings.enableLabels ? labelY : arrowY;

      // Hit area around marker
      final rect = Rect.fromCenter(
        center: Offset(x, targetY),
        width: math.max(48.0, settings.arrowSize * 2.5),
        height: math.max(44.0, settings.arrowSize * 2.5),
      );

      if (rect.contains(point)) return signal;
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant StrategyPainter old) {
    return old.signals != signals ||
        old.settings != settings ||
        old.colors != colors ||
        old.transform.scrollOffset != transform.scrollOffset ||
        old.transform.candleWidth != transform.candleWidth ||
        old.transform.minPrice != transform.minPrice ||
        old.transform.maxPrice != transform.maxPrice;
  }
}
