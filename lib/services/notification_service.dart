import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/event_bus.dart';

/// High‑level service exposing notification functionality to the rest of the app.
class NotificationService {
  final EventBus _eventBus;

  NotificationService(this._eventBus);

  void showMarginCall(double marginLevel, {double usedMargin = 0.0, double equity = 0.0, List<String> positionsAtRisk = const []}) {
    _eventBus.publish(MarginCallWarningEvent(
      marginLevel: marginLevel,
      usedMargin: usedMargin,
      equity: equity,
      positionsAtRisk: positionsAtRisk,
    ));
  }

  void showLiquidation(String positionId, String symbol, double marginLevel, double liquidationPrice) {
    _eventBus.publish(LiquidationWarningEvent(
      positionId: positionId,
      symbol: symbol,
      marginLevel: marginLevel,
      liquidationPrice: liquidationPrice,
    ));
  }

  void showDailyPnl(double dailyPnl, int tradesCount, {String? dayKey}) {
    _eventBus.publish(DailyPnlUpdatedEvent(
      dailyPnl: dailyPnl,
      tradesCount: tradesCount,
      dayKey: dayKey ?? DateTime.now().toIso8601String().substring(0, 10),
    ));
  }

  void showTradeCompleted({
    required String tradeId,
    required String symbol,
    required double pnl,
    required bool isWin,
    required String closeReason,
    double? riskReward,
    required double riskPct,
    int durationMs = 0,
  }) {
    _eventBus.publish(TradeCompletedEvent(
      tradeId: tradeId,
      symbol: symbol,
      pnl: pnl,
      isWin: isWin,
      closeReason: closeReason,
      riskReward: riskReward,
      riskPct: riskPct,
      durationMs: durationMs,
    ));
  }
}
