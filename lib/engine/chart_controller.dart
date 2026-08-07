/// Chart Controller
///
/// Independent rendering controller for the candlestick chart.
/// Decouples the chart from TradingProvider so it only depends on:
///   • A stream of price ticks (`Stream<double>`)
///   • The asset being displayed
///
/// This means the chart can be rendered in isolation, tested without
/// state management, and reused across different data sources.
///
/// Phase 6 implementation — part of the Chart Engine refactor.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:app/constants/markets.dart';
import 'package:app/core/logging/logger.dart';

/// Immutable candle snapshot passed to the chart painter.
class ChartCandle {
  final int    timestamp;
  final double open;
  double       high;
  double       low;
  double       close;
  double       volume;
  bool         isLive;

  ChartCandle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.isLive = false,
  });

  bool get isBullish => close >= open;

  void applyTick(double price, {double tickVolume = 0}) {
    close = price;
    if (price > high) high = price;
    if (price < low)  low  = price;
    volume += tickVolume;
  }

  ChartCandle copyWith({bool? isLive}) => ChartCandle(
    timestamp: timestamp,
    open:   open,
    high:   high,
    low:    low,
    close:  close,
    volume: volume,
    isLive: isLive ?? this.isLive,
  );
}

/// Indicator computed results for one series.
class IndicatorSeries {
  final String   name;   // e.g. 'EMA9', 'MACD_LINE'
  final List<double?> values;

  const IndicatorSeries({required this.name, required this.values});
}

/// All indicator data for the current candle set.
class ChartIndicators {
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

  const ChartIndicators({
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
  });

  static ChartIndicators empty(int length) {
    final nulls = List<double?>.filled(length, null);
    return ChartIndicators(
      ema9:       nulls,
      ema21:      nulls,
      ema50:      nulls,
      ema200:     nulls,
      sma50:      nulls,
      sma200:     nulls,
      vwap:       nulls,
      macdLine:   nulls,
      macdSignal: nulls,
      macdHist:   nulls,
    );
  }
}

/// Current state snapshot published to the chart widget.
class ChartState {
  final List<ChartCandle> candles;
  final ChartIndicators   indicators;
  final double            currentPrice;
  final bool              isLoading;
  final String            timeframe;
  final Asset             asset;

  const ChartState({
    required this.candles,
    required this.indicators,
    required this.currentPrice,
    required this.isLoading,
    required this.timeframe,
    required this.asset,
  });

  bool get hasData => candles.isNotEmpty;
}

/// Candle Engine — pure indicator computation (no state, no Flutter).
class CandleEngine {
  CandleEngine._();

  static List<double?> computeEma(List<ChartCandle> candles, int period) {
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

  static List<double?> computeSma(List<ChartCandle> candles, int period) {
    if (candles.length < period) return List.filled(candles.length, null);
    final result = List<double?>.filled(candles.length, null);
    double windowSum = candles.take(period).fold(0.0, (s, c) => s + c.close);
    result[period - 1] = windowSum / period;
    for (int i = period; i < candles.length; i++) {
      windowSum += candles[i].close - candles[i - period].close;
      result[i] = windowSum / period;
    }
    return result;
  }

  static List<double?> computeVwap(List<ChartCandle> candles) {
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

  static ({List<double?> line, List<double?> signal, List<double?> hist})
      computeMacd(List<ChartCandle> candles) {
    final ema12 = computeEma(candles, 12);
    final ema26 = computeEma(candles, 26);
    final n     = candles.length;

    final macdLine = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      if (ema12[i] != null && ema26[i] != null) {
        macdLine[i] = ema12[i]! - ema26[i]!;
      }
    }

    final signalLine = List<double?>.filled(n, null);
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

    final hist = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        hist[i] = macdLine[i]! - signalLine[i]!;
      }
    }
    return (line: macdLine, signal: signalLine, hist: hist);
  }

  /// Compute all indicators in one pass.
  static ChartIndicators computeAll(List<ChartCandle> candles) {
    if (candles.isEmpty) return ChartIndicators.empty(0);
    final macd = computeMacd(candles);
    return ChartIndicators(
      ema9:       computeEma(candles, 9),
      ema21:      computeEma(candles, 21),
      ema50:      computeEma(candles, 50),
      ema200:     computeEma(candles, 200),
      sma50:      computeSma(candles, 50),
      sma200:     computeSma(candles, 200),
      vwap:       computeVwap(candles),
      macdLine:   macd.line,
      macdSignal: macd.signal,
      macdHist:   macd.hist,
    );
  }
}

/// Chart Controller — manages candle state, live tick updates,
/// indicator computation, and publishes a [ChartState] stream.
///
/// Completely independent from TradingProvider.
/// The only external dependency is a [Stream<double>] of price ticks.
class ChartController extends ChangeNotifier {
  final Asset        _asset;
  String             _timeframe;
  Stream<double>?    _priceStream;
  StreamSubscription? _priceSub;

  // Candle state
  List<ChartCandle> _candles    = [];
  bool              _isLoading  = true;
  double            _lastPrice  = 0.0;

  // Computed indicators (recalculated on candle set changes)
  ChartIndicators _indicators = ChartIndicators.empty(0);

  // StreamController for publishing state to the chart widget
  final StreamController<ChartState> _stateController =
      StreamController<ChartState>.broadcast();

