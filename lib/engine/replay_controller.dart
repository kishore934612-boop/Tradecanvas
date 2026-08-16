/// Replay Controller — steps through historical candles bar-by-bar.
///
/// Loads a fixed historical window once, then exposes a growing prefix of it
/// as the "current" candle set, advancing one bar at a time (manually or on a
/// timer). This lets [ChartView] render replay exactly like a live chart —
/// it never knows the difference — while indicators recompute against only
/// the bars "seen so far", the same way they would as a live session unfolds.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/chart_data_source.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/instrument.dart';

/// How many historical candles to load for a replay session.
const int kReplayCandleCount = 500;

/// Bars need at least this many candles of lead-in before playback starts,
/// so slow indicators like EMA200 aren't all-null on bar 1.
const int kReplayLeadIn = 60;

/// Playback speed presets, in bars per second.
enum ReplaySpeed {
  x1(1.0, '1x'),
  x2(2.0, '2x'),
  x4(4.0, '4x'),
  x8(8.0, '8x');

  const ReplaySpeed(this.barsPerSecond, this.label);
  final double barsPerSecond;
  final String label;
}

class ReplayController extends ChangeNotifier implements ChartDataSource {
  final BinanceProvider _provider;
  final Logger _logger;

  Instrument _instrument;
  Timeframe _timeframe;

  /// The full historical window, fetched once at [load].
  List<CandleData> _fullHistory = [];

  /// Index (inclusive) of the last bar currently revealed. -1 before load.
  int _playhead = -1;

  ChartIndicators _indicators = ChartIndicators.empty(0);
  final Set<IndicatorType> _enabled = {IndicatorType.volume};

  bool _isLoading = true;
  String? _error;
  bool _isPlaying = false;
  ReplaySpeed _speed = ReplaySpeed.x1;

  Timer? _tickTimer;

  ReplayController({
    required BinanceProvider provider,
    required Logger logger,
    required Instrument instrument,
    Timeframe timeframe = Timeframe.h1,
  })  : _provider = provider,
        _logger = logger,
        _instrument = instrument,
        _timeframe = timeframe;

  // ==========================================================
  // CHARTDATASOURCE
  // ==========================================================

  @override
  Instrument get instrument => _instrument;
  @override
  Timeframe get timeframe => _timeframe;

  /// Only the bars revealed so far — this is what makes it "replay" rather
  /// than just showing the full history with a marker on top.
  @override
  List<CandleData> get candles => _playhead < 0
      ? const []
      : List.unmodifiable(_fullHistory.sublist(0, _playhead + 1));

  @override
  ChartIndicators get indicators => _indicators;
  @override
  Set<IndicatorType> get enabledIndicators => Set.unmodifiable(_enabled);
  @override
  double get lastPrice => _playhead < 0 ? 0 : _fullHistory[_playhead].close;
  @override
  bool get isLoading => _isLoading;
  @override
  bool get isLoadingHistory => false;
  @override
  bool get hasMoreHistory => false;
  @override
  String? get error => _error;
  @override
  bool get hasData => _playhead >= 0;
  @override
  bool get showVolume => _enabled.contains(IndicatorType.volume);
  @override
  bool get showMacd => _enabled.contains(IndicatorType.macd);

  @override
  bool isIndicatorEnabled(IndicatorType t) => _enabled.contains(t);

  @override
  void toggleIndicator(IndicatorType t) {
    if (!_enabled.remove(t)) _enabled.add(t);
    notifyListeners();
  }

