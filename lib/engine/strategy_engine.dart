/// Strategy Engine — detects educational chart strategy signals.
///
/// Pure Dart calculations over candle lists and indicator series.
library;

import 'dart:math' as math;
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/strategy_type.dart';

class StrategyEngine {
  StrategyEngine._();

  /// Evaluate all active strategies on the given candle dataset and return detected signals.
  static List<StrategySignal> evaluate({
    required List<CandleData> candles,
    required Set<StrategyType> activeStrategies,
    required StrategySettings settings,
    ChartIndicators? indicators,
  }) {
    if (!settings.isValid || settings.maxVisibleSignals == 0 ||
        candles.length < 5 || activeStrategies.isEmpty) return const [];
    // Never compute confirmed signals from the forming bar or later data.
    final forming = candles.indexWhere((c) => c.isLive);
    if (forming >= 0) candles = candles.sublist(0, forming);
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      if (![c.open, c.high, c.low, c.close, c.volume].every((v) => v.isFinite) ||
          c.low <= 0 || c.volume < 0 || c.high < math.max(c.open, c.close) ||
          c.low > math.min(c.open, c.close) ||
          (i > 0 && c.timestamp <= candles[i - 1].timestamp)) return const [];
    }

    final signals = <StrategySignal>[];
    final lastSignalBar = <(StrategyType, bool), int>{};

    // Compute or re-use EMA indicators if needed
    List<double?>? fastEmaSeries;
    List<double?>? slowEmaSeries;
    if (activeStrategies.contains(StrategyType.emaCrossover)) {
      fastEmaSeries = CandleEngine.computeEma(candles, settings.emaFastPeriod);
      slowEmaSeries = CandleEngine.computeEma(candles, settings.emaSlowPeriod);
    }

    // Compute or re-use Bollinger Bands if needed
    ({List<double?> upper, List<double?> middle, List<double?> lower})? bbResult;
    if (activeStrategies.contains(StrategyType.bollingerReversal)) {
      bbResult = CandleEngine.computeBollingerBands(candles);
    }

    // Compute or re-use RSI if needed
    List<double?>? rsiSeries;
    if (activeStrategies.contains(StrategyType.rsiExtreme)) {
      rsiSeries = CandleEngine.computeRsi(candles);
    }

    // Compute MACD if needed
    ({List<double?> line, List<double?> signal, List<double?> hist})? macdResult;
    if (activeStrategies.contains(StrategyType.macdDivergence)) {
      macdResult = CandleEngine.computeMacd(candles);
    }

    /// Helper to add a signal with cooldown deduplication.
    void addSignal(StrategySignal signal) {
      final candle = candles[signal.candleIndex];
      if (settings.strictConfirmation && (candle.body == 0 ||
          (signal.isBuy ? !candle.isBullish : !candle.isBearish))) return;
      if (settings.requireVolumeConfirmation && !_hasVolumeConfirmation(
          candles, signal.candleIndex, multiplier: settings.volumeMultiplier)) return;
      final key = (signal.strategy, signal.isBuy);
      final lastBar = lastSignalBar[key];
      if (lastBar != null && signal.candleIndex - lastBar < settings.cooldownBars) return;
      lastSignalBar[key] = signal.candleIndex;
      signals.add(signal);
    }

