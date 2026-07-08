import 'package:app/models/trading_models.dart';

/// Result of a position-size / risk computation for the trading terminal.
class PositionCalc {
  final double qty;
  final double positionValue; // notional
  final double marginRequired;
  final double estimatedProfit;
  final double estimatedLoss;
  final double riskPct; // risk as % of account
  final double riskReward;
  final double liquidationPrice;

  const PositionCalc({
    required this.qty,
    required this.positionValue,
    required this.marginRequired,
    required this.estimatedProfit,
    required this.estimatedLoss,
    required this.riskPct,
    required this.riskReward,
    required this.liquidationPrice,
  });

  static const empty = PositionCalc(
    qty: 0,
    positionValue: 0,
    marginRequired: 0,
    estimatedProfit: 0,
    estimatedLoss: 0,
    riskPct: 0,
    riskReward: 0,
    liquidationPrice: 0,
  );
}

/// Computes a position from an explicit quantity.
PositionCalc calcFromQty({
  required double qty,
  required double entryPrice,
  required double leverage,
  required PositionSide side,
  double? stopLoss,
  double? takeProfit,
  required double accountEquity,
}) {
  final notional = qty * entryPrice;
  final margin = leverage > 0 ? notional / leverage : notional;

  double estLoss = 0;
  double riskPct = 0;
  if (stopLoss != null) {
    final perUnit = (entryPrice - stopLoss).abs();
    estLoss = perUnit * qty;
    riskPct = accountEquity > 0 ? (estLoss / accountEquity) * 100.0 : 0;
  }
  double estProfit = 0;
  if (takeProfit != null) {
    final perUnit = (takeProfit - entryPrice).abs();
    estProfit = perUnit * qty;
  }
  double rr = 0;
  if (stopLoss != null && takeProfit != null) {
    final riskUnit = (entryPrice - stopLoss).abs();
    final rewardUnit = (takeProfit - entryPrice).abs();
    rr = riskUnit > 0 ? rewardUnit / riskUnit : 0;
  }

  final move = leverage > 0 ? entryPrice / leverage : entryPrice;
  final liq = side == PositionSide.long ? entryPrice - move : entryPrice + move;

  return PositionCalc(
    qty: qty,
    positionValue: notional,
    marginRequired: margin,
    estimatedProfit: estProfit,
    estimatedLoss: estLoss,
    riskPct: riskPct,
    riskReward: rr,
    liquidationPrice: liq < 0 ? 0 : liq,
  );
}

/// Derives a position size from a target risk percentage of the account and a
/// stop-loss distance: qty = (equity * risk%) / |entry - stop|.
PositionCalc calcFromRisk({
  required double riskPercent,
  required double entryPrice,
  required double stopLoss,
  required double leverage,
  required PositionSide side,
  double? takeProfit,
  required double accountEquity,
}) {
  final perUnit = (entryPrice - stopLoss).abs();
  if (perUnit <= 0 || accountEquity <= 0) return PositionCalc.empty;
  final riskAmount = accountEquity * (riskPercent / 100.0);
  final qty = riskAmount / perUnit;
  return calcFromQty(
    qty: qty,
    entryPrice: entryPrice,
    leverage: leverage,
    side: side,
    stopLoss: stopLoss,
    takeProfit: takeProfit,
    accountEquity: accountEquity,
  );
}
