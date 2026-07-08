# TradeVerse Architecture - Quick Reference

## 🗂️ Project Structure (Phase 2)

```
lib/
├── core/                           # Core infrastructure (Phase 1 & 2)
│   ├── di/
│   │   └── service_locator.dart    # Dependency injection
│   ├── events/
│   │   ├── event_bus.dart          # Event system
│   │   ├── market_events.dart      # Market-related events
│   │   ├── trade_events.dart       # Trading events
│   │   └── portfolio_events.dart   # Portfolio events
│   └── logging/
│       └── logger.dart             # Structured logging
│
├── domain/                         # Business logic layer (Phase 1)
│   ├── entities/
│   │   ├── price_data.dart         # Price entity
│   │   ├── candle_data.dart        # OHLC candle entity
│   │   └── result.dart             # Result<T> type
│   ├── repositories/
│   │   ├── market_repository.dart  # Market data interface
│   │   └── portfolio_repository.dart
│   └── services/
│       └── trading_engine.dart     # Trading calculations
│
├── data/                           # Data access layer (Phase 2) ✅
│   ├── providers/
│   │   └── market/
│   │       ├── market_provider.dart      # Provider interface
│   │       ├── binance_provider.dart     # Binance implementation ✅
│   │       └── yahoo_provider.dart       # Yahoo implementation ✅
│   ├── repositories/
│   │   └── market_repository_impl.dart   # Repository implementation ✅
│   └── cache/
│       └── cache_manager.dart      # In-memory cache
│
├── providers/                      # State management (existing)
│   ├── trading_provider.dart       # Main business logic (1000+ LOC)
│   └── app_state.dart              # App-wide state
│
├── screens/                        # UI screens
├── components/                     # Reusable widgets
├── models/                         # Data models
├── utils/                          # Utilities
└── constants/                      # Constants
```

---

## 🔌 Service Locator Usage

```dart
// Import
import 'package:app/core/di/service_locator.dart';

// Get services anywhere in the app
final repository = serviceLocator<MarketRepository>();
final logger = serviceLocator<Logger>();
final eventBus = serviceLocator<EventBus>();
final cache = serviceLocator<CacheManager>();
```

---

## 📊 Market Repository API

### **Fetch Prices**
```dart
// Single price
final result = await repository.getCurrentPrice('BTC');
if (result.isSuccess) {
  print('Price: \$${result.data!.price}');
}

// Multiple prices
final result = await repository.getPrices(['BTC', 'ETH', 'AAPL']);
```

### **Real-time Updates**
```dart
repository.subscribeToPriceUpdates('BTC').listen((update) {
  print('${update.symbol}: \$${update.price}');
});
```

### **Historical Data**
```dart
final result = await repository.getHistoricalCandles('AAPL', '1d', limit: 200);
```

### **Market Status**
```dart
if (repository.isMarketLive('AAPL')) {
  // Market is open, fetch fresh data
}

final status = repository.getMarketStatus('AAPL');
print(status.label); // OPEN, CLOSED, PRE-MARKET, AFTER HOURS
```

---

## 🎯 Supported Assets

### **Crypto (Binance)** - 24/7
- BTC, ETH, SOL, BNB, XRP, DOGE, ADA, AVAX

### **US Stocks (Yahoo)** - Mon-Fri 9:30 AM - 4:00 PM ET
- AAPL, NVDA, TSLA

### **Indian Stocks (Yahoo)** - Mon-Fri 9:15 AM - 3:30 PM IST
- TCS, RELIANCE, HDFCBANK

### **Forex (Yahoo)** - 24/5
- GBP/USD, EUR/USD, USD/JPY, USD/CAD, AUD/USD

---

## 🔄 Data Flow

