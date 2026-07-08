/// Events related to portfolio changes
library;

import 'package:app/core/events/event_bus.dart';

/// Portfolio balance changed event
class BalanceChangedEvent extends AppEvent {
  final double oldBalance;
  final double newBalance;
  final String reason; // 'deposit', 'withdrawal', 'trade', 'fee'
  
  BalanceChangedEvent({
    required this.oldBalance,
    required this.newBalance,
    required this.reason,
  });
  
  // Convenience constructor for simple changes
  factory BalanceChangedEvent.fromChange({
    required double balance,
    required double change,
    required String reason,
  }) {
    return BalanceChangedEvent(
      oldBalance: balance - change,
      newBalance: balance,
      reason: reason,
    );
  }
}

/// Realized P&L event (when position closed)
class RealizedPnlEvent extends AppEvent {
  final double pnl;
  final double totalRealized;
  final double newBalance;
  
  RealizedPnlEvent({
    required this.pnl,
    required this.totalRealized,
    required this.newBalance,
  });
}

/// Portfolio equity changed event
class EquityChangedEvent extends AppEvent {
  final double equity;
  final double unrealizedPnl;
  final double marginUsed;
  final double freeMargin;
  
  EquityChangedEvent({
    required this.equity,
    required this.unrealizedPnl,
    required this.marginUsed,
    required this.freeMargin,
  });
}

/// Margin call event
class MarginCallEvent extends AppEvent {
  final double marginLevel; // percentage
  final List<String> positionsAtRisk;
  
  MarginCallEvent({
    required this.marginLevel,
    required this.positionsAtRisk,
  });
}

/// Margin call warning event (emitted when margin level drops below threshold)
class MarginCallWarningEvent extends AppEvent {
  final double marginLevel; // percentage
  final double usedMargin;
  final double equity;
  final List<String> positionsAtRisk;

  MarginCallWarningEvent({
    required this.marginLevel,
    required this.usedMargin,
    required this.equity,
    required this.positionsAtRisk,
  });
}

/// Achievement unlocked event
class AchievementUnlockedEvent extends AppEvent {
  final String achievementId;
  final String title;
  final String description;
  
  AchievementUnlockedEvent({
    required this.achievementId,
    required this.title,
    required this.description,
  });
}

/// Challenge completed event
class ChallengeCompletedEvent extends AppEvent {
  final String challengeId;
  final String title;
  final double reward;
  
  ChallengeCompletedEvent({
    required this.challengeId,
    required this.title,
    required this.reward,
  });
}

/// Challenge progress updated event
class ChallengeProgressEvent extends AppEvent {
  final String challengeId;
  final double progress; // 0.0 to 1.0
  
  ChallengeProgressEvent({
    required this.challengeId,
    required this.progress,
  });
}

/// Daily P&L updated event
class DailyPnlUpdatedEvent extends AppEvent {
  final double dailyPnl;
  final String dayKey; // 'YYYY-MM-DD'
  final int tradesCount;
  
  DailyPnlUpdatedEvent({
    required this.dailyPnl,
    required this.dayKey,
    required this.tradesCount,
  });
}
