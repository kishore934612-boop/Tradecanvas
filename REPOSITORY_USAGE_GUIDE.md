# Repository Layer - Usage Guide

## Quick Start

The new repository layer is now available for fetching market data. Here's how to use it in your code.

---

## 🚀 Basic Usage

### 1. **Import Required Files**

```dart
import 'package:app/core/di/service_locator.dart';
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/domain/entities/result.dart';
```

### 2. **Get Repository Instance**

```dart
final repository = serviceLocator<MarketRepository>();
```

---

## 📊 Fetch Current Prices

### **Single Symbol**

```dart
// Fetch single price
final result = await repository.getCurrentPrice('BTC');

if (result.isSuccess) {
  final priceData = result.data!;
  print('BTC: \$${priceData.price}');
  print('Change: ${priceData.change}%');
  print('Source: ${priceData.source}');
  print('Age: ${priceData.ageInSeconds}s');
} else {
  print('Error: ${result.error}');
}
```

### **Multiple Symbols**

```dart
// Fetch multiple prices concurrently
final symbols = ['BTC', 'ETH', 'AAPL', 'TSLA', 'EUR/USD'];
final result = await repository.getPrices(symbols);

if (result.isSuccess) {
  final prices = result.data!;
  for (final entry in prices.entries) {
    print('${entry.key}: \$${entry.value.price}');
  }
  print('Fetched ${prices.length}/${symbols.length} prices');
}
```

### **Supported Symbols**

#### **Crypto (Binance)**
- BTC, ETH, SOL, BNB, XRP, DOGE, ADA, AVAX

#### **US Stocks (Yahoo)**
- AAPL, NVDA, TSLA

#### **Indian Stocks (Yahoo)**
- TCS, RELIANCE, HDFCBANK

#### **Forex (Yahoo)**
- GBP/USD, EUR/USD, USD/JPY, USD/CAD, AUD/USD

---

## 📈 Fetch Historical Candles

### **Basic OHLC Data**

```dart
// Fetch daily candles for Apple stock
final result = await repository.getHistoricalCandles(
  'AAPL',
  '1d',
  limit: 200,
);

if (result.isSuccess) {
  final candles = result.data!;
  print('Fetched ${candles.length} candles');
  
  for (final candle in candles) {
    print('Date: ${DateTime.fromMillisecondsSinceEpoch(candle.timestamp)}');
    print('O: ${candle.open}, H: ${candle.high}, L: ${candle.low}, C: ${candle.close}');
    print('Volume: ${candle.volume}');
  }
}
```

### **Different Timeframes**

```dart
// 1-minute candles
await repository.getHistoricalCandles('BTC', '1m', limit: 100);

// 5-minute candles
await repository.getHistoricalCandles('BTC', '5m', limit: 200);

// 15-minute candles
await repository.getHistoricalCandles('ETH', '15m', limit: 150);

// 1-hour candles
await repository.getHistoricalCandles('AAPL', '1h', limit: 168);

// Daily candles
await repository.getHistoricalCandles('TSLA', '1d', limit: 365);

// Weekly candles
await repository.getHistoricalCandles('BTC', '1w', limit: 52);
```

---

## 🔴 Real-Time Price Updates

### **Subscribe to Single Symbol**

```dart
// Subscribe to Bitcoin price updates
final subscription = repository.subscribeToPriceUpdates('BTC').listen(
  (update) {
    print('BTC: \$${update.price} (${update.change}%)');
    print('Source: ${update.source}');
  },
  onError: (error) {
    print('Stream error: $error');
  },
);

// Don't forget to cancel when done
// subscription.cancel();
```

### **Subscribe to Multiple Symbols**

```dart
// Subscribe to multiple crypto prices
final symbols = ['BTC', 'ETH', 'SOL', 'BNB'];
final subscription = repository.subscribeToMultiplePrices(symbols).listen(
  (update) {
    print('${update.symbol}: \$${update.price}');
  },
);

// Cancel when widget disposed
@override
void dispose() {
  subscription.cancel();
  super.dispose();
}
```

### **Integration with Provider**

