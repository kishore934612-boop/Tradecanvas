# Phase 4: Split TradingProvider into Controllers - Specification

## 📋 Overview

**Goal:** Split the monolithic TradingProvider (1000+ LOC) into specialized controllers following Single Responsibility Principle.

**Approach:** Strangler Fig Pattern - Create controllers alongside TradingProvider, gradually migrate logic, maintain backward compatibility.

**Duration:** 8-10 hours  
**Priority:** HIGH  
**Risk Level:** MEDIUM (larger refactor, but incremental)

---

## 🎯 Objectives

### **Primary Goals**
1. ✅ Reduce TradingProvider complexity
2. ✅ Improve testability (isolated controllers)
3. ✅ Better separation of concerns
4. ✅ Easier to maintain and extend
5. ✅ Maintain 100% backward compatibility

### **Success Criteria**
- [ ] TradingProvider < 300 LOC (from 1000+)
- [ ] 6-7 specialized controllers created
- [ ] All existing features work
- [ ] No breaking changes to UI
- [ ] Each controller < 200 LOC
- [ ] EventBus used for communication

---

## 📊 Current State Analysis

### **TradingProvider Responsibilities (Too Many!)**

Analyzed the current code and identified these responsibilities:

1. **Portfolio Management** (~200 LOC)
   - Balance, equity, margin
   - Buying power
   - P&L calculations (realized, unrealized)
   - Daily P&L tracking

2. **Position Management** (~250 LOC)
   - Open/close positions
   - Position tracking
   - Position risk updates (SL/TP/trailing)
   - Position lifecycle

3. **Order Management** (~150 LOC)
   - Pending orders (limit, stop)
   - Order execution
   - Order cancellation
   - Order validation

4. **Market Data** (~200 LOC)
   - Price fetching (now delegated to repository ✅)
   - Price subscriptions
   - Market status
   - News generation

5. **Journal Management** (~80 LOC)
   - Trade notes
   - Exit journals
   - Reflections

6. **Gamification** (~120 LOC)
   - Achievements tracking
   - Challenge progress
   - Unlocks
   - Stats

7. **Risk Management** (~150 LOC)
   - Stop loss/take profit triggers
   - Trailing stops
   - Liquidation checks
   - Order fills

8. **State Persistence** (~100 LOC)
   - Save/load from SharedPreferences
   - State serialization

**Total:** ~1250 LOC

---

## 🏗️ Target Architecture

### **New Structure**

```
TradingProvider (Facade ~200 LOC)
  ├─ PortfolioController (~150 LOC)
  ├─ PositionController (~200 LOC)
  ├─ OrderController (~150 LOC)
  ├─ JournalController (~80 LOC)
  ├─ GamificationController (~120 LOC)
  └─ RiskManagementEngine (~150 LOC)

MarketDataController is MarketRepository (Phase 2 ✅)
```

### **Communication**

```
EventBus (Central)
  ↓
  ├─ TradeOpenedEvent
  ├─ TradeClosedEvent
  ├─ PositionUpdatedEvent
  ├─ OrderFilledEvent
  ├─ AchievementUnlockedEvent
  └─ BalanceChangedEvent
  
Controllers subscribe/emit independently
```

---

## 📝 Detailed Controller Design

### **1. PortfolioController**

**Responsibilities:**
- Track account balance
- Calculate equity (balance + margin + unrealized P&L)
- Calculate buying power
- Track realized P&L
- Track daily P&L
- Provide portfolio statistics

**Public API:**
```dart
class PortfolioController {
  double get balance;
  double get equity;
  double get realizedPnl;
  double get unrealizedPnl;
  double get freeMargin;
  double get usedMargin;
  double get marginLevel;
  double get dailyPnl;
  double get totalReturnPct;
  
  void deposit(double amount);
  void withdraw(double amount);
  void recordRealized(double pnl);
  void updateDailyRealized(double pnl);
}
```

**Events Emitted:**
- `BalanceChangedEvent`
- `EquityChangedEvent`

**Events Subscribed:**
- `TradeClosedEvent` (to update realized P&L)
- `PositionUpdatedEvent` (to recalculate unrealized P&L)

---

### **2. PositionController**

**Responsibilities:**
- Manage open positions
- Track position lifecycle
- Calculate position P&L
- Update position risk parameters
- Provide position queries

