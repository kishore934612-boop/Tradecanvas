/// Dedicated Settings Detail Screen.
///
/// Contains Theme Switch, Chart Customization, App Preferences, About,
/// Terms and Conditions, and Privacy Policy.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/ui.dart';
import 'package:app/constants/colors.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/screens/chart_customization_screen.dart';
import 'package:app/utils/haptics.dart';

class SettingsDetailScreen extends StatelessWidget {
  const SettingsDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Screen Header with Back Button
            const ScreenHeader(
              title: 'Settings',
              showBackButton: true,
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const _SectionLabel('Appearance & Theme'),
                  _ThemeSwitchCard(appState: appState),

                  const _SectionLabel('Chart & Canvas'),
                  _ChartCustomizationTile(),

                  const _SectionLabel('App Preferences'),
                  _AppPreferencesCard(appState: appState),

                  const _SectionLabel('Legal & Information'),
                  _LegalInfoCard(),

                  const _SectionLabel('About & System'),
                  _AboutCard(),
                  const SizedBox(height: 12),
                  const _ResetDataCard(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

// 1. Theme Switch Card
class _ThemeSwitchCard extends StatelessWidget {
  final AppState appState;
  const _ThemeSwitchCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = appState.themeMode == ThemeMode.dark;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 20,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Dark Theme Active' : 'Light Theme Active',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDark,
            activeTrackColor: colors.primary,
            onChanged: (val) {
              Haptics.selection();
              appState.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
            },
          ),
        ],
      ),
    );
  }
}

// 2. Chart Customization Tile
class _ChartCustomizationTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ChartCustomizationScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.tune_rounded, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chart Customization',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Candle templates, colors & grid styles',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 22),
          ],
        ),
      ),
    );
  }
}

// 3. App Preferences Card
class _AppPreferencesCard extends StatelessWidget {
  final AppState appState;
  const _AppPreferencesCard({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hapticEnabled = appState.profile.hapticsEnabled;
    final autoScale = appState.profile.autoScale;

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Haptics Toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.vibration_rounded, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haptic Touch Feedback',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vibration response on chart interactions',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: hapticEnabled,
                activeTrackColor: colors.primary,
                onChanged: (val) {
                  Haptics.selection();
                  appState.setHaptics(val);
                },
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          ),

          // Auto Scale Toggle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.aspect_ratio_rounded, size: 20, color: colors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto Scale Price Axis',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Automatically fit vertical price range',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: autoScale,
                activeTrackColor: colors.primary,
                onChanged: (val) {
                  Haptics.selection();
                  appState.setAutoScale(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 4. Legal & Info Card (Terms & Conditions, Privacy Policy)
class _LegalInfoCard extends StatelessWidget {
  void _showTermsDialog(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.description_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Terms & Conditions',
              style: TextStyle(color: colors.foreground, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Technical Analysis Tool Only',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'TradeCanvas is strictly a technical analysis software. It does not provide investment advice, trading execution, financial recommendations, or portfolio management.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '2. Financial Risk Acknowledgment',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Financial markets involve substantial risk of loss. All technical indicators, drawings, and signals are for analytical and educational purposes only.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '3. Market Data Availability',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Market data feeds are provided via real-time WebSocket connections. No warranty is expressed regarding continuous uptime or zero latency.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Privacy Policy',
              style: TextStyle(color: colors.foreground, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Local Data Storage',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'All user chart drawings, indicator styles, custom price markers, and preferences are stored locally on your device via SQLite.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '2. Data Security & Telemetry',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'We do not sell, rent, or share personal user data. Market data connections communicate directly with public exchange API endpoints.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                '3. Storage Permissions',
                style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Permissions requested by TradeCanvas are strictly limited to local preference persistence and chart export functionality.',
                style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Terms & Conditions Tile
          InkWell(
            onTap: () {
              Haptics.selection();
              _showTermsDialog(context);
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.description_outlined, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Software usage & disclaimer terms',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 22),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
          ),

          // Privacy Policy Tile
          InkWell(
            onTap: () {
              Haptics.selection();
              _showPrivacyPolicyDialog(context);
            },
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.privacy_tip_outlined, size: 20, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Local storage & security details',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 5. About Card
class _AboutCard extends StatelessWidget {
  void _showAboutDialog(BuildContext context) {
    final colors = AppColors.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'About TradeCanvas',
              style: TextStyle(color: colors.foreground, fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TradeCanvas v2.4.0',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.foreground),
            ),
            const SizedBox(height: 6),
            Text(
              'High-performance technical analysis canvas with real-time candlestick engines, market session overlays, drawing tools, and customizable indicators.',
              style: TextStyle(color: colors.mutedForeground, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Market Data Stream: Binance WebSocket API',
              style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: colors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          _showAboutDialog(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.info_outline_rounded, size: 20, color: colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About TradeCanvas',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Version 2.4.0 • Technical Analysis Engine',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.mutedForeground, size: 22),
          ],
        ),
      ),
    );
  }
}

// 6. Reset Data Card
class _ResetDataCard extends StatelessWidget {
  const _ResetDataCard();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Haptics.selection();
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: colors.card,
              title: const Text('Reset App Preferences?'),
              content: const Text(
                  'This will reset chart background, candle themes and preferences back to defaults.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    context.read<AppState>().resetPreferences();
                    Navigator.pop(ctx);
                  },
                  child: Text('Reset Defaults', style: TextStyle(color: colors.destructive)),
                ),
              ],
            ),
          );
        },
        child: Row(
          children: [
            Icon(Icons.restart_alt_rounded, size: 20, color: colors.destructive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reset Preferences & Cache',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colors.destructive,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
