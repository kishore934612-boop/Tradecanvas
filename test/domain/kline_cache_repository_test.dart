import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/domain/repositories/kline_cache_repository.dart';
import '../helpers/in_memory_persistence.dart';

void main() {
  late InMemoryPersistence persistence;
  late PersistenceKlineCacheRepository repository;

  setUp(() {
    persistence = InMemoryPersistence();
    repository = PersistenceKlineCacheRepository(
      persistence: persistence,
      logger: Logger.instance,
    );
  });

  group('KlineCacheRepository Offline Caching', () {
    test('getCandles returns empty list when key absent', () async {
      final candles = await repository.getCandles('BTCUSDT', '1h');
      expect(candles, isEmpty);
    });

    test('saveCandles and getCandles round-trip candle series', () async {
      final testCandles = [
        CandleData(
          timestamp: 1600000000000,
          open: 50000.0,
          high: 51000.0,
          low: 49500.0,
          close: 50800.0,
          volume: 120.5,
        ),
        CandleData(
          timestamp: 1600003600000,
          open: 50800.0,
          high: 52000.0,
          low: 50500.0,
          close: 51500.0,
          volume: 200.0,
        ),
      ];

      await repository.saveCandles('BTCUSDT', '1h', testCandles);

      final retrieved = await repository.getCandles('BTCUSDT', '1h');
      expect(retrieved.length, equals(2));
      expect(retrieved[0].open, equals(50000.0));
      expect(retrieved[0].close, equals(50800.0));
      expect(retrieved[1].high, equals(52000.0));
    });

    test('clearCache removes stored candles for symbol', () async {
      final testCandles = [
        CandleData(
          timestamp: 1600000000000,
          open: 100.0,
          high: 105.0,
          low: 99.0,
          close: 104.0,
          volume: 10.0,
        ),
      ];

      await repository.saveCandles('ETHUSDT', '15m', testCandles);
      expect((await repository.getCandles('ETHUSDT', '15m')).length, equals(1));

      await repository.clearCache(symbol: 'ETHUSDT');
      expect(await repository.getCandles('ETHUSDT', '15m'), isEmpty);
    });
  });
}
