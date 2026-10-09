/// Smart Money Concepts (SMC) Market Structure Analysis Engine.
///
/// Pure Dart — deterministic, rule-based detection of market structure overlays.
/// Zero AI, zero heuristics, zero repainting after candle close.
library;

import 'dart:math' as math;
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/swing_engine.dart';
import 'package:app/models/smc_type.dart';

class SmcEngine {
  SmcEngine._();

  /// Evaluate market structure overlays on the provided candle dataset.
  static List<SmcStructure> evaluate({
    required List<CandleData> candles,
    required Set<SmcType> activeOverlays,
    required SmcSettings settings,
  }) {
    if (candles.length < 10 || activeOverlays.isEmpty) return const [];

    final structures = <SmcStructure>[];

    // Compute swing points via SwingEngine
    final swings = SwingEngine.detectSwings(
      candles,
      sensitivity: settings.swingSensitivity,
    );

    // 1. Breakout Detection
    if (activeOverlays.contains(SmcType.breakout)) {
      structures.addAll(_detectBreakouts(candles, settings));
    }

    // 2. Fair Value Gap (FVG) Detection
    if (activeOverlays.contains(SmcType.fvg)) {
      structures.addAll(_detectFvgs(candles, settings));
    }

    // 3. Order Blocks (OB) Detection
    if (activeOverlays.contains(SmcType.orderBlock)) {
      structures.addAll(_detectOrderBlocks(candles, settings));
    }

    // 4. Liquidity Sweeps Detection
    if (activeOverlays.contains(SmcType.liquiditySweep)) {
      structures.addAll(_detectLiquiditySweeps(candles, swings, settings));
    }

    // 5. Break of Structure (BOS) & 6. Change of Character (CHoCH)
    if (activeOverlays.contains(SmcType.bos) || activeOverlays.contains(SmcType.choch)) {
      structures.addAll(_detectBosAndChoch(candles, swings, activeOverlays, settings));
    }

    // 7. Equal Highs / Equal Lows (EQH/EQL)
    if (activeOverlays.contains(SmcType.equalLevel)) {
      structures.addAll(_detectEqualLevels(swings, settings));
    }

    // Apply maxVisibleStructures limit (keep latest)
    if (structures.length > settings.maxVisibleStructures) {
      return structures.sublist(structures.length - settings.maxVisibleStructures);
    }

    return structures;
  }

  // ==========================================================
  // 1. BREAKOUT DETECTION
  // ==========================================================

  static List<SmcStructure> _detectBreakouts(
    List<CandleData> candles,
    SmcSettings settings,
  ) {
    final result = <SmcStructure>[];
    final n = candles.length;
    const minHistory = 10;

    for (var i = minHistory; i < n; i++) {
      final curr = candles[i];
      final bodyPct = curr.range > 0 ? (curr.body / curr.range) : 0.0;
      if (bodyPct < 0.45) continue; // Require strong body

      // Look for resistance/support levels in previous lookback bars
      final lookback = math.min(i, settings.lookbackBars);
      var maxHigh = -double.infinity;
      var minLow = double.infinity;
      for (var j = i - lookback; j < i; j++) {
        if (candles[j].high > maxHigh) maxHigh = candles[j].high;
        if (candles[j].low < minLow) minLow = candles[j].low;
      }

      // Bullish Breakout close above resistance
      if (curr.close > maxHigh * (1 + settings.minBreakoutPct)) {
        result.add(SmcStructure(
          id: 'bo_bull_${curr.timestamp}',
          type: SmcType.breakout,
          timestamp: curr.timestamp,
          price: maxHigh,
          secondaryPrice: curr.close,
          isBullish: true,
          title: 'Breakout Bullish',
          description:
              'Price closed decisively above recent consolidation resistance (${maxHigh.toStringAsFixed(2)}) with a strong bullish body.',
        ));
      }
      // Bearish Breakout close below support
      else if (curr.close < minLow * (1 - settings.minBreakoutPct)) {
        result.add(SmcStructure(
          id: 'bo_bear_${curr.timestamp}',
          type: SmcType.breakout,
          timestamp: curr.timestamp,
          price: minLow,
          secondaryPrice: curr.close,
          isBullish: false,
          title: 'Breakout Bearish',
          description:
              'Price closed decisively below recent consolidation support (${minLow.toStringAsFixed(2)}) with a strong bearish body.',
        ));
      }
    }
    return result;
  }

