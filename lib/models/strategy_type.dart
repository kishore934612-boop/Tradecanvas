/// Educational Strategy Overlays models and settings.
library;

enum StrategyType {
  supportBounce,
  resistanceRejection,
  emaCrossover,
  bollingerReversal,
  rsiExtreme,
  orderBlockRetest,
  fvgFillRejection,
  engulfing,
  macdDivergence;

  String get label {
    switch (this) {
      case StrategyType.supportBounce:
        return 'Support Bounce';
      case StrategyType.resistanceRejection:
        return 'Resistance Rejection';
      case StrategyType.emaCrossover:
        return 'EMA Crossover';
      case StrategyType.bollingerReversal:
        return 'Bollinger Reversal';
      case StrategyType.rsiExtreme:
        return 'RSI Overbought/Oversold';
      case StrategyType.orderBlockRetest:
        return 'Order Block Retest';
      case StrategyType.fvgFillRejection:
        return 'Fair Value Gap Fill';
      case StrategyType.engulfing:
        return 'Engulfing Pattern';
      case StrategyType.macdDivergence:
        return 'MACD Divergence';
    }
  }

  String get shortLabel {
    switch (this) {
      case StrategyType.supportBounce:
        return 'Bounce';
      case StrategyType.resistanceRejection:
        return 'Reject';
      case StrategyType.emaCrossover:
        return 'EMA Cross';
      case StrategyType.bollingerReversal:
        return 'BB Rev';
      case StrategyType.rsiExtreme:
        return 'RSI';
      case StrategyType.orderBlockRetest:
        return 'OB Retest';
      case StrategyType.fvgFillRejection:
        return 'FVG Fill';
      case StrategyType.engulfing:
        return 'Engulf';
      case StrategyType.macdDivergence:
        return 'MACD Div';
    }
  }

  String get description {
    switch (this) {
      case StrategyType.supportBounce:
        return 'Identifies potential bullish bounces off recent key support levels.';
      case StrategyType.resistanceRejection:
        return 'Identifies potential bearish price rejections from key resistance levels.';
      case StrategyType.emaCrossover:
        return 'Highlights trend momentum changes when fast EMA crosses slow EMA.';
      case StrategyType.bollingerReversal:
        return 'Detects candles closing outside Bollinger Bands followed by reversal confirmation.';
      case StrategyType.rsiExtreme:
        return 'Flags recovery out of oversold or overbought zones after a closed candle.';
      case StrategyType.orderBlockRetest:
        return 'Highlights the first confirmed retest of an unbroken demand or supply zone; not evidence of institutional activity.';
      case StrategyType.fvgFillRejection:
        return 'Flags trade setups when price fills a Fair Value Gap (price imbalance) and confirms directional momentum.';
      case StrategyType.engulfing:
        return 'Detects bullish and bearish engulfing candlestick patterns signaling potential price reversals.';
      case StrategyType.macdDivergence:
        return 'Identifies divergences between price action and MACD histogram, flagging momentum shifts.';
    }
  }

  static StrategyType fromId(String id) => StrategyType.values.firstWhere(
        (s) => s.name == id,
        orElse: () => StrategyType.supportBounce,
      );
}

/// Strategy Overlay Settings model.
class StrategySettings {
  final bool enableLabels;
  final bool enableArrows;
  final double arrowSize;
  final double labelSize;
  final double signalOpacity;
  final int maxVisibleSignals;
  final bool strictConfirmation;
  final int cooldownBars;
  final bool requireVolumeConfirmation;
  final double volumeMultiplier;
  final double rsiUpperLevel;
  final double rsiLowerLevel;
  final int emaFastPeriod;
  final int emaSlowPeriod;

  const StrategySettings({
    this.enableLabels = true,
    this.enableArrows = true,
    this.arrowSize = 12.0,
    this.labelSize = 10.0,
    this.signalOpacity = 1.0,
    this.maxVisibleSignals = 50,
    this.strictConfirmation = true,
    this.cooldownBars = 3,
    this.requireVolumeConfirmation = false,
    this.volumeMultiplier = 1.5,
    this.rsiUpperLevel = 70.0,
    this.rsiLowerLevel = 30.0,
    this.emaFastPeriod = 20,
    this.emaSlowPeriod = 50,
  });

  bool get isValid => emaFastPeriod > 0 && emaSlowPeriod > emaFastPeriod &&
      emaSlowPeriod <= 1000 && maxVisibleSignals >= 0 && cooldownBars >= 0 &&
      rsiLowerLevel.isFinite && rsiUpperLevel.isFinite && rsiLowerLevel > 0 &&
      rsiLowerLevel < rsiUpperLevel && rsiUpperLevel < 100 &&
      volumeMultiplier.isFinite && volumeMultiplier > 0;

