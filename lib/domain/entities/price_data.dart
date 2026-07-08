/// Price data entity
library;

class PriceData {
  final String symbol;
  final double price;
  final double change; // 24h change percentage
  final int timestamp;
  final String source; // 'binance-ws', 'binance-rest', 'yahoo'
  
  const PriceData({
    required this.symbol,
    required this.price,
    required this.change,
    required this.timestamp,
    required this.source,
  });
  
  bool get isStale {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > 2000; // > 2 seconds is stale (ensures real-time REST polling)
  }
  
  int get ageInSeconds {
    return (DateTime.now().millisecondsSinceEpoch - timestamp) ~/ 1000;
  }
  
  PriceData copyWith({
    String? symbol,
    double? price,
    double? change,
    int? timestamp,
    String? source,
  }) {
    return PriceData(
      symbol: symbol ?? this.symbol,
      price: price ?? this.price,
      change: change ?? this.change,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
    );
  }
  
  @override
  String toString() {
    return 'PriceData($symbol: \$$price, ${change.toStringAsFixed(2)}%, age: ${ageInSeconds}s)';
  }
}

class PriceUpdate {
  final String symbol;
  final double price;
  final double change;
  final String source;
  
  const PriceUpdate({
    required this.symbol,
    required this.price,
    required this.change,
    required this.source,
  });
  
  PriceData toPriceData() {
    return PriceData(
      symbol: symbol,
      price: price,
      change: change,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      source: source,
    );
  }
}
