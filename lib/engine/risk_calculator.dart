/// Risk Calculator — computes position size and risk metrics from account
/// balance, risk percentage, entry/SL/TP prices.
///
/// Streamlined for the replay order flow. Sits between the risk calculator
/// widget and the order placement in ReplayController.
library;

class RiskCalculation {
  /// Position size in quote currency (e.g. USDT).
  final double positionSize;

  /// Quantity in base currency (e.g. BTC).
  final double quantity;

  /// Dollar amount at risk if SL is hit.
  final double riskAmount;

  /// Dollar reward if TP is hit.
  final double potentialReward;

  /// Risk-to-reward ratio.
  final double riskRewardRatio;

  /// Risk as percentage of account balance.
  final double riskPercent;

  /// Estimated fee cost (open + close).
  final double feeCost;

  /// Net profit after fees if TP is hit.
  final double netReward;

  /// Input SL and TP prices for reference.
  final double stopLossPrice;
  final double? takeProfitPrice;

  const RiskCalculation({
    required this.positionSize,
    required this.quantity,
    required this.riskAmount,
    required this.potentialReward,
    required this.riskRewardRatio,
    required this.riskPercent,
    required this.feeCost,
    required this.netReward,
    this.stopLossPrice = 0,
    this.takeProfitPrice,
  });

  static const RiskCalculation zero = RiskCalculation(
    positionSize: 0,
    quantity: 0,
    riskAmount: 0,
    potentialReward: 0,
    riskRewardRatio: 0,
    riskPercent: 0,
    feeCost: 0,
    netReward: 0,
    stopLossPrice: 0,
  );
}

class RiskCalculator {
  RiskCalculator._();

  /// Compute position sizing and risk metrics.
  ///
  /// [accountBalance] — current account balance in quote currency.
  /// [riskPercent] — percentage of account to risk (e.g. 1.0 = 1%).
  /// [entryPrice] — planned entry price.
  /// [stopLossPrice] — stop loss price.
  /// [takeProfitPrice] — optional take profit price.
  /// [leverage] — leverage multiplier (default 1.0).
  /// [feePercent] — per-side fee percentage (default 0.075%).
  static RiskCalculation compute({
    required double accountBalance,
    required double riskPercent,
    required double entryPrice,
    required double stopLossPrice,
    double? takeProfitPrice,
    double leverage = 1.0,
    double feePercent = 0.075,
  }) {
    if (accountBalance <= 0 || entryPrice <= 0 || stopLossPrice <= 0) {
      return RiskCalculation.zero;
    }

    final isLong = stopLossPrice < entryPrice;

    // Price risk percentage (distance from entry to SL).
    final priceRiskPct = (entryPrice - stopLossPrice).abs() / entryPrice;
    if (priceRiskPct <= 0) return RiskCalculation.zero;

    // Dollar risk amount.
    final riskAmount = accountBalance * (riskPercent / 100.0);

    // Position size: risk_amount / price_risk_pct — how much notional to
    // hold so that moving entry→SL costs exactly riskAmount.
    final positionSize = riskAmount / priceRiskPct;

    // Quantity in base asset.
    final quantity = positionSize / entryPrice;

    // Fee cost (open + close).
    final feeCost = positionSize * (feePercent / 100.0) * 2.0;

    // Potential reward calculation.
    double potentialReward = 0;
    double riskRewardRatio = 0;
    if (takeProfitPrice != null && takeProfitPrice > 0) {
      final priceRewardPct = isLong
          ? (takeProfitPrice - entryPrice) / entryPrice
          : (entryPrice - takeProfitPrice) / entryPrice;
      final rawReward = positionSize * priceRewardPct;
      potentialReward = rawReward;
      riskRewardRatio = priceRiskPct > 0 ? priceRewardPct / priceRiskPct : 0;
    }

    final netReward = potentialReward - feeCost;

    return RiskCalculation(
      positionSize: positionSize,
      quantity: quantity,
      riskAmount: riskAmount,
      potentialReward: potentialReward,
      riskRewardRatio: riskRewardRatio,
      riskPercent: riskPercent,
      feeCost: feeCost,
      netReward: netReward,
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
    );
  }

  /// Quick position size calculation (no TP, just entry + SL).
  static double quickPositionSize({
    required double accountBalance,
    required double riskPercent,
    required double entryPrice,
    required double stopLossPrice,
  }) {
    if (accountBalance <= 0 || entryPrice <= 0 || stopLossPrice <= 0) return 0;
    final priceRiskPct = (entryPrice - stopLossPrice).abs() / entryPrice;
    if (priceRiskPct <= 0) return 0;
    return (accountBalance * (riskPercent / 100.0)) / priceRiskPct;
  }
}
