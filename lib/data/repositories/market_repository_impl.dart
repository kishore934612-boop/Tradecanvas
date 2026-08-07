import 'dart:async';
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/domain/entities/result.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/data/cache/cache_manager.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/market_events.dart';
import 'package:app/core/logging/logger.dart';

class MarketRepositoryImpl implements MarketRepository {
  final BinanceProvider _binanceProvider;
  final CacheManager _cache;
  final EventBus _eventBus;
  final Logger _logger;

  final StreamController<PriceUpdate> _priceUpdateController =
      StreamController<PriceUpdate>.broadcast();

  StreamSubscription? _binanceSubscription;
  bool _isInitialized = false;

  MarketRepositoryImpl({
    required this._binanceProvider,
    required this._cache,
    required this._eventBus,
    required this._logger,
  });

  /// Initialize repository and connect to real-time data sources
  Future<void> initialize() async {
    if (_isInitialized) return;

    _logger.info('Initializing MarketRepository...');

    // Connect provider
    await _binanceProvider.connect();

    // Subscribe to Binance WebSocket updates (if available)
    final binanceStream = _binanceProvider.subscribeToPriceUpdates(
      _binanceProvider.getSupportedSymbols(),
    );

    if (binanceStream != null) {
      _binanceSubscription = binanceStream.listen((update) {
        _handlePriceUpdate(update);
      });
      _logger.info('Subscribed to Binance WebSocket updates');
    }

    _isInitialized = true;
    _logger.info('MarketRepository initialized');
  }

  /// Handle incoming price updates from providers
  void _handlePriceUpdate(PriceUpdate update) {
    // Convert to PriceData and cache
    final priceData = update.toPriceData();
    _cache.setPrice(update.symbol, priceData);

    // Emit to local stream
    _priceUpdateController.add(update);

    // Emit event to event bus
    _eventBus.publish<PriceUpdatedEvent>(PriceUpdatedEvent(
      symbol: update.symbol,
      price: update.price,
      change: update.change,
      source: update.source,
    ));
  }

  /// Determine which provider to use for a symbol
  MarketProvider _getProviderForSymbol(String symbol) {
    if (_binanceProvider.supportsAsset(symbol)) {
      return _binanceProvider;
    }
    throw UnsupportedError('No provider available for symbol: $symbol');
  }

  @override
  Future<Result<PriceData>> getCurrentPrice(String symbol) async {
    try {
      // Check cache first
      final cached = _cache.getPrice(symbol);
      if (cached != null && !cached.isStale) {
        _logger.debug('Cache hit for $symbol (age: ${cached.ageInSeconds}s)');
        return Result.success(cached);
      }

      // Fetch from Binance provider
      final provider = _getProviderForSymbol(symbol);
      final prices = await provider.fetchPrices([symbol]);

      if (prices.containsKey(symbol)) {
        final priceData = prices[symbol]!;
        
        // Cache the result
        _cache.setPrice(symbol, priceData);

        // Emit event
        _eventBus.publish<PriceUpdatedEvent>(PriceUpdatedEvent(
          symbol: symbol,
          price: priceData.price,
          change: priceData.change,
          source: priceData.source,
        ));

        return Result.success(priceData);
      }

      return Result.failure('Price not available for $symbol');
    } catch (e) {
      _logger.error('Failed to get price for $symbol: $e');
      return Result.failure('Failed to fetch price: $e');
    }
  }

  @override
  Future<Result<Map<String, PriceData>>> getPrices(List<String> symbols) async {
    if (symbols.isEmpty) {
      return Result.success({});
    }

    try {
      final Map<String, PriceData> allPrices = {};
      
      // Check cache first for all symbols
      final List<String> symbolsToFetch = [];
      for (final symbol in symbols) {
        final cached = _cache.getPrice(symbol);
        if (cached != null && !cached.isStale) {
          allPrices[symbol] = cached;
        } else {
          symbolsToFetch.add(symbol);
        }
      }

      if (symbolsToFetch.isEmpty) {
        _logger.debug('All ${symbols.length} prices served from cache');
        return Result.success(allPrices);
      }

      _logger.debug('Fetching ${symbolsToFetch.length}/${symbols.length} prices from Binance');

      // Filter to Binance symbols
      final binanceSymbols = symbolsToFetch
          .where((s) => _binanceProvider.supportsAsset(s))
          .toList();

      if (binanceSymbols.isNotEmpty) {
        final pricesMap = await _binanceProvider.fetchPrices(binanceSymbols);
        for (final entry in pricesMap.entries) {
          allPrices[entry.key] = entry.value;
          
          // Cache and emit event
          _cache.setPrice(entry.key, entry.value);
          _eventBus.publish<PriceUpdatedEvent>(PriceUpdatedEvent(
            symbol: entry.key,
            price: entry.value.price,
            change: entry.value.change,
            source: entry.value.source,
          ));
        }
      }

      _logger.info('Fetched ${allPrices.length}/${symbols.length} prices successfully');
      return Result.success(allPrices);
    } catch (e) {
      _logger.error('Failed to fetch prices: $e');
      return Result.failure('Failed to fetch prices: $e');
    }
  }

  @override
  Future<Result<List<CandleData>>> getHistoricalCandles(
    String symbol,
    String timeframe, {
    int? limit,
    int? endTime,
  }) async {
    try {
      // Check cache first
      final cached = _cache.getCandles(symbol, timeframe);
      if (cached != null && cached.isNotEmpty) {
        _logger.debug('Cache hit for $symbol $timeframe candles (${cached.length} candles)');
        return Result.success(cached);
      }

      // Fetch from Binance provider
      final provider = _getProviderForSymbol(symbol);
      final candles = await provider.fetchOHLC(
        symbol,
        timeframe,
        limit: limit,
        endTime: endTime,
      );

      if (candles.isEmpty) {
        return Result.failure('No candle data available for $symbol');
      }

      // Cache the result
      _cache.setCandles(symbol, timeframe, candles);

      _logger.info('Fetched ${candles.length} candles for $symbol $timeframe');
      return Result.success(candles);
    } catch (e) {
      _logger.error('Failed to fetch candles for $symbol: $e');
      return Result.failure('Failed to fetch candles: $e');
    }
  }

  @override
  Stream<PriceUpdate> subscribeToPriceUpdates(String symbol) {
    return _priceUpdateController.stream
        .where((update) => update.symbol == symbol);
  }

  @override
  Stream<PriceUpdate> subscribeToMultiplePrices(List<String> symbols) {
    final symbolSet = symbols.toSet();
    return _priceUpdateController.stream
        .where((update) => symbolSet.contains(update.symbol));
  }

  @override
  MarketStatus getMarketStatus(String symbol) {
    // Crypto markets are open 24/7
    return MarketStatus.open;
  }

  @override
  bool isMarketLive(String symbol) {
    return true;
  }

  @override
  PriceData? getCachedPrice(String symbol) {
    return _cache.getPrice(symbol);
  }

  @override
  void clearCache(String symbol) {
    _cache.clearPrice(symbol);
    _cache.clearCandles(symbol);
    _logger.debug('Cleared cache for $symbol');
  }

  @override
  void clearAllCache() {
    _cache.clearAll();
    _logger.info('Cleared all market data cache');
  }

  @override
  void dispose() {
    _binanceSubscription?.cancel();
    _priceUpdateController.close();
    _binanceProvider.dispose();
    _logger.info('MarketRepository disposed');
  }
}
