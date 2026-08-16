/// Replay Backtest Trade model.
library;

class ReplayTrade {
  final String symbol;
  final bool isLong;
  final double entryPrice;
  final int entryTime;
  double? exitPrice;
  int? exitTime;

  ReplayTrade({
    required this.symbol,
    required this.isLong,
    required this.entryPrice,
    required this.entryTime,
    this.exitPrice,
    this.exitTime,
  });

  bool get isOpen => exitPrice == null;

  double pnl(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    final diff = isLong ? (exit - entryPrice) : (entryPrice - exit);
    return (diff / entryPrice) * 1000.0;
  }

  double pnlPercent(double currentPrice) {
    final exit = exitPrice ?? currentPrice;
    return isLong
        ? ((exit - entryPrice) / entryPrice) * 100
        : ((entryPrice - exit) / entryPrice) * 100;
  }
}
