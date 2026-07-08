import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/models/gamification.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/utils/market_session.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
// Phase 3: Repository integration
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/core/logging/logger.dart';
// Phase 4: Controller imports
import 'package:app/controllers/portfolio_controller.dart';
import 'package:app/controllers/position_controller.dart';
import 'package:app/controllers/order_controller.dart';
import 'package:app/controllers/journal_controller.dart';
import 'package:app/controllers/gamification_controller.dart';
import 'package:app/controllers/risk_management_engine.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/di/service_locator.dart';
// Phase 5: Trading Engine
import 'package:app/engine/trading_engine.dart';
// Phase 7: Market Scheduler
import 'package:app/engine/market_scheduler.dart';
// Phase 8: Persistence layer
import 'package:app/services/persistence/persistence_service.dart';

class TradingProvider extends ChangeNotifier {
  static const String _storageKey = '@tradeverse_state_v2';

  final StreamController<String> _priceUpdateController = StreamController<String>.broadcast();
  Stream<String> get priceUpdateStream => _priceUpdateController.stream;

  /// Phase 6: Per-symbol price stream for ChartController.
  /// Converts the symbol-keyed update stream into a `Stream<double>` for one asset.
  Stream<double> priceStreamFor(String symbol) {
    return _priceUpdateController.stream
        .where((s) => s == symbol)
        .map((_) => priceOf(symbol))
        .where((p) => p > 0);
  }

  // Phase 3: Repository layer integration (optional for backward compatibility)
  final MarketRepository? _marketRepository;
  final Logger? _logger;
  StreamSubscription? _repositorySubscription;
  
  // Phase 4: Specialized controllers
  late final PortfolioController _portfolioController;
  late final PositionController _positionController;
  late final OrderController _orderController;
  late final JournalController _journalController;
  late final GamificationController _gamificationController;
  late final RiskManagementEngine _riskEngine;

  PortfolioController get portfolioController => _portfolioController;
  PositionController get positionController => _positionController;
  OrderController get orderController => _orderController;
  JournalController get journalController => _journalController;
  GamificationController get gamificationController => _gamificationController;


  double startingCapital = startingBalance;
  double _balance = startingBalance;

  final List<Position> _positions = [];
  final List<PendingOrder> _orders = [];
  final List<Trade> _trades = [];
  final List<String> _favorites = [];
  final List<NewsArticle> _news = [];
  Map<String, double>? _prices = {};
  Map<String, double>? _priceChanges = {};
  final Map<String, String> _lastDataSource = {}; // Track data source per asset to detect switching
  final Map<String, int> _lastUpdateTime = {}; // Track last update timestamp per asset

  // ---- gamification accumulators ----
  double _realizedPnl = 0.0;
  int _wins = 0;
  int _losses = 0;
  int _currentWinStreak = 0;
  int _maxWinStreak = 0;
  int _riskDisciplineTrades = 0;
  int _riskRewardTrades = 0;
  int _ruleViolations = 0;
  int _revengeTrades = 0;
  final Map<String, double> _dailyRealized = {}; // dayKey -> realized pnl
  final Map<String, int> _tradesPerDay = {}; // dayKey -> count
  int _lastLossClosedAt = 0;
  double _lastTradeNotional = 0.0;

  final Set<String> _unlockedAchievements = {};
  final Set<String> _completedChallenges = {};
  final List<String> _recentUnlocks = []; // titles to surface as toasts

  Timer? _timer;
  // Phase 7: intelligent market scheduler (replaces dumb Timer.periodic)
  MarketScheduler? _marketScheduler;
  int _tickCount = 0;
  WebSocketChannel? _cryptoChannel;
  bool _isWsConnecting = false;
  Timer? _wsReconnectTimer;

  final List<Map<String, dynamic>> _newsTemplates = [
    {'title': 'Institutional Crypto Inflow', 'description': 'Major asset managers execute multi-million dollar cryptocurrency buys, boosting optimism.', 'impactSymbol': 'crypto', 'sentiment': 'bullish', 'impactFactor': 0.08},
    {'title': 'Bitcoin Halving Optimism', 'description': 'Halving metrics align with historical bullish patterns, prompting heavy order flows into BTC.', 'impactSymbol': 'BTC', 'sentiment': 'bullish', 'impactFactor': 0.12},
    {'title': 'Ethereum Layer-2 Surge', 'description': 'Gas fee optimization prompts a surge in Ethereum layer-2 transactions and ETH accumulation.', 'impactSymbol': 'ETH', 'sentiment': 'bullish', 'impactFactor': 0.09},
  ];

  TradingProvider({
    this._marketRepository,
    this._logger,
  }) {
    _logger?.info('TradingProvider initializing${_marketRepository != null ? " (with repository)" : " (standalone)"}...');
    
    // Phase 4: Initialize controllers
    final eventBus = serviceLocator.isRegistered<EventBus>()
        ? serviceLocator<EventBus>()
        : EventBus.instance;
    final log = _logger ?? Logger.instance;
    
    _portfolioController = PortfolioController(
      eventBus: eventBus,
      logger: log,
      initialBalance: startingBalance,
    );
    
    _positionController = PositionController(
      eventBus: eventBus,
      logger: log,
    );
    
    _orderController = OrderController(
      eventBus: eventBus,
      logger: log,
    );
    
    _journalController = JournalController(
      eventBus: eventBus,
      logger: log,
    );
    
    _gamificationController = GamificationController(
      eventBus: eventBus,
      logger: log,
    );
    
    _riskEngine = RiskManagementEngine(logger: log);
    
    // Listen to PositionClosedEvent to keep legacy state in sync
    eventBus.on<PositionClosedEvent>().listen(_onPositionClosed);
    
    _loadState();
    _connectCryptoWs();
    _startSimulation();
    
    // Subscribe to repository updates if available
    if (_marketRepository != null) {
      _subscribeToRepositoryUpdates();
    }
  }
  
  /// Called when PositionController emits a PositionClosedEvent.
  /// Keeps legacy _trades list in sync for backward compatibility.
  void _onPositionClosed(PositionClosedEvent event) {
    if (event.trade == null) return;
    _trades.insert(0, event.trade!);
    
    // Update gamification counters from the event
    final netPnl = event.pnl;
    if (netPnl >= 0) {
      _wins++;
      _currentWinStreak++;
      if (_currentWinStreak > _maxWinStreak) _maxWinStreak = _currentWinStreak;
    } else {
      _losses++;
      _currentWinStreak = 0;
    }
    
    final dk = dayKey(DateTime.now().millisecondsSinceEpoch);
    _dailyRealized[dk] = (_dailyRealized[dk] ?? 0.0) + netPnl;
    
    // Emit TradeCompletedEvent after processing
    final evBus = serviceLocator.isRegistered<EventBus>()
        ? serviceLocator<EventBus>()
        : EventBus.instance;
    evBus.publish<TradeCompletedEvent>(TradeCompletedEvent(
      tradeId: event.trade!.id,
      symbol: event.trade!.symbol,
      pnl: event.pnl,
      isWin: netPnl >= 0,
      durationMs: event.trade!.durationMs,
      closeReason: event.closeReason,
      riskReward: event.trade!.riskReward,
      riskPct: event.trade!.riskPct,
      trade: event.trade!,
    ));
  }

  // ---------------- getters ----------------
  double get balance => _balance;
  List<Position> get positions => _positions;
  List<PendingOrder> get orders => _orders;
  List<Trade> get trades => _trades;
  List<String> get favorites => _favorites;
  List<NewsArticle> get news => _news;
  Map<String, double> get prices {
    _prices ??= {};
    return _prices!;
  }