  // ==========================================================
  // 2. FAIR VALUE GAP (FVG) DETECTION & MITIGATION
  // ==========================================================

  static List<SmcStructure> _detectFvgs(
    List<CandleData> candles,
    SmcSettings settings,
  ) {
    final fvgs = <SmcStructure>[];
    final n = candles.length;

    for (var i = 2; i < n; i++) {
      final c1 = candles[i - 2];
      final c3 = candles[i];

      // Bullish FVG: C1 High < C3 Low
      if (c3.low > c1.high) {
        final gapSize = c3.low - c1.high;
        if (gapSize / c1.high >= 0.0008) {
          var isMitigated = false;
          int? mitigatedTime;

          // Check mitigation by subsequent candles entering the gap zone
          for (var j = i + 1; j < n; j++) {
            if (candles[j].low <= c3.low) {
              isMitigated = true;
              mitigatedTime = candles[j].timestamp;
              break;
            }
          }

          if (!settings.hideMitigatedFvg || !isMitigated) {
            fvgs.add(SmcStructure(
              id: 'fvg_bull_${c3.timestamp}',
              type: SmcType.fvg,
              timestamp: c1.timestamp,
              endTimestamp: c3.timestamp,
              price: c3.low, // Top of gap
              secondaryPrice: c1.high, // Bottom of gap
              isBullish: true,
              title: 'Bullish Fair Value Gap',
              description:
                  '3-candle price imbalance between ${c1.high.toStringAsFixed(2)} and ${c3.low.toStringAsFixed(2)}. ${isMitigated ? "Mitigated." : "Unmitigated open gap."}',
              isMitigated: isMitigated,
              mitigatedTimestamp: mitigatedTime,
            ));
          }
        }
      }
      // Bearish FVG: C1 Low > C3 High
      else if (c1.low > c3.high) {
        final gapSize = c1.low - c3.high;
        if (gapSize / c3.high >= 0.0008) {
          var isMitigated = false;
          int? mitigatedTime;

          // Check mitigation by subsequent candles entering the gap zone
          for (var j = i + 1; j < n; j++) {
            if (candles[j].high >= c3.high) {
              isMitigated = true;
              mitigatedTime = candles[j].timestamp;
              break;
            }
          }

          if (!settings.hideMitigatedFvg || !isMitigated) {
            fvgs.add(SmcStructure(
              id: 'fvg_bear_${c3.timestamp}',
              type: SmcType.fvg,
              timestamp: c1.timestamp,
              endTimestamp: c3.timestamp,
              price: c1.low, // Top of gap
              secondaryPrice: c3.high, // Bottom of gap
              isBullish: false,
              title: 'Bearish Fair Value Gap',
              description:
                  '3-candle price imbalance between ${c3.high.toStringAsFixed(2)} and ${c1.low.toStringAsFixed(2)}. ${isMitigated ? "Mitigated." : "Unmitigated open gap."}',
              isMitigated: isMitigated,
              mitigatedTimestamp: mitigatedTime,
            ));
          }
        }
      }
    }
    return fvgs;
  }

  // ==========================================================
  // 3. ORDER BLOCKS (OB) DETECTION & MITIGATION
  // ==========================================================

