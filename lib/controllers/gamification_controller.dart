/// Gamification Controller
///
/// Tracks wins/losses, streaks, achievements, and challenges.
/// Subscribes to PositionOpenedEvent and PositionClosedEvent
/// to evaluate gamification state automatically.
library;

import 'package:flutter/foundation.dart';
import 'package:app/models/gamification.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/controllers/portfolio_controller.dart';

class GamificationController extends ChangeNotifier {
  final EventBus _eventBus;
  final Logger _logger;

  // Win/loss tracking
  int _wins = 0;
  int _losses = 0;
  int _currentWinStreak = 0;
  int _maxWinStreak = 0;

  // discipline counters
  int _riskDisciplineTrades = 0;
  int _riskRewardTrades = 0;
  int _ruleViolations = 0;
  int _revengeTrades = 0;

  // style buckets
  int _scalpTrades = 0;
  int _dayTrades = 0;
  int _swingTrades = 0;
  int _positionTrades = 0;

  // per-day aggregates
  final Map<String, int> _tradesPerDay = {};
  final Map<String, double> _dailyRealized = {}; // dayKey -> realized pnl

  // unlock state
  final Set<String> _unlockedAchievements = {};
  final Set<String> _completedChallenges = {};
  final List<String> _recentUnlocks = []; // consumed by UI for toast notifications

