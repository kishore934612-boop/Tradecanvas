import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/screens/main_tabs_screen.dart';
import 'package:app/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.75, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    // Wait for splash screen animation to display fully (2 seconds)
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    final appState = context.read<AppState>();
    
    // If not loaded yet, wait for load to complete
    if (!appState.loaded) {
      await _waitForLoad(appState);
    }
    
    if (!mounted) return;

    unawaited(Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            appState.onboarded ? const MainTabsScreen() : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    ));
  }

  Future<void> _waitForLoad(AppState appState) async {
    while (!appState.loaded) {
      await Future.delayed(const Duration(milliseconds: 100));
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
    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Background ambient color blobs — multi-hue instead of a single
          // flat tint, so the splash feels vivid rather than monochrome.
          for (final entry in colors.ambientGlow.asMap().entries)
            Positioned(
              top: -120.0 + entry.key * 40,
              left: entry.key.isEven ? -80.0 : null,
              right: entry.key.isOdd ? -80.0 : null,
              child: IgnorePointer(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        entry.value.withValues(alpha: 0.18),
                        entry.value.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Icon/Badge with gradient background
                        Container(
                          width: 86.0,
                          height: 86.0,
                          decoration: BoxDecoration(
                            gradient: colors.primaryGradient,
                            borderRadius: BorderRadius.circular(24.0),
                            boxShadow: colors.glowShadow,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24.0),
                            child: Image.asset(
                              'assets/icon.png',
                              width: 86.0,
                              height: 86.0,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.query_stats_rounded,
                                  size: 44.0,
                                  color: colors.brightness == Brightness.dark
                                      ? Colors.black
                                      : Colors.white,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),
                        // App Name
                        Text(
                          'TradeCanvas',
                          style: TextStyle(
                            fontSize: 34.0,
                            fontWeight: FontWeight.bold,
                            color: colors.foreground,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        // Subtitle
                        Text(
                          'Live charts. Every pair.',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: colors.mutedForeground,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Premium linear progress loading indicator at bottom
          Positioned(
            bottom: 60.0,
            child: SizedBox(
              width: 120.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.0),
                child: LinearProgressIndicator(
                  minHeight: 2.0,
                  backgroundColor: colors.border.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
