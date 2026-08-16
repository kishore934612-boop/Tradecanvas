/// Instrument — a tradable symbol on the exchange.
///
/// Replaces the old `Asset` model, which carried paper-trading concerns
/// (leverage, lot size, order limits, margin). A charting tool only needs
/// identity and display precision.
///
/// The Binance symbol (e.g. `BTCUSDT`) is the canonical id. There is no
/// app-symbol indirection layer.
library;

import 'dart:math' as math;

class Instrument {
  /// Canonical exchange symbol, e.g. `BTCUSDT`.
  final String symbol;

  /// Base asset, e.g. `BTC`.
  final String base;

  /// Quote asset, e.g. `USDT`.
  final String quote;

  /// Smallest price increment from exchangeInfo (PRICE_FILTER.tickSize).
  final double tickSize;

  /// Decimal places to render, derived from [tickSize].
  final int pricePrecision;

  /// Quote-asset volume over the trailing 24h, used to rank search results.
  /// Zero until a ticker snapshot has been merged in.
  final double quoteVolume24h;

  const Instrument({
    required this.symbol,
    required this.base,
    required this.quote,
    this.tickSize = 0.01,
    this.pricePrecision = 2,
    this.quoteVolume24h = 0.0,
  });

  /// `BTC/USDT`
  String get displayName => '$base/$quote';

  /// Short label for dense UI, e.g. `BTC` for USDT pairs, else `BTC/BNB`.
  String get shortLabel => isUsdQuoted ? base : displayName;

  bool get isUsdQuoted =>
      quote == 'USDT' || quote == 'USDC' || quote == 'BUSD' || quote == 'FDUSD';

  /// Derive decimal precision from a tick size (0.001 -> 3).
  static int precisionFromTickSize(double tick) {
    if (tick <= 0) return 2;
    final p = -(math.log(tick) / math.ln10);
    final rounded = p.round();
    // Guard against float noise: 0.001 -> 2.9999 -> 3
    if ((p - rounded).abs() < 0.0001) return rounded.clamp(0, 8);
    return p.ceil().clamp(0, 8);
  }

  /// Format [price] using this instrument's precision.
  String formatPrice(double price) {
    if (price.isNaN || price.isInfinite) return '—';
    return price.toStringAsFixed(pricePrecision);
  }

  /// Compact volume label, e.g. `1.24B`.
  String get volumeLabel => formatCompact(quoteVolume24h);

  static String formatCompact(double v) {
    final a = v.abs();
    if (a >= 1e12) return '${(v / 1e12).toStringAsFixed(2)}T';
    if (a >= 1e9) return '${(v / 1e9).toStringAsFixed(2)}B';
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(2)}M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(2)}K';
    return v.toStringAsFixed(2);
  }

  Instrument copyWith({double? quoteVolume24h}) => Instrument(
        symbol: symbol,
        base: base,
        quote: quote,
        tickSize: tickSize,
        pricePrecision: pricePrecision,
        quoteVolume24h: quoteVolume24h ?? this.quoteVolume24h,
      );

  Map<String, dynamic> toJson() => {
        's': symbol,
        'b': base,
        'q': quote,
        't': tickSize,
        'p': pricePrecision,
        'v': quoteVolume24h,
      };

  factory Instrument.fromJson(Map<String, dynamic> j) => Instrument(
        symbol: j['s'] as String,
        base: j['b'] as String,
        quote: j['q'] as String,
        tickSize: (j['t'] as num?)?.toDouble() ?? 0.01,
        pricePrecision: (j['p'] as num?)?.toInt() ?? 2,
        quoteVolume24h: (j['v'] as num?)?.toDouble() ?? 0.0,
      );

  /// Minimal fallback when a symbol is referenced before the registry loads.
  factory Instrument.placeholder(String symbol) {
    final upper = symbol.toUpperCase();
    for (final q in const [
      'USDT',
      'FDUSD',
      'USDC',
      'BUSD',
      'BTC',
      'ETH',
      'BNB',
    ]) {
      if (upper.endsWith(q) && upper.length > q.length) {
        return Instrument(
          symbol: upper,
          base: upper.substring(0, upper.length - q.length),
          quote: q,
        );
      }
    }
    return Instrument(symbol: upper, base: upper, quote: '');
  }

  @override
  bool operator ==(Object other) =>
      other is Instrument && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => 'Instrument($symbol)';
}

/// Chart timeframes, mapped to Binance kline intervals.
enum Timeframe {
  m1('1m', '1m', 60 * 1000),
  m5('5m', '5m', 5 * 60 * 1000),
  m15('15m', '15m', 15 * 60 * 1000),
  m30('30m', '30m', 30 * 60 * 1000),
  h1('1h', '1H', 60 * 60 * 1000),
  h4('4h', '4H', 4 * 60 * 60 * 1000),
  d1('1d', '1D', 24 * 60 * 60 * 1000),
  w1('1w', '1W', 7 * 24 * 60 * 60 * 1000);

  const Timeframe(this.apiValue, this.label, this.durationMs);

  /// Binance interval string.
  final String apiValue;

  /// Short UI label.
  final String label;

  /// Candle duration in milliseconds.
  final int durationMs;

  /// Candle duration.
  Duration get duration => Duration(milliseconds: durationMs);

  static Timeframe fromApiValue(String v) => Timeframe.values.firstWhere(
        (t) => t.apiValue == v,
        orElse: () => Timeframe.h1,
      );
}
