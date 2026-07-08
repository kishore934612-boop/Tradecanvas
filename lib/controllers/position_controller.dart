/// Position Controller
///
/// Manages open and closed positions, position lifecycle,
/// P&L calculations, and risk parameter updates.
/// Extracted from TradingProvider as part of Phase 4 refactoring.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/constants/markets.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/engine/trading_engine.dart';

/// Result returned by position open/close operations.
class PositionResult {
  final bool success;
  final String? error;
  final String? message;
  final Position? position;
  final double? pnl;

  const PositionResult({
    required this.success,
    this.error,
    this.message,
    this.position,
    this.pnl,
  });

  factory PositionResult.ok({String? message, Position? position, double? pnl}) =>
      PositionResult(success: true, message: message, position: position, pnl: pnl);

  factory PositionResult.fail(String error) =>
      PositionResult(success: false, error: error);
}

class PositionController extends ChangeNotifier {
  final EventBus _eventBus;
  final Logger _logger;

  // Position state
  final List<Position> _openPositions = [];

  // Discipline tracking (used by RiskManagementEngine / GamificationController)
  int _lastLossClosedAt = 0;
  double _lastTradeNotional = 0.0;

  StreamSubscription? _equitySubscription;

  PositionController({
    required EventBus this._eventBus,
    required Logger this._logger,
  }) {
    _logger.info('PositionController initialized');
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    _equitySubscription = _eventBus.on<EquityChangedEvent>().listen((event) {
      final marginLevel = event.marginUsed > 0 ? (event.equity / event.marginUsed) * 100.0 : 0.0;
      if (marginLevel > 0 && marginLevel < 150.0) {
        for (final p in _openPositions) {
          _eventBus.publish<LiquidationWarningEvent>(LiquidationWarningEvent(
            positionId: p.id,
            symbol: p.symbol,
            marginLevel: marginLevel,
            liquidationPrice: p.liquidationPrice,
          ));
        }
      }
    });
  }

  // ============================================================
  // GETTERS
  // ============================================================

  /// All currently open positions.
  List<Position> get openPositions => List.unmodifiable(_openPositions);

  /// Find a single open position by id, null if not found.
  Position? getPosition(String positionId) {
    try {
      return _openPositions.firstWhere((p) => p.id == positionId);
    } catch (_) {
      return null;
    }
  }

  /// Open positions for a specific symbol.
  List<Position> getPositionsBySymbol(String symbol) =>
      _openPositions.where((p) => p.symbol == symbol).toList();

  /// Total unrealised P&L across all open positions.
  double getUnrealizedPnl(Map<String, double> currentPrices) {
    double total = 0.0;
    for (final p in _openPositions) {
      final price = currentPrices[p.symbol] ?? 0.0;
      if (price > 0) total += p.pnl(price);
    }
    return total;
  }

  /// Sum of margin reserved by all open positions.
  double getUsedMargin() =>
      _openPositions.fold(0.0, (sum, p) => sum + p.margin);

  bool get hasOpenPositions => _openPositions.isNotEmpty;
  int get openPositionCount => _openPositions.length;

  // Discipline helpers used by GamificationController
  int get lastLossClosedAt => _lastLossClosedAt;
  double get lastTradeNotional => _lastTradeNotional;

  // ============================================================
  // OPEN POSITION
  // ============================================================

  /// Opens a new position immediately at [fillPrice].
  ///
  /// Requires a [freeMargin] value from PortfolioController so this
  /// controller stays independent.  Returns the margin+fee deduction
  /// via [PositionResult.position] on success.
  PositionResult openPosition({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double leverage,
    required double fillPrice,
    required double currentEquity,
    required double currentFreeMargin,
    TradingType tradingType = TradingType.spot,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    EntryJournal? entryJournal,
    required String genId,
  }) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return PositionResult.fail('Asset not found');

    final config = MarketConfig.get(asset.type, tradingType);

    // Phase 5: Use TradingEngine for all calculations
    final calc = TradingEngine.calculateMargin(
      qty: qty,
      fillPrice: fillPrice,
      leverage: leverage,
      side: side,
      asset: asset,
      config: config,
      isMarketOrder: true,
    );

    if (calc.totalCost > currentFreeMargin) {
      return PositionResult.fail('Insufficient free margin');
    }

    final adjustedPrice = calc.adjustedPrice;
    final actualQty     = calc.actualQty;
    final margin        = calc.margin;
    final fee           = calc.fee;

