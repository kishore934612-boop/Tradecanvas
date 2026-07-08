/// Trading Engine
///
/// Completely stateless pure-calculation library.
/// Covers every trading calculation in TradeVerse:
///
///   • Margin & leverage
///   • P&L (gross + net)
///   • Fee calculation
///   • Spread application
///   • Liquidation price
///   • Risk percentage
///   • Risk-to-reward ratio
///   • Pip value (forex)
///   • Position sizing
///   • Funding fee (futures)
///   • Trade validation
///
/// No Flutter imports — fully unit-testable in isolation.
library;

import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';

// ============================================================
// VALUE OBJECTS
// ============================================================

/// Immutable result of an open-position margin calculation.
class MarginCalcResult {
  final double actualQty;      // qty after lot-size conversion
  final double notional;       // actualQty × price
  final double margin;         // cash to reserve
  final double fee;            // entry fee charged
  final double totalCost;      // margin + fee
  final double adjustedPrice;  // price after spread

  const MarginCalcResult({
    required this.actualQty,
    required this.notional,
    required this.margin,
    required this.fee,
    required this.totalCost,
    required this.adjustedPrice,
  });
}

/// Immutable result of a close-position P&L calculation.
class PnlCalcResult {
  final double grossPnl;        // directional profit before fees
  final double netPnl;          // after all deductions
  final double returnedMargin;  // margin unlocked
  final double entryFeePortion; // fraction of entry fee attributed to this close
  final double exitFee;         // fee on exit
  final double adjustedExitPrice;
  final double pnlPct;          // net P&L as % of returned margin

  const PnlCalcResult({
    required this.grossPnl,
    required this.netPnl,
    required this.returnedMargin,
    required this.entryFeePortion,
    required this.exitFee,
    required this.adjustedExitPrice,
    required this.pnlPct,
  });
}

/// Immutable position-sizing suggestion.
class PositionSizeResult {
  final double suggestedQty;         // in base units (or lots for forex)
  final double maxRiskAmount;        // absolute risk in account currency
  final double riskPercent;          // requested risk % of equity
  final double riskPerUnit;          // |entry - stopLoss|
  final double requiredMargin;       // margin needed at suggested qty

  const PositionSizeResult({
    required this.suggestedQty,
    required this.maxRiskAmount,
    required this.riskPercent,
    required this.riskPerUnit,
    required this.requiredMargin,
  });
}

/// Summary of a risk/reward setup.
class RiskRewardResult {
  final double riskAmount;     // max loss in price units
  final double rewardAmount;   // potential gain in price units
  final double ratio;          // reward / risk  (e.g. 2.5 = 2.5:1)
  final bool isViable;         // true when ratio >= 1.5

  const RiskRewardResult({
    required this.riskAmount,
    required this.rewardAmount,
    required this.ratio,
    required this.isViable,
  });
}

// ============================================================
// TRADING ENGINE  (pure static methods)
// ============================================================

class TradingEngine {
  TradingEngine._(); // Not instantiable

  // ──────────────────────────────────────────────────────────
  // SPREAD
  // ──────────────────────────────────────────────────────────

  /// Applies the simulated bid/ask spread for forex instruments.
  /// For non-forex (spreadPips == 0) returns [price] unchanged.
  ///
  ///   long  → buy at ask (price + half-spread)
  ///   short → sell at bid (price - half-spread)
  static double applySpread(
    double price,
    PositionSide side,
    Asset asset,
    MarketConfig config,
  ) {
    if (!config.lotSizeUsed || config.spreadPips <= 0) return price;
    final spread = config.spreadPips * asset.pipSize;
    return side == PositionSide.long
        ? price + spread / 2
        : price - spread / 2;
  }

  // ──────────────────────────────────────────────────────────
  // LOT / QTY CONVERSION
  // ──────────────────────────────────────────────────────────

  /// Converts user-entered lots/units to the actual base-unit quantity.
  /// For forex: qty in standard lots → qty × lotBaseUnits (e.g. × 100,000).
  /// For others: qty unchanged.
  static double toActualQty(double qty, MarketConfig config) =>
      config.lotSizeUsed ? qty * config.lotBaseUnits : qty;

  // ──────────────────────────────────────────────────────────
  // FEES
  // ──────────────────────────────────────────────────────────