```dart
class MyPriceWidget extends StatefulWidget {
  final String symbol;
  
  const MyPriceWidget({required this.symbol});
  
  @override
  State<MyPriceWidget> createState() => _MyPriceWidgetState();
}

class _MyPriceWidgetState extends State<MyPriceWidget> {
  final repository = serviceLocator<MarketRepository>();
  StreamSubscription? _subscription;
  double _currentPrice = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadInitialPrice();
    _subscribeToUpdates();
  }
  
  Future<void> _loadInitialPrice() async {
    final result = await repository.getCurrentPrice(widget.symbol);
    if (result.isSuccess && mounted) {
      setState(() {
        _currentPrice = result.data!.price;
      });
    }
  }
  
  void _subscribeToUpdates() {
    _subscription = repository.subscribeToPriceUpdates(widget.symbol).listen(
      (update) {
        if (mounted) {
          setState(() {
            _currentPrice = update.price;
          });
        }
      },
    );
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Text('\$${_currentPrice.toStringAsFixed(2)}');
  }
}
```

---

## 🕐 Check Market Status

### **Market Hours Detection**

```dart
// Check if market is open
final isLive = repository.isMarketLive('AAPL');
print('AAPL market is ${isLive ? "OPEN" : "CLOSED"}');

// Get detailed status
final status = repository.getMarketStatus('AAPL');
print('Status: ${status.label}'); // OPEN, CLOSED, PRE-MARKET, AFTER HOURS

// Check for different markets
print('BTC: ${repository.getMarketStatus('BTC').label}'); // Always OPEN
print('TCS: ${repository.getMarketStatus('TCS').label}'); // Indian market hours
print('EUR/USD: ${repository.getMarketStatus('EUR/USD').label}'); // Forex 24/5
```

### **Conditional Updates Based on Market Status**

```dart
Future<void> fetchPriceIfMarketOpen(String symbol) async {
  if (!repository.isMarketLive(symbol)) {
    print('$symbol market is closed, using cached data');
    final cached = repository.getCachedPrice(symbol);
    if (cached != null) {
      print('Cached price: \$${cached.price} (${cached.ageInSeconds}s old)');
    }
    return;
  }
  
  // Market is open, fetch fresh data
  final result = await repository.getCurrentPrice(symbol);
  if (result.isSuccess) {
    print('Fresh price: \$${result.data!.price}');
  }
}
```

---

## 💾 Cache Management

### **Get Cached Data (Synchronous)**

```dart
// Get cached price without network call
final cachedPrice = repository.getCachedPrice('BTC');
if (cachedPrice != null) {
  print('Cached BTC: \$${cachedPrice.price}');
  print('Is stale: ${cachedPrice.isStale}');
  print('Age: ${cachedPrice.ageInSeconds} seconds');
} else {
  print('No cached data for BTC');
}
```

### **Clear Cache**

```dart
// Clear cache for specific symbol
repository.clearCache('BTC');

// Clear all cached data
repository.clearAllCache();
```

---

## 📡 Event Bus Integration

### **Listen to Price Update Events**

```dart
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/market_events.dart';

final eventBus = serviceLocator<EventBus>();

// Subscribe to price update events
final subscription = eventBus.on<PriceUpdatedEvent>().listen((event) {
  print('${event.symbol} updated: \$${event.price}');
  print('Change: ${event.change}%');
  print('Source: ${event.source}');
});

// Don't forget to cancel
subscription.cancel();
```

### **Listen to Market Connection Events**

```dart
eventBus.on<MarketConnectionEvent>().listen((event) {
  print('${event.provider}: ${event.connected ? "CONNECTED" : "DISCONNECTED"}');
  if (event.error != null) {
    print('Error: ${event.error}');
  }
});
```

---

## 🔧 Advanced Usage

### **Custom TTL for Cache**

```dart
import 'package:app/core/di/service_locator.dart';
import 'package:app/data/cache/cache_manager.dart';

final cache = serviceLocator<CacheManager>();

// Set price with custom TTL (10 seconds)
cache.setPrice('BTC', priceData, ttl: 10000);

// Set candles with custom TTL (1 minute)
cache.setCandles('AAPL', '1d', candles, ttl: 60000);
```

### **Cache Statistics**

```dart
final stats = cache.getStats();
print('Cached prices: ${stats["prices"]}');
print('Cached candles: ${stats["candles"]}');
print('Total entries: ${stats["total"]}');

// Cleanup expired entries
cache.cleanup();
```

### **Logging**

```dart
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';

final logger = serviceLocator<Logger>();

logger.info('Fetching prices...');
logger.warning('Cache miss for BTC');
logger.error('Failed to fetch price: timeout');
logger.debug('Cache size: 50 entries');
logger.market('BTC: \$45000.00');
logger.network('GET /api/prices - 200 OK');
```

---

## ✅ Best Practices

