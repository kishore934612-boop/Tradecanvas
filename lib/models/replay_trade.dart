/// Replay Backtest Trade model.
library;

import 'package:app/models/replay_order.dart';

class ReplayTrade {
  final String symbol;
  final bool isLong;
  final double entryPrice;
  final int entryTime;
  double? exitPrice;
  int? exitTime;

  /// Extended fields for the enhanced order system.
  final OrderType orderType;
  final double positionSize;
  final double? stopLossPrice;
  final double? takeProfitPrice;
  String? exitReason; // 'tp_hit', 'sl_hit', 'manual_close', 'cancelled'

  ReplayTrade({
    required this.symbol,
    required this.isLong,
    required this.entryPrice,
    required this.entryTime,
    this.exitPrice,
    this.exitTime,
    this.orderType = OrderType.market,
    this.positionSize = 1000.0,
    this.stopLossPrice,
    this.takeProfitPrice,
    this.exitReason,
  });

  /// Create a ReplayTrade from a closed ReplayOrder for backtest analytics.
  factory ReplayTrade.fromOrder(ReplayOrder order, String symbol) {
    return ReplayTrade(
      symbol: symbol,
      isLong: order.isLong,
      entryPrice: order.fillPrice ?? order.price,
      entryTime: order.filledAtTimestamp ?? order.createdAtTimestamp,
      exitPrice: order.exitPrice,
      exitTime: order.exitAtTimestamp,
      orderType: order.type,
      positionSize: order.positionSize,
      stopLossPrice: order.stopLossPrice,
      takeProfitPrice: order.takeProfitPrice,
      exitReason: order.exitReason,
    );
  }

  bool get isOpen => exitPrice == null;

  double pnl(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final diff = isLong ? (exit - entryPrice) : (entryPrice - exit);
    return (diff / entryPrice) * positionSize;
  }

  double pnlPercent(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    return isLong
        ? ((exit - entryPrice) / entryPrice) * 100
        : ((entryPrice - exit) / entryPrice) * 100;
  }

  /// Risk-reward ratio achieved (for closed trades with SL set).
  double? achievedRiskReward(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    if (stopLossPrice == null) return null;
    final risk = (entryPrice - stopLossPrice!).abs();
    if (risk <= 0) return null;
    final reward = isLong ? (exit - entryPrice) : (entryPrice - exit);
    return reward / risk;
  }

  /// Whether the trade was closed by hitting TP.
  bool get closedByTp => exitReason == 'tp_hit';

  /// Whether the trade was closed by hitting SL.
  bool get closedBySl => exitReason == 'sl_hit';

  /// Whether the trade was closed manually.
  bool get closedManually => exitReason == 'manual_close';
}
