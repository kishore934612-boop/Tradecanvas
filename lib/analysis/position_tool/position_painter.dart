/// Canvas Painter for rendering position tools on chart view surface.
library;

import 'package:flutter/material.dart';
import 'package:app/analysis/position_tool/position_calculator.dart';
import 'package:app/analysis/position_tool/position_tool.dart';
import 'package:app/components/chart/chart_transform.dart';
import 'package:app/constants/colors.dart';

class PositionPainter {
  /// Render a position tool onto the chart Canvas.
  static void paint({
    required Canvas canvas,
    required Size size,
    required PositionTool tool,
    required ChartTransform transform,
    bool isSelected = false,
  }) {
    if (!tool.visible) return;

    final entryX = transform.xForTimestamp(tool.entryTimestamp);
    final targetX = transform.xForTimestamp(tool.targetTimestamp);

    final leftX = entryX < targetX ? entryX : targetX;
    final rightX = (entryX - targetX).abs() < 20 ? leftX + 120.0 : (entryX > targetX ? entryX : targetX);

    final entryY = transform.yForPrice(tool.entryPrice);
    final stopY = transform.yForPrice(tool.stopLossPrice);
    final targetY = transform.yForPrice(tool.takeProfitPrice);

    final calc = PositionCalculator.calculate(tool);

    // Color definitions based on mode
    Color profitFill;
    Color profitStroke;
    Color stopFill;
    Color stopStroke;

    switch (tool.mode) {
      case PositionToolMode.longPosition:
        profitFill = AppColors.greenUp.withValues(alpha: 0.22);
        profitStroke = AppColors.greenUp;
        stopFill = AppColors.redDown.withValues(alpha: 0.22);
        stopStroke = AppColors.redDown;
        break;
      case PositionToolMode.shortPosition:
        profitFill = AppColors.redDown.withValues(alpha: 0.22);
        profitStroke = AppColors.redDown;
        stopFill = AppColors.greenUp.withValues(alpha: 0.22);
        stopStroke = AppColors.greenUp;
        break;
      case PositionToolMode.riskReward:
        profitFill = AppColors.primary.withValues(alpha: 0.18);
        profitStroke = AppColors.primary;
        stopFill = AppColors.primary.withValues(alpha: 0.12);
        stopStroke = AppColors.primary.withValues(alpha: 0.7);
        break;
    }

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 1. Draw Profit Zone Box
    final profitRect = Rect.fromLTRB(
      leftX,
      targetY < entryY ? targetY : entryY,
      rightX,
      targetY < entryY ? entryY : targetY,
    );
    fillPaint.color = profitFill;
    canvas.drawRect(profitRect, fillPaint);
    linePaint.color = profitStroke;
    canvas.drawRect(profitRect, linePaint);

    // 2. Draw Stop Zone Box
    final stopRect = Rect.fromLTRB(
      leftX,
      stopY < entryY ? stopY : entryY,
      rightX,
      stopY < entryY ? entryY : stopY,
    );
    fillPaint.color = stopFill;
    canvas.drawRect(stopRect, fillPaint);
    linePaint.color = stopStroke;
    canvas.drawRect(stopRect, linePaint);

    // 3. Draw Entry Line (Center accent line)
    final entryLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(leftX, entryY), Offset(rightX, entryY), entryLinePaint);

    // 4. Draw Stats Card Label Box
    _drawStatsCard(
      canvas: canvas,
      rect: Rect.fromLTRB(leftX, targetY < stopY ? targetY : stopY, rightX, targetY > stopY ? targetY : stopY),
      calc: calc,
      tool: tool,
      isSelected: isSelected,
    );

    // 5. Draw Handles if selected
    if (isSelected) {
      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final midX = (leftX + rightX) / 2;
      for (final y in [targetY, entryY, stopY]) {
        canvas.drawCircle(Offset(midX, y), 5.0, handlePaint);
        canvas.drawCircle(Offset(midX, y), 5.0, handleBorder);
      }
    }
  }

  static void _drawStatsCard({
    required Canvas canvas,
    required Rect rect,
    required PositionCalculationResult calc,
    required PositionTool tool,
    required bool isSelected,
  }) {
    final rrText = 'R/R: ${calc.riskRewardRatio.toStringAsFixed(2)}';
    final targetText = 'Target: ${calc.rewardPercent.toStringAsFixed(2)}% (\$+${calc.potentialProfit.toStringAsFixed(2)})';
    final stopText = 'Stop: ${calc.riskPercent.toStringAsFixed(2)}% (-\$${calc.potentialLoss.toStringAsFixed(2)})';
    final sizeText = 'Qty: ${calc.quantity.toStringAsFixed(4)} (\$${calc.positionSize.toStringAsFixed(0)})';

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    final span = TextSpan(
      children: [
        TextSpan(text: '$rrText\n'),
        TextSpan(text: '$targetText\n'),
        TextSpan(text: '$stopText\n'),
        TextSpan(text: sizeText),
      ],
      style: textStyle,
    );

    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    painter.layout();

    final cardWidth = painter.width + 16;
    final cardHeight = painter.height + 10;
    final cardLeft = rect.center.dx - cardWidth / 2;
    final cardTop = rect.center.dy - cardHeight / 2;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      const Radius.circular(6),
    );

    final bgPaint = Paint()
      ..color = const Color(0xDD1E293B)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = isSelected ? AppColors.primary : AppColors.surfaceBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);

    painter.paint(canvas, Offset(cardLeft + 8, cardTop + 5));
  }
}
