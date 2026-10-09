/// Market data provider — live prices and the user's watchlist.
///
/// The all-market ticker stream delivers well over a thousand symbol updates
/// per second. Rebuilding the widget tree on each one would be pathological, so
/// updates are written into a map and listeners are notified on a throttled
/// tick, and only when a symbol the UI actually cares about has moved.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/repositories/watchlist_repository.dart';
import 'package:app/models/instrument.dart'; // Instrument, Timeframe
import 'package:app/services/session.dart';
import 'package:app/services/symbol_registry.dart';

/// Candles fetched for each sparkline. 24 hourly candles is enough to show a
/// day's trend at the tiny size a watchlist row renders it.
const int kSparklineCandleCount = 24;
const Timeframe kSparklineTimeframe = Timeframe.h1;

/// UI refresh cadence for price-driven widgets.
const Duration kPriceFlushInterval = Duration(milliseconds: 250);

/// Seeded when a signed-out user has never picked anything.
const List<String> kDefaultWatchlist = [
  'BTCUSDT',
  'ETHUSDT',
  'SOLUSDT',
  'BNBUSDT',
  'XRPUSDT',
];

class MarketDataProvider extends ChangeNotifier {
  final BinanceProvider _provider;
  final SymbolRegistry _registry;
  final WatchlistRepository _watchlistRepo;
  final SessionProvider _session;
  final Logger _logger;

  /// Latest price for every symbol seen on the stream.
  final Map<String, PriceData> _prices = {};

  /// Symbols whose changes should trigger a UI refresh.
  final Set<String> _interest = {};

  final List<String> _watchlist = [];

  /// Closing prices for each watchlist symbol's sparkline, oldest first.
  final Map<String, List<double>> _sparklines = {};
  final Set<String> _sparklineLoading = {};

  StreamSubscription<PriceUpdate>? _tickerSub;
  Timer? _flushTimer;
  bool _dirty = false;
  bool _isLoading = true;

  MarketDataProvider({
    required BinanceProvider provider,
    required SymbolRegistry registry,
    required WatchlistRepository watchlistRepo,
    required SessionProvider session,
    required Logger logger,
  })  : _provider = provider,
        _registry = registry,
        _watchlistRepo = watchlistRepo,
        _session = session,
        _logger = logger;

  // ==========================================================
  // STATE
  // ==========================================================

  bool get isLoading => _isLoading;
  List<String> get watchlist => List.unmodifiable(_watchlist);
  bool get hasWatchlist => _watchlist.isNotEmpty;

  bool isWatched(String symbol) => _watchlist.contains(symbol.toUpperCase());

  PriceData? priceData(String symbol) => _prices[symbol.toUpperCase()];

  double priceOf(String symbol) => _prices[symbol.toUpperCase()]?.price ?? 0.0;

  double changeOf(String symbol) => _prices[symbol.toUpperCase()]?.change ?? 0.0;

  /// Instruments for the watchlist, in the user's order.
  List<Instrument> get watchlistInstruments =>
      _watchlist.map(_registry.resolve).toList();

  /// Closing-price series for a watchlist sparkline. Empty until loaded.
  List<double> sparklineOf(String symbol) =>
      _sparklines[symbol.toUpperCase()] ?? const [];

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    await _loadWatchlist();
    _startStream();

    // Seed prices immediately; the stream only reports symbols that tick.
    await _seedPrices();

    _isLoading = false;
    notifyListeners();

