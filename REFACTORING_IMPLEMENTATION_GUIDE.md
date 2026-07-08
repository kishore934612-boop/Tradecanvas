# TradeVerse Refactoring - Implementation Guide

## ⚠️ Important Notice

This is a **6-10 week project** requiring careful, incremental changes. This guide provides:
1. Exact file structure to create
2. Core interfaces to implement
3. Step-by-step migration instructions
4. Testing checkpoints

**DO NOT** attempt to complete all phases at once. Each phase must be tested and validated before proceeding.

---

## Phase 1: Foundation (Week 1) - STARTED

### ✅ Completed
- [x] Service Locator (`lib/core/di/service_locator.dart`)
- [x] Event Bus (`lib/core/events/event_bus.dart`)
- [x] Trade Events (`lib/core/events/trade_events.dart`)
- [x] Market Events (`lib/core/events/market_events.dart`)
- [x] Portfolio Events (`lib/core/events/portfolio_events.dart`)
- [x] Logger (`lib/core/logging/logger.dart`)

### 🔄 Next Steps

#### 1. Create Domain Layer Interfaces

```dart
// lib/domain/entities/result.dart
class Result<T> {
  final T? data;
  final String? error;
  final bool success;
  
  Result.success(this.data) : success = true, error = null;
  Result.failure(this.error) : success = false, data = null;
  
  bool get isSuccess => success;
  bool get isFailure => !success;
}
```

#### 2. Create Repository Interfaces

```dart
// lib/domain/repositories/market_repository.dart
abstract class MarketRepository {
  /// Get current price for a symbol
  Future<Result<double>> getCurrentPrice(String symbol);
  
  /// Get historical candles
  Future<Result<List<Candle>>> getHistoricalCandles(
    String symbol,
    String timeframe, {
    int? limit,
    int? endTime,
  });
  
  /// Subscribe to price updates
  Stream<PriceUpdate> subscribeToPriceUpdates(String symbol);
  
  /// Get market status
  MarketStatus getMarketStatus(String symbol);
}
```

#### 3. Create Service Interfaces

```dart
// lib/domain/services/trading_engine.dart
abstract class TradingEngine {
  /// Calculate position opening requirements
  PositionCalculation calculatePositionOpen({
    required String symbol,
    required PositionSide side,
    required double quantity,
    required int leverage,
    required double entryPrice,
  });
  
  /// Calculate position P&L
  double calculatePnL({
    required Position position,
    required double currentPrice,
  });
  
  /// Calculate liquidation price
  double calculateLiquidationPrice(Position position);
  
  /// Validate trade
  TradeValidation validateTrade({
    required String symbol,
    required double quantity,
    required int leverage,
    required double balance,
    required double marginUsed,
  });
}
```

#### 4. Initialize in main.dart

```dart
// Add to main() before runApp()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services
  await _initializeServices();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => TradingProvider()),
        // Gradually add new controllers here
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  // Configure logger
  logger.setEnabled(kDebugMode);
  logger.info('Initializing TradeVerse...');
  
  // Register repositories (Phase 2)
  // Register services (Phase 3)
  // Register controllers (Phase 4)
}
```

---

## Phase 2: Repository Layer (Week 1-2)

### Objective
Create abstraction layer between business logic and data sources.

### Implementation Steps

#### Step 1: Create Market Provider Interface

```dart
// lib/data/providers/market/market_provider.dart
abstract class MarketProvider {
  String get name;
  
  /// Fetch current prices
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols);
  
  /// Fetch historical OHLC data
  Future<List<CandleData>> fetchOHLC(
    String symbol,
    String interval, {
    int? limit,
    int? endTime,
  });
  
  /// Subscribe to real-time prices (WebSocket)
  Stream<PriceUpdate>? subscribeToPrice(String symbol);
  
  /// Check if provider supports asset
  bool supportsAsset(String symbol);
}
```

#### Step 2: Implement Binance Provider

