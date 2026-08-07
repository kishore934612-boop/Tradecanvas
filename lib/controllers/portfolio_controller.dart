/// Portfolio Controller
/// 
/// Manages account balance, equity, margin, and P&L calculations.
/// Handles portfolio-level financial state.
library;

import 'package:flutter/foundation.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/logging/logger.dart';

class PortfolioController extends ChangeNotifier {
  final EventBus _eventBus;
  final Logger _logger;
  
  // Portfolio state
  double _balance;
  double _startingCapital;
  double _realizedPnl = 0.0;
  final Map<String, double> _dailyRealized = {}; // dayKey -> realized pnl
  
  PortfolioController({
    required this._eventBus,
    required this._logger,
    required double initialBalance,
  })  : _balance = initialBalance,
        _startingCapital = initialBalance {
    _logger.info('PortfolioController initialized with balance: \$$initialBalance');
    _subscribeToEvents();
  }
  
  // ============================================================
  // GETTERS
  // ============================================================
  
  /// Current account balance
  double get balance => _balance;
  
  /// Starting capital
  double get startingCapital => _startingCapital;
  
  /// Total realized P&L
  double get realizedPnl => _realizedPnl;
  
  /// Calculate equity (requires external unrealized P&L and used margin)
  double calculateEquity(double unrealizedPnl, double usedMargin) {
    return _balance + usedMargin + unrealizedPnl;
  }
  
  /// Calculate free margin (requires external equity and used margin)
  double calculateFreeMargin(double equity, double usedMargin) {
    return equity - usedMargin;
  }
  
  /// Calculate margin level (requires external equity and used margin)
  double calculateMarginLevel(double equity, double usedMargin) {
    return usedMargin > 0 ? (equity / usedMargin) * 100.0 : 0.0;
  }
  
  /// Calculate total return percentage
  double calculateTotalReturnPct(double equity) {
    return _startingCapital > 0 
        ? ((equity - _startingCapital) / _startingCapital) * 100.0 
        : 0.0;
  }
  
  /// Get daily P&L (requires external unrealized P&L)
  double getDailyPnl(double unrealizedPnl) {
    final today = _dayKey(DateTime.now().millisecondsSinceEpoch);
    return (_dailyRealized[today] ?? 0.0) + unrealizedPnl;
  }
  
  // ============================================================
  // ACTIONS
  // ============================================================
  
  /// Deposit funds into account
  void deposit(double amount) {
    if (amount <= 0) {
      _logger.warning('Invalid deposit amount: $amount');
      return;
    }
    
    _balance += amount;
    _logger.info('Deposited \$$amount, new balance: \$$_balance');
    
    _eventBus.publish<BalanceChangedEvent>(BalanceChangedEvent.fromChange(
      balance: _balance,
      change: amount,
      reason: 'deposit',
    ));
    
    notifyListeners();
  }
  
  /// Withdraw funds from account
  void withdraw(double amount) {
    if (amount <= 0) {
      _logger.warning('Invalid withdrawal amount: $amount');
      return;
    }
    
    if (amount > _balance) {
      _logger.error('Insufficient balance for withdrawal: $amount > $_balance');
      return;
    }
    
    _balance -= amount;
    _logger.info('Withdrew \$$amount, new balance: \$$_balance');
    
    _eventBus.publish<BalanceChangedEvent>(BalanceChangedEvent.fromChange(
      balance: _balance,
      change: -amount,
      reason: 'withdrawal',
    ));
    
    notifyListeners();
  }
  
  /// Record realized P&L from closed position
  void recordRealized(double pnl, int timestamp) {
    _realizedPnl += pnl;
    _balance += pnl;
    
    // Track daily realized
    final dayKey = _dayKey(timestamp);
    _dailyRealized[dayKey] = (_dailyRealized[dayKey] ?? 0.0) + pnl;
    
    _logger.info('Realized P&L: \$$pnl, total realized: \$$_realizedPnl, balance: \$$_balance');
    
    _eventBus.publish<RealizedPnlEvent>(RealizedPnlEvent(
      pnl: pnl,
      totalRealized: _realizedPnl,
      newBalance: _balance,
    ));
    
    _eventBus.publish<BalanceChangedEvent>(BalanceChangedEvent.fromChange(
      balance: _balance,
      change: pnl,
      reason: 'position_closed',
    ));
    
    notifyListeners();
  }
  
  /// Set starting capital (only for new accounts)
  void setStartingCapital(double capital, {bool hasPositions = false}) {
    if (hasPositions) {
      _logger.warning('Cannot change starting capital with open positions');
      return;
    }
    
    _startingCapital = capital;
    _balance = capital;
    _logger.info('Starting capital set to: \$$capital');
    notifyListeners();
  }
  
  // ============================================================
  // STATE MANAGEMENT
  // ============================================================
  
  /// Save state to map
  Map<String, dynamic> toJson() {
    return {
      'balance': _balance,
      'startingCapital': _startingCapital,
      'realizedPnl': _realizedPnl,
      'dailyRealized': _dailyRealized,
    };
  }
  
  /// Load state from map
  void fromJson(Map<String, dynamic> json) {
    _balance = (json['balance'] as num?)?.toDouble() ?? _startingCapital;
    _startingCapital = (json['startingCapital'] as num?)?.toDouble() ?? _startingCapital;
    _realizedPnl = (json['realizedPnl'] as num?)?.toDouble() ?? 0.0;
    
    final dailyData = json['dailyRealized'] as Map<String, dynamic>?;
    if (dailyData != null) {
      _dailyRealized.clear();
      dailyData.forEach((key, value) {
        _dailyRealized[key] = (value as num).toDouble();
      });
    }
    
    _logger.info('Portfolio state loaded: balance=\$$_balance, realized=\$$_realizedPnl');
    notifyListeners();
  }
  
  // ============================================================
  // PRIVATE METHODS
  // ============================================================
  
  void _subscribeToEvents() {
    // Portfolio controller primarily emits events
    // It can subscribe to TradeClosedEvent if needed
    _logger.debug('Portfolio event subscriptions initialized');
  }
  
  String _dayKey(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
  
  @override
  void dispose() {
    _logger.info('PortfolioController disposed');
    super.dispose();
  }
}
