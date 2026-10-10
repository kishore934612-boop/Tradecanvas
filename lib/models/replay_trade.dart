/// Replay Backtest Trade model.
library;

import 'dart:math' as math;
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
  final double? quantity;
  final double fees;
  final double? initialRiskAmount;
  final double feePercent;
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
    this.quantity,
    this.fees = 0,
    this.initialRiskAmount,
    this.feePercent = 0,
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
      positionSize: order.filledNotional,
      quantity: order.quantity,
      fees: order.totalFees,
      initialRiskAmount: order.initialRiskAmount,
      feePercent: order.feePercent,
      stopLossPrice: order.stopLossPrice,
      takeProfitPrice: order.takeProfitPrice,
      exitReason: order.exitReason,
    );
  }

  bool get isOpen => exitPrice == null;

  double pnl(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final diff = isLong ? (exit - entryPrice) : (entryPrice - exit);
    final units = quantity ?? positionSize / entryPrice;
    return diff * units - fees - (isOpen ? exit * units * feePercent / 100 : 0);
  }

  double pnlPercent(double currentPrice) =>
      positionSize > 0 ? pnl(currentPrice) / positionSize * 100 : 0;

  double? achievedRiskReward(double currentPrice) {
    final risk = initialRiskAmount;
    return risk != null && risk > 0 ? pnl(currentPrice) / risk : null;
  }

  /// Whether the trade was closed by hitting TP.
  bool get closedByTp => exitReason == 'tp_hit';

  /// Whether the trade was closed by hitting SL.
  bool get closedBySl => exitReason == 'sl_hit';

  /// Whether the trade was closed manually.
  bool get closedManually => exitReason == 'manual_close';
}

/// A single testable source of truth for CLOSED-trade performance statistics.
/// Drawdown here is close-to-close balance drawdown, not intrabar equity risk.
class ReplayAnalytics {
  final List<ReplayTrade> trades;
  final double startingBalance;
  late final List<double> pnls = trades.map((t) => t.pnl(t.exitPrice!)).toList();

  ReplayAnalytics(Iterable<ReplayTrade> source, {required this.startingBalance})
      : trades = source.where((t) => !t.isOpen).toList()
          ..sort((a, b) => (a.exitTime ?? a.entryTime).compareTo(b.exitTime ?? b.entryTime));

  int get count => trades.length;
  int get wins => pnls.where((p) => p > 0).length;
  int get losses => pnls.where((p) => p < 0).length;
  int get breakEven => count - wins - losses;
  double get winRate => count == 0 ? 0 : wins / count * 100;
  double get netPnl => pnls.fold(0, (a, b) => a + b);
  double get totalFees => trades.fold(0, (sum, t) => sum + t.fees);
  double get expectancy => count == 0 ? 0 : netPnl / count;
  double? get profitFactor {
    final profit = pnls.where((p) => p > 0).fold(0.0, (a, b) => a + b);
    final loss = -pnls.where((p) => p < 0).fold(0.0, (a, b) => a + b);
    return loss > 0 ? profit / loss : (profit > 0 ? double.infinity : null);
  }

  double get maxDrawdownPercent {
    var balance = startingBalance;
    var peak = balance;
    var worst = 0.0;
    for (final pnl in pnls) {
      balance += pnl;
      peak = math.max(peak, balance);
      if (peak > 0) worst = math.max(worst, (peak - balance) / peak * 100);
    }
    return worst;
  }

  String toCsv() {
    String quote(Object? value) => '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      ['symbol', 'side', 'entry_time_ms', 'exit_time_ms', 'entry', 'exit',
        'quantity', 'fees', 'net_pnl', 'initial_risk', 'net_r', 'exit_reason'],
      for (final t in trades)
        [t.symbol, t.isLong ? 'long' : 'short', t.entryTime, t.exitTime,
          t.entryPrice, t.exitPrice, t.quantity, t.fees, t.pnl(t.exitPrice!),
          t.initialRiskAmount, t.achievedRiskReward(t.exitPrice!), t.exitReason],
    ];
    return rows.map((row) => row.map(quote).join(',')).join('\n');
  }
}
