/// Risk Management Engine
///
/// Pure business logic for stop loss, take profit, trailing stop,
/// and liquidation triggers.  Stateless — takes positions and prices,
/// returns triggers.  Called every tick by TradingProvider.
library;

import 'dart:math';
import 'package:app/models/trading_models.dart';
import 'package:app/constants/markets.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/di/service_locator.dart';

enum RiskTriggerType { stopLoss, takeProfit, trailingStop, liquidation }

/// Represents a single triggered risk event for one position.
class RiskTrigger {
  final String positionId;
  final RiskTriggerType type;
  final double triggerPrice;
  final String reason;

  const RiskTrigger({
    required this.positionId,
    required this.type,
    required this.triggerPrice,
    required this.reason,
  });
}

class RiskManagementEngine {
  final Logger _logger;

  RiskManagementEngine({required this._logger}) {
    _logger.info('RiskManagementEngine initialized');
  }

  /// Checks portfolio-level margin, emits MarginCallWarningEvent if margin level < 120%,
  /// and returns a list of LiquidationWarningEvent data if margin level is between 100% and 150%.
  List<LiquidationWarningEvent> checkLiquidationWarnings(
    List<Position> positions,
    Map<String, double> currentPrices,
    double balance,
  ) {
    final warnings = <LiquidationWarningEvent>[];
    if (positions.isEmpty) return warnings;

    double unrealizedPnl = 0.0;
    double usedMargin = 0.0;
    for (final p in positions) {
      final price = currentPrices[p.symbol] ?? 0.0;
      if (price > 0) {
        unrealizedPnl += p.pnl(price);
      }
      usedMargin += p.margin;
    }

    final equity = balance + usedMargin + unrealizedPnl;
    final marginLevel = usedMargin > 0 ? (equity / usedMargin) * 100.0 : 0.0;

    if (marginLevel > 0 && marginLevel < 120.0) {
      final eventBus = serviceLocator.isRegistered<EventBus>()
          ? serviceLocator<EventBus>()
          : EventBus.instance;
      eventBus.publish<MarginCallWarningEvent>(MarginCallWarningEvent(
        marginLevel: marginLevel,
        usedMargin: usedMargin,
        equity: equity,
        positionsAtRisk: positions.map((p) => p.id).toList(),
      ));
    }

    if (marginLevel > 100.0 && marginLevel < 150.0) {
      for (final p in positions) {
        warnings.add(LiquidationWarningEvent(
          positionId: p.id,
          symbol: p.symbol,
          marginLevel: marginLevel,
          liquidationPrice: p.liquidationPrice,
        ));
      }
    }

    return warnings;
  }

  // ============================================================
  // MAIN EVALUATION
  // ============================================================

  /// Evaluate all risk triggers for every open position.
  ///
  /// Returns a list of triggers.  The caller is responsible for acting on
  /// them (closing positions, etc.).  Mutates [position.trailingAnchor]
  /// in-place for trailing stops as a side-effect.
  List<RiskTrigger> evaluateTriggers(
    List<Position> positions,
    Map<String, double> currentPrices,
  ) {
    final triggers = <RiskTrigger>[];

    for (final position in positions) {
      final price = currentPrices[position.symbol];
      if (price == null || price <= 0) continue;

      final config = MarketConfig.get(position.marketType, position.tradingType);

      // 1. Update trailing stop anchor BEFORE checking triggers
      if (position.trailingStop != null) {
        _updateTrailingAnchorInPlace(position, price);
      }

      // 2. Liquidation takes highest precedence
      if (config.liquidationExists && shouldLiquidate(position, price)) {
        triggers.add(RiskTrigger(
          positionId: position.id,
          type: RiskTriggerType.liquidation,
          triggerPrice: position.liquidationPrice,
          reason: 'liquidation',
        ));
        continue;
      }

      // 3. Trailing stop
      if (position.trailingStop != null &&
          shouldTrailingStop(position, price)) {
        triggers.add(RiskTrigger(
          positionId: position.id,
          type: RiskTriggerType.trailingStop,
          triggerPrice: price,
          reason: 'trailingStop',
        ));
        continue;
      }

      // 4. Stop loss
      if (position.stopLoss != null && shouldStopLoss(position, price)) {
        triggers.add(RiskTrigger(
          positionId: position.id,
          type: RiskTriggerType.stopLoss,
          triggerPrice: position.stopLoss!,
          reason: 'stopLoss',
        ));
        continue;
      }

      // 5. Take profit
      if (position.takeProfit != null && shouldTakeProfit(position, price)) {
        triggers.add(RiskTrigger(
          positionId: position.id,
          type: RiskTriggerType.takeProfit,
          triggerPrice: position.takeProfit!,
          reason: 'takeProfit',
        ));
      }
    }

    if (triggers.isNotEmpty) {
      _logger.info('${triggers.length} risk trigger(s) fired');
    }

    return triggers;
  }

