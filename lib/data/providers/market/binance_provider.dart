/// Binance market data provider.
///
/// Supports the full set of TRADING spot symbols, discovered at runtime from
/// `/api/v3/exchangeInfo` rather than a hardcoded map. The canonical symbol
/// is the exchange symbol itself (e.g. `BTCUSDT`) — there is no app-symbol
/// translation layer.
///
/// Real-time data uses two distinct streams:
///   • `!ticker@arr`            — one socket carrying every symbol's 24h
///                                ticker. Drives watchlists and search.
///   • `<symbol>@kline_<tf>`    — authoritative OHLCV for the focused chart.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:app/domain/entities/price_data.dart';
import 'package:app/domain/entities/candle_data.dart';
import 'package:app/domain/entities/kline_update.dart';
import 'package:app/models/instrument.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/domain/repositories/kline_cache_repository.dart';
import 'package:app/data/providers/market/market_provider.dart';
import 'package:app/core/logging/logger.dart';

class BinanceProvider implements MarketProvider {
  static final BinanceProvider _instance = BinanceProvider._internal();
  factory BinanceProvider() => _instance;
  BinanceProvider._internal();

  static const List<String> _restHosts = [
    'api.binance.com',
    'api.binance.us',
  ];

  static const String _wsBase = 'wss://stream.binance.com:9443';

  static const List<String> _corsProxies = [
    'https://api.allorigins.win/raw?url=',
  ];

  final Logger _logger = Logger.instance;

  // ── Ticker stream (all symbols) ───────────────────────────
  WebSocketChannel? _tickerChannel;
  bool _tickerConnecting = false;
  bool _tickerConnected = false;
  int _tickerRetry = 0;
  Timer? _tickerRetryTimer;

  final StreamController<PriceUpdate> _priceUpdateController =
      StreamController<PriceUpdate>.broadcast();

  // ── Kline streams (per symbol+interval) ───────────────────
  final Map<String, _KlineSubscription> _klineSubs = {};

  /// Instruments known to the provider, populated by [fetchExchangeInfo].
  final Map<String, Instrument> _instruments = {};

  bool _disposed = false;

  @override
  String get name => 'Binance';

  @override
  bool get isConnected => _tickerConnected;

  /// Every symbol update, for every symbol on the exchange.
  Stream<PriceUpdate> get allTickerStream => _priceUpdateController.stream;

  @override
  bool supportsAsset(String symbol) =>
      _instruments.isEmpty || _instruments.containsKey(symbol.toUpperCase());

  @override
  List<String> getSupportedSymbols() => _instruments.keys.toList();

  Instrument? instrumentFor(String symbol) =>
      _instruments[symbol.toUpperCase()];

