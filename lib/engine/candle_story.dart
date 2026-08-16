/// Candle Story — deterministic narrative generation from OHLCV data.
///
/// Takes a [CandleAnalytics] result plus surrounding candle context and
/// produces a natural-language story describing what happened during the
/// candle. Pure computation, no Flutter dependency, no external API.
library;

import 'dart:math' as math;

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/candle_analytics.dart';

// ============================================================
// ENUMS
// ============================================================

/// The dominant character / structure of a single candle.
enum CandleCharacter {
  strongBullish('Strong Bullish'),
  strongBearish('Strong Bearish'),
  bullishRejection('Bullish Rejection'),
  bearishRejection('Bearish Rejection'),
  bullishIndecision('Bullish Indecision'),
  bearishIndecision('Bearish Indecision'),
  doji('Doji'),
  hammer('Hammer'),
  invertedHammer('Inverted Hammer'),
  shootingStar('Shooting Star'),
  engulfingBullish('Bullish Engulfing'),
  engulfingBearish('Bearish Engulfing'),
  neutral('Neutral');

  final String label;
  const CandleCharacter(this.label);
}

/// Volume relative to its recent average.
enum VolumeContext {
  veryLow('Very Low'),
  low('Low'),
  average('Average'),
  high('High'),
  veryHigh('Very High');

  final String label;
  const VolumeContext(this.label);
}

/// Surrounding price trend from recent candle history.
enum TrendContext {
  uptrend('Uptrend'),
  downtrend('Downtrend'),
  sideways('Sideways'),
  unknown('Unknown');

  final String label;
  const TrendContext(this.label);
}

/// How decisive the candle's directional move was.
enum MomentumLevel {
  weak('Weak'),
  moderate('Moderate'),
  strong('Strong');

  final String label;
  const MomentumLevel(this.label);
}

/// How strongly a wick rejected price in one direction.
enum RejectionLevel {
  none('None'),
  mild('Mild'),
  strong('Strong');

  final String label;
  const RejectionLevel(this.label);
}

// ============================================================
// CANDLE STORY (data class)
// ============================================================

/// The generated story plus compact analytical metadata for a candle.
class CandleStory {
  /// Short headline, e.g. "Buyers Won, But Faced Resistance".
  final String headline;

  /// 1–3 sentence narrative describing price action.
  final String narrative;

  /// Structural classification of the candle.
  final CandleCharacter character;

  /// Price direction: bullish / bearish / neutral.
  final String direction;

  /// How decisive the move was.
  final MomentumLevel momentum;

  /// Rejection strength at the upper wick.
  final RejectionLevel upperRejection;

  /// Rejection strength at the lower wick.
  final RejectionLevel lowerRejection;

  /// Volume relative to recent average.
  final VolumeContext volumeContext;

  /// Surrounding market trend.
  final TrendContext trendContext;

  const CandleStory({
    required this.headline,
    required this.narrative,
    required this.character,
    required this.direction,
    required this.momentum,
    required this.upperRejection,
    required this.lowerRejection,
    required this.volumeContext,
    required this.trendContext,
  });
}

// ============================================================
// CANDLE STORY GENERATOR
// ============================================================

/// Deterministic story generator. All outputs are produced from OHLCV data
/// alone — no AI, no randomness, no external API.
class CandleStoryGenerator {
  CandleStoryGenerator._();

  // ----------------------------------------------------------
  // THRESHOLDS (tunable)
  // ----------------------------------------------------------

  // Volume vs average ratio thresholds.
  static const double _volVeryLow = 0.4;
  static const double _volLow = 0.7;
  static const double _volHigh = 1.3;
  static const double _volVeryHigh = 1.8;

  // Body percentage thresholds.
  static const double _strongBodyMin = 70.0;
  static const double _dojiBodyMax = 10.0;
  static const double _indecisionBodyMax = 30.0;

