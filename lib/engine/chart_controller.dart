/// Chart Controller — owns the candle set for one chart.
///
/// Responsibilities:
///   • fetch history for an instrument + timeframe
///   • paginate older history when the user pans left
///   • merge authoritative live candles from the exchange kline stream
///   • recompute indicators when the candle set changes
///
/// It does not know about widgets, painters, or pixels.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/domain/entities/kline_update.dart';
import 'package:app/engine/chart_data_source.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/indicator_style.dart';
import 'package:app/models/instrument.dart';

/// How many candles to request per page.
const int kCandlePageSize = 500;

/// Hard ceiling on retained candles, to bound memory and paint cost.
const int kMaxRetainedCandles = 3000;

class ChartController extends ChangeNotifier implements ChartDataSource {
  final BinanceProvider _provider;
  final Logger _logger;

  Instrument _instrument;
  Timeframe _timeframe;

  final List<CandleData> _candles = [];
  ChartIndicators _indicators = ChartIndicators.empty(0);

  final Set<IndicatorType> _enabled = {IndicatorType.volume};

  double _lastPrice = 0.0;
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  bool _hasMoreHistory = true;
  String? _error;

  StreamSubscription<KlineUpdate>? _klineSub;

  /// Guards against a stale async fetch clobbering a newer selection.
  int _requestGeneration = 0;

  ChartController({
    required BinanceProvider provider,
    required Logger logger,
    required Instrument instrument,
    Timeframe timeframe = Timeframe.h1,
    Set<IndicatorType>? enabledIndicators,
  })  : _provider = provider,
        _logger = logger,
        _instrument = instrument,
        _timeframe = timeframe {
    if (enabledIndicators != null) {
      _enabled
        ..clear()
        ..addAll(enabledIndicators);
    }
  }

  // ==========================================================
  // STATE
  // ==========================================================

  @override
  Instrument get instrument => _instrument;
  @override
  Timeframe get timeframe => _timeframe;
  @override
  List<CandleData> get candles => List.unmodifiable(_candles);
  @override
  ChartIndicators get indicators => _indicators;
  @override
  Set<IndicatorType> get enabledIndicators => Set.unmodifiable(_enabled);
  @override
  double get lastPrice => _lastPrice;
  @override
  bool get isLoading => _isLoading;
  @override
  bool get isLoadingHistory => _isLoadingHistory;
  @override
  bool get hasMoreHistory => _hasMoreHistory;
  @override
  String? get error => _error;
  @override
  bool get hasData => _candles.isNotEmpty;

  @override
  bool isIndicatorEnabled(IndicatorType t) => _enabled.contains(t);
  @override
  bool get showVolume => _enabled.contains(IndicatorType.volume);
  @override
  bool get showMacd => _enabled.contains(IndicatorType.macd);

  /// 24h-style change computed across the loaded window.
  double get changePercent {
    if (_candles.length < 2) return 0;
    final first = _candles.first.open;
    if (first <= 0) return 0;
    return ((_candles.last.close - first) / first) * 100.0;
  }

  // ==========================================================
  // LOADING
  // ==========================================================

  /// Fetch the initial page and attach the live stream.
  Future<void> load() async {
    final generation = ++_requestGeneration;
    _isLoading = true;
    _error = null;
    _hasMoreHistory = true;
    notifyListeners();

    final fetched = await _provider.fetchOHLC(
      _instrument.symbol,
      _timeframe.apiValue,
      limit: kCandlePageSize,
    );

    if (generation != _requestGeneration) return; // superseded

    _candles
      ..clear()
      ..addAll(fetched);

    if (_candles.isEmpty) {
      _error = 'No data for ${_instrument.displayName} on ${_timeframe.label}';
      _isLoading = false;
      notifyListeners();
      return;
    }

    _candles.last.isLive = true;
    _lastPrice = _candles.last.close;
    _recompute();
    _isLoading = false;
    _error = null;
    notifyListeners();

    _attachLiveStream();
  }