  // ============================================================
  // INDIVIDUAL CHECKS
  // ============================================================

  bool shouldLiquidate(Position position, double currentPrice) {
    final config = MarketConfig.get(position.marketType, position.tradingType);
    if (!config.liquidationExists) return false;
    final mmr = 0.005; // 0.5% MMR
    final maintenanceMargin = position.qty * currentPrice * mmr;
    final remainingMargin = position.margin + position.pnl(currentPrice);
    return remainingMargin <= maintenanceMargin;
  }

  bool shouldStopLoss(Position position, double currentPrice) {
    if (position.stopLoss == null) return false;
    return position.side == PositionSide.long
        ? currentPrice <= position.stopLoss!
        : currentPrice >= position.stopLoss!;
  }

  bool shouldTakeProfit(Position position, double currentPrice) {
    if (position.takeProfit == null) return false;
    return position.side == PositionSide.long
        ? currentPrice >= position.takeProfit!
        : currentPrice <= position.takeProfit!;
  }

  bool shouldTrailingStop(Position position, double currentPrice) {
    if (position.trailingStop == null) return false;
    if (position.trailingAnchor == null) return false;
    return position.side == PositionSide.long
        ? currentPrice <= position.trailingAnchor! - position.trailingStop!
        : currentPrice >= position.trailingAnchor! + position.trailingStop!;
  }

  // ============================================================
  // CALCULATIONS
  // ============================================================

  /// Calculate margin required to open a position.
  double calculateMargin({
    required double qty,
    required double price,
    required double leverage,
    required MarketConfig config,
  }) {
    final actualQty = config.lotSizeUsed ? qty * config.lotBaseUnits : qty;
    final notional = actualQty * price;
    return config.leverageAllowed ? notional / leverage : notional;
  }

  /// Validate stop loss / take profit / trailing stop values.
  /// Returns null when valid, error message when invalid.
  String? validateRiskParameters({
    required double entryPrice,
    required PositionSide side,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
  }) {
    if (stopLoss != null) {
      if (side == PositionSide.long && stopLoss >= entryPrice) {
        return 'Stop loss must be below entry price for a long position';
      }
      if (side == PositionSide.short && stopLoss <= entryPrice) {
        return 'Stop loss must be above entry price for a short position';
      }
    }
    if (takeProfit != null) {
      if (side == PositionSide.long && takeProfit <= entryPrice) {
        return 'Take profit must be above entry price for a long position';
      }
      if (side == PositionSide.short && takeProfit >= entryPrice) {
        return 'Take profit must be below entry price for a short position';
      }
    }
    if (trailingStop != null && trailingStop <= 0) {
      return 'Trailing stop must be a positive value';
    }
    return null;
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  void _updateTrailingAnchorInPlace(Position position, double currentPrice) {
    if (position.side == PositionSide.long) {
      position.trailingAnchor = position.trailingAnchor == null
          ? currentPrice
          : max(position.trailingAnchor!, currentPrice);
    } else {
      position.trailingAnchor = position.trailingAnchor == null
          ? currentPrice
          : min(position.trailingAnchor!, currentPrice);
    }
  }
}
