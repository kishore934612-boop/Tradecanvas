# Phase 2: Repository Layer Implementation

## Objective
Create abstraction layer between business logic and external data sources.

## Files Created So Far ✅

### Core Infrastructure
- [x] `lib/core/di/service_locator.dart`
- [x] `lib/core/events/event_bus.dart`
- [x] `lib/core/events/trade_events.dart`
- [x] `lib/core/events/market_events.dart`
- [x] `lib/core/events/portfolio_events.dart`
- [x] `lib/core/logging/logger.dart`

### Domain Layer
- [x] `lib/domain/entities/result.dart`
- [x] `lib/domain/entities/price_data.dart`
- [x] `lib/domain/entities/candle_data.dart`
- [x] `lib/domain/repositories/market_repository.dart`
- [x] `lib/domain/repositories/portfolio_repository.dart`
- [x] `lib/domain/services/trading_engine.dart`

### Data Layer
- [x] `lib/data/providers/market/market_provider.dart`
- [x] `lib/data/cache/cache_manager.dart`

## Next Steps: Implement Concrete Providers

### Step 1: Extract Binance Provider

Create `lib/data/providers/market/binance_provider.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/core/logging/logger.dart';

class BinanceProvider implements MarketProvider {
  @override
  String get name => 'Binance';
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  
  final StreamController<PriceUpdate> _priceController = 
      StreamController<PriceUpdate>.broadcast();
  
  final List<String> _cryptoSymbols = [
    'BTC', 'ETH', 'SOL', 'BNB', 'XRP', 'DOGE', 'ADA', 'AVAX'
  ];
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  bool supportsAsset(String symbol) {
    return _cryptoSymbols.contains(symbol);
  }
  
  @override
  List<String> getSupportedSymbols() => List.from(_cryptoSymbols);
  
  @override
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols) async {
    // Copy existing logic from TradingProvider._fetchBinancePrices()
    logger.network('Fetching prices from Binance REST: $symbols');
    
    final results = <String, PriceData>{};
    
    // On web, use CORS proxy
    final baseUrl = kIsWeb 
        ? 'https://corsproxy.io/?https://api.binance.com'
        : 'https://api.binance.com';
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v3/ticker/24hr'),
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final cryptoMap = {
          'BTCUSDT': 'BTC',
          'ETHUSDT': 'ETH',
          'SOLUSDT': 'SOL',
          'BNBUSDT': 'BNB',
          'XRPUSDT': 'XRP',
          'DOGEUSDT': 'DOGE',
          'ADAUSDT': 'ADA',
          'AVAXUSDT': 'AVAX',
        };
        
        for (final item in data) {
          final sym = item['symbol'] as String;
          if (cryptoMap.containsKey(sym) && symbols.contains(cryptoMap[sym])) {
            final appSym = cryptoMap[sym]!;
            final price = double.tryParse(item['lastPrice'] as String) ?? 0.0;
            final change = double.tryParse(item['priceChangePercent'] as String) ?? 0.0;
            
            if (price > 0) {
              results[appSym] = PriceData(
                symbol: appSym,
                price: price,
                change: change,
                timestamp: DateTime.now().millisecondsSinceEpoch,
                source: 'binance-rest',
              );
            }
          }
        }
        
        logger.network('Binance: Fetched ${results.length} prices');
      }
    } catch (e) {
      logger.error('Binance fetch error', e);
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
    // Copy logic from candlestick_chart.dart _fetchBinanceKlines()
    logger.network('Fetching Binance candles: $symbol $interval');
    
    final binSymbol = '${symbol}USDT';
    var url = 'https://api.binance.com/api/v3/klines?symbol=$binSymbol&interval=$interval&limit=${limit ?? 500}';
    if (endTime != null) url += '&endTime=$endTime';
    
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return [];
      
      final List<dynamic> raw = jsonDecode(resp.body);
      return raw.map((k) {
        return CandleData(
          timestamp: k[0] as int,
          open: double.parse(k[1].toString()),
          high: double.parse(k[2].toString()),
          low: double.parse(k[3].toString()),
          close: double.parse(k[4].toString()),
          volume: double.parse(k[5].toString()),
        );
      }).toList();
    } catch (e) {
      logger.error('Binance OHLC fetch error', e);
      return [];
    }
  }
  
  @override
  Stream<PriceUpdate>? subscribeToPriceUpdates(List<String> symbols) {
    if (kIsWeb) {
      logger.warning('Binance WebSocket not supported on web');
      return null;
    }
    
    if (!_isConnected) {
      connect();
    }
    
    return _priceController.stream
        .where((update) => symbols.contains(update.symbol));
  }
  
  @override
  Future<void> connect() async {
    if (kIsWeb || _isConnected || _isConnecting) return;
    
    _isConnecting = true;
    logger.info('Connecting to Binance WebSocket...');
    
    final streams = [
      'btcusdt@ticker', 'ethusdt@ticker', 'solusdt@ticker', 'bnbusdt@ticker',
      'xrpusdt@ticker', 'dogeusdt@ticker', 'adausdt@ticker', 'avaxusdt@ticker',
    ].join('/');
    
    final uri = Uri.parse('wss://stream.binance.com:9443/stream?streams=$streams');
    
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnecting = false;
      _isConnected = true;
      
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
      
      logger.info('Binance WebSocket connected');
    } catch (e) {
      _isConnecting = false;
      logger.error('Binance WebSocket connection failed', e);
      _reconnect();
    }
  }
  
  void _onMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = jsonDecode(message);
      final String? stream = data['stream']?.toString();
      final ticker = data['data'] as Map<String, dynamic>?;
      if (stream == null || ticker == null) return;
      
      final rawSymbol = stream.split('@')[0].toUpperCase();
      final symbol = rawSymbol.replaceAll('USDT', '');
      
      final double price = double.tryParse(ticker['c']?.toString() ?? '') ?? 0.0;
      final double change = double.tryParse(ticker['P']?.toString() ?? '') ?? 0.0;
      
      if (price > 0) {
        _priceController.add(PriceUpdate(
          symbol: symbol,
          price: price,
          change: change,
          source: 'binance-ws',
        ));
      }
    } catch (e) {
      logger.error('Binance WS message parse error', e);
    }
  }
  
  void _onError(error) {
    logger.error('Binance WS error', error);
    _reconnect();
  }
  
  void _onDone() {
    logger.warning('Binance WS connection closed');
    _isConnected = false;
    _reconnect();
  }
  
  void _reconnect() {
    _disconnect();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }
  
  @override
  Future<void> disconnect() async {
    _disconnect();
  }
  
  void _disconnect() {
    try {
      _channel?.sink.close();
    } catch (e) {
      logger.error('Error closing Binance WebSocket', e);
    }
    _channel = null;
    _isConnected = false;
  }
  
  @override
  void dispose() {
    _disconnect();
    _reconnectTimer?.cancel();
    _priceController.close();
    logger.info('Binance provider disposed');
  }
}
```

