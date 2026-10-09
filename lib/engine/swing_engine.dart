/// Swing Point Detection Engine.
///
/// Pure Dart — deterministic pivot high / pivot low identification engine.
/// No UI, no state, no repainting after candle close.
library;

import 'package:app/domain/entities/candle_data.dart';

/// A confirmed market structure swing point (pivot high or pivot low).
class SwingPoint {
  final int index;
  final int timestamp;
  final double price;
  final bool isHigh;
  final bool isLow;

  const SwingPoint({
    required this.index,
    required this.timestamp,
    required this.price,
    required this.isHigh,
    required this.isLow,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SwingPoint &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          timestamp == other.timestamp &&
          price == other.price &&
          isHigh == other.isHigh &&
          isLow == other.isLow;

  @override
  int get hashCode =>
      index.hashCode ^
      timestamp.hashCode ^
      price.hashCode ^
      isHigh.hashCode ^
      isLow.hashCode;
}

class SwingEngine {
  SwingEngine._();

  /// Detect pivot high and pivot low swing points across the candle dataset.
  ///
  /// A candle at index `i` is a Pivot High if its high is strictly greater than
  /// all surrounding candles within `sensitivity` bars left and right.
  ///
  /// A candle at index `i` is a Pivot Low if its low is strictly lower than
  /// all surrounding candles within `sensitivity` bars left and right.
  static List<SwingPoint> detectSwings(
    List<CandleData> candles, {
    int sensitivity = 5,
  }) {
    final swings = <SwingPoint>[];
    final n = candles.length;
    final k = sensitivity.clamp(2, 15);

    if (n < k * 2 + 1) return swings;

    for (var i = k; i < n - k; i++) {
      final curr = candles[i];
      var isHigh = true;
      var isLow = true;

      for (var j = i - k; j <= i + k; j++) {
        if (j == i) continue;
        if (candles[j].high >= curr.high) isHigh = false;
        if (candles[j].low <= curr.low) isLow = false;
      }

      if (isHigh || isLow) {
        swings.add(SwingPoint(
          index: i,
          timestamp: curr.timestamp,
          price: isHigh ? curr.high : curr.low,
          isHigh: isHigh,
          isLow: isLow,
        ));
      }
    }
    return swings;
  }
}
