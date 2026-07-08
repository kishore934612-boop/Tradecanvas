# Candlestick Chart — Complete Implementation Report
### TradeVerse · `lib/components/candlestick_chart.dart`

---

## 1. Overview

The TradeVerse candlestick chart is a **fully custom, zero-dependency** charting engine built on Flutter's low-level `CustomPainter` canvas API. It requires no third-party charting library and is self-contained in a single file: `lib/components/candlestick_chart.dart`.

The chart is integrated into the **Coin Detail Page** (`lib/screens/coin_detail_screen.dart`) as a compact embedded section, and expands into a **dedicated fullscreen screen** via a maximize button.

### Key capabilities

| Feature | Detail |
|---|---|
| Chart types | Candlestick, Area (line + gradient fill) |
| Timeframes | 1m, 5m, 15m, 1h, 4h, 1D |
| Panels | Price panel (top), Volume panel (bottom 18%) |
| Axes | Right Y-axis (price labels), Bottom X-axis (time labels) |
| Interaction | Horizontal pan, pinch-to-zoom, mouse-wheel zoom, tap/long-press crosshair |
| Crosshair | Dashed lines, OHLC info overlay, price tag on right axis |
| Performance | `RepaintBoundary` isolation, visible-range culling, `shouldRepaint` guard |
| Theme | Fully driven by `ThemePalette` — adapts to all 5 app themes and light/dark modes |

---

## 2. File Structure

```
lib/components/candlestick_chart.dart
│
├── CandleData                    ← OHLCV data model
├── generateOhlcData()            ← Synthetic candle data generator
├── _intervalMs()                 ← Timeframe → milliseconds
├── _formatTimestamp()            ← Timestamp → axis label string
├── _formatAxisPrice()            ← Price → formatted string (market-aware)
│
├── _PainterParams                ← Coordinate system + visible-range math
│   ├── candleCenterX()           ← Data index → pixel X
│   ├── fitPrice()                ← Price value → pixel Y
│   ├── fitVolume()               → Volume → bar height
│   ├── getCandleIndexFromOffset()← Pixel X → data index (touch inverse)
│   ├── firstVisibleIndex         ← Left boundary of visible window
│   └── lastVisibleIndex          ← Right boundary of visible window
│
├── _ChartPainter (CustomPainter)
│   ├── _drawBackground()
│   ├── _drawGrid()
│   ├── _drawTimeLabels()
│   ├── _drawPriceLabels()
│   ├── _drawVolumePanel()
│   ├── _drawCandles()
│   ├── _drawAreaChart()
│   ├── _drawCrosshair()
│   ├── _drawInfoOverlay()
│   └── _drawDashedLine()
│
└── CandlestickChart (StatefulWidget)
    ├── _CandlestickChartState
    │   ├── _buildParams()        ← Assembles _PainterParams from current state
    │   ├── _clampScroll()        ← Prevents over-scroll
    │   ├── _buildControls()      ← Timeframe pills + chart-type toggle
    │   ├── _buildGestureLayer()  ← All gesture detection
    │   └── _rebuildCandles()     ← Regenerates data on asset/timeframe change
    └── (public API: asset, currentPrice, height, showControls)
```

The integration layer in `coin_detail_screen.dart` adds:

```
_CompactChartSection      ← Embedded chart with live price header
_FullscreenLaunchButton   ← Expand icon → pushes fullscreen route
_FullscreenCandleScreen   ← Dedicated full-height chart screen
```

---

## 3. Data Layer

### 3.1 `CandleData`

```dart
class CandleData {
  final int    timestamp; // milliseconds since epoch
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isBullish => close >= open;
}
```

A simple immutable value object. `isBullish` drives color selection throughout the painter — green for `close >= open`, red otherwise.

### 3.2 `generateOhlcData(Asset asset, String timeframe, {int count = 120})`

Produces 120 synthetic OHLCV candles per asset + timeframe combination. The generator uses a **seeded** `Random` (`asset.symbol.hashCode ^ timeframe.hashCode`) so the same asset always shows the same chart shape, giving the appearance of historical data.

