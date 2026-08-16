/// Candle (OHLCV) — the single canonical candle type.
///
/// `high`, `low`, `close` and `volume` are mutable so the forming candle can be
/// updated in place from the live stream without reallocating the list. The
/// timestamp and open are fixed once the candle exists.
library;

class CandleData {
  /// Candle open time, ms since epoch, aligned to the interval boundary.
  final int timestamp;
  final double open;

  double high;
  double low;
  double close;
  double volume;

  /// True only for the currently forming candle.
  bool isLive;

  CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0.0,
    this.isLive = false,
  });

  bool get isBullish => close >= open;
  bool get isBearish => close < open;

  double get body => (close - open).abs();
  double get range => high - low;
  double get upperWick => high - (isBullish ? close : open);
  double get lowerWick => (isBullish ? open : close) - low;

  /// Fold a trade price into this candle.
  void applyTick(double price, {double tickVolume = 0}) {
    close = price;
    if (price > high) high = price;
    if (price < low) low = price;
    volume += tickVolume;
  }

  /// Overwrite OHLCV from an authoritative exchange update.
  void overwriteFrom(CandleData other) {
    high = other.high;
    low = other.low;
    close = other.close;
    volume = other.volume;
    isLive = other.isLive;
  }

  CandleData copyWith({
    int? timestamp,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
    bool? isLive,
  }) {
    return CandleData(
      timestamp: timestamp ?? this.timestamp,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
      isLive: isLive ?? this.isLive,
    );
  }

  Map<String, dynamic> toJson() => {
        't': timestamp,
        'o': open,
        'h': high,
        'l': low,
        'c': close,
        'v': volume,
      };

  factory CandleData.fromJson(Map<String, dynamic> json) => CandleData(
        // Parenthesised deliberately: `as` binds tighter than `??`, so
        // `a ?? b as num` would cast only `b` and leave the result dynamic.
        timestamp: ((json['t'] ?? json['timestamp']) as num).toInt(),
        open: ((json['o'] ?? json['open']) as num).toDouble(),
        high: ((json['h'] ?? json['high']) as num).toDouble(),
        low: ((json['l'] ?? json['low']) as num).toDouble(),
        close: ((json['c'] ?? json['close']) as num).toDouble(),
        volume: ((json['v'] ?? json['volume']) as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return 'Candle($date O=$open H=$high L=$low C=$close)';
  }
}