  double priceOf(String symbol) {
    _prices ??= {};
    final a = getAssetBySymbol(symbol);
    return _prices![symbol] ?? a?.basePrice ?? 0.0;
  }

  double changeOf(String symbol) {
    _priceChanges ??= {};
    return _priceChanges![symbol] ?? 0.0;
  }

  double get unrealizedPnl {
    double sum = 0.0;
    for (final p in _positions) {
      sum += p.pnl(priceOf(p.symbol));
    }
    return sum;
  }

  double get usedMargin => _positions.fold(0.0, (s, p) => s + p.margin);
  double get equity     => TradingEngine.equity(balance: _balance, usedMargin: usedMargin, unrealizedPnl: unrealizedPnl);
  double get freeMargin => TradingEngine.freeMargin(equity: equity, usedMargin: usedMargin);
  double get marginLevel => TradingEngine.marginLevel(equity: equity, usedMargin: usedMargin);
  double get realizedPnl => _realizedPnl;
  double get totalReturnPct => TradingEngine.totalReturnPct(equity: equity, startingCapital: startingCapital);

  double get dailyPnl {
    final today = dayKey(DateTime.now().millisecondsSinceEpoch);
    return (_dailyRealized[today] ?? 0.0) + unrealizedPnl;
  }

  int get winCount => _wins;
  int get lossCount => _losses;
  double get winRate => (_wins + _losses) == 0 ? 0 : (_wins / (_wins + _losses)) * 100.0;

  List<String> consumeRecentUnlocks() {
    // Phase 4: Delegate to GamificationController
    return _gamificationController.consumeRecentUnlocks();
  }

  // ---------------- trading engine (Phase 5) ----------------
  /// Convenience wrappers — UI calls these instead of TradingEngine directly.