  // Wick percentage thresholds.
  static const double _significantWick = 30.0;
  static const double _strongWick = 50.0;

  // Trend analysis.
  static const int _trendLookback = 20;

  // ----------------------------------------------------------
  // PUBLIC API
  // ----------------------------------------------------------

  /// Generate a [CandleStory] for the candle at [index] given its
  /// pre-computed [analytics] and the surrounding [candles] list.
  static CandleStory generate(
    CandleAnalytics analytics,
    List<CandleData> candles,
    int index,
  ) {
    final volumeCtx = _classifyVolume(analytics.volumeVsAverage);
    final trendCtx = _analyzeTrend(candles, index);
    final momentum = _evaluateMomentum(analytics);
    final upperRej = _evaluateRejection(analytics.upperWickPercent);
    final lowerRej = _evaluateRejection(analytics.lowerWickPercent);
    final character = _classifyCharacter(analytics);

    final direction = analytics.isBullish
        ? (analytics.bodyPercent <= _dojiBodyMax ? 'neutral' : 'bullish')
        : (analytics.bodyPercent <= _dojiBodyMax ? 'neutral' : 'bearish');

    final headline = _buildHeadline(character, upperRej, lowerRej);
    final narrative = _buildNarrative(
      character: character,
      analytics: analytics,
      volumeCtx: volumeCtx,
      trendCtx: trendCtx,
      momentum: momentum,
      upperRej: upperRej,
      lowerRej: lowerRej,
    );

    return CandleStory(
      headline: headline,
      narrative: narrative,
      character: character,
      direction: direction,
      momentum: momentum,
      upperRejection: upperRej,
      lowerRejection: lowerRej,
      volumeContext: volumeCtx,
      trendContext: trendCtx,
    );
  }

  // ----------------------------------------------------------
  // VOLUME CONTEXT
  // ----------------------------------------------------------

  static VolumeContext _classifyVolume(double ratio) {
    if (ratio <= _volVeryLow) return VolumeContext.veryLow;
    if (ratio <= _volLow) return VolumeContext.low;
    if (ratio <= _volHigh) return VolumeContext.average;
    if (ratio <= _volVeryHigh) return VolumeContext.high;
    return VolumeContext.veryHigh;
  }

  // ----------------------------------------------------------
  // TREND CONTEXT
  // ----------------------------------------------------------

