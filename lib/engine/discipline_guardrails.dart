/// Discipline Guardrails — enforces configurable risk limits during replay
/// backtesting sessions to build trading discipline.
///
/// Pure Dart, no Flutter dependency. Checks session state against rules
/// and returns violations that the UI can act on.
library;

/// Which guardrail was violated.
enum GuardrailViolation {
  maxDrawdown,
  consecutiveLosses,
  maxTrades;

  String get label {
    switch (this) {
      case GuardrailViolation.maxDrawdown:
        return 'Max Drawdown Reached';
      case GuardrailViolation.consecutiveLosses:
        return 'Max Consecutive Losses';
      case GuardrailViolation.maxTrades:
        return 'Max Trades Per Session';
    }
  }

  String get icon {
    switch (this) {
      case GuardrailViolation.maxDrawdown:
        return '📉';
      case GuardrailViolation.consecutiveLosses:
        return '🔻';
      case GuardrailViolation.maxTrades:
        return '🛑';
    }
  }
}

/// Configuration for discipline guardrails.
class DisciplineSettings {
  /// Maximum drawdown from starting balance before session is locked (%).
  final double maxDailyDrawdownPercent;

  /// Maximum consecutive losing trades before session is locked.
  final int maxConsecutiveLosses;

  /// Maximum total trades allowed per session.
  final int maxTradesPerSession;

  /// Master toggle.
  final bool enabled;

  /// Individual toggles.
  final bool drawdownEnabled;
  final bool consecutiveLossesEnabled;
  final bool maxTradesEnabled;

  const DisciplineSettings({
    this.maxDailyDrawdownPercent = 3.0,
    this.maxConsecutiveLosses = 3,
    this.maxTradesPerSession = 10,
    this.enabled = false,
    this.drawdownEnabled = true,
    this.consecutiveLossesEnabled = true,
    this.maxTradesEnabled = true,
  });

  DisciplineSettings copyWith({
    double? maxDailyDrawdownPercent,
    int? maxConsecutiveLosses,
    int? maxTradesPerSession,
    bool? enabled,
    bool? drawdownEnabled,
    bool? consecutiveLossesEnabled,
    bool? maxTradesEnabled,
  }) {
    return DisciplineSettings(
      maxDailyDrawdownPercent:
          maxDailyDrawdownPercent ?? this.maxDailyDrawdownPercent,
      maxConsecutiveLosses: maxConsecutiveLosses ?? this.maxConsecutiveLosses,
      maxTradesPerSession: maxTradesPerSession ?? this.maxTradesPerSession,
      enabled: enabled ?? this.enabled,
      drawdownEnabled: drawdownEnabled ?? this.drawdownEnabled,
      consecutiveLossesEnabled:
          consecutiveLossesEnabled ?? this.consecutiveLossesEnabled,
      maxTradesEnabled: maxTradesEnabled ?? this.maxTradesEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'maxDailyDrawdownPercent': maxDailyDrawdownPercent,
        'maxConsecutiveLosses': maxConsecutiveLosses,
        'maxTradesPerSession': maxTradesPerSession,
        'enabled': enabled,
        'drawdownEnabled': drawdownEnabled,
        'consecutiveLossesEnabled': consecutiveLossesEnabled,
        'maxTradesEnabled': maxTradesEnabled,
      };

  factory DisciplineSettings.fromJson(Map<String, dynamic> j) =>
      DisciplineSettings(
        maxDailyDrawdownPercent:
            (j['maxDailyDrawdownPercent'] as num?)?.toDouble() ?? 3.0,
        maxConsecutiveLosses:
            (j['maxConsecutiveLosses'] as num?)?.toInt() ?? 3,
        maxTradesPerSession:
            (j['maxTradesPerSession'] as num?)?.toInt() ?? 10,
        enabled: j['enabled'] as bool? ?? false,
        drawdownEnabled: j['drawdownEnabled'] as bool? ?? true,
        consecutiveLossesEnabled:
            j['consecutiveLossesEnabled'] as bool? ?? true,
        maxTradesEnabled: j['maxTradesEnabled'] as bool? ?? true,
      );
}

/// Stateless discipline checker.
class DisciplineGuardrails {
  DisciplineGuardrails._();

  /// Check if a new trade is allowed given current session state.
  /// Returns `null` if trading is permitted, or the [GuardrailViolation] if not.
  static GuardrailViolation? checkViolation({
    required DisciplineSettings settings,
    required double startingBalance,
    required double currentBalance,
    required int consecutiveLosses,
    required int totalTrades,
  }) {
    if (!settings.enabled) return null;

    // 1. Max drawdown check.
    if (settings.drawdownEnabled && startingBalance > 0) {
      final drawdownPercent =
          ((startingBalance - currentBalance) / startingBalance) * 100.0;
      if (drawdownPercent >= settings.maxDailyDrawdownPercent) {
        return GuardrailViolation.maxDrawdown;
      }
    }

    // 2. Consecutive losses check.
    if (settings.consecutiveLossesEnabled) {
      if (consecutiveLosses >= settings.maxConsecutiveLosses) {
        return GuardrailViolation.consecutiveLosses;
      }
    }

    // 3. Max trades per session check.
    if (settings.maxTradesEnabled) {
      if (totalTrades >= settings.maxTradesPerSession) {
        return GuardrailViolation.maxTrades;
      }
    }

    return null;
  }

  /// Get a user-facing message explaining why trading is blocked.
  static String getViolationMessage(
    GuardrailViolation violation, {
    double? drawdownPercent,
    int? consecutiveLosses,
    int? totalTrades,
    int? maxTrades,
  }) {
    switch (violation) {
      case GuardrailViolation.maxDrawdown:
        final pct = drawdownPercent?.toStringAsFixed(1) ?? '?';
        return 'Session drawdown has reached -$pct%. Take a break, review '
            'your trades, and identify what went wrong before continuing.';
      case GuardrailViolation.consecutiveLosses:
        final count = consecutiveLosses ?? '?';
        return '$count consecutive losses detected. Step back, reassess your '
            'strategy, and only resume when you have a clear edge.';
      case GuardrailViolation.maxTrades:
        final taken = totalTrades ?? '?';
        final max = maxTrades ?? '?';
        return 'You have taken $taken / $max trades this session. Overtrading '
            'is one of the biggest account killers. Quality over quantity.';
    }
  }

  /// Get a motivational tip based on the violation type.
  static String getViolationTip(GuardrailViolation violation) {
    switch (violation) {
      case GuardrailViolation.maxDrawdown:
        return '💡 Pro Tip: The best traders know when NOT to trade. '
            'Capital preservation is the #1 priority.';
      case GuardrailViolation.consecutiveLosses:
        return '💡 Pro Tip: Consecutive losses often signal a regime change. '
            'Review whether market conditions match your strategy.';
      case GuardrailViolation.maxTrades:
        return '💡 Pro Tip: Studies show that traders who take fewer, '
            'higher-quality setups outperform high-frequency approaches.';
    }
  }
}