```dart
// lib/data/providers/market/binance_provider.dart
class BinanceProvider implements MarketProvider {
  @override
  String get name => 'Binance';
  
  WebSocketChannel? _channel;
  final _priceController = StreamController<PriceUpdate>.broadcast();
  
  @override
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols) async {
    logger.network('Fetching prices from Binance: $symbols');
    // Existing REST API logic from TradingProvider._fetchBinancePrices()
    // Return Map<String, PriceData>
  }
  
  @override
  Stream<PriceUpdate>? subscribeToPrice(String symbol) {
    // Existing WebSocket logic from TradingProvider._connectCryptoWs()
    return _priceController.stream
        .where((update) => update.symbol == symbol);
  }
  
  // ... rest of implementation
}
```

#### Step 3: Implement Yahoo Provider

```dart
// lib/data/providers/market/yahoo_provider.dart
class YahooFinanceProvider implements MarketProvider {
  @override
  String get name => 'Yahoo Finance';
  
  @override
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols) async {
    logger.network('Fetching prices from Yahoo: $symbols');
    // Existing logic from TradingProvider._fetchYahooPrices()
    // Return Map<String, PriceData>
  }
  
  @override
  Future<List<CandleData>> fetchOHLC(...) async {
    // Existing logic from candlestick_chart.dart _fetchYahooOhlc()
  }
  
  // WebSocket not supported
  @override
  Stream<PriceUpdate>? subscribeToPrice(String symbol) => null;
}
```

#### Step 4: Create Market Repository Implementation

```dart
// lib/data/repositories/market_repository_impl.dart
class MarketRepositoryImpl implements MarketRepository {
  final List<MarketProvider> _providers;
  final CacheManager _cache;
  
  MarketRepositoryImpl({
    required List<MarketProvider> providers,
    required CacheManager cache,
  }) : _providers = providers;
  
  @override
  Future<Result<double>> getCurrentPrice(String symbol) async {
    try {
      // Check cache first
      final cached = _cache.getPrice(symbol);
      if (cached != null && !cached.isStale) {
        return Result.success(cached.price);
      }
      
      // Find appropriate provider
      final provider = _getProviderForSymbol(symbol);
      if (provider == null) {
        return Result.failure('No provider for $symbol');
      }
      
      // Fetch from provider
      final prices = await provider.fetchPrices([symbol]);
      if (prices.containsKey(symbol)) {
        final price = prices[symbol]!.price;
        _cache.setPrice(symbol, price);
        return Result.success(price);
      }
      
      return Result.failure('Price not available');
    } catch (e) {
      logger.error('Failed to get price for $symbol', e);
      return Result.failure(e.toString());
    }
  }
  
  MarketProvider? _getProviderForSymbol(String symbol) {
    // Logic to select provider based on symbol
    // Crypto -> BinanceProvider
    // Stocks/Forex -> YahooProvider
  }
}
```

#### Step 5: Register in Service Locator

```dart
// In _initializeServices()
Future<void> _initializeServices() async {
  // Providers
  final binanceProvider = BinanceProvider();
  final yahooProvider = YahooFinanceProvider();
  
  // Cache
  final cacheManager = CacheManager();
  
  // Repositories
  final marketRepo = MarketRepositoryImpl(
    providers: [binanceProvider, yahooProvider],
    cache: cacheManager,
  );
  
  sl.registerSingleton<MarketRepository>(marketRepo);
  
  logger.info('Services initialized successfully');
}
```

---

## Phase 3: Split TradingProvider (Week 2-3)

### Objective
Extract responsibilities from monolithic TradingProvider into specialized controllers.

### Migration Strategy: Adapter Pattern

