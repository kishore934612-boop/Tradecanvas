/// Sleek, compact floating dropdown menu for Chart screen.
///
/// Features a narrow 42px side width and opening slide/scale/fade animation.
library;

import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';
import 'package:app/utils/haptics.dart';

class ChartQuickDropdownMenu extends StatefulWidget {
  final VoidCallback onOpenTools;

  const ChartQuickDropdownMenu({
    super.key,
    required this.onOpenTools,
  });

  @override
  State<ChartQuickDropdownMenu> createState() => _ChartQuickDropdownMenuState();
}

class _ChartQuickDropdownMenuState extends State<ChartQuickDropdownMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    Haptics.selection();
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _select(VoidCallback action) {
    Haptics.selection();
    _toggle();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Slide, scale & fade popup menu bar
        SizeTransition(
          sizeFactor: _expandAnimation,
          axis: Axis.vertical,
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: ScaleTransition(
              scale: _expandAnimation,
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 42,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: colors.border.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tools Icon (Pencil)
                    Tooltip(
                      message: 'Tools',
                      child: InkWell(
                        onTap: () => _select(widget.onOpenTools),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 20,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Main Dropdown Toggle Button
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isOpen ? colors.primary : colors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                color: _isOpen ? colors.primary : colors.foreground,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