  static List<SmcStructure> _detectOrderBlocks(
    List<CandleData> candles,
    SmcSettings settings,
  ) {
    final obs = <SmcStructure>[];
    final n = candles.length;

    // Pre-compute average range for displacement strength filter
    double totalRange = 0;
    int rangeCount = 0;
    for (var k = 1; k < n; k++) {
      totalRange += candles[k].range;
      rangeCount++;
    }
    final avgRange = rangeCount > 0 ? totalRange / rangeCount : 0.0;

    for (var i = 1; i < n - 1; i++) {
      final prev = candles[i - 1];
      final curr = candles[i];

      // Displacement strength filter: require displacement candle range > 1.5x average
      if (avgRange > 0 && curr.range < avgRange * 1.5) continue;

      // Also require strong body (> 50% of range)
      if (curr.range <= 0 || curr.body / curr.range < 0.5) continue;

      // Bullish OB: prev candle is bearish, current candle shows strong bullish displacement
      if (prev.isBearish && curr.isBullish && curr.close > prev.high) {
        var isMitigated = false;
        int? mitigatedTime;

        for (var j = i + 1; j < n; j++) {
          if (candles[j].low <= prev.low) {
            isMitigated = true;
            mitigatedTime = candles[j].timestamp;
            break;
          }
        }

        if (!settings.hideMitigatedOb || !isMitigated) {
          obs.add(SmcStructure(
            id: 'ob_bull_${prev.timestamp}',
            type: SmcType.orderBlock,
            timestamp: prev.timestamp,
            price: prev.high,
            secondaryPrice: prev.low,
            isBullish: true,
            title: 'Bullish Order Block',
            description:
                'Institutional buying zone formed at ${prev.low.toStringAsFixed(2)} - ${prev.high.toStringAsFixed(2)} preceding bullish displacement.',
            isMitigated: isMitigated,
            mitigatedTimestamp: mitigatedTime,
          ));
        }
      }
      // Bearish OB: prev candle is bullish, current candle shows strong bearish displacement
      else if (prev.isBullish && curr.isBearish && curr.close < prev.low) {
        var isMitigated = false;
        int? mitigatedTime;

        for (var j = i + 1; j < n; j++) {
          if (candles[j].high >= prev.high) {
            isMitigated = true;
            mitigatedTime = candles[j].timestamp;
            break;
          }
        }

        if (!settings.hideMitigatedOb || !isMitigated) {
          obs.add(SmcStructure(
            id: 'ob_bear_${prev.timestamp}',
            type: SmcType.orderBlock,
            timestamp: prev.timestamp,
            price: prev.high,
            secondaryPrice: prev.low,
            isBullish: false,
            title: 'Bearish Order Block',
            description:
                'Institutional selling zone formed at ${prev.low.toStringAsFixed(2)} - ${prev.high.toStringAsFixed(2)} preceding bearish displacement.',
            isMitigated: isMitigated,
            mitigatedTimestamp: mitigatedTime,
          ));
        }
      }
    }
    return obs;
  }

  // ==========================================================
  // 4. LIQUIDITY SWEEPS DETECTION
  // ==========================================================

  static List<SmcStructure> _detectLiquiditySweeps(
    List<CandleData> candles,
    List<SwingPoint> swings,
    SmcSettings settings,
  ) {
    final sweeps = <SmcStructure>[];

    for (final s in swings) {
      for (var i = s.index + 1; i < candles.length; i++) {
        final c = candles[i];

        // Bearish Sweep: price wicks above swing high but closes back below it
        if (s.isHigh && c.high > s.price && c.close <= s.price) {
          sweeps.add(SmcStructure(
            id: 'sweep_bear_${c.timestamp}',
            type: SmcType.liquiditySweep,
            timestamp: c.timestamp,
            price: s.price,
            secondaryPrice: c.high,
            isBullish: false,
            title: 'Bearish Liquidity Sweep',
            description:
                'Price breached previous swing high liquidity at ${s.price.toStringAsFixed(2)} with a wick and closed back inside.',
          ));
          break; // Avoid repeated sweeps on same level
        }
        // Bullish Sweep: price wicks below swing low but closes back above it
        else if (s.isLow && c.low < s.price && c.close >= s.price) {
          sweeps.add(SmcStructure(
            id: 'sweep_bull_${c.timestamp}',
            type: SmcType.liquiditySweep,
            timestamp: c.timestamp,
            price: s.price,
            secondaryPrice: c.low,
            isBullish: true,
            title: 'Bullish Liquidity Sweep',
            description:
                'Price breached previous swing low liquidity at ${s.price.toStringAsFixed(2)} with a wick and closed back inside.',
          ));
          break; // Avoid repeated sweeps on same level
        }
      }
    }
    return sweeps;
  }

  // ==========================================================
  // 5. BOS & 6. CHoCH DETECTION
  // ==========================================================