**Public API:**
```dart
class PositionController {
  List<Position> get openPositions;
  List<Position> get closedPositions;
  
  Position? getPosition(String positionId);
  List<Position> getPositionsBySymbol(String symbol);
  
  Result<Position> openPosition({
    required String symbol,
    required PositionSide side,
    required double qty,
    // ...
  });
  
  Result<void> closePosition(String positionId, {double fraction = 1.0});
  
  void updateRisk(String positionId, {
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
  });
  
  double getUnrealizedPnl();
  double getUsedMargin();
}
```

**Events Emitted:**
- `PositionOpenedEvent`
- `PositionClosedEvent`
- `PositionUpdatedEvent`

**Events Subscribed:**
- `PriceUpdatedEvent` (to recalculate P&L)
- `OrderFilledEvent` (to open position)

---

### **3. OrderController**

**Responsibilities:**
- Manage pending orders
- Validate orders
- Execute orders when triggered
- Cancel orders

**Public API:**
```dart
class OrderController {
  List<PendingOrder> get pendingOrders;
  
  Result<PendingOrder> placeLimitOrder({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double limitPrice,
    // ...
  });
  
  Result<PendingOrder> placeStopOrder({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double stopPrice,
    // ...
  });
  
  void cancelOrder(String orderId);
  void checkOrderTriggers(String symbol, double currentPrice);
}
```

**Events Emitted:**
- `OrderPlacedEvent`
- `OrderFilledEvent`
- `OrderCancelledEvent`

**Events Subscribed:**
- `PriceUpdatedEvent` (to check triggers)

---

### **4. JournalController**

**Responsibilities:**
- Store trading journal entries
- Attach notes to trades
- Track reflections
- Provide journal queries

**Public API:**
```dart
class JournalController {
  List<Trade> get trades;
  
  void attachExitJournal(String tradeId, ExitJournal journal);
  void updateTradeNotes(String tradeId, String notes);
  Trade? getTrade(String tradeId);
  List<Trade> getTradesBySymbol(String symbol);
  List<Trade> getTradesInDateRange(DateTime start, DateTime end);
}
```

**Events Emitted:**
- `JournalUpdatedEvent`

**Events Subscribed:**
- `TradeClosedEvent` (to create journal entry)

---

### **5. GamificationController**

**Responsibilities:**
- Track achievements
- Track challenges
- Monitor progress
- Unlock rewards
- Calculate statistics

**Public API:**
```dart
class GamificationController {
  Set<String> get unlockedAchievements;
  Set<String> get completedChallenges;
  List<String> get recentUnlocks;
  
  bool isAchievementUnlocked(String id);
  bool isChallengeComplete(String id);
  
  void evaluateAchievements();
  void evaluateChallenges();
  
  TradingStats getStats();
}
```

**Events Emitted:**
- `AchievementUnlockedEvent`
- `ChallengeCompletedEvent`

**Events Subscribed:**
- `TradeClosedEvent` (to check achievements)
- `PositionOpenedEvent` (to track stats)

---

### **6. RiskManagementEngine**

**Responsibilities:**
- Evaluate stop loss triggers
- Evaluate take profit triggers
- Check trailing stops
- Check liquidation risk
- Trigger automatic closures

**Public API:**
```dart
class RiskManagementEngine {
  void checkRiskTriggers(List<Position> positions, Map<String, double> currentPrices);
  
  bool shouldLiquidate(Position position, double currentPrice);
  bool shouldStopLoss(Position position, double currentPrice);
  bool shouldTakeProfit(Position position, double currentPrice);
  bool shouldTrailingStop(Position position, double currentPrice);
  
  double calculateLiquidationPrice(Position position);
  double calculateRequiredMargin(Position position);
}
```

**Events Emitted:**
- `PositionLiquidatedEvent`
- `StopLossTriggeredEvent`
- `TakeProfitTriggeredEvent`

**Events Subscribed:**
- `PriceUpdatedEvent` (to check all triggers)

---

## 🔄 Migration Strategy

### **Phase 4 will be broken into 6 sub-tasks:**

#### **Task 4.1: Create Controller Interfaces** (1 hour)
- Define all controller interfaces
- Define events
- Setup folder structure: `lib/controllers/`