### **1. Always Handle Errors**

```dart
final result = await repository.getCurrentPrice('INVALID');
if (result.isSuccess) {
  // Use data
  final price = result.data!;
} else {
  // Handle error
  print('Error: ${result.error}');
  // Show user-friendly message
  // Fall back to cached data
}
```

### **2. Cancel Subscriptions**

```dart
StreamSubscription? _subscription;

void subscribe() {
  _subscription = repository.subscribeToPriceUpdates('BTC').listen(...);
}

@override
void dispose() {
  _subscription?.cancel(); // Always cancel!
  super.dispose();
}
```

### **3. Use Cache When Appropriate**

```dart
// For UI that doesn't need real-time updates
final cached = repository.getCachedPrice('BTC');
if (cached != null && !cached.isStale) {
  // Use cached data (instant, no network)
  return cached;
}

// Only fetch if cache miss or stale
final result = await repository.getCurrentPrice('BTC');
```

### **4. Batch Requests**

```dart
// ❌ BAD: Multiple individual requests
for (final symbol in symbols) {
  await repository.getCurrentPrice(symbol);
}

// ✅ GOOD: Single batch request
final result = await repository.getPrices(symbols);
```

### **5. Check Market Status Before Polling**

```dart
void startPriceUpdates() {
  Timer.periodic(Duration(seconds: 5), (timer) {
    if (repository.isMarketLive('AAPL')) {
      // Market open, fetch fresh data
      repository.getCurrentPrice('AAPL');
    } else {
      // Market closed, use cached data
      // No need to poll
    }
  });
}
```

---

## 🐛 Troubleshooting

### **No WebSocket Updates on Web**

WebSocket is disabled on web due to CORS. Only REST polling works.

**Solution:** WebSocket works on mobile. On web, use REST API with polling.

### **Stale Prices**

Cached prices have a 5-second TTL. Check if data is stale:

```dart
final cached = repository.getCachedPrice('BTC');
if (cached != null && cached.isStale) {
  print('Cached price is stale, fetching fresh...');
  await repository.getCurrentPrice('BTC');
}
```

### **Provider Not Found Error**

```dart
// ❌ Error: No provider available for symbol: UNKNOWN
await repository.getCurrentPrice('UNKNOWN');

// ✅ Check supported symbols first
final binance = serviceLocator<BinanceProvider>();
final yahoo = serviceLocator<YahooProvider>();
print('Binance supports: ${binance.getSupportedSymbols()}');
print('Yahoo supports: ${yahoo.getSupportedSymbols()}');
```

---

## 📚 Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/domain/repositories/market_repository.dart';

class PriceMonitor extends StatefulWidget {
  @override
  State<PriceMonitor> createState() => _PriceMonitorState();
}

class _PriceMonitorState extends State<PriceMonitor> {
  final repository = serviceLocator<MarketRepository>();
  final symbols = ['BTC', 'ETH', 'AAPL', 'TSLA'];
  
  Map<String, double> prices = {};
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _loadPrices();
    _subscribeToUpdates();
  }
  
  Future<void> _loadPrices() async {
    final result = await repository.getPrices(symbols);
    if (result.isSuccess && mounted) {
      setState(() {
        prices = result.data!.map(
          (key, value) => MapEntry(key, value.price),
        );
      });
    }
  }
  
  void _subscribeToUpdates() {
    _subscription = repository.subscribeToMultiplePrices(symbols).listen(
      (update) {
        if (mounted) {
          setState(() {
            prices[update.symbol] = update.price;
          });
        }
      },
    );
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: symbols.length,
      itemBuilder: (context, index) {
        final symbol = symbols[index];
        final price = prices[symbol] ?? 0.0;
        final isLive = repository.isMarketLive(symbol);
        
        return ListTile(
          title: Text(symbol),
          subtitle: Text(isLive ? 'LIVE' : 'CLOSED'),
          trailing: Text('\$${price.toStringAsFixed(2)}'),
        );
      },
    );
  }
}
```

---

## 🎓 Summary

The repository layer provides:

✅ **Unified API** for all market data  
✅ **Automatic caching** with TTL  
✅ **Real-time updates** via WebSocket (mobile)  
✅ **Multi-provider** support (Binance + Yahoo)  
✅ **Market hours** detection  
✅ **Event-driven** architecture  
✅ **Error handling** with Result type  
✅ **Easy testing** and mocking  

Use `serviceLocator<MarketRepository>()` to access it anywhere in your app!
