/// Tests for the Instrument model and Timeframe enum.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:app/models/instrument.dart';

void main() {
  group('precisionFromTickSize', () {
    test('derives decimals from common Binance tick sizes', () {
      expect(Instrument.precisionFromTickSize(0.01), 2);
      expect(Instrument.precisionFromTickSize(0.001), 3);
      expect(Instrument.precisionFromTickSize(0.0001), 4);
      expect(Instrument.precisionFromTickSize(0.00000001), 8);
      expect(Instrument.precisionFromTickSize(1), 0);
    });

    test('falls back to 2 for a non-positive tick size', () {
      expect(Instrument.precisionFromTickSize(0), 2);
      expect(Instrument.precisionFromTickSize(-1), 2);
    });

    test('clamps to at most 8 decimals', () {
      expect(Instrument.precisionFromTickSize(1e-12), lessThanOrEqualTo(8));
    });
  });

  group('formatPrice', () {
    test('respects the instrument precision', () {
      const btc = Instrument(
        symbol: 'BTCUSDT',
        base: 'BTC',
        quote: 'USDT',
        pricePrecision: 2,
      );
      expect(btc.formatPrice(64000.456), '64000.46');

      const shib = Instrument(
        symbol: 'SHIBUSDT',
        base: 'SHIB',
        quote: 'USDT',
        pricePrecision: 8,
      );
      expect(shib.formatPrice(0.00001234), '0.00001234');
    });

    test('renders a dash for non-finite values', () {
      const i = Instrument(symbol: 'X', base: 'X', quote: 'USDT');
      expect(i.formatPrice(double.nan), '—');
      expect(i.formatPrice(double.infinity), '—');
    });
  });

  group('display', () {
    test('displayName is base/quote', () {
      const i = Instrument(symbol: 'ETHBTC', base: 'ETH', quote: 'BTC');
      expect(i.displayName, 'ETH/BTC');
    });

    test('shortLabel drops a USD-family quote but keeps others', () {
      const usdt = Instrument(symbol: 'BTCUSDT', base: 'BTC', quote: 'USDT');
      expect(usdt.shortLabel, 'BTC');

      const btcPair = Instrument(symbol: 'ETHBTC', base: 'ETH', quote: 'BTC');
      expect(btcPair.shortLabel, 'ETH/BTC');
    });

    test('isUsdQuoted covers the stablecoin quotes', () {
      for (final q in ['USDT', 'USDC', 'BUSD', 'FDUSD']) {
        expect(
          Instrument(symbol: 'X$q', base: 'X', quote: q).isUsdQuoted,
          isTrue,
          reason: q,
        );
      }
      expect(
        const Instrument(symbol: 'XBTC', base: 'X', quote: 'BTC').isUsdQuoted,
        isFalse,
      );
    });
  });

  group('formatCompact', () {
    test('abbreviates by magnitude', () {
      expect(Instrument.formatCompact(1.5e12), '1.50T');
      expect(Instrument.formatCompact(2.25e9), '2.25B');
      expect(Instrument.formatCompact(3.5e6), '3.50M');
      expect(Instrument.formatCompact(4500), '4.50K');
      expect(Instrument.formatCompact(12.5), '12.50');
    });

    test('handles negatives by magnitude', () {
      expect(Instrument.formatCompact(-2.5e9), '-2.50B');
    });
  });

  group('placeholder', () {
    test('splits a known quote off the end', () {
      final btc = Instrument.placeholder('BTCUSDT');
      expect(btc.base, 'BTC');
      expect(btc.quote, 'USDT');

      final ethBtc = Instrument.placeholder('ETHBTC');
      expect(ethBtc.base, 'ETH');
      expect(ethBtc.quote, 'BTC');
    });

    test('uppercases the input', () {
      expect(Instrument.placeholder('btcusdt').symbol, 'BTCUSDT');
    });

    test('degrades gracefully on an unrecognised symbol', () {
      final unknown = Instrument.placeholder('WEIRD');
      expect(unknown.symbol, 'WEIRD');
      expect(unknown.base, 'WEIRD');
      expect(unknown.quote, '');
    });
  });

  group('json', () {
    test('round-trips', () {
      const original = Instrument(
        symbol: 'SOLUSDT',
        base: 'SOL',
        quote: 'USDT',
        tickSize: 0.001,
        pricePrecision: 3,
        quoteVolume24h: 12345.6,
      );

      final restored = Instrument.fromJson(original.toJson());

      expect(restored.symbol, original.symbol);
      expect(restored.base, original.base);
      expect(restored.quote, original.quote);
      expect(restored.tickSize, original.tickSize);
      expect(restored.pricePrecision, original.pricePrecision);
      expect(restored.quoteVolume24h, original.quoteVolume24h);
    });

    test('applies defaults for missing optional fields', () {
      final i = Instrument.fromJson({'s': 'XUSDT', 'b': 'X', 'q': 'USDT'});
      expect(i.tickSize, 0.01);
      expect(i.pricePrecision, 2);
      expect(i.quoteVolume24h, 0.0);
    });
  });

  group('equality', () {
    test('is by symbol, so registry updates do not break lookups', () {
      const a = Instrument(symbol: 'BTCUSDT', base: 'BTC', quote: 'USDT');
      final b = a.copyWith(quoteVolume24h: 999);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect({a, b}.length, 1);
    });
  });

  group('Timeframe', () {
    test('durations match the interval strings', () {
      expect(Timeframe.m1.durationMs, 60 * 1000);
      expect(Timeframe.h1.durationMs, 60 * 60 * 1000);
      expect(Timeframe.d1.durationMs, 24 * 60 * 60 * 1000);
      expect(Timeframe.w1.durationMs, 7 * 24 * 60 * 60 * 1000);
    });

    test('fromApiValue round-trips and defaults to 1h', () {
      for (final tf in Timeframe.values) {
        expect(Timeframe.fromApiValue(tf.apiValue), tf);
      }
      expect(Timeframe.fromApiValue('nonsense'), Timeframe.h1);
    });
  });
}
