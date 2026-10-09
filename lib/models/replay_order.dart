/// Replay Order model — supports Market, Limit, and Stop-Market orders
/// with optional Take Profit and Stop Loss for the replay execution engine.
library;

enum OrderType { market, limit, stopMarket }
enum OrderSide { buy, sell }
enum OrderStatus { pending, filled, cancelled, expired }

class ReplayOrder {
  final String id;
  final OrderSide side;
  final OrderType type;

  /// Trigger/limit price. For market orders, this is the fill price (current close).
  final double price;

  /// Optional TP/SL levels for auto-close during replay advance.
  double? stopLossPrice;
  double? takeProfitPrice;

  /// Position size in quote currency (e.g. USDT).
  final double positionSize;

  /// Quantity in base currency (e.g. BTC).
  final double quantity;

  /// Playhead index when the order was placed.
  final int createdAtBar;

  /// Timestamp (ms) when the order was placed.
  final int createdAtTimestamp;

  OrderStatus status;
  int? filledAtBar;
  double? fillPrice;
  int? filledAtTimestamp;

  /// Exit tracking for closed positions.
  double? exitPrice;
  int? exitAtBar;
  int? exitAtTimestamp;
  String? exitReason; // 'tp_hit', 'sl_hit', 'manual_close', 'cancelled'

  ReplayOrder({
    required this.id,
    required this.side,
    required this.type,
    required this.price,
    this.stopLossPrice,
    this.takeProfitPrice,
    required this.positionSize,
    required this.quantity,
    required this.createdAtBar,
    required this.createdAtTimestamp,
    this.status = OrderStatus.pending,
    this.filledAtBar,
    this.fillPrice,
    this.filledAtTimestamp,
    this.exitPrice,
    this.exitAtBar,
    this.exitAtTimestamp,
    this.exitReason,
  });

  bool get isPending => status == OrderStatus.pending;
  bool get isFilled => status == OrderStatus.filled;
  bool get isOpen => isFilled && exitPrice == null;
  bool get isClosed => isFilled && exitPrice != null;
  bool get isLong => side == OrderSide.buy;
  bool get isShort => side == OrderSide.sell;

  /// Unrealized P&L for an open filled position.
  double unrealizedPnl(double currentPrice) {
    if (!isOpen || fillPrice == null) return 0.0;
    final diff = isLong
        ? (currentPrice - fillPrice!)
        : (fillPrice! - currentPrice);
    return (diff / fillPrice!) * positionSize;
  }

  /// Unrealized P&L as a percentage of position size.
  double unrealizedPnlPercent(double currentPrice) {
    if (!isOpen || fillPrice == null) return 0.0;
    final diff = isLong
        ? (currentPrice - fillPrice!)
        : (fillPrice! - currentPrice);
    return (diff / fillPrice!) * 100.0;
  }

  /// Realized P&L for a closed position.
  double realizedPnl() {
    if (!isClosed || fillPrice == null || exitPrice == null) return 0.0;
    final diff = isLong
        ? (exitPrice! - fillPrice!)
        : (fillPrice! - exitPrice!);
    return (diff / fillPrice!) * positionSize;
  }

  /// Realized P&L as a percentage.
  double realizedPnlPercent() {
    if (!isClosed || fillPrice == null || exitPrice == null) return 0.0;
    final diff = isLong
        ? (exitPrice! - fillPrice!)
        : (fillPrice! - exitPrice!);
    return (diff / fillPrice!) * 100.0;
  }

  /// Risk-reward ratio achieved (for closed trades).
  double? achievedRiskReward() {
    if (!isClosed || fillPrice == null || exitPrice == null || stopLossPrice == null) {
      return null;
    }
    final risk = (fillPrice! - stopLossPrice!).abs();
    if (risk <= 0) return null;
    final reward = isLong
        ? (exitPrice! - fillPrice!)
        : (fillPrice! - exitPrice!);
    return reward / risk;
  }
}
