/// Market data repository interface
/// 
/// Abstracts access to market data from external providers.
/// UI and controllers should use this instead of calling APIs directly.
library;

import 'package:app/domain/entities/result.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';

enum MarketStatus { open, closed, preMarket, afterHours }

extension MarketStatusX on MarketStatus {
  String get label {
    switch (this) {
      case MarketStatus.open:
        return 'OPEN';
      case MarketStatus.closed:
        return 'CLOSED';
      case MarketStatus.preMarket:
        return 'PRE-MARKET';
      case MarketStatus.afterHours:
        return 'AFTER HOURS';
    }
  }
  
  bool get isLive => this == MarketStatus.open;
}

abstract class MarketRepository {
  /// Get current price for a symbol
  Future<Result<PriceData>> getCurrentPrice(String symbol);
  
  /// Get current prices for multiple symbols
  Future<Result<Map<String, PriceData>>> getPrices(List<String> symbols);
  
  /// Get historical candles
  Future<Result<List<CandleData>>> getHistoricalCandles(
    String symbol,
    String timeframe, {
    int? limit,
    int? endTime,
  });
  
  /// Subscribe to real-time price updates
  Stream<PriceUpdate> subscribeToPriceUpdates(String symbol);
  
  /// Subscribe to multiple symbols
  Stream<PriceUpdate> subscribeToMultiplePrices(List<String> symbols);
  
  /// Get market status for a symbol
  MarketStatus getMarketStatus(String symbol);
  
  /// Check if market is currently trading
  bool isMarketLive(String symbol);
  
  /// Get cached price (synchronous, may be stale)
  PriceData? getCachedPrice(String symbol);
  
  /// Clear cache for symbol
  void clearCache(String symbol);
  
  /// Clear all cached data
  void clearAllCache();
  
  /// Dispose resources
  void dispose();
}
