/// Candle data entity (OHLCV)
library;

class CandleData {
  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final bool isLive;
  
  CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0.0,
    this.isLive = false,
  });
  
  /// Update candle with new tick (for live candles)
  void applyTick(double newPrice) {
    if (!isLive) return;
    
    // Update high/low
    if (newPrice > high) {
      // Note: Can't modify final fields, would need mutable version
      // This is handled in the chart implementation
    }
  }
  
  bool get isBullish => close >= open;
  bool get isBearish => close < open;
  
  double get body => (close - open).abs();
  double get range => high - low;
  double get upperWick => high - (isBullish ? close : open);
  double get lowerWick => (isBullish ? open : close) - low;
  
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
  
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
      'isLive': isLive,
    };
  }
  
  factory CandleData.fromJson(Map<String, dynamic> json) {
    return CandleData(
      timestamp: json['timestamp'] as int,
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      isLive: json['isLive'] as bool? ?? false,
    );
  }
  
  @override
  String toString() {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return 'Candle($date: O=$open H=$high L=$low C=$close)';
  }
}