### Step 2: Extract Yahoo Finance Provider

Create `lib/data/providers/market/yahoo_provider.dart`:

```dart
// Similar structure, extract logic from:
// - TradingProvider._fetchYahooPrices()
// - candlestick_chart.dart _fetchYahooOhlc()
```

### Step 3: Implement Market Repository

Create `lib/data/repositories/market_repository_impl.dart`:

```dart
import 'dart:async';
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/domain/entities/result.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/data/cache/cache_manager.dart';
import 'package:app/constants/markets.dart';
import 'package:app/utils/market_session.dart' as utils;
import 'package:app/core/logging/logger.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/market_events.dart';

class MarketRepositoryImpl implements MarketRepository {
  final List<MarketProvider> _providers;
  final CacheManager _cache;
  final StreamController<PriceUpdate> _priceStreamController = 
      StreamController<PriceUpdate>.broadcast();
  
  MarketRepositoryImpl({
    required List<MarketProvider> providers,
    required CacheManager cache,
  }) : _providers = providers,
       _cache = cache {
    _subscribeToProviders();
  }
  
  void _subscribeToProviders() {
    for (final provider in _providers) {
      final stream = provider.subscribeToPriceUpdates(provider.getSupportedSymbols());
      stream?.listen((update) {
        _onPriceUpdate(update);
      });
    }
  }
  
  void _onPriceUpdate(PriceUpdate update) {
    // Cache the update
    _cache.setPrice(update.symbol, update.toPriceData());
    
    // Forward to subscribers
    _priceStreamController.add(update);
    
    // Publish event
    eventBus.publish(PriceUpdatedEvent(
      symbol: update.symbol,
      price: update.price,
      change: update.change,
      source: update.source,
    ));
  }
  
  @override
  Future<Result<PriceData>> getCurrentPrice(String symbol) async {
    // Check cache first
    final cached = _cache.getPrice(symbol);
    if (cached != null && !cached.isStale) {
      logger.debug('Cache hit for $symbol');
      return Result.success(cached);
    }
    
    // Find provider
    final provider = _getProviderForSymbol(symbol);
    if (provider == null) {
      return Result.failure('No provider for $symbol');
    }
    
    // Fetch from provider
    try {
      final prices = await provider.fetchPrices([symbol]);
      if (prices.containsKey(symbol)) {
        final priceData = prices[symbol]!;
        _cache.setPrice(symbol, priceData);
        return Result.success(priceData);
      }
      return Result.failure('Price not available for $symbol');
    } catch (e) {
      logger.error('Failed to fetch price for $symbol', e);
      return Result.failure(e.toString());
    }
  }
  
  MarketProvider? _getProviderForSymbol(String symbol) {
    for (final provider in _providers) {
      if (provider.supportsAsset(symbol)) {
        return provider;
      }
    }
    return null;
  }
  
  @override
  Future<Result<Map<String, PriceData>>> getPrices(List<String> symbols) async {
    // Group symbols by provider
    final Map<MarketProvider, List<String>> providerGroups = {};
    
    for (final symbol in symbols) {
      final provider = _getProviderForSymbol(symbol);
      if (provider != null) {
        providerGroups.putIfAbsent(provider, () => []).add(symbol);
      }
    }
    
    // Fetch from each provider in parallel
    final results = <String, PriceData>{};
    
    await Future.wait(
      providerGroups.entries.map((entry) async {
        try {
          final prices = await entry.key.fetchPrices(entry.value);
          results.addAll(prices);
          
          // Cache all prices
          for (final priceData in prices.values) {
            _cache.setPrice(priceData.symbol, priceData);
          }
        } catch (e) {
          logger.error('Failed to fetch prices from ${entry.key.name}', e);
        }
      }),
    );
    
    if (results.isEmpty) {
      return Result.failure('No prices available');
    }
    
    return Result.success(results);
  }
  
  @override
  Future<Result<List<CandleData>>> getHistoricalCandles(
    String symbol,
    String timeframe, {
    int? limit,
    int? endTime,
  }) async {
    // Check cache
    final cached = _cache.getCandles(symbol, timeframe);
    if (cached != null) {
      logger.debug('Candle cache hit for $symbol $timeframe');
      return Result.success(cached);
    }
    
    // Find provider
    final provider = _getProviderForSymbol(symbol);
    if (provider == null) {
      return Result.failure('No provider for $symbol');
    }
    
    // Fetch candles
    try {
      final candles = await provider.fetchOHLC(
        symbol,
        timeframe,
        limit: limit,
        endTime: endTime,
      );
      
      if (candles.isEmpty) {
        return Result.failure('No candle data available');
      }
      
      // Cache candles
      _cache.setCandles(symbol, timeframe, candles);
      
      return Result.success(candles);
    } catch (e) {
      logger.error('Failed to fetch candles for $symbol', e);
      return Result.failure(e.toString());
    }
  }
  
  @override
  Stream<PriceUpdate> subscribeToPriceUpdates(String symbol) {
    return _priceStreamController.stream
        .where((update) => update.symbol == symbol);
  }
  
  @override
  Stream<PriceUpdate> subscribeToMultiplePrices(List<String> symbols) {
    return _priceStreamController.stream
        .where((update) => symbols.contains(update.symbol));
  }
  
  @override
  MarketStatus getMarketStatus(String symbol) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return MarketStatus.closed;
    
    final status = utils.getMarketStatus(asset);
    return _convertToRepoStatus(status);
  }
  
  MarketStatus _convertToRepoStatus(utils.MarketStatus status) {
    switch (status) {
      case utils.MarketStatus.open:
        return MarketStatus.open;
      case utils.MarketStatus.closed:
        return MarketStatus.closed;
      case utils.MarketStatus.preMarket:
        return MarketStatus.preMarket;
      case utils.MarketStatus.afterHours:
        return MarketStatus.afterHours;
    }
  }
  
  @override
  bool isMarketLive(String symbol) {
    return getMarketStatus(symbol).isLive;
  }
  
  @override
  PriceData? getCachedPrice(String symbol) {
    return _cache.getPrice(symbol);
  }
  
  @override
  void clearCache(String symbol) {
    _cache.clearPrice(symbol);
    _cache.clearCandles(symbol);
  }
  
  @override
  void clearAllCache() {
    _cache.clearAll();
  }
  
  @override
  void dispose() {
    _priceStreamController.close();
    for (final provider in _providers) {
      provider.dispose();
    }
    logger.info('Market repository disposed');
  }
}
```

