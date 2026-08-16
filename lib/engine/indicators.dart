/// Indicator definitions and computation.
///
/// Pure Dart — no Flutter, no state, no I/O. Every function takes a candle list
/// and returns a value series aligned index-for-index with it, using `null`
/// for the warm-up region where the indicator is not yet defined.
library;

import 'dart:math' as math;
import 'package:app/domain/entities/candle_data.dart';

enum IndicatorType {
  ema,
  sma,
  rsi,
  volume,
  macd,
  vwap,
  bollingerBands,
  atr,
  stochRsi,
  superTrend;

  String get label {
    switch (this) {
      case IndicatorType.ema:
        return 'EMA (20)';
      case IndicatorType.sma:
        return 'SMA (50)';
      case IndicatorType.rsi:
        return 'RSI (14)';
      case IndicatorType.volume:
        return 'Volume';
      case IndicatorType.macd:
        return 'MACD (12, 26, 9)';
      case IndicatorType.vwap:
        return 'VWAP';
      case IndicatorType.bollingerBands:
        return 'Bollinger Bands (20, 2)';
      case IndicatorType.atr:
        return 'ATR (14)';
      case IndicatorType.stochRsi:
        return 'Stochastic RSI';
      case IndicatorType.superTrend:
        return 'SuperTrend (10, 3)';
    }
  }

  /// Default line colour as an ARGB value.
  int get colorValue {
    switch (this) {
      case IndicatorType.ema:
        return 0xFFF59E0B;
      case IndicatorType.sma:
        return 0xFF38BDF8;
      case IndicatorType.rsi:
        return 0xFFA78BFA;
      case IndicatorType.volume:
        return 0xFF94A3B8;
      case IndicatorType.macd:
        return 0xFF60A5FA;
      case IndicatorType.vwap:
        return 0xFFFFD700;
      case IndicatorType.bollingerBands:
        return 0xFF34D399;
      case IndicatorType.atr:
        return 0xFFFF7096;
      case IndicatorType.stochRsi:
        return 0xFFC77DFF;
      case IndicatorType.superTrend:
        return 0xFF10B981;
    }
  }

  /// True when the indicator renders in its own panel below price.
  bool get isSubPanel =>
      this == IndicatorType.macd ||
      this == IndicatorType.rsi ||
      this == IndicatorType.atr ||
      this == IndicatorType.stochRsi ||
      this == IndicatorType.volume;

  /// True when the indicator draws as a line over the price panel.
  bool get isPriceOverlay => !isSubPanel;

  static IndicatorType? fromName(String n) {
    for (final t in IndicatorType.values) {
      if (t.name == n) return t;
    }
    return null;
  }
}

/// All computed indicator series for one candle set.
class ChartIndicators {
  final List<double?> ema;
  final List<double?> sma;
  final List<double?> rsi;
  final List<double?> vwap;
  final List<double?> macdLine;
  final List<double?> macdSignal;
  final List<double?> macdHist;
  final List<double?> bbUpper;
  final List<double?> bbMiddle;
  final List<double?> bbLower;
  final List<double?> atr;
  final List<double?> stochK;
  final List<double?> stochD;
  final List<double?> superTrend;
  final List<bool?> superTrendBullish;

  const ChartIndicators({
    required this.ema,
    required this.sma,
    required this.rsi,
    required this.vwap,
    required this.macdLine,
    required this.macdSignal,
    required this.macdHist,
    required this.bbUpper,
    required this.bbMiddle,
    required this.bbLower,
    required this.atr,
    required this.stochK,
    required this.stochD,
    required this.superTrend,
    required this.superTrendBullish,
  });

  static ChartIndicators empty(int length) {
    final nulls = List<double?>.filled(length, null);
    final boolNulls = List<bool?>.filled(length, null);
    return ChartIndicators(
      ema: nulls,
      sma: nulls,
      rsi: nulls,
      vwap: nulls,
      macdLine: nulls,
      macdSignal: nulls,
      macdHist: nulls,
      bbUpper: nulls,
      bbMiddle: nulls,
      bbLower: nulls,
      atr: nulls,
      stochK: nulls,
      stochD: nulls,
      superTrend: nulls,
      superTrendBullish: boolNulls,
    );
  }

