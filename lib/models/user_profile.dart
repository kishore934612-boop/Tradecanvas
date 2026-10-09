/// User preferences for Charty.
///
/// Charting preferences only. The previous trading-onboarding fields
/// (experience, style, starting capital, journal prompts) are gone.
/// Grid visibility preference.
enum GridVisibilityPref { show, hide }

extension GridVisibilityPrefX on GridVisibilityPref {
  String get label {
    switch (this) {
      case GridVisibilityPref.show:
        return 'Show Grid';
      case GridVisibilityPref.hide:
        return 'Hide Grid';
    }
  }

  static GridVisibilityPref fromId(String? id) {
    if (id == 'hide') return GridVisibilityPref.hide;
    return GridVisibilityPref.show;
  }
}

/// Grid line style options.
enum GridStylePref { solid, dashed, dots }

extension GridStylePrefX on GridStylePref {
  String get label {
    switch (this) {
      case GridStylePref.solid:
        return 'Solid';
      case GridStylePref.dashed:
        return 'Dashed';
      case GridStylePref.dots:
        return 'Dotted';
    }
  }

  static GridStylePref fromId(String? id) {
    switch (id) {
      case 'solid':
        return GridStylePref.solid;
      case 'dots':
        return GridStylePref.dots;
      default:
        return GridStylePref.dashed;
    }
  }
}

/// Grid line density options.
enum GridDensityPref { fine, medium, coarse }

extension GridDensityPrefX on GridDensityPref {
  String get label {
    switch (this) {
      case GridDensityPref.fine:
        return 'Fine';
      case GridDensityPref.medium:
        return 'Medium';
      case GridDensityPref.coarse:
        return 'Coarse';
    }
  }

  static GridDensityPref fromId(String? id) {
    switch (id) {
      case 'fine':
        return GridDensityPref.fine;
      case 'coarse':
        return GridDensityPref.coarse;
      default:
        return GridDensityPref.medium;
    }
  }
}

/// Crosshair behavior mode.
enum CrosshairMode { free, magnet, locked }

extension CrosshairModeX on CrosshairMode {
  String get label {
    switch (this) {
      case CrosshairMode.free:
        return 'Free';
      case CrosshairMode.magnet:
        return 'Magnet';
      case CrosshairMode.locked:
        return 'Locked';
    }
  }

  CrosshairMode get next {
    switch (this) {
      case CrosshairMode.free:
        return CrosshairMode.magnet;
      case CrosshairMode.magnet:
        return CrosshairMode.locked;
      case CrosshairMode.locked:
        return CrosshairMode.free;
    }
  }

  static CrosshairMode fromId(String? id) {
    switch (id) {
      case 'magnet':
        return CrosshairMode.magnet;
      case 'locked':
        return CrosshairMode.locked;
      default:
        return CrosshairMode.free;
    }
  }
}


/// Chart rendering style preference (5 chart types).
enum ChartTypePref { candles, line, baseline, area, volumeCandles }

extension ChartTypePrefX on ChartTypePref {
  String get label {
    switch (this) {
      case ChartTypePref.candles:
        return 'Candles';
      case ChartTypePref.line:
        return 'Line';
      case ChartTypePref.baseline:
        return 'Baseline';
      case ChartTypePref.area:
        return 'Area';
      case ChartTypePref.volumeCandles:
        return 'Volume Candles';
    }
  }

  static ChartTypePref fromId(String? id) {
    switch (id) {
      case 'line':
        return ChartTypePref.line;
      case 'baseline':
        return ChartTypePref.baseline;
      case 'area':
        return ChartTypePref.area;
      case 'volumeCandles':
        return ChartTypePref.volumeCandles;
      default:
        return ChartTypePref.candles;
    }
  }
}



class UserProfile {
  bool onboarded;

  /// Trader persona selected during onboarding (e.g. Scalp, Intraday, Swing, Position)
  String traderType;

  /// User's favorite coins selected during onboarding (up to 5)
  List<String> favoriteCoins;

  /// Timeframe a chart opens on when the symbol has no saved preference.
  /// Stored as a Binance interval string, e.g. `1h`.
  String defaultTimeframe;

  ChartTypePref chartType;
  GridVisibilityPref gridVisibility;
  GridStylePref gridStyle;
  GridDensityPref gridDensity;

  /// Custom candle colors ARGB integer values.
  int customBullishColorValue;
  int customBearishColorValue;

  bool hapticsEnabled;

  /// Show the volume panel by default.
  bool showVolume;

  /// Indicator names enabled by default, matching `IndicatorType.name`.
  Set<String> defaultIndicators;

  /// Up to 3 drawing tool names (matching `DrawingTool.name`) surfaced as
  /// one-tap buttons on the chart's quick-action toolbar.
  List<String> favoriteDrawingTools;

