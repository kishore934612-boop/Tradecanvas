/// Volume Profile Engine — Fixed-Range Volume Profile (VPVR) computation.
///
/// Pure Dart. Distributes each candle's volume across price bins proportionally
/// within its high-low range, then identifies POC, Value Area, HVN, and LVN.
///
/// Since Binance klines only provide aggregate volume per candle (not tick-level
/// bid/ask), buy/sell volume is estimated: bullish candles contribute to buy
/// volume, bearish candles contribute to sell volume.
library;

import 'dart:math' as math;

import 'package:app/domain/entities/candle_data.dart';

/// A single row in the volume profile histogram.
class VolumeProfileRow {
  final double priceLevel;
  final double totalVolume;
  final double buyVolume;
  final double sellVolume;
  final bool isHVN; // High Volume Node
  final bool isLVN; // Low Volume Node

  const VolumeProfileRow({
    required this.priceLevel,
    required this.totalVolume,
    required this.buyVolume,
    required this.sellVolume,
    this.isHVN = false,
    this.isLVN = false,
  });

  VolumeProfileRow copyWith({bool? isHVN, bool? isLVN}) {
    return VolumeProfileRow(
      priceLevel: priceLevel,
      totalVolume: totalVolume,
      buyVolume: buyVolume,
      sellVolume: sellVolume,
      isHVN: isHVN ?? this.isHVN,
      isLVN: isLVN ?? this.isLVN,
    );
  }
}

/// Complete volume profile analysis result.
class VolumeProfileResult {
  /// Histogram rows, sorted from lowest to highest price.
  final List<VolumeProfileRow> rows;

  /// Price level with the highest volume (Point of Control).
  final double pocPrice;

  /// Value Area High — upper bound of the 70% volume zone.
  final double valueAreaHigh;

  /// Value Area Low — lower bound of the 70% volume zone.
  final double valueAreaLow;

  /// Maximum volume in any single row (for normalization).
  final double highestVolume;

  /// Total volume across all rows.
  final double totalVolume;

  const VolumeProfileResult({
    required this.rows,
    required this.pocPrice,
    required this.valueAreaHigh,
    required this.valueAreaLow,
    required this.highestVolume,
    required this.totalVolume,
  });

  static const VolumeProfileResult empty = VolumeProfileResult(
    rows: [],
    pocPrice: 0,
    valueAreaHigh: 0,
    valueAreaLow: 0,
    highestVolume: 0,
    totalVolume: 0,
  );
}

class VolumeProfileEngine {
  VolumeProfileEngine._();

  /// Compute Fixed-Range Volume Profile over a candle dataset.
  ///
  /// [bins] — number of price levels to divide the range into (default 50).
  /// [valueAreaPercent] — percentage of total volume defining the Value Area
  ///   (default 0.70 = 70%).
  static VolumeProfileResult compute(
    List<CandleData> candles, {
    int bins = 50,
    double valueAreaPercent = 0.70,
  }) {
    if (candles.isEmpty || bins <= 0) return VolumeProfileResult.empty;

    // Find overall price range.
    var globalHigh = candles.first.high;
    var globalLow = candles.first.low;
    for (final c in candles) {
      globalHigh = math.max(globalHigh, c.high);
      globalLow = math.min(globalLow, c.low);
    }

    if (globalHigh <= globalLow) return VolumeProfileResult.empty;

    final binSize = (globalHigh - globalLow) / bins;
    if (binSize <= 0) return VolumeProfileResult.empty;

    // Accumulate volume into bins.
    final buyVolumes = List<double>.filled(bins, 0);
    final sellVolumes = List<double>.filled(bins, 0);

    for (final c in candles) {
      if (c.volume <= 0 || c.high <= c.low) continue;

      // Determine which bins this candle spans.
      final candleRange = c.high - c.low;
      final binStart = ((c.low - globalLow) / binSize).floor().clamp(0, bins - 1);
      final binEnd = ((c.high - globalLow) / binSize).floor().clamp(0, bins - 1);

      // Distribute volume proportionally across spanned bins.
      for (int b = binStart; b <= binEnd; b++) {
        final binBottom = globalLow + b * binSize;
        final binTop = binBottom + binSize;

        // Overlap between candle range and bin range.
        final overlapBottom = math.max(c.low, binBottom);
        final overlapTop = math.min(c.high, binTop);
        final overlap = math.max(0.0, overlapTop - overlapBottom);
        final fraction = candleRange > 0 ? overlap / candleRange : 0.0;
        final volumeContribution = c.volume * fraction;

        if (c.isBullish) {
          buyVolumes[b] += volumeContribution;
        } else {
          sellVolumes[b] += volumeContribution;
        }
      }
    }

    // Build rows and find POC.
    var highestVolume = 0.0;
    var totalVolume = 0.0;
    int pocIndex = 0;

    final totalVolumes = <double>[];
    for (int i = 0; i < bins; i++) {
      final total = buyVolumes[i] + sellVolumes[i];
      totalVolumes.add(total);
      totalVolume += total;
      if (total > highestVolume) {
        highestVolume = total;
        pocIndex = i;
      }
    }

    // Compute mean and stddev for HVN/LVN detection.
    final mean = totalVolume / bins;
    double sumSqDiff = 0;
    for (final v in totalVolumes) {
      sumSqDiff += (v - mean) * (v - mean);
    }
    final stdDev = math.sqrt(sumSqDiff / bins);
    final hvnThreshold = mean + stdDev * 0.5;
    final lvnThreshold = mean - stdDev * 0.5;

    // Build rows with HVN/LVN flags.
    final rows = <VolumeProfileRow>[];
    for (int i = 0; i < bins; i++) {
      final priceLevel = globalLow + (i + 0.5) * binSize;
      rows.add(VolumeProfileRow(
        priceLevel: priceLevel,
        totalVolume: totalVolumes[i],
        buyVolume: buyVolumes[i],
        sellVolume: sellVolumes[i],
        isHVN: totalVolumes[i] >= hvnThreshold,
        isLVN: totalVolumes[i] > 0 && totalVolumes[i] <= lvnThreshold,
      ));
    }

    // Value Area calculation — expand from POC up and down, collecting
    // 70% of total volume.
    final vaTarget = totalVolume * valueAreaPercent;
    var vaVolume = totalVolumes[pocIndex];
    int vaLow = pocIndex;
    int vaHigh = pocIndex;

    while (vaVolume < vaTarget && (vaLow > 0 || vaHigh < bins - 1)) {
      final addAbove =
          vaHigh < bins - 1 ? totalVolumes[vaHigh + 1] : 0.0;
      final addBelow = vaLow > 0 ? totalVolumes[vaLow - 1] : 0.0;

      if (addAbove >= addBelow && vaHigh < bins - 1) {
        vaHigh++;
        vaVolume += totalVolumes[vaHigh];
      } else if (vaLow > 0) {
        vaLow--;
        vaVolume += totalVolumes[vaLow];
      } else {
        vaHigh++;
        vaVolume += totalVolumes[vaHigh];
      }
    }

    final pocPrice = globalLow + (pocIndex + 0.5) * binSize;
    final valueAreaLow = globalLow + vaLow * binSize;
    final valueAreaHigh = globalLow + (vaHigh + 1) * binSize;

    return VolumeProfileResult(
      rows: rows,
      pocPrice: pocPrice,
      valueAreaHigh: valueAreaHigh,
      valueAreaLow: valueAreaLow,
      highestVolume: highestVolume,
      totalVolume: totalVolume,
    );
  }
}
