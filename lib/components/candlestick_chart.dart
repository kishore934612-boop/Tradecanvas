import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/market_session.dart';
import 'package:app/domain/repositories/market_repository.dart';
// Phase 6: Chart Engine
import 'package:app/engine/chart_controller.dart';
import 'package:app/core/logging/logger.dart';

// ============================================================
// SECTION 1 — DATA MODEL
// ============================================================

class CandleData {
  final int timestamp; // ms since epoch — start of the candle interval
  final double open;
  double high;
  double low;
  double close;
  double volume;
  bool isLive; // true only for the currently forming candle

  CandleData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.isLive = false,
  });

  bool get isBullish => close >= open;

  /// Apply a new tick to a live candle — updates close/high/low/volume in-place.
  void applyTick(double price, {double tickVolume = 0}) {
    close = price;
    if (price > high) high = price;
    if (price < low) low = price;
    volume += tickVolume;
  }

  CandleData copyWith({bool? isLive}) => CandleData(
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        isLive: isLive ?? this.isLive,
      );
}

// ============================================================
// SECTION 2 — INDICATOR MODEL
// ============================================================

enum IndicatorType { ema9, ema21, ema50, ema200, sma50, sma200, vwap, macd, volume }

class IndicatorConfig {
  final IndicatorType type;
  final bool enabled;
  const IndicatorConfig(this.type, {this.enabled = false});
  IndicatorConfig copyWithEnabled(bool v) => IndicatorConfig(type, enabled: v);
  Color color(ThemePalette p) {
    switch (type) {
      case IndicatorType.ema9:   return const Color(0xFFF59E0B);
      case IndicatorType.ema21:  return const Color(0xFF38BDF8);
      case IndicatorType.ema50:  return const Color(0xFFA78BFA);
      case IndicatorType.ema200: return const Color(0xFFFF6B6B);
      case IndicatorType.sma50:  return const Color(0xFF34D399);
      case IndicatorType.sma200: return const Color(0xFFE879F9);
      case IndicatorType.vwap:   return const Color(0xFFFFD700);
      case IndicatorType.macd:   return const Color(0xFF60A5FA);
      case IndicatorType.volume: return p.mutedForeground;
    }
  }
  String get label {
    switch (type) {
      case IndicatorType.ema9:   return 'EMA 9';
      case IndicatorType.ema21:  return 'EMA 21';
      case IndicatorType.ema50:  return 'EMA 50';
      case IndicatorType.ema200: return 'EMA 200';
      case IndicatorType.sma50:  return 'SMA 50';
      case IndicatorType.sma200: return 'SMA 200';
      case IndicatorType.vwap:   return 'VWAP';
      case IndicatorType.macd:   return 'MACD';
      case IndicatorType.volume: return 'Volume';
    }
  }
}

// ============================================================
// SECTION 3 — TRADE OVERLAY MODEL
// ============================================================

class TradeOverlay {
  final String positionId;
  final double entryPrice;
  final PositionSide side;
  final double? stopLoss;
  final double? takeProfit;
  final double? liquidationPrice;
  final double qty;
  const TradeOverlay({
    required this.positionId,
    required this.entryPrice,
    required this.side,
    required this.qty,
    this.stopLoss,
    this.takeProfit,
    this.liquidationPrice,
  });
}

// ============================================================
// SECTION 4 — OHLC FETCH SERVICE
// ============================================================

int _intervalMs(String tf) {
  switch (tf) {
    case '1m':  return 60 * 1000;
    case '5m':  return 5 * 60 * 1000;
    case '15m': return 15 * 60 * 1000;
    case '1h':  return 60 * 60 * 1000;
    case '4h':  return 4 * 60 * 60 * 1000;
    case '1D':  return 24 * 60 * 60 * 1000;
    default:    return 60 * 60 * 1000;
  }
}

String _binanceInterval(String tf) {
  switch (tf) {
    case '1m':  return '1m';
    case '5m':  return '5m';
    case '15m': return '15m';
    case '1h':  return '1h';
    case '4h':  return '4h';
    case '1D':  return '1d';
    default:    return '1h';
  }
}

String _yahooInterval(String tf) {
  switch (tf) {
    case '1m':  return '2m';   // Yahoo minimum is 2m for history
    case '5m':  return '5m';
    case '15m': return '15m';
    case '1h':  return '1h';
    case '4h':  return '1h';   // Yahoo has no 4h; use 1h
    case '1D':  return '1d';
    default:    return '1h';
  }
}

/// Yahoo Finance enforces strict range caps per interval:
///   2m/5m/15m/1h → max 60 days
///   1d            → max
String _yahooRange(String tf) {
  switch (tf) {
    case '1m':  return '7d';
    case '5m':  return '60d';
    case '15m': return '60d';
    case '1h':  return '60d';   // ← was 730d which Yahoo rejects for intraday
    case '4h':  return '60d';
    case '1D':  return '2y';
    default:    return '60d';
  }
}

/// Map an app symbol to the Binance USDT pair string (null = not available on Binance)
String? _toBinanceSymbol(String symbol) {
  const map = {
    'BTC': 'BTCUSDT', 'ETH': 'ETHUSDT', 'SOL': 'SOLUSDT',
    'BNB': 'BNBUSDT', 'XRP': 'XRPUSDT', 'DOGE': 'DOGEUSDT',
    'ADA': 'ADAUSDT', 'AVAX': 'AVAXUSDT',
  };
  return map[symbol];
}

/// Map an app symbol to its Yahoo Finance ticker
String _toYahooSymbol(String symbol) {
  const map = {
    // Indian stocks need .NS suffix on Yahoo
    'TCS':      'TCS.NS',
    'RELIANCE': 'RELIANCE.NS',
    'HDFCBANK': 'HDFCBANK.NS',
    // Forex — 5 pairs
    'GBP/USD': 'GBPUSD=X',
    'EUR/USD': 'EURUSD=X',
    'USD/JPY': 'USDJPY=X',
    'USD/CAD': 'USDCAD=X',
    'AUD/USD': 'AUDUSD=X',
    // US stocks map directly (AAPL, NVDA, TSLA) — no entry needed
  };
  return map[symbol] ?? symbol;
}

int _candleCountFor(String tf) {
  switch (tf) {
    case '1m':  return 1000;
    case '5m':  return 1000;
    case '15m': return 800;
    case '1h':  return 720;
    case '4h':  return 540;
    case '1D':  return 500;
    default:    return 720;
  }
}

/// Fetches OHLC candles from Binance (crypto) or Yahoo Finance (stocks/forex).
/// Returns an empty list on any failure — the chart falls back to synthetic data.
Future<List<CandleData>> fetchOhlcCandles(Asset asset, String tf,
    {int? limit, int? endTime}) async {
  try {
    final binSym = _toBinanceSymbol(asset.symbol);
    if (binSym != null) {
      return await _fetchBinanceKlines(
          binSym, tf, limit: limit ?? _candleCountFor(tf), endTime: endTime);
    } else {
      return await _fetchYahooOhlc(asset.symbol, tf);
    }
  } catch (e) {
    Logger.instance.error('[Chart] fetchOhlcCandles error', e);
    return [];
  }
}

Future<List<CandleData>> _fetchBinanceKlines(String binSymbol, String tf,
    {required int limit, int? endTime}) async {
  var url =
      'https://api.binance.com/api/v3/klines?symbol=$binSymbol&interval=${_binanceInterval(tf)}&limit=$limit';
  if (endTime != null) url += '&endTime=$endTime';

  final resp =
      await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
  if (resp.statusCode != 200) return [];
  final List<dynamic> raw = jsonDecode(resp.body);
  return raw.map((k) {
    return CandleData(
      timestamp: (k[0] as int),
      open:      double.parse(k[1].toString()),
      high:      double.parse(k[2].toString()),
      low:       double.parse(k[3].toString()),
      close:     double.parse(k[4].toString()),
      volume:    double.parse(k[5].toString()),
    );
  }).toList();
}

