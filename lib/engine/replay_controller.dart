/// Replay Controller — steps through historical candles bar-by-bar with
/// a full order execution simulation engine.
///
/// Loads a fixed historical window once, then exposes a growing prefix of it
/// as the "current" candle set, advancing one bar at a time (manually or on a
/// timer). This lets [ChartView] render replay exactly like a live chart —
/// it never knows the difference — while indicators recompute against only
/// the bars "seen so far", the same way they would as a live session unfolds.
///
/// Enhanced features:
/// - Market, Limit, and Stop-Market order simulation
/// - Automatic TP/SL execution on candle advance
/// - Account balance tracking with session P&L
/// - Discipline guardrails (max drawdown, consecutive losses, max trades)
/// - Higher-timeframe (HTF) data for MTF SMC dashboard
/// - Volume Profile computation over visible candle window
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/chart_data_source.dart';
import 'package:app/engine/discipline_guardrails.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/engine/smc_engine.dart';
import 'package:app/engine/volume_profile_engine.dart';
import 'package:app/models/indicator_style.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/replay_order.dart';
import 'package:app/models/smc_type.dart';

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

/// Maps a replay timeframe to the next-higher timeframe for MTF analysis.
Timeframe _higherTimeframe(Timeframe tf) {
  switch (tf) {
    case Timeframe.m1:
      return Timeframe.m15;
    case Timeframe.m5:
      return Timeframe.h1;
    case Timeframe.m15:
      return Timeframe.h4;
    case Timeframe.m30:
      return Timeframe.h4;
    case Timeframe.h1:
      return Timeframe.d1;
    case Timeframe.h4:
      return Timeframe.d1;
    case Timeframe.d1:
      return Timeframe.w1;
    case Timeframe.w1:
      return Timeframe.w1;
  }
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

  // ==========================================================
  // ORDER EXECUTION ENGINE
  // ==========================================================

  /// Pending orders waiting to be triggered.
  final List<ReplayOrder> _pendingOrders = [];

  /// Filled / open positions.
  final List<ReplayOrder> _filledOrders = [];

  /// All closed (completed) trades for analytics.
  final List<ReplayOrder> _closedTrades = [];

  /// Simulated account balance.
  double _accountBalance = 10000.0;
  double _startingBalance = 10000.0;

  /// Risk percentage per trade (default 1%).
  double _riskPercent = 1.0;

  /// Consecutive loss counter for discipline guardrails.
  int _consecutiveLosses = 0;

  /// Discipline guardrail settings.
  DisciplineSettings _disciplineSettings = const DisciplineSettings();

  /// Active guardrail violation (null = trading permitted).
  GuardrailViolation? _activeViolation;

  /// Order ID counter.
  int _nextOrderId = 1;

  // ==========================================================
  // MTF & VOLUME PROFILE
  // ==========================================================

  /// Higher-timeframe candles for MTF SMC dashboard.
  List<CandleData> _htfCandles = [];

  /// HTF trend analysis result.
  SmcTrend? _htfTrend;

  /// Volume Profile computed over the visible candle window.
  VolumeProfileResult? _volumeProfile;

  /// Whether volume profile is enabled.
  bool _volumeProfileEnabled = false;

  // ==========================================================
  // CALLBACKS
  // ==========================================================

  /// Called when an order is filled.
  VoidCallback? onOrderFilled;

  /// Called when a position is closed (TP/SL hit or manual).
  VoidCallback? onPositionClosed;

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
  // ORDER EXECUTION STATE
  // ==========================================================

  List<ReplayOrder> get pendingOrders => List.unmodifiable(_pendingOrders);
  List<ReplayOrder> get openPositions =>
      List.unmodifiable(_filledOrders.where((o) => o.isOpen));
  List<ReplayOrder> get closedTrades => List.unmodifiable(_closedTrades);

  /// Current open position (if any). Only one position at a time.
  ReplayOrder? get openPosition =>
      _filledOrders.where((o) => o.isOpen).firstOrNull;

  double get accountBalance => _accountBalance;
  double get startingBalance => _startingBalance;
  double get sessionPnl => _accountBalance - _startingBalance;
  double get riskPercent => _riskPercent;
  int get consecutiveLosses => _consecutiveLosses;
  int get totalTradesTaken => _closedTrades.length;

  DisciplineSettings get disciplineSettings => _disciplineSettings;
  GuardrailViolation? get activeViolation => _activeViolation;

  // ==========================================================
  // MTF & VOLUME PROFILE STATE
  // ==========================================================

  SmcTrend? get htfTrend => _htfTrend;
  Timeframe get htfTimeframe => _higherTimeframe(_timeframe);
  VolumeProfileResult? get volumeProfile => _volumeProfile;
  bool get volumeProfileEnabled => _volumeProfileEnabled;

  void toggleVolumeProfile() {
    _volumeProfileEnabled = !_volumeProfileEnabled;
    if (_volumeProfileEnabled) {
      _recomputeVolumeProfile();
    } else {
      _volumeProfile = null;
    }
    notifyListeners();
  }

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

    // Load HTF data for MTF dashboard.
    await _loadHtfData();

    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> _loadHtfData() async {
    try {
      final htfTf = _higherTimeframe(_timeframe);
      if (htfTf == _timeframe) {
        _htfCandles = [];
        _htfTrend = null;
        return;
      }
      _htfCandles = await _provider.fetchOHLC(
        _instrument.symbol,
        htfTf.apiValue,
        limit: 200,
      );
      _recomputeHtfTrend();
    } catch (e) {
      _logger.warning('HTF data load failed: $e');
      _htfCandles = [];
      _htfTrend = null;
    }
  }

  void _recomputeHtfTrend() {
    if (_htfCandles.length < 20) {
      _htfTrend = null;
      return;
    }
    _htfTrend = SmcEngine.evaluateTrend(
      candles: _htfCandles,
      settings: const SmcSettings(),
    );
  }

  void _recomputeVolumeProfile() {
    if (!_volumeProfileEnabled || _playhead < 0) {
      _volumeProfile = null;
      return;
    }
    _volumeProfile = VolumeProfileEngine.compute(candles, bins: 40);
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
  // ACCOUNT & RISK SETTINGS
  // ==========================================================

  void setAccountBalance(double balance) {
    _accountBalance = balance;
    _startingBalance = balance;
    notifyListeners();
  }

  void setRiskPercent(double percent) {
    _riskPercent = percent.clamp(0.1, 10.0);
    notifyListeners();
  }

  void setDisciplineSettings(DisciplineSettings settings) {
    _disciplineSettings = settings;
    // Re-check violations with new settings.
    _checkDiscipline();
    notifyListeners();
  }

  // ==========================================================
  // ORDER PLACEMENT
  // ==========================================================

  /// Place a new order. Returns the order ID, or null if blocked by guardrails.
  String? placeOrder({
    required OrderSide side,
    required OrderType type,
    required double price,
    double? stopLossPrice,
    double? takeProfitPrice,
    required double positionSize,
    required double quantity,
  }) {
    // Check discipline guardrails.
    if (_activeViolation != null) return null;

    // Only one position at a time.
    if (openPosition != null && type == OrderType.market) return null;

    final id = 'order_${_nextOrderId++}';
    final order = ReplayOrder(
      id: id,
      side: side,
      type: type,
      price: price,
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
      positionSize: positionSize,
      quantity: quantity,
      createdAtBar: _playhead,
      createdAtTimestamp: _playhead >= 0 ? _fullHistory[_playhead].timestamp : 0,
    );

    if (type == OrderType.market) {
      // Fill immediately at current close price.
      _fillOrder(order, _playhead >= 0 ? _fullHistory[_playhead].close : price);
    } else {
      _pendingOrders.add(order);
    }

    notifyListeners();
    return id;
  }

  /// Cancel a pending order.
  void cancelOrder(String id) {
    _pendingOrders.removeWhere((o) {
      if (o.id == id) {
        o.status = OrderStatus.cancelled;
        return true;
      }
      return false;
    });
    notifyListeners();
  }

  /// Modify TP/SL on an open position.
  void modifyPosition({double? stopLossPrice, double? takeProfitPrice}) {
    final pos = openPosition;
    if (pos == null) return;
    if (stopLossPrice != null) pos.stopLossPrice = stopLossPrice;
    if (takeProfitPrice != null) pos.takeProfitPrice = takeProfitPrice;
    notifyListeners();
  }

  /// Manually close the open position at current market price.
  void closePosition() {
    final pos = openPosition;
    if (pos == null || _playhead < 0) return;
    _closeOrder(pos, _fullHistory[_playhead].close, 'manual_close');
    notifyListeners();
  }

  void _fillOrder(ReplayOrder order, double fillPrice) {
    order.status = OrderStatus.filled;
    order.fillPrice = fillPrice;
    order.filledAtBar = _playhead;
    order.filledAtTimestamp = _playhead >= 0 ? _fullHistory[_playhead].timestamp : 0;
    _filledOrders.add(order);
    _logger.info('Order filled: ${order.id} ${order.side.name} @ $fillPrice');
    onOrderFilled?.call();
  }

  void _closeOrder(ReplayOrder order, double exitPrice, String reason) {
    order.exitPrice = exitPrice;
    order.exitAtBar = _playhead;
    order.exitAtTimestamp = _playhead >= 0 ? _fullHistory[_playhead].timestamp : 0;
    order.exitReason = reason;

    // Update account balance.
    final pnl = order.realizedPnl();
    _accountBalance += pnl;

    // Track consecutive losses.
    if (pnl < 0) {
      _consecutiveLosses++;
    } else {
      _consecutiveLosses = 0;
    }

    _closedTrades.add(order);
    _logger.info('Position closed: ${order.id} reason=$reason pnl=${pnl.toStringAsFixed(2)}');
    onPositionClosed?.call();

    // Check discipline guardrails after close.
    _checkDiscipline();
  }

  /// Process pending orders and TP/SL against the current candle.
  void _processOrders() {
    if (_playhead < 0) return;
    final candle = _fullHistory[_playhead];

    // 1. Check pending limit/stop orders.
    final toRemove = <ReplayOrder>[];
    for (final order in _pendingOrders) {
      bool shouldFill = false;
      double fillPrice = order.price;

      if (order.type == OrderType.limit) {
        if (order.side == OrderSide.buy && candle.low <= order.price) {
          shouldFill = true;
          fillPrice = order.price;
        } else if (order.side == OrderSide.sell && candle.high >= order.price) {
          shouldFill = true;
          fillPrice = order.price;
        }
      } else if (order.type == OrderType.stopMarket) {
        if (order.side == OrderSide.buy && candle.high >= order.price) {
          shouldFill = true;
          fillPrice = order.price;
        } else if (order.side == OrderSide.sell && candle.low <= order.price) {
          shouldFill = true;
          fillPrice = order.price;
        }
      }

      if (shouldFill && openPosition == null) {
        _fillOrder(order, fillPrice);
        toRemove.add(order);
      }
    }
    _pendingOrders.removeWhere((o) => toRemove.contains(o));

    // 2. Check TP/SL on open positions.
    final positions = _filledOrders.where((o) => o.isOpen).toList();
    for (final pos in positions) {
      // Check Stop Loss first (SL has priority over TP for risk management).
      if (pos.stopLossPrice != null) {
        if (pos.isLong && candle.low <= pos.stopLossPrice!) {
          _closeOrder(pos, pos.stopLossPrice!, 'sl_hit');
          continue;
        }
        if (pos.isShort && candle.high >= pos.stopLossPrice!) {
          _closeOrder(pos, pos.stopLossPrice!, 'sl_hit');
          continue;
        }
      }

      // Check Take Profit.
      if (pos.takeProfitPrice != null) {
        if (pos.isLong && candle.high >= pos.takeProfitPrice!) {
          _closeOrder(pos, pos.takeProfitPrice!, 'tp_hit');
          continue;
        }
        if (pos.isShort && candle.low <= pos.takeProfitPrice!) {
          _closeOrder(pos, pos.takeProfitPrice!, 'tp_hit');
          continue;
        }
      }
    }
  }

  void _checkDiscipline() {
    _activeViolation = DisciplineGuardrails.checkViolation(
      settings: _disciplineSettings,
      startingBalance: _startingBalance,
      currentBalance: _accountBalance,
      consecutiveLosses: _consecutiveLosses,
      totalTrades: _closedTrades.length,
    );
  }

  /// Reset the entire trading session (balance, trades, guardrails).
  void resetSession() {
    _pendingOrders.clear();
    _filledOrders.clear();
    _closedTrades.clear();
    _accountBalance = _startingBalance;
    _consecutiveLosses = 0;
    _activeViolation = null;
    notifyListeners();
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
    _processOrders();
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

  final Map<IndicatorType, IndicatorStyle> _indicatorStyles = {};

  @override
  Map<IndicatorType, IndicatorStyle> get indicatorStyles =>
      Map.unmodifiable(_indicatorStyles);

  @override
  void setIndicatorStyle(IndicatorType t, IndicatorStyle style) {
    _indicatorStyles[t] = style;
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
    if (_volumeProfileEnabled) {
      _recomputeVolumeProfile();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }
}