The price walk algorithm:

```
drift     = (rand − 0.495) × volatility × price × 0.6   // slight directional bias per step
amplitude = volatility × price × (0.4 + rand × 0.8)     // random candle body range
close     = clamp(open + drift, open − amplitude, open + amplitude)
high      = max(open, close) + highOffset                // upper wick extends beyond body
low       = min(open, close) − lowOffset                 // lower wick extends beyond body
```

Each candle's `open` equals the previous candle's `close`, forming a continuous chain. Timestamps are evenly spaced by `_intervalMs(timeframe)` backwards from `DateTime.now()`.

The data is regenerated (not cached) when the asset symbol or timeframe changes, keeping memory usage constant regardless of how many assets the user browses.

---

## 4. Coordinate System (`_PainterParams`)

This is the most critical part of the implementation. All five alignment bugs from the initial version traced back to an inconsistent coordinate system. The fixed model uses a single anchor:

### 4.1 Layout Regions

The total canvas height is divided into three stacked regions:

```
┌─────────────────────────────────────────────┬───────────┐
│                                             │           │
│           Price Panel  (priceH)             │  Right    │
│                                             │  Axis     │
│                                             │ (62 px)   │
├─────────────────────────────────────────────┤           │
│           Volume Panel (volumeH = 18%)      │           │
├─────────────────────────────────────────────┴───────────┤
│           Time Axis    (22 px)                          │
└─────────────────────────────────────────────────────────┘
```

```dart
const double _kRightAxisWidth    = 62.0;
const double _kBottomAxisHeight  = 22.0;
const double _kVolumeHeightFactor = 0.18;

chartWidth = totalWidth  − _kRightAxisWidth
volumeH    = totalHeight × 0.18
priceH     = totalHeight − volumeH − 22.0
```

### 4.2 X-Axis: Candle Positioning

The scroll model is **right-anchored**: `scrollOffset = 0` means the newest (last) candle sits with its centre at `chartWidth − candleWidth/2`. Older candles extend to the left. Panning right increases `scrollOffset`, revealing older candles.

**Centre X of candle at `dataIndex`:**

$$x = \underbrace{(chartWidth - \tfrac{candleWidth}{2})}_{\text{rightAnchor}} - (lastIndex - dataIndex) \times candleWidth + scrollOffset$$

Where `lastIndex = candles.length − 1`.

This formula has one correct inverse (used for touch-to-candle mapping):

$$dataIndex = lastIndex - \text{round}\!\left(\frac{rightAnchor + scrollOffset - x}{candleWidth}\right)$$

### 4.3 Y-Axis: Price Mapping

Price bounds (`minPrice`, `maxPrice`) are computed **only from the visible window** (candles between `firstVisibleIndex` and `lastVisibleIndex`) plus an 8% padding:

$$y_{pixel} = priceH \times \frac{maxPrice - price}{maxPrice - minPrice}$$

```dart
double fitPrice(double y) {
  if (maxPrice == minPrice) return priceHeight / 2;
  return priceHeight * (maxPrice - y) / (maxPrice - minPrice);
}
```

Top of panel (`y = 0`) = highest price. Bottom (`y = priceH`) = lowest price.

### 4.4 Visible Window Calculation

The visible index range is derived by inverting `candleCenterX`:

```dart
int get firstVisibleIndex {
  final raw = (candles.length - 1) -
      ((_rightAnchor + scrollOffset + candleWidth) / candleWidth).floor();
  return raw.clamp(0, candles.length - 1);
}

int get lastVisibleIndex {
  final raw = (candles.length - 1) -
      ((_rightAnchor + scrollOffset - chartWidth - candleWidth) / candleWidth).floor();
  return raw.clamp(0, candles.length - 1);
}
```

All drawing methods — candles, volume bars, time labels, and grid lines — iterate only `first..last`, not the full 120-candle dataset. This ensures:

1. Price bounds match exactly what is on screen
2. Time labels align to the candles they label
3. No off-screen drawing work is done

### 4.5 Scroll Clamping

```dart
void _clampScroll(double width) {
  final chartW    = width - _kRightAxisWidth;
  final maxScroll = max(0.0, candles.length * candleWidth - chartW + candleWidth);
  scrollOffset    = scrollOffset.clamp(0.0, maxScroll);
}
```

`scrollOffset` is bounded between `0` (newest candle at right edge) and `maxScroll` (oldest candle at left edge). Called after every pan, pinch, and zoom event.

---

## 5. Canvas Painter (`_ChartPainter`)

### 5.1 Paint Order

The `paint()` method calls draw routines in strict back-to-front z-order:

1. Background gradient
2. Grid (horizontal + vertical lines)
3. Time labels (X-axis)
4. Price labels (right Y-axis)
5. Volume bars
6. Candlesticks **or** Area chart (depending on `isArea`)
7. Crosshair + overlays (only when `selectedIndex != null`)

### 5.2 Background

A subtle vertical linear gradient from transparent to 6% card colour adds depth without obscuring candles:

```dart
shader: ui.Gradient.linear(
  Offset.zero,
  Offset(0, size.height),
  [colors.card.withValues(alpha: 0.0), colors.card.withValues(alpha: 0.06)],
)
```

### 5.3 Grid

**Horizontal lines** — 5 evenly-spaced lines across `priceH` at `y = priceH × i/4` for `i ∈ {0,1,2,3,4}`.

**Vertical lines** — candle-aligned, one every `max(1, (80 / candleWidth).round())` candles. Because they iterate the same index loop as the candles themselves, vertical grid lines always pass through candle centres regardless of zoom level or scroll position.

Grid stroke: `border.withValues(alpha: 0.35)`, width `0.5` — deliberately faint so candles remain the visual focus.

### 5.4 Time Labels

```dart
final candleInterval = max(1, (70.0 / candleWidth).round());
for (int i = first; i <= last; i++) {
  if (i % candleInterval != 0) continue;
  ...
}
```

Labels are snapped to **multiples of `candleInterval`** in absolute dataset index space. This means labels stay at fixed positions as the user scrolls — they don't drift or jump. The minimum pixel gap between labels is ~70px, automatically increasing when zoomed out.

Format by timeframe:
- `1m / 5m / 15m / 1h / 4h` → `HH:mm`
- `1D` → `D/M`

### 5.5 Price Labels

5 labels on the right axis at `y = priceH × i/4`:

$$price_i = minPrice + (maxPrice - minPrice) \times \frac{4 - i}{4}$$

Precision is market-aware: 4 decimal places for Forex, 0 for prices ≥ 1000, 2 for prices ≥ 10, 4 for micro-cap assets.

### 5.6 Volume Panel

Volume bars sit in the bottom 18% of the canvas (`baseY = priceH`). Bar height:

$$barHeight = volumeH \times \frac{volume}{maxVolume}$$

Bar width = `max(candleWidth × 0.6, 1.0)` so bars remain visible even at minimum zoom. Bullish candles → `positive` colour at 30% alpha; bearish → `negative` colour at 30% alpha.

### 5.7 Candlestick Rendering

For each visible candle:

**Wick** — a single vertical line from `fitPrice(high)` to `fitPrice(low)`, centred on `candleCenterX(i)`. Stroke width scales with zoom: `max(candleWidth × 0.1, 1.0)`.

**Body** — a filled rectangle:
- Top edge: `min(fitPrice(open), fitPrice(close))`
- Height: `max(bodyBottom − bodyTop, 1.5)` — minimum 1.5px to ensure doji candles are always visible
- Width: `max(candleWidth × 0.65, 2.0)`

Both wick and body use the same colour (`positive` / `negative` from `ThemePalette`), ensuring the wick is never a different colour than the body.

**Selected state** — an additional 1.5px stroke rectangle (selection ring) is drawn around the body when `i == selectedIndex`.