Future<List<CandleData>> _fetchYahooOhlc(String symbol, String tf) async {
  final ySym     = _toYahooSymbol(symbol);
  final interval = _yahooInterval(tf);
  final range    = _yahooRange(tf);

  // Yahoo Finance blocks direct browser fetch (CORS). On web we route through
  // a public CORS proxy; on mobile we hit Yahoo directly with required headers.
  //
  // We try two Yahoo hostnames — query1 is sometimes rate-limited, query2 is
  // the fallback. Both are official Yahoo Finance endpoints.
  const headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'application/json',
    'Accept-Language': 'en-US,en;q=0.9',
    'Origin': 'https://finance.yahoo.com',
    'Referer': 'https://finance.yahoo.com/',
  };

  // Build candidate URLs — direct on mobile, proxied on web
  List<String> candidates() {
    final path = '$ySym?interval=$interval&range=$range&includePrePost=false';
    final directQ1 = 'https://query1.finance.yahoo.com/v8/finance/chart/$path';
    final directQ2 = 'https://query2.finance.yahoo.com/v8/finance/chart/$path';
    // Public CORS proxy (web only fallback)
    final proxyQ1  = 'https://corsproxy.io/?${Uri.encodeComponent(directQ1)}';
    // On Flutter web, kIsWeb == true; on mobile both direct URLs work.
    if (kIsWeb) {
      return [proxyQ1, directQ1, directQ2];
    }
    return [directQ1, directQ2];
  }

  for (final url in candidates()) {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) continue;

      final Map<String, dynamic> body = jsonDecode(resp.body);

      // Yahoo returns an error field on bad requests
      final yahooError = body['chart']?['error'];
      if (yahooError != null) {
        Logger.instance.warning('[Chart] Yahoo error for $ySym $tf: $yahooError');
        continue;
      }

      final result = body['chart']?['result'];
      if (result == null || (result as List).isEmpty) continue;

      final chart      = result[0] as Map<String, dynamic>;
      final timestamps = (chart['timestamp'] as List?)?.cast<int>() ?? [];
      if (timestamps.isEmpty) continue;

      final q = chart['indicators']?['quote']?[0] as Map<String, dynamic>?;
      if (q == null) continue;

      final opens   = (q['open']   as List?)?.cast<num?>() ?? [];
      final highs   = (q['high']   as List?)?.cast<num?>() ?? [];
      final lows    = (q['low']    as List?)?.cast<num?>() ?? [];
      final closes  = (q['close']  as List?)?.cast<num?>() ?? [];
      final volumes = (q['volume'] as List?)?.cast<num?>() ?? [];

      final candles = <CandleData>[];
      for (int i = 0; i < timestamps.length; i++) {
        final o = opens.length  > i ? opens[i]?.toDouble()  : null;
        final h = highs.length  > i ? highs[i]?.toDouble()  : null;
        final l = lows.length   > i ? lows[i]?.toDouble()   : null;
        final c = closes.length > i ? closes[i]?.toDouble() : null;
        if (o == null || h == null || l == null || c == null) continue;
        if (h < l || o <= 0 || c <= 0) continue; // sanity check
        candles.add(CandleData(
          timestamp: timestamps[i] * 1000,
          open:   o, high: h, low: l, close: c,
          volume: (volumes.length > i ? volumes[i]?.toDouble() : null) ?? 0.0,
        ));
      }

      if (candles.isNotEmpty) return candles;
    } catch (e) {
      Logger.instance.warning('[Chart] Yahoo attempt failed ($url): $e');
      // Try next candidate
    }
  }

  // All attempts exhausted — caller will use synthetic fallback
  return [];
}

// ============================================================
// SECTION 5 — SYNTHETIC FALLBACK (debug / offline)
// ============================================================

List<CandleData> generateOhlcData(Asset asset, String tf) {
  final count      = _candleCountFor(tf);
  final intervalMs = _intervalMs(tf);
  final rand       = math.Random(asset.symbol.hashCode ^ tf.hashCode);
  final now        = DateTime.now().millisecondsSinceEpoch;
  final alignedNow = (now ~/ intervalMs) * intervalMs;
  final startMs    = alignedNow - intervalMs * (count - 1);

  double price = asset.basePrice;
  final vol    = asset.volatility;
  final result = <CandleData>[];
  for (int i = 0; i < count; i++) {
    final ts        = startMs + intervalMs * i;
    final drift     = (rand.nextDouble() - 0.495) * vol * price * 0.6;
    final open      = price;
    final amplitude = vol * price * (0.4 + rand.nextDouble() * 0.8);
    final highOff   = amplitude * (0.3 + rand.nextDouble() * 0.7);
    final lowOff    = amplitude * (0.3 + rand.nextDouble() * 0.7);
    final close     = (open + drift).clamp(open - amplitude, open + amplitude);
    result.add(CandleData(
      timestamp: ts,
      open:   open,
      high:   math.max(open, close) + highOff,
      low:    math.min(open, close) - lowOff,
      close:  close,
      volume: (rand.nextDouble() * 0.8 + 0.2) * 1000.0 * price,
    ));
    price = close;
  }
  return result;
}

// ============================================================
// SECTION 6 — INDICATOR COMPUTATION
// ============================================================

List<double?> _calcEma(List<CandleData> candles, int period) {
  if (candles.length < period) return List.filled(candles.length, null);
  final k      = 2.0 / (period + 1);
  final result = List<double?>.filled(candles.length, null);
  double ema   = candles.take(period).map((c) => c.close).reduce((a, b) => a + b) / period;
  result[period - 1] = ema;
  for (int i = period; i < candles.length; i++) {
    ema = candles[i].close * k + ema * (1 - k);
    result[i] = ema;
  }
  return result;
}

/// Simple Moving Average — unweighted mean of the last [period] closes.
List<double?> _calcSma(List<CandleData> candles, int period) {
  if (candles.length < period) return List.filled(candles.length, null);
  final result = List<double?>.filled(candles.length, null);
  // Seed with first window sum
  double windowSum = candles.take(period).fold(0.0, (s, c) => s + c.close);
  result[period - 1] = windowSum / period;
  for (int i = period; i < candles.length; i++) {
    windowSum += candles[i].close - candles[i - period].close;
    result[i] = windowSum / period;
  }
  return result;
}

/// VWAP — cumulative (typical price × volume) / cumulative volume.
/// Resets at each calendar day boundary so it behaves like exchange VWAP.
List<double?> _calcVwap(List<CandleData> candles) {
  final result = List<double?>.filled(candles.length, null);
  double cumPV = 0, cumVol = 0;
  int? lastDay;
  for (int i = 0; i < candles.length; i++) {
    final dt  = DateTime.fromMillisecondsSinceEpoch(candles[i].timestamp).toLocal();
    final day = dt.year * 1000 + dt.month * 32 + dt.day;
    if (day != lastDay) { cumPV = 0; cumVol = 0; lastDay = day; }
    final typical = (candles[i].high + candles[i].low + candles[i].close) / 3.0;
    cumPV  += typical * candles[i].volume;
    cumVol += candles[i].volume;
    result[i] = cumVol > 0 ? cumPV / cumVol : null;
  }
  return result;
}

/// MACD — returns (macdLine, signalLine, histogram).
/// Standard parameters: fast=12, slow=26, signal=9.
({List<double?> line, List<double?> signal, List<double?> hist})
    _calcMacd(List<CandleData> candles) {
  final ema12 = _calcEma(candles, 12);
  final ema26 = _calcEma(candles, 26);
  final n     = candles.length;

  // MACD line = EMA12 − EMA26
  final macdLine = List<double?>.filled(n, null);
  for (int i = 0; i < n; i++) {
    if (ema12[i] != null && ema26[i] != null) {
      macdLine[i] = ema12[i]! - ema26[i]!;
    }
  }

  // Signal line = EMA9 of MACD line
  final signalLine = List<double?>.filled(n, null);
  // find first non-null MACD value
  int firstMacd = n;
  for (int i = 0; i < n; i++) {
    if (macdLine[i] != null) { firstMacd = i; break; }
  }
  const sigPeriod = 9;
  if (n - firstMacd >= sigPeriod) {
    final k = 2.0 / (sigPeriod + 1);
    double sig = 0;
    for (int i = firstMacd; i < firstMacd + sigPeriod; i++) {
      sig += macdLine[i]!;
    }
    sig /= sigPeriod;
    signalLine[firstMacd + sigPeriod - 1] = sig;
    for (int i = firstMacd + sigPeriod; i < n; i++) {
      if (macdLine[i] == null) continue;
      sig = macdLine[i]! * k + sig * (1 - k);
      signalLine[i] = sig;
    }
  }

  // Histogram = MACD − Signal
  final hist = List<double?>.filled(n, null);
  for (int i = 0; i < n; i++) {
    if (macdLine[i] != null && signalLine[i] != null) {
      hist[i] = macdLine[i]! - signalLine[i]!;
    }
  }
  return (line: macdLine, signal: signalLine, hist: hist);
}

// ============================================================
// SECTION 7 — AXIS FORMATTING
// ============================================================

String _formatTimestamp(int ms, String tf) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  if (tf == '1D') {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month]} ${dt.day}';
  }
  return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

bool _isLabelBoundary(int ms, String tf) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
  switch (tf) {
    case '1m':
    case '5m':
    case '15m': return dt.minute == 0;
    case '1h':  return dt.minute == 0 && dt.hour % 4 == 0;
    case '4h':  return dt.hour == 0 && dt.minute == 0;
    case '1D':  return dt.weekday == DateTime.monday;
    default:    return dt.minute == 0 && dt.hour % 4 == 0;
  }
}

String _formatAxisPrice(double price, MarketType type) {
  if (price >= 10000) return price.toStringAsFixed(0);
  if (price >= 1000)  return price.toStringAsFixed(1);
  if (price >= 10)    return price.toStringAsFixed(2);
  return price.toStringAsFixed(4);
}

String _formatCountdown(int remainingMs) {
  if (remainingMs <= 0) return '00:00';
  final s = remainingMs ~/ 1000;
  final m = s ~/ 60;
  final h = m ~/ 60;
  if (h > 0) return '${h.toString().padLeft(2,'0')}:${(m % 60).toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';
  return '${m.toString().padLeft(2,'0')}:${(s % 60).toString().padLeft(2,'0')}';
}

// ============================================================
// SECTION 8 — PAINTER PARAMS (coordinate system)
// ============================================================

const double _kRightAxisWidth   = 68.0;
const double _kBottomAxisHeight = 24.0;
const double _kVolumeHeightFactor = 0.18;

/// Right-anchored coordinate model.
/// scrollOffset == 0  →  newest candle centre at  chartWidth − candleWidth/2
/// scrollOffset >  0  →  user has scrolled left (older candles visible)
class _PainterParams {
  final List<CandleData> candles;
  final double scrollOffset;
  final double candleWidth;
  final double chartWidth;
  final double chartHeight;
  final double volumeHeight;
  final double priceHeight;
  final double minPrice;
  final double maxPrice;
  final double maxVolume;
  final int? selectedIndex;
  final ThemePalette colors;
  final MarketType marketType;
  final bool isArea;
  final String timeframe;
  final double currentPrice;
  final double? prevClose;        // last closed candle close — drives price line colour
  // indicators
  final List<double?> ema9;
  final List<double?> ema21;
  final List<double?> ema50;
  final List<double?> ema200;
  final List<double?> sma50;
  final List<double?> sma200;
  final List<double?> vwap;
  final List<double?> macdLine;
  final List<double?> macdSignal;
  final List<double?> macdHist;
  final bool macdEnabled;          // drives extra MACD sub-panel height
  final Map<IndicatorType, bool> indicatorEnabled;
  final Map<IndicatorType, Color> indicatorColors;
  // overlays
  final List<TradeOverlay> tradeOverlays;
  final bool isLoading;
  final int countdownMs;
  final MarketStatus marketStatus;

