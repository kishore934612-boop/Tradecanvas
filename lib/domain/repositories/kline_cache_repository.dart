/// Kline/Candle offline cache repository interface and persistence implementation.
///
/// Caches historical OHLCV kline series locally so charts and replay mode load
/// seamlessly when network connectivity is lost or unavailable.
library;

import 'dart:convert';

import 'package:app/core/logging/logger.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/services/persistence/persistence_service.dart';

abstract class KlineCacheRepository {
  /// Retrieve cached candles for a symbol and interval (e.g. BTCUSDT, 1h).
  Future<List<CandleData>> getCandles(String symbol, String interval);

  /// Save/overwrite cached candles for a symbol and interval.
  Future<void> saveCandles(
    String symbol,
    String interval,
    List<CandleData> candles,
  );

  /// Clear cached candles for a symbol, or all cached klines if symbol is null.
  Future<void> clearCache({String? symbol});
}

class PersistenceKlineCacheRepository implements KlineCacheRepository {
  final PersistenceService _persistence;
  final Logger _logger;

  /// Maximum cached candles kept per symbol/interval pair (e.g. 500 candles).
  static const int kMaxCachedCandlesPerSeries = 500;

  PersistenceKlineCacheRepository({
    required PersistenceService persistence,
    required Logger logger,
  })  : _persistence = persistence,
        _logger = logger;

  String _cacheKey(String symbol, String interval) =>
      'kline_cache:${symbol.toUpperCase()}:$interval';

  @override
  Future<List<CandleData>> getCandles(String symbol, String interval) async {
    try {
      final key = _cacheKey(symbol, interval);
      final raw = await _persistence.readString(key);
      if (raw == null || raw.isEmpty) return const [];

      final list = jsonDecode(raw) as List<dynamic>;
      final candles = list
          .map((item) {
            if (item is Map<String, dynamic>) {
              return CandleData.fromJson(item);
            }
            return null;
          })
          .whereType<CandleData>()
          .toList();

      if (candles.isNotEmpty) {
        _logger.info(
          'Loaded ${candles.length} cached candles offline for ${symbol.toUpperCase()} ($interval)',
        );
      }
      return candles;
    } catch (e) {
      _logger.warning('Failed to load cached klines for $symbol: $e');
      return const [];
    }
  }

  @override
  Future<void> saveCandles(
    String symbol,
    String interval,
    List<CandleData> candles,
  ) async {
    if (candles.isEmpty) return;
    try {
      final key = _cacheKey(symbol, interval);

      // Keep up to kMaxCachedCandlesPerSeries latest candles
      final toSave = candles.length > kMaxCachedCandlesPerSeries
          ? candles.sublist(candles.length - kMaxCachedCandlesPerSeries)
          : candles;

      final encoded = jsonEncode(toSave.map((c) => c.toJson()).toList());
      await _persistence.writeString(key, encoded);
    } catch (e) {
      _logger.warning('Failed to save kline cache for $symbol: $e');
    }
  }

  @override
  Future<void> clearCache({String? symbol}) async {
    try {
      final allKeys = await _persistence.getKeys();
      if (symbol != null) {
        final prefix = 'kline_cache:${symbol.toUpperCase()}:';
        final keys = allKeys.where((k) => k.startsWith(prefix)).toList();
        for (final k in keys) {
          await _persistence.delete(k);
        }
      } else {
        final keys = allKeys.where((k) => k.startsWith('kline_cache:')).toList();
        for (final k in keys) {
          await _persistence.delete(k);
        }
      }
    } catch (e) {
      _logger.warning('Failed to clear kline cache: $e');
    }
  }
}