```dart
// Keep TradingProvider as facade during migration
class TradingProvider extends ChangeNotifier {
  // Old implementation (keep temporarily)
  double _balance = 10000.0;
  
  // New controllers (inject gradually)
  late PortfolioController _portfolioController;
  late PositionController _positionController;
  
  TradingProvider() {
    // Initialize new controllers
    _portfolioController = sl.get<PortfolioController>();
    _positionController = sl.get<PositionController>();
    
    // Listen to events from controllers
    eventBus.subscribe<BalanceChangedEvent>((event) {
      notifyListeners(); // Maintain compatibility
    });
    
    // Load old state
    _loadState();
  }
  
  // Gradually delegate to controllers
  double get balance => _portfolioController.balance; // New
  // double get balance => _balance; // Old (remove after migration)
}
```

### Create PortfolioController

```dart
// lib/presentation/controllers/portfolio_controller.dart
class PortfolioController extends ChangeNotifier {
  final PortfolioRepository _repository;
  final TradingEngine _tradingEngine;
  
  double _balance;
  double _startingCapital;
  double _realizedPnl = 0.0;
  
  PortfolioController({
    required PortfolioRepository repository,
    required TradingEngine tradingEngine,
  }) : _repository = repository,
       _tradingEngine = tradingEngine,
       _balance = 10000.0,
       _startingCapital = 10000.0 {
    _initialize();
  }
  
  // Getters
  double get balance => _balance;
  double get equity => _balance + _getUnrealizedPnL();
  double get startingCapital => _startingCapital;
  double get realizedPnl => _realizedPnl;
  double get totalReturnPct => 
      (_startingCapital > 0) ? ((equity - _startingCapital) / _startingCapital) * 100.0 : 0.0;
  
  // Methods
  Future<void> _initialize() async {
    await _repository.load();
    _balance = _repository.getBalance();
    _startingCapital = _repository.getStartingCapital();
    _realizedPnl = _repository.getRealizedPnl();
    notifyListeners();
  }
  
  void updateBalance(double amount, String reason) {
    final oldBalance = _balance;
    _balance += amount;
    
    _repository.saveBalance(_balance);
    
    eventBus.publish(BalanceChangedEvent(
      oldBalance: oldBalance,
      newBalance: _balance,
      reason: reason,
    ));
    
    notifyListeners();
  }
  
  double _getUnrealizedPnL() {
    // Get from PositionController
    final positionController = sl.get<PositionController>();
    return positionController.totalUnrealizedPnL;
  }
}
```

---

## Testing Checkpoints

### After Phase 1
```dart
// test/core/service_locator_test.dart
test('Service locator registers and retrieves services', () {
  sl.registerSingleton<String>('test');
  expect(sl.get<String>(), 'test');
});

// test/core/event_bus_test.dart
test('Event bus publishes and receives events', () async {
  final received = <TradeCompletedEvent>[];
  eventBus.subscribe<TradeCompletedEvent>((event) {
    received.add(event);
  });
  
  final event = TradeCompletedEvent(...);
  eventBus.publish(event);
  
  await Future.delayed(Duration.zero);
  expect(received.length, 1);
});
```

### After Phase 2
- All prices should still update correctly
- Charts should still work
- No visual changes

### After Phase 3
- All trading functions work
- Portfolio displays correctly
- No performance regression

---

## Rollback Plan

If issues occur at any phase:

1. **Keep old code commented** during migration
2. **Feature flag** new architecture:
```dart
const USE_NEW_ARCHITECTURE = false; // Set to true after testing

if (USE_NEW_ARCHITECTURE) {
  // Use new controllers
} else {
  // Use old TradingProvider
}
```
3. **Git branches** for each phase
4. **Backup database** before changes

---

## Summary

**Phase 1 (Week 1):** ✅ Foundation complete - Event bus, logging, DI
**Phase 2 (Week 1-2):** 🔄 Create repository layer
**Phase 3 (Week 2-3):** 🔄 Split TradingProvider
**Phase 4-10:** See ARCHITECTURE_REFACTOR_PLAN.md

**Current Status:** Foundation infrastructure created
**Next Action:** Implement Phase 2 - Repository Layer

**Estimated Total Time:** 6-10 weeks for complete refactoring

