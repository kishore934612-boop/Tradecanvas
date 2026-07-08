# Real-Time Crypto Price Alternatives for Web Platform

## The Problem

Flutter Web apps face **CORS (Cross-Origin Resource Sharing)** restrictions:
- Browsers block direct WebSocket connections to external APIs
- Binance WebSocket (`wss://stream.binance.com`) is blocked
- Result: No real-time crypto prices on web platform

## Available Alternatives

### ✅ **Option 1: REST API via CORS Proxy** (IMPLEMENTED)

**What**: Use Binance REST API through a public CORS proxy

**How it works:**
```
Flutter Web → CORS Proxy (corsproxy.io) → Binance REST API
```

**Pros:**
- ✅ Simple to implement
- ✅ No backend infrastructure needed
- ✅ Works immediately
- ✅ Same approach as Yahoo Finance
- ✅ Real prices (not simulated)

**Cons:**
- ⚠️ Slower than WebSocket (4s polling vs 1-2s real-time)
- ⚠️ Depends on third-party proxy (corsproxy.io)
- ⚠️ Higher latency

**Implementation:**
```dart
// Web: Route through CORS proxy
final baseUrl = kIsWeb 
    ? 'https://corsproxy.io/?https://api.binance.com'
    : 'https://api.binance.com';

// Fetch every 4 seconds
final response = await http.get(
  Uri.parse('$baseUrl/api/v3/ticker/24hr'),
);
```

**Status:** ✅ **IMPLEMENTED IN THIS SESSION**

---

### Option 2: Your Own Backend Proxy (Best for Production)

**What**: Deploy your own server to proxy WebSocket/REST requests

**Architecture:**
```
Flutter Web → Your Backend → Binance WebSocket/REST
           (Node.js/Python/Go)
```

**Pros:**
- ✅ Full control over infrastructure
- ✅ Can use WebSocket on backend → real-time
- ✅ No third-party dependency
- ✅ Can add caching, rate limiting, authentication
- ✅ Better reliability

**Cons:**
- ⚠️ Requires backend development
- ⚠️ Hosting costs
- ⚠️ Maintenance overhead

**Implementation Example (Node.js):**
```javascript
// server.js
const WebSocket = require('ws');
const express = require('express');
const app = express();

// Connect to Binance WebSocket
const binanceWs = new WebSocket('wss://stream.binance.com:9443/stream?streams=...');

// Serve WebSocket to Flutter clients
const wss = new WebSocket.Server({ server: app.listen(3000) });

wss.on('connection', (clientWs) => {
  // Forward Binance data to Flutter clients
  binanceWs.on('message', (data) => {
    clientWs.send(data);
  });
});
```

**Then in Flutter:**
```dart
// Connect to your backend instead of Binance directly
final uri = Uri.parse('wss://your-backend.com/crypto-prices');
_cryptoChannel = WebSocketChannel.connect(uri);
```

**Status:** ❌ Not implemented (requires backend setup)

---

### Option 3: Alternative CORS Proxies

**What**: Use different public CORS proxy services

**Options:**
1. **corsproxy.io** ✅ (currently using)
2. **allorigins.win** - `https://api.allorigins.win/raw?url=`
3. **cors-anywhere** - Self-hostable: `https://github.com/Rob--W/cors-anywhere`
4. **codetabs.com** - `https://api.codetabs.com/v1/proxy?quest=`

**How to switch:**
```dart
// In _fetchBinancePrices()
final baseUrl = kIsWeb 
    ? 'https://api.allorigins.win/raw?url=https://api.binance.com'  // Alternative
    : 'https://api.binance.com';
```

**Status:** ℹ️ Easy to switch if current proxy fails

---

### Option 4: Firebase Realtime Database / Cloud Functions

**What**: Use Firebase to fetch and cache prices

**Architecture:**
```
Binance → Firebase Cloud Function → Realtime DB → Flutter Web
         (runs every 4s)                         (real-time listener)
```

**Pros:**
- ✅ Google infrastructure (reliable)
- ✅ Real-time updates to all clients
- ✅ Automatic scaling
- ✅ Generous free tier

**Cons:**
- ⚠️ Firebase setup required
- ⚠️ Costs at scale
- ⚠️ Cloud Function cold starts

**Implementation:**
```javascript
// Firebase Cloud Function (scheduled every 4s)
exports.updateCryptoPrices = functions.pubsub
  .schedule('every 4 seconds')
  .onRun(async (context) => {
    const prices = await fetch('https://api.binance.com/api/v3/ticker/24hr');
    await admin.database().ref('crypto-prices').set(prices);
  });
```

