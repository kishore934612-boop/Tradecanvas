/// Volume Profile Painter — renders horizontal histogram bars on the chart.
///
/// Draws buy/sell volume bars, POC line, and Value Area shading as a
/// CustomPainter overlay on the right side of the chart viewport.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:app/engine/volume_profile_engine.dart';

class VolumeProfilePainter extends CustomPainter {
  final VolumeProfileResult profile;
  final double priceMin;
  final double priceMax;

  /// Width fraction of the chart area the histogram occupies (0.0 – 1.0).
  final double widthFraction;

  /// Overall opacity.
  final double opacity;

  VolumeProfilePainter({
    required this.profile,
    required this.priceMin,
    required this.priceMax,
    this.widthFraction = 0.15,
    this.opacity = 0.55,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.rows.isEmpty || profile.highestVolume <= 0) return;
    if (priceMax <= priceMin) return;

    final maxBarWidth = size.width * widthFraction;
    final priceRange = priceMax - priceMin;

    // Paint styles.
    final buyPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: opacity * 0.85)
      ..style = PaintingStyle.fill;

    final sellPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.fill;

    final pocPaint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final vaPaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Draw Value Area shading.
    final vaTopY = size.height * (1.0 - (profile.valueAreaHigh - priceMin) / priceRange);
    final vaBottomY = size.height * (1.0 - (profile.valueAreaLow - priceMin) / priceRange);
    canvas.drawRect(
      Rect.fromLTRB(
        size.width - maxBarWidth - 4,
        vaTopY.clamp(0.0, size.height),
        size.width,
        vaBottomY.clamp(0.0, size.height),
      ),
      vaPaint,
    );

    // Draw histogram bars.
    final barHeight = profile.rows.length > 1
        ? (size.height / profile.rows.length).clamp(1.0, 8.0)
        : 4.0;

    for (final row in profile.rows) {
      if (row.totalVolume <= 0) continue;

      final y = size.height * (1.0 - (row.priceLevel - priceMin) / priceRange);
      if (y < -barHeight || y > size.height + barHeight) continue;

      final normalizedTotal = row.totalVolume / profile.highestVolume;
      final totalWidth = normalizedTotal * maxBarWidth;

      // Buy volume bar (teal, drawn from right edge inward).
      final buyFraction = row.totalVolume > 0
          ? row.buyVolume / row.totalVolume
          : 0.5;
      final buyWidth = totalWidth * buyFraction;
      final sellWidth = totalWidth * (1.0 - buyFraction);

      final barRight = size.width - 2;
      final barTop = y - barHeight / 2;

      // Draw sell volume (left part of bar).
      if (sellWidth > 0.5) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            barRight - totalWidth,
            barTop,
            barRight - buyWidth,
            barTop + barHeight,
            const Radius.circular(1),
          ),
          sellPaint,
        );
      }

      // Draw buy volume (right part of bar).
      if (buyWidth > 0.5) {
        canvas.drawRRect(
          RRect.fromLTRBR(
            barRight - buyWidth,
            barTop,
            barRight,
            barTop + barHeight,
            const Radius.circular(1),
          ),
          buyPaint,
        );
      }

      // HVN highlight outline.
      if (row.isHVN) {
        final hvnPaint = Paint()
          ..color = const Color(0xFFFFD700).withValues(alpha: 0.3)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        canvas.drawRect(
          Rect.fromLTRB(barRight - totalWidth, barTop, barRight, barTop + barHeight),
          hvnPaint,
        );
      }
    }

    // Draw POC line.
    final pocY = size.height * (1.0 - (profile.pocPrice - priceMin) / priceRange);
    if (pocY >= 0 && pocY <= size.height) {
      // Dashed line effect.
      const dashWidth = 6.0;
      const dashGap = 3.0;
      var x = size.width - maxBarWidth - 8;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, pocY),
          Offset(math.min(x + dashWidth, size.width), pocY),
          pocPaint,
        );
        x += dashWidth + dashGap;
      }

      // POC label.
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'POC',
          style: TextStyle(
            color: const Color(0xFFFFD700).withValues(alpha: 0.9),
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - maxBarWidth - textPainter.width - 12, pocY - textPainter.height - 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant VolumeProfilePainter oldDelegate) =>
      profile != oldDelegate.profile ||
      priceMin != oldDelegate.priceMin ||
      priceMax != oldDelegate.priceMax ||
      opacity != oldDelegate.opacity;
}