  static List<SmcStructure> _detectBosAndChoch(
    List<CandleData> candles,
    List<SwingPoint> swings,
    Set<SmcType> activeOverlays,
    SmcSettings settings,
  ) {
    final result = <SmcStructure>[];
    if (swings.isEmpty) return result;

    var currentTrend = 0; // 1 = uptrend, -1 = downtrend

    for (final s in swings) {
      for (var j = s.index + 1; j < candles.length; j++) {
        final c = candles[j];

        // Candle closes above previous swing high
        if (s.isHigh && c.close > s.price) {
          if (currentTrend == -1) {
            // Trend reversal -> CHoCH
            if (activeOverlays.contains(SmcType.choch)) {
              result.add(SmcStructure(
                id: 'choch_bull_${c.timestamp}',
                type: SmcType.choch,
                timestamp: c.timestamp,
                endTimestamp: s.timestamp,
                price: s.price,
                isBullish: true,
                title: 'Bullish CHoCH',
                description:
                    'Market structure change: candle closed above previous lower high (${s.price.toStringAsFixed(2)}), signaling early trend reversal.',
              ));
            }
            currentTrend = 1;
          } else {
            // Continuation -> BOS
            if (activeOverlays.contains(SmcType.bos)) {
              result.add(SmcStructure(
                id: 'bos_bull_${c.timestamp}',
                type: SmcType.bos,
                timestamp: c.timestamp,
                endTimestamp: s.timestamp,
                price: s.price,
                isBullish: true,
                title: 'Bullish BOS',
                description:
                    'Break of Structure: candle closed above previous swing high (${s.price.toStringAsFixed(2)}), confirming uptrend continuation.',
              ));
            }
            currentTrend = 1;
          }
          break;
        }
        // Candle closes below previous swing low
        else if (s.isLow && c.close < s.price) {
          if (currentTrend == 1) {
            // Trend reversal -> CHoCH
            if (activeOverlays.contains(SmcType.choch)) {
              result.add(SmcStructure(
                id: 'choch_bear_${c.timestamp}',
                type: SmcType.choch,
                timestamp: c.timestamp,
                endTimestamp: s.timestamp,
                price: s.price,
                isBullish: false,
                title: 'Bearish CHoCH',
                description:
                    'Market structure change: candle closed below previous higher low (${s.price.toStringAsFixed(2)}), signaling early trend reversal.',
              ));
            }
            currentTrend = -1;
          } else {
            // Continuation -> BOS
            if (activeOverlays.contains(SmcType.bos)) {
              result.add(SmcStructure(
                id: 'bos_bear_${c.timestamp}',
                type: SmcType.bos,
                timestamp: c.timestamp,
                endTimestamp: s.timestamp,
                price: s.price,
                isBullish: false,
                title: 'Bearish BOS',
                description:
                    'Break of Structure: candle closed below previous swing low (${s.price.toStringAsFixed(2)}), confirming downtrend continuation.',
              ));
            }
            currentTrend = -1;
          }
          break;
        }
      }
    }

    return result;
  }

  // ==========================================================
  // 7. EQUAL HIGHS / EQUAL LOWS (EQH/EQL) DETECTION
  // ==========================================================

  static List<SmcStructure> _detectEqualLevels(
    List<SwingPoint> swings,
    SmcSettings settings,
  ) {
    final result = <SmcStructure>[];

    // Compare swing highs with each other and swing lows with each other
    final highs = swings.where((s) => s.isHigh).toList();
    final lows = swings.where((s) => s.isLow).toList();

    // Detect Equal Highs
    for (var i = 0; i < highs.length; i++) {
      for (var j = i + 1; j < highs.length; j++) {
        final a = highs[i];
        final b = highs[j];
        final tolerance = a.price * 0.001; // 0.1% tolerance

        if ((a.price - b.price).abs() <= tolerance) {
          result.add(SmcStructure(
            id: 'eqh_${a.timestamp}_${b.timestamp}',
            type: SmcType.equalLevel,
            timestamp: a.timestamp,
            endTimestamp: b.timestamp,
            price: a.price,
            secondaryPrice: b.price,
            isBullish: false, // EQH is sell-side liquidity
            title: 'Equal Highs (EQH)',
            description:
                'Two swing highs formed at approximately the same level (${a.price.toStringAsFixed(2)}), creating a sell-side liquidity pool.',
          ));
          break; // avoid duplicate clusters
        }
      }
    }

    // Detect Equal Lows
    for (var i = 0; i < lows.length; i++) {
      for (var j = i + 1; j < lows.length; j++) {
        final a = lows[i];
        final b = lows[j];
        final tolerance = a.price * 0.001; // 0.1% tolerance

        if ((a.price - b.price).abs() <= tolerance) {
          result.add(SmcStructure(
            id: 'eql_${a.timestamp}_${b.timestamp}',
            type: SmcType.equalLevel,
            timestamp: a.timestamp,
            endTimestamp: b.timestamp,
            price: a.price,
            secondaryPrice: b.price,
            isBullish: true, // EQL is buy-side liquidity
            title: 'Equal Lows (EQL)',
            description:
                'Two swing lows formed at approximately the same level (${a.price.toStringAsFixed(2)}), creating a buy-side liquidity pool.',
          ));
          break; // avoid duplicate clusters
        }
      }
    }

    return result;
  }