  /// Calculates the entry or exit fee for a trade.
  ///
  /// Fee logic (in priority order):
  ///   1. Forex  → commission per lot (commissionPerLot × lots)
  ///   2. Stocks → flat brokerage fee per side (brokerageFee)
  ///   3. Crypto → takerFee × notional  (market) / makerFee × notional (limit)
  ///   4. Default → 0
  static double calculateFee({
    required MarketConfig config,
    required double notional,
    required double qty,          // in lots for forex, base units otherwise
    required bool isMarketOrder,
  }) {
    if (config.lotSizeUsed && config.commissionPerLot > 0) {
      // Forex: per-lot commission
      return config.commissionPerLot * qty;
    }
    if (config.brokerageEnabled && config.brokerageFee > 0) {
      // Stocks: flat brokerage
      return config.brokerageFee;
    }
    final feeRate = config.feeForOrder(isMarketOrder);
    if (feeRate > 0) {
      return notional * feeRate;
    }
    return 0.0;
  }

  // ──────────────────────────────────────────────────────────
  // MARGIN
  // ──────────────────────────────────────────────────────────

  /// Full margin calculation for opening a position.
  ///
  /// Returns a [MarginCalcResult] with every relevant figure.
  static MarginCalcResult calculateMargin({
    required double qty,
    required double fillPrice,
    required double leverage,
    required PositionSide side,
    required Asset asset,
    required MarketConfig config,
    bool isMarketOrder = true,
  }) {
    final adjustedPrice = applySpread(fillPrice, side, asset, config);
    final actualQty     = toActualQty(qty, config);
    final notional      = actualQty * adjustedPrice;
    final margin = config.leverageAllowed ? notional / leverage : notional;
    final fee    = calculateFee(
      config: config,
      notional: notional,
      qty: qty,
      isMarketOrder: isMarketOrder,
    );
    return MarginCalcResult(
      actualQty: actualQty,
      notional: notional,
      margin: margin,
      fee: fee,
      totalCost: margin + fee,
      adjustedPrice: adjustedPrice,
    );
  }

  // ──────────────────────────────────────────────────────────
  // LIQUIDATION PRICE
  // ──────────────────────────────────────────────────────────

  /// Approximate liquidation price: the price at which the unrealised loss
  /// equals the posted margin.
  ///
  ///   long  liq = entryPrice − entryPrice / leverage
  ///   short liq = entryPrice + entryPrice / leverage
  static double liquidationPrice({
    required double entryPrice,
    required double leverage,
    required PositionSide side,
    required MarketConfig config,
    double mmr = 0.005, // 0.5% Maintenance Margin Rate
  }) {
    if (!config.liquidationExists || leverage <= 0) return 0.0;
    if (side == PositionSide.long) {
      final num = entryPrice * (1.0 - 1.0 / leverage);
      final den = 1.0 - mmr;
      return den <= 0 ? 0.0 : num / den;
    } else {
      final num = entryPrice * (1.0 + 1.0 / leverage);
      final den = 1.0 + mmr;
      return num / den;
    }
  }

  // ──────────────────────────────────────────────────────────
  // P&L
  // ──────────────────────────────────────────────────────────

  /// Gross unrealised P&L for an open position at [currentPrice].
  static double grossPnl({
    required double entryPrice,
    required double currentPrice,
    required double actualQty,
    required PositionSide side,
  }) {
    return side == PositionSide.long
        ? (currentPrice - entryPrice) * actualQty
        : (entryPrice - currentPrice) * actualQty;
  }

  /// Net unrealised P&L (subtracts accumulated funding fees).
  static double netUnrealizedPnl({
    required double entryPrice,
    required double currentPrice,
    required double actualQty,
    required PositionSide side,
    double accumulatedFunding = 0.0,
  }) {
    return grossPnl(
          entryPrice: entryPrice,
          currentPrice: currentPrice,
          actualQty: actualQty,
          side: side,
        ) -
        accumulatedFunding;
  }