    for (var i = 2; i < candles.length; i++) {
      // 1. Support Bounce
      if (activeStrategies.contains(StrategyType.supportBounce)) {
        final signal = _checkSupportBounce(candles, i);
        if (signal != null) addSignal(signal);
      }

      // 2. Resistance Rejection
      if (activeStrategies.contains(StrategyType.resistanceRejection)) {
        final signal = _checkResistanceRejection(candles, i);
        if (signal != null) addSignal(signal);
      }

      // 3. EMA Crossover
      if (activeStrategies.contains(StrategyType.emaCrossover) &&
          fastEmaSeries != null &&
          slowEmaSeries != null) {
        final signal = _checkEmaCrossover(
            candles, i, fastEmaSeries, slowEmaSeries, settings);
        if (signal != null) addSignal(signal);
      }

      // 4. Bollinger Band Reversal
      if (activeStrategies.contains(StrategyType.bollingerReversal) &&
          bbResult != null) {
        final signal = _checkBollingerReversal(candles, i, bbResult, settings);
        if (signal != null) addSignal(signal);
      }

      // 5. RSI Overbought / Oversold
      if (activeStrategies.contains(StrategyType.rsiExtreme) &&
          rsiSeries != null) {
        final signal = _checkRsiExtreme(candles, i, rsiSeries, settings);
        if (signal != null) addSignal(signal);
      }

      // 6. Order Block Retest
      if (activeStrategies.contains(StrategyType.orderBlockRetest)) {
        final signal = _checkOrderBlockRetest(candles, i);
        if (signal != null) addSignal(signal);
      }

      // 7. Fair Value Gap Fill & Rejection
      if (activeStrategies.contains(StrategyType.fvgFillRejection)) {
        final signal = _checkFvgFillRejection(candles, i);
        if (signal != null) addSignal(signal);
      }

      // 8. Engulfing Candle Pattern
      if (activeStrategies.contains(StrategyType.engulfing)) {
        final signal = _checkEngulfing(candles, i);
        if (signal != null) addSignal(signal);
      }

      // 9. MACD Divergence
      if (activeStrategies.contains(StrategyType.macdDivergence) &&
          macdResult != null) {
        final signal = _checkMacdDivergence(candles, i, macdResult.hist);
        if (signal != null) addSignal(signal);
      }
    }

    // Bound output by maxVisibleSignals (take latest)
    if (signals.length > settings.maxVisibleSignals) {
      return signals.sublist(signals.length - settings.maxVisibleSignals);
    }