  /// Right offset (empty space / future margin) as a percentage of chart width (e.g. 20.0 for 20%)
  double rightOffsetPercent;

  /// Crosshair behavior mode: free, magnet (snap to OHLC), locked (snap to close).
  CrosshairMode crosshairMode;

  /// Whether to show price/time labels on the crosshair.
  bool crosshairShowLabels;

  /// Whether to auto-scale the price axis to visible candles.
  bool autoScale;

  /// When true, chart zoom and pan are disabled.
  bool chartLocked;

  /// User-placed horizontal price markers.
  List<double> customPriceLines;

  double get rightOffsetFraction =>
      (rightOffsetPercent / 100.0).clamp(0.0, 0.50);

  UserProfile({
    this.onboarded = false,
    this.traderType = 'Intraday Trader',
    List<String>? favoriteCoins,
    this.defaultTimeframe = '1h',
    this.chartType = ChartTypePref.candles,
    this.gridVisibility = GridVisibilityPref.show,
    this.gridStyle = GridStylePref.dashed,
    this.gridDensity = GridDensityPref.medium,
    this.customBullishColorValue = 0xFF22C55E, // Neon Green
    this.customBearishColorValue = 0xFFEF4444, // Crimson Red
    this.hapticsEnabled = true,
    this.showVolume = true,
    this.rightOffsetPercent = 20.0,
    Set<String>? defaultIndicators,
    List<String>? favoriteDrawingTools,
    this.crosshairMode = CrosshairMode.free,
    this.crosshairShowLabels = true,
    this.autoScale = true,
    this.chartLocked = false,
    List<double>? customPriceLines,
  })  : favoriteCoins = favoriteCoins ?? const ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'],
        defaultIndicators = defaultIndicators ?? {'volume'},
        favoriteDrawingTools =
            favoriteDrawingTools ?? ['trendline', 'horizontalLine', 'rectangle'],
        customPriceLines = customPriceLines ?? [];

  Map<String, dynamic> toJson() => {
        'onboarded': onboarded,
        'traderType': traderType,
        'favoriteCoins': favoriteCoins,
        'defaultTimeframe': defaultTimeframe,
        'chartType': chartType.name,
        'gridVisibility': gridVisibility.name,
        'gridStyle': gridStyle.name,
        'gridDensity': gridDensity.name,
        'customBullishColorValue': customBullishColorValue,
        'customBearishColorValue': customBearishColorValue,
        'hapticsEnabled': hapticsEnabled,
        'showVolume': showVolume,
        'rightOffsetPercent': rightOffsetPercent,
        'defaultIndicators': defaultIndicators.toList(),
        'favoriteDrawingTools': favoriteDrawingTools,
        'crosshairMode': crosshairMode.name,
        'crosshairShowLabels': crosshairShowLabels,
        'autoScale': autoScale,
        'chartLocked': chartLocked,
        'customPriceLines': customPriceLines,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        onboarded: j['onboarded'] as bool? ?? false,
        traderType: j['traderType'] as String? ?? 'Intraday Trader',
        favoriteCoins: (j['favoriteCoins'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'],
        defaultTimeframe: j['defaultTimeframe'] as String? ?? '1h',
        chartType: ChartTypePrefX.fromId(j['chartType'] as String?),
        gridVisibility:
            GridVisibilityPrefX.fromId(j['gridVisibility'] as String?),
        gridStyle: GridStylePrefX.fromId(j['gridStyle'] as String?),
        gridDensity: GridDensityPrefX.fromId(j['gridDensity'] as String?),
        customBullishColorValue:
            j['customBullishColorValue'] as int? ?? 0xFF22C55E,
        customBearishColorValue:
            j['customBearishColorValue'] as int? ?? 0xFFEF4444,
        hapticsEnabled: j['hapticsEnabled'] as bool? ?? true,
        showVolume: j['showVolume'] as bool? ?? true,
        rightOffsetPercent: (j['rightOffsetPercent'] as num?)?.toDouble() ?? 20.0,
        defaultIndicators: j['defaultIndicators'] != null
            ? Set<String>.from(j['defaultIndicators'] as List)
            : {'volume'},
        favoriteDrawingTools: j['favoriteDrawingTools'] != null
            ? List<String>.from(j['favoriteDrawingTools'] as List)
            : ['trendline', 'horizontalLine', 'rectangle'],
        crosshairMode:
            CrosshairModeX.fromId(j['crosshairMode'] as String?),
        crosshairShowLabels: j['crosshairShowLabels'] as bool? ?? true,
        autoScale: j['autoScale'] as bool? ?? true,
        chartLocked: j['chartLocked'] as bool? ?? false,
        customPriceLines: (j['customPriceLines'] as List<dynamic>?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
      );
}
