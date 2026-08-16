/// Vertical band layout for the chart and sub-panels.
library;

class ChartLayout {
  /// Full canvas size.
  final double width;
  final double height;

  /// Right-hand gutter reserved for price labels.
  final double priceAxisWidth;

  /// Bottom strip reserved for time labels.
  final double timeAxisHeight;

  final double volumeHeight;
  final double macdHeight;
  final double rsiHeight;
  final double atrHeight;
  final double stochRsiHeight;

  const ChartLayout({
    required this.width,
    required this.height,
    this.priceAxisWidth = 62.0,
    this.timeAxisHeight = 20.0,
    this.volumeHeight = 0.0,
    this.macdHeight = 0.0,
    this.rsiHeight = 0.0,
    this.atrHeight = 0.0,
    this.stochRsiHeight = 0.0,
  });

  factory ChartLayout.forPanels({
    required double width,
    required double height,
    bool showVolume = false,
    bool showMacd = false,
    bool showRsi = false,
    bool showAtr = false,
    bool showStochRsi = false,
  }) {
    return ChartLayout(
      width: width,
      height: height,
      volumeHeight: showVolume ? 40.0 : 0.0,
      macdHeight: showMacd ? 55.0 : 0.0,
      rsiHeight: showRsi ? 50.0 : 0.0,
      atrHeight: showAtr ? 45.0 : 0.0,
      stochRsiHeight: showStochRsi ? 50.0 : 0.0,
    );
  }

  double get subPanelsHeight =>
      volumeHeight + macdHeight + rsiHeight + atrHeight + stochRsiHeight;

  /// Plot width, excluding the price gutter.
  double get plotWidth => (width - priceAxisWidth).clamp(0.0, double.infinity);

  /// Height available to all panels, excluding the time axis.
  double get panelsHeight =>
      (height - timeAxisHeight).clamp(0.0, double.infinity);

  /// Height of the price (candle) panel.
  double get priceHeight =>
      (panelsHeight - subPanelsHeight).clamp(0.0, double.infinity);

  double get volumeTop => priceHeight;
  double get macdTop => volumeTop + volumeHeight;
  double get rsiTop => macdTop + macdHeight;
  double get atrTop => rsiTop + rsiHeight;
  double get stochRsiTop => atrTop + atrHeight;
  double get timeAxisTop => panelsHeight;

  bool get isUsable => plotWidth > 20 && priceHeight > 40;
}
