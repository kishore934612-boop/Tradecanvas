import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/risk_calculator.dart';

void main() {
  group('RiskCalculator tests', () {
    test('calculate standard 1% risk long position', () {
      final calc = RiskCalculator.compute(
        accountBalance: 10000,
        riskPercent: 1.0,
        entryPrice: 100,
        stopLossPrice: 95,
        takeProfitPrice: 110,
      );

      expect(calc.riskAmount, equals(100.0)); // 1% of 10000
      expect(calc.positionSize, closeTo(2000.0, 0.01)); // $100 risk / 5% stop distance
      expect(calc.quantity, closeTo(20.0, 0.01)); // 2000 / 100
      expect(calc.potentialReward, closeTo(200.0, 0.01)); // 10% target gain on $2000
      expect(calc.riskRewardRatio, closeTo(2.0, 0.01)); // 10% gain / 5% risk
    });

    test('returns zero for invalid inputs', () {
      final calc = RiskCalculator.compute(
        accountBalance: 0,
        riskPercent: 1.0,
        entryPrice: 100,
        stopLossPrice: 95,
      );

      expect(calc.positionSize, equals(0));
    });
  });
}