  GamificationController({
    required this._eventBus,
    required this._logger,
  }) {
    _logger.info('GamificationController initialized');
    _subscribeToEvents();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  int get wins               => _wins;
  int get losses             => _losses;
  int get currentWinStreak   => _currentWinStreak;
  int get maxWinStreak       => _maxWinStreak;
  int get riskDisciplineTrades => _riskDisciplineTrades;
  int get riskRewardTrades   => _riskRewardTrades;
  int get ruleViolations     => _ruleViolations;
  int get revengeTrades      => _revengeTrades;

  Set<String> get unlockedAchievements => Set.unmodifiable(_unlockedAchievements);
  Set<String> get completedChallenges  => Set.unmodifiable(_completedChallenges);

  bool isAchievementUnlocked(String id) => _unlockedAchievements.contains(id);
  bool isChallengeComplete(String id)   => _completedChallenges.contains(id);

  /// Consumes (and clears) recent unlock titles for UI toast notifications.
  List<String> consumeRecentUnlocks() {
    final copy = List<String>.from(_recentUnlocks);
    _recentUnlocks.clear();
    return copy;
  }

  int get _consecutiveProfitableDays {
    if (_dailyRealized.isEmpty) return 0;
    final keys = _dailyRealized.keys.toList()..sort();
    int streak = 0;
    for (int i = keys.length - 1; i >= 0; i--) {
      if ((_dailyRealized[keys[i]] ?? 0.0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int get _maxTradesInADay => _tradesPerDay.values.fold(0, (m, v) => v > m ? v : m);

  /// Builds a TradingStats snapshot.  Callers should supply context values
  /// (totalTrades, equity, etc.) that live in other controllers.
  TradingStats buildStats({
    required int totalTrades,
    required double totalReturnPct,
    required double equity,
    required double startingCapital,
    required int scalpTrades,
    required int dayTrades,
    required int swingTrades,
    required int positionTrades,
    required int consecutiveProfitableDays,
  }) {
    return TradingStats(
      totalTrades: totalTrades,
      wins: _wins,
      losses: _losses,
      currentWinStreak: _currentWinStreak,
      maxWinStreak: _maxWinStreak,
      totalReturnPct: totalReturnPct,
      equity: equity,
      startingCapital: startingCapital,
      consecutiveProfitableDays: consecutiveProfitableDays,
      tradingDays: _tradesPerDay.length,
      riskDisciplineTrades: _riskDisciplineTrades,
      riskRewardTrades: _riskRewardTrades,
      ruleViolations: _ruleViolations,
      revengeTrades: _revengeTrades,
      maxTradesInADay: _maxTradesInADay,
      scalpTrades: scalpTrades,
      dayTrades: dayTrades,
      swingTrades: swingTrades,
      positionTrades: positionTrades,
      winningTrades: _wins,
    );
  }

  // ============================================================
  // EVALUATION
  // ============================================================

  /// Run through all achievements and challenges against [stats].
  /// Emits events for newly unlocked items.
  void evaluate(TradingStats stats) {
    bool changed = false;

    for (final achievement in kAchievements) {
      if (!_unlockedAchievements.contains(achievement.id) &&
          achievement.unlocked(stats)) {
        _unlockedAchievements.add(achievement.id);
        _recentUnlocks.add('🏆 ${achievement.title}');
        _logger.info('Achievement unlocked: ${achievement.title}');
        _eventBus.publish<AchievementUnlockedEvent>(AchievementUnlockedEvent(
          achievementId: achievement.id,
          title: achievement.title,
          description: achievement.description,
        ));
        changed = true;
      }
    }

    for (final challenge in kChallenges) {
      if (!_completedChallenges.contains(challenge.id) &&
          challenge.isComplete(stats)) {
        _completedChallenges.add(challenge.id);
        _recentUnlocks.add('✅ ${challenge.title}');
        _logger.info('Challenge completed: ${challenge.title}');
        _eventBus.publish<ChallengeCompletedEvent>(ChallengeCompletedEvent(
          challengeId: challenge.id,
          title: challenge.title,
          reward: 0.0,
        ));
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  // ============================================================
  // RECORD EVENTS
  // ============================================================

  /// Record that a trade day has occurred (increments daily counter).
  void recordTradeDay(int timestamp) {
    final dk = dayKey(timestamp);
    _tradesPerDay[dk] = (_tradesPerDay[dk] ?? 0) + 1;
  }

  /// Update discipline flags from a PositionOpenedEvent.
  void recordOpenedPosition({
    required bool isRevengeTrade,
    required bool isRuleViolation,
  }) {
    if (isRevengeTrade) _revengeTrades++;
    if (isRuleViolation) _ruleViolations++;
    if (isRevengeTrade || isRuleViolation) notifyListeners();
  }

  /// Update win/loss streaks from a closed trade.
  void recordClosedTrade({
    required double netPnl,
    double? stopLoss,
    double? takeProfit,
    double? riskPerUnit,
    double? closeQty,
    double? equity,
    double? returnedMargin,
    double? riskPctVal,
    double? riskRewardVal,
  }) {
    // Win / loss streaks
    if (netPnl >= 0) {
      _wins++;
      _currentWinStreak++;
      if (_currentWinStreak > _maxWinStreak) _maxWinStreak = _currentWinStreak;
    } else {
      _losses++;
      _currentWinStreak = 0;
    }

    // Risk discipline / R:R tracking
    if (riskPctVal != null) {
      if (riskPctVal <= 1.0) _riskDisciplineTrades++;
    } else {
      final eq = (equity ?? 1.0) <= 0 ? 1.0 : (equity ?? 1.0);
      if (stopLoss != null && riskPerUnit != null && closeQty != null) {
        final riskPct = (riskPerUnit * closeQty / eq) * 100.0;
        if (riskPct <= 1.0) _riskDisciplineTrades++;
      } else if (returnedMargin != null) {
        final riskPct = (returnedMargin / eq) * 100.0;
        if (riskPct <= 1.0) _riskDisciplineTrades++;
      }
    }

    if (riskRewardVal != null) {
      if (riskRewardVal >= 2.0) _riskRewardTrades++;
    } else if (stopLoss != null && riskPerUnit != null && takeProfit != null && riskPerUnit > 0) {
      final rr = takeProfit / riskPerUnit;
      if (rr >= 2.0) _riskRewardTrades++;
    }

    notifyListeners();
  }

  // ============================================================
  // EVENT SUBSCRIPTIONS
  // ============================================================

  void _subscribeToEvents() {
    // On position opened — track discipline flags
    _eventBus.on<PositionOpenedEvent>().listen((event) {
      recordOpenedPosition(
        isRevengeTrade: event.isRevengeTrade,
        isRuleViolation: event.isRuleViolation,
      );
      recordTradeDay(DateTime.now().millisecondsSinceEpoch);
    });

    // On trade completed — update win/loss + evaluate gamification
    _eventBus.on<TradeCompletedEvent>().listen((event) {
      recordTradeDay(DateTime.now().millisecondsSinceEpoch);
      
      final dk = dayKey(DateTime.now().millisecondsSinceEpoch);
      _dailyRealized[dk] = (_dailyRealized[dk] ?? 0.0) + event.pnl;

      // Update style buckets based on event duration
      final mins = event.durationMs / 60000.0;
      if (mins < 15) {
        _scalpTrades++;
      } else if (mins < 480) {
        _dayTrades++;
      } else if (mins < 10080) {
        _swingTrades++;
      } else {
        _positionTrades++;
      }

      recordClosedTrade(
        netPnl: event.pnl,
        riskPctVal: event.riskPct,
        riskRewardVal: event.riskReward,
      );

      final portfolio = serviceLocator.isRegistered<PortfolioController>()
          ? serviceLocator<PortfolioController>()
          : null;
      final balance = portfolio?.balance ?? 1.0;
      final startingCapital = portfolio?.startingCapital ?? 1.0;
      final totalReturnPct = startingCapital > 0 ? ((balance - startingCapital) / startingCapital) * 100.0 : 0.0;
      final totalTrades = _wins + _losses;

      final stats = buildStats(
        totalTrades: totalTrades,
        totalReturnPct: totalReturnPct,
        equity: balance,
        startingCapital: startingCapital,
        scalpTrades: _scalpTrades,
        dayTrades: _dayTrades,
        swingTrades: _swingTrades,
        positionTrades: _positionTrades,
        consecutiveProfitableDays: _consecutiveProfitableDays,
      );

      evaluate(stats);
    });
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  Map<String, dynamic> toJson() => {
        'wins': _wins,
        'losses': _losses,
        'currentWinStreak': _currentWinStreak,
        'maxWinStreak': _maxWinStreak,
        'riskDisciplineTrades': _riskDisciplineTrades,
        'riskRewardTrades': _riskRewardTrades,
        'ruleViolations': _ruleViolations,
        'revengeTrades': _revengeTrades,
        'scalpTrades': _scalpTrades,
        'dayTrades': _dayTrades,
        'swingTrades': _swingTrades,
        'positionTrades': _positionTrades,
        'tradesPerDay': _tradesPerDay,
        'dailyRealized': _dailyRealized,
        'unlockedAchievements': _unlockedAchievements.toList(),
        'completedChallenges': _completedChallenges.toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    _wins               = json['wins'] as int? ?? 0;
    _losses             = json['losses'] as int? ?? 0;
    _currentWinStreak   = json['currentWinStreak'] as int? ?? 0;
    _maxWinStreak       = json['maxWinStreak'] as int? ?? 0;
    _riskDisciplineTrades = json['riskDisciplineTrades'] as int? ?? 0;
    _riskRewardTrades   = json['riskRewardTrades'] as int? ?? 0;
    _ruleViolations     = json['ruleViolations'] as int? ?? 0;
    _revengeTrades      = json['revengeTrades'] as int? ?? 0;

    _tradesPerDay.clear();
    (json['tradesPerDay'] as Map<String, dynamic>?)?.forEach((k, v) {
      _tradesPerDay[k] = v as int;
    });

    _dailyRealized.clear();
    (json['dailyRealized'] as Map<String, dynamic>?)?.forEach((k, v) {
      _dailyRealized[k] = (v as num).toDouble();
    });

    _scalpTrades = json['scalpTrades'] as int? ?? 0;
    _dayTrades = json['dayTrades'] as int? ?? 0;
    _swingTrades = json['swingTrades'] as int? ?? 0;
    _positionTrades = json['positionTrades'] as int? ?? 0;

    _unlockedAchievements.clear();
    final achievements = json['unlockedAchievements'] as List<dynamic>?;
    if (achievements != null) {
      _unlockedAchievements.addAll(achievements.cast<String>());
    }

    _completedChallenges.clear();
    final challenges = json['completedChallenges'] as List<dynamic>?;
    if (challenges != null) {
      _completedChallenges.addAll(challenges.cast<String>());
    }

    _logger.info(
      'Gamification state loaded: W=$_wins L=$_losses, '
      '${_unlockedAchievements.length} achievements, '
      '${_completedChallenges.length} challenges',
    );
    notifyListeners();
  }

  void reset() {
    _wins = _losses = _currentWinStreak = _maxWinStreak = 0;
    _riskDisciplineTrades = _riskRewardTrades = _ruleViolations = _revengeTrades = 0;
    _scalpTrades = _dayTrades = _swingTrades = _positionTrades = 0;
    _tradesPerDay.clear();
    _dailyRealized.clear();
    _unlockedAchievements.clear();
    _completedChallenges.clear();
    _recentUnlocks.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.info('GamificationController disposed');
    super.dispose();
  }
}
