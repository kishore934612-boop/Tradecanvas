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

  /// Costs and original risk are captured at fill, never changed by stop edits.
  double entryFee = 0;
  double exitFee = 0;
  double feePercent = 0;
  double? initialRiskAmount;
  double get filledNotional => quantity * (fillPrice ?? price);
  double get totalFees => entryFee + exitFee;

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
    return diff * quantity - entryFee - currentPrice * quantity * feePercent / 100;
  }

  /// Net mark-to-market return on actual entry notional.
  double unrealizedPnlPercent(double currentPrice) =>
      filledNotional > 0 ? unrealizedPnl(currentPrice) / filledNotional * 100 : 0;

  /// Realized P&L for a closed position.
  double realizedPnl() {
    if (!isClosed || fillPrice == null || exitPrice == null) return 0.0;
    final diff = isLong
        ? (exitPrice! - fillPrice!)
        : (fillPrice! - exitPrice!);
    return diff * quantity - totalFees;
  }

  double realizedPnlPercent() =>
      filledNotional > 0 ? realizedPnl() / filledNotional * 100 : 0;

  /// Net R multiple uses ORIGINAL risk, not a subsequently moved stop.
  double? achievedRiskReward() {
    final risk = initialRiskAmount;
    return isClosed && risk != null && risk > 0 ? realizedPnl() / risk : null;
  }
}