## Integration Steps

### 1. Register Services in main.dart

```dart
Future<void> _initializeServices() async {
  logger.info('Initializing TradeVerse services...');
  
  // Cache
  final cacheManager = CacheManager();
  sl.registerSingleton<CacheManager>(cacheManager);
  
  // Market providers
  final binanceProvider = BinanceProvider();
  final yahooProvider = YahooFinanceProvider();
  
  await binanceProvider.connect(); // Connect WebSocket
  
  // Market repository
  final marketRepo = MarketRepositoryImpl(
    providers: [binanceProvider, yahooProvider],
    cache: cacheManager,
  );
  sl.registerSingleton<MarketRepository>(marketRepo);
  
  logger.info('Services initialized successfully');
}
```

### 2. Use in TradingProvider (Gradual Migration)

```dart
class TradingProvider extends ChangeNotifier {
  // Add repository
  late final MarketRepository _marketRepo;
  
  TradingProvider() {
    _marketRepo = sl.get<MarketRepository>();
    
    // Subscribe to market events
    eventBus.subscribe<PriceUpdatedEvent>((event) {
      _onPriceUpdate(event);
    });
    
    _loadState();
    // Old WebSocket code can be removed gradually
  }
  
  void _onPriceUpdate(PriceUpdatedEvent event) {
    _prices ??= {};
    _priceChanges ??= {};
    _prices![event.symbol] = event.price;
    _priceChanges![event.symbol] = event.change;
    _priceUpdateController.add(event.symbol);
    notifyListeners();
  }
  
  // Old method can delegate to repository
  double priceOf(String symbol) {
    // Try new repository first
    final cached = _marketRepo.getCachedPrice(symbol);
    if (cached != null) {
      return cached.price;
    }
    
    // Fallback to old implementation
    _prices ??= {};
    final a = getAssetBySymbol(symbol);
    return _prices![symbol] ?? a?.basePrice ?? 0.0;
  }
}
```

