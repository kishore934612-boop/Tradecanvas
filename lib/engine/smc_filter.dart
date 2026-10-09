/// Smart Money Concepts Structure Filter & Zone Merging Engine.
///
/// Pure Dart — TradingView-grade structure filtering, zone merging, and decluttering.
library;

import 'dart:math' as math;

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/models/smc_type.dart';

class SmcFilter {
  SmcFilter._();

  /// Process raw detected SMC structures through TradingView-quality filters & zone merging.
  static List<SmcStructure> filterAndMerge({
    required List<SmcStructure> structures,
    required List<CandleData> candles,
    required SmcSettings settings,
  }) {
    if (structures.isEmpty) return const [];

    final lastCandleTime = candles.isNotEmpty ? candles.last.timestamp : 0;
    final lastPrice = candles.isNotEmpty ? candles.last.close : 0.0;

    // 1. Separate structures by type
    var breakouts = structures.where((s) => s.type == SmcType.breakout).toList();
    var fvgs = structures.where((s) => s.type == SmcType.fvg).toList();
    var obs = structures.where((s) => s.type == SmcType.orderBlock).toList();
    var sweeps = structures.where((s) => s.type == SmcType.liquiditySweep).toList();
    var bosList = structures.where((s) => s.type == SmcType.bos).toList();
    var chochList = structures.where((s) => s.type == SmcType.choch).toList();
    var equalLevels = structures.where((s) => s.type == SmcType.equalLevel).toList();

    // 2. Zone Merging for OB and FVG if enabled
    if (settings.mergeOverlappingZones) {
      obs = _mergeOverlappingZones(obs);
      fvgs = _mergeOverlappingZones(fvgs);
    }

    // 3. Mode-specific quota filtering
    final mode = settings.visualizationMode;

    if (mode == SmcVisualizationMode.minimal) {
      breakouts = _takeLatest(breakouts, 1);
      fvgs = _takeLatest(fvgs, 1);
      obs = _takeLatest(obs, 1);
      sweeps = _takeLatest(sweeps, 1);
      bosList = _takeLatest(bosList, 1);
      chochList = _takeLatest(chochList, 1);
      equalLevels = _takeLatest(equalLevels, 1);
    } else if (mode == SmcVisualizationMode.balanced) {
      // Breakout: Max 3 Bullish, 3 Bearish; Expire older than 100 candles (100 * 60,000 ms)
      const expirationMs = 100 * 60000;
      breakouts = breakouts
          .where((s) => lastCandleTime == 0 || (lastCandleTime - s.timestamp) <= expirationMs)
          .toList();

      final bullBreakouts = _takeLatest(breakouts.where((s) => s.isBullish).toList(), 3);
      final bearBreakouts = _takeLatest(breakouts.where((s) => !s.isBullish).toList(), 3);
      breakouts = [...bullBreakouts, ...bearBreakouts];

      // Order Blocks: Max 5 Bullish, 5 Bearish
      final bullObs = _takeLatest(obs.where((s) => s.isBullish).toList(), 5);
      final bearObs = _takeLatest(obs.where((s) => !s.isBullish).toList(), 5);
      obs = [...bullObs, ...bearObs];

      // Fair Value Gaps: Max 5 active (filter out tiny gaps < 0.25%)
      fvgs = fvgs.where((s) {
        final top = math.max(s.price, s.secondaryPrice);
        final bottom = math.min(s.price, s.secondaryPrice);
        final gapPct = top > 0 ? (top - bottom) / top : 0.0;
        return gapPct >= 0.0025;
      }).toList();
      fvgs = _takeLatest(fvgs, 5);

      // Liquidity Sweeps: Max 3 High, 3 Low sweeps. Remove if price moves > 3 ATR away or > 100 candles
      sweeps = sweeps.where((s) {
        final ageMs = lastCandleTime > 0 ? (lastCandleTime - s.timestamp) : 0;
        final dist = (lastPrice - s.price).abs();
        final distPct = s.price > 0 ? dist / s.price : 0.0;
        return ageMs <= (100 * 60000) && distPct <= 0.05;
      }).toList();

      final highSweeps = _takeLatest(sweeps.where((s) => !s.isBullish).toList(), 3);
      final lowSweeps = _takeLatest(sweeps.where((s) => s.isBullish).toList(), 3);
      sweeps = [...highSweeps, ...lowSweeps];

      bosList = _takeLatest(bosList, 4);
      chochList = _takeLatest(chochList, 4);
      equalLevels = _takeLatest(equalLevels, 3);
    }

    final combined = [
      ...obs,
      ...fvgs,
      ...sweeps,
      ...breakouts,
      ...bosList,
      ...chochList,
      ...equalLevels,
    ];

    // Sort by timestamp
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (combined.length > settings.maxVisibleStructures) {
      return combined.sublist(combined.length - settings.maxVisibleStructures);
    }

    return combined;
  }

  static List<SmcStructure> _takeLatest(List<SmcStructure> list, int count) {
    if (list.length <= count) return list;
    return list.sublist(list.length - count);
  }

  /// Merge overlapping rectangular zones (Order Blocks or FVGs) of the same directional bias.
  static List<SmcStructure> _mergeOverlappingZones(List<SmcStructure> zones) {
    if (zones.length <= 1) return zones;

    final merged = <SmcStructure>[];
    final visited = List<bool>.filled(zones.length, false);

    for (var i = 0; i < zones.length; i++) {
      if (visited[i]) continue;
      visited[i] = true;

      var base = zones[i];
      var baseTop = math.max(base.price, base.secondaryPrice);
      var baseBottom = math.min(base.price, base.secondaryPrice);

      for (var j = i + 1; j < zones.length; j++) {
        if (visited[j]) continue;
        final other = zones[j];

        // Must match direction (bullish/bearish)
        if (base.isBullish != other.isBullish) continue;

        final otherTop = math.max(other.price, other.secondaryPrice);
        final otherBottom = math.min(other.price, other.secondaryPrice);

        // Check vertical overlap
        final overlaps = !(baseBottom > otherTop || baseTop < otherBottom);
        if (overlaps) {
          visited[j] = true;
          // Combine price bounds
          baseTop = math.max(baseTop, otherTop);
          baseBottom = math.min(baseBottom, otherBottom);
          base = base.copyWith(isMerged: true);
        }
      }

      merged.add(SmcStructure(
        id: base.id,
        type: base.type,
        timestamp: base.timestamp,
        endTimestamp: base.endTimestamp,
        price: baseTop,
        secondaryPrice: baseBottom,
        isBullish: base.isBullish,
        title: base.isMerged ? 'Merged ${base.title}' : base.title,
        description: base.description,
        isMitigated: base.isMitigated,
        mitigatedTimestamp: base.mitigatedTimestamp,
        isMerged: base.isMerged,
      ));
    }
    return merged;
  }
}