  /// Series for a given overlay type, or null for non-overlay types.
  List<double?>? seriesFor(IndicatorType t) {
    switch (t) {
      case IndicatorType.ema:
        return ema;
      case IndicatorType.sma:
        return sma;
      case IndicatorType.vwap:
        return vwap;
      case IndicatorType.bollingerBands:
        return bbMiddle;
      case IndicatorType.superTrend:
        return superTrend;
      case IndicatorType.rsi:
      case IndicatorType.macd:
      case IndicatorType.volume:
      case IndicatorType.atr:
      case IndicatorType.stochRsi:
        return null;
    }
  }
}

/// Stateless indicator computation.
class CandleEngine {
  CandleEngine._();

  static List<double?> computeEma(List<CandleData> candles, int period) {
    final n = candles.length;
    if (n < period || period <= 0) return List<double?>.filled(n, null);

    final k = 2.0 / (period + 1);
    final result = List<double?>.filled(n, null);

    double seed = 0;
    for (int i = 0; i < period; i++) {
      seed += candles[i].close;
    }
    double ema = seed / period;
    result[period - 1] = ema;

    for (int i = period; i < n; i++) {
      ema = candles[i].close * k + ema * (1 - k);
      result[i] = ema;
    }
    return result;
  }

  static List<double?> computeSma(List<CandleData> candles, int period) {
    final n = candles.length;
    if (n < period || period <= 0) return List<double?>.filled(n, null);

    final result = List<double?>.filled(n, null);
    double windowSum = 0;
    for (int i = 0; i < period; i++) {
      windowSum += candles[i].close;
    }
    result[period - 1] = windowSum / period;

    for (int i = period; i < n; i++) {
      windowSum += candles[i].close - candles[i - period].close;
      result[i] = windowSum / period;
    }
    return result;
  }

  static List<double?> computeRsi(List<CandleData> candles, {int period = 14}) {
    final n = candles.length;
    if (n <= period) return List<double?>.filled(n, null);

    final result = List<double?>.filled(n, null);
    double gainSum = 0, lossSum = 0;

    for (int i = 1; i <= period; i++) {
      final diff = candles[i].close - candles[i - 1].close;
      if (diff >= 0) {
        gainSum += diff;
      } else {
        lossSum -= diff;
      }
    }

    double avgGain = gainSum / period;
    double avgLoss = lossSum / period;

    result[period] = avgLoss == 0 ? 100 : 100 - (100 / (1 + (avgGain / avgLoss)));

    for (int i = period + 1; i < n; i++) {
      final diff = candles[i].close - candles[i - 1].close;
      final gain = diff > 0 ? diff : 0.0;
      final loss = diff < 0 ? -diff : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      if (avgLoss == 0) {
        result[i] = 100;
      } else {
        final rs = avgGain / avgLoss;
        result[i] = 100 - (100 / (1 + rs));
      }
    }

    return result;
  }

