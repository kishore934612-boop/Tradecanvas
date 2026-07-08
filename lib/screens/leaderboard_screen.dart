import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/leaderboard_models.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/providers/leaderboard_provider.dart';
import 'package:app/components/ui.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  void _refreshData() {
    final appState = context.read<AppState>();
    final tradingProvider = context.read<TradingProvider>();
    final leaderboardProvider = context.read<LeaderboardProvider>();

    leaderboardProvider.fetchLeaderboard(
      isAuthenticated: appState.profile.onboarded,
      currentUsername: 'You (${appState.profile.experience.name})',
      currentUserReturn: tradingProvider.totalReturnPct,
      currentUserWinRate: tradingProvider.winRate,
      currentUserChallenges: tradingProvider.trades.where((t) => t.pnl > 0).length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final leaderboardProvider = Provider.of<LeaderboardProvider>(context);
    final appState = Provider.of<AppState>(context);
    final isLoggedIn = appState.profile.onboarded;

    final entries = leaderboardProvider.entries;
    final top3 = entries.take(3).toList();
    final remaining = entries.skip(3).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Leaderboard',
              showBackButton: true,
              trailing: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _refreshData();
                },
                child: Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: colors.muted.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border, width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.refresh_rounded,
                    color: colors.primary,
                    size: 18.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Timeframe Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(14.0),
                  border: Border.all(color: colors.border, width: 1.0),
                ),
                child: Row(
                  children: ['daily', 'weekly', 'monthly'].map((t) {
                    final isSelected = leaderboardProvider.timeframe == t;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          leaderboardProvider.setTimeframe(t);
                          _refreshData();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          decoration: BoxDecoration(
                            gradient: isSelected ? colors.primaryGradient : null,
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            t.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.0,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white)
                                  : colors.mutedForeground,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 14.0),

            // Guest Mode Alert Banner
            if (!isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: GlassCard(
                  color: colors.destructive.withValues(alpha: 0.08),
                  borderColor: colors.destructive.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.destructive, size: 20.0),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          'Guest Mode enabled. Sign in on the Profile page to sync data and join the Leaderboard ranks.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colors.destructive,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Main Content Area
            Expanded(
              child: leaderboardProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                      ? Center(
                          child: Text(
                            'No entries found.',
                            style: TextStyle(color: colors.mutedForeground),
                          ),
                        )
                      : ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 100.0),
                          children: [
                            if (top3.isNotEmpty) ...[
                              _buildPodiumWidget(top3, colors),
                              const SizedBox(height: 20.0),
                            ],
                            if (remaining.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 20.0, bottom: 10.0),
                                child: Text(
                                  'OTHER COMPETITORS',
                                  style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w800,
                                    color: colors.mutedForeground,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  children: remaining.map((e) => _buildRankCard(e, colors)).toList(),
                                ),
                              ),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumWidget(List<LeaderboardEntry> top3, ThemePalette colors) {
    // Top 3 indices in order: 2nd place (idx 1), 1st place (idx 0), 3rd place (idx 2)
    LeaderboardEntry? first = top3.isNotEmpty ? top3[0] : null;
    LeaderboardEntry? second = top3.length > 1 ? top3[1] : null;
    LeaderboardEntry? third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: colors.border.withValues(alpha: 0.5), width: 0.8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 2nd Place Column
            if (second != null)
              Expanded(
                child: _buildPodiumColumn(
                  second,
                  const Color(0xFFC0C0C0), // Silver
                  95.0,
                  colors,
                ),
              )
            else
              const Spacer(),

            const SizedBox(width: 8.0),

            // 1st Place Column
            if (first != null)
              Expanded(
                child: _buildPodiumColumn(
                  first,
                  const Color(0xFFFFD700), // Gold
                  125.0,
                  colors,
                  isTopSpot: true,
                ),
              )
            else
              const Spacer(),

            const SizedBox(width: 8.0),

            // 3rd Place Column
            if (third != null)
              Expanded(
                child: _buildPodiumColumn(
                  third,
                  const Color(0xFFCD7F32), // Bronze
                  80.0,
                  colors,
                ),
              )
            else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumColumn(
    LeaderboardEntry entry,
    Color metalColor,
    double height,
    ThemePalette colors, {
    bool isTopSpot = false,
  }) {
    final bool isUser = entry.isCurrentUser;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar stack
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isTopSpot ? 62.0 : 52.0,
              height: isTopSpot ? 62.0 : 52.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: metalColor, width: isTopSpot ? 3.0 : 2.0),
                boxShadow: [
                  BoxShadow(
                    color: metalColor.withValues(alpha: 0.25),
                    blurRadius: 10.0,
                    spreadRadius: 2.0,
                  )
                ],
              ),
              child: CircleAvatar(
                backgroundColor: isUser ? colors.primary.withValues(alpha: 0.15) : colors.muted,
                child: Text(
                  entry.username.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: isTopSpot ? 20.0 : 16.0,
                    fontWeight: FontWeight.w900,
                    color: isUser ? colors.primary : colors.foreground,
                  ),
                ),
              ),
            ),
            // Metal Crown Badge
            Positioned(
              top: isTopSpot ? -18.0 : -14.0,
              child: Icon(
                Icons.emoji_events_rounded,
                color: metalColor,
                size: isTopSpot ? 20.0 : 16.0,
              ),
            ),
            // Mini rank indicator at the bottom right
            Positioned(
              bottom: -2.0,
              right: -2.0,
              child: Container(
                width: 18.0,
                height: 18.0,
                decoration: BoxDecoration(
                  color: metalColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${entry.rank}',
                  style: TextStyle(
                    fontSize: 10.0,
                    fontWeight: FontWeight.w900,
                    color: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // Text Username
        Text(
          entry.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isUser ? FontWeight.w900 : FontWeight.bold,
            color: isUser ? colors.primary : colors.foreground,
          ),
        ),
        const SizedBox(height: 2.0),

        // Total Return %
        Text(
          '${entry.totalReturnPct >= 0 ? '+' : ''}${entry.totalReturnPct.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w900,
            color: entry.totalReturnPct >= 0 ? colors.positive : colors.destructive,
          ),
        ),
        const SizedBox(height: 10.0),

        // Elevated column pedestal
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                metalColor.withValues(alpha: 0.15),
                metalColor.withValues(alpha: 0.02),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10.0),
              topRight: Radius.circular(10.0),
            ),
            border: Border(
              top: BorderSide(color: metalColor.withValues(alpha: 0.3), width: 1.0),
              left: BorderSide(color: metalColor.withValues(alpha: 0.15), width: 0.8),
              right: BorderSide(color: metalColor.withValues(alpha: 0.15), width: 0.8),
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Win Rate',
                style: TextStyle(
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                  color: colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                '${entry.winRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w900,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankCard(LeaderboardEntry entry, ThemePalette colors) {
    final isUser = entry.isCurrentUser;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      borderColor: isUser ? colors.primary : colors.border.withValues(alpha: 0.6),
      color: isUser ? colors.primary.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32.0,
            height: 32.0,
            decoration: BoxDecoration(
              color: colors.muted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontSize: 13.0,
                fontWeight: FontWeight.w900,
                color: colors.foreground,
              ),
            ),
          ),
          const SizedBox(width: 14.0),

          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: isUser ? FontWeight.bold : FontWeight.w600,
                        color: colors.foreground,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(fontSize: 8.0, fontWeight: FontWeight.bold, color: colors.primary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2.0),
                Text(
                  'Win Rate: ${entry.winRate.toStringAsFixed(1)}%  ·  Challenges: ${entry.challengesCompleted}',
                  style: TextStyle(fontSize: 11.5, color: colors.mutedForeground),
                ),
              ],
            ),
          ),

          // Return metrics
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.totalReturnPct >= 0 ? '+' : ''}${entry.totalReturnPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.bold,
                  color: entry.totalReturnPct >= 0 ? colors.positive : colors.destructive,
                ),
              ),
              const SizedBox(height: 1.0),
              Text(
                'return',
                style: TextStyle(fontSize: 10.0, color: colors.mutedForeground, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