### 5.8 Area Chart

When `isArea = true`, candlesticks are replaced with a filled area chart:

1. A `Path` traces the close price across the visible window
2. A `fillPath` encloses the area to `priceH` (bottom of price panel)
3. Gradient fill: `lineColor` at 22% alpha fading to 0% at the bottom
4. A 1.8px stroke line is drawn on top
5. A selected dot (4px outer, 2px inner card-colour) marks the crosshair position

The `isBull` flag is computed from `candles.first.close` vs `candles.last.close` to colour the entire line green or red based on the overall direction of the visible history.

### 5.9 Crosshair

Triggered by tap or long-press. Renders:

**Dashed vertical line** — from top of price panel to bottom of volume panel, through `candleCenterX(selectedIndex)`.

**Dashed horizontal line** — across the full `chartWidth` at `fitPrice(close)`.

The dashed line renderer manually walks the path at fixed intervals:
```
dashLen = 4.0px,  gapLen = 3.0px
```

**Price tag** — a filled rounded rectangle on the right axis at the horizontal crosshair Y position. Background colour matches `positive`/`negative`. White price label centred inside.

**OHLC overlay** — a semi-transparent card (92% opacity) with a coloured border appears near the selected candle showing:

| Row | Label | Colour |
|---|---|---|
| 0 | O (open) | foreground |
| 1 | H (high) | positive |
| 2 | L (low) | negative |
| 3 | C (close) | foreground |

The overlay auto-flips left/right: if `candleCenterX + 10 + 90 > chartWidth`, it renders to the left of the candle instead.

---

## 6. Interaction Layer (`CandlestickChart`)

### 6.1 State Variables

```dart
String _tf           = '1h';          // active timeframe
bool   _isArea       = false;         // chart type toggle
double _candleWidth  = 8.0;           // current zoom level (px per candle slot)
double _scrollOffset = 0.0;           // pixels scrolled left from right-anchor
int?   _selectedIndex;                // crosshair target (null = no crosshair)
double _scaleStartWidth = 8.0;        // candleWidth at start of pinch gesture
```

### 6.2 Gesture Handling

All gestures are handled inside `_buildGestureLayer()` which wraps a `GestureDetector` in a `Listener`.

**Horizontal pan** (`onHorizontalDragUpdate`):
```dart
_scrollOffset -= delta.dx;  // drag finger left → scrollOffset increases → older candles appear
_clampScroll(w);
```

**Pinch-to-zoom** (`onScaleStart` / `onScaleUpdate`):
```dart
_candleWidth = (_scaleStartWidth * d.horizontalScale).clamp(3.0, 28.0);
```
`_scaleStartWidth` is captured on `onScaleStart` so the zoom is relative to the width at the start of the gesture, not the previous frame.

**Mouse wheel** (`Listener.onPointerSignal`):
```dart
final zoomFactor = scrollDelta.dy > 0 ? 0.9 : 1.1;
_candleWidth = (_candleWidth * zoomFactor).clamp(3.0, 28.0);
```
Scroll down = zoom out (smaller candles), scroll up = zoom in (larger candles).

**Long-press crosshair** (`onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd`):
- Start/move: calls `getCandleIndexFromOffset(localPosition.dx)` → sets `_selectedIndex`
- End: clears `_selectedIndex`

**Single tap** (`onTapDown` / `onTap`):
- `onTapDown`: shows crosshair at tapped candle
- `onTap`: clears crosshair (tap away to dismiss)

### 6.3 Zoom Bounds

```dart
static const double _minCandleW = 3.0;   // most zoomed out: very thin candles
static const double _maxCandleW = 28.0;  // most zoomed in: wide candles
```

At `_minCandleW = 3.0` with a 360px wide chart, ~100 candles are visible simultaneously. At `_maxCandleW = 28.0`, ~12 candles fill the viewport.

### 6.4 Timeframe Change

When the user taps a timeframe pill:

```dart
_tf = tf;
_rebuildCandles();   // generates new 120-candle dataset for this tf
_scrollOffset = 0.0; // snap back to newest candle at right edge
_selectedIndex = null;
```

Resetting `_scrollOffset` ensures the chart always loads showing the latest data.

### 6.5 `_buildParams()` — Two-Pass Pattern

Because `firstVisibleIndex` and `lastVisibleIndex` depend on `_PainterParams` fields (which require `minPrice`/`maxPrice` that depend on the visible range), `_buildParams` uses a two-pass approach:

**Pass 1** — Build a temporary `_PainterParams` with placeholder `minPrice = 0, maxPrice = 0` just to call `firstVisibleIndex` / `lastVisibleIndex`.

**Pass 2** — Iterate `first..last` to compute real `minPrice`, `maxPrice`, `maxVolume`. Build the final `_PainterParams` with correct bounds.

This avoids a circular dependency without requiring a separate range-calculation method.

---

## 7. Performance Strategy

### 7.1 `RepaintBoundary`

The `CustomPaint` canvas is wrapped in a `RepaintBoundary`:

```dart
RepaintBoundary(
  child: LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        width: w, height: h,
        child: _buildGestureLayer(w, h, colors),
      );
    },
  ),
),
```

This isolates the canvas from the rest of the widget tree. The live price header (`PriceStreamBuilder`) and timeframe controls rebuild independently on every price tick without triggering a canvas repaint.

### 7.2 `shouldRepaint` Guard

```dart
@override
bool shouldRepaint(covariant _ChartPainter old) =>
    old.p.scrollOffset  != p.scrollOffset  ||
    old.p.selectedIndex != p.selectedIndex ||
    old.p.candles       != p.candles       ||
    old.p.candleWidth   != p.candleWidth   ||
    old.p.isArea        != p.isArea;
```

The painter skips a full canvas redraw unless one of these five values has actually changed. In particular, price tick rebuilds that only update the header widget do **not** trigger a repaint of the chart canvas.

### 7.3 Visible-Range Culling

All drawing loops — `_drawCandles`, `_drawVolumePanel`, `_drawTimeLabels`, `_drawGrid` — iterate only `firstVisibleIndex..lastVisibleIndex`, not the full 120-candle array. Typically only 40–80 candles are visible at the default zoom, so at least 33–66% of the dataset is skipped entirely every frame.

### 7.4 Low-Allocation Rendering

- No `List.generate` or collection allocations inside `paint()`.
- `TextPainter` instances are created and immediately laid out and painted — not stored.
- `Paint` objects are created inline (Flutter recycles them via the canvas recording mechanism).
- Paths (`Path`, `fillPath` in area mode) are created once per `paint()` call with sequential `lineTo` operations — no intermediate point lists.

---

## 8. Theme Integration

The chart reads exclusively from `ThemePalette` (resolved via `AppColors.of(context)`) — it has no hardcoded colours. All 5 app themes (Classic, Sapphire, Emerald, Sunset, Amethyst) and both light/dark modes work automatically.

| Element | Palette field |
|---|---|
| Bullish candle / wick / volume bar | `colors.positive` |
| Bearish candle / wick / volume bar | `colors.negative` |
| Grid lines | `colors.border` |
| Axis labels | `colors.mutedForeground` |
| Background gradient | `colors.card` |
| OHLC overlay background | `colors.card` |
| OHLC overlay text | `colors.foreground` |
| Crosshair lines | `colors.mutedForeground` |
| Price tag background | `colors.positive` or `colors.negative` |
| Price tag text | `colors.card` |
| Active timeframe pill | `colors.positive` or `colors.negative` (based on price direction) |

---

## 9. Integration — Coin Detail Screen

The chart is embedded through three private widgets defined at the bottom of `coin_detail_screen.dart`.

### 9.1 `_CompactChartSection`

A `StatelessWidget` that subscribes to `PriceStreamBuilder` for the asset's symbol. On each price tick it provides a fresh `price` and `change` value to rebuild the header — but the chart canvas itself is insulated by `RepaintBoundary` and only repaints when scroll/zoom/timeframe state changes.

