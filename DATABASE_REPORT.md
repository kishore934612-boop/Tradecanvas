# TradeVerse (Charty) — Complete Local Database & Storage Report

A complete technical specification of the current local database and persistence architecture, detailing stored data, tables, columns, indexes, data types, and key-value storage mechanisms.

---

## 🏗️ Storage Architecture Overview

The app operates on a **100% offline-first local database model**. All data is stored locally on the user's device across two primary storage engines:

```
                  ┌───────────────────────────────────────────┐
                  │          TradeVerse App Layer             │
                  └─────────────────────┬─────────────────────┘
                                        │
             ┌──────────────────────────┴──────────────────────────┐
             ▼                                                     ▼
┌─────────────────────────┐                             ┌─────────────────────────┐
│ SQLite Database Engine  │                             │   Key-Value Storage     │
│   (charty_local.db)     │                             │   (SharedPreferences)   │
└────────────┬────────────┘                             └────────────┬────────────┘
             │                                                     │
   ├── watchlist                                         ├── @charty_appstate
   ├── drawings                                          └── kline_cache:<symbol>:<interval>
   ├── chart_prefs                                           (Up to 500 OHLCV candles)
   ├── profiles
   └── settings
```

---

## 1. SQLite Database (`charty_local.db`)

* **Database Name**: `charty_local.db`
* **Schema Version**: `3`
* **Access Layer**: `SqliteDbHelper` (`sqflite` for Android/iOS/Desktop, with FFI/In-Memory fallback for Web).

### 📋 Table 1: `watchlist`
Stores the user's custom market watchlist items and their drag-and-drop display order.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `TEXT` | `PRIMARY KEY (1/2)` | Scoped to `'guest'` |
| `symbol` | `TEXT` | `PRIMARY KEY (2/2)` | Trading pair symbol (e.g. `'BTCUSDT'`) |
| `display_order` | `INTEGER` | `NOT NULL DEFAULT 0` | Sort order index |
| `created_at` | `TEXT` | `NOT NULL` | ISO 8601 creation timestamp |

* **Indexes**: `idx_watchlist_user` on `watchlist(user_id)`

---

### 🎨 Table 2: `drawings`
Stores technical chart drawings and measurement tools. Anchors are stored in **data space** (Price + Timestamp), so drawings automatically re-project across pan, zoom, and timeframe changes.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `drawing_id` | `TEXT` | `PRIMARY KEY` | Unique UUID string |
| `user_id` | `TEXT` | `NOT NULL` | Scoped to `'guest'` |
| `symbol` | `TEXT` | `NOT NULL` | Instrument symbol (e.g. `'ETHUSDT'`) |
| `tool` | `TEXT` | `NOT NULL` | Tool ID (`trendline`, `ray`, `arrow`, `horizontalLine`, `verticalLine`, `rectangle`, `fibRetracement`, `text`, `measurement`) |
| `anchors` | `TEXT` | `NOT NULL` | JSON array of coordinates `[{"t": timestamp_ms, "p": price}]` |
| `color` | `INTEGER` | `NOT NULL` | Line color stored as ARGB integer |
| `stroke_width` | `REAL` | `NOT NULL DEFAULT 1.5` | Line thickness in pixels |
| `text` | `TEXT` | `NULLABLE` | Text label content for text annotation tool |
| `created_at` | `INTEGER` | `NOT NULL` | Creation timestamp in epoch milliseconds |

* **Indexes**: `idx_drawings_user_symbol` on `drawings(user_id, symbol)`

---

### 📈 Table 3: `chart_prefs`
Stores per-symbol chart settings so every chart reopens exactly as it was left.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `TEXT` | `PRIMARY KEY (1/2)` | Scoped to `'guest'` |
| `symbol` | `TEXT` | `PRIMARY KEY (2/2)` | Symbol (e.g. `'SOLUSDT'`) |
| `timeframe` | `TEXT` | `NOT NULL` | Active interval (`'1m'`, `'5m'`, `'15m'`, `'1h'`, `'4h'`, `'1d'`) |
| `indicators` | `TEXT` | `NULLABLE` | JSON array of active indicators (`["ema", "rsi", "volume"]`) |
| `chart_type` | `TEXT` | `NOT NULL DEFAULT 'candles'` | Chart style (`candles`, `line`, `baseline`, `area`, `volumeCandles`) |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 update timestamp |

* **Indexes**: `idx_chart_prefs_user` on `chart_prefs(user_id)`

---