  const _PainterParams({
    required this.candles,
    required this.scrollOffset,
    required this.candleWidth,
    required this.chartWidth,
    required this.chartHeight,
    required this.volumeHeight,
    required this.priceHeight,
    required this.minPrice,
    required this.maxPrice,
    required this.maxVolume,
    required this.selectedIndex,
    required this.colors,
    required this.marketType,
    required this.isArea,
    required this.timeframe,
    required this.currentPrice,
    required this.prevClose,
    required this.ema9,
    required this.ema21,
    required this.ema50,
    required this.ema200,
    required this.sma50,
    required this.sma200,
    required this.vwap,
    required this.macdLine,
    required this.macdSignal,
    required this.macdHist,
    required this.macdEnabled,
    required this.indicatorEnabled,
    required this.indicatorColors,
    required this.tradeOverlays,
    required this.isLoading,
    required this.countdownMs,
    required this.marketStatus,
  });

  double get _rightAnchor => chartWidth - candleWidth / 2;

  /// Height consumed by the MACD sub-panel (0 when disabled).
  double get macdPanelHeight => macdEnabled ? 70.0 : 0.0;

  /// Effective price panel height accounting for MACD panel.
  double get effectivePriceHeight => priceHeight - macdPanelHeight;

  double candleCenterX(int dataIndex) {
    final last = candles.length - 1;
    return _rightAnchor - (last - dataIndex) * candleWidth + scrollOffset;
  }

  double fitPrice(double y) {
    if (maxPrice == minPrice) return priceHeight / 2;
    return effectivePriceHeight * (maxPrice - y) / (maxPrice - minPrice);
  }

  double fitVolume(double v) {
    if (maxVolume == 0) return 0;
    return volumeHeight * (v / maxVolume).clamp(0.0, 1.0);
  }

  /// Maps a MACD value to a Y pixel within the MACD sub-panel.
  /// The sub-panel sits directly below the price panel.
  double fitMacd(double v, double maxAbs) {
    if (maxAbs == 0) return effectivePriceHeight + macdPanelHeight / 2;
    final centre = effectivePriceHeight + macdPanelHeight / 2;
    return centre - (v / maxAbs) * (macdPanelHeight / 2 - 4);
  }

  int? getCandleIndexFromOffset(double x) {
    if (candles.isEmpty) return null;
    final last = candles.length - 1;
    final raw  = last - ((_rightAnchor + scrollOffset - x) / candleWidth).round();
    if (raw < 0 || raw >= candles.length) return null;
    return raw;
  }

  int get firstVisibleIndex {
    if (candles.isEmpty) return 0;
    final raw = (candles.length - 1) -
        ((_rightAnchor + scrollOffset + candleWidth) / candleWidth).floor();
    return raw.clamp(0, candles.length - 1);
  }

  int get lastVisibleIndex {
    if (candles.isEmpty) return 0;
    final raw = (candles.length - 1) -
        ((_rightAnchor + scrollOffset - chartWidth - candleWidth) / candleWidth).floor();
    return raw.clamp(0, candles.length - 1);
  }
}

// ============================================================
// SECTION 9 — CHART PAINTER (layered rendering)
// ============================================================

class _ChartPainter extends CustomPainter {
  final _PainterParams p;

  // Reusable Paint objects — avoids per-frame allocation
  final _gridPaint     = Paint()..strokeWidth = 0.5;
  final _wickPaint     = Paint()..strokeWidth = 1.0;
  final _bodyPaint     = Paint();
  final _linePaint     = Paint()..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap  = StrokeCap.round;
  final _dashPaint     = Paint()..strokeWidth = 0.9
      ..style = PaintingStyle.stroke;

