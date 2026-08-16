/// A live candle update pushed from the exchange kline stream.
///
/// Unlike a synthesized candle (built by folding ticks into a bucket), this
/// carries the exchange's own OHLCV for the interval, so the forming candle
/// is always authoritative.
library;

import 'package:app/domain/entities/candle_data.dart';

class KlineUpdate {
  final String symbol;

  /// Binance interval string, e.g. `1h`.
  final String interval;

  /// Candle open time in ms since epoch.
  final int openTime;

  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  /// True when the exchange has closed this candle. A closed candle should be
  /// appended to history; an open one replaces the current forming candle.
  final bool isClosed;

  const KlineUpdate({
    required this.symbol,
    required this.interval,
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.isClosed,
  });

  CandleData toCandle() => CandleData(
        timestamp: openTime,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        isLive: !isClosed,
      );

  @override
  String toString() =>
      'KlineUpdate($symbol $interval @$openTime C=$close closed=$isClosed)';
}
