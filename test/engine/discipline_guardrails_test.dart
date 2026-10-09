import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/discipline_guardrails.dart';

void main() {
  group('DisciplineGuardrails tests', () {
    const settings = DisciplineSettings(
      enabled: true,
      maxDailyDrawdownPercent: 3.0,
      maxConsecutiveLosses: 3,
      maxTradesPerSession: 10,
    );

    test('permits trade when within limits', () {
      final violation = DisciplineGuardrails.checkViolation(
        settings: settings,
        startingBalance: 10000,
        currentBalance: 9900,
        consecutiveLosses: 1,
        totalTrades: 5,
      );

      expect(violation, isNull);
    });

    test('detects max drawdown violation', () {
      final violation = DisciplineGuardrails.checkViolation(
        settings: settings,
        startingBalance: 10000,
        currentBalance: 9650, // 3.5% drawdown
        consecutiveLosses: 1,
        totalTrades: 4,
      );

      expect(violation, equals(GuardrailViolation.maxDrawdown));
    });

    test('detects consecutive losses violation', () {
      final violation = DisciplineGuardrails.checkViolation(
        settings: settings,
        startingBalance: 10000,
        currentBalance: 9900,
        consecutiveLosses: 3,
        totalTrades: 3,
      );

      expect(violation, equals(GuardrailViolation.consecutiveLosses));
    });

    test('detects max trades per session violation', () {
      final violation = DisciplineGuardrails.checkViolation(
        settings: settings,
        startingBalance: 10000,
        currentBalance: 10500,
        consecutiveLosses: 0,
        totalTrades: 10,
      );

      expect(violation, equals(GuardrailViolation.maxTrades));
    });
  });
}