  /// Fetch one page of older candles. Safe to call repeatedly; it no-ops while
  /// a page is in flight or once history is exhausted.
  @override
  Future<void> loadMoreHistory() async {
    if (_isLoadingHistory || !_hasMoreHistory || _candles.isEmpty) return;

    _isLoadingHistory = true;
    notifyListeners();

    final generation = _requestGeneration;
    final oldestOpen = _candles.first.timestamp;

    try {
      final older = await _provider.fetchOHLC(
        _instrument.symbol,
        _timeframe.apiValue,
        limit: kCandlePageSize,
        // endTime is inclusive, so step back one ms to avoid a duplicate.
        endTime: oldestOpen - 1,
      );

      if (generation != _requestGeneration) return;

      // Drop anything at or past our current oldest, then prepend.
      final fresh = older.where((c) => c.timestamp < oldestOpen).toList();

      if (fresh.isEmpty) {
        _hasMoreHistory = false;
      } else {
        _candles.insertAll(0, fresh);
        _trimIfNeeded(fromStart: false);
        _recompute();
      }
    } catch (e) {
      _logger.warning('History page failed: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ==========================================================
  // SELECTION
  // ==========================================================

  Future<void> setInstrument(Instrument instrument) async {
    if (instrument.symbol == _instrument.symbol) return;
    _instrument = instrument;
    await _resetAndLoad();
  }

  Future<void> setTimeframe(Timeframe tf) async {
    if (tf == _timeframe) return;
    _timeframe = tf;
    await _resetAndLoad();
  }

  Future<void> _resetAndLoad() async {
    await _klineSub?.cancel();
    _klineSub = null;
    _candles.clear();
    _indicators = ChartIndicators.empty(0);
    _lastPrice = 0;
    await load();
  }

  @override
  Future<void> refresh() => _resetAndLoad();

  // ==========================================================
  // INDICATORS
  // ==========================================================

  @override
  void toggleIndicator(IndicatorType t) {
    if (_enabled.contains(t)) {
      _enabled.remove(t);
    } else {
      _enabled.add(t);
    }
    notifyListeners();
  }

  @override
  void setIndicators(Set<IndicatorType> next) {
    _enabled
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  final Map<IndicatorType, IndicatorStyle> _indicatorStyles = {};

  @override
  Map<IndicatorType, IndicatorStyle> get indicatorStyles =>
      Map.unmodifiable(_indicatorStyles);

  @override
  void setIndicatorStyle(IndicatorType t, IndicatorStyle style) {
    _indicatorStyles[t] = style;
    notifyListeners();
  }

  // ==========================================================
  // LIVE DATA
  // ==========================================================

  void _attachLiveStream() {
    _klineSub?.cancel();
    _klineSub = _provider
        .klineStream(_instrument.symbol, _timeframe.apiValue)
        .listen(_onKline, onError: (Object e) {
      _logger.warning('Kline stream error: $e');
    });
  }

  /// Merge an exchange candle update.
  ///
  /// The exchange is authoritative, so a matching candle is overwritten rather
  /// than folded. A newer open time appends, and any gap left by a dropped
  /// message is bridged with flat candles so the time axis stays continuous.
  void _onKline(KlineUpdate update) {
    if (update.symbol != _instrument.symbol) return;
    if (update.interval != _timeframe.apiValue) return;

    _lastPrice = update.close;

    if (_candles.isEmpty) {
      _candles.add(update.toCandle());
      _recompute();
      notifyListeners();
      return;
    }

    final last = _candles.last;

    if (update.openTime == last.timestamp) {
      last.overwriteFrom(update.toCandle());
      // Indicators depend on close, so the tail must be refreshed.
      _recompute();
      notifyListeners();
      return;
    }

    if (update.openTime > last.timestamp) {
      last.isLive = false;

      final step = _timeframe.durationMs;
      var slot = last.timestamp + step;
      // Bridge any missing intervals with flat candles at the last close.
      while (slot < update.openTime && step > 0) {
        _candles.add(CandleData(
          timestamp: slot,
          open: last.close,
          high: last.close,
          low: last.close,
          close: last.close,
          volume: 0,
        ));
        slot += step;
      }

      _candles.add(update.toCandle());
      _trimIfNeeded(fromStart: true);
      _recompute();
      notifyListeners();
    }
    // An older openTime is a late duplicate; ignore it.
  }

  // ==========================================================
  // INTERNAL
  // ==========================================================

  void _recompute() {
    _indicators = CandleEngine.computeAll(_candles);
  }

  void _trimIfNeeded({required bool fromStart}) {
    final excess = _candles.length - kMaxRetainedCandles;
    if (excess <= 0) return;
    if (fromStart) {
      _candles.removeRange(0, excess);
    } else {
      _candles.removeRange(_candles.length - excess, _candles.length);
      // Trimming the tail means we dropped the live candle; stop paginating.
      _hasMoreHistory = false;
    }
  }

  /// Highest and lowest price across an index range, used for autoscaling.
  @override
  ({double min, double max}) priceRange(int fromIndex, int toIndex) {
    if (_candles.isEmpty) return (min: 0, max: 1);
    final lo = fromIndex.clamp(0, _candles.length - 1);
    final hi = toIndex.clamp(0, _candles.length - 1);
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (int i = lo; i <= hi; i++) {
      min = math.min(min, _candles[i].low);
      max = math.max(max, _candles[i].high);
    }
    if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
    if (min == max) return (min: min * 0.999, max: max * 1.001);
    return (min: min, max: max);
  }

  @override
  void dispose() {
    _klineSub?.cancel();
    _klineSub = null;
    super.dispose();
  }
}
