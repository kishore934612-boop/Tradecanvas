/// High-performance rendering engine for Smart Analysis Tools overlay labels and badges.
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:app/analysis_tools/models/analysis_metadata.dart';
import 'package:app/components/chart/chart_layout.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/components/chart/drawing_geometry.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/drawing.dart';

class AnalysisRenderer {
  /// Renders specialized analysis badges, labels, and status tags over standard drawing canvas.
  static void render(
    Canvas canvas,
    Drawing drawing,
    AnalysisMetadata metadata,
    ChartTransform transform,
    ChartLayout layout, {
    required ThemePalette colors,
    bool isSelected = false,
    bool isPreview = false,
  }) {
    final pts = DrawingGeometry.project(drawing, transform);
    if (pts.isEmpty) return;

    final primaryColor = drawing.color;

    if (drawing.tool == DrawingTool.rectangle && pts.length >= 2) {
      final rect = Rect.fromPoints(pts[0], pts[1]);
      _renderZoneLabel(canvas, rect, metadata, primaryColor, layout, isSelected: isSelected);
    } else if (drawing.tool == DrawingTool.horizontalLine) {
      final y = transform.yForPrice(drawing.anchors.first.price);
      if (y >= 0 && y <= layout.priceHeight) {
        _renderLineLabel(canvas, y, metadata, primaryColor, layout, isSelected: isSelected);
      }
    }
  }

  static void _renderZoneLabel(
    Canvas canvas,
    Rect rect,
    AnalysisMetadata metadata,
    Color primaryColor,
    ChartLayout layout, {
    bool isSelected = false,
  }) {
    final labelStr = metadata.label.isNotEmpty ? metadata.label : metadata.analysisType.shortLabel;
    final tp = _createTextPainter(labelStr, Colors.white, 9.5, fontWeight: FontWeight.bold);

    final midX = (rect.left + rect.right) / 2;
    final midY = (rect.top + rect.bottom) / 2;

    // Badge centered inside zone rectangle
    final badgeW = tp.width + 12.0;
    final badgeH = tp.height + 6.0;

    final badgeRect = Rect.fromCenter(
      center: Offset(midX.clamp(40.0, layout.plotWidth - 40.0), midY),
      width: badgeW,
      height: badgeH,
    );

    final bgPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      bgPaint,
    );

    tp.paint(canvas, Offset(badgeRect.left + 6.0, badgeRect.top + 3.0));

    // Status tags: Mitigated / Invalidated strike
    if (metadata.mitigated) {
      final strikePaint = Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(badgeRect.left + 2, badgeRect.center.dy),
        Offset(badgeRect.right - 2, badgeRect.center.dy),
        strikePaint,
      );
    }
  }

  static void _renderLineLabel(
    Canvas canvas,
    double y,
    AnalysisMetadata metadata,
    Color primaryColor,
    ChartLayout layout, {
    bool isSelected = false,
  }) {
    final labelStr = metadata.label.isNotEmpty ? metadata.label : metadata.analysisType.shortLabel;
    final tp = _createTextPainter(labelStr, Colors.white, 9.5, fontWeight: FontWeight.bold);

    final midX = layout.plotWidth / 2;
    final badgeW = tp.width + 12.0;
    final badgeH = tp.height + 6.0;

    final badgeRect = Rect.fromCenter(
      center: Offset(midX, y),
      width: badgeW,
      height: badgeH,
    );

    final bgPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
      bgPaint,
    );

    tp.paint(canvas, Offset(badgeRect.left + 6.0, badgeRect.top + 3.0));
  }

  static TextPainter _createTextPainter(
    String text,
    Color color,
    double fontSize, {
    FontWeight fontWeight = FontWeight.w600,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}
