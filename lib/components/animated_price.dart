import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';

/// Displays a formatted price that briefly flashes green when it ticks up and
/// red when it ticks down, mimicking real trading terminals. The flash fades
/// back to [baseColor] (or the theme foreground) after a short interval.
class AnimatedPrice extends StatefulWidget {
  final double value;
  final String formatted;
  final TextStyle style;
  final Color? baseColor;

  const AnimatedPrice({
    super.key,
    required this.value,
    required this.formatted,
    required this.style,
    this.baseColor,
  });

  @override
  State<AnimatedPrice> createState() => _AnimatedPriceState();
}

class _AnimatedPriceState extends State<AnimatedPrice> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double? _previous;
  int _direction = 0; // 1 up, -1 down, 0 none

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _previous = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _previous) {
      _direction = widget.value > (_previous ?? widget.value) ? 1 : -1;
      _previous = widget.value;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = widget.baseColor ?? widget.style.color ?? colors.foreground;
    final flash = _direction >= 0 ? colors.positive : colors.negative;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Fade from the flash color back to the base color.
        final t = Curves.easeOut.transform(_controller.value);
        final color = Color.lerp(flash, base, t) ?? base;
        return Text(
          widget.formatted,
          style: widget.style.copyWith(color: _controller.isAnimating ? color : base),
        );
      },
    );
  }
}
