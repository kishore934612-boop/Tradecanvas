/// Journal Controller
///
/// Manages the trading journal — closed trade records, notes, and
/// post-trade reflections.  Subscribes to PositionClosedEvent to
/// automatically capture every trade.
library;

import 'package:flutter/foundation.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/logging/logger.dart';

class JournalController extends ChangeNotifier {
  final EventBus _eventBus;
  final Logger _logger;

  final List<Trade> _trades = [];

  JournalController({
    required this._eventBus,
    required this._logger,
  }) {
    _logger.info('JournalController initialized');
    _subscribeToEvents();
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<Trade> get trades => List.unmodifiable(_trades);

  Trade? getTrade(String tradeId) {
    try {
      return _trades.firstWhere((t) => t.id == tradeId);
    } catch (_) {
      return null;
    }
  }

  List<Trade> getTradesBySymbol(String symbol) =>
      _trades.where((t) => t.symbol == symbol).toList();

  List<Trade> getTradesInDateRange(DateTime start, DateTime end) {
    final s = start.millisecondsSinceEpoch;
    final e = end.millisecondsSinceEpoch;
    return _trades.where((t) => t.openedAt >= s && t.openedAt <= e).toList();
  }

  List<Trade> get winningTrades => _trades.where((t) => t.pnl > 0).toList();
  List<Trade> get losingTrades  => _trades.where((t) => t.pnl < 0).toList();
  int get tradeCount => _trades.length;

  // ============================================================
  // ACTIONS
  // ============================================================

  /// Called directly when a trade is created (e.g. loaded from persistence).
  void addTrade(Trade trade) {
    _trades.insert(0, trade);
    notifyListeners();
  }

  /// Bulk-load trades — used by state restore.
  void setTrades(List<Trade> trades) {
    _trades
      ..clear()
      ..addAll(trades);
    notifyListeners();
  }

  /// Attach a post-trade exit journal to a closed trade.
  void attachExitJournal(String tradeId, ExitJournal journal) {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx < 0) {
      _logger.warning('attachExitJournal: trade $tradeId not found');
      return;
    }
    _trades[idx].exitJournal = journal;
    _logger.info('Exit journal attached to trade $tradeId');
    notifyListeners();
  }

  /// Update free-text notes on a trade.
  void updateTradeNotes(String tradeId, String notes) {
    final idx = _trades.indexWhere((t) => t.id == tradeId);
    if (idx < 0) {
      _logger.warning('updateTradeNotes: trade $tradeId not found');
      return;
    }
    _trades[idx].notes = notes;
    _logger.info('Notes updated for trade $tradeId');
    notifyListeners();
  }

  /// Basic statistics used by analytics screens.
  Map<String, dynamic> getStats() {
    if (_trades.isEmpty) return {};

    final wins   = _trades.where((t) => t.pnl > 0).toList();
    final losses = _trades.where((t) => t.pnl < 0).toList();

    final totalPnl  = _trades.fold(0.0, (s, t) => s + t.pnl);
    final avgPnl    = totalPnl / _trades.length;
    final avgWin    = wins.isEmpty ? 0.0
        : wins.fold(0.0, (s, t) => s + t.pnl) / wins.length;
    final avgLoss   = losses.isEmpty ? 0.0
        : losses.fold(0.0, (s, t) => s + t.pnl) / losses.length;
    final largestWin  = wins.isEmpty   ? 0.0 : wins.map((t) => t.pnl).reduce((a, b) => a > b ? a : b);
    final largestLoss = losses.isEmpty ? 0.0 : losses.map((t) => t.pnl).reduce((a, b) => a < b ? a : b);
    final winRate  = _trades.isEmpty ? 0.0 : wins.length / _trades.length * 100;

    return {
      'total':       _trades.length,
      'wins':        wins.length,
      'losses':      losses.length,
      'winRate':     winRate,
      'totalPnl':    totalPnl,
      'avgPnl':      avgPnl,
      'avgWin':      avgWin,
      'avgLoss':     avgLoss,
      'largestWin':  largestWin,
      'largestLoss': largestLoss,
    };
  }

  // ============================================================
  // EVENTS
  // ============================================================

  void _subscribeToEvents() {
    // Auto-capture every completed trade into the journal
    _eventBus.on<TradeCompletedEvent>().listen((event) {
      if (event.trade != null) {
        _trades.insert(0, event.trade!);
        _logger.info(
          'Journal: recorded trade ${event.trade!.id} (${event.trade!.symbol}, P&L: \$${event.trade!.pnl.toStringAsFixed(2)})',
        );
        notifyListeners();
      }
    });
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  Map<String, dynamic> toJson() => {
        'trades': _trades.map((t) => t.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    _trades.clear();
    final data = json['trades'] as List<dynamic>?;
    if (data != null) {
      for (final item in data) {
        try {
          _trades.add(Trade.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          _logger.error('Failed to load trade: $e');
        }
      }
    }
    _logger.info('Journal state loaded: ${_trades.length} trades');
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.info('JournalController disposed');
    super.dispose();
  }
}