  StrategySettings copyWith({
    bool? enableLabels,
    bool? enableArrows,
    double? arrowSize,
    double? labelSize,
    double? signalOpacity,
    int? maxVisibleSignals,
    bool? strictConfirmation,
    int? cooldownBars,
    bool? requireVolumeConfirmation,
    double? volumeMultiplier,
    double? rsiUpperLevel,
    double? rsiLowerLevel,
    int? emaFastPeriod,
    int? emaSlowPeriod,
  }) {
    return StrategySettings(
      enableLabels: enableLabels ?? this.enableLabels,
      enableArrows: enableArrows ?? this.enableArrows,
      arrowSize: arrowSize ?? this.arrowSize,
      labelSize: labelSize ?? this.labelSize,
      signalOpacity: signalOpacity ?? this.signalOpacity,
      maxVisibleSignals: maxVisibleSignals ?? this.maxVisibleSignals,
      strictConfirmation: strictConfirmation ?? this.strictConfirmation,
      cooldownBars: cooldownBars ?? this.cooldownBars,
      requireVolumeConfirmation: requireVolumeConfirmation ?? this.requireVolumeConfirmation,
      volumeMultiplier: volumeMultiplier ?? this.volumeMultiplier,
      rsiUpperLevel: rsiUpperLevel ?? this.rsiUpperLevel,
      rsiLowerLevel: rsiLowerLevel ?? this.rsiLowerLevel,
      emaFastPeriod: emaFastPeriod ?? this.emaFastPeriod,
      emaSlowPeriod: emaSlowPeriod ?? this.emaSlowPeriod,
    );
  }

  Map<String, dynamic> toJson() => {
        'enableLabels': enableLabels,
        'enableArrows': enableArrows,
        'arrowSize': arrowSize,
        'labelSize': labelSize,
        'signalOpacity': signalOpacity,
        'maxVisibleSignals': maxVisibleSignals,
        'strictConfirmation': strictConfirmation,
        'cooldownBars': cooldownBars,
        'requireVolumeConfirmation': requireVolumeConfirmation,
        'volumeMultiplier': volumeMultiplier,
        'rsiUpperLevel': rsiUpperLevel,
        'rsiLowerLevel': rsiLowerLevel,
        'emaFastPeriod': emaFastPeriod,
        'emaSlowPeriod': emaSlowPeriod,
      };

  factory StrategySettings.fromJson(Map<String, dynamic> j) => StrategySettings(
        enableLabels: j['enableLabels'] as bool? ?? true,
        enableArrows: j['enableArrows'] as bool? ?? true,
        arrowSize: (j['arrowSize'] as num?)?.toDouble() ?? 12.0,
        labelSize: (j['labelSize'] as num?)?.toDouble() ?? 10.0,
        signalOpacity: (j['signalOpacity'] as num?)?.toDouble() ?? 1.0,
        maxVisibleSignals: (j['maxVisibleSignals'] as num?)?.toInt() ?? 50,
        strictConfirmation: j['strictConfirmation'] as bool? ?? true,
        cooldownBars: (j['cooldownBars'] as num?)?.toInt() ?? 3,
        requireVolumeConfirmation: j['requireVolumeConfirmation'] as bool? ?? false,
        volumeMultiplier: (j['volumeMultiplier'] as num?)?.toDouble() ?? 1.5,
        rsiUpperLevel: (j['rsiUpperLevel'] as num?)?.toDouble() ?? 70.0,
        rsiLowerLevel: (j['rsiLowerLevel'] as num?)?.toDouble() ?? 30.0,
        emaFastPeriod: (j['emaFastPeriod'] as num?)?.toInt() ?? 20,
        emaSlowPeriod: (j['emaSlowPeriod'] as num?)?.toInt() ?? 50,
      );
}

/// Individual Strategy Signal Marker detected on the chart.
class StrategySignal {
  final String id;
  final StrategyType strategy;
  final int timestamp;
  final int candleIndex;
  final double price;
  final bool isBuy;
  final String title;
  final String shortTag;
  final String explanation;

  const StrategySignal({
    required this.id,
    required this.strategy,
    required this.timestamp,
    required this.candleIndex,
    required this.price,
    required this.isBuy,
    required this.title,
    required this.shortTag,
    required this.explanation,
  });
}