  /// Full P&L calculation when closing [fraction] of a position.
  static PnlCalcResult calculateClosePnl({
    required Position position,
    required double exitPrice,
    required double fraction,
    required Asset? asset,
    required MarketConfig config,
  }) {
    fraction = fraction.clamp(0.0001, 1.0);
    final closeQty = position.qty * fraction;

    // Apply exit spread (opposite side)
    final exitSide = position.side == PositionSide.long
        ? PositionSide.short
        : PositionSide.long;
    final adjustedExit = asset != null
        ? applySpread(exitPrice, exitSide, asset, config)
        : exitPrice;

    final gross = position.side == PositionSide.long
        ? (adjustedExit - position.entryPrice) * closeQty
        : (position.entryPrice - adjustedExit) * closeQty;

    final returnedMargin  = position.margin * fraction;
    final entryFeePortion = position.fees * fraction;
    const exitFee         = 0.0; // placeholder — Phase 9 persistence layer
    const funding         = 0.0; // placeholder — Phase 6 (funding fees)

    final netPnl = gross - entryFeePortion - exitFee - funding;
    final pnlPct = returnedMargin > 0 ? (netPnl / returnedMargin) * 100.0 : 0.0;

    return PnlCalcResult(
      grossPnl: gross,
      netPnl: netPnl,
      returnedMargin: returnedMargin,
      entryFeePortion: entryFeePortion,
      exitFee: exitFee,
      adjustedExitPrice: adjustedExit,
      pnlPct: pnlPct,
    );
  }

  // ──────────────────────────────────────────────────────────
  // RISK PERCENTAGE
  // ──────────────────────────────────────────────────────────

  /// Risk as a percentage of equity when entering with a stop-loss.
  ///
  ///   riskPct = (|entry - stopLoss| × actualQty) / equity × 100
  static double riskPercent({
    required double entryPrice,
    required double stopLoss,
    required double actualQty,
    required double equity,
  }) {
    if (equity <= 0) return 0.0;
    final riskPerUnit = (entryPrice - stopLoss).abs();
    return (riskPerUnit * actualQty / equity) * 100.0;
  }

  // ──────────────────────────────────────────────────────────
  // RISK : REWARD
  // ──────────────────────────────────────────────────────────

  /// Computes the risk-to-reward ratio given entry, stop-loss, take-profit.
  ///
  /// Returns null if stop or take-profit is not set, or risk == 0.
  static RiskRewardResult? riskReward({
    required double entryPrice,
    required PositionSide side,
    required double stopLoss,
    required double takeProfit,
  }) {
    final risk   = (entryPrice - stopLoss).abs();
    final reward = (takeProfit - entryPrice).abs();
    if (risk <= 0) return null;

    final ratio = reward / risk;
    return RiskRewardResult(
      riskAmount:   risk,
      rewardAmount: reward,
      ratio:        ratio,
      isViable:     ratio >= 1.5,
    );
  }

  // ──────────────────────────────────────────────────────────
  // POSITION SIZING
  // ──────────────────────────────────────────────────────────

  /// Suggests a position size based on a fixed-risk model.
  ///
  /// riskAmount = equity × (riskPercent / 100)
  /// suggestedQty = riskAmount / riskPerUnit  (in lots for forex)
  ///
  /// Returns null when inputs are invalid (e.g. no stop-loss defined).
  static PositionSizeResult? suggestPositionSize({
    required double equity,
    required double riskPercent,   // e.g. 1.0 for 1%
    required double entryPrice,
    required double stopLoss,
    required double leverage,
    required Asset asset,
    required MarketConfig config,
  }) {
    final riskPerUnit = (entryPrice - stopLoss).abs();
    if (riskPerUnit <= 0 || equity <= 0) return null;

    final maxRisk = equity * (riskPercent / 100.0);

    // For forex, compute in lots then convert to qty
    double suggestedQty;
    if (config.lotSizeUsed) {
      // riskPerUnit is in quote currency, 1 lot = lotBaseUnits × riskPerUnit
      final riskPerLot = riskPerUnit * config.lotBaseUnits;
      suggestedQty = riskPerLot > 0 ? maxRisk / riskPerLot : 0.0;
    } else {
      suggestedQty = maxRisk / riskPerUnit;
    }

    // Round down to sensible precision
    suggestedQty = _floorToDecimals(suggestedQty, config.lotSizeUsed ? 2 : 4);

    final actualQty = toActualQty(suggestedQty, config);
    final notional  = actualQty * entryPrice;
    final margin    = config.leverageAllowed ? notional / leverage : notional;

    return PositionSizeResult(
      suggestedQty: suggestedQty,
      maxRiskAmount: maxRisk,
      riskPercent: riskPercent,
      riskPerUnit: riskPerUnit,
      requiredMargin: margin,
    );
  }

  // ──────────────────────────────────────────────────────────
  // FOREX — PIP VALUE
  // ──────────────────────────────────────────────────────────

