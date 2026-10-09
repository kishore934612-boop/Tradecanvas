/// Smart Money Concepts (SMC) Overlay models, settings, and structure entities.
library;

enum SmcType {
  breakout,
  fvg,
  orderBlock,
  liquiditySweep,
  bos,
  choch,
  equalLevel;

  String get label {
    switch (this) {
      case SmcType.breakout:
        return 'Breakout';
      case SmcType.fvg:
        return 'Fair Value Gap (FVG)';
      case SmcType.orderBlock:
        return 'Order Blocks';
      case SmcType.liquiditySweep:
        return 'Liquidity Sweeps';
      case SmcType.bos:
        return 'Break of Structure (BOS)';
      case SmcType.choch:
        return 'Change of Character (CHoCH)';
      case SmcType.equalLevel:
        return 'Equal Highs / Lows (EQH/EQL)';
    }
  }

  String get shortLabel {
    switch (this) {
      case SmcType.breakout:
        return 'Breakout';
      case SmcType.fvg:
        return 'FVG';
      case SmcType.orderBlock:
        return 'OB';
      case SmcType.liquiditySweep:
        return 'Sweep';
      case SmcType.bos:
        return 'BOS';
      case SmcType.choch:
        return 'CHoCH';
      case SmcType.equalLevel:
        return 'EQH/EQL';
    }
  }

  String get description {
    switch (this) {
      case SmcType.breakout:
        return 'Highlights price breaking out of key support or resistance consolidation levels.';
      case SmcType.fvg:
        return 'Detects 3-candle price imbalances and efficiency gaps in market structure.';
      case SmcType.orderBlock:
        return 'Identifies institutional order blocks preceding strong price displacement.';
      case SmcType.liquiditySweep:
        return 'Highlights liquidity grabs where price wicks beyond key swing levels.';
      case SmcType.bos:
        return 'Highlights confirmed trend continuation closes beyond previous swing points.';
      case SmcType.choch:
        return 'Flags early market structure trend reversals breaking last key swing points.';
      case SmcType.equalLevel:
        return 'Detects equal highs and equal lows forming liquidity pools that smart money may target.';
    }
  }

  static SmcType fromId(String id) => SmcType.values.firstWhere(
        (s) => s.name == id,
        orElse: () => SmcType.breakout,
      );
}

enum SmcVisualizationMode {
  minimal,
  balanced,
  detailed;

  String get label {
    switch (this) {
      case SmcVisualizationMode.minimal:
        return 'Minimal';
      case SmcVisualizationMode.balanced:
        return 'Balanced (Default)';
      case SmcVisualizationMode.detailed:
        return 'Detailed';
    }
  }

  String get description {
    switch (this) {
      case SmcVisualizationMode.minimal:
        return 'Shows only the latest key BOS, Order Block, FVG, and Sweep.';
      case SmcVisualizationMode.balanced:
        return 'TradingView standard: max 3 Breakouts, 5 OBs, 5 FVGs, 3 Sweeps.';
      case SmcVisualizationMode.detailed:
        return 'Displays all valid detected structures on the chart.';
    }
  }

  static SmcVisualizationMode fromId(String id) =>
      SmcVisualizationMode.values.firstWhere(
        (v) => v.name == id,
        orElse: () => SmcVisualizationMode.balanced,
      );
}

/// SMC Overlay Settings model.
class SmcSettings {
  final double opacity;
  final int maxVisibleStructures;
  final bool hideMitigatedFvg;
  final bool hideMitigatedOb;
  final int swingSensitivity;
  final int lookbackBars;
  final double minBreakoutPct;
  final SmcVisualizationMode visualizationMode;
  final bool mergeOverlappingZones;
  final bool enableCollisionAvoidance;

  const SmcSettings({
    this.opacity = 0.85,
    this.maxVisibleStructures = 40,
    this.hideMitigatedFvg = false,
    this.hideMitigatedOb = false,
    this.swingSensitivity = 5,
    this.lookbackBars = 100,
    this.minBreakoutPct = 0.002,
    this.visualizationMode = SmcVisualizationMode.balanced,
    this.mergeOverlappingZones = true,
    this.enableCollisionAvoidance = true,
  });

  SmcSettings copyWith({
    double? opacity,
    int? maxVisibleStructures,
    bool? hideMitigatedFvg,
    bool? hideMitigatedOb,
    int? swingSensitivity,
    int? lookbackBars,
    double? minBreakoutPct,
    SmcVisualizationMode? visualizationMode,
    bool? mergeOverlappingZones,
    bool? enableCollisionAvoidance,
  }) {
    return SmcSettings(
      opacity: opacity ?? this.opacity,
      maxVisibleStructures: maxVisibleStructures ?? this.maxVisibleStructures,
      hideMitigatedFvg: hideMitigatedFvg ?? this.hideMitigatedFvg,
      hideMitigatedOb: hideMitigatedOb ?? this.hideMitigatedOb,
      swingSensitivity: swingSensitivity ?? this.swingSensitivity,
      lookbackBars: lookbackBars ?? this.lookbackBars,
      minBreakoutPct: minBreakoutPct ?? this.minBreakoutPct,
      visualizationMode: visualizationMode ?? this.visualizationMode,
      mergeOverlappingZones:
          mergeOverlappingZones ?? this.mergeOverlappingZones,
      enableCollisionAvoidance:
          enableCollisionAvoidance ?? this.enableCollisionAvoidance,
    );
  }