  _ChartPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    // Layer 1 – Background
    _drawBackground(canvas);
    // Layer 2 – Grid
    _drawGrid(canvas);
    _drawTimeLabels(canvas);
    _drawPriceLabels(canvas);
    // Layer 3 – Volume panel
    _drawVolumePanel(canvas);
    // Layer 4 – Indicator lines (under candles)
    _drawEmaLines(canvas);
    _drawSmaVwapLines(canvas);
    // Layer 4b – MACD sub-panel
    if (p.macdEnabled) _drawMacdPanel(canvas);
    // Layer 5 – Candles or Area
    if (p.isArea) {
      _drawAreaChart(canvas);
    } else {
      _drawCandles(canvas);
    }
    // Layer 6 – Trade overlays
    _drawTradeOverlays(canvas);
    // Layer 7 – Current price line
    _drawCurrentPriceLine(canvas);
    // Layer 8 – Countdown badge
    _drawCountdownBadge(canvas);
    // Layer 8b – Market status badge (when not open)
    if (!p.marketStatus.isLive) _drawMarketStatusBadge(canvas);
    // Layer 9 – Crosshair
    if (p.selectedIndex != null) _drawCrosshair(canvas, p.selectedIndex!);
    // Layer 10 – Loading indicator
    if (p.isLoading) _drawLoadingOverlay(canvas, Size(size.width, size.height));
  }

  // ── Background ─────────────────────────────────────────────
  void _drawBackground(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, p.chartWidth, p.priceHeight),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero, Offset(0, p.priceHeight),
          [p.colors.card.withValues(alpha: 0.0),
           p.colors.card.withValues(alpha: 0.06)],
        ),
    );
  }

  // ── Grid ───────────────────────────────────────────────────
  void _drawGrid(Canvas canvas) {
    _gridPaint.color = p.colors.border.withValues(alpha: 0.3);
    for (int i = 0; i <= 4; i++) {
      final y = p.effectivePriceHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(p.chartWidth, y), _gridPaint);
    }
    // MACD panel separator
    if (p.macdEnabled) {
      _gridPaint.color = p.colors.border.withValues(alpha: 0.5);
      canvas.drawLine(
        Offset(0, p.effectivePriceHeight),
        Offset(p.chartWidth, p.effectivePriceHeight),
        _gridPaint,
      );
    }
    final first = p.firstVisibleIndex;
    final last  = p.lastVisibleIndex;
    double lastX = double.negativeInfinity;
    for (int i = first; i <= last; i++) {
      if (!_isLabelBoundary(p.candles[i].timestamp, p.timeframe)) continue;
      final x = p.candleCenterX(i);
      if (x < 0 || x > p.chartWidth) continue;
      if (x - lastX < 40) continue;
      lastX = x;
      _gridPaint.color = p.colors.border.withValues(alpha: 0.3);
      canvas.drawLine(
          Offset(x, 0),
          Offset(x, p.effectivePriceHeight + p.macdPanelHeight + p.volumeHeight),
          _gridPaint);
    }
  }

  // ── Time labels ────────────────────────────────────────────
  void _drawTimeLabels(Canvas canvas) {
    final style = TextStyle(color: p.colors.mutedForeground,
        fontSize: 9.5, fontFamily: 'monospace');
    final first = p.firstVisibleIndex;
    final last  = p.lastVisibleIndex;
    double lastX = double.negativeInfinity;
    for (int i = first; i <= last; i++) {
      if (!_isLabelBoundary(p.candles[i].timestamp, p.timeframe)) continue;
      final x = p.candleCenterX(i);
      if (x < 0 || x > p.chartWidth) continue;
      if (x - lastX < 60) continue;
      lastX = x;
      final tp = _tp(_formatTimestamp(p.candles[i].timestamp, p.timeframe), style);
      tp.paint(canvas, Offset(x - tp.width / 2, p.effectivePriceHeight + p.macdPanelHeight + p.volumeHeight + 4));
    }
  }

  // ── Price labels ───────────────────────────────────────────
  void _drawPriceLabels(Canvas canvas) {
    final style = TextStyle(color: p.colors.mutedForeground,
        fontSize: 9.5, fontFamily: 'monospace');
    for (int i = 0; i <= 4; i++) {
      final price = p.minPrice + (p.maxPrice - p.minPrice) * (4 - i) / 4;
      final y     = p.effectivePriceHeight * i / 4;
      final tp    = _tp(_formatAxisPrice(price, p.marketType), style);
      tp.paint(canvas, Offset(p.chartWidth + 4, y - tp.height / 2));
    }
  }

  // ── Volume panel ───────────────────────────────────────────
  void _drawVolumePanel(Canvas canvas) {
    final baseY = p.effectivePriceHeight + p.macdPanelHeight;
    final first = p.firstVisibleIndex;
    final last  = p.lastVisibleIndex;
    for (int i = first; i <= last; i++) {
      final c    = p.candles[i];
      final x    = p.candleCenterX(i);
      final barH = p.fitVolume(c.volume);
      if (barH <= 0) continue;
      final barW = math.max(p.candleWidth * 0.6, 1.0);
      _bodyPaint.color = c.isBullish
          ? p.colors.positive.withValues(alpha: 0.28)
          : p.colors.negative.withValues(alpha: 0.28);
      canvas.drawRect(
          Rect.fromLTWH(x - barW / 2, baseY + p.volumeHeight - barH, barW, barH),
          _bodyPaint);
    }
  }

  // ── EMA lines ──────────────────────────────────────────────
  void _drawEmaLines(Canvas canvas) {
    void drawLine(List<double?> values, Color color) {
      final first = p.firstVisibleIndex;
      final last  = p.lastVisibleIndex;
      Path? path;
      for (int i = first; i <= last; i++) {
        final v = values.length > i ? values[i] : null;
        if (v == null) { path = null; continue; }
        final x = p.candleCenterX(i);
        final y = p.fitPrice(v);
        if (path == null) {
          path = Path()..moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      if (path != null) {
        _linePaint.color = color;
        canvas.drawPath(path, _linePaint);
      }
    }
    if (p.indicatorEnabled[IndicatorType.ema9] == true) {
      drawLine(p.ema9, p.indicatorColors[IndicatorType.ema9]!);
    }
    if (p.indicatorEnabled[IndicatorType.ema21] == true) {
      drawLine(p.ema21, p.indicatorColors[IndicatorType.ema21]!);
    }
    if (p.indicatorEnabled[IndicatorType.ema50] == true) {
      drawLine(p.ema50, p.indicatorColors[IndicatorType.ema50]!);
    }
    if (p.indicatorEnabled[IndicatorType.ema200] == true) {
      drawLine(p.ema200, p.indicatorColors[IndicatorType.ema200]!);
    }
  }

  // ── SMA + VWAP lines ───────────────────────────────────────
  void _drawSmaVwapLines(Canvas canvas) {
    void drawLine(List<double?> values, Color color) {
      final first = p.firstVisibleIndex;
      final last  = p.lastVisibleIndex;
      Path? path;
      for (int i = first; i <= last; i++) {
        final v = values.length > i ? values[i] : null;
        if (v == null) { path = null; continue; }
        final x = p.candleCenterX(i);
        final y = p.fitPrice(v);
        if (y < 0 || y > p.effectivePriceHeight) { path = null; continue; }
        if (path == null) { path = Path()..moveTo(x, y); }
        else              { path.lineTo(x, y); }
      }
      if (path != null) {
        _linePaint.color       = color;
        _linePaint.strokeWidth = 1.4;
        canvas.drawPath(path, _linePaint);
      }
    }

    if (p.indicatorEnabled[IndicatorType.sma50] == true) {
      drawLine(p.sma50, p.indicatorColors[IndicatorType.sma50]!);
    }
    if (p.indicatorEnabled[IndicatorType.sma200] == true) {
      drawLine(p.sma200, p.indicatorColors[IndicatorType.sma200]!);
    }
    if (p.indicatorEnabled[IndicatorType.vwap] == true) {
      drawLine(p.vwap, p.indicatorColors[IndicatorType.vwap]!);
    }
  }

  // ── MACD sub-panel ─────────────────────────────────────────
  void _drawMacdPanel(Canvas canvas) {
    final panelTop = p.effectivePriceHeight;
    final panelH   = p.macdPanelHeight;
    if (panelH <= 0) return;

    // Collect visible MACD values to find max-abs for scaling
    final first = p.firstVisibleIndex;
    final last  = p.lastVisibleIndex;
    double maxAbs = 0;
    for (int i = first; i <= last; i++) {
      final v = p.macdHist.length > i ? p.macdHist[i] : null;
      if (v != null && v.abs() > maxAbs) maxAbs = v.abs();
      final l = p.macdLine.length > i ? p.macdLine[i] : null;
      if (l != null && l.abs() > maxAbs) maxAbs = l.abs();
    }
    if (maxAbs == 0) maxAbs = 1;

    // Zero line
    final zeroY = p.fitMacd(0, maxAbs);
    _gridPaint.color = p.colors.border.withValues(alpha: 0.5);
    canvas.drawLine(Offset(0, zeroY), Offset(p.chartWidth, zeroY), _gridPaint);

    // MACD label
    final labelTp = _tp('MACD',
        TextStyle(color: p.colors.mutedForeground, fontSize: 8.5, fontFamily: 'monospace'));
    labelTp.paint(canvas, Offset(4, panelTop + 3));

    // Histogram bars
    for (int i = first; i <= last; i++) {
      final v = p.macdHist.length > i ? p.macdHist[i] : null;
      if (v == null) continue;
      final x    = p.candleCenterX(i);
      final barY = p.fitMacd(v, maxAbs);
      final barW = math.max(p.candleWidth * 0.6, 1.0);
      final top  = math.min(barY, zeroY);
      final h    = (barY - zeroY).abs().clamp(1.0, double.infinity);
      _bodyPaint.color = v >= 0
          ? p.colors.positive.withValues(alpha: 0.55)
          : p.colors.negative.withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTWH(x - barW / 2, top, barW, h), _bodyPaint);
    }

    // MACD line
    Path? macdPath;
    for (int i = first; i <= last; i++) {
      final v = p.macdLine.length > i ? p.macdLine[i] : null;
      if (v == null) { macdPath = null; continue; }
      final x = p.candleCenterX(i);
      final y = p.fitMacd(v, maxAbs);
      if (macdPath == null) { macdPath = Path()..moveTo(x, y); }
      else                  { macdPath.lineTo(x, y); }
    }
    if (macdPath != null) {
      _linePaint
        ..color       = p.indicatorColors[IndicatorType.macd] ?? const Color(0xFF60A5FA)
        ..strokeWidth = 1.2;
      canvas.drawPath(macdPath, _linePaint);
    }

    // Signal line
    Path? sigPath;
    for (int i = first; i <= last; i++) {
      final v = p.macdSignal.length > i ? p.macdSignal[i] : null;
      if (v == null) { sigPath = null; continue; }
      final x = p.candleCenterX(i);
      final y = p.fitMacd(v, maxAbs);
      if (sigPath == null) { sigPath = Path()..moveTo(x, y); }
      else                 { sigPath.lineTo(x, y); }
    }
    if (sigPath != null) {
      _linePaint
        ..color       = const Color(0xFFFF6B6B)
        ..strokeWidth = 1.2;
      canvas.drawPath(sigPath, _linePaint);
    }
  }

  // ── Candlesticks ───────────────────────────────────────────
  void _drawCandles(Canvas canvas) {
    final first = p.firstVisibleIndex;
    final last  = p.lastVisibleIndex;
    for (int i = first; i <= last; i++) {
      final c    = p.candles[i];
      final x    = p.candleCenterX(i);
      final sel  = i == p.selectedIndex;
      final col  = c.isBullish ? p.colors.positive : p.colors.negative;
      final openY  = p.fitPrice(c.open);
      final closeY = p.fitPrice(c.close);
      final highY  = p.fitPrice(c.high);
      final lowY   = p.fitPrice(c.low);
      // Wick
      _wickPaint
        ..color      = col.withValues(alpha: sel ? 1.0 : 0.75)
        ..strokeWidth = math.max(p.candleWidth * 0.1, 1.0);
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), _wickPaint);
      // Body
      final bodyTop = math.min(openY, closeY);
      final bodyH   = math.max((closeY - openY).abs(), 1.5);
      final bodyW   = math.max(p.candleWidth * 0.65, 2.0);
      _bodyPaint.color = col.withValues(alpha: sel ? 1.0 : 0.9);
      canvas.drawRect(Rect.fromLTWH(x - bodyW / 2, bodyTop, bodyW, bodyH), _bodyPaint);
      // Live candle pulse border
      if (c.isLive) {
        canvas.drawRect(
          Rect.fromLTWH(x - bodyW / 2 - 1, bodyTop - 1, bodyW + 2, bodyH + 2),
          Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 1.2,
        );
      }
      // Selection ring
      if (sel) {
        canvas.drawRect(
          Rect.fromLTWH(x - bodyW / 2 - 1.5, bodyTop - 1.5, bodyW + 3, bodyH + 3),
          Paint()..color = col..style = PaintingStyle.stroke..strokeWidth = 1.5,
        );
      }
    }
  }

  // ── Area chart ─────────────────────────────────────────────
  void _drawAreaChart(Canvas canvas) {
    if (p.candles.isEmpty) return;
    final isBull    = p.candles.last.close >= p.candles.first.close;
    final lineColor = isBull ? p.colors.positive : p.colors.negative;
    final first     = p.firstVisibleIndex;
    final last      = p.lastVisibleIndex;
    final path      = Path();
    final fillPath  = Path();
    bool started    = false;
    for (int i = first; i <= last; i++) {
      final x = p.candleCenterX(i);
      final y = p.fitPrice(p.candles[i].close);
      if (!started) {
        path.moveTo(x, y);
        fillPath.moveTo(x, p.priceHeight);
        fillPath.lineTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    if (!started) return;
    final lastX = p.candleCenterX(last);
    fillPath.lineTo(lastX, p.priceHeight);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, p.priceHeight),
          [lineColor.withValues(alpha: 0.22), lineColor.withValues(alpha: 0.0)])
      ..style = PaintingStyle.fill);
    _linePaint.color      = lineColor;
    _linePaint.strokeWidth = 1.8;
    canvas.drawPath(path, _linePaint);
    if (p.selectedIndex != null) {
      final si = p.selectedIndex!.clamp(first, last);
      final sx = p.candleCenterX(si);
      final sy = p.fitPrice(p.candles[si].close);
      canvas.drawCircle(Offset(sx, sy), 4.0, Paint()..color = lineColor);
      canvas.drawCircle(Offset(sx, sy), 2.0, Paint()..color = p.colors.card);
    }
  }

  // ── Trade overlays ─────────────────────────────────────────
  void _drawTradeOverlays(Canvas canvas) {
    for (final ov in p.tradeOverlays) {
      final isLong = ov.side == PositionSide.long;
      final entryY = p.fitPrice(ov.entryPrice);
      if (entryY >= 0 && entryY <= p.effectivePriceHeight) {
        final entryColor = isLong ? p.colors.positive : p.colors.negative;
        _drawOverlayLine(canvas, entryY, entryColor,
            '${isLong ? '▲ Long' : '▼ Short'}  ${_formatAxisPrice(ov.entryPrice, p.marketType)}');
      }
      if (ov.stopLoss != null) {
        final slY = p.fitPrice(ov.stopLoss!);
        if (slY >= 0 && slY <= p.effectivePriceHeight) {
          _drawOverlayLine(canvas, slY, p.colors.negative,
              'SL  ${_formatAxisPrice(ov.stopLoss!, p.marketType)}', dashed: true);
        }
      }
      if (ov.takeProfit != null) {
        final tpY = p.fitPrice(ov.takeProfit!);
        if (tpY >= 0 && tpY <= p.effectivePriceHeight) {
          _drawOverlayLine(canvas, tpY, p.colors.positive,
              'TP  ${_formatAxisPrice(ov.takeProfit!, p.marketType)}', dashed: true);
        }
      }
      if (ov.liquidationPrice != null && ov.liquidationPrice! > 0) {
        final liqY = p.fitPrice(ov.liquidationPrice!);
        if (liqY >= 0 && liqY <= p.effectivePriceHeight) {
          _drawOverlayLine(canvas, liqY, const Color(0xFFFF6B6B),
              'LIQ  ${_formatAxisPrice(ov.liquidationPrice!, p.marketType)}',
              dashed: true);
        }
      }
    }
  }

  void _drawOverlayLine(Canvas canvas, double y, Color color, String label,
      {bool dashed = false}) {
    _dashPaint.color = color.withValues(alpha: 0.8);
    if (dashed) {
      _drawDashedLine(canvas, Offset(0, y), Offset(p.chartWidth, y), _dashPaint);
    } else {
      canvas.drawLine(Offset(0, y), Offset(p.chartWidth, y), _dashPaint);
    }
    // Label badge
    final tp = _tp(label,
        TextStyle(color: p.colors.card, fontSize: 9.0, fontWeight: FontWeight.bold));
    tp.layout(maxWidth: _kRightAxisWidth + 40);
    final tagRect = Rect.fromLTWH(
        p.chartWidth + 2, y - tp.height / 2 - 3, _kRightAxisWidth - 4, tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
        Paint()..color = color);
    tp.paint(canvas, Offset(tagRect.left + 4, tagRect.top + 3));
  }

  // ── Current price line ─────────────────────────────────────
  void _drawCurrentPriceLine(Canvas canvas) {
    if (p.currentPrice <= 0) return;
    final y = p.fitPrice(p.currentPrice);
    if (y < 0 || y > p.effectivePriceHeight) return;
    final isUp = p.prevClose == null || p.currentPrice >= p.prevClose!;
    final col  = isUp ? p.colors.positive : p.colors.negative;
    _dashPaint.color = col.withValues(alpha: 0.65);
    _drawDashedLine(canvas, Offset(0, y), Offset(p.chartWidth, y), _dashPaint);
    // Price tag
    final label = _formatAxisPrice(p.currentPrice, p.marketType);
    final tp = _tp(label,
        TextStyle(color: p.colors.card, fontSize: 9.5,
            fontWeight: FontWeight.bold, fontFamily: 'monospace'));
    tp.layout();
    final tagW    = math.max(tp.width + 12, _kRightAxisWidth - 4);
    final tagRect = Rect.fromLTWH(
        p.chartWidth + 2, y - tp.height / 2 - 3, tagW, tp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
        Paint()..color = col);
    tp.paint(canvas,
        Offset(tagRect.left + (tagRect.width - tp.width) / 2, tagRect.top + 3));
  }

  // ── Countdown badge ────────────────────────────────────────
  void _drawCountdownBadge(Canvas canvas) {
    if (p.countdownMs <= 0) return;
    // Only show countdown when market is live
    if (!p.marketStatus.isLive) return;
    final label = _formatCountdown(p.countdownMs);
    final tp = _tp(label,
        TextStyle(color: p.colors.mutedForeground, fontSize: 9.0,
            fontFamily: 'monospace'));
    tp.layout();
    const px = 6.0; const py = 4.0;
    final bx = p.chartWidth - tp.width - px * 2 - 4;
    const by = 4.0;
    final bgRect = Rect.fromLTWH(bx, by, tp.width + px * 2, tp.height + py * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = p.colors.muted.withValues(alpha: 0.7));
    tp.paint(canvas, Offset(bx + px, by + py));
  }

  // ── Market status badge ────────────────────────────────────
  void _drawMarketStatusBadge(Canvas canvas) {
    final status = p.marketStatus;
    final Color bgColor;
    switch (status) {
      case MarketStatus.closed:     bgColor = p.colors.negative.withValues(alpha: 0.75); break;
      case MarketStatus.preMarket:  bgColor = const Color(0xFFE6A817).withValues(alpha: 0.85); break;
      case MarketStatus.afterHours: bgColor = const Color(0xFF6366F1).withValues(alpha: 0.85); break;
      default:                      return;
    }
    final label = status.label;
    final tp = _tp(label,
        TextStyle(color: Colors.white, fontSize: 9.0,
            fontWeight: FontWeight.bold, letterSpacing: 0.5));
    tp.layout();
    const px = 7.0; const py = 4.0;
    final bx = 6.0;
    const by = 6.0;
    final bgRect = Rect.fromLTWH(bx, by, tp.width + px * 2, tp.height + py * 2);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = bgColor);
    tp.paint(canvas, Offset(bx + px, by + py));
  }

  // ── Crosshair ──────────────────────────────────────────────
  void _drawCrosshair(Canvas canvas, int idx) {
    if (idx < 0 || idx >= p.candles.length) return;
    final c    = p.candles[idx];
    final x    = p.candleCenterX(idx);
    final midY = p.fitPrice(c.close);
    _dashPaint.color = p.colors.mutedForeground.withValues(alpha: 0.5);
    _drawDashedLine(canvas, Offset(x, 0), Offset(x, p.effectivePriceHeight + p.macdPanelHeight + p.volumeHeight), _dashPaint);
    _drawDashedLine(canvas, Offset(0, midY), Offset(p.chartWidth, midY), _dashPaint);
    // Price tag
    final ptLabel = _formatAxisPrice(c.close, p.marketType);
    final ptTp    = _tp(ptLabel,
        TextStyle(color: p.colors.card, fontSize: 9.5,
            fontWeight: FontWeight.bold, fontFamily: 'monospace'));
    ptTp.layout();
    final tagRect = Rect.fromLTWH(p.chartWidth + 2, midY - ptTp.height / 2 - 3,
        _kRightAxisWidth - 4, ptTp.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
        Paint()..color = (c.isBullish ? p.colors.positive : p.colors.negative));
    ptTp.paint(canvas,
        Offset(tagRect.left + (tagRect.width - ptTp.width) / 2, tagRect.top + 3));
    // OHLCV info card
    _drawInfoCard(canvas, c, x, midY);
  }

  void _drawInfoCard(Canvas canvas, CandleData c, double x, double y) {
    final bullCol  = p.colors.positive;
    final bearCol  = p.colors.negative;
    final fgCol    = p.colors.foreground;
    final isBull   = c.isBullish;
    final pctChange = c.open > 0 ? ((c.close - c.open) / c.open) * 100 : 0.0;
    final pctStr    = '${pctChange >= 0 ? '+' : ''}${pctChange.toStringAsFixed(2)}%';
    final dt        = DateTime.fromMillisecondsSinceEpoch(c.timestamp).toLocal();
    final dateStr   = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-'
        '${dt.day.toString().padLeft(2,'0')}  '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    final rows = [
      ('Date', dateStr,        fgCol),
      ('O',    _formatAxisPrice(c.open,   p.marketType), fgCol),
      ('H',    _formatAxisPrice(c.high,   p.marketType), bullCol),
      ('L',    _formatAxisPrice(c.low,    p.marketType), bearCol),
      ('C',    _formatAxisPrice(c.close,  p.marketType),
               isBull ? bullCol : bearCol),
      ('Chg',  pctStr, isBull ? bullCol : bearCol),
    ];
    const pad  = 8.0;
    const lineH = 16.0;
    final boxH  = rows.length * lineH + pad * 2;
    const boxW  = 160.0;
    double bx   = x + 12;
    if (bx + boxW > p.chartWidth - 4) bx = x - boxW - 12;
    bx = bx.clamp(2.0, p.chartWidth - boxW - 2);
    double by   = y - boxH / 2;
    by = by.clamp(2.0, p.effectivePriceHeight - boxH - 2);
    final boxRect = Rect.fromLTWH(bx, by, boxW, boxH);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(7)),
        Paint()..color = p.colors.card.withValues(alpha: 0.94));
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(7)),
        Paint()
          ..color = (isBull ? bullCol : bearCol).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8);
    for (int i = 0; i < rows.length; i++) {
      final (lbl, val, col) = rows[i];
      final labelTp = _tp(lbl,
          TextStyle(color: p.colors.mutedForeground, fontSize: 9.5, fontFamily: 'monospace'));
      final valTp   = _tp(val,
          TextStyle(color: col, fontSize: 9.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'));
      labelTp.layout();
      valTp.layout();
      final ry = by + pad + i * lineH;
      labelTp.paint(canvas, Offset(bx + pad, ry));
      valTp.paint(canvas, Offset(bx + boxW - valTp.width - pad, ry));
    }
  }

  // ── Loading overlay ────────────────────────────────────────
  void _drawLoadingOverlay(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, p.chartWidth, p.effectivePriceHeight),
        Paint()..color = p.colors.background.withValues(alpha: 0.6));
    final tp = _tp('Loading chart…',
        TextStyle(color: p.colors.mutedForeground, fontSize: 12.0));
    tp.layout();
    tp.paint(canvas, Offset(
        p.chartWidth / 2 - tp.width / 2, p.effectivePriceHeight / 2 - tp.height / 2));
  }

  // ── Helpers ────────────────────────────────────────────────
  TextPainter _tp(String text, TextStyle style) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr)..layout();

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dash = 4.0;
    const gap  = 3.0;
    final dx   = p2.dx - p1.dx;
    final dy   = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final ux = dx / dist;
    final uy = dy / dist;
    double t = 0;
    while (t < dist) {
      final s = Offset(p1.dx + ux * t, p1.dy + uy * t);
      t += dash;
      final e = Offset(p1.dx + ux * math.min(t, dist), p1.dy + uy * math.min(t, dist));
      canvas.drawLine(s, e, paint);
      t += gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) {
    return old.p.scrollOffset   != p.scrollOffset   ||
           old.p.candleWidth    != p.candleWidth     ||
           old.p.selectedIndex  != p.selectedIndex   ||
           old.p.candles        != p.candles         ||
           old.p.isArea         != p.isArea          ||
           old.p.currentPrice   != p.currentPrice    ||
           old.p.countdownMs    != p.countdownMs     ||
           old.p.isLoading      != p.isLoading       ||
           old.p.marketStatus   != p.marketStatus    ||
           old.p.tradeOverlays  != p.tradeOverlays;
  }
}

