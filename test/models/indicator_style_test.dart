import 'package:flutter_test/flutter_test.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/indicator_style.dart';

void main() {
  group('IndicatorStyle Tests', () {
    test('defaultStyle returns default color and thickness for indicator type', () {
      final style = IndicatorStyle.defaultStyle(IndicatorType.ema);
      expect(style.colorValue, equals(IndicatorType.ema.colorValue));
      expect(style.strokeWidth, equals(1.8));
    });

    test('copyWith creates modified clone', () {
      final style = IndicatorStyle.defaultStyle(IndicatorType.rsi);
      final modified = style.copyWith(colorValue: 0xFFEF4444, strokeWidth: 3.5);

      expect(modified.colorValue, equals(0xFFEF4444));
      expect(modified.strokeWidth, equals(3.5));
    });

    test('json serialization round-trips correctly', () {
      const style = IndicatorStyle(colorValue: 0xFF38BDF8, strokeWidth: 2.5);
      final json = style.toJson();
      final restored = IndicatorStyle.fromJson(json, IndicatorType.sma);

      expect(restored.colorValue, equals(0xFF38BDF8));
      expect(restored.strokeWidth, equals(2.5));
    });
  });
}