  // ==========================================================
  // MULTI-TIMEFRAME TREND EVALUATION
  // ==========================================================

  /// Evaluate overall market trend direction from BOS/CHoCH analysis.
  ///
  /// Returns an [SmcTrend] summary including trend direction, nearest
  /// structures, and liquidity targets. Used by the MTF SMC dashboard HUD.
  static SmcTrend evaluateTrend({
    required List<CandleData> candles,
    required SmcSettings settings,
  }) {
    if (candles.length < 20) return SmcTrend.empty;

    final swings = SwingEngine.detectSwings(
      candles,
      sensitivity: settings.swingSensitivity,
    );

    if (swings.isEmpty) return SmcTrend.empty;

    // Compute all structures for analysis.
    final allOverlays = {
      SmcType.bos,
      SmcType.choch,
      SmcType.fvg,
      SmcType.orderBlock,
      SmcType.liquiditySweep,
      SmcType.equalLevel,
    };
    final structures = evaluate(
      candles: candles,
      activeOverlays: allOverlays,
      settings: settings,
    );

    // Find last BOS and CHoCH.
    SmcStructure? lastBos;
    SmcStructure? lastChoch;
    for (final s in structures.reversed) {
      if (s.type == SmcType.bos && lastBos == null) lastBos = s;
      if (s.type == SmcType.choch && lastChoch == null) lastChoch = s;
      if (lastBos != null && lastChoch != null) break;
    }

    // Determine trend direction.
    SmcTrendDirection direction = SmcTrendDirection.ranging;
    if (lastChoch != null && lastBos != null) {
      // If CHoCH is more recent than BOS, we're in a reversal.
      if (lastChoch.timestamp > lastBos.timestamp) {
        direction = lastChoch.isBullish
            ? SmcTrendDirection.bullish
            : SmcTrendDirection.bearish;
      } else {
        // BOS is more recent — trend continuation.
        direction = lastBos.isBullish
            ? SmcTrendDirection.bullish
            : SmcTrendDirection.bearish;
      }
    } else if (lastBos != null) {
      direction = lastBos.isBullish
          ? SmcTrendDirection.bullish
          : SmcTrendDirection.bearish;
    } else if (lastChoch != null) {
      direction = lastChoch.isBullish
          ? SmcTrendDirection.bullish
          : SmcTrendDirection.bearish;
    }

    // Find nearest unmitigated FVG to current price.
    final currentPrice = candles.last.close;
    SmcStructure? nearestFvg;
    double nearestFvgDist = double.infinity;
    for (final s in structures) {
      if (s.type == SmcType.fvg && !s.isMitigated) {
        final mid = (s.price + s.secondaryPrice) / 2.0;
        final dist = (mid - currentPrice).abs();
        if (dist < nearestFvgDist) {
          nearestFvgDist = dist;
          nearestFvg = s;
        }
      }
    }

    // Find nearest unmitigated Order Block.
    SmcStructure? nearestOb;
    double nearestObDist = double.infinity;
    for (final s in structures) {
      if (s.type == SmcType.orderBlock && !s.isMitigated) {
        final mid = (s.price + s.secondaryPrice) / 2.0;
        final dist = (mid - currentPrice).abs();
        if (dist < nearestObDist) {
          nearestObDist = dist;
          nearestOb = s;
        }
      }
    }

    // Liquidity targets: nearest swing high above and swing low below price.
    double? buyLiquidityTarget;
    double? sellLiquidityTarget;
    for (final sp in swings) {
      if (sp.isHigh && sp.price > currentPrice) {
        if (buyLiquidityTarget == null || sp.price < buyLiquidityTarget) {
          buyLiquidityTarget = sp.price;
        }
      }
      if (sp.isLow && sp.price < currentPrice) {
        if (sellLiquidityTarget == null || sp.price > sellLiquidityTarget) {
          sellLiquidityTarget = sp.price;
        }
      }
    }

    return SmcTrend(
      direction: direction,
      lastBos: lastBos,
      lastChoch: lastChoch,
      nearestFvg: nearestFvg,
      nearestOb: nearestOb,
      buyLiquidityTarget: buyLiquidityTarget,
      sellLiquidityTarget: sellLiquidityTarget,
    );
  }
}
