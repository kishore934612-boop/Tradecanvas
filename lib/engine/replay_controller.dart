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
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/engine/replay_execution.dart';
import 'package:app/engine/risk_calculator.dart';
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
const int kReplayLeadIn = 200;

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
  final MarketProvider _provider;
  final ReplayExecution execution;
  int _loadGeneration = 0;
  bool _disposed = false;
  String? _lastOrderError;
  double _peakEquity = 10000;

  String? get lastOrderError => _lastOrderError;
  double get equity => _accountBalance + openPositions.fold<double>(0,
      (sum, o) => sum + o.unrealizedPnl(lastPrice) + o.entryFee);
  double get peakEquity => _peakEquity;
  double get drawdownPercent => _peakEquity > 0
      ? math.max(0, (_peakEquity - equity) / _peakEquity * 100) : 0;
  bool get hasTradingActivity => _pendingOrders.isNotEmpty || _filledOrders.isNotEmpty;
  bool get canRewind => !hasTradingActivity && !_isLoading;
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
    required MarketProvider provider,
    this.execution = const ReplayExecution(),
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
  int get totalTradesTaken => _filledOrders.length;

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
    final generation = ++_loadGeneration;
    _isLoading = true;
    _error = null;
    _fullHistory = [];
    _htfCandles = [];
    _htfTrend = null;
    _playhead = -1;
    resetSession();
    _recompute();
    try {
      final fetched = await _provider.fetchOHLC(
        _instrument.symbol, _timeframe.apiValue, limit: kReplayCandleCount);
      if (_disposed || generation != _loadGeneration) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final closed = fetched.where((c) => !c.isLive &&
          c.timestamp + _timeframe.durationMs <= now).toList();
      for (var i = 0; i < closed.length; i++) {
        final c = closed[i];
        if (![c.open, c.high, c.low, c.close, c.volume].every((v) => v.isFinite) ||
            c.low <= 0 || c.volume < 0 || c.high < math.max(c.open, c.close) ||
            c.low > math.min(c.open, c.close) ||
            (i > 0 && c.timestamp <= closed[i - 1].timestamp)) {
          throw const FormatException('Invalid or unordered historical candles.');
        }
      }
      if (closed.length <= kReplayLeadIn) {
        throw const FormatException('Need more than 200 closed candles. Try a lower timeframe.');
      }
      _fullHistory = closed.map((c) => c.copyWith(isLive: false)).toList();
      _playhead = kReplayLeadIn - 1;
      _recompute();
      final htf = _higherTimeframe(_timeframe);
      if (htf != _timeframe) {
        final fetchedHtf = await _provider.fetchOHLC(_instrument.symbol,
            htf.apiValue, limit: 1000,
            endTime: _fullHistory.last.timestamp + _timeframe.durationMs - 1);
        if (_disposed || generation != _loadGeneration) return;
        _htfCandles = fetchedHtf.map((c) => c.copyWith()).toList();
        _recomputeHtfTrend();
      }
    } catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _logger.warning('Replay history load failed: $e');
      // A failed HTF request must not destroy a valid primary replay window.
      if (_fullHistory.isEmpty) _error = 'Unable to load replay: $e';
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Only completed HTF bars known at the current replay close are visible.
  List<CandleData> get visibleHtfCandles {
    if (_playhead < 0) return const [];
    final cutoff = _fullHistory[_playhead].timestamp + _timeframe.durationMs;
    return List.unmodifiable(_htfCandles.where((c) => !c.isLive &&
        c.timestamp + htfTimeframe.durationMs <= cutoff));
  }

  void _recomputeHtfTrend() {
    final visible = visibleHtfCandles;
    _htfTrend = visible.length < 20 ? null : SmcEngine.evaluateTrend(
      candles: visible, settings: const SmcSettings());
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
    if (!balance.isFinite || balance <= 0 || hasTradingActivity) return;
    _accountBalance = balance;
    _startingBalance = balance;
    _peakEquity = balance;
    _checkDiscipline();
    notifyListeners();
  }

  void setRiskPercent(double percent) {
    if (!percent.isFinite || percent <= 0 || percent > 10) return;
    _riskPercent = percent;
    notifyListeners();
  }

  void setDisciplineSettings(DisciplineSettings settings) {
    if (!settings.isValid) return;
    _disciplineSettings = settings;
    _activeViolation = null;
    _checkDiscipline();
    notifyListeners();
  }

  RiskCalculation calculateOrderRisk({required OrderSide side,
      required OrderType type, required double price, required double stopLossPrice,
      double? takeProfitPrice}) => RiskCalculator.compute(
    accountBalance: _accountBalance, riskPercent: _riskPercent,
    entryPrice: type == OrderType.limit ? price : execution.marketFill(price, side),
    stopLossPrice: stopLossPrice, takeProfitPrice: takeProfitPrice,
    isLong: side == OrderSide.buy, feePercent: execution.feePercent,
    slippagePercent: execution.slippagePercent);

  String? _reject(String message) {
    _lastOrderError = message;
    notifyListeners();
    return null;
  }

  /// Queue an order for the next bar. Current close is never a retroactive fill.
  /// All entry paths enforce the same risk policy, even non-UI callers.
  String? placeOrder({
    required OrderSide side, required OrderType type, required double price,
    double? stopLossPrice, double? takeProfitPrice,
    required double positionSize, required double quantity,
  }) {
    _lastOrderError = null;
    if (_isLoading || !hasData || isAtEnd) return _reject('Load a replay with a next bar before trading.');
    _checkDiscipline();
    if (_activeViolation != null) return _reject(_activeViolation!.label);
    if (hasOpenOrPendingOrder) return _reject('Close or cancel the existing order first.');
    if (!execution.isValid) return _reject('Invalid simulation cost settings.');
    if (![price, positionSize, quantity].every((v) => v.isFinite && v > 0)) {
      return _reject('Price and quantity must be positive finite values.');
    }
    if (stopLossPrice == null) return _reject('A protective stop loss is required.');
    if (type != OrderType.market) {
      final below = type == OrderType.limit ? side == OrderSide.buy : side == OrderSide.sell;
      if (below ? price >= lastPrice : price <= lastPrice) {
        return _reject('Limit entries must improve price; stop entries must be beyond market.');
      }
    }
    final plannedPrice = type == OrderType.market ? lastPrice : price;
    final calc = calculateOrderRisk(side: side, type: type, price: plannedPrice,
        stopLossPrice: stopLossPrice, takeProfitPrice: takeProfitPrice);
    if (!calc.isValid) return _reject(calc.error ?? 'Invalid trade plan.');
    if (quantity > calc.quantity * (1 + 1e-9)) {
      return _reject('Quantity exceeds the risk budget or available buying power.');
    }
    final id = 'order_${_nextOrderId++}';
    _pendingOrders.add(ReplayOrder(id: id, side: side, type: type,
      price: plannedPrice, stopLossPrice: stopLossPrice, takeProfitPrice: takeProfitPrice,
      positionSize: quantity * plannedPrice, quantity: quantity,
      createdAtBar: _playhead, createdAtTimestamp: _fullHistory[_playhead].timestamp));
    notifyListeners();
    return id;
  }

  bool get hasOpenOrPendingOrder => openPosition != null || _pendingOrders.isNotEmpty;

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

  /// Stops may tighten, never widen original risk. Reject crossed brackets.
  bool modifyPosition({double? stopLossPrice, double? takeProfitPrice}) {
    final pos = openPosition;
    if (pos == null) return false;
    final sl = stopLossPrice ?? pos.stopLossPrice!;
    final tp = takeProfitPrice ?? pos.takeProfitPrice;
    if (!sl.isFinite || sl <= 0 || (pos.isLong ? sl >= lastPrice : sl <= lastPrice) ||
        (pos.isLong ? sl < pos.stopLossPrice! : sl > pos.stopLossPrice!) ||
        (tp != null && (!tp.isFinite || tp <= 0 || (pos.isLong ? tp <= lastPrice : tp >= lastPrice)))) {
      _reject('Stop may only tighten and brackets must remain on the correct side of market.');
      return false;
    }
    pos.stopLossPrice = sl;
    pos.takeProfitPrice = tp;
    _lastOrderError = null;
    notifyListeners();
    return true;
  }

  void closePosition() {
    final pos = openPosition;
    if (pos == null || _playhead < 0) return;
    _closeOrder(pos, execution.marketFill(lastPrice,
        pos.isLong ? OrderSide.sell : OrderSide.buy), 'manual_close');
    notifyListeners();
  }

  bool _fillOrder(ReplayOrder order, double fillPrice) {
    final calc = RiskCalculator.compute(accountBalance: _accountBalance,
      riskPercent: _riskPercent, entryPrice: fillPrice,
      stopLossPrice: order.stopLossPrice!, takeProfitPrice: order.takeProfitPrice,
      isLong: order.isLong, feePercent: execution.feePercent,
      slippagePercent: execution.slippagePercent);
    if (!calc.isValid || order.quantity > calc.quantity * (1 + 1e-9)) {
      order.status = OrderStatus.cancelled;
      _lastOrderError = 'Order cancelled: fill would violate brackets, risk or buying power after a price gap.';
      return false;
    }
    order.status = OrderStatus.filled;
    order.fillPrice = fillPrice;
    order.filledAtBar = _playhead;
    order.filledAtTimestamp = _fullHistory[_playhead].timestamp;
    order.feePercent = execution.feePercent;
    order.entryFee = execution.fee(fillPrice, order.quantity);
    order.initialRiskAmount = execution.stopRisk(order, fillPrice);
    _accountBalance -= order.entryFee;
    _filledOrders.add(order);
    onOrderFilled?.call();
    return true;
  }

  void _closeOrder(ReplayOrder order, double exitPrice, String reason) {
    if (!order.isOpen) return;
    order.exitPrice = exitPrice;
    order.exitAtBar = _playhead;
    order.exitAtTimestamp = _fullHistory[_playhead].timestamp;
    order.exitReason = reason;
    order.exitFee = execution.fee(exitPrice, order.quantity);
    final pnl = order.realizedPnl();
    // Entry fees were already paid at fill.
    _accountBalance += pnl + order.entryFee;
    _consecutiveLosses = pnl < 0 ? _consecutiveLosses + 1 : 0;
    _closedTrades.add(order);
    _logger.info('Position closed: ${order.id} reason=$reason net=$pnl');
    _checkDiscipline();
    onPositionClosed?.call();
  }

  void _processOrders() {
    if (_playhead < 0) return;
    final candle = _fullHistory[_playhead];
    final existing = openPosition;
    if (existing != null) {
      final exit = execution.exit(existing, candle);
      if (exit != null) _closeOrder(existing, exit.price, exit.reason);
    } else if (_activeViolation == null && _pendingOrders.isNotEmpty) {
      final order = _pendingOrders.first;
      if (order.createdAtBar < _playhead) {
        final entry = execution.entry(order, candle);
        if (entry != null) {
          _pendingOrders.remove(order);
          if (_fillOrder(order, entry.price)) {
            final exit = execution.exit(order, candle, enteredIntrabar: !entry.atOpen);
            if (exit != null) _closeOrder(order, exit.price, exit.reason);
          }
        }
      }
    }
    _checkDiscipline();
  }

  void _checkDiscipline() {
    _peakEquity = math.max(_peakEquity, equity);
    _activeViolation ??= DisciplineGuardrails.checkViolation(
      settings: _disciplineSettings, startingBalance: _peakEquity,
      currentBalance: equity, consecutiveLosses: _consecutiveLosses,
      totalTrades: totalTradesTaken);
    if (_activeViolation != null) {
      for (final order in _pendingOrders) { order.status = OrderStatus.cancelled; }
      _pendingOrders.clear();
    }
  }

  /// Reset the entire trading session (balance, trades, guardrails).
  void resetSession() {
    pause();
    _pendingOrders.clear();
    _filledOrders.clear();
    _closedTrades.clear();
    _accountBalance = _startingBalance;
    _peakEquity = _startingBalance;
    _lastOrderError = null;
    _consecutiveLosses = 0;
    _activeViolation = null;
    notifyListeners();
  }

  // ==========================================================
  // PLAYBACK
  // ==========================================================

  void play() {
    if (_isLoading || _isPlaying || isAtEnd || _playhead < 0) return;
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
    if (_isLoading || !hasData) return;
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
    if (!canRewind || _playhead <= kReplayLeadIn - 1) return;
    pause();
    _playhead--;
    _recompute();
    notifyListeners();
  }

  /// Jump to a specific point in [0, 1] along the replay timeline.
  void seekToProgress(double value) {
    if (_isLoading || !value.isFinite || totalBars <= 0) return;
    pause();
    final target = (kReplayLeadIn - 1 + (value.clamp(0.0, 1.0) * totalBars).round())
        .clamp(kReplayLeadIn - 1, _fullHistory.length - 1);
    if (target < _playhead && !canRewind) {
      _reject('Restart the session before rewinding recorded trades.');
      return;
    }
    while (_playhead < target) {
      _playhead++;
      _processOrders();
    }
    _playhead = target;
    _recompute();
    notifyListeners();
  }

  /// Restart clears the account ledger; old trades cannot survive rewinding.
  void restart() {
    if (_isLoading || _fullHistory.isEmpty) return;
    pause();
    resetSession();
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
    _recomputeHtfTrend();
    if (_volumeProfileEnabled) {
      _recomputeVolumeProfile();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _tickTimer?.cancel();
    super.dispose();
  }
}