#### **Task 4.2: Portfolio Controller** (1.5 hours)
- Extract portfolio logic from TradingProvider
- Implement PortfolioController
- Wire up events
- Test portfolio calculations

#### **Task 4.3: Position Controller** (2 hours)
- Extract position logic
- Implement PositionController
- Wire up events
- Test position lifecycle

#### **Task 4.4: Order Controller** (1.5 hours)
- Extract order logic
- Implement OrderController
- Wire up events
- Test order execution

#### **Task 4.5: Journal & Gamification Controllers** (1.5 hours)
- Extract journal logic → JournalController
- Extract gamification logic → GamificationController
- Wire up events
- Test tracking

#### **Task 4.6: Risk Management Engine** (1.5 hours)
- Extract risk logic
- Implement RiskManagementEngine
- Wire up event subscriptions
- Test triggers

#### **Task 4.7: Refactor TradingProvider as Facade** (1 hour)
- Keep TradingProvider as thin facade
- Delegate to controllers
- Maintain backward compatibility
- Update main.dart

**Total:** 10 hours

---

## 🎯 Success Checklist

### **Architecture**
- [ ] 6 controllers created
- [ ] EventBus communication working
- [ ] TradingProvider < 300 LOC
- [ ] Each controller < 200 LOC
- [ ] Clear separation of concerns

### **Functionality**
- [ ] All portfolio calculations correct
- [ ] All positions work (open/close)
- [ ] All orders work (place/cancel)
- [ ] Journal entries save
- [ ] Achievements unlock
- [ ] Risk triggers fire

### **Backward Compatibility**
- [ ] All existing UI components work
- [ ] No breaking API changes
- [ ] All screens render correctly
- [ ] Trading still functional
- [ ] State persistence works

### **Code Quality**
- [ ] No compilation errors
- [ ] Structured logging in controllers
- [ ] Events properly typed
- [ ] Controllers are testable
- [ ] Documentation complete

---

## 📂 New File Structure

```
lib/
├── controllers/                    # NEW
│   ├── portfolio_controller.dart
│   ├── position_controller.dart
│   ├── order_controller.dart
│   ├── journal_controller.dart
│   ├── gamification_controller.dart
│   └── risk_management_engine.dart
│
├── core/
│   ├── events/
│   │   ├── trade_events.dart      # Expand with new events
│   │   ├── portfolio_events.dart  # Expand
│   │   └── gamification_events.dart # NEW
│
├── providers/
│   └── trading_provider.dart      # REFACTOR to facade (~200 LOC)
│
└── ... (existing structure)
```

---

## ⚠️ Risk Mitigation

### **Risks**
1. **Breaking existing functionality** - High impact
2. **Complex dependencies between controllers** - Medium
3. **State synchronization issues** - Medium
4. **Event ordering problems** - Low

### **Mitigation**
1. **Incremental migration** - One controller at a time
2. **Keep TradingProvider facade** - Backward compatibility
3. **Extensive logging** - Track state changes
4. **Event replay testing** - Verify order
5. **Rollback plan** - Git branches for each controller

---

## 🧪 Testing Strategy

### **Per Controller**
1. Unit tests for calculations
2. Integration tests with events
3. Manual testing of features

### **End-to-End**
1. Open/close positions
2. Place/cancel orders
3. Check journal entries
4. Verify achievements
5. Test risk triggers

### **Regression**
1. All existing screens
2. All existing features
3. State persistence
4. Performance (no degradation)

---

## 📚 Documentation

### **To Create**
- [ ] Controller API documentation
- [ ] Event flow diagrams
- [ ] Migration guide
- [ ] Testing guide
- [ ] Rollback procedure

---

## 🚀 Next Steps

1. **Start with Task 4.1** - Create controller interfaces
2. **Implement one controller at a time** - Test thoroughly
3. **Wire up events** - Use EventBus for communication
4. **Refactor TradingProvider** - Thin facade
5. **Test end-to-end** - All features work
6. **Document** - Complete Phase 4 documentation

---

**Status:** 📝 SPECIFICATION COMPLETE  
**Ready For:** Implementation via incremental tasks  
**Estimated Duration:** 10 hours  
**Approach:** Create controllers → Wire events → Refactor facade → Test

Would you like to proceed with Task 4.1 (Create Controller Interfaces)?