// ============================================================
// SECTION 10 — CANDLESTICK CHART WIDGET (stateful)
// ============================================================

class CandlestickChart extends StatefulWidget {
  final Asset asset;
  final double currentPrice;
  final double height;
  final bool showControls;
  /// Phase 6: Optional price stream — when provided the chart uses ChartController
  /// instead of reading directly from TradingProvider.
  final Stream<double>? priceStream;

  const CandlestickChart({
    super.key,
    required this.asset,
    required this.currentPrice,
    this.height = 260.0,
    this.showControls = true,
    this.priceStream,
  });

  @override
  State<CandlestickChart> createState() => _CandlestickChartState();
}

class _CandlestickChartState extends State<CandlestickChart> {
  // ── timeframe & mode ──────────────────────────────────────
  String _tf      = '1h';
  bool   _isArea  = false;

  // ── data ──────────────────────────────────────────────────
  List<CandleData> _candles     = [];
  bool             _isLoading   = false;
  bool             _isPaginating = false;

  // ── live candle ───────────────────────────────────────────
  StreamSubscription<String>? _priceSub;

  // Phase 6: ChartController — manages candle state independently
  ChartController? _chartController;

  // ── indicators ────────────────────────────────────────────
  List<double?> _ema9   = [];
  List<double?> _ema21  = [];
  List<double?> _ema50  = [];
  List<double?> _ema200 = [];
  List<double?> _sma50  = [];
  List<double?> _sma200 = [];
  List<double?> _vwap   = [];
  List<double?> _macdLine   = [];
  List<double?> _macdSignal = [];
  List<double?> _macdHist   = [];