    // Risk discipline accounting
    final eq = currentEquity <= 0 ? 1.0 : currentEquity;
    double riskPerUnit = 0.0;
    if (stopLoss != null) {
      riskPerUnit = (adjustedPrice - stopLoss).abs();
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Revenge-trade detection (passed to gamification via event)
    bool isRevengeTrade = false;
    bool isRuleViolation = false;
    if (_lastLossClosedAt > 0 &&
        now - _lastLossClosedAt < 5 * 60 * 1000 &&
        calc.notional > _lastTradeNotional * 1.2) {
      isRevengeTrade = true;
      isRuleViolation = true;
    }
    if (stopLoss != null) {
      final riskPct = (riskPerUnit * actualQty / eq) * 100.0;
      if (riskPct > 1.0) isRuleViolation = true;
    }

    final position = Position(
      id: genId,
      symbol: symbol,
      side: side,
      qty: actualQty,
      entryPrice: adjustedPrice,
      leverage: leverage,
      margin: margin,
      fees: fee,
      openedAt: now,
      marketType: asset.type,
      tradingType: tradingType,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: trailingStop,
      trailingAnchor: trailingStop != null ? adjustedPrice : null,
      entryJournal: entryJournal,
      initialRiskPerUnit: riskPerUnit,
    );

    _openPositions.add(position);

    _logger.info('Position opened: ${side.label} $qty $symbol @ \$$adjustedPrice');

    _eventBus.publish<PositionOpenedEvent>(PositionOpenedEvent(
      positionId: position.id,
      symbol: symbol,
      side: side.label,
      quantity: actualQty,
      entryPrice: adjustedPrice,
      leverage: leverage.toInt(),
      isRevengeTrade: isRevengeTrade,
      isRuleViolation: isRuleViolation,
      marginUsed: margin,
      feeCharged: fee,
    ));

    notifyListeners();
    return PositionResult.ok(
      message: '${side.label} position opened',
      position: position,
    );
  }

  // ============================================================
  // CLOSE POSITION
  // ============================================================

  /// Closes [fraction] (0..1) of position [positionId] at [exitPrice].
  ///
  /// Returns a [PositionResult] containing the net P&L for the closed part.
  /// The caller (TradingProvider facade) must apply the P&L to PortfolioController.
  PositionResult closePosition(
    String positionId, {
    double fraction = 1.0,
    required double exitPrice,
    String reason = 'manual',
    required String genTradeId,
  }) {
    final p = getPosition(positionId);
    if (p == null) return PositionResult.fail('Position not found');

    fraction = fraction.clamp(0.0001, 1.0);
    return _closeInternal(p, fraction, exitPrice, reason, genTradeId);
  }

  PositionResult _closeInternal(
    Position p,
    double fraction,
    double exitPrice,
    String reason,
    String tradeId,
  ) {
    final config = MarketConfig.get(p.marketType, p.tradingType);
    final asset = getAssetBySymbol(p.symbol);

    // Phase 5: Use TradingEngine for all P&L calculations
    final pnlCalc = TradingEngine.calculateClosePnl(
      position: p,
      exitPrice: exitPrice,
      fraction: fraction,
      asset: asset,
      config: config,
    );

    final netPnl         = pnlCalc.netPnl;
    final returnedMargin = pnlCalc.returnedMargin;
    final adjustedExit   = pnlCalc.adjustedExitPrice;

    // Build trade record
    final trade = Trade(
      id: tradeId,
      symbol: p.symbol,
      name: asset?.name ?? p.symbol,
      side: p.side,
      qty: p.qty * fraction,
      entryPrice: p.entryPrice,
      exitPrice: adjustedExit,
      leverage: p.leverage,
      fees: pnlCalc.entryFeePortion + pnlCalc.exitFee,
      openedAt: p.openedAt,
      closedAt: DateTime.now().millisecondsSinceEpoch,
      pnl: netPnl,
      pnlPct: pnlCalc.pnlPct,
      marketType: p.marketType,
      tradingType: p.tradingType,
      stopLoss: p.stopLoss,
      takeProfit: p.takeProfit,
      riskReward: (p.stopLoss != null && p.takeProfit != null)
          ? TradingEngine.riskReward(
              entryPrice: p.entryPrice,
              side: p.side,
              stopLoss: p.stopLoss!,
              takeProfit: p.takeProfit!,
            )?.ratio
          : null,
      riskPct: TradingEngine.riskPercent(
        entryPrice: p.entryPrice,
        stopLoss: p.stopLoss ?? p.entryPrice,
        actualQty: p.qty * fraction,
        equity: p.margin > 0 ? p.margin / (1.0 / p.leverage) : 1.0,
      ),
      closeReason: reason,
      entryJournal: p.entryJournal,
    );

    // Update discipline state
    _lastTradeNotional = p.qty * fraction * p.entryPrice;
    if (netPnl < 0) _lastLossClosedAt = DateTime.now().millisecondsSinceEpoch;

    // Reduce or remove position
    if (fraction >= 1.0) {
      _openPositions.removeWhere((x) => x.id == p.id);
    } else {
      p.qty    -= p.qty * fraction;
      p.margin -= returnedMargin;
    }

    _logger.info(
      'Position closed: ${p.side.label} ${p.qty * fraction} ${p.symbol} @ \$$adjustedExit | P&L: \$$netPnl ($reason)',
    );

    _eventBus.publish<PositionClosedEvent>(PositionClosedEvent(
      positionId: p.id,
      symbol: p.symbol,
      exitPrice: adjustedExit,
      pnl: netPnl,
      closeReason: reason,
      trade: trade,
      returnedMargin: returnedMargin,
    ));

    _eventBus.publish<TradeCompletedEvent>(TradeCompletedEvent(
      tradeId: trade.id,
      symbol: trade.symbol,
      pnl: trade.pnl,
      isWin: trade.isWin,
      durationMs: trade.durationMs,
      closeReason: trade.closeReason,
      riskReward: trade.riskReward,
      riskPct: trade.riskPct,
      trade: trade,
    ));

    notifyListeners();
    return PositionResult.ok(
      message: 'Position closed',
      pnl: netPnl,
    );
  }