```
┌──────────┐
│    UI    │
└────┬─────┘
     │
     ▼
┌────────────────┐       ┌─────────────┐
│ TradingProvider│◀─────▶│  AppState   │
└────┬───────────┘       └─────────────┘
     │
     ▼
┌─────────────────┐
│ MarketRepository│ (NEW ✅)
└────┬────────────┘
     │
     ├──────────────┬──────────────┐
     ▼              ▼              ▼
┌─────────┐  ┌──────────┐  ┌──────────┐
│ Binance │  │  Yahoo   │  │  Cache   │
│Provider │  │ Provider │  │ Manager  │
└─────────┘  └──────────┘  └──────────┘
     │              │
     ▼              ▼
┌──────────────────────────────────────┐
│         External APIs                 │
│  Binance REST + WS | Yahoo REST       │
└──────────────────────────────────────┘
```

---

## 📝 Event Bus Usage

```dart
// Import
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/market_events.dart';

// Get event bus
final eventBus = serviceLocator<EventBus>();

// Subscribe to events
final subscription = eventBus.on<PriceUpdatedEvent>().listen((event) {
  print('${event.symbol}: \$${event.price}');
});

// Emit event
eventBus.emit(PriceUpdatedEvent(
  symbol: 'BTC',
  price: 45000.0,
  change: 2.5,
  source: 'binance-ws',
));

// Cancel subscription
subscription.cancel();
```

---

## 🔍 Logger Usage

```dart
final logger = serviceLocator<Logger>();

logger.info('Application started');
logger.warning('Cache miss for BTC');
logger.error('API request failed: timeout');
logger.debug('Cache size: 50 entries');
logger.market('BTC: \$45000.00');
logger.network('GET /api/prices - 200 OK');
```

---

## 💾 Cache Usage

```dart
final cache = serviceLocator<CacheManager>();

// Get cached price (synchronous)
final priceData = cache.getPrice('BTC');

// Set price with custom TTL
cache.setPrice('BTC', priceData, ttl: 10000); // 10 seconds

// Clear cache
cache.clearPrice('BTC');
cache.clearAll();

// Statistics
final stats = cache.getStats();
print('Cached entries: ${stats["total"]}');
```

---

## 🧪 Testing Examples

### **Test Price Fetching**
```dart
void testRepository() async {
  final repo = serviceLocator<MarketRepository>();
  
  // Test crypto
  final btc = await repo.getCurrentPrice('BTC');
  print('BTC: ${btc.isSuccess ? "\$${btc.data!.price}" : "FAILED"}');
  
  // Test stocks
  final aapl = await repo.getCurrentPrice('AAPL');
  print('AAPL: ${aapl.isSuccess ? "\$${aapl.data!.price}" : "FAILED"}');
  
  // Test forex
  final forex = await repo.getCurrentPrice('EUR/USD');
  print('EUR/USD: ${forex.isSuccess ? "\$${forex.data!.price}" : "FAILED"}');
}
```

### **Test Real-time Updates**
```dart
void testWebSocket() {
  final repo = serviceLocator<MarketRepository>();
  
  repo.subscribeToPriceUpdates('BTC').listen((update) {
    print('BTC WebSocket: \$${update.price} (${update.source})');
  });
}
```

### **Test Market Status**
```dart
void testMarketHours() {
  final repo = serviceLocator<MarketRepository>();
  
  print('BTC: ${repo.getMarketStatus('BTC').label}');
  print('AAPL: ${repo.getMarketStatus('AAPL').label}');
  print('TCS: ${repo.getMarketStatus('TCS').label}');
  print('EUR/USD: ${repo.getMarketStatus('EUR/USD').label}');
}
```

---

## ⚙️ Configuration

### **Cache TTL (Time-To-Live)**
```dart
// Default values in CacheManager
static const int priceTTL = 5000;   // 5 seconds
static const int candleTTL = 30000; // 30 seconds

// Custom TTL
cache.setPrice('BTC', data, ttl: 10000); // 10 seconds
```

### **Polling Interval**
```dart
// In TradingProvider
Timer.periodic(const Duration(seconds: 5), (_) {
  // Fetch prices every 5 seconds
});
```

### **WebSocket Reconnection**
```dart
// Automatic reconnection after 5 seconds
Future.delayed(const Duration(seconds: 5), () {
  if (!_isConnected) {
    connect();
  }
});
```

