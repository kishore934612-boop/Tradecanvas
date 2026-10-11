import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/replay_execution.dart';
import 'package:app/models/replay_order.dart';
import 'package:app/models/replay_trade.dart';

CandleData bar({double open = 100, double high = 112, double low = 90, double close = 100}) =>
    CandleData(timestamp: 0, open: open, high: high, low: low, close: close);
ReplayOrder order({OrderSide side = OrderSide.buy, OrderType type = OrderType.limit}) =>
    ReplayOrder(id: 'test', side: side, type: type, price: 100,
      stopLossPrice: side == OrderSide.buy ? 95 : 105,
      takeProfitPrice: side == OrderSide.buy ? 110 : 90,
      positionSize: 1000, quantity: 10, createdAtBar: 0, createdAtTimestamp: 0);

void main() {
  const policy = ReplayExecution(feePercent: 0.1, slippagePercent: 0.1);
  test('limits improve at opening gaps and never slip through limit', () {
    expect(policy.entry(order(), bar(open: 98))!.price, 98);
    expect(policy.entry(order(side: OrderSide.sell), bar(open: 103))!.price, 103);
    expect(policy.entry(order(), bar(open: 105))!.price, 100);
  });
  test('stop-market gaps use open plus adverse slippage', () {
    expect(policy.entry(order(type: OrderType.stopMarket), bar(open: 105))!.price, closeTo(105.105, 1e-9));
    expect(policy.entry(order(side: OrderSide.sell, type: OrderType.stopMarket), bar(open: 95))!.price, closeTo(94.905, 1e-9));
  });
  test('stops take priority when both exits touch intrabar', () {
    final exit = policy.exit(order(), bar())!;
    expect(exit.reason, 'sl_hit');
    expect(exit.price, closeTo(94.905, 1e-9));
    expect(policy.exit(order(side: OrderSide.sell), bar())!.price, closeTo(105.105, 1e-9));
  });
  test('stop gap is not filled at an unavailable stop price', () {
    expect(policy.exit(order(), bar(open: 90, low: 85))!.price, closeTo(89.91, 1e-9));
  });
  test('opening target precedes later adverse range', () {
    expect(policy.exit(order(), bar(open: 111))!.reason, 'tp_hit');
  });
  test('intrabar entry cannot claim an earlier favorable touch', () {
    expect(policy.exit(order(), bar(open: 105, low: 99, high: 112, close: 103), enteredIntrabar: true), isNull);
    expect(policy.exit(order(), bar(open: 105, low: 99, high: 112, close: 111), enteredIntrabar: true)!.reason, 'tp_hit');
  });
  test('order, trade and journal share quantity-based net accounting', () {
    final o = order()..status = OrderStatus.filled..fillPrice = 98
      ..exitPrice = 110..entryFee = 0.98..exitFee = 1.1..initialRiskAmount = 32;
    expect(o.realizedPnl(), closeTo(117.92, 1e-9));
    final trade = ReplayTrade.fromOrder(o, 'BTCUSDT');
    expect(trade.pnl(200), o.realizedPnl());
    o.stopLossPrice = 97;
    expect(o.achievedRiskReward(), closeTo(117.92 / 32, 1e-9));
    final stats = ReplayAnalytics([trade], startingBalance: 10000);
    expect(stats.profitFactor, double.infinity);
    expect(stats.totalFees, closeTo(2.08, 1e-9));
    expect(stats.toCsv(), contains('"net_pnl"'));
    expect(stats.netPnl, trade.pnl(0));
  });
  test('analytics excludes open trades and uses chronological peak drawdown', () {
    ReplayTrade trade(int time, double exit) => ReplayTrade(symbol: 'BTCUSDT',
      isLong: true, entryPrice: 100, entryTime: time, exitTime: time + 1,
      exitPrice: exit, positionSize: 100, quantity: 1);
    final stats = ReplayAnalytics([trade(3, 90), trade(1, 110),
      ReplayTrade(symbol: 'BTCUSDT', isLong: true, entryPrice: 100, entryTime: 5)],
      startingBalance: 100);
    expect(stats.count, 2);
    expect(stats.profitFactor, 1);
    expect(stats.expectancy, 0);
    expect(stats.maxDrawdownPercent, closeTo(10 / 110 * 100, 1e-9));
    expect(ReplayAnalytics([], startingBalance: 100).profitFactor, isNull);
  });
}
