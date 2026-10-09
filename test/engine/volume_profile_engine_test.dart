import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/volume_profile_engine.dart';

void main() {
  group('VolumeProfileEngine tests', () {
    test('computes POC and Value Area from candle dataset', () {
      final candles = [
        CandleData(timestamp: 1000, open: 100, high: 105, low: 98, close: 104, volume: 500, isLive: false),
        CandleData(timestamp: 2000, open: 104, high: 108, low: 102, close: 106, volume: 1200, isLive: false),
        CandleData(timestamp: 3000, open: 106, high: 110, low: 103, close: 105, volume: 800, isLive: false),
      ];

      final profile = VolumeProfileEngine.compute(candles, bins: 20);

      expect(profile.rows, isNotEmpty);
      expect(profile.pocPrice, greaterThan(98));
      expect(profile.pocPrice, lessThan(110));
      expect(profile.valueAreaHigh, greaterThanOrEqualTo(profile.valueAreaLow));
      expect(profile.highestVolume, greaterThan(0));
    });

    test('returns empty result for empty candles list', () {
      final profile = VolumeProfileEngine.compute([], bins: 20);
      expect(profile.rows, isEmpty);
      expect(profile.pocPrice, equals(0));
    });
  });
}