```dart
// Flutter
FirebaseDatabase.instance.ref('crypto-prices').onValue.listen((event) {
  final prices = event.snapshot.value;
  // Update UI
});
```

**Status:** ❌ Not implemented (requires Firebase setup)

---

### Option 5: Supabase / Appwrite Backend

**What**: Use BaaS (Backend-as-a-Service) with edge functions

**Similar to Firebase but open-source alternatives:**
- Supabase Edge Functions
- Appwrite Functions
- AWS Lambda + API Gateway

**Status:** ❌ Not implemented

---

### Option 6: CoinGecko / CoinMarketCap API

**What**: Use dedicated crypto price APIs

**Pros:**
- ✅ Built for crypto data
- ✅ Usually CORS-friendly
- ✅ Additional data (market cap, volume, etc.)

**Cons:**
- ⚠️ Rate limits on free tier
- ⚠️ May require API key
- ⚠️ Costs for high-frequency updates

**CoinGecko Example:**
```dart
// Free API - rate limited
final response = await http.get(
  Uri.parse('https://api.coingecko.com/api/v3/simple/price?ids=bitcoin,ethereum&vs_currencies=usd&include_24hr_change=true'),
);
```

**Status:** ❌ Not implemented (consider for future)

---

### Option 7: Server-Sent Events (SSE)

**What**: Use SSE instead of WebSocket

**Pros:**
- ✅ Better CORS support than WebSocket
- ✅ Automatic reconnection
- ✅ Works over HTTP/HTTPS

**Cons:**
- ⚠️ One-way (server → client only)
- ⚠️ Still requires backend

**Status:** ❌ Not implemented

---

## Current Implementation (After This Session)

### Mobile/Desktop Platform:
```
Binance WebSocket → TradingProvider → UI
(Real-time, 1-2s updates)
```

### Web Platform:
```
Binance REST API → CORS Proxy (corsproxy.io) → TradingProvider → UI
(Polling every 4s)
```

### Architecture:
```dart
if (kIsWeb) {
  // Web: Use REST API via CORS proxy
  final binanceData = await _fetchBinancePrices();
  // Polled every 4 seconds
} else {
  // Mobile: Use WebSocket (real-time)
  // Data already in _prices from WebSocket stream
}
```

## Comparison Table

| Solution | Latency | Reliability | Cost | Setup Complexity | Production Ready |
|----------|---------|-------------|------|------------------|------------------|
| **CORS Proxy (current)** | 4s | Medium | Free | ⭐ Easy | ⚠️ OK for MVP |
| Own Backend Proxy | 1-2s | High | $5-20/mo | ⭐⭐⭐ Complex | ✅ Yes |
| Alternative CORS Proxy | 4s | Medium | Free | ⭐ Easy | ⚠️ OK for MVP |
| Firebase Functions | 4s | High | $0-50/mo | ⭐⭐ Medium | ✅ Yes |
| Supabase/Appwrite | 4s | High | $0-25/mo | ⭐⭐ Medium | ✅ Yes |
| CoinGecko API | 60s+ | High | $0-130/mo | ⭐ Easy | ⚠️ Rate limited |
| SSE Backend | 1-2s | High | $5-20/mo | ⭐⭐⭐ Complex | ✅ Yes |

## Recommendations

### For Development/MVP (Current): ✅
**Use CORS Proxy (corsproxy.io)**
- Already implemented
- Good enough for testing and MVP
- Easy to switch later

### For Production: 🎯
**Option A: Deploy Your Own Backend Proxy**
- Best performance (WebSocket on backend)
- Full control
- Can add features (caching, analytics, rate limiting)

**Option B: Firebase Cloud Functions + Realtime DB**
- Easier than custom backend
- Google infrastructure
- Good for small-medium scale

### For Quick Production Fix: 🚀
**Use Paid CORS Proxy Service**
- https://cors.sh (paid, reliable)
- https://crossorigin.me (deprecated but stable)
- Deploy cors-anywhere on Heroku/Railway (free tier)

## Migration Path

**Current (MVP):** CORS Proxy → Good for testing ✅

**Phase 1 (Production):** Own backend proxy or Firebase Functions → Better reliability 🎯

**Phase 2 (Scale):** Dedicated infrastructure with caching/CDN → Best performance 🚀

## Next Steps

1. **Test current implementation** (CORS proxy)
2. **Monitor reliability** - does corsproxy.io stay up?
3. **If issues occur** - switch to alternative proxy immediately
4. **For production** - plan backend deployment (1-2 weeks)

---

**Status:** ✅ Web platform now has real-time crypto prices via Binance REST API + CORS proxy
**Performance:** 4-second updates (vs 1-2s on mobile)
**Cost:** Free
**Production Ready:** OK for MVP, needs backend for production scale
