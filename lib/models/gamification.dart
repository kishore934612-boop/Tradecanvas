import 'package:flutter/material.dart';

/// Snapshot of aggregate trading stats used to evaluate challenges/achievements.
class TradingStats {
  final int totalTrades;
  final int wins;
  final int losses;
  final int currentWinStreak;
  final int maxWinStreak;
  final double totalReturnPct; // equity vs starting capital
  final double equity;
  final double startingCapital;
  final int consecutiveProfitableDays;
  final int tradingDays;
  final int riskDisciplineTrades; // trades risked <= 1%
  final int riskRewardTrades; // trades with R:R >= 2
  final int ruleViolations;
  final int revengeTrades;
  final int maxTradesInADay;
  final int scalpTrades;
  final int dayTrades;
  final int swingTrades;
  final int positionTrades;
  final int winningTrades;

  const TradingStats({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.currentWinStreak = 0,
    this.maxWinStreak = 0,
    this.totalReturnPct = 0,
    this.equity = 0,
    this.startingCapital = 0,
    this.consecutiveProfitableDays = 0,
    this.tradingDays = 0,
    this.riskDisciplineTrades = 0,
    this.riskRewardTrades = 0,
    this.ruleViolations = 0,
    this.revengeTrades = 0,
    this.maxTradesInADay = 0,
    this.scalpTrades = 0,
    this.dayTrades = 0,
    this.swingTrades = 0,
    this.positionTrades = 0,
    this.winningTrades = 0,
  });

  double get winRate => totalTrades == 0 ? 0 : (wins / totalTrades) * 100.0;
}

enum ChallengeCategory { beginner, intermediate, advanced, discipline, consistency }

extension ChallengeCategoryX on ChallengeCategory {
  String get label {
    switch (this) {
      case ChallengeCategory.beginner:
        return 'Beginner';
      case ChallengeCategory.intermediate:
        return 'Intermediate';
      case ChallengeCategory.advanced:
        return 'Advanced';
      case ChallengeCategory.discipline:
        return 'Discipline';
      case ChallengeCategory.consistency:
        return 'Consistency';
    }
  }
}

class ChallengeDef {
  final String id;
  final String title;
  final String description;
  final ChallengeCategory category;
  final IconData icon;

  /// Returns current progress value given stats.
  final double Function(TradingStats) progress;

  /// Target value progress is measured against.
  final double target;

  /// Optional unit suffix for display (e.g. '%').
  final String unit;

  const ChallengeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.progress,
    required this.target,
    this.unit = '',
  });

  double progressPct(TradingStats s) {
    final p = progress(s);
    if (target <= 0) return p > 0 ? 1.0 : 0.0;
    return (p / target).clamp(0.0, 1.0);
  }

  bool isComplete(TradingStats s) => progress(s) >= target;
}

