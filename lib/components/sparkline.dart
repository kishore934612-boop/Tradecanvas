import 'dart:math' as math;
import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  final List<double> data;
  final double width;
  final double height;
  final Color color;
  final bool showGradient;

  const Sparkline({
    super.key,
    required this.data,
    this.width = 80.0,
    this.height = 36.0,
    required this.color,
    this.showGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return SizedBox(width: width, height: height);
    }
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        data: data,
        color: color,
        showGradient: showGradient,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool showGradient;

  _SparklinePainter({
    required this.data,
    required this.color,
    required this.showGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double minVal = data.reduce(math.min);
    final double maxVal = data.reduce(math.max);
    final double range = (maxVal - minVal == 0.0) ? 1.0 : (maxVal - minVal);
    
    const double padY = 4.0;
    final double drawH = size.height - padY * 2;
    final double stepX = size.width / (data.length - 1);

    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double y = padY + drawH - ((data[i] - minVal) / range) * drawH;
      points.add(Offset(x, y));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final pt = points[i];
      final cpX = (prev.dx + pt.dx) / 2;
      path.cubicTo(cpX, prev.dy, cpX, pt.dy, pt.dx, pt.dy);
    }

    if (showGradient) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, size.height);
      fillPath.lineTo(0.0, size.height);
      fillPath.lineTo(0.0, points.first.dy);
      fillPath.close();

      final paintGradient = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, paintGradient);
    }

    // Glowing path stroke underlay
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.color != color ||
        oldDelegate.showGradient != showGradient;
  }
}