  static List<double?> computeVwap(List<CandleData> candles) {
    final result = List<double?>.filled(candles.length, null);
    double cumPV = 0, cumVol = 0;
    int? lastDay;

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final dt = DateTime.fromMillisecondsSinceEpoch(c.timestamp).toLocal();
      final day = dt.year * 10000 + dt.month * 100 + dt.day;
      if (day != lastDay) {
        cumPV = 0;
        cumVol = 0;
        lastDay = day;
      }
      final typical = (c.high + c.low + c.close) / 3.0;
      cumPV += typical * c.volume;
      cumVol += c.volume;
      result[i] = cumVol > 0 ? cumPV / cumVol : null;
    }
    return result;
  }

  static ({List<double?> upper, List<double?> middle, List<double?> lower})
      computeBollingerBands(List<CandleData> candles,
          {int period = 20, double multiplier = 2.0}) {
    final n = candles.length;
    final middle = computeSma(candles, period);
    final upper = List<double?>.filled(n, null);
    final lower = List<double?>.filled(n, null);

    for (int i = period - 1; i < n; i++) {
      final mid = middle[i];
      if (mid == null) continue;

      double variance = 0;
      for (int j = i - period + 1; j <= i; j++) {
        final diff = candles[j].close - mid;
        variance += diff * diff;
      }
      final stdDev = math.sqrt(variance / period);
      upper[i] = mid + multiplier * stdDev;
      lower[i] = mid - multiplier * stdDev;
    }

    return (upper: upper, middle: middle, lower: lower);
  }

  static List<double?> computeAtr(List<CandleData> candles, {int period = 14}) {
    final n = candles.length;
    if (n < period + 1) return List<double?>.filled(n, null);

    final tr = List<double>.filled(n, 0);
    for (int i = 1; i < n; i++) {
      final high = candles[i].high;
      final low = candles[i].low;
      final prevClose = candles[i - 1].close;
      tr[i] = math.max(
        high - low,
        math.max((high - prevClose).abs(), (low - prevClose).abs()),
      );
    }

    final atr = List<double?>.filled(n, null);
    double sum = 0;
    for (int i = 1; i <= period; i++) {
      sum += tr[i];
    }
    atr[period] = sum / period;

    for (int i = period + 1; i < n; i++) {
      atr[i] = (atr[i - 1]! * (period - 1) + tr[i]) / period;
    }

    return atr;
  }

  static ({List<double?> k, List<double?> d}) computeStochRsi(
    List<CandleData> candles, {
    int rsiPeriod = 14,
    int stochPeriod = 14,
    int kPeriod = 3,
    int dPeriod = 3,
  }) {
    final n = candles.length;
    final rsi = computeRsi(candles, period: rsiPeriod);
    final rawStoch = List<double?>.filled(n, null);

    for (int i = rsiPeriod + stochPeriod - 1; i < n; i++) {
      double minRsi = double.infinity;
      double maxRsi = -double.infinity;
      bool valid = true;

      for (int j = i - stochPeriod + 1; j <= i; j++) {
        final val = rsi[j];
        if (val == null) {
          valid = false;
          break;
        }
        minRsi = math.min(minRsi, val);
        maxRsi = math.max(maxRsi, val);
      }

      if (valid && maxRsi > minRsi) {
        rawStoch[i] = (rsi[i]! - minRsi) / (maxRsi - minRsi) * 100;
      }
    }

    // %K = SMA(StochRSI, kPeriod)
    final kSeries = List<double?>.filled(n, null);
    for (int i = rsiPeriod + stochPeriod + kPeriod - 2; i < n; i++) {
      double sum = 0;
      bool valid = true;
      for (int j = i - kPeriod + 1; j <= i; j++) {
        final val = rawStoch[j];
        if (val == null) {
          valid = false;
          break;
        }
        sum += val;
      }
      if (valid) kSeries[i] = sum / kPeriod;
    }

    // %D = SMA(%K, dPeriod)
    final dSeries = List<double?>.filled(n, null);
    for (int i = rsiPeriod + stochPeriod + kPeriod + dPeriod - 3; i < n; i++) {
      double sum = 0;
      bool valid = true;
      for (int j = i - dPeriod + 1; j <= i; j++) {
        final val = kSeries[j];
        if (val == null) {
          valid = false;
          break;
        }
        sum += val;
      }
      if (valid) dSeries[i] = sum / dPeriod;
    }

    return (k: kSeries, d: dSeries);
  }

  static ({List<double?> line, List<bool?> isBullish}) computeSuperTrend(
    List<CandleData> candles, {
    int period = 10,
    double multiplier = 3.0,
  }) {
    final n = candles.length;
    final atr = computeAtr(candles, period: period);
    final superTrend = List<double?>.filled(n, null);
    final isBull = List<bool?>.filled(n, null);

    if (n < period + 1) return (line: superTrend, isBullish: isBull);

    final upperBand = List<double>.filled(n, 0);
    final lowerBand = List<double>.filled(n, 0);

    for (int i = period; i < n; i++) {
      final a = atr[i] ?? 0;
      final hl2 = (candles[i].high + candles[i].low) / 2;
      final basicUpper = hl2 + multiplier * a;
      final basicLower = hl2 - multiplier * a;

      final prevUpper = i > period ? upperBand[i - 1] : basicUpper;
      final prevLower = i > period ? lowerBand[i - 1] : basicLower;
      final prevClose = i > 0 ? candles[i - 1].close : candles[i].close;

      upperBand[i] = (basicUpper < prevUpper || prevClose > prevUpper)
          ? basicUpper
          : prevUpper;
      lowerBand[i] = (basicLower > prevLower || prevClose < prevLower)
          ? basicLower
          : prevLower;

      bool prevBull = i > period ? (isBull[i - 1] ?? true) : true;
      if (prevBull && candles[i].close < lowerBand[i]) {
        prevBull = false;
      } else if (!prevBull && candles[i].close > upperBand[i]) {
        prevBull = true;
      }

      isBull[i] = prevBull;
      superTrend[i] = prevBull ? lowerBand[i] : upperBand[i];
    }

    return (line: superTrend, isBullish: isBull);
  }

  static ({List<double?> line, List<double?> signal, List<double?> hist})
      computeMacd(
    List<CandleData> candles, {
    int fast = 12,
    int slow = 26,
    int signalPeriod = 9,
  }) {
    final n = candles.length;
    final emaFast = computeEma(candles, fast);
    final emaSlow = computeEma(candles, slow);

    final macdLine = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      final f = emaFast[i], s = emaSlow[i];
      if (f != null && s != null) macdLine[i] = f - s;
    }

    final signalLine = List<double?>.filled(n, null);
    int firstMacd = n;
    for (int i = 0; i < n; i++) {
      if (macdLine[i] != null) {
        firstMacd = i;
        break;
      }
    }

    if (n - firstMacd >= signalPeriod) {
      final k = 2.0 / (signalPeriod + 1);
      double sig = 0;
      for (int i = firstMacd; i < firstMacd + signalPeriod; i++) {
        sig += macdLine[i]!;
      }
      sig /= signalPeriod;
      signalLine[firstMacd + signalPeriod - 1] = sig;

      for (int i = firstMacd + signalPeriod; i < n; i++) {
        final m = macdLine[i];
        if (m == null) continue;
        sig = m * k + sig * (1 - k);
        signalLine[i] = sig;
      }
    }

    final hist = List<double?>.filled(n, null);
    for (int i = 0; i < n; i++) {
      final m = macdLine[i], s = signalLine[i];
      if (m != null && s != null) hist[i] = m - s;
    }

    return (line: macdLine, signal: signalLine, hist: hist);
  }

  /// Compute every series in one pass.
  static ChartIndicators computeAll(List<CandleData> candles) {
    if (candles.isEmpty) return ChartIndicators.empty(0);
    final macd = computeMacd(candles);
    final bb = computeBollingerBands(candles);
    final stoch = computeStochRsi(candles);
    final superTr = computeSuperTrend(candles);

    return ChartIndicators(
      ema: computeEma(candles, 20),
      sma: computeSma(candles, 50),
      rsi: computeRsi(candles),
      vwap: computeVwap(candles),
      macdLine: macd.line,
      macdSignal: macd.signal,
      macdHist: macd.hist,
      bbUpper: bb.upper,
      bbMiddle: bb.middle,
      bbLower: bb.lower,
      atr: computeAtr(candles),
      stochK: stoch.k,
      stochD: stoch.d,
      superTrend: superTr.line,
      superTrendBullish: superTr.isBullish,
    );
  }
}