    return signals;
  }

  // ==========================================================
  // DETECTION HELPERS
  // ==========================================================

  // ==========================================================
  // SHARED HELPERS
  // ==========================================================

  /// Volume confirmation: current candle volume > 1.5x average of last 20 candles.
  static bool _hasVolumeConfirmation(List<CandleData> candles, int i,
      {double multiplier = 1.5}) {
    final lookback = math.min(20, i);
    if (lookback < 20) return false; // missing history is not confirmation
    double avgVol = 0;
    for (var j = i - lookback; j < i; j++) {
      avgVol += candles[j].volume;
    }
    avgVol /= lookback;
    return avgVol > 0 && candles[i].volume >= avgVol * multiplier;
  }

  /// Count how many candles in the lookback window touched a price level within tolerance.
  static int _countTouches(List<CandleData> candles, int start, int end,
      double level, double tolerance, {required bool useLow}) {
    int count = 0;
    for (var j = start; j < end; j++) {
      final testPrice = useLow ? candles[j].low : candles[j].high;
      if ((testPrice - level).abs() <= tolerance) count++;
    }
    return count;
  }

  // ==========================================================
  // DETECTION HELPERS
  // ==========================================================

  /// 1. Support Bounce Detection (with multi-touch validation + volume confirmation)
  static StrategySignal? _checkSupportBounce(List<CandleData> candles, int i) {
    if (i < 20) return null;
    final curr = candles[i];

    // Check candle confirmation: must be a bullish candle closing above support
    if (!curr.isBullish) return null;

    // Find local support (min low) in recent lookback window prior to current candle
    final lookbackStart = math.max(0, i - 20);
    var minLow = double.infinity;
    for (var j = lookbackStart; j < i; j++) {
      if (candles[j].low < minLow) {
        minLow = candles[j].low;
      }
    }

    if (minLow == double.infinity) return null;

    // Tolerance range for bounce (0.5% of price)
    final tolerance = minLow * 0.005;

    // Touch validation: require at least 2 prior touches of the support level
    final touches = _countTouches(candles, lookbackStart, i, minLow, tolerance, useLow: true);
    if (touches < 2) return null;

    // Current candle low touched/tested near support and closed above it
    if (curr.low <= minLow + tolerance && curr.close > minLow) {
      final hasVolume = _hasVolumeConfirmation(candles, i);
      return StrategySignal(
        id: 'sb_${curr.timestamp}',
        strategy: StrategyType.supportBounce,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.low,
        isBuy: true,
        title: 'Support Bounce',
        shortTag: 'Bounce',
        explanation:
            'Price tested support ($touches touches at ${minLow.toStringAsFixed(2)}) and closed bullishly above it.${hasVolume ? ' Volume confirmed.' : ''}',
      );
    }
    return null;
  }

  /// 2. Resistance Rejection Detection (with multi-touch validation + volume confirmation)
  static StrategySignal? _checkResistanceRejection(
      List<CandleData> candles, int i) {
    if (i < 20) return null;
    final curr = candles[i];

    // Check candle confirmation: must be a bearish candle closing below resistance
    if (!curr.isBearish) return null;

    // Find local resistance (max high) in recent lookback window prior to current candle
    final lookbackStart = math.max(0, i - 20);
    var maxHigh = -double.infinity;
    for (var j = lookbackStart; j < i; j++) {
      if (candles[j].high > maxHigh) {
        maxHigh = candles[j].high;
      }
    }

    if (maxHigh == -double.infinity) return null;

    // Tolerance range for rejection (0.5% of price)
    final tolerance = maxHigh * 0.005;

    // Touch validation: require at least 2 prior touches of the resistance level
    final touches = _countTouches(candles, lookbackStart, i, maxHigh, tolerance, useLow: false);
    if (touches < 2) return null;

    // Current candle high touched/tested near resistance and closed below it
    if (curr.high >= maxHigh - tolerance && curr.close < maxHigh) {
      final hasVolume = _hasVolumeConfirmation(candles, i);
      return StrategySignal(
        id: 'rr_${curr.timestamp}',
        strategy: StrategyType.resistanceRejection,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.high,
        isBuy: false,
        title: 'Resistance Rejection',
        shortTag: 'Reject',
        explanation:
            'Price tested resistance ($touches touches at ${maxHigh.toStringAsFixed(2)}) and closed bearishly below it.${hasVolume ? ' Volume confirmed.' : ''}',
      );
    }
    return null;
  }

  /// 3. EMA Crossover Detection
  static StrategySignal? _checkEmaCrossover(
    List<CandleData> candles,
    int i,
    List<double?> fastEma,
    List<double?> slowEma,
    StrategySettings settings,
  ) {
    if (i < 1) return null;
    final prevFast = fastEma[i - 1];
    final prevSlow = slowEma[i - 1];
    final currFast = fastEma[i];
    final currSlow = slowEma[i];

    if (prevFast == null ||
        prevSlow == null ||
        currFast == null ||
        currSlow == null) {
      return null;
    }

    final curr = candles[i];

    // Bullish Crossover: Fast EMA crosses above Slow EMA
    if (prevFast <= prevSlow && currFast > currSlow) {
      if (settings.strictConfirmation && !curr.isBullish) return null;
      return StrategySignal(
        id: 'ema_bull_${curr.timestamp}',
        strategy: StrategyType.emaCrossover,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.low,
        isBuy: true,
        title: 'Bullish EMA Cross',
        shortTag: 'EMA Cross',
        explanation:
            'EMA ${settings.emaFastPeriod} crossed above EMA ${settings.emaSlowPeriod}, signaling potential increasing bullish momentum.',
      );
    }

    // Bearish Crossover: Fast EMA crosses below Slow EMA
    if (prevFast >= prevSlow && currFast < currSlow) {
      if (settings.strictConfirmation && !curr.isBearish) return null;
      return StrategySignal(
        id: 'ema_bear_${curr.timestamp}',
        strategy: StrategyType.emaCrossover,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.high,
        isBuy: false,
        title: 'Bearish EMA Cross',
        shortTag: 'EMA Cross',
        explanation:
            'EMA ${settings.emaFastPeriod} crossed below EMA ${settings.emaSlowPeriod}, signaling potential weakening momentum and bearish bias.',
      );
    }

    return null;
  }

  /// 4. Bollinger Band Reversal Detection
  static StrategySignal? _checkBollingerReversal(
    List<CandleData> candles,
    int i,
    ({List<double?> upper, List<double?> middle, List<double?> lower}) bb,
    StrategySettings settings,
  ) {
    if (i < 1) return null;

    final prevCandle = candles[i - 1];
    final currCandle = candles[i];

    final prevLower = bb.lower[i - 1];
    final prevUpper = bb.upper[i - 1];

    final lower = bb.lower[i];
    final upper = bb.upper[i];
    if (prevLower == null || prevUpper == null || lower == null || upper == null) return null;
    final inside = currCandle.close >= lower && currCandle.close <= upper;

    // Bullish Reversal: Prev candle closes below lower BB, current candle closes bullish & back inside
    if (prevCandle.close < prevLower && currCandle.isBullish && inside) {
      return StrategySignal(
        id: 'bb_bull_${currCandle.timestamp}',
        strategy: StrategyType.bollingerReversal,
        timestamp: currCandle.timestamp,
        candleIndex: i,
        price: currCandle.low,
        isBuy: true,
        title: 'Bollinger Reversal',
        shortTag: 'BB Rev',
        explanation:
            'Price closed outside lower Bollinger Band followed by a bullish reversal candle, indicating a potential mean-reversion move upwards.',
      );
    }

    // Bearish Reversal: Prev candle closes above upper BB, current candle closes bearish & back inside
    if (prevCandle.close > prevUpper && currCandle.isBearish && inside) {
      return StrategySignal(
        id: 'bb_bear_${currCandle.timestamp}',
        strategy: StrategyType.bollingerReversal,
        timestamp: currCandle.timestamp,
        candleIndex: i,
        price: currCandle.high,
        isBuy: false,
        title: 'Bollinger Reversal',
        shortTag: 'BB Rev',
        explanation:
            'Price closed outside upper Bollinger Band followed by a bearish reversal candle, indicating a potential mean-reversion move downwards.',
      );
    }

    return null;
  }

  /// 5. RSI Overbought / Oversold Detection
  static StrategySignal? _checkRsiExtreme(
    List<CandleData> candles,
    int i,
    List<double?> rsi,
    StrategySettings settings,
  ) {
    if (i < 1) return null;
    final prevRsi = rsi[i - 1];
    final currRsi = rsi[i];

    if (prevRsi == null || currRsi == null) return null;

    final curr = candles[i];

    // Oversold Signal: RSI crosses up from below lower level (e.g. 30)
    if (prevRsi < settings.rsiLowerLevel && currRsi >= settings.rsiLowerLevel) {
      if (settings.strictConfirmation && !curr.isBullish) return null;
      return StrategySignal(
        id: 'rsi_oversold_${curr.timestamp}',
        strategy: StrategyType.rsiExtreme,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.low,
        isBuy: true,
        title: 'RSI Oversold',
        shortTag: 'RSI',
        explanation:
            'RSI recovered back above ${settings.rsiLowerLevel.toInt()} from oversold conditions, suggesting a potential short-term bullish bounce.',
      );
    }

    // Overbought Signal: RSI crosses down from above upper level (e.g. 70)
    if (prevRsi > settings.rsiUpperLevel && currRsi <= settings.rsiUpperLevel) {
      if (settings.strictConfirmation && !curr.isBearish) return null;
      return StrategySignal(
        id: 'rsi_overbought_${curr.timestamp}',
        strategy: StrategyType.rsiExtreme,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.high,
        isBuy: false,
        title: 'RSI Overbought',
        shortTag: 'RSI',
        explanation:
            'RSI dropped back below ${settings.rsiUpperLevel.toInt()} from overbought conditions, suggesting a potential short-term bearish pullback.',
      );
    }

    return null;
  }

  /// 6. Order Block Retest Detection
  static StrategySignal? _checkOrderBlockRetest(List<CandleData> candles, int i) {
    if (i < 10) return null;
    final curr = candles[i];

    final lookback = math.max(2, i - 15);
    for (var j = i - 2; j >= lookback; j--) {
      final obCandle = candles[j];
      final next1 = candles[j + 1];

      // Demand Order Block: Bearish candle before strong upward movement
      if (obCandle.isBearish && next1.isBullish && next1.close > obCandle.high) {
        final obTop = obCandle.high;
        final obBottom = obCandle.low;

        // Current candle touches or dips into Demand OB zone and closes bullishly
        final consumed = candles.sublist(j + 2, i).any((c) => c.low <= obTop);
        if (!consumed && curr.low <= obTop && curr.high >= obBottom &&
            curr.close > obTop && curr.isBullish) {
          return StrategySignal(
            id: 'ob_buy_${curr.timestamp}',
            strategy: StrategyType.orderBlockRetest,
            timestamp: curr.timestamp,
            candleIndex: i,
            price: curr.low,
            isBuy: true,
            title: 'Order Block Retest',
            shortTag: 'OB Retest',
            explanation:
                'Price returned to retest a Demand Order Block (${obBottom.toStringAsFixed(2)} - ${obTop.toStringAsFixed(2)}) and rejected higher with bullish confirmation.',
          );
        }
      }

      // Supply Order Block: Bullish candle before strong downward movement
      if (obCandle.isBullish && next1.isBearish && next1.close < obCandle.low) {
        final obTop = obCandle.high;
        final obBottom = obCandle.low;

        // Current candle touches or rallies into Supply OB zone and closes bearishly
        final consumed = candles.sublist(j + 2, i).any((c) => c.high >= obBottom);
        if (!consumed && curr.high >= obBottom && curr.low <= obTop &&
            curr.close < obBottom && curr.isBearish) {
          return StrategySignal(
            id: 'ob_sell_${curr.timestamp}',
            strategy: StrategyType.orderBlockRetest,
            timestamp: curr.timestamp,
            candleIndex: i,
            price: curr.high,
            isBuy: false,
            title: 'Order Block Retest',
            shortTag: 'OB Reject',
            explanation:
                'Price returned to retest a Supply Order Block (${obBottom.toStringAsFixed(2)} - ${obTop.toStringAsFixed(2)}) and rejected lower with bearish confirmation.',
          );
        }
      }
    }

    return null;
  }

  /// 7. Fair Value Gap Fill & Rejection Detection (with c2 displacement validation)
  static StrategySignal? _checkFvgFillRejection(List<CandleData> candles, int i) {
    if (i < 5) return null;
    final curr = candles[i];

    final lookback = math.max(2, i - 12);
    for (var j = i - 1; j >= lookback; j--) {
      if (j < 2) continue;
      final c1 = candles[j - 2];
      final c2 = candles[j - 1]; // displacement candle
      final c3 = candles[j];

      // Require c2 (middle candle) to be a displacement candle (body/range > 0.35)
      if (c2.range <= 0 || c2.body / c2.range < 0.35) continue;

      // Bullish FVG: c1.high < c3.low
      if (c1.high < c3.low && c2.isBullish) {
        final fvgBottom = c1.high;
        final fvgTop = c3.low;

        // Current candle enters the FVG gap and closes bullishly above fvgBottom
        final consumed = candles.sublist(j + 1, i).any((c) => c.low <= fvgTop);
        if (!consumed && curr.low <= fvgTop && curr.high >= fvgBottom &&
            curr.close > fvgTop && curr.isBullish) {
          return StrategySignal(
            id: 'fvg_buy_${curr.timestamp}',
            strategy: StrategyType.fvgFillRejection,
            timestamp: curr.timestamp,
            candleIndex: i,
            price: curr.low,
            isBuy: true,
            title: 'FVG Fill & Rejection',
            shortTag: 'FVG Fill',
            explanation:
                'Price filled a Bullish Fair Value Gap (${fvgBottom.toStringAsFixed(2)} - ${fvgTop.toStringAsFixed(2)}) and reacted with buying momentum.',
          );
        }
      }

      // Bearish FVG: c1.low > c3.high
      if (c1.low > c3.high && c2.isBearish) {
        final fvgTop = c1.low;
        final fvgBottom = c3.high;

        // Current candle enters the FVG gap and closes bearishly below fvgTop
        final consumed = candles.sublist(j + 1, i).any((c) => c.high >= fvgBottom);
        if (!consumed && curr.high >= fvgBottom && curr.low <= fvgTop &&
            curr.close < fvgBottom && curr.isBearish) {
          return StrategySignal(
            id: 'fvg_sell_${curr.timestamp}',
            strategy: StrategyType.fvgFillRejection,
            timestamp: curr.timestamp,
            candleIndex: i,
            price: curr.high,
            isBuy: false,
            title: 'FVG Fill & Rejection',
            shortTag: 'FVG Fill',
            explanation:
                'Price filled a Bearish Fair Value Gap (${fvgBottom.toStringAsFixed(2)} - ${fvgTop.toStringAsFixed(2)}) and reacted with selling momentum.',
          );
        }
      }
    }

    return null;
  }

  /// 8. Engulfing Candle Pattern Detection
  static StrategySignal? _checkEngulfing(List<CandleData> candles, int i) {
    if (i < 2) return null;
    final prev = candles[i - 1];
    final curr = candles[i];

    // Require meaningful body sizes
    if (curr.range <= 0 || curr.body / curr.range < 0.4) return null;
    if (prev.range <= 0 || prev.body / prev.range < 0.25) return null;

    // Bullish Engulfing: prev bearish, curr bullish, curr body engulfs prev body
    if (prev.isBearish && curr.isBullish &&
        curr.close >= prev.open && curr.open <= prev.close &&
        (curr.close - curr.open) >= (prev.open - prev.close)) {
      return StrategySignal(
        id: 'eng_bull_${curr.timestamp}',
        strategy: StrategyType.engulfing,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.low,
        isBuy: true,
        title: 'Bullish Engulfing',
        shortTag: 'Engulf',
        explanation:
            'Bullish candle completely engulfed the previous bearish body, indicating strong buyer takeover and potential reversal.',
      );
    }

    // Bearish Engulfing: prev bullish, curr bearish, curr body engulfs prev body
    if (prev.isBullish && curr.isBearish &&
        curr.close <= prev.open && curr.open >= prev.close &&
        (curr.open - curr.close) >= (prev.close - prev.open)) {
      return StrategySignal(
        id: 'eng_bear_${curr.timestamp}',
        strategy: StrategyType.engulfing,
        timestamp: curr.timestamp,
        candleIndex: i,
        price: curr.high,
        isBuy: false,
        title: 'Bearish Engulfing',
        shortTag: 'Engulf',
        explanation:
            'Bearish candle completely engulfed the previous bullish body, indicating strong seller takeover and potential reversal.',
      );
    }

    return null;
  }

  /// 9. MACD Divergence Detection
  static StrategySignal? _checkMacdDivergence(
    List<CandleData> candles,
    int i,
    List<double?> macdHist,
  ) {
    // Two right-hand bars confirm the pivot; emit NOW, never backdate it.
    if (i < 8) return null;
    final pivot = i - 2;
    bool isPivot(int index, bool low) {
      for (var k = index - 2; k <= index + 2; k++) {
        if (k == index) continue;
        if (low ? candles[k].low <= candles[index].low
                : candles[k].high >= candles[index].high) return false;
      }
      return true;
    }
    final currentHist = macdHist[pivot];
    if (currentHist == null) return null;
    for (final buy in [true, false]) {
      if (!isPivot(pivot, buy)) continue;
      for (var j = pivot - 4; j >= math.max(2, pivot - 40); j--) {
        final previousHist = macdHist[j];
        if (previousHist == null || !isPivot(j, buy)) continue;
        final divergent = buy
            ? candles[pivot].low < candles[j].low && currentHist > previousHist && currentHist < 0
            : candles[pivot].high > candles[j].high && currentHist < previousHist && currentHist > 0;
        if (divergent) {
          return StrategySignal(
            id: 'macd_${buy ? 'bull' : 'bear'}_${candles[i].timestamp}',
            strategy: StrategyType.macdDivergence, timestamp: candles[i].timestamp,
            candleIndex: i, price: buy ? candles[i].low : candles[i].high,
            isBuy: buy, title: '${buy ? 'Bullish' : 'Bearish'} MACD Divergence',
            shortTag: 'MACD Div',
            explanation: 'Price and MACD histogram diverged between two confirmed swing points. '
                'The latest pivot is confirmed by two completed right-hand bars; this is not an entry guarantee.',
          );
        }
        break; // compare consecutive eligible pivots, not cherry-picked history
      }
    }
    return null;
  }
}
