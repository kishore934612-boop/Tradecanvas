import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/risk_calculator.dart';

void main() {
  group('RiskCalculator tests', () {
    test('fees and adverse stop slippage stay inside risk budget', () {
      final c = RiskCalculator.compute(accountBalance: 10000, riskPercent: 1,
        entryPrice: 100, stopLossPrice: 95, takeProfitPrice: 110, isLong: true);
      expect(c.isValid, isTrue);
      expect(c.riskAmount, closeTo(100, 1e-8));
      expect(c.quantity, lessThan(20));
      expect(c.netReward, lessThan(c.potentialReward));
      expect(c.riskRewardRatio, lessThan(2));
    });
    test('tight stops cap size by buying power including entry fee', () {
      final c = RiskCalculator.compute(accountBalance: 1000, riskPercent: 10,
        entryPrice: 100, stopLossPrice: 99.99);
      expect(c.buyingPowerLimited, isTrue);
      expect(c.positionSize * 1.00075, lessThanOrEqualTo(1000.0000001));
      expect(c.riskPercent, lessThan(10));
    });
    test('explicit direction rejects wrong-side stop and target', () {
      expect(RiskCalculator.compute(accountBalance: 1000, riskPercent: 1,
        entryPrice: 100, stopLossPrice: 110, isLong: true).isValid, isFalse);
      expect(RiskCalculator.compute(accountBalance: 1000, riskPercent: 1,
        entryPrice: 100, stopLossPrice: 110, takeProfitPrice: 120, isLong: false).isValid, isFalse);
    });
    test('invalid numeric inputs fail closed', () {
      for (final v in [double.nan, double.infinity, -1.0, 0.0, 101.0]) {
        expect(RiskCalculator.compute(accountBalance: 1000, riskPercent: v,
          entryPrice: 100, stopLossPrice: 95).isValid, isFalse);
      }
    });
    test('calculate standard 1% risk long position', () {
      final calc = RiskCalculator.compute(
        accountBalance: 10000,
        riskPercent: 1.0,
        entryPrice: 100,
        stopLossPrice: 95,
        takeProfitPrice: 110,
        feePercent: 0,
        slippagePercent: 0,
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
