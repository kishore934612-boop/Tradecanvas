import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/components/ui.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = Provider.of<AppState>(context);
    final isPro = appState.isProUser;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.foreground, size: 20.0),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'TradeVerse Pro',
          style: TextStyle(
            color: colors.foreground,
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pro Badge/Banner Illustration
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.2),
                        colors.accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    size: 64.0,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Title Header
              Center(
                child: Column(
                  children: [
                    Text(
                      isPro ? 'TradeVerse Pro Active' : 'Upgrade to Pro',
                      style: TextStyle(
                        fontSize: 24.0,
                        fontWeight: FontWeight.w900,
                        color: colors.foreground,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text(
                      isPro
                          ? 'You have unlocked the complete learning ecosystem'
                          : 'Supercharge your trading learning experience',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32.0),

              // Plan Status Card
              GlassCard(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      isPro ? Icons.stars_rounded : Icons.star_border_rounded,
                      color: isPro ? colors.primary : colors.mutedForeground,
                      size: 24.0,
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPro ? 'Pro Member' : 'Current Plan: TradeVerse Free',
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: isPro ? colors.primary : colors.foreground,
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            isPro ? 'Enjoy lifetime access' : 'Virtual assets & simulated tools',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28.0),

              // Benefits Checklist Header
              Text(
                'PRO BENEFITS INCLUDE:',
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  color: colors.mutedForeground,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12.0),

              // Benefits Items
              _proFeature('AI Coach & Feedback summaries', colors),
              _proFeature('Advanced Trade Analytics & charts', colors),
              _proFeature('Unlimited Journal reflections storage', colors),
              _proFeature('Replay Mode to practice historical candles', colors),
              _proFeature('Premium Lessons on liquidation, margins', colors),
              _proFeature('Cloud backup & multi-device sync', colors),
              const SizedBox(height: 40.0),

              // Subscribe Actions
              if (!isPro) ...[
                Container(
                  width: double.infinity,
                  height: 52.0,
                  decoration: BoxDecoration(
                    gradient: colors.primaryGradient,
                    borderRadius: BorderRadius.circular(14.0),
                    boxShadow: colors.glowShadow,
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TradeVerse Pro Subscriptions - Coming Soon!')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text(
                      'Get TradeVerse Pro',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14.0),
                Center(
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TradeVerse Pro Subscriptions - Coming Soon!')),
                      );
                    },
                    child: Text(
                      'Restore Purchases',
                      style: TextStyle(
                        fontSize: 14.0,
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Center(
                  child: Text(
                    'Lifetime Access Granted',
                    style: TextStyle(
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      color: colors.positive,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proFeature(String text, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: colors.primary,
            size: 18.0,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14.0,
                color: colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