  final Map<IndicatorType, IndicatorConfig> _indicators = {
    IndicatorType.ema9:   IndicatorConfig(IndicatorType.ema9),
    IndicatorType.ema21:  IndicatorConfig(IndicatorType.ema21),
    IndicatorType.ema50:  IndicatorConfig(IndicatorType.ema50),
    IndicatorType.ema200: IndicatorConfig(IndicatorType.ema200),
    IndicatorType.sma50:  IndicatorConfig(IndicatorType.sma50),
    IndicatorType.sma200: IndicatorConfig(IndicatorType.sma200),
    IndicatorType.vwap:   IndicatorConfig(IndicatorType.vwap),
    IndicatorType.macd:   IndicatorConfig(IndicatorType.macd),
    IndicatorType.volume: IndicatorConfig(IndicatorType.volume, enabled: true),
  };

  // ── viewport ──────────────────────────────────────────────
  double _candleWidth  = 8.0;
  double _scrollOffset = 0.0;
  int?   _selectedIndex;

  // ── gesture ───────────────────────────────────────────────
  double _scaleStartWidth = 8.0;

  // ── countdown ─────────────────────────────────────────────
  Timer?  _countdownTimer;
  int     _countdownMs = 0;

  // ── market status ─────────────────────────────────────────
  MarketStatus _marketStatus = MarketStatus.open;
  Timer?       _sessionTimer;

  static const List<String> _timeframes = ['1m','5m','15m','1h','4h','1D'];
  static const double _minCandleW = 2.5;
  static const double _maxCandleW = 30.0;

  @override
  void initState() {
    super.initState();
    _marketStatus = getMarketStatus(widget.asset);
    
    // Phase 6: Initialize ChartController if a price stream is provided
    if (widget.priceStream != null) {
      _chartController = ChartController(
        asset: widget.asset,
        initialTimeframe: _tf,
        priceStream: widget.priceStream,
      );
      // Listen to controller state updates
      _chartController!.addListener(_onControllerUpdate);
    }
    
    _loadCandles();
    _subscribeToPrice();
    _startCountdownTimer();
    _startSessionTimer();
  }

  @override
  void didUpdateWidget(covariant CandlestickChart old) {
    super.didUpdateWidget(old);
    if (old.asset.symbol != widget.asset.symbol) {
      _priceSub?.cancel();
      _marketStatus = getMarketStatus(widget.asset);
      
      // Phase 6: Recreate controller for new asset
      if (widget.priceStream != null) {
        _chartController?.removeListener(_onControllerUpdate);
        _chartController?.dispose();
        _chartController = ChartController(
          asset: widget.asset,
          initialTimeframe: _tf,
          priceStream: widget.priceStream,
        );
        _chartController!.addListener(_onControllerUpdate);
      }
      
      _loadCandles();
      _subscribeToPrice();
    }
  }
  
  /// Phase 6: Called when ChartController notifies listeners.
  void _onControllerUpdate() {
    if (!mounted || _chartController == null) return;
    // Sync controller state into local state for the painter
    setState(() {});
  }

