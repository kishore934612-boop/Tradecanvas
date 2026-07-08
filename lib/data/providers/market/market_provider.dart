/// Market data provider interface
/// 
/// All market data sources must implement this interface.
/// This allows swapping providers without changing business logic.
library;

import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';

abstract class MarketProvider {
  /// Provider name (e.g., 'Binance', 'Yahoo Finance')
  String get name;
  
  /// Fetch current prices for symbols
  /// Returns `Map<symbol, PriceData>`
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols);
  
  /// Fetch historical OHLC candles
  Future<List<CandleData>> fetchOHLC(
    String symbol,
    String interval, {
    int? limit,
    int? endTime,
  });
  
  /// Subscribe to real-time price updates (WebSocket)
  /// Returns null if WebSocket not supported
  Stream<PriceUpdate>? subscribeToPriceUpdates(List<String> symbols);
  
  /// Check if provider supports this asset
  bool supportsAsset(String symbol);
  
  /// Get list of supported symbols
  List<String> getSupportedSymbols();
  
  /// Connect to real-time data source
  Future<void> connect();
  
  /// Disconnect from real-time data source
  Future<void> disconnect();
  
  /// Check if connected
  bool get isConnected;
  
  /// Dispose resources
  void dispose();
}
