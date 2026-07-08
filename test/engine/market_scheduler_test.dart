import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/market_scheduler.dart';
import 'package:app/constants/markets.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/domain/repositories/market_repository.dart' show MarketStatus;


MarketScheduler _makeScheduler({
  required void Function(Set<MarketType> activeMarkets) onPoll,
  Set<MarketType>? markets,
}) {
  return MarketScheduler(
    eventBus: EventBus.instance,
    logger: Logger.instance,
    onPoll: onPoll,
    watchedMarkets: markets ?? {MarketType.crypto},
  );
}

void main() {
  group('MarketScheduler.evaluate()', () {
    test('crypto market evaluates to open and should poll', () {
      final scheduler = _makeScheduler(
        onPoll: (m) {},
        markets: {MarketType.crypto},
      );
      final schedule = scheduler.evaluate();
      expect(schedule.length, equals(1));
      expect(schedule.first.market, equals(MarketType.crypto));
      expect(schedule.first.status, equals(MarketStatus.open));
      expect(schedule.first.shouldPoll, isTrue);
    });
  });

  group('MarketScheduler start/stop', () {
    test('can start and stop without errors', () {
      final scheduler = _makeScheduler(onPoll: (m) {});
      expect(() => scheduler.start(), returnsNormally);
      expect(() => scheduler.stop(), returnsNormally);
    });
  });
}