## Testing Phase 2

```dart
// test/data/repositories/market_repository_test.dart
void main() {
  late MarketRepositoryImpl repository;
  late MockBinanceProvider binanceProvider;
  late MockYahooProvider yahooProvider;
  late CacheManager cache;
  
  setUp(() {
    binanceProvider = MockBinanceProvider();
    yahooProvider = MockYahooProvider();
    cache = CacheManager();
    
    repository = MarketRepositoryImpl(
      providers: [binanceProvider, yahooProvider],
      cache: cache,
    );
  });
  
  test('fetches price from correct provider', () async {
    when(binanceProvider.fetchPrices(['BTC']))
        .thenAnswer((_) async => {
          'BTC': PriceData(
            symbol: 'BTC',
            price: 67000.0,
            change: 2.5,
            timestamp: DateTime.now().millisecondsSinceEpoch,
            source: 'binance',
          ),
        });
    
    final result = await repository.getCurrentPrice('BTC');
    
    expect(result.isSuccess, true);
    expect(result.data!.price, 67000.0);
  });
  
  test('caches fetched prices', () async {
    // ... test caching logic
  });
}
```

## Success Criteria

- [ ] All market data flows through repository
- [ ] Providers are interchangeable
- [ ] Cache reduces API calls
- [ ] No breaking changes to UI
- [ ] All existing features work
- [ ] Performance maintained or improved

