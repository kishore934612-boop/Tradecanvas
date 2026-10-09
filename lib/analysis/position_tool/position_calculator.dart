/// Position Calculator engine executing financial math for position tools.
library;

import 'dart:math' as math;
import 'package:app/analysis/position_tool/position_tool.dart';

class PositionCalculationResult {
  final double riskAmount;
  final double rewardAmount;
  final double riskPercent;
  final double rewardPercent;
  final double riskRewardRatio;
  final double positionSize;
  final double quantity;
  final double marginRequired;
  final double potentialProfit;
  final double potentialLoss;
  final double roiPercent;
  final double liquidationPrice;
  final double breakevenPrice;
  final double feeCost;
  final double maxDrawdownPercent;

  const PositionCalculationResult({
    required this.riskAmount,
    required this.rewardAmount,
    required this.riskPercent,
    required this.rewardPercent,
    required this.riskRewardRatio,
    required this.positionSize,
    required this.quantity,
    required this.marginRequired,
    required this.potentialProfit,
    required this.potentialLoss,
    required this.roiPercent,
    required this.liquidationPrice,
    required this.breakevenPrice,
    required this.feeCost,
    required this.maxDrawdownPercent,
  });
}

class PositionCalculator {
  /// Calculate full position metrics for given position tool inputs.
  static PositionCalculationResult calculate(PositionTool tool) {
    final isLong = tool.mode == PositionToolMode.longPosition ||
        (tool.mode == PositionToolMode.riskReward && tool.takeProfitPrice >= tool.entryPrice);

    final entry = tool.entryPrice;
    final stop = tool.stopLossPrice;
    final target = tool.takeProfitPrice;
    final account = tool.accountSize;
    final riskPct = tool.riskPercent;
    final lev = tool.leverage > 0 ? tool.leverage : 1.0;
    final feePct = tool.feePercent;

    // Price deltas %
    final stopDelta = (entry - stop).abs();
    final targetDelta = (target - entry).abs();

    final priceRiskPct = entry > 0 ? (stopDelta / entry) * 100 : 0.0;
    final priceRewardPct = entry > 0 ? (targetDelta / entry) * 100 : 0.0;

    final rrRatio = priceRiskPct > 0 ? priceRewardPct / priceRiskPct : 0.0;

    final riskAmount = account * (riskPct / 100.0);
    final positionSize = priceRiskPct > 0 ? (riskAmount / (priceRiskPct / 100.0)) : 0.0;
    final quantity = entry > 0 ? positionSize / entry : 0.0;
    final marginRequired = positionSize / lev;

    final feeCost = positionSize * (feePct / 100.0) * 2.0; // Open + Close fees

    final rawPotentialProfit = positionSize * (priceRewardPct / 100.0);
    final potentialProfit = math.max(0.0, rawPotentialProfit - feeCost);
    final potentialLoss = riskAmount + feeCost;

    final rewardAmount = potentialProfit;

    final roiPercent = marginRequired > 0 ? (potentialProfit / marginRequired) * 100.0 : 0.0;

    // Liquidation Price calculation (Standard Isolated Leverage formula, assuming 0.5% maintenance margin)
    const mmr = 0.005;
    final liquidationPrice = isLong
        ? entry * (1.0 - (1.0 / lev) + mmr)
        : entry * (1.0 + (1.0 / lev) - mmr);

    // Breakeven Price accounting for fee costs
    final breakevenPrice = isLong
        ? entry * (1.0 + 2.0 * (feePct / 100.0))
        : entry * (1.0 - 2.0 * (feePct / 100.0));

    final maxDrawdownPercent = priceRiskPct * lev;

    return PositionCalculationResult(
      riskAmount: riskAmount,
      rewardAmount: rewardAmount,
      riskPercent: priceRiskPct,
      rewardPercent: priceRewardPct,
      riskRewardRatio: rrRatio,
      positionSize: positionSize,
      quantity: quantity,
      marginRequired: marginRequired,
      potentialProfit: potentialProfit,
      potentialLoss: potentialLoss,
      roiPercent: roiPercent,
      liquidationPrice: math.max(0.0, liquidationPrice),
      breakevenPrice: math.max(0.0, breakevenPrice),
      feeCost: feeCost,
      maxDrawdownPercent: maxDrawdownPercent,
    );
  }
}