### 👤 Table 4: `profiles`
Stores the local user profile metadata.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `TEXT` | `PRIMARY KEY` | `'guest'` |
| `display_name` | `TEXT` | `NULLABLE` | User display name |
| `email` | `TEXT` | `NULLABLE` | Profile label string |
| `photo_url` | `TEXT` | `NULLABLE` | Profile avatar URL |
| `country` | `TEXT` | `NULLABLE` | Selected country |
| `joined_at` | `TEXT` | `NOT NULL` | ISO timestamp when first run |
| `last_login` | `TEXT` | `NOT NULL` | ISO timestamp of last session |
| `account_type` | `TEXT` | `NOT NULL` | Account type (`'Registered'` / `'Guest'`) |

---

### ⚙️ Table 5: `settings`
Stores fallback system settings for backward compatibility.

| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `user_id` | `TEXT` | `PRIMARY KEY` | `'guest'` |
| `theme` | `TEXT` | `NOT NULL DEFAULT 'dark'` | Theme ID |
| `theme_index` | `INTEGER` | `NOT NULL DEFAULT 0` | Theme numeric index |
| `language` | `TEXT` | `NOT NULL DEFAULT 'en'` | App language locale |
| `chart_type` | `TEXT` | `NOT NULL DEFAULT 'candles'` | Global fallback chart style |
| `default_timeframe` | `TEXT` | `NOT NULL DEFAULT '1h'` | Global fallback timeframe |
| `updated_at` | `TEXT` | `NOT NULL` | ISO 8601 timestamp |

---

## 2. Key-Value Storage (`SharedPreferences`)

Key-Value persistence manages global application state, preferences, and candle data caching.

### 📱 Key 1: `@charty_appstate` (Global App State & Settings)
Contains a JSON-encoded object storing:
* **`profile`**:
  * `onboarded` (`bool`): Whether the onboarding flow is completed.
  * `traderType` (`String`): Selected trader persona (`Scalp Trader`, `Intraday Trader`, `Swing Trader`, `Position Trader`).
  * `favoriteCoins` (`List<String>`): Top 5 favorite coin symbols (e.g. `['BTCUSDT', 'ETHUSDT', 'SOLUSDT']`).
  * `defaultTimeframe` (`String`): Default resolution when opening a new symbol chart (`'1h'`).
  * `chartType` (`String`): Default chart rendering type.
  * `gridVisibility` (`String`): Grid visibility preference (`'show'` vs `'hide'`).
  * `gridStyle` (`String`): Grid pattern (`'solid'`, `'dashed'`, `'dots'`).
  * `gridDensity` (`String`): Grid line density (`'fine'`, `'medium'`, `'coarse'`).
  * `customBullishColorValue` (`int`): ARGB hex value for bullish candles (default Neon Green `0xFF22C55E`).
  * `customBearishColorValue` (`int`): ARGB hex value for bearish candles (default Crimson Red `0xFFEF4444`).
  * `hapticsEnabled` (`bool`): Tactile haptic feedback toggle.
  * `showVolume` (`bool`): Whether to display volume sub-panel by default.
  * `rightOffsetPercent` (`double`): Future right margin percentage (`0.0` to `50.0%`).
  * `defaultIndicators` (`List<String>`): Default active indicator set (`['volume']`).
  * `favoriteDrawingTools` (`List<String>`): Up to 3 quick-action pinned drawing tools (`['trendline', 'horizontalLine', 'rectangle']`).
  * `sessionConfig`: Configurations for Market Session Overlays (Sydney, Tokyo, London, New York).
* **`themeMode`** (`int`): `ThemeMode.dark.index` vs `ThemeMode.light.index`.
* **`lastSymbol`** (`String`): Symbol last charted on the Chart screen (e.g. `'BTCUSDT'`).
* **`dashboardSymbol`** (`String`): Symbol currently previewed on the Dashboard tab.

---

### 📊 Key 2: `kline_cache:<SYMBOL>:<INTERVAL>` (Offline Candlestick Cache)
* **Key Format**: `kline_cache:BTCUSDT:1h`, `kline_cache:ETHUSDT:15m`, etc.
* **Capacity**: Caches up to **500 latest OHLCV candles** per series.
* **Content**: JSON array of candle objects:
  ```json
  [
    {
      "t": 1700000000000,
      "o": 36500.0,
      "h": 36800.0,
      "l": 36400.0,
      "c": 36750.0,
      "v": 1245.50
    }
  ]
  ```
* **Function**: Powers offline chart rendering and offline paper replay mode when internet connection is unavailable.
