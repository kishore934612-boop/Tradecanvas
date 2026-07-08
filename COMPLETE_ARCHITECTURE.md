# TradeVerse - Complete Architecture Documentation

## 📋 Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Architecture Layers](#architecture-layers)
4. [Technology Stack](#technology-stack)
5. [Project Structure](#project-structure)
6. [Data Flow](#data-flow)
7. [State Management](#state-management)
8. [External Integrations](#external-integrations)
9. [Feature Modules](#feature-modules)
10. [Design Patterns](#design-patterns)

---

## Executive Summary

**TradeVerse** is a **paper trading simulator** built with Flutter that enables users to practice trading crypto, stocks, and forex without risking real money.

### Key Characteristics
- **Type**: Single-page application (SPA) with tab-based navigation
- **Platform**: Cross-platform (iOS, Android, Web)
- **Architecture**: Provider-based state management with layered structure
- **Data**: Local persistence + real-time external APIs
- **UI**: Material Design 3 with custom theming

### Core Purpose
Educate users on trading mechanics (leverage, margin, risk management) through gamified experiences with real market data.

---

## System Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  (Screens, Widgets, Components)                             │
│  - 13 Screens                                               │
│  - Reusable UI Components                                   │
│  - Custom Charts (Candlestick, Sparkline, Allocation)      │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Provider (watch/read)
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                  STATE MANAGEMENT LAYER                      │
│  (Provider - ChangeNotifier)                                │
│  - AppState (theme, preferences)                            │
│  - TradingProvider (portfolio, positions, prices)           │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Business Logic
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                   BUSINESS LOGIC LAYER                       │
│  (Models, Utilities, Calculations)                          │
│  - Trading models (Position, Trade, Order)                  │
│  - Market calculations                                       │
│  - Gamification logic                                        │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        │ Save/Load
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                     DATA LAYER                               │
│  (Persistence + External APIs)                              │
│  - SharedPreferences (local storage)                        │
│  - Binance API (crypto prices)                              │
│  - Yahoo Finance API (stocks/forex prices)                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Layers

### 1. Presentation Layer (`lib/screens`, `lib/widgets`, `lib/components`)

**Responsibility:** User interface and user interaction

**Components:**

#### Screens (13)
- `splash_screen.dart` - App initialization
- `onboarding_screen.dart` - First-time user experience
- `main_tabs_screen.dart` - Bottom navigation host
- `portfolio_screen.dart` - Portfolio overview (Dashboard)
- `markets_screen.dart` - Asset list browser
- `trade_screen.dart` - Trading terminal
- `coin_detail_screen.dart` - Asset detail with chart
- `history_screen.dart` - Trade history
- `analytics_screen.dart` - Performance analytics
- `challenges_screen.dart` - Gamification challenges
- `journal_screen.dart` - Trading journal
- `settings_screen.dart` - App settings
- `more_screen.dart` - Additional features
- `trade_detail_screen.dart` - Individual trade details

#### Reusable Components (8)
- `candlestick_chart.dart` - Professional trading chart (1800+ lines)
- `interactive_chart.dart` - Simple price chart
- `sparkline.dart` - Mini price history
- `allocation_chart.dart` - Portfolio pie chart
- `animated_price.dart` - Live price display
- `asset_row.dart` - Asset list item
- `price_stream_builder.dart` - Real-time price widget
- `ui.dart` - Common UI components

#### Widgets (2)
- `position_card.dart` - Position display card
- `journal_dialogs.dart` - Entry/exit journal forms

---


### 2. State Management Layer (`lib/providers`)

**Responsibility:** Application state and business coordination

**Pattern:** Provider (ChangeNotifier)

#### AppState Provider
```dart
class AppState extends ChangeNotifier {
  UserProfile _profile;
  ThemeMode _themeMode;
  int _themeIndex;
  bool _loaded;
}
```

**Manages:**
- User profile (name, experience level, risk tolerance)
- Theme preferences (light/dark/system, color scheme)
- Onboarding status
- App-wide settings

**Persistence:** `@tradeverse_appstate` in SharedPreferences

#### TradingProvider
```dart
class TradingProvider extends ChangeNotifier {
  double _balance;
  List<Position> _positions;
  List<PendingOrder> _orders;
  List<Trade> _trades;
  Map<String, double> _prices;
  // ... 1000+ lines of trading logic
}
```

**Manages:**
- Portfolio (balance, equity, margin, P&L)
- Positions (long/short, leverage, size)
- Orders (pending limit/stop orders)
- Trade history
- Real-time prices (crypto, stocks, forex)
- News articles (simulated)
- Achievements and challenges
- Risk management (stop-loss, take-profit, liquidation)

**Persistence:** `@tradeverse_state_v2` in SharedPreferences

**Real-Time Updates:**
- WebSocket subscription (crypto, mobile only)
- REST API polling (all assets, every 3 seconds)
- Broadcast stream for price updates

---

### 3. Business Logic Layer (`lib/models`, `lib/utils`, `lib/constants`)

**Responsibility:** Core domain logic and calculations

#### Models (`lib/models`)

**Trading Models** (`trading_models.dart`):
```dart
class Position {
  String symbol;
  PositionSide side;  // long/short
  double qty;
  int leverage;
  double entryPrice;
  double? stopLoss;
  double? takeProfit;
  TradingType tradingType;
}

class Trade {
  String symbol;
  PositionSide side;
  double entryPrice;
  double exitPrice;
  double qty;
  int leverage;
  double pnl;
  int entryTimestamp;
  int exitTimestamp;
}

class PendingOrder {
  OrderType type;  // limit/stop
  String symbol;
  double triggerPrice;
  PositionSide side;
  double qty;
}
```

**Gamification** (`gamification.dart`):
```dart
class Achievement {
  String id;
  String title;
  String description;
  bool unlocked;
}

class Challenge {
  String id;
  String title;
  double targetProfit;
  int maxLosses;
  bool completed;
}
```

**User Profile** (`user_profile.dart`):
```dart
class UserProfile {
  String name;
  String experienceLevel;
  String riskTolerance;
  bool onboarded;
}
```


#### Constants (`lib/constants`)

**Markets** (`markets.dart`):
```dart
enum MarketType { crypto, stocks, forex }
enum TradingType { spot, futures, cash, margin, forexMargin }

class Asset {
  String symbol;
  String name;
  MarketType type;
  double basePrice;
  double volatility;
  int maxLeverage;
  String? region;  // 'US', 'IN' for stocks
}

// 14 total assets:
// - 8 Crypto: BTC, ETH, SOL, BNB, XRP, DOGE, ADA, AVAX
// - 6 Stocks: AAPL, NVDA, TSLA, TCS, RELIANCE, HDFCBANK
// - 5 Forex: GBP/USD, EUR/USD, USD/JPY, USD/CAD, AUD/USD
```

**Colors** (`colors.dart`):
- Multiple theme palettes (8 color schemes)
- Light and dark mode support
- Material Design 3 tokens

#### Utilities (`lib/utils`)

**Formatters** (`formatters.dart`):
- Currency formatting
- Number abbreviation (1.2K, 1.5M)
- Percentage formatting
- Date/time formatting

**Market Session** (`market_session.dart`):
```dart
enum MarketStatus { open, closed, preMarket, afterHours }

MarketStatus getMarketStatus(Asset asset);
bool isMarketLive(Asset asset);
int candleBoundary(int nowMs, int intervalMs);

// Stock hours:
// - US: 09:30-16:00 ET
// - India: 09:15-15:30 IST
// Forex: Sun 21:00 UTC - Fri 22:00 UTC
// Crypto: 24/7
```

**Position Calculator** (`position_calculator.dart`):
- P&L calculations
- Margin requirements
- Liquidation price
- Risk/reward ratios

**Haptics** (`haptics.dart`):
- Vibration feedback for trades
- Platform-specific haptic patterns

---

### 4. Data Layer

**Responsibility:** Data persistence and external data sources

#### Local Storage (SharedPreferences)

**Two storage keys:**

1. `@tradeverse_appstate` (AppState)
   - Theme preferences
   - User profile
   - Settings
   - Survives account reset

2. `@tradeverse_state_v2` (TradingProvider)
   - Portfolio data
   - Positions
   - Trade history
   - Achievements
   - Can be reset

#### External APIs

**1. Binance (Crypto Prices)**

*Mobile/Desktop (WebSocket):*
```
wss://stream.binance.com:9443/stream?streams=btcusdt@ticker,ethusdt@ticker,...
```
- Real-time (1-2 second updates)
- 8 crypto pairs
- Reconnects automatically

*Web (REST API):*
```
https://corsproxy.io/?https://api.binance.com/api/v3/ticker/24hr
```
- Polled every 3 seconds
- Via CORS proxy
- Returns 24hr price + change

**2. Yahoo Finance (Stocks/Forex)**

*All Platforms (REST API):*
```
[Web]: https://corsproxy.io/?https://query1.finance.yahoo.com/v7/finance/quote?symbols=...
[Mobile]: https://query1.finance.yahoo.com/v7/finance/quote?symbols=...
```
- Polled every 3 seconds
- 11 symbols (6 stocks + 5 forex)
- Returns regularMarketPrice, preMarketPrice, postMarketPrice

*Chart Data:*
```
https://query1.finance.yahoo.com/v8/finance/chart/{symbol}?interval={tf}&range={range}
```
- OHLCV candle data
- Multiple timeframes (1m, 5m, 15m, 1h, 4h, 1D)
- Historical data (up to 2 years)


---

## Technology Stack

### Core Framework
```yaml
Flutter SDK: ^3.12.0
Dart: ^3.12.0
```

### Key Dependencies

#### State Management & Architecture
- `provider: ^6.1.2` - State management
- `shared_preferences: ^2.3.2` - Local persistence

#### UI & Design
- `google_fonts: ^6.2.1` - Typography (Plus Jakarta Sans, Outfit)
- `syncfusion_flutter_charts: ^33.2.15` - Charts (allocation pie chart)
- Material Design 3 - Design system

#### Networking
- `http: ^1.6.0` - REST API calls
- `web_socket_channel: ^3.0.1` - WebSocket (crypto prices)
- `webview_flutter: ^4.14.0` - In-app browser
- `webview_flutter_web: ^0.2.3+4` - Web platform support

#### Development Tools
- `flutter_lints: ^6.0.0` - Code quality
- `flutter_launcher_icons: ^0.13.1` - App icon generation

### Platform Support
- ✅ Android (native)
- ✅ iOS (native)
- ✅ Web (with CORS proxies)
- ❌ Desktop (not configured)

---

## Project Structure

```
TradeVerse/
├── lib/
│   ├── main.dart                      # App entry point
│   │
│   ├── screens/                       # Full-screen pages (13)
│   │   ├── splash_screen.dart
│   │   ├── onboarding_screen.dart
│   │   ├── main_tabs_screen.dart     # Bottom nav host
│   │   ├── portfolio_screen.dart     # Dashboard
│   │   ├── markets_screen.dart       # Asset browser
│   │   ├── trade_screen.dart         # Trading terminal
│   │   ├── coin_detail_screen.dart   # Asset detail + chart
│   │   ├── history_screen.dart
│   │   ├── analytics_screen.dart
│   │   ├── challenges_screen.dart
│   │   ├── journal_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── more_screen.dart
│   │   └── trade_detail_screen.dart
│   │
│   ├── components/                    # Reusable UI (8)
│   │   ├── candlestick_chart.dart    # 1800+ line trading chart
│   │   ├── interactive_chart.dart
│   │   ├── sparkline.dart
│   │   ├── allocation_chart.dart
│   │   ├── animated_price.dart
│   │   ├── asset_row.dart
│   │   ├── price_stream_builder.dart
│   │   └── ui.dart
│   │
│   ├── widgets/                       # Specific widgets (2)
│   │   ├── position_card.dart
│   │   └── journal_dialogs.dart
│   │
│   ├── providers/                     # State management (3)
│   │   ├── app_state.dart            # Theme & preferences
│   │   ├── trading_provider.dart     # Trading logic (1000+ lines)
│   │   └── settings_provider.dart    # (legacy/unused?)
│   │
│   ├── models/                        # Data structures (3)
│   │   ├── trading_models.dart       # Position, Trade, Order
│   │   ├── gamification.dart         # Achievement, Challenge
│   │   └── user_profile.dart         # UserProfile
│   │
│   ├── constants/                     # Static data (2)
│   │   ├── markets.dart              # Assets, MarketType, TradingType
│   │   └── colors.dart               # Theme palettes
│   │
│   └── utils/                         # Helper functions (4)
│       ├── formatters.dart
│       ├── market_session.dart
│       ├── position_calculator.dart
│       └── haptics.dart
│
├── assets/
│   └── icon.png                       # App launcher icon
│
├── android/                           # Android native config
├── ios/                               # iOS native config
├── web/                               # Web platform config
│
├── pubspec.yaml                       # Dependencies
└── README.md
```

### File Count Summary
- **Screens:** 13
- **Components:** 8
- **Widgets:** 2
- **Providers:** 3 (2 active)
- **Models:** 3
- **Constants:** 2
- **Utils:** 4
- **Total Dart Files:** ~35

### Lines of Code (Approximate)
- `trading_provider.dart`: ~1000 lines
- `candlestick_chart.dart`: ~1800 lines
- Other files: ~100-300 lines each
- **Total:** ~8,000-10,000 lines


---

## Data Flow

### 1. App Initialization Flow

```
User Opens App
    ↓
main() → WidgetsFlutterBinding.ensureInitialized()
    ↓
MultiProvider created
    ├─→ AppState()
    │    ├─ Load SharedPreferences (@tradeverse_appstate)
    │    ├─ Set theme, profile, onboarding status
    │    └─ notifyListeners()
    │
    └─→ TradingProvider()
         ├─ Load SharedPreferences (@tradeverse_state_v2)
         ├─ Restore portfolio, positions, trades
         ├─ Connect Binance WebSocket (mobile only)
         ├─ Start price update timer (every 3s)
         └─ notifyListeners()
    ↓
MaterialApp builds with theme from AppState
    ↓
SplashScreen shown (2s)
    ↓
Check AppState.onboarded
    ├─ false → OnboardingScreen
    └─ true → MainTabsScreen (bottom nav)
```

### 2. Real-Time Price Update Flow

```
┌─────────────────────────────────────────┐
│       MOBILE PLATFORM (Crypto)          │
└─────────────────────────────────────────┘
Binance WebSocket
    ↓ (every 1-2s)
Message: {"stream":"btcusdt@ticker", "data":{"c":"67234.56","P":"2.34"}}
    ↓
TradingProvider._cryptoChannel.stream.listen()
    ↓
Parse price and change
    ↓
Update _prices['BTC'] = 67234.56
Update _priceChanges['BTC'] = 2.34
    ↓
notifyListeners()
    ↓
Emit _priceUpdateController.add('BTC')
    ↓
UI widgets rebuild
    ├─ AnimatedPrice updates
    ├─ Chart live candle updates
    └─ Position P&L recalculated

┌─────────────────────────────────────────┐
│    ALL PLATFORMS (Stocks/Forex)         │
└─────────────────────────────────────────┘
Timer.periodic(3 seconds)
    ↓
TradingProvider._updatePrices()
    ↓
Parallel API calls:
    ├─ _fetchBinancePrices() (web only, crypto)
    └─ _fetchYahooPrices() (stocks/forex)
    ↓
HTTP GET → Yahoo Finance API
Response: [{symbol:'AAPL', regularMarketPrice:221.34, ...}, ...]
    ↓
Validate freshness (< 60s during market hours)
Reject stale/suspicious data
    ↓
Update _prices['AAPL'] = 221.34
Update _priceChanges['AAPL'] = -0.45
    ↓
notifyListeners()
    ↓
Emit _priceUpdateController.add('AAPL')
    ↓
UI widgets rebuild
```

### 3. Trade Execution Flow

```
User on TradeScreen
    ↓
Selects asset (e.g., BTC)
Sets side (Long/Short)
Sets quantity (0.1)
Sets leverage (10x)
Adds stop-loss/take-profit (optional)
    ↓
Taps "Open Position" button
    ↓
TradingProvider.openPosition(
  symbol: 'BTC',
  side: PositionSide.long,
  qty: 0.1,
  leverage: 10,
  stopLoss: 65000,
  takeProfit: 70000,
)
    ↓
Validation:
    ├─ Check balance sufficient?
    ├─ Check margin available?
    ├─ Check qty > 0?
    └─ Check asset exists?
    ↓
Calculate:
    ├─ Entry price = current market price
    ├─ Position value = qty × price × leverage
    ├─ Margin required = value / leverage
    ├─ Liquidation price
    └─ Spread (for forex)
    ↓
Create Position object
Add to _positions list
Deduct margin from _balance
    ↓
Save state to SharedPreferences
    ↓
notifyListeners()
    ↓
UI updates:
    ├─ Portfolio screen shows new position
    ├─ Balance decreases
    ├─ Equity includes unrealized P&L
    └─ Chart shows entry line (optional overlay)
    ↓
Haptic feedback (vibration)
    ↓
Show success message
```


### 4. Position Monitoring & Risk Management Flow

```
Timer.periodic(3 seconds) in TradingProvider
    ↓
_updatePrices() fetches new prices
    ↓
_processRiskAndOrders() called
    ↓
For each open position:
    ↓
Get current price
    ↓
Check Stop-Loss:
    ├─ Long: price <= stopLoss? → Close position
    └─ Short: price >= stopLoss? → Close position
    ↓
Check Take-Profit:
    ├─ Long: price >= takeProfit? → Close position
    └─ Short: price <= takeProfit? → Close position
    ↓
Check Trailing Stop:
    ├─ Update trailing anchor (highest/lowest since entry)
    └─ If price moves against by trailing % → Close
    ↓
Check Liquidation:
    ├─ Calculate unrealized P&L
    ├─ If loss >= 90% of margin → Liquidate
    └─ Close position, deduct remaining margin
    ↓
For each pending order:
    ↓
Check if trigger price reached
    ├─ Limit order: price <= limit (buy) or >= limit (sell)
    └─ Stop order: price >= stop (buy) or <= stop (sell)
    ↓
If triggered → Execute order as market position
    ↓
Remove from _orders list
Add to _positions list
    ↓
Save state, notifyListeners(), emit events
```

### 5. Theme Change Flow

```
User on SettingsScreen
    ↓
Selects new theme (e.g., Dark Mode)
    ↓
AppState.setThemeMode(ThemeMode.dark)
    ↓
Update _themeMode = ThemeMode.dark
    ↓
Save to SharedPreferences (@tradeverse_appstate)
    ↓
notifyListeners()
    ↓
MaterialApp (in main.dart) watches AppState
    ↓
Rebuilds with new themeMode
    ↓
All screens/widgets inherit new theme
    ↓
Colors, text styles update automatically
```

---

## State Management

### Provider Pattern Implementation

```dart
// 1. Provider Definition
class TradingProvider extends ChangeNotifier {
  double _balance = 10000.0;
  
  double get balance => _balance;
  
  void updateBalance(double newBalance) {
    _balance = newBalance;
    notifyListeners();  // ← Triggers rebuild
  }
}

// 2. Provider Registration (main.dart)
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppState()),
    ChangeNotifierProvider(create: (_) => TradingProvider()),
  ],
  child: const MyApp(),
)

// 3. Consumer Usage (in widgets)
// Option A: context.watch (rebuilds on change)
Widget build(BuildContext context) {
  final balance = context.watch<TradingProvider>().balance;
  return Text('\$$balance');
}

// Option B: Provider.of with listen
Widget build(BuildContext context) {
  final provider = Provider.of<TradingProvider>(context);
  return Text('\$${provider.balance}');
}

// Option C: Provider.of without listen (no rebuild)
void _executeTrade(BuildContext context) {
  final provider = Provider.of<TradingProvider>(context, listen: false);
  provider.openPosition(...);
}

// Option D: Consumer widget (granular control)
Consumer<TradingProvider>(
  builder: (context, trading, child) {
    return Text('\$${trading.balance}');
  },
)
```

### State Lifecycle

```
App Start
    ↓
Provider created → _loadState() from SharedPreferences
    ↓
State available to all widgets
    ↓
User interaction → Method called on provider
    ↓
State updated internally
    ↓
notifyListeners() called
    ↓
All listening widgets rebuild
    ↓
_saveState() to SharedPreferences
    ↓
State persisted
```


---

## External Integrations

### 1. Binance API (Crypto Prices)

**WebSocket (Mobile/Desktop)**
```
Endpoint: wss://stream.binance.com:9443/stream
Streams: btcusdt@ticker,ethusdt@ticker,solusdt@ticker,bnbusdt@ticker,
         xrpusdt@ticker,dogeusdt@ticker,adausdt@ticker,avaxusdt@ticker

Message Format:
{
  "stream": "btcusdt@ticker",
  "data": {
    "c": "67234.56",  // Current price
    "P": "2.34"       // 24h change %
  }
}

Connection: Persistent, auto-reconnects on error (5s delay)
Updates: Real-time (1-2 seconds)
Platform: Mobile/Desktop only (web blocked by CORS)
```

**REST API (Web + Fallback)**
```
Endpoint: https://api.binance.com/api/v3/ticker/24hr
Method: GET
Response: Array of ticker objects
[
  {
    "symbol": "BTCUSDT",
    "lastPrice": "67234.56",
    "priceChangePercent": "2.34"
  },
  ...
]

Polling: Every 3 seconds
Platform: Web (via CORS proxy), Mobile (direct)
Proxy: https://corsproxy.io/?https://api.binance.com/...
```

### 2. Yahoo Finance API (Stocks/Forex)

**Live Prices**
```
Endpoint: https://query1.finance.yahoo.com/v7/finance/quote
Parameters: symbols=AAPL,NVDA,TSLA,TCS.NS,RELIANCE.NS,HDFCBANK.NS,
                    GBPUSD=X,EURUSD=X,USDJPY=X,USDCAD=X,AUDUSD=X

Response:
{
  "quoteResponse": {
    "result": [
      {
        "symbol": "AAPL",
        "regularMarketPrice": 221.34,
        "regularMarketChangePercent": -0.45,
        "regularMarketTime": 1704470400,
        "marketState": "REGULAR",
        "preMarketPrice": 220.50,
        "postMarketPrice": 221.80
      },
      ...
    ]
  }
}

Polling: Every 3 seconds
Platform: All platforms
Proxy (Web): https://corsproxy.io/?https://query1.finance.yahoo.com/...
Data Freshness: < 60s during market hours, < 300s when closed
```

**Historical Chart Data**
```
Endpoint: https://query1.finance.yahoo.com/v8/finance/chart/{symbol}
Parameters:
  - interval: 2m, 5m, 15m, 1h, 1d
  - range: 7d, 60d, 2y (depends on interval)
  - includePrePost: false

Response:
{
  "chart": {
    "result": [{
      "timestamp": [1704470400, 1704474000, ...],
      "indicators": {
        "quote": [{
          "open": [221.30, 221.50, ...],
          "high": [221.80, 222.10, ...],
          "low": [221.00, 221.20, ...],
          "close": [221.50, 221.90, ...],
          "volume": [1234567, 1345678, ...]
        }]
      }
    }]
  }
}

Fetched: On-demand (when chart loads/changes timeframe)
Platform: All platforms (with CORS proxy on web)
Candles: 500-1000 per request
Fallback: Multiple Yahoo hostnames (query1, query2)
```

### 3. CORS Proxy (Web Platform)

**Why Needed:**
- Browsers block direct API calls (CORS policy)
- Yahoo Finance and Binance don't allow web origins

**Proxy Used:**
```
https://corsproxy.io/?{encoded_url}
```

**How It Works:**
```
Flutter Web App
    ↓ HTTPS Request
corsproxy.io (proxy server)
    ↓ Relays request to
Binance/Yahoo Finance API
    ↓ Response
corsproxy.io
    ↓ Returns to
Flutter Web App (with CORS headers added)
```

**Limitations:**
- Free service (rate limits apply)
- ~200-500ms added latency
- Dependency on third-party
- Alternatives: allorigins.win, codetabs.com, self-hosted cors-anywhere


---

## Feature Modules

### 1. Portfolio Management

**Purpose:** Track user's trading account

**Components:**
- Dashboard (PortfolioScreen)
- Position cards
- Equity/balance display
- P&L tracking

**Key Features:**
- Real-time portfolio value
- Unrealized P&L (open positions)
- Realized P&L (closed trades)
- Margin usage visualization
- Free margin calculation
- Win/loss statistics

**Data Flow:**
```
TradingProvider maintains:
  - _balance (available funds)
  - _positions (open trades)
  - _trades (history)

Calculations:
  equity = balance + sum(position.unrealizedPnL)
  usedMargin = sum(position.margin)
  freeMargin = equity - usedMargin
  marginLevel = (equity / usedMargin) × 100
```

### 2. Trading Terminal

**Purpose:** Execute trades with advanced order types

**Components:**
- TradeScreen (main terminal)
- Order entry form
- Position sizing calculator
- Risk management controls

**Trading Types:**
- **Spot:** Simple buy/sell (crypto only, 1x leverage)
- **Futures:** Leveraged perpetual contracts (up to 125x)
- **Cash:** Stock trading without leverage
- **Margin:** Stock trading with leverage (2-5x)
- **Forex Margin:** Currency pair trading (up to 500x)

**Order Types:**
- **Market:** Execute immediately at current price
- **Limit:** Execute when price reaches specified level
- **Stop:** Trigger market order at stop price
- **Stop-Limit:** Trigger limit order at stop price

**Risk Controls:**
- Stop-loss (automatic exit on loss)
- Take-profit (automatic exit on profit)
- Trailing stop (dynamic stop-loss)
- Position size limits
- Leverage limits per asset

### 3. Market Data & Charts

**Purpose:** Real-time price visualization and analysis

**Components:**
- CandlestickChart (1800+ line custom implementation)
- InteractiveChart (simple line chart)
- Sparkline (mini price history)
- Price streams (live updates)

**Chart Features:**
- Multiple timeframes (1m, 5m, 15m, 1h, 4h, 1D)
- 500-1000 historical candles
- Live candle updates (ticks)
- Pan and zoom gestures
- Crosshair with OHLC data
- Volume panel
- Technical indicators:
  - EMA (9, 21, 50, 200)
  - SMA (50, 200)
  - VWAP (Volume-Weighted Average Price)
  - MACD (Moving Average Convergence Divergence)
- Trading overlays (entry, stop-loss, take-profit)
- Fullscreen mode (landscape support)
- Market status badge (open/closed)
- Countdown timer (next candle)

**Data Sources:**
- Historical: Binance klines, Yahoo Finance chart API
- Live: WebSocket (crypto), REST polling (stocks/forex)
- Pagination: Load older candles on scroll

### 4. Trade History & Analytics

**Purpose:** Review past performance and improve strategy

**Components:**
- HistoryScreen (trade list)
- TradeDetailScreen (individual trade)
- AnalyticsScreen (statistics)
- Journal entries

**Tracked Metrics:**
- Total trades
- Win rate (wins / total trades)
- Average profit/loss
- Best/worst trade
- Trading style distribution (scalping, day, swing)
- Consecutive wins/losses
- Profit factor
- Risk/reward adherence

**Trade Journal:**
- **Entry Journal:** Why entering, strategy, confidence (1-10)
- **Exit Journal:** What went well/wrong, emotional state, lessons

### 5. Gamification System

**Purpose:** Educate and motivate through game mechanics

**Components:**
- Achievements (milestones)
- Challenges (specific goals)
- Leaderboard concepts (not implemented)

**Achievements (Examples):**
- First Trade
- 10 Winning Trades
- Reach $20,000 equity
- Use stop-loss 10 times
- Complete trade journal 5 times
- Hit 70% win rate
- Survive 7 consecutive days profitable

**Challenges (Examples):**
- Profit Challenge: Make $2,000 with max 3 losses
- Discipline Challenge: Follow stop-loss for 10 trades
- Diversification: Trade 5 different assets

**Progression:**
- Unlock new features (leverage limits)
- Visual badges and titles
- Progress tracking


### 6. Market Session Management

**Purpose:** Respect real-world trading hours

**Implementation:** `lib/utils/market_session.dart`

**Market Hours:**

**Crypto:**
- 24/7 trading
- Always returns `MarketStatus.open`

**US Stocks (NYSE/NASDAQ):**
- Regular: 09:30 - 16:00 ET (Mon-Fri)
- Pre-market: 04:00 - 09:30 ET
- After-hours: 16:00 - 20:00 ET
- Timezone: UTC-4 (EDT) approximation

**Indian Stocks (NSE/BSE):**
- Regular: 09:15 - 15:30 IST (Mon-Fri)
- Pre-market: 09:00 - 09:15 IST
- After-hours: 15:30 - 17:00 IST
- Timezone: UTC+5:30

**Forex:**
- Trading: Sunday 21:00 UTC - Friday 22:00 UTC
- Closed: Saturday and Sunday (before 21:00)
- Global 24-hour market (Mon-Fri)

**Behavior:**
```dart
// Check if market is open
if (isMarketLive(asset)) {
  // Allow live candle updates
  // Accept only fresh data (< 60s)
  // Show countdown timer
} else {
  // Freeze chart
  // Hold last price
  // Show "CLOSED" badge
  // Accept stale data (< 300s)
}
```

### 7. News & Market Events

**Purpose:** Simulate market-moving events

**Implementation:** Simulated news articles

**News Types:**
- Crypto: "Institutional Inflow", "Bitcoin Halving"
- Stocks: "Tech Earnings Beat", "Inflation Fears"
- Forex: "US Yields Spike", "Rate Hike Surprise"

**Impact System:**
```dart
class NewsArticle {
  String title;
  String description;
  String impactSymbol;  // 'BTC', 'AAPL', or 'crypto'/'stocks'/'forex'
  String sentiment;     // 'bullish' or 'bearish'
  double impactFactor;  // 0.08 = +8% impact
  int timestamp;
}
```

**Price Impact:**
- Active for 90 seconds after publication
- Affects simulated price volatility
- Multiple news can stack
- Generated every ~60 seconds

**Note:** Currently simulated. Future could integrate real news APIs.

### 8. Onboarding & User Profile

**Purpose:** Personalize experience for skill level

**Onboarding Flow:**
```
1. Welcome screen
2. Enter name
3. Select experience level:
   - Beginner
   - Intermediate
   - Advanced
4. Select risk tolerance:
   - Conservative
   - Moderate
   - Aggressive
5. Complete → MainTabsScreen
```

**Profile Usage:**
- Customize tutorial content
- Suggest appropriate leverage
- Set default risk parameters
- Personalize UI complexity

### 9. Settings & Preferences

**SettingsScreen Features:**
- Theme mode (Light/Dark/System)
- Color scheme selection (8 palettes)
- Haptic feedback toggle
- Currency display format
- Account reset
- Data export (future)

**Theme System:**
```dart
// 8 color palettes × 2 modes = 16 themes
ThemePalette {
  primary, secondary, destructive, warning, success,
  background, card, border, text, textMuted,
  brightness
}

// Dynamic theme switching
AppState.setThemeIndex(2)  // Changes entire app
```

---

## Design Patterns

### 1. **Provider Pattern** (State Management)

**Pattern:** Observer pattern via ChangeNotifier

**Structure:**
```dart
// Subject
class TradingProvider extends ChangeNotifier {
  // State
  double _balance;
  
  // Observers notified on change
  void updateBalance(double val) {
    _balance = val;
    notifyListeners();  // ← Notify all observers
  }
}

// Observers (widgets)
Widget build(context) {
  return context.watch<TradingProvider>().balance;
}
```

**Benefits:**
- Decouples UI from business logic
- Automatic UI updates
- Single source of truth

### 2. **Repository Pattern** (Data Layer)

**Pattern:** Abstract data source access

**Structure:**
```dart
// Data comes from multiple sources
abstract class PriceRepository {
  Stream<double> getPriceStream(String symbol);
  Future<List<Candle>> getHistoricalData(String symbol);
}

// Implementations:
class BinanceRepository implements PriceRepository { ... }
class YahooRepository implements PriceRepository { ... }
class LocalCacheRepository implements PriceRepository { ... }
```

**Current State:** Partially implemented
- TradingProvider acts as repository
- Could be extracted for better separation

### 3. **Factory Pattern** (Object Creation)

**Pattern:** Centralized object creation

**Examples:**
```dart
// Asset creation from constants
Asset.fromSymbol('BTC');
Asset.fromJson(json);

// Market config based on type
MarketConfig.get(MarketType.crypto, TradingType.futures);

// Theme creation
AppColors.getPalette(index, brightness);
```

### 4. **Strategy Pattern** (Trading Types)

**Pattern:** Interchangeable algorithms

**Structure:**
```dart
// Different calculation strategies per trading type
class MarketConfig {
  double maxLeverage;
  double makerFee;
  double takerFee;
  bool allowShort;
  
  static MarketConfig get(MarketType market, TradingType type) {
    if (market == MarketType.crypto && type == TradingType.futures) {
      return MarketConfig(maxLeverage: 125, fee: 0.0005, ...);
    }
    // ... different configs per combination
  }
}
```

**Used For:**
- Fee calculation
- Leverage limits
- Margin requirements
- P&L calculation


### 5. **Builder Pattern** (UI Construction)

**Pattern:** Step-by-step complex object creation

**Examples:**
```dart
// Chart builder
CandlestickChart(
  asset: asset,
  height: 400,
  timeframe: '1h',
  showVolume: true,
  showIndicators: true,
  indicators: ['EMA_9', 'EMA_21', 'MACD'],
  onCandleClick: (candle) { ... },
);

// Position builder (via method parameters)
openPosition(
  symbol: 'BTC',
  side: PositionSide.long,
  qty: 0.1,
  leverage: 10,
  stopLoss: 65000,
  takeProfit: 70000,
  trailingStop: 500,
  entryJournal: EntryJournal(...),
);
```

### 6. **Stream Pattern** (Reactive Programming)

**Pattern:** Event-based data flow

**Structure:**
```dart
// Price update stream
final StreamController<String> _priceUpdateController = 
    StreamController<String>.broadcast();

Stream<String> get priceUpdateStream => _priceUpdateController.stream;

// Emit events
_priceUpdateController.add('BTC');

// Listen to events
priceUpdateStream.listen((symbol) {
  print('$symbol price updated');
});
```

**Used For:**
- Real-time price updates
- Chart live candle updates
- Position monitoring
- Event propagation

### 7. **Singleton Pattern** (Global Access)

**Pattern:** Single instance across app

**Examples:**
```dart
// Global navigation key
final GlobalKey<MainTabsScreenState> mainTabsKey = GlobalKey();

// Usage from anywhere
mainTabsKey.currentState?.openTradeWith('BTC');

// Provider instances (managed by Provider package)
TradingProvider (single instance via ChangeNotifierProvider)
AppState (single instance via ChangeNotifierProvider)
```

### 8. **Command Pattern** (Action Encapsulation)

**Pattern:** Encapsulate actions as objects

**Structure:**
```dart
// Trade actions
class TradeResult {
  bool success;
  String? error;
  Position? position;
}

// Execute command
TradeResult result = trading.openPosition(...);
if (result.success) {
  // Handle success
} else {
  // Handle error: result.error
}
```

**Benefits:**
- Undo/redo capability (future)
- Logging and audit trail
- Error handling consistency

### 9. **Decorator Pattern** (Feature Extension)

**Pattern:** Add functionality without modifying core

**Examples:**
```dart
// Animated price (decorates plain price display)
AnimatedPrice(
  value: 67234.56,
  change: 2.34,
  animate: true,
);

// Price stream builder (decorates price with real-time updates)
PriceStreamBuilder(
  symbol: 'BTC',
  builder: (context, price, change) {
    return Text('\$$price');
  },
);
```

### 10. **Facade Pattern** (Simplified Interface)

**Pattern:** Hide complex subsystem behind simple interface

**Example:**
```dart
// Complex market session logic hidden
bool isMarketLive(Asset asset) {
  // Internally checks:
  // - Asset type
  // - Current time
  // - Timezone conversions
  // - Market hours
  // - Weekday/weekend
  return getMarketStatus(asset).isLive;
}

// Simple usage
if (isMarketLive(asset)) {
  updateLiveCandle();
}
```

---

## Security & Privacy

### Data Security

**Local Storage:**
- SharedPreferences (encrypted on device)
- No cloud sync (fully local)
- No user authentication required
- No personally identifiable information (PII)

**API Keys:**
- None required (public APIs)
- No sensitive credentials stored

**Network Security:**
- HTTPS for all API calls
- WebSocket over TLS (wss://)
- CORS proxy for web platform

### Privacy

**Data Collection:**
- No analytics tracking
- No crash reporting
- No user data sent to servers
- No ads or third-party SDKs

**User Data:**
- Name (local only)
- Trading history (local only)
- Preferences (local only)
- Can be reset/deleted anytime

**Note:** This is a simulation app. No real money involved.

---

## Performance Optimization

### 1. **Efficient Rendering**

**Chart Optimization:**
```dart
// Only repaint what changed
if (isLiveCandle) {
  // Update only last candle + price line
  _paintLiveCandle(canvas);
  _paintPriceLine(canvas);
} else {
  // Full repaint
  _paintAllCandles(canvas);
}

// Reuse Paint objects
final _candlePaint = Paint()..style = PaintingStyle.fill;

// Cull offscreen candles
if (candle.x < -100 || candle.x > width + 100) continue;
```

**Widget Rebuilds:**
```dart
// Use const constructors
const Text('Portfolio');

// Use keys for list items
ListView.builder(
  itemBuilder: (context, index) {
    return PositionCard(
      key: ValueKey(position.id),
      position: position,
    );
  },
);

// Limit rebuild scope with Consumer
Consumer<TradingProvider>(
  builder: (context, trading, child) {
    return Text('\$${trading.balance}');
  },
);
```

### 2. **Lazy Loading**

**On-Demand Data:**
- Historical candles loaded when chart opens
- Older candles paginated on scroll
- News articles generated as needed
- Settings loaded on settings screen

### 3. **Debouncing & Throttling**

**Price Updates:**
```dart
// WebSocket: Real-time (1-2s)
// REST API: Throttled to 3s intervals
// Chart repaints: Only when visible

// Don't rebuild on every tick
if (kDebugMode && _tickCount % 10 == 0) {
  debugPrint('[Price] BTC: $price');
}
```

### 4. **Memory Management**

**Stream Disposal:**
```dart
@override
void dispose() {
  _priceUpdateController.close();
  _cryptoChannel?.sink.close();
  _timer?.cancel();
  super.dispose();
}
```

**Limited Cache:**
- Max 1000 candles in memory
- Old candles trimmed automatically
- News limited to 20 articles


---

## Testing Strategy

### Current State
- **Unit Tests:** Not implemented
- **Widget Tests:** Not implemented
- **Integration Tests:** Not implemented
- **Manual Testing:** Primary method

### Recommended Test Coverage

**Unit Tests (High Priority):**
```dart
// test/models/position_test.dart
test('Position P&L calculation - Long', () {
  final position = Position(
    symbol: 'BTC',
    side: PositionSide.long,
    qty: 0.1,
    entryPrice: 60000,
    leverage: 10,
  );
  
  final pnl = position.pnl(65000);
  expect(pnl, 500.0);  // (65000-60000) * 0.1 = 500
});

// test/utils/market_session_test.dart
test('US market open during trading hours', () {
  final asset = getAssetBySymbol('AAPL')!;
  // Mock DateTime to 10:30 AM ET on Monday
  final status = getMarketStatus(asset);
  expect(status, MarketStatus.open);
});
```

**Widget Tests (Medium Priority):**
```dart
// test/widgets/position_card_test.dart
testWidgets('Position card displays correct P&L', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PositionCard(position: testPosition),
    ),
  );
  
  expect(find.text('+\$500.00'), findsOneWidget);
  expect(find.byIcon(Icons.trending_up), findsOneWidget);
});
```

**Integration Tests (Low Priority):**
- Test complete trade flow
- Test position liquidation
- Test price update propagation

---

## Deployment

### Build Configuration

**Android:**
```gradle
// android/app/build.gradle.kts
android {
  namespace = "com.example.app"
  compileSdk = 35
  
  defaultConfig {
    applicationId = "com.example.app"
    minSdk = 21
    targetSdk = 35
    versionCode = 1
    versionName = "1.0.0"
  }
}
```

**iOS:**
```
Info.plist configurations
- Bundle identifier
- Version number
- Permissions (none required)
```

**Web:**
```html
<!-- web/index.html -->
<meta charset="UTF-8">
<title>TradeVerse</title>
<!-- CORS handling via proxy -->
```

### Build Commands

```bash
# Development
flutter run

# Android Release
flutter build apk --release
flutter build appbundle --release

# iOS Release
flutter build ios --release

# Web Release
flutter build web --release
```

### Release Checklist
- [ ] Update version in pubspec.yaml
- [ ] Test on all target platforms
- [ ] Verify API connections
- [ ] Check CORS proxy availability
- [ ] Test market hours logic
- [ ] Validate theme switching
- [ ] Test portfolio persistence
- [ ] Verify chart functionality
- [ ] Check gamification features
- [ ] Test account reset

---

## Known Limitations

### Technical Constraints

1. **Web Platform:**
   - WebSocket blocked by CORS (crypto uses REST API)
   - Depends on third-party CORS proxy
   - Slower price updates (3s vs 1-2s on mobile)

2. **Data Sources:**
   - Yahoo Finance rate limits (free tier)
   - No guaranteed SLA for public APIs
   - Data freshness varies by market

3. **Market Hours:**
   - Timezone approximations (no DST handling)
   - No support for market holidays
   - Simple open/closed logic

4. **Charting:**
   - Historical data limited by API (60 days for intraday)
   - No drawing tools
   - Limited indicator customization

5. **Gamification:**
   - No multiplayer features
   - No global leaderboard
   - Achievements stored locally only

### Business Constraints

1. **Simulated Environment:**
   - Not connected to real exchanges
   - No real money handling
   - Educational purpose only

2. **Data Accuracy:**
   - Real-time delays (3-11 seconds)
   - Simulated news events
   - No order book depth

3. **Scalability:**
   - Local storage only
   - No cloud backup
   - Single device usage

---

## Future Enhancements

### Short-Term (Next Sprint)

1. **Improved Error Handling:**
   - API failure recovery
   - Network status detection
   - User-friendly error messages

2. **Better Logging:**
   - Structured logging system
   - Error tracking
   - Performance metrics

3. **Code Refactoring:**
   - Split TradingProvider (too large)
   - Extract price fetching to repository
   - Separate chart logic

### Medium-Term (Next Quarter)

1. **Advanced Features:**
   - More indicators (RSI, Bollinger Bands, Fibonacci)
   - Drawing tools (trendlines, support/resistance)
   - Multi-timeframe analysis
   - Advanced order types (OCO, trailing limit)

2. **Cloud Sync:**
   - Firebase backend
   - Multi-device support
   - Portfolio backup

3. **Social Features:**
   - Trade sharing
   - Community challenges
   - Global leaderboard

4. **Better Data:**
   - Professional data feeds
   - More assets (commodities, indices)
   - Real order book simulation

### Long-Term (Roadmap)

1. **AI/ML Features:**
   - Pattern recognition
   - Trade suggestions
   - Risk scoring

2. **Educational Content:**
   - Interactive tutorials
   - Video courses
   - Strategy guides

3. **Advanced Analytics:**
   - Backtesting engine
   - Strategy optimizer
   - Risk analytics dashboard

4. **Real Trading Integration:**
   - Broker API connections
   - Paper trading alongside live
   - Copy trading features

---

## Troubleshooting Guide

### Common Issues

**1. Prices Not Updating**
```
Symptoms: Stale prices, "waiting for WebSocket"
Causes:
  - Network connectivity
  - CORS proxy down (web)
  - API rate limit reached
  - Market closed (stocks/forex)

Solutions:
  - Check internet connection
  - Switch CORS proxy in code
  - Wait for market to open
  - Check console for API errors
```

**2. Chart Not Loading**
```
Symptoms: Empty chart, loading spinner forever
Causes:
  - Yahoo Finance API failure
  - Invalid symbol
  - No historical data available

Solutions:
  - Retry with different timeframe
  - Check Yahoo Finance status
  - Use different asset
```

**3. Position Not Closing**
```
Symptoms: Stop-loss not triggered
Causes:
  - Price hasn't reached trigger yet
  - Market closed (stops only checked during hours)
  - Price gap (slippage not simulated)

Solutions:
  - Wait for price to reach level
  - Check market hours
  - Manual close if needed
```

**4. App Crashes on Startup**
```
Symptoms: White screen, app closes
Causes:
  - Corrupted SharedPreferences
  - Invalid saved state
  - Memory issue

Solutions:
  - Clear app data
  - Reinstall app
  - Reset account from settings
```

**5. Theme Not Applying**
```
Symptoms: Wrong colors, inconsistent styling
Causes:
  - AppState not loaded
  - Theme index out of range
  - Material 3 not applied

Solutions:
  - Restart app
  - Reset settings
  - Check pubspec.yaml for google_fonts
```


---

## Architecture Decision Records (ADRs)

### ADR-001: State Management - Provider

**Date:** 2024
**Status:** Accepted

**Context:**
Need simple, maintainable state management for a medium-sized app.

**Decision:**
Use Provider (ChangeNotifier pattern)

**Alternatives Considered:**
- BLoC: Too much boilerplate for scope
- Riverpod: Migration overhead, learning curve
- GetX: Non-standard approach
- Redux: Excessive complexity

**Consequences:**
- ✅ Easy to learn and maintain
- ✅ Official Flutter recommendation
- ✅ Good performance
- ⚠️ Manual notifyListeners() calls
- ⚠️ Less structured than BLoC

---

### ADR-002: Local-Only Storage

**Date:** 2024
**Status:** Accepted

**Context:**
Need data persistence for portfolio and trades.

**Decision:**
Use SharedPreferences with local-only storage.

**Alternatives Considered:**
- Firebase: Unnecessary for MVP, costs
- SQLite: Overkill for simple data
- Hive: Additional dependency

**Consequences:**
- ✅ Simple implementation
- ✅ No backend needed
- ✅ Privacy-friendly
- ⚠️ No multi-device sync
- ⚠️ No backup

---

### ADR-003: Custom Chart Implementation

**Date:** 2024
**Status:** Accepted

**Context:**
Need professional trading chart with full customization.

**Decision:**
Build custom CustomPainter-based candlestick chart.

**Alternatives Considered:**
- fl_chart: Limited candlestick support
- syncfusion_flutter_charts: Free version restricted
- webview + TradingView: Poor performance

**Consequences:**
- ✅ Full control over features
- ✅ No licensing costs
- ✅ Perfect integration
- ⚠️ 1800+ lines to maintain
- ⚠️ Manual indicator implementation

---

### ADR-004: Real-Time Data Strategy

**Date:** 2024
**Status:** Accepted

**Context:**
Need real-time prices without paid data feeds.

**Decision:**
- Mobile: Binance WebSocket (crypto) + Yahoo REST (stocks/forex)
- Web: Binance REST via proxy + Yahoo REST via proxy

**Alternatives Considered:**
- Professional feeds (Bloomberg, Refinitiv): Too expensive
- Single REST API for all: Too slow
- WebSocket for everything: CORS issues on web

**Consequences:**
- ✅ Free data access
- ✅ Real-time on mobile (crypto)
- ⚠️ Web has higher latency
- ⚠️ Depends on CORS proxies
- ⚠️ Rate limit concerns

---

### ADR-005: Paper Trading Simulation

**Date:** 2024
**Status:** Accepted

**Context:**
Educational app for learning trading concepts.

**Decision:**
Fully simulated environment with real market data.

**Alternatives Considered:**
- Real broker integration: Complex, risky
- Purely synthetic data: Unrealistic

**Consequences:**
- ✅ Safe learning environment
- ✅ No financial risk
- ✅ Real market prices
- ⚠️ Not connected to exchanges
- ⚠️ No order book simulation

---

## Glossary

**API (Application Programming Interface):** Interface for accessing external services (Binance, Yahoo Finance)

**Asset:** Tradable instrument (crypto, stock, forex pair)

**Candle/Candlestick:** OHLC data point representing price movement in a time period

**CORS (Cross-Origin Resource Sharing):** Browser security policy that blocks certain API calls

**EMA (Exponential Moving Average):** Technical indicator showing weighted average price

**Equity:** Total account value (balance + unrealized P&L)

**Futures:** Leveraged derivative contract

**Leverage:** Borrowed capital multiplier (10x = $1000 controls $10,000)

**Liquidation:** Forced position closure when losses exceed margin

**Long Position:** Bet that price will increase (buy low, sell high)

**MACD (Moving Average Convergence Divergence):** Momentum indicator

**Margin:** Collateral required to hold leveraged position

**OHLC:** Open, High, Low, Close (candle data)

**P&L (Profit & Loss):** Gain or loss on a position/trade

**Paper Trading:** Simulated trading with virtual money

**Provider:** Flutter state management pattern

**Short Position:** Bet that price will decrease (sell high, buy low)

**SMA (Simple Moving Average):** Technical indicator showing arithmetic average price

**Spot:** Non-leveraged trading (1x)

**Stop-Loss:** Automatic exit order to limit losses

**Take-Profit:** Automatic exit order to lock in profits

**Trailing Stop:** Dynamic stop-loss that moves with favorable price

**VWAP (Volume-Weighted Average Price):** Price weighted by trading volume

**WebSocket:** Persistent two-way connection for real-time data

---

## Summary

### Architecture Highlights

✅ **Well-Structured:** Clear layer separation (UI, State, Logic, Data)
✅ **Provider Pattern:** Simple, effective state management
✅ **Real Market Data:** Binance + Yahoo Finance APIs
✅ **Custom Chart:** Professional 1800-line implementation
✅ **Cross-Platform:** iOS, Android, Web support
✅ **Local-First:** Privacy-friendly, no cloud dependency
✅ **Gamified:** Achievements and challenges for engagement
✅ **Responsive:** Real-time updates (1-3 seconds)

### Key Metrics

| Metric | Value |
|--------|-------|
| Total Files | ~35 Dart files |
| Lines of Code | ~8,000-10,000 |
| Screens | 13 |
| Components | 8 |
| Assets | 14 (8 crypto, 6 stocks, 5 forex) |
| Dependencies | 8 main packages |
| State Providers | 2 (AppState, TradingProvider) |
| Chart LOC | 1,800 lines |
| Trading Provider LOC | 1,000+ lines |

### Technology Stack

- **Framework:** Flutter 3.12+
- **Language:** Dart 3.12+
- **State Management:** Provider 6.1
- **Persistence:** SharedPreferences
- **Charts:** Custom CustomPainter
- **Networking:** http + WebSocket
- **Fonts:** Google Fonts (Plus Jakarta Sans, Outfit)

---

## Conclusion

TradeVerse is a **well-architected paper trading simulator** that successfully balances:
- Educational value (gamification, real data)
- Technical quality (clean code, good patterns)
- User experience (responsive UI, real-time updates)
- Maintainability (clear structure, documented)

The architecture is **appropriate for the scope** and can scale to accommodate future features like cloud sync, social features, and advanced analytics.

**Recommended Next Steps:**
1. Add unit/widget tests
2. Refactor large providers
3. Implement error boundaries
4. Add structured logging
5. Consider Firebase for cloud features

---

**Document Version:** 1.0
**Last Updated:** 2024
**Maintained By:** Development Team

---