  ChartController({
    required Asset asset,
    required String initialTimeframe,
    this._priceStream,
  })  : _asset = asset,
        _timeframe = initialTimeframe {
    Logger.instance.info('ChartController Created for ${asset.symbol} ($initialTimeframe)');
    _subscribeToPrices();
  }

  // ============================================================
  // PUBLIC API
  // ============================================================

  Asset             get asset      => _asset;
  String            get timeframe  => _timeframe;
  List<ChartCandle> get candles    => List.unmodifiable(_candles);
  ChartIndicators   get indicators => _indicators;
  double            get lastPrice  => _lastPrice;
  bool              get isLoading  => _isLoading;

  /// Stream of chart state updates — the chart widget subscribes to this.
  Stream<ChartState> get stateStream => _stateController.stream;

  /// Current snapshot (synchronous).
  ChartState get currentState => ChartState(
    candles:      _candles,
    indicators:   _indicators,
    currentPrice: _lastPrice,
    isLoading:    _isLoading,
    timeframe:    _timeframe,
    asset:        _asset,
  );

  // ============================================================
  // CANDLE MANAGEMENT
  // ============================================================

  /// Load candles into the controller.
  /// Called by the chart widget after an async fetch.
  void loadCandles(List<ChartCandle> candles) {
    _candles    = candles;
    _isLoading  = candles.isEmpty;
    _recomputeIndicators();
    _bootstrapLiveCandle();
    _publish();
    Logger.instance.chart('Loaded ${candles.length} candles for ${_asset.symbol}');
  }

  /// Set loading state while candles are being fetched.
  void setLoading(bool loading) {
    _isLoading = loading;
    _publish();
  }

  /// Change timeframe — callers must re-fetch and call loadCandles.
  void setTimeframe(String tf) {
    _timeframe = tf;
    _candles   = [];
    _isLoading = true;
    _publish();
  }

  // ============================================================
  // LIVE TICK
  // ============================================================

  /// Apply a live price tick to the current (live) candle.
  /// Creates a new candle when the interval boundary is crossed.
  void applyPriceTick(double price, int nowMs) {
    if (_candles.isEmpty || price <= 0) return;

    _lastPrice = price;

    final intervalMs   = _intervalMs(_timeframe);
    final currentSlot  = _candleBoundary(nowMs, intervalMs);
    final liveCandle   = _candles.last;

    if (currentSlot > liveCandle.timestamp) {
      // New candle period — close current, open new
      liveCandle.isLive = false;

      int nextSlot    = liveCandle.timestamp + intervalMs;
      double bridgeP  = liveCandle.close;
      while (nextSlot <= currentSlot) {
        final isCurrent = nextSlot == currentSlot;
        _candles.add(ChartCandle(
          timestamp: nextSlot,
          open:      bridgeP,
          high:      isCurrent ? math.max(bridgeP, price) : bridgeP,
          low:       isCurrent ? math.min(bridgeP, price) : bridgeP,
          close:     isCurrent ? price : bridgeP,
          volume:    0,
          isLive:    isCurrent,
        ));
        nextSlot += intervalMs;
      }

      // Trim to bounded length
      final maxCandles = _candleCountFor(_timeframe) + 200;
      while (_candles.length > maxCandles) {
        _candles.removeAt(0);
      }
      _recomputeIndicators();
    } else {
      // Update existing live candle
      liveCandle.applyTick(price);
    }

    _publish();
    notifyListeners();
  }

  // ============================================================
  // PRICE STREAM
  // ============================================================

  /// Attach a new price stream (e.g. when switching assets).
  void attachPriceStream(Stream<double> stream) {
    _priceSub?.cancel();
    _priceStream = stream;
    _subscribeToPrices();
  }

  void _subscribeToPrices() {
    if (_priceStream == null) return;
    _priceSub = _priceStream!.listen((price) {
      applyPriceTick(price, DateTime.now().millisecondsSinceEpoch);
    });
  }

  // ============================================================
  // PRIVATE
  // ============================================================

  void _recomputeIndicators() {
    _indicators = CandleEngine.computeAll(_candles);
  }

  void _bootstrapLiveCandle() {
    if (_candles.isEmpty) return;
    final last = _candles.last;
    if (!last.isLive) {
      last.isLive = true;
    }
  }

  void _publish() {
    if (!_stateController.isClosed) {
      _stateController.add(currentState);
    }
    notifyListeners();
  }

  // ============================================================
  // INTERVAL HELPERS  (duplicated from candlestick_chart.dart
  //                    so chart_controller.dart is standalone)
  // ============================================================

  static int _intervalMs(String tf) {
    switch (tf) {
      case '1m':  return 60 * 1000;
      case '5m':  return 5  * 60 * 1000;
      case '15m': return 15 * 60 * 1000;
      case '1h':  return 60 * 60 * 1000;
      case '4h':  return 4  * 60 * 60 * 1000;
      case '1D':  return 24 * 60 * 60 * 1000;
      default:    return 60 * 60 * 1000;
    }
  }

  static int _candleBoundary(int ms, int intervalMs) =>
      (ms ~/ intervalMs) * intervalMs;

  static int _candleCountFor(String tf) {
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

  @override
  void dispose() {
    _priceSub?.cancel();
    _stateController.close();
    Logger.instance.info('ChartController Disposed for ${_asset.symbol}');
    super.dispose();
  }
}
