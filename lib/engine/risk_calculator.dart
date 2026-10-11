/// Risk Calculator — computes position size and risk metrics from account
/// balance, risk percentage, entry/SL/TP prices.
///
/// Streamlined for the replay order flow. Sits between the risk calculator
/// widget and the order placement in ReplayController.
library;

import 'dart:math' as math;

class RiskCalculation {
  /// Validation feedback; invalid calculations cannot be applied.
  final String? error;
  final bool buyingPowerLimited;
  bool get isValid => error == null && quantity > 0;

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
    this.error,
    this.buyingPowerLimited = false,
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

  /// Size by total estimated stop loss INCLUDING fees and adverse stop slippage.
  /// Entry is the expected fill price. Leverage caps buying power, never risk.
  /// Direction may be inferred for backwards compatibility; order tickets must
  /// pass [isLong] explicitly. These are estimates, not guaranteed loss limits.
  static RiskCalculation compute({
    required double accountBalance,
    required double riskPercent,
    required double entryPrice,
    required double stopLossPrice,
    double? takeProfitPrice,
    bool? isLong,
    double leverage = 1.0,
    double feePercent = 0.075,
    double slippagePercent = 0.05,
  }) {
    RiskCalculation invalid(String message) => RiskCalculation(
      positionSize: 0, quantity: 0, riskAmount: 0, potentialReward: 0,
      riskRewardRatio: 0, riskPercent: 0, feeCost: 0, netReward: 0,
      error: message,
    );
    final inputs = [accountBalance, riskPercent, entryPrice, stopLossPrice,
      leverage, feePercent, slippagePercent, if (takeProfitPrice != null) takeProfitPrice];
    if (inputs.any((v) => !v.isFinite)) {
      return invalid('Use finite numeric values for every field.');
    }
    if (accountBalance <= 0 || entryPrice <= 0 || stopLossPrice <= 0) {
      return invalid('Balance, entry and stop loss must be positive.');
    }
    if (riskPercent <= 0 || riskPercent > 10 || leverage < 1 || leverage > 100 ||
        feePercent < 0 || feePercent > 5 || slippagePercent < 0 || slippagePercent > 5) {
      return invalid('Risk must be 0–10%, leverage 1–100x and costs 0–5%.');
    }
    final long = isLong ?? stopLossPrice < entryPrice;
    if (long ? stopLossPrice >= entryPrice : stopLossPrice <= entryPrice) {
      return invalid(long ? 'Long stop must be below entry.' : 'Short stop must be above entry.');
    }
    if (takeProfitPrice != null && (takeProfitPrice <= 0 ||
        (long ? takeProfitPrice <= entryPrice : takeProfitPrice >= entryPrice))) {
      return invalid(long ? 'Long target must be above entry.' : 'Short target must be below entry.');
    }
    final fee = feePercent / 100;
    final stopFill = stopLossPrice * (1 + (long ? -1 : 1) * slippagePercent / 100);
    final lossPerUnit = (entryPrice - stopFill).abs() + (entryPrice + stopFill) * fee;
    final budget = accountBalance * riskPercent / 100;
    final riskQuantity = budget / lossPerUnit;
    // Margin plus entry fee must fit available funds.
    final maxQuantity = accountBalance / (entryPrice / leverage + entryPrice * fee);
    final quantity = math.min(riskQuantity, maxQuantity);
    final notional = quantity * entryPrice;
    final risk = quantity * lossPerUnit;
    final reward = takeProfitPrice == null ? 0.0 :
        quantity * (long ? takeProfitPrice - entryPrice : entryPrice - takeProfitPrice);
    final fees = quantity * (entryPrice + (takeProfitPrice ?? stopFill)) * fee;
    final netReward = takeProfitPrice == null ? 0.0 : reward - fees;
    if (![quantity, notional, risk, reward, fees, netReward].every((v) => v.isFinite)) {
      return invalid('Values exceed supported calculation range.');
    }
    return RiskCalculation(
      positionSize: notional, quantity: quantity, riskAmount: risk,
      potentialReward: reward, riskRewardRatio: risk > 0 ? netReward / risk : 0,
      riskPercent: risk / accountBalance * 100, feeCost: fees,
      netReward: netReward, stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice, buyingPowerLimited: maxQuantity < riskQuantity,
    );
  }

  static double quickPositionSize({
    required double accountBalance,
    required double riskPercent,
    required double entryPrice,
    required double stopLossPrice,
  }) => compute(accountBalance: accountBalance, riskPercent: riskPercent,
    entryPrice: entryPrice, stopLossPrice: stopLossPrice).positionSize;
}
