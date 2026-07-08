import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/notification_service.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';

void main() {
  late NotificationService notificationService;
  late EventBus bus;

  setUp(() {
    bus = EventBus.instance;
    notificationService = NotificationService(bus);
  });

  tearDown(() {
    bus.dispose();
  });

  test('showMarginCall publishes MarginCallWarningEvent', () async {
    final completer = Completer<MarginCallWarningEvent>();
    final sub = bus.subscribe<MarginCallWarningEvent>((e) => completer.complete(e));
    notificationService.showMarginCall(12.5);
    final event = await completer.future.timeout(const Duration(seconds: 1));
    expect(event.marginLevel, equals(12.5));
    await sub.cancel();
  });

  test('showLiquidation publishes LiquidationWarningEvent', () async {
    final completer = Completer<LiquidationWarningEvent>();
    final sub = bus.subscribe<LiquidationWarningEvent>((e) => completer.complete(e));
    notificationService.showLiquidation('pos-1', 'ETH', 5.0, 2500.0);
    final event = await completer.future.timeout(const Duration(seconds: 1));
    expect(event.positionId, equals('pos-1'));
    expect(event.symbol, equals('ETH'));
    expect(event.marginLevel, equals(5.0));
    expect(event.liquidationPrice, equals(2500.0));
    await sub.cancel();
  });

  test('showDailyPnl publishes DailyPnlUpdatedEvent', () async {
    final completer = Completer<DailyPnlUpdatedEvent>();
    final sub = bus.subscribe<DailyPnlUpdatedEvent>((e) => completer.complete(e));
    notificationService.showDailyPnl(123.45, 3);
    final event = await completer.future.timeout(const Duration(seconds: 1));
    expect(event.dailyPnl, equals(123.45));
    expect(event.tradesCount, equals(3));
    await sub.cancel();
  });

  test('showTradeCompleted publishes TradeCompletedEvent', () async {
    final completer = Completer<TradeCompletedEvent>();
    final sub = bus.subscribe<TradeCompletedEvent>((e) => completer.complete(e));
    notificationService.showTradeCompleted(
      tradeId: 't-1',
      symbol: 'BTC',
      pnl: 200.0,
      isWin: true,
      closeReason: 'takeProfit',
      riskPct: 1.5,
      riskReward: 3.0,
      durationMs: 5000,
    );
    final event = await completer.future.timeout(const Duration(seconds: 1));
    expect(event.tradeId, equals('t-1'));
    expect(event.symbol, equals('BTC'));
    expect(event.pnl, equals(200.0));
    expect(event.isWin, isTrue);
    expect(event.closeReason, equals('takeProfit'));
    expect(event.riskPct, equals(1.5));
    expect(event.durationMs, equals(5000));
    await sub.cancel();
  });
}