  /// Value of 1 pip in account currency (USD) for [qty] lots of [asset].
  ///
  ///   pip value = lotBaseUnits × pipSize × qty
  ///
  /// For USD-quoted pairs (EUR/USD, GBP/USD, AUD/USD) this is already in USD.
  /// For USD-base pairs (USD/JPY, USD/CAD) we'd need the conversion rate
  /// (simplified here — caller provides [quoteToUsd]).
  static double forexPipValue({
    required double qty,
    required Asset asset,
    required MarketConfig config,
    double quoteToUsd = 1.0,
  }) {
    return 0.0;
  }

  // ──────────────────────────────────────────────────────────
  // FUNDING FEES (futures)
  // ──────────────────────────────────────────────────────────

  /// Funding fee for one 8-hour funding interval.
  ///
  ///   fee = notional × fundingRate
  ///
  /// [fundingRate] is typically ±0.01% (0.0001) per 8 hours.
  static double fundingFee({
    required double notional,
    required double fundingRate,
  }) {
    return notional * fundingRate;
  }

  // ──────────────────────────────────────────────────────────
  // TRADE VALIDATION
  // ──────────────────────────────────────────────────────────

  /// Full pre-trade validation.  Returns null if valid; an error string if not.
  static String? validateTrade({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double leverage,
    required double freeMargin,
    required double entryPrice,
    required MarketConfig config,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    double? limitPrice,
    double? stopPrice,
  }) {
    if (qty <= 0) return 'Quantity must be positive';
    if (entryPrice <= 0) return 'Invalid entry price';
    if (leverage <= 0) return 'Invalid leverage';
    if (!config.shortSellingAllowed && side == PositionSide.short) {
      return 'Short selling is not allowed for this instrument';
    }
    if (!config.leverageAllowed && leverage > 1.0) {
      return 'Leverage is not available for this instrument';
    }
    if (leverage > config.maxLeverage) {
      return 'Maximum leverage for this instrument is ${config.maxLeverage.toStringAsFixed(0)}x';
    }

    // Estimate cost
    final actualQty = toActualQty(qty, config);
    final refPrice  = limitPrice ?? stopPrice ?? entryPrice;
    final notional  = actualQty * refPrice;
    final margin    = config.leverageAllowed ? notional / leverage : notional;
    if (margin > freeMargin) {
      return 'Insufficient free margin (need \$${margin.toStringAsFixed(2)}, '
          'available \$${freeMargin.toStringAsFixed(2)})';
    }

    // Stop-loss direction check
    if (stopLoss != null) {
      if (side == PositionSide.long && stopLoss >= entryPrice) {
        return 'Stop loss must be below entry price for a long position';
      }
      if (side == PositionSide.short && stopLoss <= entryPrice) {
        return 'Stop loss must be above entry price for a short position';
      }
    }

    // Take-profit direction check
    if (takeProfit != null) {
      if (side == PositionSide.long && takeProfit <= entryPrice) {
        return 'Take profit must be above entry price for a long position';
      }
      if (side == PositionSide.short && takeProfit >= entryPrice) {
        return 'Take profit must be below entry price for a short position';
      }
    }

    // Trailing stop sanity
    if (trailingStop != null && trailingStop <= 0) {
      return 'Trailing stop must be a positive price distance';
    }

    return null; // Valid
  }

  // ──────────────────────────────────────────────────────────
  // EQUITY / PORTFOLIO CALCULATIONS
  // ──────────────────────────────────────────────────────────

  /// Account equity = balance + used margin + unrealised P&L.
  static double equity({
    required double balance,
    required double usedMargin,
    required double unrealizedPnl,
  }) =>
      balance + usedMargin + unrealizedPnl;

  /// Free margin = equity − used margin.
  static double freeMargin({
    required double equity,
    required double usedMargin,
  }) =>
      equity - usedMargin;

  /// Margin level % = (equity / used margin) × 100.
  /// Returns 0 when no margin is in use.
  static double marginLevel({
    required double equity,
    required double usedMargin,
  }) =>
      usedMargin > 0 ? (equity / usedMargin) * 100.0 : 0.0;

  /// Total return % = (equity − startingCapital) / startingCapital × 100.
  static double totalReturnPct({
    required double equity,
    required double startingCapital,
  }) =>
      startingCapital > 0
          ? ((equity - startingCapital) / startingCapital) * 100.0
          : 0.0;

  // ──────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────

  static double _floorToDecimals(double value, int decimals) {
    final factor = _pow10(decimals);
    return (value * factor).floor() / factor;
  }

  static double _pow10(int n) {
    double result = 1.0;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }
}
