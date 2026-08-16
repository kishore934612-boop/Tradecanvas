/// Chart data source — the contract [ChartView] and [IndicatorSheet] render
/// against.
///
/// [ChartController] (live data) and [ReplayController] (historical
/// bar-by-bar playback) both implement this, so the same rendering, gesture
/// and drawing pipeline works unmodified for both live charts and Replay Mode.
library;

import 'package:flutter/foundation.dart';

import 'package:app/domain/entities/candle_data.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/instrument.dart';

abstract class ChartDataSource implements Listenable {
  Instrument get instrument;
  Timeframe get timeframe;

  /// Currently visible candle set, oldest first.
  List<CandleData> get candles;

  ChartIndicators get indicators;
  Set<IndicatorType> get enabledIndicators;

  /// Most recent close, used for the price header when no live tick is newer.
  double get lastPrice;

  bool get isLoading;
  bool get isLoadingHistory;
  bool get hasMoreHistory;
  String? get error;
  bool get hasData;

  bool get showVolume;
  bool get showMacd;

  bool isIndicatorEnabled(IndicatorType t);
  void toggleIndicator(IndicatorType t);
  void setIndicators(Set<IndicatorType> next);

  /// Page in older candles when panning reaches the left edge. A no-op source
  /// (e.g. replay, which already holds its full bounded window) may complete
  /// immediately without changing [hasMoreHistory].
  Future<void> loadMoreHistory();

  /// Re-fetch from scratch, e.g. after an error.
  Future<void> refresh();

  /// Highest and lowest price across an index range, used for autoscaling.
  ({double min, double max}) priceRange(int fromIndex, int toIndex);
}
