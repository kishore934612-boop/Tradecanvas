import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';

class TestEvent extends AppEvent {
  final String message;
  TestEvent(this.message);
}

class AnotherTestEvent extends AppEvent {
  final int value;
  AnotherTestEvent(this.value);
}

void main() {
  late EventBus bus;

  setUp(() {
    bus = EventBus.instance;
  });

  group('EventBus', () {
    test('publish/subscribe lifecycle', () async {
      final completer = Completer<String>();
      
      final subscription = bus.subscribe<TestEvent>((event) {
        completer.complete(event.message);
      });
      
      bus.publish(TestEvent('Hello EventBus'));
      
      final result = await completer.future.timeout(const Duration(seconds: 1));
      expect(result, equals('Hello EventBus'));
      
      await subscription.cancel();
    });

    test('multiple subscribers receive the same event', () async {
      final completer1 = Completer<String>();
      final completer2 = Completer<String>();
      
      final sub1 = bus.subscribe<TestEvent>((event) => completer1.complete(event.message));
      final sub2 = bus.subscribe<TestEvent>((event) => completer2.complete(event.message));
      
      bus.publish(TestEvent('Broadcast'));
      
      final res1 = await completer1.future.timeout(const Duration(seconds: 1));
      final res2 = await completer2.future.timeout(const Duration(seconds: 1));
      
      expect(res1, equals('Broadcast'));
      expect(res2, equals('Broadcast'));
      
      await sub1.cancel();
      await sub2.cancel();
    });

    test('events are typed correctly (separate streams)', () async {
      final completer = Completer<int>();
      bool receivedWrongEvent = false;
      
      final sub1 = bus.subscribe<TestEvent>((event) {
        receivedWrongEvent = true;
      });
      
      final sub2 = bus.subscribe<AnotherTestEvent>((event) {
        completer.complete(event.value);
      });
      
      bus.publish(AnotherTestEvent(42));
      
      final res = await completer.future.timeout(const Duration(seconds: 1));
      expect(res, equals(42));
      expect(receivedWrongEvent, isFalse);
      
      await sub1.cancel();
      await sub2.cancel();
    });

    test('subscription cancellation works', () async {
      int receiveCount = 0;
      
      final subscription = bus.subscribe<TestEvent>((event) {
        receiveCount++;
      });
      
      bus.publish(TestEvent('First'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(receiveCount, equals(1));
      
      await subscription.cancel();
      
      bus.publish(TestEvent('Second'));
      await Future.delayed(const Duration(milliseconds: 10));
      expect(receiveCount, equals(1)); // Should not increase
    });

    test('TradeCompletedEvent carries correct data', () async {
      final completer = Completer<TradeCompletedEvent>();
      
      final sub = bus.subscribe<TradeCompletedEvent>((event) {
        completer.complete(event);
      });
      
      bus.publish(TradeCompletedEvent(
        tradeId: 't-123',
        symbol: 'BTC',
        pnl: 150.0,
        isWin: true,
        durationMs: 5000,
        closeReason: 'takeProfit',
        riskReward: 2.5,
        riskPct: 1.0,
      ));
      
      final event = await completer.future.timeout(const Duration(seconds: 1));
      expect(event.tradeId, equals('t-123'));
      expect(event.symbol, equals('BTC'));
      expect(event.pnl, equals(150.0));
      expect(event.isWin, isTrue);
      expect(event.durationMs, equals(5000));
      expect(event.closeReason, equals('takeProfit'));
      expect(event.riskReward, equals(2.5));
      expect(event.riskPct, equals(1.0));
      
      await sub.cancel();
    });
  });
}
