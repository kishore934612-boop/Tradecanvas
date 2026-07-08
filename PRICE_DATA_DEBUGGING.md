# TradeVerse Real-Time Price Data Flow — Debugging Guide

## Overview
This document explains how TradeVerse fetches and displays real-time price data, and how to debug issues with data switching between sources.

## Platform-Specific Behavior

### **Web Platform (Flutter Web)**
- **CORS Restrictions**: Browsers block direct API calls to Yahoo Finance
- **Solution**: Automatic CORS proxy (`corsproxy.io`) for stock/forex data
- **Binance**: REST API works directly (no CORS issues)
- **WebSocket**: Disabled on web (browsers have strict WebSocket CORS policies)

### **Mobile Platform (iOS/Android)**
- **No CORS**: Direct API calls work for all sources
- **WebSocket**: Enabled for crypto (real-time Binance WebSocket)

## Data Sources

### 1. **Crypto Prices** (8 assets: BTC, ETH, SOL, BNB, XRP, DOGE, ADA, AVAX)

**Mobile/Desktop:**
- **Source**: Binance WebSocket (`wss://stream.binance.com:9443/stream`)
- **Updates**: Real-time (1-2 seconds)
- **Data**: Ticker with price and 24h change
- **Tracked as**: `binance-ws`
- **Features**: Auto-reconnects on disconnect

**Web Platform:**
- **Source**: Binance REST API via CORS proxy (`corsproxy.io`)
- **Updates**: Polling every 4 seconds
- **Data**: 24hr ticker data
- **Tracked as**: `binance-rest`
- **Note**: WebSocket blocked by browser CORS policy

### 2. **Stock Prices** (6 assets: AAPL, NVDA, TSLA, TCS, RELIANCE, HDFCBANK)
- **Only source**: Yahoo Finance API
  - **Web**: `corsproxy.io` CORS proxy → `query1.finance.yahoo.com/v7/finance/quote`
  - **Mobile**: Direct → `query1.finance.yahoo.com/v7/finance/quote`
  - Polled every 4 seconds
  - Returns: `regularMarketPrice`, `preMarketPrice`, `postMarketPrice` depending on market state
  - Data source tracked as: `yahoo`
  - Market hours enforced:
    - US stocks: 09:30-16:00 ET (Mon-Fri)
    - Indian stocks: 09:15-15:30 IST (Mon-Fri)

### 3. **Forex Prices** (5 pairs: GBP/USD, EUR/USD, USD/JPY, USD/CAD, AUD/USD)
- **Only source**: Yahoo Finance API (same as stocks)
  - **Web**: Via CORS proxy
  - **Mobile**: Direct
  - Polled every 4 seconds
  - Data source tracked as: `yahoo`
  - Market hours: Sun 21:00 UTC – Fri 22:00 UTC

## Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  TradingProvider (lib/providers/trading_provider.dart)      │
│                                                              │
│  Timer (every 4s) → _updatePrices()                         │
│         │                                                    │
│         ├─→ _fetchBinancePrices() → REST API                │
│         │         (skipped if WebSocket active)             │
│         │                                                    │
│         └─→ _fetchYahooPrices() → REST API                  │
│                   (stocks + forex)                          │
│                                                              │
│  For each asset:                                            │
│    1. Check if real data available (from above sources)     │
│    2. Validate data freshness (< 120s age for open markets) │
│    3. Detect suspicious jumps (> 50% in 4s = stale data)    │
│    4. Track data source change (binance-ws → yahoo)         │
│    5. If no valid data + market closed → hold last price    │
│    6. If no valid data + market open → simulate price       │
│    7. Emit price update → priceUpdateStream                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  CandlestickChart (lib/components/candlestick_chart.dart)   │
│                                                              │
│  Subscribes to: provider.priceUpdateStream                  │
│         │                                                    │
│         └─→ _onPriceTick()                                  │
│               │                                              │
│               ├─ Check: !isMarketLive(asset) → return       │
│               ├─ Get: newPrice = provider.priceOf(symbol)   │
│               ├─ Update live candle OHLC                    │
│               └─ setState() → repaint chart                 │
└─────────────────────────────────────────────────────────────┘
```

## Common Issues & Solutions

### Issue 0: "Yahoo Finance not working on web" (CORS Error)

**Symptoms:**
- `[Yahoo] Fetch error: ClientException: Failed to fetch`
- Stocks/Forex show simulated prices only
- Works fine on mobile but fails on web

**Root Cause:**
- Browsers block cross-origin requests to Yahoo Finance (CORS policy)

**Solution (Already Implemented):**
- Web platform automatically uses CORS proxy: `corsproxy.io`
- Log will show: `[Yahoo] ✓ Fetched 11 quotes successfully (via CORS proxy)`
- If proxy fails, check:
  - Internet connectivity
  - Firewall not blocking `corsproxy.io`
  - Try different CORS proxy (alternatives: `allorigins.win`, `api.codetabs.com`)

### Issue 1: "Prices switching between old and new data"

**Symptoms:**
- Stock/forex prices jump between different values
- Chart shows price A, then B, then back to A

**Root Causes:**
1. **Yahoo API returning stale data** (regularMarketTime > 2 minutes ago)
   - System now rejects stale data during market hours
   - Check logs for: `[Yahoo] ⚠️ Rejecting stale data for <SYMBOL>`

2. **Market session detection wrong**
   - If market hours in `lib/utils/market_session.dart` are incorrect, the system might:
     - Reject valid data (thinking market is closed when it's open)
     - Accept stale data (thinking market is open when it's closed)
   - Check logs for: `[Price] 🔄 <SYMBOL> switched: yahoo -> simulation`

3. **Suspicious price jump detection**
   - If price changes > 50% in 4 seconds, data is rejected
   - This prevents displaying obviously stale/wrong data
   - Check logs for: `[Price] ⚠️ Rejecting suspicious jump for <SYMBOL>`

### Issue 2: "Crypto prices not updating"

**Root Causes:**
1. **WebSocket not connected**
   - Check logs for: `[Binance] ✓ WebSocket connected`
   - If missing, check network/firewall blocking WebSocket

2. **WebSocket connected but not receiving data**
   - Should see: `[Binance WS] BTC: <price>` every few seconds
   - If missing, Binance stream may be down

3. **Fallback to REST API not working**
   - Check logs for: `[Binance] Using WebSocket prices (REST skipped)` vs `[Binance] <SYMBOL> = $<price> (REST)`

### Issue 3: "Stock prices not updating during market hours"

**Root Causes:**
1. **Yahoo API rate limit** (429 error)
   - Asset list reduced to 14 total (9 stocks/forex) to avoid this
   - Check logs for: `[Yahoo] ⚠️ API error: HTTP 429`

2. **Market hours timezone issue**
   - US stocks use `UTC-4` (EDT) approximation
   - Indian stocks use `UTC+5:30` (IST)
   - Verify current UTC time matches expected market hours

3. **Yahoo returning invalid market state**
   - Check logs for: `[Yahoo] <SYMBOL> = $<price> (preMarket/regular/postMarket, age: <N>s, state: PRE/REGULAR/POST)`

## Debug Logging Guide

All enhanced logging is enabled in debug mode (`kDebugMode = true`).

### Key Log Patterns to Watch:

#### **Data source switching** (indicates root cause of "switching data"):
```
[Price] 🔄 AAPL switched: yahoo -> simulation (price: $221.3456)
```
This means Yahoo data became unavailable and system fell back to simulation.

#### **Stale data rejection**:
```
[Yahoo] ⚠️ Rejecting stale data for TSLA (age: 345s, market: open)
```
This means Yahoo returned data that's 345 seconds old — too stale to use.

#### **Price source confirmation** (every ~60s per asset):
```
[Price] BTC: $67234.5600 from binance-ws (change: +2.34%)
[Price] AAPL: $221.3456 from yahoo (change: -0.45%)
```

#### **Suspicious jump detection**:
```
[Price] ⚠️ Rejecting suspicious jump for NVDA: $500.00 -> $1000.00 (100.0%)
```

#### **Market closed behavior**:
```
[Price] AAPL: Market closed, holding last price
```

## Testing Checklist

### Before Market Hours:
1. Open TradeVerse
2. Navigate to stock detail screen (e.g., AAPL)
3. Check chart badge shows: **CLOSED**
4. Verify price is static (not moving)
5. Check logs: `[Price] AAPL: Market closed, holding last price`

### During Market Hours:
1. Navigate to stock detail screen
2. Check chart badge shows: **OPEN**
3. Verify price updates every 4-8 seconds
4. Check logs for regular: `[Yahoo] AAPL = $<price> (regular, age: <N>s, state: REGULAR)`
5. Check logs for no data switching: no `🔄` emoji

### If Data Switching Occurs:
1. Look for the `🔄` log line to see which sources are switching
2. Look backward for the reason:
   - Stale data rejection?
   - API error (HTTP 429, timeout)?
   - Market session detection error?
3. Verify Yahoo API response manually:
   ```powershell
   curl "https://query1.finance.yahoo.com/v7/finance/quote?symbols=AAPL"
   ```
4. Check `regularMarketTime` field in response — is it recent?

## Files to Check

| File | Purpose | What to Look For |
|------|---------|------------------|
| `lib/providers/trading_provider.dart` | Price fetching & management | `_updatePrices()`, `_fetchYahooPrices()`, `_fetchBinancePrices()` |
| `lib/utils/market_session.dart` | Market hours detection | `_stockSessionStatus()`, `_forexSessionStatus()` |
| `lib/components/candlestick_chart.dart` | Live candle updates | `_onPriceTick()` |
| `lib/constants/markets.dart` | Asset list & metadata | `assets` array, region fields |

## Recent Enhancements (This Session)

1. ✅ Added `_lastDataSource` tracking map to detect when prices switch between sources
2. ✅ Added detailed logging with emojis (🔄 ⚠️) for easier debugging
3. ✅ Improved Yahoo API to check `marketState` and use `preMarketPrice`/`postMarketPrice` when appropriate
4. ✅ Added freshness checking based on `regularMarketTime` field
5. ✅ Added suspicious jump detection (>50% in 4s)
6. ✅ Added better WebSocket logging for crypto
7. ✅ Increased log frequency from every 2min to every 1min for stocks during debugging

## Next Steps for User

1. **Run the app in debug mode**
2. **Navigate to a stock chart** (AAPL, NVDA, or TSLA)
3. **Watch the debug console** for 30-60 seconds
4. **Look for these specific patterns:**
   - Are you seeing `🔄` (data source switching)?
   - Are you seeing `⚠️ Rejecting stale data`?
   - What is the `age:` value in Yahoo logs?
   - Is `marketState:` showing the correct state (REGULAR when market is open)?
5. **Share the logs** showing the exact pattern when the issue occurs

The enhanced logging will now clearly show **why** the data is switching, allowing for targeted fixes.
