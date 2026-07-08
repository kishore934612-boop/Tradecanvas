import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';

class AllocationSegment {
  final String label;
  final double value;
  final Color color;
  AllocationSegment({required this.label, required this.value, required this.color});
}

class AllocationChart extends StatelessWidget {
  final List<AllocationSegment> segments;
  final double size;

  const AllocationChart({super.key, required this.segments, this.size = 120.0});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = segments.where((s) => s.value > 0).toList();
    final drawSegments = active.isEmpty
        ? [AllocationSegment(label: 'Cash', value: 1.0, color: colors.primary)]
        : active;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return CustomPaint(
          size: Size(size, size),
          painter: _DonutChartPainter(segments: drawSegments, animationProgress: value),
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<AllocationSegment> segments;
  final double animationProgress;

  _DonutChartPainter({required this.segments, required this.animationProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final double totalVal = segments.fold(0, (sum, seg) => sum + seg.value);
    if (totalVal == 0) return;
    const double strokeWidth = 14.0;
    final Rect rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      final double sweepAngle = (seg.value / totalVal) * 2 * math.pi * animationProgress;
      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(rect, startAngle + 0.04, math.max(0.0, sweepAngle - 0.08), false, paint);
      }
      startAngle += (seg.value / totalVal) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.animationProgress != animationProgress;
}
