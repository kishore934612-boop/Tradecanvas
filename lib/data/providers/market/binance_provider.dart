/// Binance market data provider
/// 
/// Provides crypto prices from Binance API (REST + WebSocket)
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/core/logging/logger.dart';

class BinanceProvider implements MarketProvider {
  static final BinanceProvider _instance = BinanceProvider._internal();
  factory BinanceProvider() => _instance;
  BinanceProvider._internal();

  final Logger _logger = Logger.instance;
  WebSocketChannel? _wsChannel;
  bool _isConnecting = false;
  bool _isConnected = false;
  
  final StreamController<PriceUpdate> _priceUpdateController = 
      StreamController<PriceUpdate>.broadcast();

  /// Symbol mapping: Binance symbol -> App symbol
  static const Map<String, String> _symbolMap = {
    'BTCUSDT': 'BTC',
    'ETHUSDT': 'ETH',
    'SOLUSDT': 'SOL',
    'BNBUSDT': 'BNB',
    'XRPUSDT': 'XRP',
    'DOGEUSDT': 'DOGE',
    'ADAUSDT': 'ADA',
    'AVAXUSDT': 'AVAX',
  };

  /// Reverse mapping: App symbol -> Binance symbol
  static final Map<String, String> _reverseMap = {
    for (final entry in _symbolMap.entries) entry.value: entry.key
  };

  @override
  String get name => 'Binance';

  @override
  bool get isConnected => _isConnected;

  @override
  bool supportsAsset(String symbol) {
    return _reverseMap.containsKey(symbol);
  }

  @override
  List<String> getSupportedSymbols() {
    return _reverseMap.keys.toList();
  }

