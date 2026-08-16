/// Interactive Spotlight Tour — Step-by-step walkthrough feature for Charty.
///
/// Highlights key platform capabilities with spotlight animations, step tooltips,
/// progress indicators, and interactive controls.
library;

import 'package:flutter/material.dart';
import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/utils/haptics.dart';

class SpotlightStep {
  final String title;
  final String description;
  final IconData icon;
  final String badge;
  final Alignment tooltipAlignment;

  const SpotlightStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.badge,
    this.tooltipAlignment = Alignment.bottomCenter,
  });
}

class SpotlightTourOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const SpotlightTourOverlay({super.key, required this.onDismiss});

  @override
  State<SpotlightTourOverlay> createState() => _SpotlightTourOverlayState();
}

class _SpotlightTourOverlayState extends State<SpotlightTourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;

  static const List<SpotlightStep> _steps = [
    SpotlightStep(
      title: 'Interactive Live Charts',
      description:
          'Stream real-time Binance WebSocket prices with 5 chart types (Candles, Line, Area, Baseline & Volume) and instant timeframe switching.',
      icon: Icons.candlestick_chart_rounded,
      badge: 'CHART ENGINE',
      tooltipAlignment: Alignment.center,
    ),
    SpotlightStep(
      title: 'Precision Drawing & Magnet',
      description:
          'Draw trendlines, parallel channels, Fibonacci retracements & rectangles with high-precision magnetic snapping to candle OHLCs.',
      icon: Icons.gesture_rounded,
      badge: 'DRAWING TOOLS',
      tooltipAlignment: Alignment.topCenter,
    ),
    SpotlightStep(
      title: 'Automatic Candlestick Detection',
      description:
          'Scan and detect 15+ classic candlestick patterns (Doji, Engulfing, Hammer, Morning Star) automatically on tap.',
      icon: Icons.auto_awesome_rounded,
      badge: 'AI PATTERNS',
      tooltipAlignment: Alignment.center,
    ),
    SpotlightStep(
      title: 'Chart Customization & AMOLED',
      description:
          'Personalize candle colors, grid style & density (solid, dashed, dotted), and switch to pitch-black AMOLED mode in settings.',
      icon: Icons.palette_rounded,
      badge: 'CUSTOMIZATION',
      tooltipAlignment: Alignment.bottomCenter,
    ),
    SpotlightStep(
      title: 'Market Sessions & Replay',
      description:
          'Overlay Sydney, Tokyo, London & New York market sessions or step through price history bar-by-bar in Replay Simulator.',
      icon: Icons.history_toggle_off_rounded,
      badge: 'SIMULATOR & SESSIONS',
      tooltipAlignment: Alignment.center,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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

  void _previous() {
    Haptics.selection();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finish() {
    Haptics.medium();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent Spotlight Overlay Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: _next,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                color: Colors.black.withValues(alpha: 0.78),
              ),
            ),
          ),

          // Animated Glowing Spotlight Target Ring
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  return Center(
                    child: Container(
                      width: 280 + (_pulseController.value * 12),
                      height: 280 + (_pulseController.value * 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(
                              alpha: 0.4 + (_pulseController.value * 0.4)),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(
                                alpha: 0.2 + (_pulseController.value * 0.3)),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Floating Glassmorphic Tooltip Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Align(
                alignment: step.tooltipAlignment,
                child: GlassCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(20),
                  borderColor: colors.primary.withValues(alpha: 0.6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Badge + Step Counter + Skip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              step.badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            'Step ${_currentStep + 1} of ${_steps.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.mutedForeground,
                            ),
                          ),
                          InkWell(
                            onTap: _finish,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Title & Icon Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: colors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              step.icon,
                              color: colors.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colors.foreground,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        step.description,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: colors.foreground.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Step Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / _steps.length,
                          backgroundColor: colors.border.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Navigation Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentStep > 0)
                            OutlinedButton.icon(
                              onPressed: _previous,
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Back'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.foreground,
                                side: BorderSide(
                                    color: colors.border.withValues(alpha: 0.8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          ElevatedButton.icon(
                            onPressed: _next,
                            icon: Icon(
                              isLast
                                  ? Icons.check_circle_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                            ),
                            label: Text(isLast ? 'Complete Tour' : 'Next Step'),
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
