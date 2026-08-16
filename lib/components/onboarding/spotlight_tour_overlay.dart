/// Interactive Spotlight Tour — guided walkthrough with animated spotlight,
/// step-by-step tooltips, step counter, and skip button.
library;

import 'package:flutter/material.dart';

import 'package:app/constants/colors.dart';
import 'package:app/utils/haptics.dart';

class SpotlightStep {
  final String title;
  final String description;
  final Rect Function(Size size) getTargetRect;
  final Alignment tooltipAlignment;

  const SpotlightStep({
    required this.title,
    required this.description,
    required this.getTargetRect,
    this.tooltipAlignment = Alignment.center,
  });
}

class SpotlightTourOverlay extends StatefulWidget {
  final VoidCallback onComplete;

  const SpotlightTourOverlay({super.key, required this.onComplete});

  @override
  State<SpotlightTourOverlay> createState() => _SpotlightTourOverlayState();
}

class _SpotlightTourOverlayState extends State<SpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;

  static final List<SpotlightStep> _steps = [
    SpotlightStep(
      title: 'Smart Candle Analytics',
      description:
          'Tap any candle body on the chart to inspect 20+ Smart Statistics & Auto-Detected Patterns (Bullish Engulfing, Hammer, Doji, etc.).',
      getTargetRect: (s) => Rect.fromLTWH(
        s.width * 0.1,
        s.height * 0.25,
        s.width * 0.8,
        s.height * 0.35,
      ),
      tooltipAlignment: const Alignment(0, 0.75),
    ),
    SpotlightStep(
      title: 'Price Bar Vertical Scale',
      description:
          'Drag up/down on the right price axis bar to scale vertically. Double-tap the price axis to reset auto-fit.',
      getTargetRect: (s) => Rect.fromLTWH(
        s.width - 65,
        s.height * 0.15,
        60,
        s.height * 0.65,
      ),
      tooltipAlignment: const Alignment(-0.6, 0.0),
    ),
    SpotlightStep(
      title: 'Magnetic Precision Drawing',
      description:
          'Select Trendline, Fibonacci or Measurement tools. Snaps to candle OHLCs with magnetic precision 🧲.',
      getTargetRect: (s) => Rect.fromLTWH(
        12,
        s.height - 110,
        s.width - 24,
        65,
      ),
      tooltipAlignment: const Alignment(0, -0.4),
    ),
    SpotlightStep(
      title: 'Indicators & Market Sessions',
      description:
          'Configure Technical Indicators (MA, RSI, MACD) and overlay Market Trading Sessions (Sydney, Tokyo, London, NY).',
      getTargetRect: (s) => Rect.fromLTWH(
        s.width - 160,
        45,
        150,
        42,
      ),
      tooltipAlignment: const Alignment(0, 0.35),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _next() {
    Haptics.selection();
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _finish() {
    Haptics.medium();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final step = _steps[_currentStep];
        final targetRect = step.getTargetRect(size);

        return Stack(
          children: [
            // Darkened Backdrop with Spotlight Hole Punch
            CustomPaint(
              size: size,
              painter: _SpotlightHolePainter(
                targetRect: targetRect,
                pulse: _pulseController,
                primaryColor: colors.primary,
              ),
            ),

            // Dismiss tap barrier
            GestureDetector(
              onTap: _next,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),

            // Floating Glassmorphic Tooltip Card
            Align(
              alignment: step.tooltipAlignment,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                padding: const EdgeInsets.all(18),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: colors.primary.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Step Counter
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Step ${_currentStep + 1} of ${_steps.length}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _finish,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Skip Tour',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Description
                    Text(
                      step.description,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colors.mutedForeground,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor:
                              colors.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _currentStep == _steps.length - 1
                              ? 'Finish Tour'
                              : 'Next Tip',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightHolePainter extends CustomPainter {
  final Rect targetRect;
  final Animation<double> pulse;
  final Color primaryColor;

  _SpotlightHolePainter({
    required this.targetRect,
    required this.pulse,
    required this.primaryColor,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final backdrop = Paint()..color = const Color(0xD9000000);
    final RRect rrect = RRect.fromRectAndRadius(
      targetRect.inflate(8),
      const Radius.circular(12),
    );

    // Path with hole punch
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backdrop);

    // Glowing Animated Pulsing Border
    final pulseExpand = pulse.value * 4.0;
    final pulseRect = RRect.fromRectAndRadius(
      targetRect.inflate(8 + pulseExpand),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      pulseRect,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.7 - (pulse.value * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_SpotlightHolePainter old) =>
      old.targetRect != targetRect || old.primaryColor != primaryColor;
}
