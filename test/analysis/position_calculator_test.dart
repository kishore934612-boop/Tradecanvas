import 'package:flutter_test/flutter_test.dart';
import 'package:app/analysis/position_tool/position_calculator.dart';
import 'package:app/analysis/position_tool/position_tool.dart';

void main() {
  group('PositionCalculator Financial Math Tests', () {
    test('calculates Long Position metrics correctly', () {
      const tool = PositionTool(
        id: 'p1',
        symbol: 'BTCUSDT',
        mode: PositionToolMode.longPosition,
        entryPrice: 50000.0,
        stopLossPrice: 48000.0, // 4% stop loss
        takeProfitPrice: 55000.0, // 10% take profit
        entryTimestamp: 1000,
        targetTimestamp: 2000,
        accountSize: 10000.0,
        riskPercent: 2.0, // $200 risk
        leverage: 10.0,
        feePercent: 0.05,
        createdAt: 1000,
      );

      final result = PositionCalculator.calculate(tool);

      // Price risk % = (50000 - 48000) / 50000 * 100 = 4.0%
      expect(result.riskPercent, equals(4.0));

      // Price reward % = (55000 - 50000) / 50000 * 100 = 10.0%
      expect(result.rewardPercent, equals(10.0));

      // Risk Reward Ratio = 10.0 / 4.0 = 2.5
      expect(result.riskRewardRatio, equals(2.5));

      // Risk Amount = $10,000 * 2% = $200
      expect(result.riskAmount, equals(200.0));

      // Position Size = $200 / (4% / 100) = $5,000
      expect(result.positionSize, equals(5000.0));

      // Quantity = $5,000 / 50,000 = 0.1 BTC
      expect(result.quantity, equals(0.1));

      // Margin Required = $5,000 / 10x leverage = $500
      expect(result.marginRequired, equals(500.0));

      // Fee cost = $5000 * 0.05% * 2 = $5.00
      expect(result.feeCost, equals(5.0));

      // Potential Profit = ($5000 * 10%) - $5 fee = $495.00
      expect(result.potentialProfit, equals(495.0));

      // Potential Loss = $200 + $5 fee = $205.00
      expect(result.potentialLoss, equals(205.0));

      // ROI = ($495 / $500) * 100 = 99.0%
      expect(result.roiPercent, equals(99.0));

      // Breakeven = 50,000 * (1 + 0.001) = 50,050
      expect(result.breakevenPrice, closeTo(50050.0, 0.01));
    });

    test('calculates Short Position metrics correctly', () {
      const tool = PositionTool(
        id: 'p2',
        symbol: 'BTCUSDT',
        mode: PositionToolMode.shortPosition,
        entryPrice: 50000.0,
        stopLossPrice: 52000.0, // 4% stop loss
        takeProfitPrice: 45000.0, // 10% take profit
        entryTimestamp: 1000,
        targetTimestamp: 2000,
        accountSize: 10000.0,
        riskPercent: 1.0, // $100 risk
        leverage: 5.0,
        feePercent: 0.05,
        createdAt: 1000,
      );

      final result = PositionCalculator.calculate(tool);

      expect(result.riskPercent, equals(4.0));
      expect(result.rewardPercent, equals(10.0));
      expect(result.riskRewardRatio, equals(2.5));
      expect(result.riskAmount, equals(100.0));
      expect(result.positionSize, equals(2500.0));
      expect(result.marginRequired, equals(500.0));
    });
  });
}
