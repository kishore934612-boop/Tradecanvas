import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/trading_engine.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';

final btc = getAssetBySymbol('BTC')!;
final eth = getAssetBySymbol('ETH')!;

final cryptoSpot     = MarketConfig.get(MarketType.crypto, TradingType.spot);
final cryptoFutures  = MarketConfig.get(MarketType.crypto, TradingType.futures);

void main() {
  group('applySpread', () {
    test('long entry applies spread', () {
      final price = TradingEngine.applySpread(
        100.0,
        PositionSide.long,
        btc,
        cryptoSpot,
      );
      expect(price, equals(100.0));
    });
  });

  group('toActualQty', () {
    test('spot conversion does not change qty', () {
      final qty = TradingEngine.toActualQty(1.234567, cryptoSpot);
      expect(qty, equals(1.234567));
    });
  });

  group('calculateMargin', () {
    test('spot margin is 100% of notional', () {
      final res = TradingEngine.calculateMargin(
        qty: 2.0,
        fillPrice: 50000.0,
        leverage: 1.0,
        side: PositionSide.long,
        asset: btc,
        config: cryptoSpot,
      );
      expect(res.margin, equals(100000.0));
    });

    test('futures margin accounts for leverage', () {
      final res = TradingEngine.calculateMargin(
        qty: 2.0,
        fillPrice: 50000.0,
        leverage: 10.0,
        side: PositionSide.long,
        asset: btc,
        config: cryptoFutures,
      );
      expect(res.margin, equals(10000.0));
    });
  });

  group('liquidationPrice', () {
    test('long futures liquidation price', () {
      final liq = TradingEngine.liquidationPrice(
        entryPrice: 50000.0,
        leverage: 10.0,
        side: PositionSide.long,
        config: cryptoFutures,
      );
      expect(liq, closeTo(45226.13, 0.01));
    });

    test('short futures liquidation price', () {
      final liq = TradingEngine.liquidationPrice(
        entryPrice: 50000.0,
        leverage: 10.0,
        side: PositionSide.short,
        config: cryptoFutures,
      );
      expect(liq, closeTo(54726.37, 0.01));
    });
  });

  group('grossPnl', () {
    test('long position profit', () {
      final pnl = TradingEngine.grossPnl(
        entryPrice: 50000.0,
        currentPrice: 55000.0,
        actualQty: 1.0,
        side: PositionSide.long,
      );
      expect(pnl, equals(5000.0));
    });
  });

  group('riskReward', () {
    test('long risk reward ratio', () {
      final rr = TradingEngine.riskReward(
        entryPrice: 50000.0,
        side: PositionSide.long,
        stopLoss: 45000.0,
        takeProfit: 60000.0,
      )!;
      expect(rr.riskAmount, equals(5000.0));
      expect(rr.rewardAmount, equals(10000.0));
      expect(rr.ratio, equals(2.0));
    });
  });

  group('suggestPositionSize', () {
    test('calculates correct size for futures', () {
      final res = TradingEngine.suggestPositionSize(
        equity: 10000.0,
        riskPercent: 1.0,
        entryPrice: 50000.0,
        stopLoss: 49000.0,
        leverage: 10.0,
        asset: btc,
        config: cryptoFutures,
      )!;
      expect(res.maxRiskAmount, equals(100.0));
      expect(res.suggestedQty, equals(0.1));
    });
  });

  group('equity / freeMargin / marginLevel / totalReturnPct', () {
    test('equity = balance + usedMargin + unrealizedPnl', () {
      expect(
        TradingEngine.equity(
          balance: 90000.0,
          usedMargin: 10000.0,
          unrealizedPnl: 2000.0,
        ),
        equals(102000.0),
      );
    });
  });
}
