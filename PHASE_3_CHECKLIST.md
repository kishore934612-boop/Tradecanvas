# Phase 3: TradingProvider Integration - Checklist

## 📋 Overview
Gradually migrate TradingProvider to use the new MarketRepository while maintaining full backward compatibility.

---

## ✅ Pre-Integration Tasks

- [x] Phase 1 complete (infrastructure)
- [x] Phase 2 complete (repository layer)
- [x] All services initialized in main.dart
- [x] No compilation errors
- [x] Documentation complete
- [ ] Backup current working code
- [ ] Create feature branch: `feature/phase-3-integration`

---

## 🔧 Step 1: Add Repository Dependency to TradingProvider

### **File:** `lib/providers/trading_provider.dart`

### **Tasks:**
- [ ] Import repository and service locator
  ```dart
  import 'package:app/core/di/service_locator.dart';
  import 'package:app/domain/repositories/market_repository.dart';
  ```

- [ ] Add repository field to TradingProvider
  ```dart
  final MarketRepository? _marketRepository;
  ```

- [ ] Update constructor
  ```dart
  TradingProvider({MarketRepository? marketRepository})
      : _marketRepository = marketRepository {
    _loadState();
    _connectCryptoWs();
    _startSimulation();
  }
  ```

- [ ] Update main.dart provider creation
  ```dart
  ChangeNotifierProvider(
    create: (_) => TradingProvider(
      marketRepository: serviceLocator<MarketRepository>(),
    ),
  ),
  ```

- [ ] Test app still runs correctly
- [ ] Verify no errors in console

---

## 🔄 Step 2: Subscribe to Repository Price Updates

### **File:** `lib/providers/trading_provider.dart`

### **Tasks:**
- [ ] Add subscription field
  ```dart
  StreamSubscription? _repositorySubscription;
  ```

- [ ] Create subscription method
  ```dart
  void _subscribeToRepositoryUpdates() {
    if (_marketRepository == null) return;
    
    final allSymbols = [...]; // All tracked symbols
    
    _repositorySubscription = _marketRepository!
        .subscribeToMultiplePrices(allSymbols)
        .listen((update) {
      _prices ??= {};
      _prices![update.symbol] = update.price;
      _priceChanges![update.symbol] = update.change;
      _lastUpdateTime[update.symbol] = DateTime.now().millisecondsSinceEpoch;
      _lastDataSource[update.symbol] = update.source;
      notifyListeners();
    });
  }
  ```

- [ ] Call in constructor after existing setup
- [ ] Cancel subscription in dispose
  ```dart
  @override
  void dispose() {
    _repositorySubscription?.cancel();
    // ... existing disposal code
  }
  ```

- [ ] Test prices still update in UI
- [ ] Verify WebSocket updates work (mobile)
- [ ] Check console for price update logs

---

## 📊 Step 3: Delegate Price Fetching to Repository

### **File:** `lib/providers/trading_provider.dart`

### **Tasks:**
- [ ] Create new method `_fetchPricesFromRepository()`
  ```dart
  Future<void> _fetchPricesFromRepository() async {
    if (_marketRepository == null) {
      // Fallback to old implementation
      await _fetchBinancePrices();
      await _fetchYahooPrices();
      return;
    }
    
    try {
      final allSymbols = [...]; // All symbols
      final result = await _marketRepository!.getPrices(allSymbols);
      
      if (result.isSuccess) {
        for (final entry in result.data!.entries) {
          _prices![entry.key] = entry.value.price;
          _priceChanges![entry.key] = entry.value.change;
          _lastUpdateTime[entry.key] = entry.value.timestamp;
          _lastDataSource[entry.key] = entry.value.source;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TradingProvider] Repository fetch failed: $e');
      // Fallback to old implementation
      await _fetchBinancePrices();
      await _fetchYahooPrices();
    }
  }
  ```

