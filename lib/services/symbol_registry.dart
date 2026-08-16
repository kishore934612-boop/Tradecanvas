/// Symbol registry — the searchable universe of instruments.
///
/// Loads from disk cache first so the UI is never blocked on the network, then
/// refreshes from `exchangeInfo` in the background. Volume data arrives later
/// via ticker snapshots and is used to rank search results by liquidity.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/models/instrument.dart';
import 'package:app/services/persistence/persistence_service.dart';

class SymbolRegistry extends ChangeNotifier {
  static const String _cacheKey = '@charty_symbols_v1';
  static const String _cacheStampKey = '@charty_symbols_ts_v1';

  /// Refresh the symbol list at most once a day; listings change rarely.
  static const Duration _maxCacheAge = Duration(hours: 24);

  /// Quote assets surfaced in the UI. Binance lists hundreds of pairs against
  /// obscure quotes; these are the ones worth charting.
  static const List<String> preferredQuotes = [
    'USDT',
  ];

  final BinanceProvider _provider;
  final PersistenceService _persistence;
  final Logger _logger;

  final Map<String, Instrument> _bySymbol = {};
  bool _isLoading = false;
  bool _isReady = false;
  String? _error;

  SymbolRegistry({
    required BinanceProvider provider,
    required PersistenceService persistence,
    required Logger logger,
  })  : _provider = provider,
        _persistence = persistence,
        _logger = logger;

  bool get isLoading => _isLoading;
  bool get isReady => _isReady;
  String? get error => _error;
  int get count => _bySymbol.length;

  List<Instrument> get all => _bySymbol.values.toList();

  Instrument? bySymbol(String symbol) => _bySymbol[symbol.toUpperCase()];

  /// Always returns something usable, even before the registry has loaded.
  Instrument resolve(String symbol) =>
      bySymbol(symbol) ?? Instrument.placeholder(symbol);

  // ==========================================================
  // LOADING
  // ==========================================================

  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final usedCache = !forceRefresh && await _loadFromCache();
      if (usedCache) {
        _isReady = true;
        _isLoading = false;
        notifyListeners();
        // Refresh in the background if the cache is old; the UI already has
        // usable data so there is nothing to wait for.
        if (await _cacheIsStale()) {
          unawaited(_refreshFromNetwork());
        }
        return;
      }

      await _refreshFromNetwork();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _loadFromCache() async {
    try {
      final raw = await _persistence.readString(_cacheKey);
      if (raw == null || raw.isEmpty) return false;

      final list = jsonDecode(raw) as List<dynamic>;
      if (list.isEmpty) return false;

      _bySymbol.clear();
      for (final e in list) {
        final inst = Instrument.fromJson(e as Map<String, dynamic>);
        _bySymbol[inst.symbol] = inst;
      }
      _logger.info('Symbol registry: ${_bySymbol.length} from cache');
      return true;
    } catch (e) {
      _logger.warning('Symbol cache read failed: $e');
      return false;
    }
  }

  Future<bool> _cacheIsStale() async {
    try {
      final ts = await _persistence.readInt(_cacheStampKey);
      if (ts <= 0) return true;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      return age > _maxCacheAge.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  Future<void> _refreshFromNetwork() async {
    final instruments = await _provider.fetchExchangeInfo();

    if (instruments.isEmpty) {
      if (_bySymbol.isEmpty) {
        _error = 'Could not load symbols. Check your connection.';
        _logger.error('Symbol registry empty and network refresh failed');
      }
      notifyListeners();
      return;
    }

    _bySymbol
      ..clear()
      ..addEntries(instruments.map((i) => MapEntry(i.symbol, i)));
    _isReady = true;
    _error = null;

    await _writeCache();
    notifyListeners();

    // Volume ranking is a nice-to-have; failure here must not break the app.
    unawaited(hydrateVolumes());
  }

  Future<void> _writeCache() async {
    try {
      final payload =
          jsonEncode(_bySymbol.values.map((i) => i.toJson()).toList());
      await _persistence.writeString(_cacheKey, payload);
      await _persistence.writeInt(
          _cacheStampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      _logger.warning('Symbol cache write failed: $e');
    }
  }

  /// Pull a full ticker snapshot to populate 24h volume for search ranking.
  Future<void> hydrateVolumes() async {
    try {
      await _provider.fetchPrices(const []);
      // fetchPrices enriches the provider's own instrument map; mirror it here.
      var updated = 0;
      for (final symbol in _bySymbol.keys.toList()) {
        final fromProvider = _provider.instrumentFor(symbol);
        if (fromProvider != null && fromProvider.quoteVolume24h > 0) {
          _bySymbol[symbol] =
              _bySymbol[symbol]!.copyWith(quoteVolume24h: fromProvider.quoteVolume24h);
          updated++;
        }
      }
      if (updated > 0) {
        _logger.info('Symbol registry: volume for $updated symbols');
        await _writeCache();
        notifyListeners();
      }
    } catch (e) {
      _logger.warning('Volume hydration failed: $e');
    }
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  /// Rank-ordered search across symbol, base and quote assets.
  ///
  /// Ranking: exact symbol, then exact base, then base prefix, then substring.
  /// Ties break on 24h quote volume so liquid pairs surface first.
  List<Instrument> search(
    String query, {
    int limit = 50,
    String? quoteFilter,
    bool preferredQuotesOnly = true,
  }) {
    final q = query.trim().toUpperCase();

    Iterable<Instrument> pool = _bySymbol.values;
    if (quoteFilter != null && quoteFilter.isNotEmpty) {
      pool = pool.where((i) => i.quote == quoteFilter);
    } else if (preferredQuotesOnly) {
      pool = pool.where((i) => preferredQuotes.contains(i.quote));
    }

    if (q.isEmpty) {
      final sorted = pool.toList()
        ..sort((a, b) => b.quoteVolume24h.compareTo(a.quoteVolume24h));
      return sorted.take(limit).toList();
    }

    final scored = <_Scored>[];
    for (final i in pool) {
      final score = _score(i, q);
      if (score > 0) scored.add(_Scored(i, score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.instrument.quoteVolume24h.compareTo(a.instrument.quoteVolume24h);
    });

    return scored.take(limit).map((s) => s.instrument).toList();
  }

  int _score(Instrument i, String q) {
    if (i.symbol == q) return 1000;
    if (i.base == q) return 900;
    if (i.base.startsWith(q)) return 700;
    if (i.symbol.startsWith(q)) return 600;
    if (i.base.contains(q)) return 400;
    if (i.symbol.contains(q)) return 300;
    if (i.quote == q) return 100;
    return 0;
  }

  /// Most liquid instruments, used as the default watchlist and empty-state.
  List<Instrument> topByVolume({int limit = 20, String quote = 'USDT'}) {
    final pool = _bySymbol.values.where((i) => i.quote == quote).toList()
      ..sort((a, b) => b.quoteVolume24h.compareTo(a.quoteVolume24h));
    return pool.take(limit).toList();
  }

  /// Quote assets actually present, ordered with the preferred ones first.
  List<String> availableQuotes() {
    final present = _bySymbol.values.map((i) => i.quote).toSet();
    final ordered = preferredQuotes.where(present.contains).toList();
    final rest = present.where((q) => !preferredQuotes.contains(q)).toList()
      ..sort();
    return [...ordered, ...rest];
  }
}

class _Scored {
  final Instrument instrument;
  final int score;
  const _Scored(this.instrument, this.score);
}
