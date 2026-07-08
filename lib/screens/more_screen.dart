import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/gamification.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/providers/learn_provider.dart';
import 'package:app/components/ui.dart';
import 'package:app/screens/challenges_screen.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/screens/subscription_screen.dart';
import 'package:app/screens/analytics_screen.dart';
import 'package:app/screens/leaderboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = Provider.of<AppState>(context);
    final tradingProvider = Provider.of<TradingProvider>(context);
    final s = tradingProvider.stats;

    final completedChallenges = kChallenges.where((c) => c.isComplete(s)).length;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Profile'),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  // 1. USER PROFILE SECTION
                  _buildUserProfile(context, appState, colors),
                  const SizedBox(height: 16.0),



                  // 4. TRADING ANALYTICS SECTION
                  _buildSectionCard(
                    context,
                    colors,
                    title: 'TRADING ANALYTICS',
                    icon: Icons.bar_chart_rounded,
                    iconColor: colors.primary,
                    titleText: 'Win Rate: ${tradingProvider.winRate.toStringAsFixed(1)}%  ·  ${tradingProvider.trades.length} Trades',
                    subtitleText: 'Total Return: ${tradingProvider.totalReturnPct >= 0 ? "+" : ""}${tradingProvider.totalReturnPct.toStringAsFixed(2)}% · View full metrics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 5. CHALLENGE PROGRESS SECTION
                  _buildSectionCard(
                    context,
                    colors,
                    title: 'CHALLENGES PROGRESS',
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Colors.purple,
                    titleText: '$completedChallenges of ${kChallenges.length} Active Completed',
                    subtitleText: 'Practice disciplined guidelines and trading rules',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChallengesScreen())),
                  ),
                  const SizedBox(height: 16.0),



                  // 7. SUBSCRIPTION SECTION
                  _buildSectionCard(
                    context,
                    colors,
                    title: 'TRADEVERSE PRO',
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Colors.orange,
                    titleText: appState.isProUser ? 'Pro Membership Active' : 'Upgrade to TradeVerse Pro',
                    subtitleText: 'Unlock AI Coach, Replay Mode, and Advanced Analytics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 7.5 LEADERBOARD SECTION
                  _buildNavigationRow(
                    context,
                    colors,
                    icon: Icons.leaderboard_rounded,
                    title: 'Leaderboard',
                    subtitle: 'Global trader rankings and metrics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // 8. SETTINGS SECTION
                  _buildNavigationRow(
                    context,
                    colors,
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    subtitle: 'Theme, profile settings, triggers',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                  const SizedBox(height: 12.0),



                  // 10. ABOUT SECTION
                  _buildAboutSection(colors),
                  const SizedBox(height: 24.0),

                  // 11. LOGOUT SECTION
                  _buildLogoutButton(context, appState, tradingProvider, colors),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUB-BUILDERS ---

  Widget _buildUserProfile(BuildContext context, AppState appState, ThemePalette colors) {
    final isLoggedIn = appState.isAuthenticated;
    final isPro = appState.isProUser;

    return GlassCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  gradient: colors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: colors.glowShadow,
                ),
                child: Icon(
                  isLoggedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded,
                  color: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                  size: 28.0,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isLoggedIn ? appState.username! : 'Guest User',
                          style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: colors.foreground),
                        ),
                        if (isPro) ...[
                          const SizedBox(width: 6.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                            decoration: BoxDecoration(
                              gradient: colors.primaryGradient,
                              borderRadius: BorderRadius.circular(6.0),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      isLoggedIn ? appState.email! : 'Guest Account  ·  Local Data Storage Only',
                      style: TextStyle(fontSize: 12.0, color: colors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLoggedIn) ...[
            const SizedBox(height: 16.0),
            Divider(height: 1.0, color: colors.border),
            const SizedBox(height: 12.0),
            Text(
              'Sign in to sync your portfolio, learning logs, and appear on the ranks Leaderboard.',
              style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              height: 44.0,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final success = await appState.signInWithGoogle();
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google Sign-In Successful! Syncing data...')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google Sign-In failed or was cancelled.')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login_rounded, size: 18.0),
                label: const Text('Connect Google Sign-In', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }





  Widget _buildSectionCard(
    BuildContext context,
    ThemePalette colors, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required String titleText,
    required String subtitleText,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(title, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: colors.mutedForeground, letterSpacing: 0.6)),
        ),
        GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(icon, color: iconColor, size: 22.0),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleText, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                    const SizedBox(height: 2.0),
                    Text(subtitleText, style: TextStyle(fontSize: 11.5, color: colors.mutedForeground)),
                  ],
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationRow(
    BuildContext context,
    ThemePalette colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(icon, color: colors.primary, size: 22.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: colors.foreground)),
                const SizedBox(height: 2.0),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: colors.mutedForeground)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.mutedForeground),
        ],
      ),
    );
  }

  Widget _buildAboutSection(ThemePalette colors) {
    return Column(
      children: [
        const SizedBox(height: 8.0),
        Center(child: Text('TradeVerse · Paper Trading Simulator', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.bold))),
        const SizedBox(height: 4.0),
        Center(child: Text('Version 1.1.0 (Build 2)  ·  Crypto Only Refactoring', style: TextStyle(fontSize: 11.0, color: colors.mutedForeground.withValues(alpha: 0.7), fontWeight: FontWeight.w500))),
        const SizedBox(height: 6.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'All portfolios and trading data are purely virtual. Cryptocurrency prices are simulated or fed from the Binance public network. This is not financial advice.',
            style: TextStyle(fontSize: 10.0, color: colors.mutedForeground.withValues(alpha: 0.5), height: 1.3),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context, AppState appState, TradingProvider provider, ThemePalette colors) {
    final isLoggedIn = appState.isAuthenticated;
    final learnProvider = Provider.of<LearnProvider>(context, listen: false);

    return SizedBox(
      width: double.infinity,
      height: 46.0,
      child: TextButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          if (isLoggedIn) {
            appState.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logged out of Google account.')),
            );
          } else {
            // Clear guest data
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: colors.card,
                title: Text('Reset Guest Data', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold)),
                content: Text('This clears all local trades, positions, and resets your balance. This cannot be undone.', style: TextStyle(color: colors.foreground)),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: TextStyle(color: colors.mutedForeground))),
                  TextButton(
                    onPressed: () {
                      provider.resetAccount();
                      learnProvider.resetProgress();
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Guest data cleared successfully!')),
                      );
                    },
                    child: Text('Reset', style: TextStyle(color: colors.destructive, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }
        },
        style: TextButton.styleFrom(
          backgroundColor: colors.destructive.withValues(alpha: 0.1),
          foregroundColor: colors.destructive,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        ),
        icon: Icon(isLoggedIn ? Icons.logout_rounded : Icons.delete_forever_rounded, size: 18.0),
        label: Text(
          isLoggedIn ? 'Log Out Account' : 'Reset Guest Data & Trades',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }


}