- [ ] Replace calls to `_fetchBinancePrices()` and `_fetchYahooPrices()` with `_fetchPricesFromRepository()`
- [ ] Comment out old methods (don't delete yet)
  ```dart
  // OLD IMPLEMENTATION - Kept for rollback
  // Future<Map<String, List<double>>> _fetchBinancePrices() async {
  //   ...
  // }
  ```

- [ ] Test all symbols fetch correctly
- [ ] Test cache is working (check logs)
- [ ] Test fallback works if repository fails
- [ ] Verify no performance regression

---

## 📈 Step 4: Update Chart to Use Repository

### **File:** `lib/components/candlestick_chart.dart`

### **Tasks:**
- [ ] Import repository and service locator
- [ ] Create method `_fetchCandlesFromRepository()`
  ```dart
  Future<List<CandleData>> _fetchCandlesFromRepository(
    String symbol,
    String timeframe,
  ) async {
    try {
      final repository = serviceLocator<MarketRepository>();
      final result = await repository.getHistoricalCandles(
        symbol,
        timeframe,
        limit: 200,
      );
      
      if (result.isSuccess) {
        return result.data!;
      }
    } catch (e) {
      debugPrint('[Chart] Repository fetch failed: $e');
    }
    
    // Fallback to old implementation
    return _fetchYahooOhlc(symbol, timeframe);
  }
  ```

- [ ] Replace `_fetchYahooOhlc()` calls with `_fetchCandlesFromRepository()`
- [ ] Comment out old method (don't delete)
- [ ] Test charts render correctly
- [ ] Test all timeframes (1m, 5m, 15m, 1h, 1d, 1w)
- [ ] Test all symbols (crypto, stocks, forex)
- [ ] Verify candle data quality

---

## 🕐 Step 5: Use Market Status for Intelligent Polling

### **File:** `lib/providers/trading_provider.dart`

### **Tasks:**
- [ ] Update `_startSimulation()` method
  ```dart
  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _tickCount++;
      
      // Use repository for market status
      final hasOpenMarkets = _positions.any((pos) {
        return _marketRepository?.isMarketLive(pos.symbol) ?? true;
      });
      
      // Only fetch if markets are open or every 10 ticks when closed
      if (hasOpenMarkets || _tickCount % 10 == 0) {
        await _fetchPricesFromRepository();
      }
      
      // Rest of simulation logic...
    });
  }
  ```

- [ ] Test polling stops when all markets closed
- [ ] Test polling resumes when markets open
- [ ] Verify CPU usage drops when markets closed
- [ ] Check logs show intelligent polling

---

## 🧪 Step 6: Testing & Validation

### **Functional Testing**
- [ ] All prices update correctly
- [ ] Real-time WebSocket works (mobile)
- [ ] REST polling works (web)
- [ ] Charts display correctly
- [ ] All timeframes work
- [ ] Market status detection accurate
- [ ] Trading functionality intact
- [ ] Portfolio calculations correct
- [ ] Journal entries work
- [ ] Challenges/achievements work
- [ ] Settings persist

### **Performance Testing**
- [ ] No visible lag in UI
- [ ] Price updates are smooth
- [ ] Charts render quickly
- [ ] Cache hit rate > 80% (check logs)
- [ ] Network calls reduced
- [ ] Memory usage stable
- [ ] CPU usage acceptable

### **Error Handling**
- [ ] Fallback works when repository unavailable
- [ ] Graceful degradation on network errors
- [ ] Stale data handled correctly
- [ ] WebSocket reconnection works
- [ ] CORS proxy fallback works (web)

### **Edge Cases**
- [ ] App launch with no network
- [ ] Network interrupted mid-fetch
- [ ] Provider returns empty data
- [ ] Invalid symbols handled
- [ ] Market transition (open → closed)
- [ ] Weekend behavior correct

---

## 🧹 Step 7: Cleanup & Optimization

### **Code Cleanup**
- [ ] Remove commented old methods once confident
  - `_fetchBinancePrices()`
  - `_fetchYahooPrices()`
  - `_connectCryptoWs()`
  - `_fetchYahooOhlc()` (from chart)

- [ ] Remove unused imports
- [ ] Remove unused fields
- [ ] Update comments to reflect new architecture

### **Optimization**
- [ ] Reduce polling frequency during closed markets
- [ ] Increase cache TTL for closed markets
- [ ] Batch multiple concurrent requests
- [ ] Deduplicate redundant fetches

---

## 📝 Step 8: Documentation Updates

- [ ] Update `COMPLETE_ARCHITECTURE.md` with new data flow
- [ ] Update architecture diagrams
- [ ] Document migration in `PHASE_3_COMPLETE.md`
- [ ] Update README with new architecture
- [ ] Add inline code comments
- [ ] Update API documentation

---

## 🚀 Step 9: Deployment Preparation

### **Pre-Deployment**
- [ ] All tests passing
- [ ] No console errors
- [ ] No performance regressions
- [ ] Code review complete
- [ ] Documentation updated

### **Feature Flag (Optional)**
- [ ] Add environment variable `USE_REPOSITORY_LAYER`
- [ ] Allow runtime toggle for rollback
- [ ] Log which path is active

### **Monitoring**
- [ ] Add analytics events for repository usage
- [ ] Track cache hit rate
- [ ] Monitor API call frequency
- [ ] Track error rates by provider

---

## 🔄 Step 10: Rollback Plan

### **If Issues Found:**

1. **Immediate Rollback** (< 5 minutes)
   ```dart
   // In TradingProvider constructor:
   TradingProvider({MarketRepository? marketRepository})
       : _marketRepository = null {  // Force null to disable
     // ...
   }
   ```

2. **Revert Feature Flag** (< 1 minute)
   ```dart
   const USE_REPOSITORY = false;  // Disable new path
   ```

3. **Revert Git Commit** (< 2 minutes)
   ```bash
   git revert HEAD
   git push
   ```

4. **Uncomment Old Code** (< 10 minutes)
   - Restore `_fetchBinancePrices()`
   - Restore `_fetchYahooPrices()`
   - Restore direct API calls

---

## 📊 Success Criteria

### **Must Have (Blocking)**
- ✅ All existing features work
- ✅ No visual changes to UI
- ✅ No performance regression
- ✅ No new errors in console
- ✅ Tests pass

### **Should Have (Important)**
- ✅ Cache hit rate > 80%
- ✅ Network calls reduced by 50%
- ✅ Market status detection works
- ✅ WebSocket updates work (mobile)
- ✅ Fallback path works

### **Nice to Have (Optional)**
- ✅ Reduced polling when markets closed
- ✅ Better error messages
- ✅ Improved logging
- ✅ Performance metrics

---

## ⏱️ Time Estimates

| Step | Estimated Time | Complexity |
|------|----------------|------------|
| Step 1: Add dependency | 30 min | Low |
| Step 2: Subscribe to updates | 1 hour | Medium |
| Step 3: Delegate fetching | 1 hour | Medium |
| Step 4: Update charts | 1 hour | Medium |
| Step 5: Market status | 30 min | Low |
| Step 6: Testing | 2 hours | High |
| Step 7: Cleanup | 30 min | Low |
| Step 8: Documentation | 1 hour | Low |
| **Total** | **7.5 hours** | **Medium** |

---

## 🎯 Next Phase Preview

### **Phase 4: Split TradingProvider into Controllers**

After Phase 3 is complete and stable, we'll refactor TradingProvider into specialized controllers:

- PortfolioController
- PositionController
- OrderController
- JournalController
- ChallengeController

This will further reduce complexity and improve maintainability.

---

## 📞 Support

### **If You Get Stuck:**

1. **Check logs**: Look for error messages in console
2. **Test fallback**: Ensure old code path still works
3. **Review docs**: Check `REPOSITORY_USAGE_GUIDE.md`
4. **Test incrementally**: Don't change everything at once
5. **Use git**: Commit after each working step

### **Common Issues:**

| Issue | Solution |
|-------|----------|
| "No provider for symbol" | Check symbol is in provider's supported list |
| "WebSocket not connecting" | Check if on web (WebSocket disabled on web) |
| "Stale prices" | Check cache TTL, verify market is open |
| "Charts not loading" | Check candle fetch logs, verify OHLC data |
| "Performance slow" | Check for excessive polling, verify caching |

---

## ✅ Final Checklist

Before marking Phase 3 complete:

- [ ] All 10 steps completed
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Performance validated
- [ ] Rollback plan tested
- [ ] Team notified
- [ ] Deployment ready

---

**Good luck with Phase 3! 🚀**

Take your time, test thoroughly, and remember: **backward compatibility is the top priority**.