  @override
  void dispose() {
    _priceSub?.cancel();
    _countdownTimer?.cancel();
    _sessionTimer?.cancel();
    // Phase 6: Dispose ChartController
    _chartController?.removeListener(_onControllerUpdate);
    _chartController?.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────
  Future<void> _loadCandles({bool prepend = false, int? endTime}) async {
    if (_isLoading) return;
    if (!prepend) {
      setState(() {
        _isLoading = true;
        _candles = [];
      });
    } else {
      setState(() => _isPaginating = true);
    }

    try {
      final fetched = await fetchOhlcCandles(widget.asset, _tf,
          limit: _candleCountFor(_tf), endTime: endTime);
      if (!mounted) return;
      if (fetched.isEmpty) {
        // Fallback to synthetic
        final synth = generateOhlcData(widget.asset, _tf);
        setState(() {
          _candles    = synth;
          _isLoading  = false;
          _isPaginating = false;
          _scrollOffset = 0;
          _selectedIndex = null;
          _recomputeIndicators();
          _bootstrapLiveCandle();
        });
        // Phase 6: feed synthetic candles into ChartController
        _syncCandlesToController();
        return;
      }
      setState(() {
        if (prepend) {
          // Remove duplicates by timestamp before prepending
          final existingTs = _candles.isNotEmpty ? _candles.first.timestamp : 0;
          final newCandles  = fetched.where((c) => c.timestamp < existingTs).toList();
          _candles = [...newCandles, ..._candles];
          // Keep viewport in the same position
          _scrollOffset += newCandles.length * _candleWidth;
        } else {
          _candles       = fetched;
          _scrollOffset  = 0;
          _selectedIndex = null;
          _bootstrapLiveCandle();
        }
        _isLoading    = false;
        _isPaginating = false;
        _recomputeIndicators();
      });
      // Phase 6: feed loaded candles into ChartController
      _syncCandlesToController();
    } catch (e) {
      if (!mounted) return;
      final synth = generateOhlcData(widget.asset, _tf);
      setState(() {
        _candles      = synth;
        _isLoading    = false;
        _isPaginating = false;
        _scrollOffset = 0;
        _recomputeIndicators();
        _bootstrapLiveCandle();
      });
      // Phase 6: feed fallback candles into ChartController
      _syncCandlesToController();
    }
  }

  /// Mark the last candle as live only if it belongs to the current time slot
  /// and the market is currently open.
  void _bootstrapLiveCandle() {
    if (_candles.isEmpty) return;
    if (!isMarketLive(widget.asset)) return;
    final now         = DateTime.now().millisecondsSinceEpoch;
    final intervalMs  = _intervalMs(_tf);
    final currentSlot = candleBoundary(now, intervalMs);
    final last        = _candles.last;
    // Mark live only if the last candle's slot is the current slot or one behind
    // (one behind because the API may not yet have delivered the very latest bar)
    if (last.timestamp >= currentSlot - intervalMs) {
      last.isLive = true;
    }
  }

  void _recomputeIndicators() {
    _ema9   = _calcEma(_candles, 9);
    _ema21  = _calcEma(_candles, 21);
    _ema50  = _calcEma(_candles, 50);
    _ema200 = _calcEma(_candles, 200);
    _sma50  = _calcSma(_candles, 50);
    _sma200 = _calcSma(_candles, 200);
    _vwap   = _calcVwap(_candles);
    final macd  = _calcMacd(_candles);
    _macdLine   = macd.line;
    _macdSignal = macd.signal;
    _macdHist   = macd.hist;
  }

  /// Phase 6: Push current _candles into ChartController as ChartCandle list.
  /// Converts the chart-local CandleData to the engine's ChartCandle type.
  void _syncCandlesToController() {
    final ctrl = _chartController;
    if (ctrl == null) return;
    final chartCandles = _candles.map((c) => ChartCandle(
      timestamp: c.timestamp,
      open:      c.open,
      high:      c.high,
      low:       c.low,
      close:     c.close,
      volume:    c.volume,
      isLive:    c.isLive,
    )).toList();
    ctrl.loadCandles(chartCandles);
  }

  // ── Live candle ───────────────────────────────────────────
  void _subscribeToPrice() {
    // Phase 6: Use ChartController path if price stream was provided
    if (_chartController != null) {
      // ChartController already subscribed to priceStream — nothing to do here
      return;
    }
    // Legacy path: listen to TradingProvider's priceUpdateStream
    final provider = Provider.of<TradingProvider>(context, listen: false);
    _priceSub = provider.priceUpdateStream
        .where((sym) => sym == widget.asset.symbol)
        .listen(_onPriceTick);
  }

  void _onPriceTick(String _) {
    if (!mounted || _candles.isEmpty) return;

    // Do not create fake candles when market is closed
    if (!isMarketLive(widget.asset)) return;

    final provider   = Provider.of<TradingProvider>(context, listen: false);
    final newPrice   = provider.priceOf(widget.asset.symbol);
    if (newPrice <= 0) return;

    final now         = DateTime.now().millisecondsSinceEpoch;
    final intervalMs  = _intervalMs(_tf);

    // The canonical slot this tick belongs to
    final currentSlot = candleBoundary(now, intervalMs);
    final liveCandle  = _candles.last;

    if (currentSlot > liveCandle.timestamp) {
      // ── A new candle period has started ──
      setState(() {
        liveCandle.isLive = false;

        // Fill any missing candle slots between last known candle and now
        // (can happen after a gap, e.g. app was backgrounded)
        int nextSlot = liveCandle.timestamp + intervalMs;
        double bridgePrice = liveCandle.close;
        while (nextSlot <= currentSlot) {
          final isCurrentSlot = nextSlot == currentSlot;
          _candles.add(CandleData(
            timestamp: nextSlot,
            open:   bridgePrice,
            high:   isCurrentSlot ? math.max(bridgePrice, newPrice) : bridgePrice,
            low:    isCurrentSlot ? math.min(bridgePrice, newPrice) : bridgePrice,
            close:  isCurrentSlot ? newPrice : bridgePrice,
            volume: 0,
            isLive: isCurrentSlot,
          ));
          nextSlot += intervalMs;
        }

        // Trim to keep bounded
        while (_candles.length > _candleCountFor(_tf) + 200) {
          _candles.removeAt(0);
          _scrollOffset = math.max(0, _scrollOffset - _candleWidth);
        }

        _recomputeIndicators();
        _resetCountdown();
      });
    } else if (currentSlot == liveCandle.timestamp) {
      // ── Same candle period — update in-place ──
      setState(() {
        liveCandle.isLive = true;
        liveCandle.applyTick(newPrice);

        // Incremental EMA update (last value only — avoid full recompute on every tick)
        void updateEmaLast(List<double?> ema, int period) {
          if (ema.length < 2 || _candles.length <= period) return;
          final prev = ema[ema.length - 2];
          if (prev == null) return;
          final k = 2.0 / (period + 1);
          ema.last = newPrice * k + prev * (1 - k);
        }

        updateEmaLast(_ema9, 9);
        updateEmaLast(_ema21, 21);
        updateEmaLast(_ema50, 50);
      });
    }
    // If currentSlot < liveCandle.timestamp the data has a future timestamp
    // (clock skew or bad API data) — skip silently.
  }

  // ── Countdown ─────────────────────────────────────────────
  void _startCountdownTimer() {
    _resetCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdownMs = math.max(0, _countdownMs - 1000));
    });
  }

  void _resetCountdown() {
    if (_candles.isEmpty) { _countdownMs = 0; return; }
    // Only show countdown when market is live
    if (!isMarketLive(widget.asset)) { _countdownMs = 0; return; }
    final intervalMs = _intervalMs(_tf);
    final now        = DateTime.now().millisecondsSinceEpoch;
    final nextTs     = candleBoundary(now, intervalMs) + intervalMs;
    _countdownMs     = math.max(0, nextTs - now);
  }

  // ── Session timer ─────────────────────────────────────────
  // Re-evaluates market status every minute so the badge and live candle
  // logic respond correctly when a session opens or closes.
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      final newStatus = getMarketStatus(widget.asset);
      if (newStatus != _marketStatus) {
        setState(() => _marketStatus = newStatus);
        // When market opens, reload to get fresh data
        if (newStatus.isLive && !_marketStatus.isLive) {
          _loadCandles();
        }
      }
    });
  }

  // ── Historical pagination ──────────────────────────────────
  void _checkPagination(double width) {
    if (_isPaginating || _candles.isEmpty) return;
    final chartW    = width - _kRightAxisWidth;
    final maxScroll = math.max(0.0, _candles.length * _candleWidth - chartW + _candleWidth);
    // Trigger when user has scrolled within 3 candle-widths of the oldest candle
    if (_scrollOffset > maxScroll - _candleWidth * 3) {
      final oldest = _candles.first.timestamp;
      _loadCandles(prepend: true, endTime: oldest - 1);
    }
  }

  // ── Params builder ────────────────────────────────────────
  _PainterParams _buildParams(double width, double height) {
    final chartW  = width - _kRightAxisWidth;
    final volumeH = height * _kVolumeHeightFactor;
    final priceH  = height - volumeH - _kBottomAxisHeight;

    // Guard: while loading, return a minimal params that draws nothing
    if (_candles.isEmpty) {
      final colors = AppColors.of(context);
      return _PainterParams(
        candles: const [], scrollOffset: 0, candleWidth: _candleWidth,
        chartWidth: chartW, chartHeight: height,
        volumeHeight: volumeH, priceHeight: priceH,
        minPrice: widget.asset.basePrice * 0.9,
        maxPrice: widget.asset.basePrice * 1.1,
        maxVolume: 1.0, selectedIndex: null,
        colors: colors, marketType: widget.asset.type,
        isArea: _isArea, timeframe: _tf,
        currentPrice: widget.currentPrice, prevClose: null,
        ema9: const [], ema21: const [], ema50: const [], ema200: const [],
        sma50: const [], sma200: const [], vwap: const [],
        macdLine: const [], macdSignal: const [], macdHist: const [],
        macdEnabled: false,
        indicatorEnabled: const {}, indicatorColors: const {},
        tradeOverlays: const [], isLoading: _isLoading, countdownMs: 0,
        marketStatus: _marketStatus,
      );
    }

    // Temp params to get visible range
    final temp = _PainterParams(
      candles: _candles, scrollOffset: _scrollOffset,
      candleWidth: _candleWidth, chartWidth: chartW, chartHeight: height,
      volumeHeight: volumeH, priceHeight: priceH,
      minPrice: 0, maxPrice: 0, maxVolume: 0,
      selectedIndex: null, colors: AppColors.of(context),
      marketType: widget.asset.type, isArea: _isArea, timeframe: _tf,
      currentPrice: widget.currentPrice, prevClose: null,
      ema9: const [], ema21: const [], ema50: const [], ema200: const [],
      sma50: const [], sma200: const [], vwap: const [],
      macdLine: const [], macdSignal: const [], macdHist: const [],
      macdEnabled: false,
      indicatorEnabled: const {}, indicatorColors: const {},
      tradeOverlays: const [], isLoading: false, countdownMs: 0,
      marketStatus: _marketStatus,
    );

    final first = temp.firstVisibleIndex;
    final last  = temp.lastVisibleIndex;
    double minP = double.infinity, maxP = double.negativeInfinity, maxV = 0;

    for (int i = first; i <= last; i++) {
      final c = _candles[i];
      if (c.low  < minP) minP = c.low;
      if (c.high > maxP) maxP = c.high;
      if (c.volume > maxV) maxV = c.volume;
    }
    // Include current price in the visible range
    if (widget.currentPrice > 0) {
      if (widget.currentPrice < minP) minP = widget.currentPrice;
      if (widget.currentPrice > maxP) maxP = widget.currentPrice;
    }
    final pad = (maxP - minP) * 0.08;
    minP -= pad; maxP += pad;

    final provider = Provider.of<TradingProvider>(context, listen: false);
    final overlays = provider.positions
        .where((pos) => pos.symbol == widget.asset.symbol)
        .map((pos) => TradeOverlay(
              positionId:        pos.id,
              entryPrice:        pos.entryPrice,
              side:              pos.side,
              qty:               pos.qty,
              stopLoss:          pos.stopLoss,
              takeProfit:        pos.takeProfit,
              liquidationPrice:  pos.liquidationPrice > 0 ? pos.liquidationPrice : null,
            ))
        .toList();

    final colors = AppColors.of(context);
    final iMap   = <IndicatorType, bool>{};
    final cMap   = <IndicatorType, Color>{};
    for (final e in _indicators.entries) {
      iMap[e.key] = e.value.enabled;
      cMap[e.key] = e.value.color(colors);
    }

    final prevClose = _candles.length >= 2 ? _candles[_candles.length - 2].close : null;

    return _PainterParams(
      candles:          _candles,
      scrollOffset:     _scrollOffset,
      candleWidth:      _candleWidth,
      chartWidth:       chartW,
      chartHeight:      height,
      volumeHeight:     volumeH,
      priceHeight:      priceH,
      minPrice:         minP.isFinite ? minP : widget.asset.basePrice * 0.9,
      maxPrice:         maxP.isFinite ? maxP : widget.asset.basePrice * 1.1,
      maxVolume:        maxV > 0 ? maxV : 1.0,
      selectedIndex:    _selectedIndex,
      colors:           colors,
      marketType:       widget.asset.type,
      isArea:           _isArea,
      timeframe:        _tf,
      currentPrice:     widget.currentPrice,
      prevClose:        prevClose,
      ema9:             _ema9, ema21: _ema21, ema50: _ema50, ema200: _ema200,
      sma50:            _sma50,
      sma200:           _sma200,
      vwap:             _vwap,
      macdLine:         _macdLine,
      macdSignal:       _macdSignal,
      macdHist:         _macdHist,
      macdEnabled:      _indicators[IndicatorType.macd]?.enabled ?? false,
      indicatorEnabled: iMap,
      indicatorColors:  cMap,
      tradeOverlays:    overlays,
      isLoading:        _isLoading,
      countdownMs:      _countdownMs,
      marketStatus:     _marketStatus,
    );
  }

  void _clampScroll(double width) {
    final chartW    = width - _kRightAxisWidth;
    final maxScroll = math.max(0.0, _candles.length * _candleWidth - chartW + _candleWidth);
    _scrollOffset   = _scrollOffset.clamp(0.0, maxScroll);
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors      = AppColors.of(context);
    final isPositive  = widget.currentPrice >= widget.asset.basePrice;
    final accentColor = isPositive ? colors.positive : colors.negative;

    // The canvas fills remaining space via Expanded inside the bounded SizedBox.

    return SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showControls) ...[
            _buildControls(colors, accentColor),
            const SizedBox(height: 10.0),
          ],
          Expanded(
            child: RepaintBoundary(
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return _buildGestureLayer(w, h, colors);
              }),
            ),
          ),
          if (_isPaginating)
            LinearProgressIndicator(
                minHeight: 1.5,
                color: colors.primary,
                backgroundColor: colors.border),
        ],
      ),
    );
  }

  // ── Controls ──────────────────────────────────────────────
  Widget _buildControls(ThemePalette colors, Color accentColor) {
    return Row(
      children: [
        // Market status dot (only shown when not open)
        if (_marketStatus != MarketStatus.open) ...[
          _buildStatusDot(colors),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _timeframes.map((tf) {
                final active = _tf == tf;
                return GestureDetector(
                  onTap: () => setState(() {
                    _tf = tf; _scrollOffset = 0; _selectedIndex = null;
                    _loadCandles(); _resetCountdown();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 6.0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? accentColor : colors.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(tf,
                        style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold,
                          color: active
                              ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white)
                              : colors.mutedForeground,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Chart type toggle
        _iconBtn(
          icon: _isArea ? Icons.candlestick_chart_rounded : Icons.area_chart_rounded,
          color: accentColor, tooltip: _isArea ? 'Candles' : 'Area',
          onTap: () => setState(() { _isArea = !_isArea; _selectedIndex = null; }),
          colors: colors,
        ),
        const SizedBox(width: 4),
        // Indicator toggle
        _iconBtn(
          icon: Icons.show_chart_rounded, color: colors.mutedForeground,
          tooltip: 'Indicators',
          onTap: () => _showIndicatorSheet(colors),
          colors: colors,
        ),
        const SizedBox(width: 4),
        // Refresh
        _iconBtn(
          icon: Icons.refresh_rounded, color: colors.mutedForeground,
          tooltip: 'Refresh',
          onTap: () { setState(() { _scrollOffset = 0; }); _loadCandles(); },
          colors: colors,
        ),
      ],
    );
  }

  Widget _iconBtn({required IconData icon, required Color color,
      required String tooltip, required VoidCallback onTap,
      required ThemePalette colors}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildStatusDot(ThemePalette colors) {
    final Color dotColor;
    switch (_marketStatus) {
      case MarketStatus.open:       dotColor = colors.positive; break;
      case MarketStatus.preMarket:  dotColor = const Color(0xFFE6A817); break;
      case MarketStatus.afterHours: dotColor = const Color(0xFF6366F1); break;
      case MarketStatus.closed:     dotColor = colors.negative; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dotColor.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            _marketStatus.label,
            style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.bold,
              color: dotColor, letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  void _showIndicatorSheet(ThemePalette colors) {
    const overlayTypes = [
      IndicatorType.ema9, IndicatorType.ema21,
      IndicatorType.ema50, IndicatorType.ema200,
      IndicatorType.sma50, IndicatorType.sma200,
      IndicatorType.vwap,
    ];
    const subPanelTypes = [IndicatorType.macd];

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, sheetSetState) {
          Widget sectionLabel(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Text(text,
                style: TextStyle(
                  color: colors.mutedForeground,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                )),
          );

          Widget tile(IndicatorType t) {
            final cfg = _indicators[t]!;
            return SwitchListTile(
              dense: true,
              title: Text(cfg.label,
                  style: TextStyle(color: colors.foreground, fontSize: 13.5)),
              subtitle: Row(children: [
                Container(
                  width: 28, height: 3,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: cfg.color(colors),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ]),
              value: cfg.enabled,
              activeThumbColor: cfg.color(colors),
              onChanged: (v) {
                sheetSetState(() => _indicators[t] = cfg.copyWithEnabled(v));
                setState(() {});
              },
            );
          }

          // Limit sheet height to 70% of screen so it never overflows
          final maxH = MediaQuery.of(ctx).size.height * 0.70;

          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text('Indicators',
                      style: TextStyle(color: colors.foreground,
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                // Scrollable tile list so content never clips
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        sectionLabel('OVERLAY — price panel'),
                        ...overlayTypes.map(tile),
                        sectionLabel('SUB-PANEL'),
                        ...subPanelTypes.map(tile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Gesture layer ─────────────────────────────────────────
  Widget _buildGestureLayer(double w, double h, ThemePalette colors) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          setState(() {
            _candleWidth = (_candleWidth * (event.scrollDelta.dy > 0 ? 0.9 : 1.1))
                .clamp(_minCandleW, _maxCandleW);
            _clampScroll(w);
            _selectedIndex = null;
          });
        }
      },
      child: GestureDetector(
        onScaleStart: (_) => _scaleStartWidth = _candleWidth,
        onScaleUpdate: (d) {
          setState(() {
            if (d.pointerCount >= 2) {
              final scale = d.scale != 1.0 ? d.scale : d.horizontalScale;
              _candleWidth = (_scaleStartWidth * scale)
                  .clamp(_minCandleW, _maxCandleW);
            } else {
              _scrollOffset -= d.focalPointDelta.dx;
              _checkPagination(w);
            }
            _clampScroll(w);
            _selectedIndex = null;
          });
        },
        onLongPressStart: (d) {
          final idx = _buildParams(w, h).getCandleIndexFromOffset(d.localPosition.dx);
          if (idx != null) setState(() => _selectedIndex = idx);
        },
        onLongPressMoveUpdate: (d) {
          final idx = _buildParams(w, h).getCandleIndexFromOffset(d.localPosition.dx);
          if (idx != null) setState(() => _selectedIndex = idx);
        },
        onLongPressEnd: (_) => setState(() => _selectedIndex = null),
        onTapDown: (d) {
          final idx = _buildParams(w, h).getCandleIndexFromOffset(d.localPosition.dx);
          setState(() => _selectedIndex = idx);
        },
        onTap: () => setState(() => _selectedIndex = null),
        child: ClipRect(
          child: CustomPaint(
            painter: _candles.isEmpty
                ? null
                : _ChartPainter(_buildParams(w, h)),
            size: Size(w, h),
            child: _isLoading
                ? Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.of(context).primary)))
                : null,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SECTION 11 — FULLSCREEN SCREEN (preserves zoom/scroll/tf)
// ============================================================

class CandlestickFullscreenScreen extends StatelessWidget {
  final Asset  asset;
  final double currentPrice;

  const CandlestickFullscreenScreen({
    super.key,
    required this.asset,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        title: Text('${asset.symbol} · ${asset.name}',
            style: TextStyle(color: colors.foreground,
                fontSize: 16, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: colors.foreground),
        actions: [
          StreamBuilder<String>(
            stream: Provider.of<TradingProvider>(context, listen: false)
                .priceUpdateStream
                .where((s) => s == asset.symbol),
            builder: (context, _) {
              final p    = Provider.of<TradingProvider>(context, listen: false);
              final price  = p.priceOf(asset.symbol);
              final change = p.changeOf(asset.symbol);
              final isPos  = change >= 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatAxisPrice(price, asset.type),
                        style: TextStyle(color: colors.foreground,
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('${isPos ? '+' : ''}${change.toStringAsFixed(2)}%',
                        style: TextStyle(
                            color: isPos ? colors.positive : colors.negative,
                            fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartH = constraints.maxHeight;
              final tp = Provider.of<TradingProvider>(context, listen: false);
              return StreamBuilder<String>(
                stream: tp.priceUpdateStream.where((s) => s == asset.symbol),
                builder: (context, _) {
                  final price = tp.priceOf(asset.symbol);
                  return CandlestickChart(
                    asset: asset,
                    currentPrice: price > 0 ? price : currentPrice,
                    height: chartH,
                    // Phase 6: decoupled price stream
                    priceStream: tp.priceStreamFor(asset.symbol),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
