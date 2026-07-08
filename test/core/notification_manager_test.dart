import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/notifications/notification_manager.dart';

void main() {
  late EventBus eventBus;
  late NotificationManager notificationManager;

  setUp(() {
    eventBus = EventBus.instance;
    notificationManager = NotificationManager(eventBus: eventBus);
  });

  tearDown(() {
    notificationManager.dispose();
  });

  group('NotificationManager Event Subscriptions', () {
    test('MarginCallWarningEvent creates a notification', () async {
      final completer = Completer<NotificationMessage>();
      final sub = notificationManager.notificationStream.listen((msg) {
        completer.complete(msg);
      });

      eventBus.publish(MarginCallWarningEvent(
        marginLevel: 115.0,
        usedMargin: 1000.0,
        equity: 1150.0,
        positionsAtRisk: ['pos-1'],
      ));

      final msg = await completer.future.timeout(const Duration(seconds: 1));
      expect(msg.type, equals(NotificationType.marginCall));
      expect(msg.title, equals('Margin Call Warning'));
      expect(msg.body, contains('115.0%'));
      expect(notificationManager.notifications.length, equals(1));
      
      await sub.cancel();
    });

    test('LiquidationWarningEvent creates a notification with price', () async {
      final completer = Completer<NotificationMessage>();
      final sub = notificationManager.notificationStream.listen((msg) {
        completer.complete(msg);
      });

      eventBus.publish(LiquidationWarningEvent(
        positionId: 'pos-123',
        symbol: 'BTC',
        marginLevel: 140.0,
        liquidationPrice: 42000.0,
      ));

      final msg = await completer.future.timeout(const Duration(seconds: 1));
      expect(msg.type, equals(NotificationType.liquidation));
      expect(msg.title, equals('Liquidation Warning'));
      expect(msg.body, contains('BTC'));
      expect(msg.body, contains('140.0%'));
      expect(msg.body, contains('42000.00'));
      expect(notificationManager.notifications.length, equals(1));
      
      await sub.cancel();
    });

    test('DailyPnlUpdatedEvent creates a performance notification', () async {
      final completer = Completer<NotificationMessage>();
      final sub = notificationManager.notificationStream.listen((msg) {
        completer.complete(msg);
      });

      eventBus.publish(DailyPnlUpdatedEvent(
        dailyPnl: 250.50,
        tradesCount: 5,
        dayKey: '2026-07-04',
      ));

      final msg = await completer.future.timeout(const Duration(seconds: 1));
      expect(msg.type, equals(NotificationType.dailyPnl));
      expect(msg.title, equals('Daily Performance Update'));
      expect(msg.body, contains('250.50'));
      expect(msg.body, contains('5 trades'));
      expect(notificationManager.notifications.length, equals(1));
      
      await sub.cancel();
    });

    test('TradeCompletedEvent creates a win/loss notification', () async {
      final completer = Completer<NotificationMessage>();
      final sub = notificationManager.notificationStream.listen((msg) {
        completer.complete(msg);
      });

      eventBus.publish(TradeCompletedEvent(
        tradeId: 't-99',
        symbol: 'ETH',
        pnl: 75.0,
        isWin: true,
        durationMs: 120000,
        closeReason: 'takeProfit',
        riskReward: 3.0,
        riskPct: 0.5,
      ));

      final msg = await completer.future.timeout(const Duration(seconds: 1));
      expect(msg.type, equals(NotificationType.tradeCompleted));
      expect(msg.title, equals('Trade Won! 🎉'));
      expect(msg.body, contains('ETH'));
      expect(msg.body, contains('75.00'));
      expect(msg.body, contains('takeProfit'));
      expect(msg.body, contains('3.00'));
      expect(msg.body, contains('0.50%'));
      expect(notificationManager.notifications.length, equals(1));
      
      await sub.cancel();
    });
  });

  group('NotificationManager Operations', () {
    test('markAsRead, markAllAsRead, clearNotification, and clearAll work correctly', () async {
      eventBus.publish(DailyPnlUpdatedEvent(dailyPnl: 10.0, tradesCount: 1, dayKey: '2026-07-04'));
      eventBus.publish(DailyPnlUpdatedEvent(dailyPnl: 20.0, tradesCount: 2, dayKey: '2026-07-04'));

      // Wait a microtask to allow event delivery
      await Future.delayed(Duration.zero);
      expect(notificationManager.notifications.length, equals(2));

      final n1 = notificationManager.notifications[0];
      final n2 = notificationManager.notifications[1];

      expect(n1.isRead, isFalse);
      expect(n2.isRead, isFalse);

      notificationManager.markAsRead(n1.id);
      expect(n1.isRead, isTrue);
      expect(n2.isRead, isFalse);

      notificationManager.markAllAsRead();
      expect(n1.isRead, isTrue);
      expect(n2.isRead, isTrue);

      notificationManager.clearNotification(n1.id);
      expect(notificationManager.notifications.length, equals(1));
      expect(notificationManager.notifications[0].id, equals(n2.id));

      notificationManager.clearAll();
      expect(notificationManager.notifications, isEmpty);
    });
  });
}