  static TrendContext _analyzeTrend(List<CandleData> candles, int index) {
    // Need at least a few candles before the current one to gauge trend.
    if (index < 5) return TrendContext.unknown;

    final lookback = math.min(_trendLookback, index);
    final start = index - lookback;

    // Simple linear regression on closes.
    var sumX = 0.0;
    var sumY = 0.0;
    var sumXY = 0.0;
    var sumX2 = 0.0;
    final n = lookback;

    for (var i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = candles[start + i].close;
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final denominator = n * sumX2 - sumX * sumX;
    if (denominator.abs() < 1e-12) return TrendContext.sideways;

    final slope = (n * sumXY - sumX * sumY) / denominator;

    // Normalise slope by the average price to get a percentage slope.
    final avgPrice = sumY / n;
    if (avgPrice.abs() < 1e-12) return TrendContext.unknown;

    final normalizedSlope = (slope / avgPrice) * 100.0;

    // Count rising / falling candles for confirmation.
    var rising = 0;
    var falling = 0;
    for (var i = start + 1; i < start + n; i++) {
      if (candles[i].close > candles[i - 1].close) {
        rising++;
      } else if (candles[i].close < candles[i - 1].close) {
        falling++;
      }
    }

    // Require both slope direction and candle-count confirmation.
    const slopeThreshold = 0.02; // 0.02% per bar
    final risingRatio = rising / (n - 1);
    final fallingRatio = falling / (n - 1);

    if (normalizedSlope > slopeThreshold && risingRatio > 0.55) {
      return TrendContext.uptrend;
    }
    if (normalizedSlope < -slopeThreshold && fallingRatio > 0.55) {
      return TrendContext.downtrend;
    }
    return TrendContext.sideways;
  }

  // ----------------------------------------------------------
  // MOMENTUM
  // ----------------------------------------------------------

  static MomentumLevel _evaluateMomentum(CandleAnalytics a) {
    // Combine body% and ATR ratio for a momentum score.
    final bodyScore = a.bodyPercent / 100.0; // 0..1
    final atrScore = a.atrRatio.clamp(0.0, 2.0) / 2.0; // 0..1
    final score = bodyScore * 0.6 + atrScore * 0.4;

    if (score >= 0.55) return MomentumLevel.strong;
    if (score >= 0.30) return MomentumLevel.moderate;
    return MomentumLevel.weak;
  }

  // ----------------------------------------------------------
  // REJECTION
  // ----------------------------------------------------------

  static RejectionLevel _evaluateRejection(double wickPercent) {
    if (wickPercent >= _strongWick) return RejectionLevel.strong;
    if (wickPercent >= _significantWick) return RejectionLevel.mild;
    return RejectionLevel.none;
  }

  // ----------------------------------------------------------
  // CHARACTER CLASSIFICATION
  // ----------------------------------------------------------

  static CandleCharacter _classifyCharacter(CandleAnalytics a) {
    // First check multi-candle patterns already detected by CandleAnalytics.
    for (final p in a.detectedPatterns) {
      if (p.name == 'Bullish Engulfing') return CandleCharacter.engulfingBullish;
      if (p.name == 'Bearish Engulfing') return CandleCharacter.engulfingBearish;
    }

    // Single-candle structural patterns from detected patterns.
    for (final p in a.detectedPatterns) {
      if (p.name == 'Doji' ||
          p.name == 'Dragonfly Doji' ||
          p.name == 'Gravestone Doji') {
        return CandleCharacter.doji;
      }
      if (p.name == 'Hammer') return CandleCharacter.hammer;
      if (p.name == 'Shooting Star') return CandleCharacter.shootingStar;
      if (p.name == 'Inverted Hammer') return CandleCharacter.invertedHammer;
    }

    // Doji by body percentage (fallback if pattern detection didn't catch it).
    if (a.bodyPercent <= _dojiBodyMax) {
      return CandleCharacter.doji;
    }

    // Strong directional candles.
    if (a.bodyPercent >= _strongBodyMin) {
      return a.isBullish
          ? CandleCharacter.strongBullish
          : CandleCharacter.strongBearish;
    }

    // Rejection candles — meaningful wick on one side.
    if (a.isBullish) {
      if (a.upperWickPercent >= _significantWick) {
        return CandleCharacter.bullishRejection;
      }
      if (a.lowerWickPercent >= _significantWick) {
        // Bullish candle with long lower wick but not a hammer pattern.
        return CandleCharacter.bullishRejection;
      }
    } else {
      if (a.lowerWickPercent >= _significantWick) {
        return CandleCharacter.bearishRejection;
      }
      if (a.upperWickPercent >= _significantWick) {
        return CandleCharacter.bearishRejection;
      }
    }

    // Indecision — smallish body with wicks on both sides.
    if (a.bodyPercent <= _indecisionBodyMax) {
      return a.isBullish
          ? CandleCharacter.bullishIndecision
          : CandleCharacter.bearishIndecision;
    }

    // Moderate directional candle that doesn't fit other categories.
    return a.isBullish ? CandleCharacter.strongBullish : CandleCharacter.strongBearish;
  }

  // ----------------------------------------------------------
  // HEADLINE
  // ----------------------------------------------------------

  static String _buildHeadline(
    CandleCharacter character,
    RejectionLevel upperRej,
    RejectionLevel lowerRej,
  ) {
    switch (character) {
      case CandleCharacter.strongBullish:
        return 'Buyers Dominated';
      case CandleCharacter.strongBearish:
        return 'Sellers Dominated';
      case CandleCharacter.bullishRejection:
        if (upperRej != RejectionLevel.none) {
          return 'Buyers Won, But Faced Resistance';
        }
        return 'Buyers Held After Early Pressure';
      case CandleCharacter.bearishRejection:
        if (lowerRej != RejectionLevel.none) {
          return 'Sellers Won, But Faced Support';
        }
        return 'Sellers Held After Early Pressure';
      case CandleCharacter.bullishIndecision:
        return 'Slight Bullish Lean, Indecisive';
      case CandleCharacter.bearishIndecision:
        return 'Slight Bearish Lean, Indecisive';
      case CandleCharacter.doji:
        return 'Neither Side Won';
      case CandleCharacter.hammer:
        return 'Lower Prices Rejected';
      case CandleCharacter.invertedHammer:
        return 'Buyers Attempted a Push Higher';
      case CandleCharacter.shootingStar:
        return 'Higher Prices Rejected';
      case CandleCharacter.engulfingBullish:
        return 'Buyers Overwhelmed Sellers';
      case CandleCharacter.engulfingBearish:
        return 'Sellers Overwhelmed Buyers';
      case CandleCharacter.neutral:
        return 'Market Showed No Clear Direction';
    }
  }

  // ----------------------------------------------------------
  // NARRATIVE
  // ----------------------------------------------------------

  static String _buildNarrative({
    required CandleCharacter character,
    required CandleAnalytics analytics,
    required VolumeContext volumeCtx,
    required TrendContext trendCtx,
    required MomentumLevel momentum,
    required RejectionLevel upperRej,
    required RejectionLevel lowerRej,
  }) {
    final buf = StringBuffer();

    // Core story based on character.
    buf.write(_coreNarrative(character, analytics));

    // Trend context sentence.
    final trendSentence = _trendSentence(trendCtx, character);
    if (trendSentence != null) {
      buf.write(' $trendSentence');
    }

    // Volume context sentence — only when notably high or low.
    final volumeSentence = _volumeSentence(volumeCtx);
    if (volumeSentence != null) {
      buf.write(' $volumeSentence');
    }

    return buf.toString();
  }

  static String _coreNarrative(CandleCharacter character, CandleAnalytics a) {
    final closeDesc = a.closePosition >= 75
        ? 'near its high'
        : a.closePosition <= 25
            ? 'near its low'
            : 'in the middle of its range';

    switch (character) {
      case CandleCharacter.strongBullish:
        return 'Buying pressure dominated the candle and pushed price strongly higher. '
            'The candle closed $closeDesc, showing that buyers maintained control into the close.';

      case CandleCharacter.strongBearish:
        return 'Selling pressure dominated the candle and pushed price lower. '
            'The candle closed $closeDesc, showing that sellers maintained control into the close.';

      case CandleCharacter.bullishRejection:
        if (a.upperWickPercent >= _significantWick) {
          return 'Buyers pushed price higher, but sellers stepped in near the high '
              'and rejected part of the move. Price still closed above the open, '
              'leaving a bullish candle with noticeable upper rejection.';
        }
        return 'Sellers initially pushed price lower, but buying pressure recovered '
            'most of the decline. Price closed above the open despite the early selling pressure.';

      case CandleCharacter.bearishRejection:
        if (a.lowerWickPercent >= _significantWick) {
          return 'Sellers pushed price lower, but buyers stepped in near the low '
              'and recovered part of the decline. Price still closed below the open, '
              'showing bearish pressure with lower-price rejection.';
        }
        return 'Buyers initially pushed price higher, but selling pressure reversed '
            'most of the move. Price closed below the open despite the early buying attempt.';

      case CandleCharacter.bullishIndecision:
        return 'Price moved in both directions during the candle with a slight bullish lean. '
            'The small body suggests that neither buyers nor sellers established clear control.';

      case CandleCharacter.bearishIndecision:
        return 'Price moved in both directions during the candle with a slight bearish lean. '
            'The small body suggests that neither buyers nor sellers established clear control.';

      case CandleCharacter.doji:
        return 'Price moved in both directions during the candle, but neither side maintained '
            'control. The close remained close to the open, indicating indecision.';

      case CandleCharacter.hammer:
        return 'Sellers pushed price sharply lower, but buying pressure recovered most of '
            'the decline before the close. The long lower wick shows strong rejection of lower prices.';

      case CandleCharacter.invertedHammer:
        return 'Buyers pushed price higher during the candle, but were unable to maintain '
            'the gains. The long upper wick indicates emerging buying interest, though sellers '
            'pushed price back near the open.';

      case CandleCharacter.shootingStar:
        return 'Buyers pushed price sharply higher, but selling pressure rejected the move '
            'and forced price back toward the open. The long upper wick shows rejection of '
            'higher prices.';

      case CandleCharacter.engulfingBullish:
        return 'Buying pressure overwhelmed the previous candle\'s range and pushed price '
            'strongly higher. The bullish engulfing structure indicates a strong shift in '
            'short-term price pressure.';

      case CandleCharacter.engulfingBearish:
        return 'Selling pressure overwhelmed the previous candle\'s range and pushed price '
            'lower. The bearish engulfing structure indicates a strong shift in short-term '
            'price pressure.';

      case CandleCharacter.neutral:
        return 'Price showed limited movement with no clear directional bias. '
            'The candle closed $closeDesc, with neither buyers nor sellers asserting dominance.';
    }
  }

  static String? _trendSentence(TrendContext trend, CandleCharacter character) {
    switch (trend) {
      case TrendContext.uptrend:
        if (character == CandleCharacter.strongBearish ||
            character == CandleCharacter.bearishRejection ||
            character == CandleCharacter.shootingStar ||
            character == CandleCharacter.engulfingBearish) {
          return 'This occurred after a sustained upward move, which may indicate weakening upside momentum.';
        }
        if (character == CandleCharacter.strongBullish ||
            character == CandleCharacter.engulfingBullish) {
          return 'This continues the prevailing upward price trend.';
        }
        return 'This occurred within the context of a broader uptrend.';

      case TrendContext.downtrend:
        if (character == CandleCharacter.strongBullish ||
            character == CandleCharacter.bullishRejection ||
            character == CandleCharacter.hammer ||
            character == CandleCharacter.engulfingBullish) {
          return 'This occurred after a sustained decline, suggesting that buying pressure appeared near the lows.';
        }
        if (character == CandleCharacter.strongBearish ||
            character == CandleCharacter.engulfingBearish) {
          return 'This continues the prevailing downward price trend.';
        }
        return 'This occurred within the context of a broader downtrend.';

      case TrendContext.sideways:
        if (character == CandleCharacter.hammer ||
            character == CandleCharacter.bullishRejection) {
          return 'Price was rejected from the lower part of the recent range.';
        }
        if (character == CandleCharacter.shootingStar ||
            character == CandleCharacter.bearishRejection) {
          return 'Price was rejected from the upper part of the recent range.';
        }
        return null; // Don't add noise for sideways + non-rejection candles.

      case TrendContext.unknown:
        return null;
    }
  }

  static String? _volumeSentence(VolumeContext vol) {
    switch (vol) {
      case VolumeContext.veryHigh:
        return 'Trading volume was significantly above its recent average, indicating unusually strong market activity.';
      case VolumeContext.high:
        return 'Volume was above its recent average, suggesting elevated market participation.';
      case VolumeContext.low:
        return 'The move occurred with below-average volume, suggesting relatively limited participation.';
      case VolumeContext.veryLow:
        return 'Volume was notably thin, indicating very limited market participation.';
      case VolumeContext.average:
        return null; // Average volume is not noteworthy.
    }
  }
}
