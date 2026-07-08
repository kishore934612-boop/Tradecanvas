/// Cache manager for market data
/// 
/// Provides in-memory caching with TTL (time-to-live).
library;

import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/core/logging/logger.dart';

class CacheEntry<T> {
  final T data;
  final int timestamp;
  final int ttl; // milliseconds
  
  CacheEntry(this.data, this.ttl) 
      : timestamp = DateTime.now().millisecondsSinceEpoch;
  
  bool get isExpired {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > ttl;
  }
  
  int get ageInSeconds => 
      (DateTime.now().millisecondsSinceEpoch - timestamp) ~/ 1000;
}

class CacheManager {
  final Map<String, CacheEntry<PriceData>> _priceCache = {};
  final Map<String, CacheEntry<List<CandleData>>> _candleCache = {};
  
  // Default TTL values
  static const int priceTTL = 5000; // 5 seconds
  static const int candleTTL = 30000; // 30 seconds
  
  /// Get cached price
  PriceData? getPrice(String symbol) {
    final entry = _priceCache[symbol];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _priceCache.remove(symbol);
      logger.debug('Cache expired for $symbol (age: ${entry.ageInSeconds}s)');
      return null;
    }
    
    return entry.data;
  }
  
  /// Set price in cache
  void setPrice(String symbol, PriceData data, {int? ttl}) {
    _priceCache[symbol] = CacheEntry(data, ttl ?? priceTTL);
  }
  
  /// Get cached candles
  List<CandleData>? getCandles(String symbol, String timeframe) {
    final key = '${symbol}_$timeframe';
    final entry = _candleCache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _candleCache.remove(key);
      logger.debug('Candle cache expired for $key (age: ${entry.ageInSeconds}s)');
      return null;
    }
    
    return entry.data;
  }
  
  /// Set candles in cache
  void setCandles(
    String symbol,
    String timeframe,
    List<CandleData> data, {
    int? ttl,
  }) {
    final key = '${symbol}_$timeframe';
    _candleCache[key] = CacheEntry(data, ttl ?? candleTTL);
  }
  
  /// Clear price cache for symbol
  void clearPrice(String symbol) {
    _priceCache.remove(symbol);
  }
  
  /// Clear candle cache for symbol
  void clearCandles(String symbol) {
    _candleCache.removeWhere((key, _) => key.startsWith(symbol));
  }
  
  /// Clear all cache
  void clearAll() {
    _priceCache.clear();
    _candleCache.clear();
    logger.info('All cache cleared');
  }
  
  /// Get cache statistics
  Map<String, int> getStats() {
    return {
      'prices': _priceCache.length,
      'candles': _candleCache.length,
      'total': _priceCache.length + _candleCache.length,
    };
  }
  
  /// Remove expired entries
  void cleanup() {
    _priceCache.removeWhere((_, entry) => entry.isExpired);
    _candleCache.removeWhere((_, entry) => entry.isExpired);
    
    final stats = getStats();
    logger.debug('Cache cleanup: ${stats["total"]} entries remaining');
  }
}
