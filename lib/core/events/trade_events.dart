/// Events related to trading operations
library;

import 'package:app/core/events/event_bus.dart';
import 'package:app/models/trading_models.dart';

/// Position opened event
class PositionOpenedEvent extends AppEvent {
  final String positionId;
  final String symbol;
  final String side;
  final double quantity;
  final double entryPrice;
  final int leverage;
  final bool isRevengeTrade;
  final bool isRuleViolation;
  final double marginUsed;
  final double feeCharged;
  
  PositionOpenedEvent({
    required this.positionId,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.entryPrice,
    required this.leverage,
    this.isRevengeTrade = false,
    this.isRuleViolation = false,
    this.marginUsed = 0.0,
    this.feeCharged = 0.0,
  });
}

/// Position closed event
class PositionClosedEvent extends AppEvent {
  final String positionId;
  final String symbol;
  final double exitPrice;
  final double pnl;
  final String closeReason; // 'manual', 'stopLoss', 'takeProfit', 'trailingStop', 'liquidation'
  final Trade? trade;        // Completed trade record
  final double returnedMargin;
  
  PositionClosedEvent({
    required this.positionId,
    required this.symbol,
    required this.exitPrice,
    required this.pnl,
    required this.closeReason,
    this.trade,
    this.returnedMargin = 0.0,
  });
}

/// Position updated event (SL/TP modified)
class PositionUpdatedEvent extends AppEvent {
  final String positionId;
  final double? stopLoss;
  final double? takeProfit;
  
  PositionUpdatedEvent({
    required this.positionId,
    this.stopLoss,
    this.takeProfit,
  });
}

/// Order placed event
class OrderPlacedEvent extends AppEvent {
  final String orderId;
  final String symbol;
  final String orderType;
  final double triggerPrice;
  
  OrderPlacedEvent({
    required this.orderId,
    required this.symbol,
    required this.orderType,
    required this.triggerPrice,
  });
}

/// Order filled event
class OrderFilledEvent extends AppEvent {
  final String orderId;
  final String positionId;
  final double filledPrice;
  
  OrderFilledEvent({
    required this.orderId,
    required this.positionId,
    required this.filledPrice,
  });
}

/// Order cancelled event
class OrderCancelledEvent extends AppEvent {
  final String orderId;
  final String reason;
  
  OrderCancelledEvent({
    required this.orderId,
    required this.reason,
  });
}

/// Trade completed event (position opened and closed)
class TradeCompletedEvent extends AppEvent {
  final String tradeId;
  final String symbol;
  final double pnl;
  final bool isWin;
  final int durationMs;
  final String closeReason;
  final double? riskReward;
  final double riskPct;
  final Trade? trade;
  
  TradeCompletedEvent({
    required this.tradeId,
    required this.symbol,
    required this.pnl,
    required this.isWin,
    required this.durationMs,
    required this.closeReason,
    this.riskReward,
    required this.riskPct,
    this.trade,
  });
}

/// Position risk parameters updated event
class PositionRiskUpdatedEvent extends AppEvent {
  final String positionId;
  final double? stopLoss;
  final double? takeProfit;
  final double? trailingStop;
  
  PositionRiskUpdatedEvent({
    required this.positionId,
    this.stopLoss,
    this.takeProfit,
    this.trailingStop,
  });
}

/// Position near liquidation warning event
class LiquidationWarningEvent extends AppEvent {
  final String positionId;
  final String symbol;
  final double marginLevel; // current margin level %
  final double liquidationPrice;
  
  LiquidationWarningEvent({
    required this.positionId,
    required this.symbol,
    required this.marginLevel,
    required this.liquidationPrice,
  });
}
