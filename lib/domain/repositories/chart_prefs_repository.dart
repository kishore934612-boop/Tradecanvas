/// Per-symbol chart preferences, so a chart reopens as the user left it.
library;

class ChartPrefs {
  final String symbol;

  /// Binance interval string, e.g. `1h`.
  final String timeframe;

  /// `candles` or `area`.
  final String chartType;

  /// Enabled indicator names, matching `IndicatorType.name`.
  final List<String> indicators;

  const ChartPrefs({
    required this.symbol,
    required this.timeframe,
    this.chartType = 'candles',
    this.indicators = const [],
  });
}

abstract class ChartPrefsRepository {
  Future<ChartPrefs?> get(String symbol);
  Future<void> save(ChartPrefs prefs);
}