---

## 🚨 Error Handling

### **Result Pattern**
```dart
final result = await repository.getCurrentPrice('BTC');

if (result.isSuccess) {
  // Success path
  final price = result.data!;
  print('Price: \$${price.price}');
} else {
  // Error path
  print('Error: ${result.error}');
  // Show user-friendly message
  // Fall back to cached data
}
```

### **Try-Catch with Fallback**
```dart
try {
  final result = await repository.getCurrentPrice('BTC');
  if (result.isSuccess) {
    return result.data!;
  }
} catch (e) {
  logger.error('Failed to fetch: $e');
}

// Fallback to cache
final cached = repository.getCachedPrice('BTC');
if (cached != null) {
  return cached;
}

// Last resort
return PriceData(symbol: 'BTC', price: 0, change: 0, timestamp: 0, source: 'fallback');
```

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| `COMPLETE_ARCHITECTURE.md` | Full app architecture overview |
| `ARCHITECTURE_REFACTOR_PLAN.md` | 15-phase refactoring plan |
| `PHASE_2_COMPLETE.md` | Phase 2 implementation details |
| `PHASE_2_SUMMARY.md` | Executive summary of Phase 2 |
| `PHASE_3_CHECKLIST.md` | Step-by-step Phase 3 guide |
| `REPOSITORY_USAGE_GUIDE.md` | Code examples and patterns |
| `QUICK_REFERENCE.md` | This file - quick lookup |

---

## 🔗 Key Concepts

### **Repository Pattern**
Abstracts data access behind clean interface. UI never calls APIs directly.

### **Provider Pattern**
Multiple data sources (Binance, Yahoo) implement same interface.

### **Result Type**
`Result<T>` wraps success/failure instead of throwing exceptions.

### **Service Locator**
Global registry for dependency injection.

### **Event Bus**
Decoupled communication between components.

### **Strangler Fig**
Build new system alongside old, migrate gradually.

---

## 🎯 Phase Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Foundation (events, logging, DI, entities) |
| Phase 2 | ✅ Complete | Repository layer (providers, repository) |
| Phase 3 | 🔄 Next | TradingProvider integration |
| Phase 4 | ⏳ Planned | Split into controllers |
| Phase 5+ | ⏳ Planned | Trading engine, chart engine, etc. |

---

## 💡 Pro Tips

1. **Always check cache first** - Reduces API calls
2. **Use batch requests** - `getPrices()` over `getCurrentPrice()` in loop
3. **Cancel subscriptions** - Prevent memory leaks
4. **Check market status** - Don't poll closed markets
5. **Handle errors gracefully** - Use Result type
6. **Use service locator** - Don't pass dependencies manually
7. **Subscribe to EventBus** - React to system-wide events
8. **Log strategically** - Use appropriate log levels
9. **Test incrementally** - Don't change everything at once
10. **Document as you go** - Future you will thank you

---

## 🔍 Debugging

### **Check Service Initialization**
```dart
// In console after app starts:
[INFO] === Phase 2: Initializing Repository Layer ===
[INFO] Binance WebSocket connected
[INFO] Yahoo Finance provider ready (REST-only)
[INFO] MarketRepository initialized
[INFO] === Repository Layer Initialized Successfully ===
```

### **Check Price Updates**
```dart
[MARKET] BTC: $45000.00 (2.5%)
[MARKET] AAPL FRESH: $175.5000 (regular, 5s old)
```

### **Check Cache**
```dart
[DEBUG] Cache hit for BTC (age: 3s)
[DEBUG] Cache miss for AAPL
[DEBUG] Cache cleanup: 25 entries remaining
```

### **Check Network**
```dart
[NETWORK] Fetching Binance prices for 8 symbols
[NETWORK] Binance fetched 8 prices
[NETWORK] Fetching Yahoo prices for 8 symbols
[NETWORK] Yahoo fetched 8 quotes
```

---

**Happy Coding! 🚀**
