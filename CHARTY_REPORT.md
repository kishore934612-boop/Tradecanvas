# TradeVerse (Charty) — Implemented Features Report

A comprehensive breakdown of all implemented technical tools, user customizations, and application preferences.

---

## 1. Technical Drawing & Analytical Tools

### 🎨 Drawing Tools (9 Interactive Tools)
Drawings are stored in **data-space coordinates** (Timestamp + Price), allowing them to automatically scale, pan, zoom, and persist accurately across timeframe switches and window resizes.

* **Trend Line**: Connects two price-time anchors for trend channel analysis.
* **Ray**: Radiates infinitely forward from an initial anchor point.
* **Arrow**: Directional trend line with customizable arrowhead dimensions.
* **Horizontal Line**: Key price level line spanning across the entire chart.
* **Vertical Line**: Time/Event marker across all price levels.
* **Rectangle**: Box tool for highlighting support/resistance zones and order blocks (supports fill color and opacity).
* **Fibonacci Retracement**: Multi-level ratio tool displaying `0.0`, `0.236`, `0.382`, `0.5`, `0.618`, `0.786`, and `1.0` retracement levels.
* **Text Annotation**: Custom text labels with configurable font size, background cards, and border styling.
* **Measurement Tool**: Dual-anchor box calculating price delta, percentage change, bar count, time duration, and aggregated volume.

### 🧲 Magnetic Snap Engine
* **OHLC Snapping**: Snaps drawing anchors to high, low, open, or close prices within a proximity threshold.
* **Timestamp Snapping**: Aligns anchors directly with candle timestamps.

### 📊 Technical Indicators (10 Built-In Indicators)
* **Overlay Indicators** (Rendered directly on price canvas):
  * **EMA (20)** — Exponential Moving Average
  * **SMA (50)** — Simple Moving Average
  * **VWAP** — Volume Weighted Average Price
  * **Bollinger Bands (20, 2)** — Volatility bands with upper/lower envelopes
  * **SuperTrend (10, 3)** — Trend direction and trailing stop indicator
* **Sub-Panel Indicators** (Rendered in separate bottom panels):
  * **Volume** — Bar volume with bullish/bearish color coding
  * **MACD (12, 26, 9)** — Moving Average Convergence Divergence with histogram & signal line
  * **RSI (14)** — Relative Strength Index with overbought (70) / oversold (30) levels
  * **ATR (14)** — Average True Range for volatility measurement
  * **Stochastic RSI** — K% & D% momentum oscillator

### 🔍 Smart Candle Insights & Analytics
* **Pattern Recognition**: Automated detection of classic candlestick patterns:
  * Bullish / Bearish Engulfing
  * Hammer & Shooting Star
  * Doji & Morning / Evening Star
* **Pivot Points & Key Levels**: Automatic calculation of Support (S1, S2) and Resistance (R1, R2) pivot levels.
* **Price Action Metrics**: Range analysis, body-to-wick ratios, and volume weight.

### ⏯️ Bar Replay Engine
* Historical backtesting / paper replay simulation.
* Controls: Play, Pause, Step Forward (1 bar), and Jump to specific historical candle.
* Adjustable Speed Settings: `0.5x`, `1.0x`, `2.0x`, `5.0x`.

### 🌍 Market Session Overlays
* Highlights major global trading sessions behind price candles:
  * **Sydney Session** (Purple overlay)
  * **Tokyo Session** (Blue overlay)
  * **London Session** (Green overlay)
  * **New York Session** (Orange/Gold overlay)
* Automatically converted from UTC to the user's local timezone.

---

## 2. Customizations

### 📈 Chart Render Styles (5 Visual Modes)
1. **Candlesticks**: Traditional hollow/filled OHLC body candles.
2. **Line Chart**: Smooth line connecting closing prices.
3. **Baseline Chart**: Highlights price performance above/below a custom reference baseline.
4. **Area Chart**: Gradient-filled area chart underneath closing prices.
5. **Volume-Weighted Candlesticks**: Candle body widths dynamically scale according to relative volume.

### 🎨 Color & Visual Palette
* **Custom Candle Colors**: Users can customize bullish and bearish candle colors (stored as ARGB hex values, defaulting to Neon Green `#22C55E` and Crimson Red `#EF4444`).
* **Grid Formatting**:
  * **Visibility**: Toggle Grid `Show` vs. `Hide`.
  * **Style Options**: `Solid`, `Dashed`, `Dotted`.
  * **Density Options**: `Fine`, `Medium`, `Coarse`.
* **Chart Right Margin / Future Offset**: Adjustable right margin space (`0%` to `50%` of chart width) for drawing forward projections into future time.

### 🛠️ Tool & Drawing Customization
* **Drawing Styling**: Adjust stroke thickness, line color, fill color, font size, background card toggles, and infinite/ray extensions.
* **Quick-Access Toolbar Favorites**: Select up to 3 preferred drawing tools to pin directly to the chart overlay for one-tap access.

---

## 3. Preferences & App Settings

### 📱 App Branding & Icons
* **Multi-Platform App Launcher Icons**: Native launcher icons generated across Android, iOS, and Web platforms using `assets/icon.png`.
* **Dashboard Header Branding**: Integrated `assets/icon.png` directly into the top navigation header on the main Dashboard screen.

### ⚙️ User Preferences & Defaults
* **Default Timeframe**: Configurable default resolution for new symbol charts (`1m`, `5m`, `15m`, `1h`, `4h`, `1d`).
* **Default Active Indicators**: Persisted set of default indicators applied when opening a chart.
* **Haptic & Feedback Preferences**: Toggle tactile haptic feedback for user interactions, tool selection, and gestures.
* **Trader Persona Profile**: Custom trader classification (Scalper, Intraday, Swing, Position trader) set during onboarding.

### 💾 Data Persistence & Storage
* **Local Database Engine**: Uses SQLite (`sqflite` / `sqflite_common_ffi`) for local watchlists, custom trendlines & drawing shapes, and saved chart preferences per symbol.
* **Key-Value Persistence**: SharedPreferences engine for application-wide theme settings, default timeframe, favorite tools, and user profile configuration.
* **Local Data Management**: Complete offline-first storage with explicit user controls to clear local data or reset chart state.

### 🎓 Interactive Onboarding Spotlight Tour
* Guided step-by-step interactive tour introducing chart gestures, indicator configuration, drawing tools, and symbol search.