  Map<String, dynamic> toJson() => {
        'opacity': opacity,
        'maxVisibleStructures': maxVisibleStructures,
        'hideMitigatedFvg': hideMitigatedFvg,
        'hideMitigatedOb': hideMitigatedOb,
        'swingSensitivity': swingSensitivity,
        'lookbackBars': lookbackBars,
        'minBreakoutPct': minBreakoutPct,
        'visualizationMode': visualizationMode.name,
        'mergeOverlappingZones': mergeOverlappingZones,
        'enableCollisionAvoidance': enableCollisionAvoidance,
      };

  factory SmcSettings.fromJson(Map<String, dynamic> j) => SmcSettings(
        opacity: (j['opacity'] as num?)?.toDouble() ?? 0.85,
        maxVisibleStructures:
            (j['maxVisibleStructures'] as num?)?.toInt() ?? 40,
        hideMitigatedFvg: j['hideMitigatedFvg'] as bool? ?? false,
        hideMitigatedOb: j['hideMitigatedOb'] as bool? ?? false,
        swingSensitivity: (j['swingSensitivity'] as num?)?.toInt() ?? 5,
        lookbackBars: (j['lookbackBars'] as num?)?.toInt() ?? 100,
        minBreakoutPct: (j['minBreakoutPct'] as num?)?.toDouble() ?? 0.002,
        visualizationMode: SmcVisualizationMode.fromId(
            j['visualizationMode'] as String? ?? 'balanced'),
        mergeOverlappingZones: j['mergeOverlappingZones'] as bool? ?? true,
        enableCollisionAvoidance:
            j['enableCollisionAvoidance'] as bool? ?? true,
      );
}

/// An individual detected Smart Money Concepts market structure element.
class SmcStructure {
  final String id;
  final SmcType type;
  final int timestamp;
  final int? endTimestamp;
  final double price; // Primary reference price (e.g. level, FVG top/bottom, OB price)
  final double secondaryPrice; // Secondary price for zones (e.g. FVG bottom/top, OB low)
  final bool isBullish;
  final String title;
  final String description;
  final bool isMitigated;
  final int? mitigatedTimestamp;
  final bool isMerged;

  const SmcStructure({
    required this.id,
    required this.type,
    required this.timestamp,
    this.endTimestamp,
    required this.price,
    this.secondaryPrice = 0.0,
    required this.isBullish,
    required this.title,
    required this.description,
    this.isMitigated = false,
    this.mitigatedTimestamp,
    this.isMerged = false,
  });

  SmcStructure copyWith({
    bool? isMitigated,
    int? mitigatedTimestamp,
    int? endTimestamp,
    bool? isMerged,
  }) {
    return SmcStructure(
      id: id,
      type: type,
      timestamp: timestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      price: price,
      secondaryPrice: secondaryPrice,
      isBullish: isBullish,
      title: title,
      description: description,
      isMitigated: isMitigated ?? this.isMitigated,
      mitigatedTimestamp: mitigatedTimestamp ?? this.mitigatedTimestamp,
      isMerged: isMerged ?? this.isMerged,
    );
  }
}

/// Market trend direction derived from BOS / CHoCH analysis.
enum SmcTrendDirection {
  bullish,
  bearish,
  ranging;

  String get label {
    switch (this) {
      case SmcTrendDirection.bullish:
        return 'Bullish';
      case SmcTrendDirection.bearish:
        return 'Bearish';
      case SmcTrendDirection.ranging:
        return 'Ranging';
    }
  }

  String get icon {
    switch (this) {
      case SmcTrendDirection.bullish:
        return '▲';
      case SmcTrendDirection.bearish:
        return '▼';
      case SmcTrendDirection.ranging:
        return '◆';
    }
  }
}

/// Multi-timeframe SMC trend summary used by the MTF dashboard HUD.
class SmcTrend {
  final SmcTrendDirection direction;
  final SmcStructure? lastBos;
  final SmcStructure? lastChoch;
  final SmcStructure? nearestFvg;
  final SmcStructure? nearestOb;
  final double? buyLiquidityTarget;
  final double? sellLiquidityTarget;

  const SmcTrend({
    required this.direction,
    this.lastBos,
    this.lastChoch,
    this.nearestFvg,
    this.nearestOb,
    this.buyLiquidityTarget,
    this.sellLiquidityTarget,
  });

  static const SmcTrend empty = SmcTrend(direction: SmcTrendDirection.ranging);
}