  @override
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols) async {
    final Map<String, PriceData> results = {};
    
    // Filter to only supported symbols
    final supportedSymbols = symbols.where((s) => supportsAsset(s)).toList();
    if (supportedSymbols.isEmpty) return results;

    // On web, use CORS proxy for Binance API
    final baseUrl = kIsWeb 
        ? 'https://corsproxy.io/?https://api.binance.com'
        : 'https://api.binance.com';
    
    try {
      _logger.network('Fetching Binance prices for ${supportedSymbols.length} symbols');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/v3/ticker/24hr'),
        headers: kIsWeb ? {} : {},
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        
        int successCount = 0;
        for (final item in data) {
          final binanceSymbol = item['symbol'] as String;
          if (_symbolMap.containsKey(binanceSymbol)) {
            final appSymbol = _symbolMap[binanceSymbol]!;
            
            // Only process if requested
            if (!supportedSymbols.contains(appSymbol)) continue;
            
            final price = double.tryParse(item['lastPrice'] as String) ?? 0.0;
            final change = double.tryParse(item['priceChangePercent'] as String) ?? 0.0;
            
            if (price > 0) {
              results[appSymbol] = PriceData(
                symbol: appSymbol,
                price: price,
                change: change,
                timestamp: nowMs,
                source: 'binance-rest',
              );
              successCount++;
            }
          }
        }
        
        _logger.info('Binance fetched $successCount prices${kIsWeb ? " (via CORS proxy)" : ""}');
      } else {
        _logger.warning('Binance REST API error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.error('Binance fetch error${kIsWeb ? " (web/CORS)" : ""}: $e');
    }
    
    return results;
  }

  @override
  Future<List<CandleData>> fetchOHLC(
    String symbol,
    String interval, {
    int? limit,
    int? endTime,
  }) async {
    if (!supportsAsset(symbol)) {
      _logger.warning('Binance does not support symbol: $symbol');
      return [];
    }

    final binanceSymbol = _reverseMap[symbol]!;
    
    try {
      // Binance interval mapping
      final binanceInterval = _mapInterval(interval);
      
      final queryParams = {
        'symbol': binanceSymbol,
        'interval': binanceInterval,
        if (limit != null) 'limit': limit.toString(),
        if (endTime != null) 'endTime': endTime.toString(),
      };
      
      final uri = Uri.https(
        'api.binance.com',
        '/api/v3/klines',
        queryParams,
      );
      
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((k) {
          return CandleData(
            timestamp: k[0] as int,
            open: double.parse(k[1].toString()),
            high: double.parse(k[2].toString()),
            low: double.parse(k[3].toString()),
            close: double.parse(k[4].toString()),
            volume: double.parse(k[5].toString()),
          );
        }).toList();
      } else {
        _logger.warning('Binance OHLC error: HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _logger.error('Binance OHLC fetch error: $e');
      return [];
    }
  }

  /// Map app interval to Binance interval format
  String _mapInterval(String interval) {
    // Map common interval formats to Binance format
    switch (interval.toLowerCase()) {
      case '1m':
      case '1min':
        return '1m';
      case '5m':
      case '5min':
        return '5m';
      case '15m':
      case '15min':
        return '15m';
      case '1h':
      case '1hour':
        return '1h';
      case '4h':
      case '4hour':
        return '4h';
      case '1d':
      case '1day':
      case 'day':
        return '1d';
      case '1w':
      case '1week':
      case 'week':
        return '1w';
      default:
        return interval; // Pass through if unknown
    }
  }

  @override
  Stream<PriceUpdate>? subscribeToPriceUpdates(List<String> symbols) {
    // WebSocket not supported on web platform due to CORS restrictions
    if (kIsWeb) {
      _logger.warning('Binance WebSocket disabled on web platform (CORS restriction)');
      return null;
    }
    
    // Filter to supported symbols
    final supportedSymbols = symbols.where((s) => supportsAsset(s)).toList();
    if (supportedSymbols.isEmpty) return null;
    
    // Connect if not already connected
    if (!_isConnected && !_isConnecting) {
      connect();
    }
    
    return _priceUpdateController.stream;
  }

  @override
  Future<void> connect() async {
    // WebSocket not supported on web
    if (kIsWeb) {
      _logger.warning('WebSocket not available on web platform');
      return;
    }
    
    if (_wsChannel != null || _isConnecting) return;
    
    _isConnecting = true;
    
    try {
      // Build stream list for all supported symbols
      final cryptoStreams = _symbolMap.keys
          .map((s) => '${s.toLowerCase()}@ticker')
          .join('/');

      final uri = Uri.parse('wss://stream.binance.com:9443/stream?streams=$cryptoStreams');

      _logger.info('Connecting Binance WebSocket...');
      _wsChannel = WebSocketChannel.connect(uri);
      _isConnecting = false;
      _isConnected = true;

      _wsChannel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketClose,
        cancelOnError: false,
      );
      
      _logger.info('Binance WebSocket connected');
    } catch (e) {
      _logger.error('Binance WebSocket connection failed: $e');
      _isConnecting = false;
      _isConnected = false;
      _wsChannel = null;
    }
  }

  void _handleWebSocketMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String? stream = data['stream']?.toString();
      final ticker = data['data'] as Map<String, dynamic>?;
      
      if (stream == null || ticker == null) return;

      final rawSymbol = stream.split('@')[0].toUpperCase();
      
      // Check if we have a mapping for this symbol
      if (!_symbolMap.containsKey(rawSymbol)) return;
      
      final appSymbol = _symbolMap[rawSymbol]!;
      final price = double.tryParse(ticker['c']?.toString() ?? '') ?? 0.0;
      final change = double.tryParse(ticker['P']?.toString() ?? '') ?? 0.0;

      if (price > 0) {
        final update = PriceUpdate(
          symbol: appSymbol,
          price: price,
          change: change,
          source: 'binance-ws',
        );
        
        _priceUpdateController.add(update);
        _logger.market('$appSymbol: \$${price.toStringAsFixed(2)} (${change.toStringAsFixed(2)}%)');
      }
    } catch (e) {
      _logger.error('Binance WebSocket message parse error: $e');
    }
  }

  void _handleWebSocketError(Object error) {
    _logger.error('Binance WebSocket error: $error');
    _isConnected = false;
    _wsChannel = null;
    
    // Attempt reconnection after delay
    Future.delayed(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _logger.info('Attempting Binance WebSocket reconnection...');
        connect();
      }
    });
  }

  void _handleWebSocketClose() {
    _logger.warning('Binance WebSocket closed');
    _isConnected = false;
    _wsChannel = null;
  }

  @override
  Future<void> disconnect() async {
    await _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _isConnecting = false;
    _logger.info('Binance WebSocket disconnected');
  }

  @override
  void dispose() {
    disconnect();
    _priceUpdateController.close();
  }
}