Layout:

```
_CompactChartSection
├── Row (header)
│   ├── Column
│   │   ├── Text "Price Chart"
│   │   └── Row
│   │       ├── Text (live price, 20px bold)
│   │       └── Container (% change badge, green/red background)
│   └── _FullscreenLaunchButton
└── GlassCard
    └── CandlestickChart(height: 240)
```

The `GlassCard` uses asymmetric padding (`fromLTRB(12, 12, 4, 10)`) — the reduced right padding of `4px` is intentional: since the right axis width is `62px` and is drawn *inside* the canvas, the chart visually aligns with the card's right edge without requiring extra outer padding.

### 9.2 `_FullscreenLaunchButton`

A simple `InkWell` + `Container` icon button in the top-right of the chart header. On tap, it pushes `_FullscreenCandleScreen` as a `fullscreenDialog` route (slide-up on iOS, fade on Android).

### 9.3 `_FullscreenCandleScreen`

A standalone `Scaffold` that re-uses `CandlestickChart` at 72% of screen height (`MediaQuery.of(context).size.height * 0.72`). It maintains its own `PriceStreamBuilder` subscription so the app bar displays a live-updating price and percentage badge independent of the compact chart section below.

The fullscreen chart is a completely separate `CandlestickChart` widget instance with its own `_CandlestickChartState` — scroll position, zoom, and selected candle are independent from the compact chart.

---

## 10. Alignment Bug Fixes (Change Log)

The initial implementation had five systematic alignment bugs, all fixed in the current version:

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | Candles shifted right by half a candle width | `candleCenterX` placed last candle at `chartWidth` (left edge of slot) instead of `chartWidth − candleWidth/2` (centre) | Added `_rightAnchor = chartWidth − candleWidth/2` as the base anchor |
| 2 | Touch → wrong candle selected | `getCandleIndexFromOffset` used a different formula than `candleCenterX`, so the inverse was incorrect | Rewrote as exact algebraic inverse of `candleCenterX` |
| 3 | Price axis didn't match visible candles | `_buildParams` computed min/max from a left-to-right slice derived from `startOffset / candleWidth`, which was inverted relative to the right-anchored coordinate system | Replaced with `firstVisibleIndex / lastVisibleIndex` computed directly from the right-anchored formula |
| 4 | Time labels misaligned with candles | Labels used `(candles.length − 1 − i) % interval` with full-dataset `i`, not the visible window | Changed to iterate `first..last` and snap to `i % candleInterval == 0` in absolute index space |
| 5 | Vertical grid lines detached from candle positions | Grid used an independent pixel-spacing loop unrelated to candle positions | Grid now iterates the same candle-index loop and places lines at `candleCenterX(i)` |

---

## 11. Public API

```dart
CandlestickChart({
  required Asset  asset,          // Asset definition (symbol, type, basePrice, volatility)
  required double currentPrice,   // Live price — drives accent colour (bull/bear)
  double  height       = 260.0,  // Canvas height in logical pixels
  bool    showControls = true,   // Whether to render the timeframe/mode control row
})
```

The widget is stateful and self-contained. It does not depend on any Provider or inherited state beyond `AppColors.of(context)` for theming.

---

## 12. Known Limitations & Future Considerations

| Item | Note |
|---|---|
| Data source | Currently uses seeded synthetic OHLC data. Can be swapped for real API data by replacing `generateOhlcData()` with an async fetch + `setState` pattern |
| Vertical zoom | Not implemented — only horizontal zoom (candle width) is supported |
| Technical indicators | No EMA, Bollinger Bands, RSI etc. Infrastructure exists in the coordinate system but indicator computation and drawing methods are not yet added |
| Date format | `1D` timeframe uses `D/M` format; does not adapt to locale |
| Accessibility | The canvas is not exposed to screen readers; no semantic labels on candle data |
| Real-time candle updates | The chart data is static after generation; the live price in the header updates but candles do not extend in real-time |
