/// Replay Order Overlay Painter — renders order lines, TP/SL levels, and
/// fill markers on the chart canvas.
///
/// Draws:
/// - Pending limit/stop order prices as amber dashed lines
/// - Open position TP (green) and SL (red) dashed lines
/// - Entry price marker with label
/// - Fill markers (triangles) at fill candles
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/models/replay_order.dart';

class ReplayOrderOverlayPainter extends CustomPainter {
  final List<ReplayOrder> pendingOrders;
  final List<ReplayOrder> openPositions;
  final double priceMin;
  final double priceMax;
  final int visibleStartIndex;
  final int visibleEndIndex;
  final double candleWidth;
  final double candleSpacing;
  final double scrollOffset;

  ReplayOrderOverlayPainter({
    required this.pendingOrders,
    required this.openPositions,
    required this.priceMin,
    required this.priceMax,
    this.visibleStartIndex = 0,
    this.visibleEndIndex = 0,
    this.candleWidth = 8,
    this.candleSpacing = 2,
    this.scrollOffset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (priceMax <= priceMin) return;

    // Draw pending order lines.
    for (final order in pendingOrders) {
      _drawOrderLine(
        canvas,
        size,
        order.price,
        order.isLong ? 'BUY LIMIT' : 'SELL LIMIT',
        const Color(0xFFF59E0B), // Amber
        isLimit: order.type == OrderType.limit,
        isStop: order.type == OrderType.stopMarket,
      );
    }

    // Draw open position lines.
    for (final pos in openPositions) {
      // Entry price.
      if (pos.fillPrice != null) {
        _drawOrderLine(
          canvas,
          size,
          pos.fillPrice!,
          pos.isLong ? 'LONG ENTRY' : 'SHORT ENTRY',
          const Color(0xFF3B82F6), // Blue
        );
      }

      // Take Profit line.
      if (pos.takeProfitPrice != null) {
        _drawOrderLine(
          canvas,
          size,
          pos.takeProfitPrice!,
          'TP',
          const Color(0xFF10B981), // Green
          isDashed: true,
        );
      }

      // Stop Loss line.
      if (pos.stopLossPrice != null) {
        _drawOrderLine(
          canvas,
          size,
          pos.stopLossPrice!,
          'SL',
          const Color(0xFFEF4444), // Red
          isDashed: true,
        );
      }

      // Fill marker triangle.
      if (pos.fillPrice != null && pos.filledAtBar != null) {
        _drawFillMarker(canvas, size, pos);
      }
    }
  }

  double _priceToY(Size size, double price) {
    return size.height * (1.0 - (price - priceMin) / (priceMax - priceMin));
  }

  void _drawOrderLine(
    Canvas canvas,
    Size size,
    double price,
    String label,
    Color color, {
    bool isDashed = false,
    bool isLimit = false,
    bool isStop = false,
  }) {
    final y = _priceToY(size, price);
    if (y < -20 || y > size.height + 20) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    if (isDashed || isLimit || isStop) {
      // Dashed line.
      const dashWidth = 5.0;
      const dashGap = 3.0;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + dashWidth, size.width), y),
          paint,
        );
        x += dashWidth + dashGap;
      }
    } else {
      // Solid line.
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Label background pill.
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    final pillWidth = textPainter.width + 8;
    final pillHeight = textPainter.height + 4;
    final pillRect = RRect.fromLTRBR(
      4,
      y - pillHeight / 2,
      4 + pillWidth,
      y + pillHeight / 2,
      const Radius.circular(3),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = color.withValues(alpha: 0.85),
    );
    textPainter.paint(canvas, Offset(8, y - textPainter.height / 2));

    // Price label on right side.
    final priceText = TextPainter(
      text: TextSpan(
        text: _formatPrice(price),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    priceText.layout();
    final priceX = size.width - priceText.width - 4;
    final priceBg = RRect.fromLTRBR(
      priceX - 3,
      y - priceText.height / 2 - 2,
      size.width - 1,
      y + priceText.height / 2 + 2,
      const Radius.circular(2),
    );
    canvas.drawRRect(
      priceBg,
      Paint()..color = color.withValues(alpha: 0.15),
    );
    priceText.paint(canvas, Offset(priceX, y - priceText.height / 2));
  }

  void _drawFillMarker(Canvas canvas, Size size, ReplayOrder pos) {
    final y = _priceToY(size, pos.fillPrice!);
    if (y < -20 || y > size.height + 20) return;

    // Calculate x position based on bar index.
    final barIndex = pos.filledAtBar ?? 0;
    final step = candleWidth + candleSpacing;
    final x = (barIndex - visibleStartIndex) * step + step / 2 - scrollOffset;

    if (x < -20 || x > size.width + 20) return;

    final color = pos.isLong
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    final path = Path();
    if (pos.isLong) {
      // Triangle pointing up.
      path.moveTo(x, y - 6);
      path.lineTo(x - 5, y + 3);
      path.lineTo(x + 5, y + 3);
    } else {
      // Triangle pointing down.
      path.moveTo(x, y + 6);
      path.lineTo(x - 5, y - 3);
      path.lineTo(x + 5, y - 3);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill,
    );
  }

  String _formatPrice(double price) {
    if (price >= 1000) return price.toStringAsFixed(1);
    if (price >= 1) return price.toStringAsFixed(2);
    return price.toStringAsFixed(4);
  }

  @override
  bool shouldRepaint(covariant ReplayOrderOverlayPainter oldDelegate) =>
      pendingOrders != oldDelegate.pendingOrders ||
      openPositions != oldDelegate.openPositions ||
      priceMin != oldDelegate.priceMin ||
      priceMax != oldDelegate.priceMax;
}
