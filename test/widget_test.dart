// TradeVerse — app smoke tests
// Tests that the app's pure service/engine layer is correctly wired.
// Full widget tests require a running device; this file covers unit-level
// sanity checks on core types.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/persistence/in_memory_persistence.dart';
import 'package:app/services/persistence/persistence_service.dart';
import 'package:app/engine/trading_engine.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';

void main() {
  group('App smoke tests', () {
    test('InMemoryPersistence satisfies PersistenceService', () {
      expect(InMemoryPersistence(), isA<PersistenceService>());
    });

    test('TradingEngine.equity calculation works', () {
      expect(
        TradingEngine.equity(
          balance: 100000,
          usedMargin: 5000,
          unrealizedPnl: 1000,
        ),
        equals(106000),
      );
    });

    test('Assets list is not empty', () {
      expect(assets, isNotEmpty);
    });

    test('getAssetBySymbol returns BTC', () {
      final asset = getAssetBySymbol('BTC');
      expect(asset, isNotNull);
      expect(asset!.symbol, equals('BTC'));
      expect(asset.type, equals(MarketType.crypto));
    });

    test('TradingEngine.validateTrade passes for valid long BTC', () {
      final config = MarketConfig.get(MarketType.crypto, TradingType.spot);
      final error = TradingEngine.validateTrade(
        symbol: 'BTC',
        side: PositionSide.long,
        qty: 0.01,
        leverage: 1.0,
        freeMargin: 10000.0,
        entryPrice: 50000.0,
        config: config,
      );
      expect(error, isNull);
    });
  });
}
