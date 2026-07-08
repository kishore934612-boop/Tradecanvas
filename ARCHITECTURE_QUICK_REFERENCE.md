# TradeVerse Architecture - Quick Reference

## 🏗️ System Overview

```
┌────────────────────────────────────────────────────────┐
│                  TradeVerse                            │
│         Paper Trading Simulator App                    │
└────────────────────────────────────────────────────────┘

📱 Platforms: iOS, Android, Web
🎨 Framework: Flutter 3.12+
📊 Type: Single-page app with tab navigation
💾 Storage: Local (SharedPreferences)
🔄 State: Provider (ChangeNotifier)
```

---

## 📁 Project Structure (35 Files)

```
lib/
├── screens/ (13)          → Full-screen pages
├── components/ (8)        → Reusable UI (charts, cards)
├── widgets/ (2)           → Specific widgets
├── providers/ (2)         → State management
│   ├── app_state.dart           Theme, preferences
│   └── trading_provider.dart    Trading logic (1000+ LOC)
├── models/ (3)            → Data structures
├── constants/ (2)         → Assets, colors, config
├── utils/ (4)             → Helpers, formatters
└── main.dart              → App entry point
```

---

## 🔄 Data Flow

```
User Action
    ↓
UI Widget (Screen/Component)
    ↓
Provider Method Call
    ↓
Business Logic Execution
    ↓
State Update + notifyListeners()
    ↓
UI Automatically Rebuilds
    ↓
Save to SharedPreferences
```

---

## 📊 State Management (Provider)

### Two Providers

**1. AppState**
- Theme & colors
- User profile
- Settings
- Key: `@tradeverse_appstate`

**2. TradingProvider**
- Portfolio & positions
- Real-time prices
- Trade history
- Gamification
- Key: `@tradeverse_state_v2`

### Access Pattern

```dart
// Read & Watch (rebuilds on change)
final balance = context.watch<TradingProvider>().balance;

// Read Only (no rebuild)
final trading = Provider.of<TradingProvider>(context, listen: false);
trading.openPosition(...);
```

---

## 💰 Trading Features

### Assets (14 Total)
- **Crypto (8):** BTC, ETH, SOL, BNB, XRP, DOGE, ADA, AVAX
- **Stocks (6):** AAPL, NVDA, TSLA, TCS, RELIANCE, HDFCBANK
- **Forex (5):** GBP/USD, EUR/USD, USD/JPY, USD/CAD, AUD/USD

### Trading Types
- **Spot:** 1x (crypto)
- **Futures:** up to 125x (crypto)
- **Cash:** 1x (stocks)
- **Margin:** 2-5x (stocks)
- **Forex Margin:** up to 500x

### Order Types
- Market, Limit, Stop, Stop-Limit

### Risk Tools
- Stop-loss, Take-profit, Trailing stop

---

## 📈 Real-Time Price Updates

### Mobile/Desktop
```
Crypto:  WebSocket (Binance) → 1-2s updates
Stocks:  REST (Yahoo) → 3s polling
Forex:   REST (Yahoo) → 3s polling
```

### Web Platform
```
Crypto:  REST via proxy (Binance) → 3s polling
Stocks:  REST via proxy (Yahoo) → 3s polling
Forex:   REST via proxy (Yahoo) → 3s polling

Proxy: corsproxy.io (CORS workaround)
```

---

## 📉 Candlestick Chart (1800 LOC)

### Features
- **Timeframes:** 1m, 5m, 15m, 1h, 4h, 1D
- **Data:** 500-1000 historical candles
- **Gestures:** Pan, zoom, crosshair
- **Indicators:** EMA, SMA, VWAP, MACD
- **Overlays:** Entry, SL, TP lines
- **Live Updates:** Real-time candle ticks
- **Modes:** Candle, Area, Fullscreen

### Technical
- Custom `CustomPainter` implementation
- Zero third-party chart libraries
- OHLCV data from Binance & Yahoo Finance

---

## 🎮 Gamification

### Achievements
- First Trade, 10 Wins, $20K Equity
- Use SL 10x, 70% Win Rate
- 7 Day Profit Streak