  /// Suggest a position size based on fixed-risk model.
  PositionSizeResult? suggestPositionSize({
    required String symbol,
    required PositionSide side,
    required double riskPercent,
    required double stopLoss,
    required TradingType tradingType,
  }) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return null;
    final config = MarketConfig.get(asset.type, tradingType);
    return TradingEngine.suggestPositionSize(
      equity: equity,
      riskPercent: riskPercent,
      entryPrice: priceOf(symbol),
      stopLoss: stopLoss,
      leverage: config.defaultLeverage,
      asset: asset,
      config: config,
    );
  }

  /// Risk-reward ratio for a proposed setup.
  RiskRewardResult? riskReward({
    required String symbol,
    required PositionSide side,
    required double stopLoss,
    required double takeProfit,
  }) {
    return TradingEngine.riskReward(
      entryPrice: priceOf(symbol),
      side: side,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
    );
  }

  double pipValue(String symbol, double qty) {
    return 0.0;
  }

  /// Full pre-trade validation via TradingEngine.
  String? validateTrade({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double leverage,
    required TradingType tradingType,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
  }) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return 'Asset not found';
    final config = MarketConfig.get(asset.type, tradingType);
    return TradingEngine.validateTrade(
      symbol: symbol,
      side: side,
      qty: qty,
      leverage: leverage,
      freeMargin: freeMargin,
      entryPrice: priceOf(symbol),
      config: config,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: trailingStop,
    );
  }

  // ---------------- favorites ----------------
  bool isFavorite(String symbol) => _favorites.contains(symbol);

  void toggleFavorite(String symbol) {
    if (_favorites.contains(symbol)) {
      _favorites.remove(symbol);
    } else {
      _favorites.add(symbol);
    }
    _saveState();
    notifyListeners();
  }

  // ---------------- stats ----------------
  int get _consecutiveProfitableDays {
    if (_dailyRealized.isEmpty) return 0;
    final keys = _dailyRealized.keys.toList()..sort();
    int streak = 0;
    for (int i = keys.length - 1; i >= 0; i--) {
      if ((_dailyRealized[keys[i]] ?? 0) > 0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int get _maxTradesInADay => _tradesPerDay.values.fold(0, (m, v) => v > m ? v : m);

  TradingStats get stats {
    int scalp = 0, day = 0, swing = 0, pos = 0;
    for (final t in _trades) {
      switch (t.styleBucket) {
        case 'Scalping':
          scalp++;
          break;
        case 'Day Trading':
          day++;
          break;
        case 'Swing Trading':
          swing++;
          break;
        default:
          pos++;
      }
    }
    return TradingStats(
      totalTrades: _trades.length,
      wins: _wins,
      losses: _losses,
      currentWinStreak: _currentWinStreak,
      maxWinStreak: _maxWinStreak,
      totalReturnPct: totalReturnPct,
      equity: equity,
      startingCapital: startingCapital,
      consecutiveProfitableDays: _consecutiveProfitableDays,
      tradingDays: _tradesPerDay.length,
      riskDisciplineTrades: _riskDisciplineTrades,
      riskRewardTrades: _riskRewardTrades,
      ruleViolations: _ruleViolations,
      revengeTrades: _revengeTrades,
      maxTradesInADay: _maxTradesInADay,
      scalpTrades: scalp,
      dayTrades: day,
      swingTrades: swing,
      positionTrades: pos,
      winningTrades: _wins,
    );
  }

  bool isAchievementUnlocked(String id) => _unlockedAchievements.contains(id);
  bool isChallengeComplete(String id) => _completedChallenges.contains(id);

  // ---------------- simulation ----------------
  bool _isFetching = false;

  /// Fetch crypto prices from Binance REST API (used on web where WebSocket is blocked)
  Future<Map<String, List<double>>> _fetchBinancePrices() async {
    final Map<String, List<double>> results = {};
    
    // On web, use CORS proxy for Binance API
    final baseUrl = kIsWeb 
        ? 'https://corsproxy.io/?https://api.binance.com'
        : 'https://api.binance.com';
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v3/ticker/24hr'),
        headers: kIsWeb ? {} : {},
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final cryptoSymbols = {
          'BTCUSDT': 'BTC',
          'ETHUSDT': 'ETH',
          'SOLUSDT': 'SOL',
          'BNBUSDT': 'BNB',
          'XRPUSDT': 'XRP',
          'DOGEUSDT': 'DOGE',
          'ADAUSDT': 'ADA',
          'AVAXUSDT': 'AVAX',
        };
        
        int successCount = 0;
        for (final item in data) {
          final sym = item['symbol'] as String;
          if (cryptoSymbols.containsKey(sym)) {
            final appSym = cryptoSymbols[sym]!;
            final price = double.tryParse(item['lastPrice'] as String) ?? 0.0;
            final change = double.tryParse(item['priceChangePercent'] as String) ?? 0.0;
            if (price > 0) {
              results[appSym] = [price, change];
              successCount++;
            }
          }
        }
        
        if (successCount > 0) {
          Logger.instance.network('[Binance] ✓ Fetched $successCount crypto prices${kIsWeb ? " (via CORS proxy)" : ""}');
        }
      } else {
        Logger.instance.warning('[Binance] ⚠️ REST API error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Logger.instance.error('[Binance] REST fetch error', e);
    }
    return results;
  }

  Future<Map<String, List<double>>> _fetchYahooPrices() async {
    final Map<String, List<double>> results = {};
    final yahooMap = {
      // US Stocks
      'AAPL': 'AAPL',
      'NVDA': 'NVDA',
      'TSLA': 'TSLA',
      // Indian Stocks
      'TCS.NS':      'TCS',
      'RELIANCE.NS': 'RELIANCE',
      'HDFCBANK.NS': 'HDFCBANK',
      // Forex — 5 pairs only
      'GBPUSD=X': 'GBP/USD',
      'EURUSD=X': 'EUR/USD',
      'USDJPY=X': 'USD/JPY',
      'USDCAD=X': 'USD/CAD',
      'AUDUSD=X': 'AUD/USD',
    };

    final symbolsQuery = yahooMap.keys.join(',');
    
    // On web, Yahoo Finance has CORS restrictions - use CORS proxy
    final baseUrl = kIsWeb 
        ? 'https://corsproxy.io/?https://query1.finance.yahoo.com'
        : 'https://query1.finance.yahoo.com';
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/v7/finance/quote?symbols=$symbolsQuery'),
        headers: kIsWeb ? {} : {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 6));  // Slightly longer timeout for reliability

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> quoteList = data['quoteResponse']?['result'] ?? [];
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        
        if (quoteList.isNotEmpty) {
          Logger.instance.network('[Yahoo] ✓ Fetched ${quoteList.length} quotes successfully ${kIsWeb ? "(via CORS proxy)" : ""}');
        }
        
        for (final item in quoteList) {
          final yahooSymbol = item['symbol'] as String;
          final appSymbol = yahooMap[yahooSymbol];
          if (appSymbol == null) continue;

          // Check if data is fresh by examining regularMarketTime
          final marketTime = (item['regularMarketTime'] as num?)?.toInt() ?? 0;
          final dataAgeSeconds = marketTime > 0 ? (nowMs ~/ 1000) - marketTime : 999999;
          
          // Try multiple price fields depending on market state
          final marketState = item['marketState'] as String?;
          double price = 0.0;
          String priceSource = '';
          
          if (marketState == 'PRE' && item['preMarketPrice'] != null) {
            price = (item['preMarketPrice'] as num).toDouble();
            priceSource = 'preMarket';
          } else if (marketState == 'POST' && item['postMarketPrice'] != null) {
            price = (item['postMarketPrice'] as num).toDouble();
            priceSource = 'postMarket';
          } else if (item['regularMarketPrice'] != null) {
            price = (item['regularMarketPrice'] as num).toDouble();
            priceSource = 'regular';
          }
          
          final change = (item['regularMarketChangePercent'] as num?)?.toDouble() ?? 0.0;
          
          // Get market state to determine if we should trust this data
          final asset = getAssetBySymbol(appSymbol);
          final isMarketOpen = asset != null && getMarketStatus(asset).isLive;
          
          // Aggressive freshness check for real-time updates
          // During market hours, data older than 60s is considered stale
          // Outside market hours, accept data up to 5 minutes old
          final isDataFresh = dataAgeSeconds < (isMarketOpen ? 60 : 300);

          // Only use Yahoo data if:
          // 1. Price is valid (> 0)
          // 2. Market is open AND data is fresh, OR market is closed (then stale data is expected)
          if (price > 0 && (isDataFresh || !isMarketOpen)) {
            results[appSymbol] = [price, change];
            // Log fresh data during market hours to verify real-time updates
            if (isMarketOpen && dataAgeSeconds < 10) {
              Logger.instance.market('[Yahoo] ⚡ $appSymbol FRESH: \$${price.toStringAsFixed(4)} ($priceSource, ${dataAgeSeconds}s old)');
            } else if (dataAgeSeconds < 999999 && _tickCount % 10 == 0) {
              Logger.instance.market('[Yahoo] $appSymbol = \$${price.toStringAsFixed(4)} ($priceSource, age: ${dataAgeSeconds}s, state: $marketState)');
            }
          } else if (isMarketOpen && price > 0) {
            Logger.instance.warning('[Yahoo] ⚠️ Rejecting stale data for $appSymbol (age: ${dataAgeSeconds}s, market: open)');
          } else if (price == 0) {
            Logger.instance.warning('[Yahoo] ⚠️ No valid price for $appSymbol (marketState: $marketState)');
          }
        }
      } else {
        Logger.instance.warning('[Yahoo] ⚠️ API error: HTTP ${response.statusCode}');
      }
    } catch (e) {
      Logger.instance.error('[Yahoo] Fetch error', e);
    }
    return results;
  }

  void _connectCryptoWs() {
    // WebSocket not supported on web platform due to CORS restrictions
    // On web, crypto prices will use base prices until a WebSocket-compatible
    // solution is implemented (e.g., server-side WebSocket proxy)
    if (kIsWeb) {
      Logger.instance.info('[Binance] WebSocket disabled on web platform (CORS restriction)');
      Logger.instance.info('[Binance] Crypto prices will show base values on web');
      return;
    }
    
    if (_cryptoChannel != null || _isWsConnecting) return;
    _isWsConnecting = true;

    final cryptoStreams = [
      'btcusdt@ticker',
      'ethusdt@ticker',
      'solusdt@ticker',
      'bnbusdt@ticker',
      'xrpusdt@ticker',
      'dogeusdt@ticker',
      'adausdt@ticker',
      'avaxusdt@ticker',
    ].join('/');

    final uri = Uri.parse('wss://stream.binance.com:9443/stream?streams=$cryptoStreams');

    try {
      Logger.instance.info('[Binance] Connecting WebSocket...');
      _cryptoChannel = WebSocketChannel.connect(uri);
      _isWsConnecting = false;

      _cryptoChannel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message);
            final String? stream = data['stream']?.toString();
            final ticker = data['data'] as Map<String, dynamic>?;
            if (stream == null || ticker == null) return;

            final rawSymbol = stream.split('@')[0].toUpperCase();
            final symbol = rawSymbol.replaceAll('USDT', '');

            final double price = double.tryParse(ticker['c']?.toString() ?? '') ?? 0.0;
            final double change = double.tryParse(ticker['P']?.toString() ?? '') ?? 0.0;

            if (price > 0) {
              _prices ??= {};
              _priceChanges ??= {};
              
              final oldPrice = _prices![symbol] ?? 0.0;
              _prices![symbol] = price;
              _priceChanges![symbol] = change;
              
              // Track WebSocket as data source
              _lastDataSource[symbol] = 'binance-ws';

              if (oldPrice > 0) {
                final diff = ((price - oldPrice) / oldPrice * 100).abs();
                if (diff > 0.1) {
                  Logger.instance.market('[Binance WS] $symbol: \$${price.toStringAsFixed(2)} (${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%)');
                }
              } else if (oldPrice == 0.0) {
                // First price received for this symbol
                Logger.instance.info('[Binance WS] ✓ $symbol connected: \$${price.toStringAsFixed(2)}');
              }

              // Run real-time order triggers/trailing stops
              _processRiskAndOrders();
              _priceUpdateController.add(symbol);
            }
          } catch (e) {
            Logger.instance.error('[Binance WS] ⚠️ Parse error', e);
          }
        },
        onError: (err) {
          Logger.instance.error('[Binance WS] ⚠️ Error', err);
          _reconnectCryptoWs();
        },
        onDone: () {
          Logger.instance.warning('[Binance WS] Connection closed, reconnecting...');
          _reconnectCryptoWs();
        },
        cancelOnError: true,
      );
      
      Logger.instance.info('[Binance] ✓ WebSocket stream listening');
    } catch (e) {
      _isWsConnecting = false;
      Logger.instance.error('[Binance] ⚠️ WS connection failed', e);
      _reconnectCryptoWs();
    }
  }

  void _reconnectCryptoWs() {
    _closeCryptoWs();
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 5), () {
      _connectCryptoWs();
    });
  }

  void _closeCryptoWs() {
    try {
      _cryptoChannel?.sink.close();
    } catch (_) {}
    _cryptoChannel = null;
  }

  // ============================================================
  // PHASE 3: REPOSITORY INTEGRATION METHODS
  // ============================================================

  /// Subscribe to price updates from the new repository layer
  void _subscribeToRepositoryUpdates() {
    if (_marketRepository == null) return;

    _logger?.info('Subscribing to repository price updates...');

    // Get all symbols we track
    final allSymbols = assets.map((a) => a.symbol).toList();

    _repositorySubscription = _marketRepository
        .subscribeToMultiplePrices(allSymbols)
        .listen(
      (update) {
        // Update local prices map
        _prices ??= {};
        _priceChanges ??= {};
        _prices![update.symbol] = update.price;
        _priceChanges![update.symbol] = update.change;
        _lastUpdateTime[update.symbol] = DateTime.now().millisecondsSinceEpoch;
        _lastDataSource[update.symbol] = update.source;

        // Trigger risk management and notify listeners
        _processRiskAndOrders();
        _priceUpdateController.add(update.symbol);
        notifyListeners();

        // Log real-time updates
        if (kDebugMode && update.source.contains('ws')) {
          _logger?.market('${update.symbol}: \$${update.price.toStringAsFixed(2)} (${update.change >= 0 ? "+" : ""}${update.change.toStringAsFixed(2)}%)');
        }
      },
      onError: (error) {
        _logger?.error('Repository subscription error: $error');
      },
    );

    _logger?.info('✓ Subscribed to repository updates for ${allSymbols.length} symbols');
  }

  /// Fetch prices from repository (NEW PATH) with fallback to old implementation
  Future<void> _fetchPricesFromRepository() async {
    if (_marketRepository == null) {
      // Fallback to old implementation if repository not available
      _logger?.debug('Repository not available, using legacy price fetching');
      await _fetchBinancePrices();
      await _fetchYahooPrices();
      return;
    }

    try {
      _logger?.network('Fetching prices from repository...');
      final allSymbols = assets.map((a) => a.symbol).toList();
      final result = await _marketRepository.getPrices(allSymbols);

      if (result.isSuccess) {
        final pricesData = result.data!;
        
        for (final entry in pricesData.entries) {
          _prices![entry.key] = entry.value.price;
          _priceChanges![entry.key] = entry.value.change;
          _lastUpdateTime[entry.key] = entry.value.timestamp;
          _lastDataSource[entry.key] = entry.value.source;
          _priceUpdateController.add(entry.key); // Publish stream event for real-time widgets
        }

        _logger?.info('✓ Fetched ${pricesData.length}/${allSymbols.length} prices from repository');
        notifyListeners();
      } else {
        _logger?.warning('Repository fetch failed: ${result.error}, falling back to legacy');
        // Fallback to old implementation on error
        await _fetchBinancePrices();
        await _fetchYahooPrices();
      }
    } catch (e) {
      _logger?.error('Repository fetch error: $e, falling back to legacy');
      // Fallback to old implementation on exception
      await _fetchBinancePrices();
      await _fetchYahooPrices();
    }
  }

  // ============================================================
  // END PHASE 3 METHODS
  // ============================================================



  void _startSimulation() {
    _updatePrices();
    if (_news.isEmpty) _generateNewsArticle();

    // Phase 7: Use MarketScheduler for intelligent polling.
    // The scheduler only fires the callback for markets that are currently live,
    // avoiding unnecessary API calls when all markets are closed.
    if (serviceLocator.isRegistered<EventBus>()) {
      final eventBus = serviceLocator<EventBus>();
      final log      = _logger ?? Logger.instance;

      _marketScheduler = MarketScheduler(
        eventBus: eventBus,
        logger: log,
        onPoll: (activeMarkets) {
          // Only update prices + run risk for the markets currently trading
          _updatePricesForMarkets(activeMarkets);
          _processRiskAndOrders();
          _processFundingFees();
          _tickCount++;
          if (_tickCount % 20 == 0) _generateNewsArticle();
        },
        watchedMarkets: {MarketType.crypto},
        config: ScheduleConfig.defaults,
      );
      _marketScheduler!.start();
    } else {
      // Fallback: use simple timer when scheduler not available (e.g. tests)
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _updatePrices();
        _processRiskAndOrders();
        _processFundingFees();
        _tickCount++;
        if (_tickCount % 20 == 0) _generateNewsArticle();
      });
    }
  }

  double _getActiveImpact(String symbol, MarketType type) {
    double totalImpact = 0.0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final article in _news) {
      if (nowMs - article.timestamp > 90000) continue;
      if (article.impactSymbol == symbol) {
        totalImpact += article.impactFactor;
      } else if (article.impactSymbol == type.id) {
        totalImpact += article.impactFactor;
      }
    }
    return totalImpact;
  }

  /// Phase 7: Market-aware price update — only polls markets in [activeMarkets].
  /// Called by MarketScheduler on each tick with exactly the set that is live.
  Future<void> _updatePricesForMarkets(Set<MarketType> activeMarkets) async {
    // Crypto: always handled by WebSocket on mobile, Binance REST on web
    // Stocks/Forex: Yahoo REST
    // We simply run the full update but the scheduler ensures we're only
    // called when at least one market in activeMarkets is trading.
    if (activeMarkets.isNotEmpty) {
      Logger.instance.info('[Scheduler] Polling: ${activeMarkets.map((m) => m.label).join(", ")}');
    }
    await _updatePrices();
  }

  Future<void> _updatePrices() async {
    _prices ??= {};
    _priceChanges ??= {};
    if (_isFetching) return;
    _isFetching = true;
    _tickCount++;
    try {
      // PHASE 3: Use repository if available, otherwise fall back to old implementation
      if (_marketRepository != null) {
        await _fetchPricesFromRepository();
      } else {
        // OLD IMPLEMENTATION: Direct API calls (kept for backward compatibility)
        // Fetch prices from APIs
        // - Web: Binance REST (WebSocket blocked) + Yahoo REST
        // - Mobile: Yahoo REST only (crypto comes from WebSocket)
        final futures = <Future<Map<String, List<double>>>>[];
        
        // Always fetch Yahoo for stocks/forex
        futures.add(_fetchYahooPrices());
        
        // On web, also fetch Binance REST (WebSocket unavailable)
        // On mobile, skip Binance REST (WebSocket provides real-time data)
        if (kIsWeb) {
          futures.add(_fetchBinancePrices());
        }
        
        final results = await Future.wait(futures);
        final yahooData = results[0];
        final binanceData = kIsWeb && results.length > 1 ? results[1] : <String, List<double>>{};

      for (final asset in assets) {
        List<double>? realData;
        String dataSource = 'none';
        
        if (asset.type == MarketType.crypto) {
          if (kIsWeb) {
            // Web: Use Binance REST API data
            if (binanceData.containsKey(asset.symbol)) {
              realData = binanceData[asset.symbol];
              dataSource = 'binance-rest';
            }
          } else {
            // Mobile: WebSocket only (prices already in _prices map)
            // Skip if WebSocket has provided data
            if (_prices![asset.symbol] != null && _prices![asset.symbol]! > 0) {
              dataSource = 'binance-ws';
              // Don't overwrite WebSocket data
              _priceUpdateController.add(asset.symbol);
              continue;
            }
            // If WebSocket not connected yet, use base price as placeholder
            if (_cryptoChannel == null) {
              _prices![asset.symbol] = asset.basePrice;
              _priceChanges![asset.symbol] = 0.0;
              if (_tickCount % 30 == 0) {
                Logger.instance.market('[Price] ${asset.symbol}: Waiting for WebSocket connection...');
              }
              continue;
            }
          }
        } else {
          // Stocks/Forex: Yahoo only
          if (yahooData.containsKey(asset.symbol)) {
            realData = yahooData[asset.symbol];
            dataSource = 'yahoo';
          }
        }

        if (realData != null && realData[0] > 0) {
          final oldPrice = _prices![asset.symbol] ?? 0.0;
          final newPrice = realData[0];
          
          // Detect suspicious price jumps (> 20% in 3 seconds indicates stale data)
          // Reduced from 50% to 20% for more aggressive stale data detection
          // during rapid market movements
          final isMarketOpen = getMarketStatus(asset).isLive;
          if (oldPrice > 0 && isMarketOpen) {
            final priceDiff = ((newPrice - oldPrice) / oldPrice).abs();
            if (priceDiff > 0.20) {
              Logger.instance.warning('[Price] ⚠️ Rejecting suspicious jump for ${asset.symbol}: \$${oldPrice.toStringAsFixed(2)} -> \$${newPrice.toStringAsFixed(2)} (${(priceDiff * 100).toStringAsFixed(1)}%)');
              continue; // Skip this update, keep old price
            }
          }
          
          // Track data source changes to detect switching behavior
          final lastSource = _lastDataSource[asset.symbol];
          if (lastSource != null && lastSource != dataSource) {
            Logger.instance.market('[Price] 🔄 ${asset.symbol} switched: $lastSource -> $dataSource (price: \$${newPrice.toStringAsFixed(4)})');
          }
          _lastDataSource[asset.symbol] = dataSource;
          
          // Track update frequency for real-time monitoring
          final now = DateTime.now().millisecondsSinceEpoch;
          final lastUpdate = _lastUpdateTime[asset.symbol];
          if (lastUpdate != null) {
            final timeSinceUpdate = (now - lastUpdate) / 1000;
            if (timeSinceUpdate > 10) {
              Logger.instance.market('[Price] ⏰ ${asset.symbol} update gap: ${timeSinceUpdate.toStringAsFixed(1)}s');
            }
          }
          _lastUpdateTime[asset.symbol] = now;
          
          _prices![asset.symbol] = newPrice;
          _priceChanges![asset.symbol] = realData[1];
          
          if (_tickCount % 10 == 0) {
            // Log every ~30 seconds (10 ticks × 3s) to show live updates
            Logger.instance.market('[Price] ${asset.symbol}: \$${newPrice.toStringAsFixed(4)} from $dataSource (change: ${realData[1].toStringAsFixed(2)}%)');
          }
        } else {
          // Fallback to simulation only if no real data available
          final isMarketOpen = getMarketStatus(asset).isLive;
          
          // For closed markets, preserve last known price instead of simulating
          if (!isMarketOpen && _prices![asset.symbol] != null) {
            if (_tickCount % 60 == 0) {
              Logger.instance.market('[Price] ${asset.symbol}: Market closed, holding last price');
            }
            continue;
          }
          
          // Simulate only if market is open but data unavailable
          final basePrice = simulatePrice(asset, _tickCount * 0.05);
          final impact = _getActiveImpact(asset.symbol, asset.type);
          final finalPrice = basePrice * (1.0 + impact);
          _prices![asset.symbol] = finalPrice;
          _priceChanges![asset.symbol] = ((finalPrice - asset.basePrice) / asset.basePrice) * 100.0;
          
          if (_tickCount % 30 == 0) {
            Logger.instance.market('[Price] ${asset.symbol}: ${finalPrice.toStringAsFixed(4)} from simulation (market: ${isMarketOpen ? "open" : "closed"})');
          }
        }
        _priceUpdateController.add(asset.symbol);
      }
      } // End of else block (old implementation)
    } catch (e) {
      Logger.instance.error("[Price] Error in _updatePrices", e);
      _logger?.error("Price update error: $e");
    } finally {
      _isFetching = false;
    }
  }

  void _generateNewsArticle() {
    final rand = Random();
    final template = _newsTemplates[rand.nextInt(_newsTemplates.length)];
    _news.insert(
      0,
      NewsArticle(
        id: '${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(100000)}',
        title: template['title'],
        description: template['description'],
        impactSymbol: template['impactSymbol'],
        sentiment: template['sentiment'],
        impactFactor: (template['impactFactor'] as num).toDouble(),
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_news.length > 20) _news.removeLast();
    _saveState();
    notifyListeners();
  }

  // ---------------- funding fees (futures) ----------------
  /// Simulates periodic funding fees for open perpetual futures positions.
  /// Called every tick (~4s). We apply a small funding rate every ~60 ticks
  /// (roughly 4 minutes of simulated time, representing an 8-hour period).
  void _processFundingFees() {
    // Applied roughly every 60 ticks (representing the 8-hour funding cycle)
    if (_tickCount % 60 != 0) return;
    
    bool changed = false;
    for (final pos in _positions) {
      if (pos.tradingType != TradingType.futures) continue;
      
      final config = MarketConfig.get(pos.marketType, pos.tradingType);
      if (!config.fundingFeesExist) continue;
      
      final price = priceOf(pos.symbol);
      if (price <= 0) continue;
      
      // Configurable simulated rate: 0.01% (0.0001) per interval
      const double rate = 0.0001; 
      final fee = pos.qty * price * rate;
      
      // Long pays funding (accumulates positive fee)
      // Short receives funding (accumulates negative fee/credit)
      final signedFee = pos.side == PositionSide.long ? fee : -fee;
      pos.accumulatedFunding += signedFee;
      
      _logger?.info('[Funding] Applied funding fee of \$${signedFee.toStringAsFixed(4)} for ${pos.symbol} (${pos.side.label})');
      changed = true;
    }
    
    if (changed) {
      _saveState();
      notifyListeners();
    }
  }

  /// Evaluates pending orders, stop-loss/take-profit/trailing, and liquidations.
  void _processRiskAndOrders() {
    bool changed = false;

    // Phase 4: Fill triggered orders via OrderController
    final triggered = _orderController.consumeAllTriggeredOrders(
      Map.fromEntries(_positions.map((p) => MapEntry(p.symbol, priceOf(p.symbol)))),
    );
    for (final order in triggered) {
      _orders.remove(order); // keep legacy list in sync
      final res = _openPositionInternal(
        symbol: order.symbol,
        side: order.side,
        qty: order.qty,
        leverage: order.leverage,
        tradingType: order.tradingType,
        stopLoss: order.stopLoss,
        takeProfit: order.takeProfit,
        trailingStop: order.trailingStop,
        entryJournal: order.entryJournal,
        fillPrice: priceOf(order.symbol),
      );
      if (res.success) changed = true;
    }

    final prices = Map.fromEntries(
      _positions.map((p) => MapEntry(p.symbol, priceOf(p.symbol))),
    );
    final riskTriggers = _riskEngine.evaluateTriggers(_positions, prices);
    for (final trigger in riskTriggers) {
      final pos = _positions.firstWhere(
        (p) => p.id == trigger.positionId,
        orElse: () => _nullPos,
      );
      if (pos.id.isEmpty) continue;
      _closePositionInternal(pos, 1.0, trigger.triggerPrice, trigger.reason);
      changed = true;
    }

    // Publish EquityChangedEvent for other controllers to monitor margin risk
    final evBus = serviceLocator.isRegistered<EventBus>()
        ? serviceLocator<EventBus>()
        : EventBus.instance;
    evBus.publish<EquityChangedEvent>(EquityChangedEvent(
      equity: equity,
      unrealizedPnl: unrealizedPnl,
      marginUsed: usedMargin,
      freeMargin: freeMargin,
    ));

    // Check portfolio level liquidation and margin call warnings
    final warnings = _riskEngine.checkLiquidationWarnings(_positions, prices, _balance);
    for (final warning in warnings) {
      evBus.publish<LiquidationWarningEvent>(warning);
    }

    if (changed) {
      _saveState();
      notifyListeners();
    }
  }

  // ---------------- fee / spread — delegated to TradingEngine (Phase 5) ----------------

  double _computeFee({
    required MarketConfig config,
    required double notional,
    required double qty,
    required bool isMarketOrder,
  }) {
    return TradingEngine.calculateFee(
      config: config,
      notional: notional,
      qty: qty,
      isMarketOrder: isMarketOrder,
    );
  }


  // ---------------- trading actions ----------------

  /// Places an order. For market orders it executes immediately; otherwise the
  /// order is queued and filled when its trigger condition is met.
  TradeResult placeOrder({
    required String symbol,
    required OrderType type,
    required PositionSide side,
    required double qty,
    required double leverage,
    TradingType? tradingType,
    double? limitPrice,
    double? stopPrice,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    EntryJournal? entryJournal,
  }) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return TradeResult(success: false, error: 'Asset not found');
    if (qty <= 0) return TradeResult(success: false, error: 'Quantity must be positive');

    final tt = tradingType ?? defaultTradingType(asset.type);
    final config = MarketConfig.get(asset.type, tt);

    // Enforce market rules
    if (!config.shortSellingAllowed && side == PositionSide.short && tt != TradingType.spot) {
      return TradeResult(success: false, error: 'Short selling not allowed in ${tt.label} mode');
    }
    if (!config.leverageAllowed && leverage > 1.0) {
      return TradeResult(success: false, error: 'Leverage not available in ${tt.label} mode');
    }
    if (leverage > config.maxLeverage) {
      return TradeResult(success: false, error: 'Max leverage is ${config.maxLeverage}x');
    }

    // Validation: check min/max order size
    if (qty < asset.minOrderSize) {
      return TradeResult(success: false, error: 'Order quantity is below the minimum limit of ${asset.minOrderSize}');
    }
    if (qty > asset.maxOrderSize) {
      return TradeResult(success: false, error: 'Order quantity exceeds the maximum limit of ${asset.maxOrderSize}');
    }

    // For Spot Sell orders, validate immediately that we have enough holdings
    if (tt == TradingType.spot && side == PositionSide.short) {
      final existing = _positions.firstWhere(
        (p) => p.symbol == symbol && p.tradingType == TradingType.spot,
        orElse: () => _nullPos,
      );
      if (existing.id.isEmpty) {
        return TradeResult(success: false, error: 'You do not own any Spot assets for $symbol to sell');
      }
      if (qty > existing.qty) {
        return TradeResult(success: false, error: 'Insufficient spot holdings (you own ${existing.qty})');
      }
    }

    if (type == OrderType.market) {
      return _openPositionInternal(
        symbol: symbol,
        side: side,
        qty: qty,
        leverage: leverage,
        tradingType: tt,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        trailingStop: trailingStop,
        entryJournal: entryJournal,
        fillPrice: priceOf(symbol),
      );
    }

    // Validate trigger prices
    if ((type == OrderType.limit || type == OrderType.stopLimit) && limitPrice == null) {
      return TradeResult(success: false, error: 'Limit price required');
    }
    if ((type == OrderType.stop || type == OrderType.stopLimit) && stopPrice == null) {
      return TradeResult(success: false, error: 'Stop price required');
    }

    // Reserve check (estimate margin needed against best-known price)
    final isSpotSell = tt == TradingType.spot && side == PositionSide.short;
    if (!isSpotSell) {
      final estPrice = limitPrice ?? stopPrice ?? priceOf(symbol);
      final actualQty = config.lotSizeUsed ? qty * config.lotBaseUnits : qty;
      final estNotional = actualQty * estPrice;
      final estMargin = config.leverageAllowed ? estNotional / leverage : estNotional;
      final estFee = _computeFee(config: config, notional: estNotional, qty: qty, isMarketOrder: false);
      if (estMargin + estFee > (tt == TradingType.spot ? _balance : freeMargin)) {
        return TradeResult(
          success: false, 
          error: tt == TradingType.spot ? 'Insufficient balance for this order' : 'Insufficient free margin for this order',
        );
      }
    }

    _orders.insert(
      0,
      PendingOrder(
        id: _genId(),
        symbol: symbol,
        type: type,
        side: side,
        qty: qty,
        leverage: leverage,
        limitPrice: limitPrice,
        stopPrice: stopPrice,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        trailingStop: trailingStop,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        marketType: asset.type,
        tradingType: tt,
        entryJournal: entryJournal,
      ),
    );
    _saveState();
    notifyListeners();
    return TradeResult(success: true, message: '${type.label} order placed');
  }

  TradeResult _openPositionInternal({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double leverage,
    required double fillPrice,
    TradingType tradingType = TradingType.spot,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    EntryJournal? entryJournal,
  }) {
    final asset = getAssetBySymbol(symbol);
    if (asset == null) return TradeResult(success: false, error: 'Asset not found');

    // 1. Validation
    if (qty < asset.minOrderSize) {
      return TradeResult(success: false, error: 'Quantity below minimum limit: ${asset.minOrderSize}');
    }
    if (qty > asset.maxOrderSize) {
      return TradeResult(success: false, error: 'Quantity exceeds maximum limit: ${asset.maxOrderSize}');
    }

    final config = MarketConfig.get(asset.type, tradingType);
    final fee = TradingEngine.calculateFee(
      config: config,
      notional: qty * fillPrice,
      qty: qty,
      isMarketOrder: true,
    );

    // ==================== SPOT CONSOLIDATION ====================
    if (tradingType == TradingType.spot) {
      final evBus = serviceLocator.isRegistered<EventBus>()
          ? serviceLocator<EventBus>()
          : EventBus.instance;

      if (side == PositionSide.short) {
        // Spot Sell (reduce/close long position)
        final existing = _positions.firstWhere(
          (p) => p.symbol == symbol && p.tradingType == TradingType.spot,
          orElse: () => _nullPos,
        );
        if (existing.id.isEmpty) {
          return TradeResult(success: false, error: 'You do not own any Spot assets for $symbol to sell');
        }
        if (qty > existing.qty) {
          return TradeResult(success: false, error: 'Insufficient spot holdings (you own ${existing.qty})');
        }

        // Execution & P&L calculation
        final grossPnl = qty * (fillPrice - existing.entryPrice);
        final netPnl = grossPnl - fee;
        
        // Portfolio Updates
        existing.qty -= qty;
        existing.margin = existing.qty * existing.entryPrice;
        
        // Update balance: return the margin portion plus the net P&L
        _balance += (qty * existing.entryPrice) + netPnl;
        _realizedPnl += netPnl;

        final isFullClose = existing.qty <= 0.00001;
        
        // Register Trade / Analytics
        final now = DateTime.now().millisecondsSinceEpoch;
        final trade = Trade(
          id: _genId(),
          symbol: symbol,
          name: asset.name,
          side: PositionSide.long, // Spot trades are recorded as long closures
          qty: qty,
          entryPrice: existing.entryPrice,
          exitPrice: fillPrice,
          leverage: 1.0,
          pnlPct: (netPnl / (existing.entryPrice * qty)) * 100.0,
          pnl: netPnl,
          fees: fee,
          openedAt: existing.openedAt,
          closedAt: now,
          marketType: asset.type,
          tradingType: tradingType,
          closeReason: 'manual',
          notes: entryJournal?.reason ?? '',
          entryJournal: entryJournal,
        );

        if (isFullClose) {
          _positions.removeWhere((p) => p.id == existing.id);
          _positionController.removePositionDirectly(existing.id);
        } else {
          _positionController.notifyListenersDirectly();
        }

        // Publish PositionClosedEvent to trigger auto-journaling and gamification
        evBus.publish<PositionClosedEvent>(PositionClosedEvent(
          positionId: existing.id,
          symbol: symbol,
          pnl: netPnl,
          exitPrice: fillPrice,
          closeReason: 'manual',
          trade: trade,
        ));

        _registerTradeDay(now);
        _saveState();
        notifyListeners();
        return TradeResult(success: true, message: 'Spot Sell executed successfully');
      } else {
        // Spot Buy (Long)
        final totalCost = qty * fillPrice + fee;
        if (totalCost > _balance) {
          return TradeResult(success: false, error: 'Insufficient balance to buy Spot asset');
        }

        final existing = _positions.firstWhere(
          (p) => p.symbol == symbol && p.tradingType == TradingType.spot,
          orElse: () => _nullPos,
        );

        if (existing.id.isNotEmpty) {
          // Consolidate!
          final double oldQty = existing.qty;
          final double newQty = oldQty + qty;
          final double newEntryPrice = (oldQty * existing.entryPrice + qty * fillPrice) / newQty;
          
          existing.qty = newQty;
          existing.entryPrice = newEntryPrice;
          existing.margin = newQty * newEntryPrice;
          existing.fees += fee;
          
          _balance -= totalCost;
          
          _positionController.notifyListenersDirectly();
        } else {
          // Create new Position
          final newPos = Position(
            id: _genId(),
            symbol: symbol,
            side: PositionSide.long,
            qty: qty,
            entryPrice: fillPrice,
            leverage: 1.0,
            margin: qty * fillPrice,
            fees: fee,
            openedAt: DateTime.now().millisecondsSinceEpoch,
            marketType: asset.type,
            tradingType: tradingType,
            stopLoss: stopLoss,
            takeProfit: takeProfit,
            trailingStop: trailingStop,
          );
          
          _positions.add(newPos);
          _positionController.addPositionDirectly(newPos);
          _balance -= totalCost;
        }

        _registerTradeDay(DateTime.now().millisecondsSinceEpoch);
        _evaluateGamification();
        _saveState();
        notifyListeners();
        return TradeResult(success: true, message: 'Spot Buy executed successfully');
      }
    }

    // ==================== FUTURES TRADING ====================
    // Enforce Futures validation & margin
    final margin = (qty * fillPrice) / leverage;
    final totalCost = margin + fee;
    if (totalCost > freeMargin) {
      return TradeResult(success: false, error: 'Insufficient free margin to open Futures position');
    }

    final newPos = Position(
      id: _genId(),
      symbol: symbol,
      side: side,
      qty: qty,
      entryPrice: fillPrice,
      leverage: leverage,
      margin: margin,
      fees: fee,
      openedAt: DateTime.now().millisecondsSinceEpoch,
      marketType: asset.type,
      tradingType: tradingType,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: trailingStop,
      marginMode: MarginMode.isolated, // isolated margin preparation
    );

    _positions.add(newPos);
    _positionController.addPositionDirectly(newPos);
    _balance -= totalCost;

    _registerTradeDay(newPos.openedAt);
    _evaluateGamification();
    _saveState();
    notifyListeners();
    return TradeResult(success: true, message: 'Futures ${side.label} position opened');
  }

  /// Closes [fraction] (0..1) of a position by id.
  TradeResult closePosition(String positionId, {double fraction = 1.0}) {
    final p = _positions.firstWhere((x) => x.id == positionId, orElse: () => _nullPos);
    if (p.id.isEmpty) return TradeResult(success: false, error: 'Position not found');
    fraction = fraction.clamp(0.0001, 1.0);

    // Phase 4: Delegate to PositionController
    final result = _positionController.closePosition(
      positionId,
      fraction: fraction,
      exitPrice: priceOf(p.symbol),
      reason: 'manual',
      genTradeId: _genId(),
    );

    if (result.success) {
      // Keep legacy _positions list in sync
      if (fraction >= 1.0) {
        _positions.removeWhere((x) => x.id == positionId);
      }
      // Return pnl to legacy balance (_onPositionClosed handles _trades / gamification)
      _balance += (result.pnl ?? 0.0) + (p.margin * fraction);
      _saveState();
      notifyListeners();
    }
    return TradeResult(
      success: result.success,
      error: result.error,
      message: result.message,
    );
  }

  void _closePositionInternal(Position p, double fraction, double exitPrice, String reason) {
    // Phase 4: Delegate to PositionController
    final result = _positionController.closePosition(
      p.id,
      fraction: fraction,
      exitPrice: exitPrice,
      reason: reason,
      genTradeId: _genId(),
    );

    if (result.success) {
      // Keep legacy _positions list in sync
      if (fraction >= 1.0) {
        _positions.removeWhere((x) => x.id == p.id);
      }
      // Return margin + pnl to legacy balance
      _balance += (result.pnl ?? 0.0) + (p.margin * fraction);
    }
    // _onPositionClosed listener handles _trades / gamification / win-loss
  }

  /// Updates the risk controls on an open position.
  void updatePositionRisk(String positionId, {double? stopLoss, double? takeProfit, double? trailingStop, bool clearTrailing = false}) {
    // Phase 4: Delegate to PositionController
    _positionController.updatePositionRisk(
      positionId,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: trailingStop,
      clearTrailing: clearTrailing,
      currentPrice: priceOf(
        _positions.firstWhere((p) => p.id == positionId, orElse: () => _nullPos).symbol,
      ),
    );

    // Keep legacy list in sync
    final p = _positions.firstWhere((x) => x.id == positionId, orElse: () => _nullPos);
    if (p.id.isEmpty) return;
    p.stopLoss = stopLoss;
    p.takeProfit = takeProfit;
    if (clearTrailing) {
      p.trailingStop = null;
      p.trailingAnchor = null;
    } else if (trailingStop != null) {
      p.trailingStop = trailingStop;
      p.trailingAnchor = priceOf(p.symbol);
    }
    _saveState();
    notifyListeners();
  }

  void cancelOrder(String orderId) {
    // Phase 4: Delegate to OrderController
    _orderController.cancelOrder(orderId);
    _orders.removeWhere((o) => o.id == orderId); // keep legacy list in sync
    _saveState();
    notifyListeners();
  }

  /// Attaches post-trade reflection journal to a closed trade.
  void attachExitJournal(String tradeId, ExitJournal journal) {
    // Phase 4: Delegate to JournalController
    _journalController.attachExitJournal(tradeId, journal);
    // Also update legacy list
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx >= 0) {
      _trades[idx].exitJournal = journal;
      _saveState();
      notifyListeners();
    }
  }

  void updateTradeNotes(String tradeId, String notes) {
    // Phase 4: Delegate to JournalController
    _journalController.updateTradeNotes(tradeId, notes);
    // Also update legacy list
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx >= 0) {
      _trades[idx].notes = notes;
      _saveState();
      notifyListeners();
    }
  }

  // ---------------- gamification ----------------
  void _evaluateGamification() {
    // Phase 4: Delegate to GamificationController
    final s = stats;
    _gamificationController.evaluate(s);
    // Sync legacy sets so existing UI getters remain accurate
    _unlockedAchievements
      ..clear()
      ..addAll(_gamificationController.unlockedAchievements);
    _completedChallenges
      ..clear()
      ..addAll(_gamificationController.completedChallenges);
  }

  void _registerTradeDay(int ts) {
    final dk = dayKey(ts);
    _tradesPerDay[dk] = (_tradesPerDay[dk] ?? 0) + 1;
  }

  // ---------------- account management ----------------
  /// Sets starting capital for a brand new account (no trades yet).
  void applyStartingCapital(double capital) {
    if (_trades.isEmpty && _positions.isEmpty && _orders.isEmpty) {
      startingCapital = capital;
      _balance = capital;
      _saveState();
      notifyListeners();
    }
  }

  Future<void> resetAccount({double? capital}) async {
    startingCapital = capital ?? startingCapital;
    _balance = startingCapital;
    _positions.clear();
    _orders.clear();
    _trades.clear();
    _favorites.clear();
    _news.clear();
    _realizedPnl = 0;
    _wins = 0;
    _losses = 0;
    _currentWinStreak = 0;
    _maxWinStreak = 0;
    _riskDisciplineTrades = 0;
    _riskRewardTrades = 0;
    _ruleViolations = 0;
    _revengeTrades = 0;
    _dailyRealized.clear();
    _tradesPerDay.clear();
    _lastLossClosedAt = 0;
    _lastTradeNotional = 0;
    _unlockedAchievements.clear();
    _completedChallenges.clear();
    _recentUnlocks.clear();
    // Phase 4: Reset controllers
    _gamificationController.reset();
    _generateNewsArticle();
    notifyListeners();
    // Phase 8: Use persistence service
    await _persistence.delete(_storageKey);
  }

  // ---------------- persistence (Phase 8) ----------------
  PersistenceService get _persistence {
    if (serviceLocator.isRegistered<PersistenceService>()) {
      return serviceLocator<PersistenceService>();
    }
    // Inline fallback using direct SharedPreferences (backward compat)
    return _FallbackSharedPrefs._instance;
  }

  Future<void> _loadState() async {
    try {
      final raw = await _persistence.readString(_storageKey);
      if (raw == null) return;
      final Map<String, dynamic> s = jsonDecode(raw);
      startingCapital = (s['startingCapital'] as num?)?.toDouble() ?? startingBalance;
      _balance = (s['balance'] as num?)?.toDouble() ?? startingCapital;
      _positions
        ..clear()
        ..addAll((s['positions'] as List? ?? []).map((p) => Position.fromJson(p)));
      _orders
        ..clear()
        ..addAll((s['orders'] as List? ?? []).map((o) => PendingOrder.fromJson(o)));
      _trades
        ..clear()
        ..addAll((s['trades'] as List? ?? []).map((t) => Trade.fromJson(t)));
      _favorites
        ..clear()
        ..addAll(List<String>.from(s['favorites'] ?? []));
      _news
        ..clear()
        ..addAll((s['news'] as List? ?? []).map((n) => NewsArticle.fromJson(n)));
      _realizedPnl         = (s['realizedPnl'] as num?)?.toDouble() ?? 0.0;
      _wins                = s['wins'] ?? 0;
      _losses              = s['losses'] ?? 0;
      _currentWinStreak    = s['currentWinStreak'] ?? 0;
      _maxWinStreak        = s['maxWinStreak'] ?? 0;
      _riskDisciplineTrades= s['riskDisciplineTrades'] ?? 0;
      _riskRewardTrades    = s['riskRewardTrades'] ?? 0;
      _ruleViolations      = s['ruleViolations'] ?? 0;
      _revengeTrades       = s['revengeTrades'] ?? 0;
      _lastLossClosedAt    = s['lastLossClosedAt'] ?? 0;
      _lastTradeNotional   = (s['lastTradeNotional'] as num?)?.toDouble() ?? 0.0;
      (s['dailyRealized'] as Map?)?.forEach((k, v) => _dailyRealized[k] = (v as num).toDouble());
      (s['tradesPerDay']  as Map?)?.forEach((k, v) => _tradesPerDay[k] = v as int);
      _unlockedAchievements..clear()..addAll(List<String>.from(s['unlockedAchievements'] ?? []));
      _completedChallenges..clear()..addAll(List<String>.from(s['completedChallenges'] ?? []));
      // Phase 4: sync controllers from loaded state
      _gamificationController.fromJson(s);
      _positionController.fromJson(s);
      _orderController.fromJson(s);
      _portfolioController.fromJson(s);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveState() async {
    try {
      await _persistence.writeString(
        _storageKey,
        jsonEncode({
          'startingCapital':      startingCapital,
          'balance':              _balance,
          'positions':            _positions.map((p) => p.toJson()).toList(),
          'orders':               _orders.map((o) => o.toJson()).toList(),
          'trades':               _trades.map((t) => t.toJson()).toList(),
          'favorites':            _favorites,
          'news':                 _news.map((n) => n.toJson()).toList(),
          'realizedPnl':          _realizedPnl,
          'wins':                 _wins,
          'losses':               _losses,
          'currentWinStreak':     _currentWinStreak,
          'maxWinStreak':         _maxWinStreak,
          'riskDisciplineTrades': _riskDisciplineTrades,
          'riskRewardTrades':     _riskRewardTrades,
          'ruleViolations':       _ruleViolations,
          'revengeTrades':        _revengeTrades,
          'lastLossClosedAt':     _lastLossClosedAt,
          'lastTradeNotional':    _lastTradeNotional,
          'dailyRealized':        _dailyRealized,
          'tradesPerDay':         _tradesPerDay,
          'unlockedAchievements': _unlockedAchievements.toList(),
          'completedChallenges':  _completedChallenges.toList(),
        }),
      );
    } catch (_) {}
  }

  String _genId() => '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';

  static final Position _nullPos = Position(
    id: '',
    symbol: '',
    side: PositionSide.long,
    qty: 0,
    entryPrice: 0,
    leverage: 1,
    margin: 0,
    fees: 0,
    openedAt: 0,
    marketType: MarketType.crypto,
  );

  @override
  void dispose() {
    _repositorySubscription?.cancel();
    _priceUpdateController.close();
    _closeCryptoWs();
    _wsReconnectTimer?.cancel();
    _timer?.cancel();
    _marketScheduler?.dispose();
    _portfolioController.dispose();
    _positionController.dispose();
    _orderController.dispose();
    _journalController.dispose();
    _gamificationController.dispose();
    _logger?.info('TradingProvider disposed');
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Fallback persistence: direct SharedPreferences when service locator not
// initialised. Only used during early startup or legacy test paths.
// ---------------------------------------------------------------------------
class _FallbackSharedPrefs implements PersistenceService {
  static final _FallbackSharedPrefs _instance = _FallbackSharedPrefs._();
  _FallbackSharedPrefs._();

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override Future<String?> readString(String k) async => (await _prefs).getString(k);
  @override Future<void> writeString(String k, String v) async { await (await _prefs).setString(k, v); }
  @override Future<List<String>?> readStringList(String k) async => (await _prefs).getStringList(k);
  @override Future<void> writeStringList(String k, List<String> v) async { await (await _prefs).setStringList(k, v); }
  @override Future<bool> readBool(String k, {bool defaultValue = false}) async => (await _prefs).getBool(k) ?? defaultValue;
  @override Future<void> writeBool(String k, bool v) async { await (await _prefs).setBool(k, v); }
  @override Future<int> readInt(String k, {int defaultValue = 0}) async => (await _prefs).getInt(k) ?? defaultValue;
  @override Future<void> writeInt(String k, int v) async { await (await _prefs).setInt(k, v); }
  @override Future<double> readDouble(String k, {double defaultValue = 0.0}) async => (await _prefs).getDouble(k) ?? defaultValue;
  @override Future<void> writeDouble(String k, double v) async { await (await _prefs).setDouble(k, v); }
  @override Future<void> delete(String k) async { await (await _prefs).remove(k); }
  @override Future<void> deleteAll() async { await (await _prefs).clear(); }
  @override Future<bool> containsKey(String k) async => (await _prefs).containsKey(k);
  @override Future<Set<String>> getKeys() async => (await _prefs).getKeys();
}