final List<ChallengeDef> kChallenges = [
  // Beginner
  ChallengeDef(
    id: 'ch_10_profit',
    title: 'Make 10 Profitable Trades',
    description: 'Close 10 trades in the green.',
    category: ChallengeCategory.beginner,
    icon: Icons.emoji_events_outlined,
    progress: (s) => s.wins.toDouble(),
    target: 10,
  ),
  // Intermediate
  ChallengeDef(
    id: 'ch_10_return',
    title: 'Achieve 10% Return',
    description: 'Grow your account by 10%.',
    category: ChallengeCategory.intermediate,
    icon: Icons.trending_up_rounded,
    progress: (s) => s.totalReturnPct.clamp(0, 1000),
    target: 10,
    unit: '%',
  ),
  // Advanced
  ChallengeDef(
    id: 'ch_double',
    title: 'Double Your Account',
    description: 'Reach a 100% total return.',
    category: ChallengeCategory.advanced,
    icon: Icons.rocket_launch_rounded,
    progress: (s) => s.totalReturnPct.clamp(0, 1000),
    target: 100,
    unit: '%',
  ),
  // Discipline
  ChallengeDef(
    id: 'ch_no_revenge',
    title: 'No Revenge Trading',
    description: 'Complete 10 trades without revenge trading.',
    category: ChallengeCategory.discipline,
    icon: Icons.shield_outlined,
    progress: (s) => s.revengeTrades > 0 ? 0 : s.totalTrades.toDouble(),
    target: 10,
  ),
  ChallengeDef(
    id: 'ch_2_per_day',
    title: 'Only 2 Trades / Day',
    description: 'Trade across 3 sessions with max 2 trades each day.',
    category: ChallengeCategory.discipline,
    icon: Icons.av_timer_rounded,
    progress: (s) => s.maxTradesInADay > 2 ? 0 : s.tradingDays.toDouble(),
    target: 3,
  ),
  ChallengeDef(
    id: 'ch_risk_1pct',
    title: 'Risk ≤ 1% Per Trade',
    description: 'Keep risk at or under 1% for 10 trades.',
    category: ChallengeCategory.discipline,
    icon: Icons.security_rounded,
    progress: (s) => s.ruleViolations > 0 ? s.riskDisciplineTrades.toDouble().clamp(0, 9) : s.riskDisciplineTrades.toDouble(),
    target: 10,
  ),
  ChallengeDef(
    id: 'ch_2to1_rr',
    title: 'Maintain 2:1 Risk-Reward',
    description: 'Place 10 trades with a 2:1 reward target.',
    category: ChallengeCategory.discipline,
    icon: Icons.balance_rounded,
    progress: (s) => s.riskRewardTrades.toDouble(),
    target: 10,
  ),
  // Consistency
  ChallengeDef(
    id: 'ch_5_green_days',
    title: '5 Profitable Days in a Row',
    description: 'String together 5 consecutive green days.',
    category: ChallengeCategory.consistency,
    icon: Icons.local_fire_department_rounded,
    progress: (s) => s.consecutiveProfitableDays.toDouble(),
    target: 5,
  ),
  ChallengeDef(
    id: 'ch_20_sessions',
    title: '20 Trading Sessions',
    description: 'Trade on 20 different days.',
    category: ChallengeCategory.consistency,
    icon: Icons.calendar_month_rounded,
    progress: (s) => s.tradingDays.toDouble(),
    target: 20,
  ),
  ChallengeDef(
    id: 'ch_no_violations',
    title: 'No Rule Violations',
    description: 'Complete 20 trades with zero rule violations.',
    category: ChallengeCategory.consistency,
    icon: Icons.verified_user_rounded,
    progress: (s) => s.ruleViolations > 0 ? 0 : s.totalTrades.toDouble(),
    target: 20,
  ),
];

class AchievementDef {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(TradingStats) unlocked;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
  });
}

final List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'a_first_trade',
    title: 'First Trade',
    description: 'Place your very first trade.',
    icon: Icons.flag_rounded,
    unlocked: (s) => s.totalTrades >= 1,
  ),
  AchievementDef(
    id: 'a_first_win',
    title: 'First Winning Trade',
    description: 'Close a trade in profit.',
    icon: Icons.thumb_up_rounded,
    unlocked: (s) => s.wins >= 1,
  ),
  AchievementDef(
    id: 'a_5_streak',
    title: '5 Wins in a Row',
    description: 'Win 5 trades consecutively.',
    icon: Icons.whatshot_rounded,
    unlocked: (s) => s.maxWinStreak >= 5,
  ),
  AchievementDef(
    id: 'a_risk_master',
    title: 'Risk Master',
    description: 'Risk ≤ 1% on 10 trades.',
    icon: Icons.security_rounded,
    unlocked: (s) => s.riskDisciplineTrades >= 10,
  ),
  AchievementDef(
    id: 'a_swing',
    title: 'Swing Trader',
    description: 'Hold a swing trade to close.',
    icon: Icons.waves_rounded,
    unlocked: (s) => s.swingTrades >= 1,
  ),
  AchievementDef(
    id: 'a_scalper',
    title: 'Scalper',
    description: 'Close a sub-15-minute scalp.',
    icon: Icons.bolt_rounded,
    unlocked: (s) => s.scalpTrades >= 1,
  ),
  AchievementDef(
    id: 'a_trend',
    title: 'Trend Follower',
    description: 'Rack up 10 winning trades.',
    icon: Icons.trending_up_rounded,
    unlocked: (s) => s.winningTrades >= 10,
  ),
  AchievementDef(
    id: 'a_100_trades',
    title: '100 Trades Completed',
    description: 'Complete 100 trades.',
    icon: Icons.military_tech_rounded,
    unlocked: (s) => s.totalTrades >= 100,
  ),
];