  // ============================================================
  // RISK PARAMETER UPDATES
  // ============================================================

  /// Update SL / TP / trailing stop for an open position.
  void updatePositionRisk(
    String positionId, {
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    bool clearTrailing = false,
    required double currentPrice,
  }) {
    final p = getPosition(positionId);
    if (p == null) {
      _logger.warning('updatePositionRisk: position $positionId not found');
      return;
    }

    p.stopLoss = stopLoss;
    p.takeProfit = takeProfit;

    if (clearTrailing) {
      p.trailingStop = null;
      p.trailingAnchor = null;
    } else if (trailingStop != null) {
      p.trailingStop = trailingStop;
      p.trailingAnchor = currentPrice;
    }

    _logger.info(
      'Position risk updated: ${p.symbol} SL=$stopLoss TP=$takeProfit trailing=$trailingStop',
    );

    _eventBus.publish<PositionUpdatedEvent>(PositionUpdatedEvent(
      positionId: positionId,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
    ));

    _eventBus.publish<PositionRiskUpdatedEvent>(PositionRiskUpdatedEvent(
      positionId: positionId,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: clearTrailing ? null : trailingStop,
    ));

    notifyListeners();
  }

  /// Update trailing stop anchor after price movement.
  void updateTrailingAnchor(String positionId, double currentPrice) {
    final p = getPosition(positionId);
    if (p == null || p.trailingStop == null) return;

    if (p.side == PositionSide.long) {
      p.trailingAnchor =
          p.trailingAnchor == null ? currentPrice : max(p.trailingAnchor!, currentPrice);
    } else {
      p.trailingAnchor =
          p.trailingAnchor == null ? currentPrice : min(p.trailingAnchor!, currentPrice);
    }
  }

  void addPositionDirectly(Position position) {
    _openPositions.add(position);
    notifyListeners();
  }

  void removePositionDirectly(String positionId) {
    _openPositions.removeWhere((p) => p.id == positionId);
    notifyListeners();
  }

  void notifyListenersDirectly() {
    notifyListeners();
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  Map<String, dynamic> toJson() => {
        'openPositions': _openPositions.map((p) => p.toJson()).toList(),
        'lastLossClosedAt': _lastLossClosedAt,
        'lastTradeNotional': _lastTradeNotional,
      };

  void fromJson(Map<String, dynamic> json) {
    _openPositions.clear();

    final openData = (json['openPositions'] ?? json['positions']) as List<dynamic>?;
    if (openData != null) {
      for (final item in openData) {
        try {
          _openPositions.add(Position.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          _logger.error('Failed to load position: $e');
        }
      }
    }

    _lastLossClosedAt = json['lastLossClosedAt'] as int? ?? 0;
    _lastTradeNotional =
        (json['lastTradeNotional'] as num?)?.toDouble() ?? 0.0;

    _logger.info('Position state loaded: ${_openPositions.length} open positions');
    notifyListeners();
  }

  // ============================================================
  // PRIVATE HELPERS — spread now handled by TradingEngine
  // ============================================================

  @override
  void dispose() {
    _equitySubscription?.cancel();
    _logger.info('PositionController disposed');
    super.dispose();
  }
}
