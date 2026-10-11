import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/replay_controller.dart';
import 'package:app/engine/replay_execution.dart';
import 'package:app/engine/discipline_guardrails.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/replay_order.dart';

const symbol = Instrument(symbol: 'BTCUSDT', base: 'BTC', quote: 'USDT');
List<CandleData> history([int n = 210]) => List.generate(n, (i) => CandleData(
    timestamp: i * 60000, open: 100, high: 101, low: 99, close: 100, volume: 100));
class FakeMarket extends Fake implements MarketProvider {
  List<CandleData> data = history();
  List<CandleData> htf = List.generate(30, (i) => CandleData(
    timestamp: i * 900000, open: 100, high: 101, low: 99, close: 100));
  Completer<List<CandleData>>? delayed;
  bool fail = false;
  @override
  Future<List<CandleData>> fetchOHLC(String symbol, String interval,
      {int? limit, int? endTime}) async {
    if (fail) throw StateError('offline');
    if (interval == '1m') {
      if (delayed != null) return delayed!.future;
      return data;
    }
    return htf;
  }
}
ReplayController controller(FakeMarket provider) => ReplayController(
    provider: provider, logger: Logger()..setEnabled(false), instrument: symbol,
    timeframe: Timeframe.m1,
    execution: const ReplayExecution(feePercent: 0.1, slippagePercent: 0));
String? buy(ReplayController c, {double quantity = 10, double? sl = 95, double tp = 110}) =>
    c.placeOrder(side: OrderSide.buy, type: OrderType.market,
      price: 100, positionSize: quantity * 100, quantity: quantity,
      stopLossPrice: sl, takeProfitPrice: tp);

void main() {
  late FakeMarket provider;
  late ReplayController c;
  setUp(() { provider = FakeMarket(); c = controller(provider); });
  tearDown(() => c.dispose());
  test('cannot trade or step before history is ready', () {
    expect(buy(c), isNull);
    c.stepForward();
    expect(c.hasData, isFalse);
  });
  test('market order fills next bar, charges fees once and reconciles balance', () async {
    await c.load();
    expect(buy(c), isNotNull);
    expect(c.openPosition, isNull);
    expect(c.pendingOrders.length, 1);
    c.stepForward();
    expect(c.openPosition!.fillPrice, 100);
    expect(c.accountBalance, 9999);
    expect(c.equity, 9998);
    c.closePosition();
    expect(c.closedTrades.single.realizedPnl(), -2);
    expect(c.accountBalance, 9998);
    c.closePosition();
    expect(c.closedTrades.length, 1);
  });
  test('invalid stops, NaN and oversized orders are rejected', () async {
    await c.load();
    expect(buy(c, sl: null), isNull);
    expect(buy(c, sl: 105), isNull);
    expect(buy(c, quantity: double.nan), isNull);
    expect(buy(c, quantity: 1000), isNull);
    expect(c.pendingOrders, isEmpty);
  });
  test('only one pending or open order may reserve buying power', () async {
    await c.load();
    expect(buy(c), isNotNull);
    expect(buy(c), isNull);
    c.cancelOrder(c.pendingOrders.single.id);
    expect(buy(c), isNotNull);
  });
  test('unaffordable gap cancels before filling', () async {
    provider.data[200] = provider.data[200].copyWith(open: 120, high: 121, low: 119, close: 120);
    await c.load();
    buy(c);
    c.stepForward();
    expect(c.openPositions, isEmpty);
    expect(c.pendingOrders, isEmpty);
    expect(c.accountBalance, 10000);
    expect(c.lastOrderError, contains('gap'));
  });
  test('seek processes intermediate exits identically to stepping', () async {
    provider.data[201] = provider.data[201].copyWith(high: 112);
    await c.load();
    buy(c);
    c.seekToProgress(1);
    expect(c.closedTrades.single.exitReason, 'tp_hit');
    expect(c.closedTrades.single.exitAtBar, 201);
    expect(c.accountBalance, closeTo(10097.9, 1e-8));
  });
  test('rewind cannot retain a ledger and restart clears it', () async {
    await c.load(); buy(c); c.stepForward(); c.closePosition();
    final bars = c.barsElapsed;
    c.stepBackward(); c.seekToProgress(0);
    expect(c.barsElapsed, bars);
    c.restart();
    expect(c.barsElapsed, 0);
    expect(c.closedTrades, isEmpty);
    expect(c.accountBalance, 10000);
  });
  test('HTF candles are filtered by completion time on every step', () async {
    await c.load();
    expect(c.visibleHtfCandles.length, 13); // 200 minutes, 13 complete 15m bars
    c.seekToProgress(1);
    expect(c.visibleHtfCandles.length, 14);
  });
  test('stop edits cannot widen risk or alter initial R denominator', () async {
    await c.load(); buy(c); c.stepForward();
    final risk = c.openPosition!.initialRiskAmount;
    expect(c.modifyPosition(stopLossPrice: 94), isFalse);
    expect(c.modifyPosition(stopLossPrice: 98), isTrue);
    expect(c.openPosition!.initialRiskAmount, risk);
  });
  test('trade cap counts fills and still permits closing an existing position', () async {
    await c.load();
    c.setDisciplineSettings(const DisciplineSettings(maxTradesPerSession: 1));
    buy(c); c.stepForward();
    expect(c.activeViolation, GuardrailViolation.maxTrades);
    c.closePosition();
    expect(c.closedTrades.length, 1);
    expect(buy(c), isNull);
  });
  test('failed load clears stale market state and exits loading', () async {
    await c.load(); buy(c);
    provider.fail = true;
    await c.load();
    expect(c.isLoading, isFalse);
    expect(c.error, isNotNull);
    expect(c.hasData, isFalse);
    expect(c.pendingOrders, isEmpty);
  });
  test('stale load completion cannot replace newer history', () async {
    provider.delayed = Completer<List<CandleData>>();
    final old = provider.delayed!;
    final first = c.load();
    provider.delayed = null;
    await c.load();
    old.complete(history(202));
    await first;
    expect(c.totalBars, 10);
  });
  test('disposal during asynchronous load does not notify disposed listeners', () async {
    final otherProvider = FakeMarket()..delayed = Completer<List<CandleData>>();
    final other = controller(otherProvider);
    final loading = other.load();
    other.dispose();
    otherProvider.delayed!.complete(history());
    await expectLater(loading, completes);
  });
}