### Challenges
- Profit Challenge (Make $2K, max 3 losses)
- Discipline Challenge (Follow SL 10x)
- Diversification (Trade 5 assets)

---

## 🎨 Design System

### Theming
- **8 Color Palettes** × Light/Dark = 16 themes
- **Material Design 3**
- **Fonts:** Plus Jakarta Sans, Outfit (Google Fonts)

### Dynamic Theme
```dart
AppState.setThemeIndex(2)  // Changes entire app
AppState.setThemeMode(ThemeMode.dark)
```

---

## 🔧 Key Technologies

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.12+ |
| Language | Dart 3.12+ |
| State | Provider 6.1 |
| Storage | SharedPreferences 2.3 |
| Network | http 1.6, WebSocket 3.0 |
| Fonts | Google Fonts 6.2 |
| Charts | Custom (no library) |

---

## 📱 Screens (13)

1. **Splash** - Initialization
2. **Onboarding** - First-time setup
3. **MainTabs** - Bottom nav host
4. **Portfolio** - Dashboard overview
5. **Markets** - Asset browser
6. **Trade** - Trading terminal
7. **CoinDetail** - Asset detail + chart
8. **History** - Trade history
9. **Analytics** - Performance stats
10. **Challenges** - Gamification
11. **Journal** - Trading notes
12. **Settings** - Preferences
13. **More** - Extra features

---

## 🌐 External APIs

### Binance (Crypto)
**WebSocket (Mobile):**
```
wss://stream.binance.com:9443/stream
Real-time, 1-2s updates
```

**REST (Web):**
```
https://api.binance.com/api/v3/ticker/24hr
Via CORS proxy, 3s polling
```

### Yahoo Finance (Stocks/Forex)
**Live Prices:**
```
https://query1.finance.yahoo.com/v7/finance/quote
3s polling, all platforms
```

**Chart Data:**
```
https://query1.finance.yahoo.com/v8/finance/chart/{symbol}
OHLCV historical data
```

---

## ⏰ Market Hours

| Market | Hours | Days |
|--------|-------|------|
| **Crypto** | 24/7 | Every day |
| **US Stocks** | 09:30-16:00 ET | Mon-Fri |
| **Indian Stocks** | 09:15-15:30 IST | Mon-Fri |
| **Forex** | Sun 21:00 - Fri 22:00 UTC | Mon-Fri |

---

## 🎯 Design Patterns Used

1. **Observer** - Provider/ChangeNotifier
2. **Repository** - Data access abstraction
3. **Factory** - Object creation
4. **Strategy** - Trading type configs
5. **Builder** - Complex UI construction
6. **Stream** - Reactive price updates
7. **Singleton** - Global providers
8. **Command** - Trade actions
9. **Decorator** - Feature wrapping
10. **Facade** - Simplified interfaces

---

## 📊 Performance

### Update Frequency
- Crypto (Mobile): **1-2 seconds** (WebSocket)
- Crypto (Web): **3 seconds** (REST)
- Stocks/Forex: **3 seconds** (REST)

### Data Limits
- Chart: Max 1000 candles in memory
- News: Max 20 articles
- Trades: Unlimited (local storage)

### Optimizations
- Incremental chart rendering
- Const constructors
- Lazy loading
- Debounced updates
- Stream disposal

---

## 🔐 Security & Privacy

✅ **Local-Only Storage** (no cloud)
✅ **No User Authentication** (no backend)
✅ **No PII Collection**
✅ **No Analytics Tracking**
✅ **HTTPS/WSS Only**
✅ **No Real Money** (simulation only)

---

## 🚀 Quick Commands

```bash
# Run Development
flutter run

# Build Android
flutter build apk --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release

# Clean
flutter clean
flutter pub get
```

---

## 📝 Key Files

| File | LOC | Purpose |
|------|-----|---------|
| `trading_provider.dart` | 1000+ | Core trading logic |
| `candlestick_chart.dart` | 1800+ | Professional chart |
| `main.dart` | 70 | App entry + theme |
| `markets.dart` | 300+ | Asset definitions |
| `trade_screen.dart` | 500+ | Trading terminal |

---

## 🔍 For More Details

See **COMPLETE_ARCHITECTURE.md** (full 2000+ line documentation)

