import 'package:flutter_test/flutter_test.dart';

import 'package:app/engine/smc_filter.dart';
import 'package:app/models/smc_type.dart';

void main() {
  group('SmcFilter Engine - Zone Merging & Decluttering', () {
    test('Merges overlapping Order Blocks of same directional bias', () {
      const now = 1000000;
      final zones = [
        const SmcStructure(
          id: 'ob_1',
          type: SmcType.orderBlock,
          timestamp: now,
          price: 100.0,
          secondaryPrice: 90.0,
          isBullish: true,
          title: 'Bullish Order Block',
          description: 'OB 1',
        ),
        const SmcStructure(
          id: 'ob_2',
          type: SmcType.orderBlock,
          timestamp: now + 60000,
          price: 95.0,
          secondaryPrice: 85.0,
          isBullish: true,
          title: 'Bullish Order Block',
          description: 'OB 2',
        ),
      ];

      final filtered = SmcFilter.filterAndMerge(
        structures: zones,
        candles: const [],
        settings: const SmcSettings(mergeOverlappingZones: true),
      );

      // 2 overlapping zones should merge into 1 zone with combined price range [100.0, 85.0]
      expect(filtered.length, equals(1));
      final merged = filtered.first;
      expect(merged.isMerged, isTrue);
      expect(merged.price, equals(100.0));
      expect(merged.secondaryPrice, equals(85.0));
    });

    test('Filters structures according to Minimal Visualization Mode', () {
      const now = 1000000;
      final structures = List.generate(
        10,
        (i) => SmcStructure(
          id: 'ob_$i',
          type: SmcType.orderBlock,
          timestamp: now + i * 60000,
          price: 100.0 + i,
          secondaryPrice: 90.0 + i,
          isBullish: true,
          title: 'Bullish OB',
          description: 'OB',
        ),
      );

      final minimalResult = SmcFilter.filterAndMerge(
        structures: structures,
        candles: const [],
        settings: const SmcSettings(
          visualizationMode: SmcVisualizationMode.minimal,
          mergeOverlappingZones: false,
        ),
      );

      // Minimal mode takes only 1 latest Order Block
      expect(minimalResult.length, equals(1));
      expect(minimalResult.first.id, equals('ob_9'));
    });

    test('Enforces Balanced mode limits (max 5 OBs)', () {
      const now = 1000000;
      final structures = List.generate(
        10,
        (i) => SmcStructure(
          id: 'ob_$i',
          type: SmcType.orderBlock,
          timestamp: now + i * 60000,
          price: 100.0 + i * 10, // Non-overlapping
          secondaryPrice: 95.0 + i * 10,
          isBullish: true,
          title: 'Bullish OB',
          description: 'OB',
        ),
      );

      final balancedResult = SmcFilter.filterAndMerge(
        structures: structures,
        candles: const [],
        settings: const SmcSettings(
          visualizationMode: SmcVisualizationMode.balanced,
          mergeOverlappingZones: false,
        ),
      );

      // Balanced mode caps bullish OBs to 5
      expect(balancedResult.length, equals(5));
    });
  });
}