    // Sparklines are a nice-to-have; fetch them after the essential state is
    // up so they never delay first paint.
    unawaited(_loadSparklines(_watchlist));
  }

  Future<void> _loadSparklines(Iterable<String> symbols) async {
    for (final symbol in symbols) {
      if (_sparklines.containsKey(symbol) || _sparklineLoading.contains(symbol)) {
        continue;
      }
      _sparklineLoading.add(symbol);
      try {
        final candles = await _provider.fetchOHLC(
          symbol,
          kSparklineTimeframe.apiValue,
          limit: kSparklineCandleCount,
        );
        if (candles.isNotEmpty) {
          _sparklines[symbol] = candles.map((c) => c.close).toList();
          _dirty = true;
        }
      } catch (e) {
        _logger.warning('Sparkline fetch failed for $symbol: $e');
      } finally {
        _sparklineLoading.remove(symbol);
      }
    }
  }

  Future<void> _loadWatchlist() async {
    try {
      final stored = await _watchlistRepo.getWatchlist(_session.userId);
      _watchlist
        ..clear()
        ..addAll(stored);

      if (_watchlist.isEmpty) {
        for (final s in kDefaultWatchlist) {
          _watchlist.add(s);
          await _watchlistRepo.addToWatchlist(_session.userId, s);
        }
        _logger.info('Seeded default watchlist');
      }
    } catch (e) {
      _logger.warning('Watchlist load failed, using defaults: $e');
      _watchlist
        ..clear()
        ..addAll(kDefaultWatchlist);
    }
    _interest.addAll(_watchlist);
  }

  Future<void> _seedPrices() async {
    try {
      final snapshot = await _provider.fetchPrices(const []);
      _prices.addAll(snapshot);
    } catch (e) {
      _logger.warning('Initial price snapshot failed: $e');
    }
  }

  void _startStream() {
    _tickerSub?.cancel();
    _tickerSub = _provider.subscribeToPriceUpdates(const [])?.listen(
      _onTick,
      onError: (Object e) => _logger.warning('Ticker error: $e'),
    );

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(kPriceFlushInterval, (_) {
      if (!_dirty) return;
      _dirty = false;
      notifyListeners();
    });
  }

  void _onTick(PriceUpdate update) {
    final symbol = update.symbol;
    final previous = _prices[symbol];
    _prices[symbol] = update.toPriceData();

    // Nudge the sparkline's last point live so it doesn't look frozen between
    // hourly candle refreshes. This does not change the candle count.
    final series = _sparklines[symbol];
    if (series != null && series.isNotEmpty) {
      series[series.length - 1] = update.price;
    }

    // Only schedule a rebuild for symbols currently on screen.
    if (!_interest.contains(symbol)) return;
    if (previous != null &&
        previous.price == update.price &&
        previous.change == update.change) {
      return;
    }
    _dirty = true;
  }

  // ==========================================================
  // INTEREST TRACKING
  // ==========================================================

  /// Register symbols whose updates should refresh the UI. Screens showing
  /// long lists call this so off-screen symbols cannot cause rebuilds.
  void setInterest(Iterable<String> symbols) {
    _interest
      ..clear()
      ..addAll(_watchlist)
      ..addAll(symbols.map((s) => s.toUpperCase()));
  }

  void addInterest(String symbol) => _interest.add(symbol.toUpperCase());

  // ==========================================================
  // WATCHLIST MUTATIONS
  // ==========================================================

  Future<void> addToWatchlist(String symbol) async {
    final upper = symbol.toUpperCase();
    if (_watchlist.contains(upper)) return;

    _watchlist.add(upper);
    _interest.add(upper);
    notifyListeners();
    unawaited(_loadSparklines([upper]));

    try {
      await _watchlistRepo.addToWatchlist(_session.userId, upper);
    } catch (e) {
      _logger.warning('Watchlist add failed: $e');
    }
  }

  Future<void> removeFromWatchlist(String symbol) async {
    final upper = symbol.toUpperCase();
    if (!_watchlist.remove(upper)) return;
    notifyListeners();

    try {
      await _watchlistRepo.removeFromWatchlist(_session.userId, upper);
    } catch (e) {
      _logger.warning('Watchlist remove failed: $e');
    }
  }

  Future<void> toggleWatchlist(String symbol) =>
      isWatched(symbol) ? removeFromWatchlist(symbol) : addToWatchlist(symbol);

  /// [newIndex] is expected to be already adjusted for the removal of the item
  /// at [oldIndex], which is what `ReorderableListView.onReorderItem` provides.
  Future<void> reorderWatchlist(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _watchlist.length) return;

    final moved = _watchlist.removeAt(oldIndex);
    final target = newIndex.clamp(0, _watchlist.length);
    _watchlist.insert(target, moved);
    notifyListeners();

    try {
      await _watchlistRepo.reorder(_session.userId, _watchlist);
    } catch (e) {
      // Ordering is cosmetic; a failure here should not surface to the user.
      _logger.warning('Watchlist reorder failed: $e');
    }
  }

  /// Re-read the watchlist, e.g. after a cloud sync-down on sign-in.
  Future<void> reloadWatchlist() async {
    await _loadWatchlist();
    notifyListeners();
    unawaited(_loadSparklines(_watchlist));
  }

  /// Replace the entire watchlist with [newWatchlist] (e.g. from onboarding/settings).
  Future<void> replaceWatchlist(List<String> newWatchlist) async {
    final upperList = newWatchlist
        .map((s) => s.toUpperCase().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (upperList.isEmpty) return;

    _watchlist
      ..clear()
      ..addAll(upperList);
    _interest
      ..clear()
      ..addAll(upperList);
    notifyListeners();
    unawaited(_loadSparklines(upperList));

    try {
      await _watchlistRepo.clearWatchlist(_session.userId);
      for (final symbol in upperList) {
        await _watchlistRepo.addToWatchlist(_session.userId, symbol);
      }
    } catch (e) {
      _logger.warning('Watchlist replace failed: $e');
    }
  }

  @override
  void dispose() {
    _tickerSub?.cancel();
    _flushTimer?.cancel();
    super.dispose();
  }
}