  /// Executes a REST GET with fallback support across primary Binance hosts
  /// and CORS proxies. Direct endpoints natively return `Access-Control-Allow-Origin: *`.
  Future<http.Response?> _getWithFallback(
    String path, [
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 12),
  ]) async {
    for (final host in _restHosts) {
      try {
        final uri = Uri.https(host, path, query);
        final response = await http.get(uri).timeout(timeout);
        if (response.statusCode == 200) {
          return response;
        } else {
          _logger.warning('$path on $host returned HTTP ${response.statusCode}');
        }
      } catch (e) {
        _logger.warning('$path on $host failed: $e');
      }
    }

    if (kIsWeb) {
      for (final proxy in _corsProxies) {
        try {
          final directUrl = Uri.https('api.binance.com', path, query).toString();
          final proxyUri = Uri.parse('$proxy${Uri.encodeComponent(directUrl)}');
          final response = await http.get(proxyUri).timeout(timeout);
          if (response.statusCode == 200) {
            return response;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  // ==========================================================
  // SYMBOL DISCOVERY
  // ==========================================================

  /// Fetch every spot symbol with status `TRADING`.
  ///
  /// Returns an empty list on failure; callers should fall back to a cached
  /// registry rather than treating this as fatal.
  Future<List<Instrument>> fetchExchangeInfo() async {
    try {
      _logger.network('Fetching Binance exchangeInfo');
      final response = await _getWithFallback(
        '/api/v3/exchangeInfo',
        null,
        const Duration(seconds: 15),
      );

      if (response == null || response.statusCode != 200) {
        _logger.warning('exchangeInfo HTTP ${response?.statusCode ?? 'failed'}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final symbols = data['symbols'] as List<dynamic>? ?? const [];
      final out = <Instrument>[];

      for (final raw in symbols) {
        final s = raw as Map<String, dynamic>;
        if (s['status'] != 'TRADING') continue;
        if (s['isSpotTradingAllowed'] != true && s['spotTradingAllowed'] != true) continue;

        final symbol = s['symbol'] as String;
        final base = s['baseAsset'] as String? ?? symbol;
        final quote = s['quoteAsset'] as String? ?? '';

        double tickSize = 0.01;
        final filters = s['filters'] as List<dynamic>? ?? const [];
        for (final f in filters) {
          final filter = f as Map<String, dynamic>;
          if (filter['filterType'] == 'PRICE_FILTER') {
            tickSize =
                double.tryParse(filter['tickSize']?.toString() ?? '') ?? 0.01;
            break;
          }
        }

        out.add(Instrument(
          symbol: symbol,
          base: base,
          quote: quote,
          tickSize: tickSize,
          pricePrecision: Instrument.precisionFromTickSize(tickSize),
        ));
      }

      _instruments
        ..clear()
        ..addEntries(out.map((i) => MapEntry(i.symbol, i)));

      _logger.info('exchangeInfo: ${out.length} tradable spot symbols');
      return out;
    } catch (e) {
      _logger.error('exchangeInfo fetch failed: $e');
      return [];
    }
  }

  // ==========================================================
  // REST — PRICES
  // ==========================================================

  /// Fetch 24h ticker data. An empty [symbols] list fetches every symbol.
  @override
  Future<Map<String, PriceData>> fetchPrices(List<String> symbols) async {
    final wanted = symbols.map((s) => s.toUpperCase()).toSet();
    final results = <String, PriceData>{};

    try {
      final response = await _getWithFallback('/api/v3/ticker/24hr');

      if (response == null || response.statusCode != 200) {
        _logger.warning('ticker/24hr HTTP ${response?.statusCode ?? 'failed'}');
        return results;
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      for (final raw in data) {
        final item = raw as Map<String, dynamic>;
        final symbol = item['symbol'] as String;
        if (wanted.isNotEmpty && !wanted.contains(symbol)) continue;

        final price = double.tryParse(item['lastPrice']?.toString() ?? '') ?? 0;
        if (price <= 0) continue;

        final change =
            double.tryParse(item['priceChangePercent']?.toString() ?? '') ?? 0;
        final quoteVolume =
            double.tryParse(item['quoteVolume']?.toString() ?? '') ?? 0;

        results[symbol] = PriceData(
          symbol: symbol,
          price: price,
          change: change,
          timestamp: nowMs,
          source: 'binance-rest',
        );

        // Opportunistically enrich the registry with liquidity ranking data.
        final known = _instruments[symbol];
        if (known != null && quoteVolume > 0) {
          _instruments[symbol] = known.copyWith(quoteVolume24h: quoteVolume);
        }
      }

      _logger.info('Fetched ${results.length} prices from Binance');
    } catch (e) {
      _logger.error('Binance price fetch failed: $e');
    }

    return results;
  }

  // ==========================================================
  // REST — CANDLES
  // ==========================================================

  @override
  Future<List<CandleData>> fetchOHLC(
    String symbol,
    String interval, {
    int? limit,
    int? endTime,
  }) async {
    final upper = symbol.toUpperCase();
    final cache = serviceLocator.isRegistered<KlineCacheRepository>()
        ? serviceLocator<KlineCacheRepository>()
        : null;

    try {
      final query = {
        'symbol': upper,
        'interval': interval,
        if (limit != null) 'limit': limit.toString(),
        if (endTime != null) 'endTime': endTime.toString(),
      };

      final response = await _getWithFallback('/api/v3/klines', query);

      if (response == null || response.statusCode != 200) {
        _logger.warning('klines $upper HTTP ${response?.statusCode ?? 'failed'} — checking offline cache');
        if (cache != null) {
          final cached = await cache.getCandles(upper, interval);
          if (cached.isNotEmpty) return cached;
        }
        return [];
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final candles = data
          .map((k) => CandleData(
                timestamp: (k[0] as num).toInt(),
                open: double.parse(k[1].toString()),
                high: double.parse(k[2].toString()),
                low: double.parse(k[3].toString()),
                close: double.parse(k[4].toString()),
                volume: double.parse(k[5].toString()),
              ))
          .toList();

      if (candles.isNotEmpty && cache != null) {
        unawaited(cache.saveCandles(upper, interval, candles));
      }

      return candles;
    } catch (e) {
      _logger.error('klines fetch failed for $upper: $e — checking offline cache');
      if (cache != null) {
        final cached = await cache.getCandles(upper, interval);
        if (cached.isNotEmpty) return cached;
      }
      return [];
    }
  }

  // ==========================================================
  // WEBSOCKET — ALL-MARKET TICKER
  // ==========================================================

  @override
  Stream<PriceUpdate>? subscribeToPriceUpdates(List<String> symbols) {
    connect();
    if (symbols.isEmpty) return _priceUpdateController.stream;
    final wanted = symbols.map((s) => s.toUpperCase()).toSet();
    return _priceUpdateController.stream
        .where((u) => wanted.contains(u.symbol));
  }

  @override
  Future<void> connect() async {
    if (_disposed || _tickerConnected || _tickerConnecting) return;
    _tickerConnecting = true;

    try {
      final uri = Uri.parse('$_wsBase/ws/!ticker@arr');
      _logger.info('Connecting Binance all-market ticker stream');
      final channel = WebSocketChannel.connect(uri);
      _tickerChannel = channel;

      channel.stream.listen(
        _handleTickerMessage,
        onError: (Object e) => _onTickerDown('error: $e'),
        onDone: () => _onTickerDown('closed'),
        cancelOnError: false,
      );

      _tickerConnecting = false;
      _tickerConnected = true;
      _tickerRetry = 0;
      _logger.info('Ticker stream connected');
    } catch (e) {
      _tickerConnecting = false;
      _tickerConnected = false;
      _tickerChannel = null;
      _onTickerDown('connect failed: $e');
    }
  }

  void _handleTickerMessage(dynamic message) {
    try {
      final decoded = jsonDecode(message as String);
      if (decoded is! List) return;

      for (final raw in decoded) {
        final t = raw as Map<String, dynamic>;
        final symbol = t['s'] as String?;
        if (symbol == null) continue;

        final price = double.tryParse(t['c']?.toString() ?? '') ?? 0;
        if (price <= 0) continue;
        final change = double.tryParse(t['P']?.toString() ?? '') ?? 0;

        _priceUpdateController.add(PriceUpdate(
          symbol: symbol,
          price: price,
          change: change,
          source: 'binance-ws',
        ));
      }
    } catch (e) {
      _logger.error('Ticker parse error: $e');
    }
  }

  /// Shared teardown + backoff for both error and close, so a silent close
  /// reconnects instead of stalling the stream permanently.
  void _onTickerDown(String reason) {
    if (_disposed) return;
    _tickerConnected = false;
    _tickerConnecting = false;
    _tickerChannel = null;
    _logger.warning('Ticker stream down ($reason)');
    _scheduleTickerReconnect();
  }

  void _scheduleTickerReconnect() {
    if (_disposed) return;
    _tickerRetryTimer?.cancel();
    // Exponential backoff, capped at 30s.
    final delaySec = (1 << _tickerRetry).clamp(1, 30);
    _tickerRetry = (_tickerRetry + 1).clamp(0, 5);
    _logger.info('Reconnecting ticker stream in ${delaySec}s');
    _tickerRetryTimer = Timer(Duration(seconds: delaySec), () {
      if (!_tickerConnected) connect();
    });
  }

  // ==========================================================
  // WEBSOCKET — KLINES (focused chart)
  // ==========================================================

  /// Live authoritative candles for one symbol+interval.
  ///
  /// Subscriptions are reference-counted: the socket closes when the last
  /// listener for that symbol+interval detaches.
  Stream<KlineUpdate> klineStream(String symbol, String interval) {
    final key = '${symbol.toUpperCase()}_$interval';
    final existing = _klineSubs[key];
    if (existing != null) return existing.controller.stream;

    final sub = _KlineSubscription(
      symbol: symbol.toUpperCase(),
      interval: interval,
      logger: _logger,
      wsBase: _wsBase,
      onGone: () => _klineSubs.remove(key),
    );
    _klineSubs[key] = sub;
    return sub.controller.stream;
  }

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  Future<void> disconnect() async {
    _tickerRetryTimer?.cancel();
    _tickerRetryTimer = null;
    try {
      await _tickerChannel?.sink.close();
    } catch (_) {}
    _tickerChannel = null;
    _tickerConnected = false;
    _tickerConnecting = false;

    for (final sub in _klineSubs.values.toList()) {
      await sub.close();
    }
    _klineSubs.clear();
    _logger.info('Binance streams disconnected');
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _priceUpdateController.close();
  }
}

/// One `<symbol>@kline_<interval>` socket with lazy connect and auto-reconnect.
class _KlineSubscription {
  final String symbol;
  final String interval;
  final Logger logger;
  final String wsBase;
  final void Function() onGone;

  late final StreamController<KlineUpdate> controller;
  WebSocketChannel? _channel;
  Timer? _retryTimer;
  int _retry = 0;
  bool _closed = false;

  _KlineSubscription({
    required this.symbol,
    required this.interval,
    required this.logger,
    required this.wsBase,
    required this.onGone,
  }) {
    controller = StreamController<KlineUpdate>.broadcast(
      onListen: _connect,
      onCancel: () {
        if (!controller.hasListener) close();
      },
    );
  }

  void _connect() {
    if (_closed) return;
    try {
      final stream = '${symbol.toLowerCase()}@kline_$interval';
      final uri = Uri.parse('$wsBase/ws/$stream');
      logger.info('Connecting kline stream $stream');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _retry = 0;

      channel.stream.listen(
        _onMessage,
        onError: (Object e) => _down('error: $e'),
        onDone: () => _down('closed'),
        cancelOnError: false,
      );
    } catch (e) {
      _down('connect failed: $e');
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final k = data['k'] as Map<String, dynamic>?;
      if (k == null) return;

      final update = KlineUpdate(
        symbol: (data['s'] as String?) ?? symbol,
        interval: (k['i'] as String?) ?? interval,
        openTime: (k['t'] as num).toInt(),
        open: double.parse(k['o'].toString()),
        high: double.parse(k['h'].toString()),
        low: double.parse(k['l'].toString()),
        close: double.parse(k['c'].toString()),
        volume: double.parse(k['v'].toString()),
        isClosed: k['x'] == true,
      );

      if (!controller.isClosed) controller.add(update);
    } catch (e) {
      logger.error('Kline parse error ($symbol $interval): $e');
    }
  }

  void _down(String reason) {
    if (_closed) return;
    _channel = null;
    logger.warning('Kline $symbol $interval down ($reason)');
    _retryTimer?.cancel();
    final delaySec = (1 << _retry).clamp(1, 30);
    _retry = (_retry + 1).clamp(0, 5);
    _retryTimer = Timer(Duration(seconds: delaySec), () {
      if (!_closed && controller.hasListener) _connect();
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retryTimer?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (!controller.isClosed) await controller.close();
    onGone();
  }
}