  @override
  void setIndicators(Set<IndicatorType> next) {
    _enabled
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  /// Replay's history is a bounded, already-loaded window; there is nothing
  /// further back to page in.
  @override
  Future<void> loadMoreHistory() async {}

  @override
  Future<void> refresh() => load();

  @override
  ({double min, double max}) priceRange(int fromIndex, int toIndex) {
    final visible = candles;
    if (visible.isEmpty) return (min: 0, max: 1);
    final lo = fromIndex.clamp(0, visible.length - 1);
    final hi = toIndex.clamp(0, visible.length - 1);
    var min = double.infinity;
    var max = double.negativeInfinity;
    for (int i = lo; i <= hi; i++) {
      min = math.min(min, visible[i].low);
      max = math.max(max, visible[i].high);
    }
    if (!min.isFinite || !max.isFinite) return (min: 0, max: 1);
    if (min == max) return (min: min * 0.999, max: max * 1.001);
    return (min: min, max: max);
  }

  // ==========================================================
  // REPLAY-SPECIFIC STATE
  // ==========================================================

  bool get isPlaying => _isPlaying;
  ReplaySpeed get speed => _speed;

  /// Total bars available to replay (excluding the lead-in window).
  int get totalBars =>
      math.max(0, _fullHistory.length - kReplayLeadIn);

  /// How many of [totalBars] have been revealed so far.
  int get barsElapsed =>
      _playhead < 0 ? 0 : math.max(0, _playhead - kReplayLeadIn + 1);

  double get progress => totalBars == 0 ? 0 : barsElapsed / totalBars;

  bool get isAtEnd => _playhead >= _fullHistory.length - 1;
  bool get isAtStart => barsElapsed <= 0;

  // ==========================================================
  // LOADING
  // ==========================================================

  Future<void> load() async {
    pause();
    _isLoading = true;
    _error = null;
    notifyListeners();

    final fetched = await _provider.fetchOHLC(
      _instrument.symbol,
      _timeframe.apiValue,
      limit: kReplayCandleCount,
    );

    if (fetched.length <= kReplayLeadIn) {
      _error = fetched.isEmpty
          ? 'No history available for ${_instrument.displayName}.'
          : 'Not enough history to replay on ${_timeframe.label}. Try a '
              'lower timeframe.';
      _logger.warning(
          'Replay load insufficient for ${_instrument.symbol}: ${fetched.length} candles');
      _isLoading = false;
      notifyListeners();
      return;
    }

    _fullHistory = fetched;
    // Historical bars are all closed; replay never shows a "live" candle.
    for (final c in _fullHistory) {
      c.isLive = false;
    }

    _playhead = kReplayLeadIn - 1;
    _recompute();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> setInstrument(Instrument instrument) async {
    if (instrument.symbol == _instrument.symbol) return;
    _instrument = instrument;
    await load();
  }

  Future<void> setTimeframe(Timeframe tf) async {
    if (tf == _timeframe) return;
    _timeframe = tf;
    await load();
  }

  // ==========================================================
  // PLAYBACK
  // ==========================================================

  void play() {
    if (_isPlaying || isAtEnd || _playhead < 0) return;
    _isPlaying = true;
    _scheduleTick();
    notifyListeners();
  }

  void pause() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  void togglePlay() => _isPlaying ? pause() : play();

  void setSpeed(ReplaySpeed speed) {
    if (_speed == speed) return;
    _speed = speed;
    if (_isPlaying) _scheduleTick(); // re-arm at the new interval
    notifyListeners();
  }

  /// Advance exactly one bar. Pauses playback if it reaches the end.
  void stepForward() {
    if (_playhead >= _fullHistory.length - 1) {
      pause();
      return;
    }
    _playhead++;
    _recompute();
    notifyListeners();
    if (isAtEnd) pause();
  }

  /// Step back one bar. Manual only — does not resume auto-play.
  void stepBackward() {
    if (_playhead <= kReplayLeadIn - 1) return;
    pause();
    _playhead--;
    _recompute();
    notifyListeners();
  }

  /// Jump to a specific point in [0, 1] along the replay timeline.
  void seekToProgress(double value) {
    if (totalBars <= 0) return;
    pause();
    final target = kReplayLeadIn - 1 + (value.clamp(0.0, 1.0) * totalBars).round();
    _playhead = target.clamp(kReplayLeadIn - 1, _fullHistory.length - 1);
    _recompute();
    notifyListeners();
  }

  /// Restart from the beginning of the playable window.
  void restart() {
    pause();
    _playhead = kReplayLeadIn - 1;
    _recompute();
    notifyListeners();
  }

  void _scheduleTick() {
    _tickTimer?.cancel();
    final intervalMs = (1000 / _speed.barsPerSecond).round();
    _tickTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      stepForward();
    });
  }

  // ==========================================================
  // INTERNAL
  // ==========================================================

  void _recompute() {
    // Indicators are computed over only the revealed prefix, so e.g. EMA200
    // genuinely warms up over the replay rather than being visible from bar 1
    // using future data it shouldn't have access to yet.
    _indicators = CandleEngine.computeAll(candles);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
