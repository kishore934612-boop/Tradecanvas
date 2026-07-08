import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/asset_metadata.dart';
import 'package:app/constants/markets.dart';
import 'package:app/utils/market_session.dart';
import 'package:app/domain/repositories/market_repository.dart' show MarketStatus;

void main() {
  group('assetMetadataRegistry coverage', () {
    test('all app assets are registered', () {
      for (final asset in assets) {
        expect(
          assetMetadataRegistry.containsKey(asset.symbol),
          isTrue,
          reason: '${asset.symbol} is missing from assetMetadataRegistry',
        );
      }
    });

    test('getAssetMetadata returns null for unknown symbol', () {
      expect(getAssetMetadata('UNKNOWN'), isNull);
    });

    test('getAssetMetadataOrDefault never returns null', () {
      expect(getAssetMetadataOrDefault('UNKNOWN'), isNotNull);
      expect(getAssetMetadataOrDefault('BTC'), isNotNull);
    });
  });

  group('AssetMetadata crypto (BTC)', () {
    late AssetMetadata btc;
    setUp(() => btc = getAssetMetadata('BTC')!);

    test('exchange is Binance', () => expect(btc.exchange, equals('Binance')));
    test('marketCurrency is USD', () => expect(btc.marketCurrency, equals('USD')));
    test('accountCurrency is USD', () => expect(btc.accountCurrency, equals('USD')));
    test('decimalPrecision is 2', () => expect(btc.decimalPrecision, equals(2)));
    test('lotSize is 1', () => expect(btc.lotSize, equals(1.0)));
    test('isLotBased is false', () => expect(btc.isLotBased, isFalse));
    test('maxLeverage is 20', () => expect(btc.maxLeverage, equals(20.0)));
    test('session is 24/7', () => expect(btc.session.is24h, isTrue));
    test('currencySymbol is \$', () => expect(btc.currencySymbol, equals('\$')));
    test('marketIcon is currency_bitcoin', () {
      expect(btc.marketIcon, equals(Icons.currency_bitcoin));
    });
    test('pipSize is tickSize for non-forex', () {
      expect(btc.pipSize, equals(btc.tickSize));
    });
    test('formatPrice produces 2 decimals', () {
      expect(btc.formatPrice(45678.12), equals('45678.12'));
    });
  });

  group('TradingSession', () {
    test('crypto session isTradingDay for all days', () {
      for (int d = 1; d <= 7; d++) {
        expect(TradingSession.crypto.isTradingDay(d), isTrue);
      }
    });

    test('crypto openMinutes is 0', () {
      expect(TradingSession.crypto.openMinutes, equals(0));
    });
  });

  group('getMarketStatus', () {
    test('BTC (crypto) always returns open', () {
      final btc = getAssetBySymbol('BTC')!;
      expect(getMarketStatus(btc), equals(MarketStatus.open));
    });

    test('isMarketLive crypto is true', () {
      expect(isMarketLive(getAssetBySymbol('BTC')!), isTrue);
    });
  });
}
