import 'dart:convert';
import 'package:app/services/persistence/sqlite_db_helper.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/domain/repositories/portfolio_repository.dart';
import 'package:app/domain/repositories/position_repository.dart';
import 'package:app/domain/repositories/trade_repository.dart';
import 'package:app/domain/repositories/learning_repository.dart';
import 'package:app/domain/repositories/watchlist_repository.dart';
import 'package:app/domain/repositories/statistics_repository.dart';
import 'package:app/constants/markets.dart';

// -----------------------------------------------------------------
// 1. PORTFOLIO REPOSITORY
// -----------------------------------------------------------------
class SqlitePortfolioRepository implements PortfolioRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<double> getInitialBalance(String userId) async {
    final res = await _db.query('portfolio', where: 'user_id = ?', whereArgs: [userId]);
    if (res.isEmpty) return 100000.0;
    return (res.first['initial_balance'] as num).toDouble();
  }

  @override
  Future<double> getAvailableBalance(String userId) async {
    final res = await _db.query('portfolio', where: 'user_id = ?', whereArgs: [userId]);
    if (res.isEmpty) return 100000.0;
    return (res.first['available_balance'] as num).toDouble();
  }

  @override
  Future<void> saveBalances(String userId, double initial, double available) async {
    await _db.insert('portfolio', {
      'user_id': userId,
      'initial_balance': initial,
      'available_balance': available,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> clearPortfolio(String userId) async {
    await _db.delete('portfolio', 'user_id = ?', [userId]);
  }
}

// -----------------------------------------------------------------
// 2. POSITION REPOSITORY
// -----------------------------------------------------------------
class SqlitePositionRepository implements PositionRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<List<Position>> getPositions(String userId) async {
    final res = await _db.query('positions', where: 'user_id = ?', whereArgs: [userId]);
    return res.map((row) {
      return Position(
        id: row['position_id'] as String,
        symbol: row['symbol'] as String,
        side: sideFromId(row['direction'] as String? ?? 'long'),
        qty: (row['quantity'] as num).toDouble(),
        entryPrice: (row['entry_price'] as num).toDouble(),
        leverage: (row['leverage'] as num? ?? 1.0).toDouble(),
        margin: (row['margin'] as num).toDouble(),
        fees: 0.0,
        openedAt: DateTime.parse(row['opened_at'] as String).millisecondsSinceEpoch,
        marketType: marketTypeFromId(row['market_type'] as String? ?? 'crypto') ?? MarketType.crypto,
        tradingType: row['market_type'] == 'futures' ? TradingType.futures : TradingType.spot,
        stopLoss: (row['stop_loss'] as num?)?.toDouble(),
        takeProfit: (row['take_profit'] as num?)?.toDouble(),
      );
    }).toList();
  }

  @override
  Future<void> addPosition(String userId, Position p) async {
    await _db.insert('positions', {
      'position_id': p.id,
      'user_id': userId,
      'symbol': p.symbol,
      'market_type': p.tradingType.id,
      'entry_price': p.entryPrice,
      'quantity': p.qty,
      'leverage': p.leverage,
      'margin': p.margin,
      'direction': p.side.id,
      'stop_loss': p.stopLoss,
      'take_profit': p.takeProfit,
      'opened_at': DateTime.fromMillisecondsSinceEpoch(p.openedAt).toIso8601String(),
    });
  }

  @override
  Future<void> updatePosition(String userId, Position p) async {
    await _db.update(
      'positions',
      {
        'quantity': p.qty,
        'entry_price': p.entryPrice,
        'margin': p.margin,
        'stop_loss': p.stopLoss,
        'take_profit': p.takeProfit,
      },
      'position_id = ? AND user_id = ?',
      [p.id, userId],
    );
  }

  @override
  Future<void> removePosition(String userId, String positionId) async {
    await _db.delete('positions', 'position_id = ? AND user_id = ?', [positionId, userId]);
  }

  @override
  Future<void> clearPositions(String userId) async {
    await _db.delete('positions', 'user_id = ?', [userId]);
  }
}

// -----------------------------------------------------------------
// 3. TRADE REPOSITORY
// -----------------------------------------------------------------
class SqliteTradeRepository implements TradeRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<List<Trade>> getTrades(String userId) async {
    final res = await _db.query('trades', where: 'user_id = ?', whereArgs: [userId], orderBy: 'closed_at DESC');
    return res.map((row) {
      final entryJ = row['entry_journal'] != null && (row['entry_journal'] as String).isNotEmpty
          ? EntryJournal.fromJson(jsonDecode(row['entry_journal'] as String))
          : null;
      final exitJ = row['exit_journal'] != null && (row['exit_journal'] as String).isNotEmpty
          ? ExitJournal.fromJson(jsonDecode(row['exit_journal'] as String))
          : null;

      return Trade(
        id: row['trade_id'] as String,
        symbol: row['symbol'] as String,
        name: row['symbol'] as String,
        side: sideFromId(row['direction'] as String? ?? 'long'),
        qty: (row['quantity'] as num).toDouble(),
        entryPrice: (row['entry_price'] as num).toDouble(),
        exitPrice: (row['exit_price'] as num).toDouble(),
        leverage: (row['leverage'] as num? ?? 1.0).toDouble(),
        fees: (row['entry_fee'] as num? ?? 0.0).toDouble() + (row['exit_fee'] as num? ?? 0.0).toDouble(),
        openedAt: DateTime.parse(row['opened_at'] as String).millisecondsSinceEpoch,
        closedAt: DateTime.parse(row['closed_at'] as String).millisecondsSinceEpoch,
        pnl: (row['realized_pnl'] as num).toDouble(),
        pnlPct: (row['return_pct'] as num).toDouble(),
        marketType: MarketType.crypto,
        tradingType: row['market_type'] == 'futures' ? TradingType.futures : TradingType.spot,
        closeReason: row['closed_reason'] as String? ?? 'manual',
        entryJournal: entryJ,
        exitJournal: exitJ,
        notes: row['notes'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<void> addTrade(String userId, Trade t) async {
    // Determine order type and fee structures
    final double entryFee = t.fees / 2;
    final double exitFee = t.fees / 2;

    await _db.insert('trades', {
      'trade_id': t.id,
      'user_id': userId,
      'symbol': t.symbol,
      'market_type': t.tradingType.id,
      'direction': t.side.id,
      'entry_price': t.entryPrice,
      'exit_price': t.exitPrice,
      'quantity': t.qty,
      'leverage': t.leverage,
      'entry_fee': entryFee,
      'exit_fee': exitFee,
      'realized_pnl': t.pnl,
      'return_pct': t.pnlPct,
      'duration': (t.durationMs / 1000).round(),
      'closed_reason': t.closeReason,
      'order_type': 'market', // default metadata
      'trade_status': t.closeReason == 'liquidation' ? 'liquidated' : 'closed',
      'opened_at': DateTime.fromMillisecondsSinceEpoch(t.openedAt).toIso8601String(),
      'closed_at': DateTime.fromMillisecondsSinceEpoch(t.closedAt).toIso8601String(),
    });

    // Write accompanying journal details directly to journal_entries row
    if (t.exitJournal != null || t.entryJournal != null || t.notes.isNotEmpty) {
      await _db.insert('journal_entries', {
        'journal_id': '${t.id}_journal',
        'user_id': userId,
        'trade_id': t.id,
        'title': '${t.symbol} Trade Journal',
        'notes': t.notes,
        'emotion': t.exitJournal?.emotionalState ?? '',
        'mistakes': t.exitJournal?.whatWentWrong ?? '',
        'lessons': t.exitJournal?.lessonsLearned ?? '',
        'rating': t.exitJournal != null ? 5 : 0,
        'tags': '[]',
        'screenshots': '[]',
        'strategy': t.entryJournal?.strategy ?? '',
        'created_at': DateTime.fromMillisecondsSinceEpoch(t.closedAt).toIso8601String(),
      });
    }
  }

  @override
  Future<void> updateTradeJournal(String userId, String tradeId, ExitJournal journal) async {
    // Retrieve trade for closed time reference
    final rows = await _db.query('trades', where: 'trade_id = ? AND user_id = ?', whereArgs: [tradeId, userId]);
    final String timeStr = rows.isNotEmpty ? rows.first['closed_at'] as String : DateTime.now().toIso8601String();

    await _db.insert('journal_entries', {
      'journal_id': '${tradeId}_journal',
      'user_id': userId,
      'trade_id': tradeId,
      'title': 'Trade Reflection',
      'emotion': journal.emotionalState,
      'mistakes': journal.whatWentWrong,
      'lessons': journal.lessonsLearned,
      'rating': 5,
      'tags': '[]',
      'screenshots': '[]',
      'created_at': timeStr,
    });
  }

  @override
  Future<void> updateTradeNotes(String userId, String tradeId, String notes) async {
    await _db.execute(
      'UPDATE journal_entries SET notes = ? WHERE trade_id = ? AND user_id = ?',
      [notes, tradeId, userId],
    );
  }

  @override
  Future<void> clearTrades(String userId) async {
    await _db.delete('trades', 'user_id = ?', [userId]);
    await _db.delete('journal_entries', 'user_id = ?', [userId]);
  }
}

// -----------------------------------------------------------------
// 4. LEARNING REPOSITORY
// -----------------------------------------------------------------
class SqliteLearningRepository implements LearningRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<void> saveProgress(
    String userId,
    String lessonId, {
    required bool completed,
    int? completionTime,
    int? quizScore,
    String? lastOpened,
  }) async {
    await _db.insert('learning_progress', {
      'user_id': userId,
      'lesson_id': lessonId,
      'completed': completed ? 1 : 0,
      'completion_time': completionTime,
      'quiz_score': quizScore,
      'last_opened': lastOpened,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>> getProgress(String userId) async {
    final res = await _db.query('learning_progress', where: 'user_id = ?', whereArgs: [userId]);
    final Map<String, dynamic> lessonsMap = {};
    final Map<String, dynamic> quizzesMap = {};

    for (final row in res) {
      final String lessonId = row['lesson_id'] as String;
      final bool completed = (row['completed'] as int) == 1;
      
      lessonsMap[lessonId] = {
        'id': lessonId,
        'isCompleted': completed,
        'lastReadTimestamp': row['last_opened'] != null ? DateTime.parse(row['last_opened'] as String).millisecondsSinceEpoch : null,
      };

      if (row['quiz_score'] != null) {
        quizzesMap[lessonId] = {
          'id': lessonId,
          'isCompleted': completed,
          'highestScore': row['quiz_score'] as int,
        };
      }
    }

    return {
      'lessons': lessonsMap,
      'quizzes': quizzesMap,
    };
  }

  @override
  Future<void> clearProgress(String userId) async {
    await _db.delete('learning_progress', 'user_id = ?', [userId]);
  }
}

// -----------------------------------------------------------------
// 5. WATCHLIST REPOSITORY
// -----------------------------------------------------------------
class SqliteWatchlistRepository implements WatchlistRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<List<String>> getWatchlist(String userId) async {
    final res = await _db.query('watchlist', where: 'user_id = ?', whereArgs: [userId], orderBy: 'display_order ASC');
    return res.map((row) => row['symbol'] as String).toList();
  }

  @override
  Future<void> addToWatchlist(String userId, String symbol) async {
    await _db.insert('watchlist', {
      'user_id': userId,
      'symbol': symbol,
      'display_order': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> removeFromWatchlist(String userId, String symbol) async {
    await _db.delete('watchlist', 'user_id = ? AND symbol = ?', [userId, symbol]);
  }

  @override
  Future<void> clearWatchlist(String userId) async {
    await _db.delete('watchlist', 'user_id = ?', [userId]);
  }
}

// -----------------------------------------------------------------
// 6. STATISTICS REPOSITORY
// -----------------------------------------------------------------
class SqliteStatisticsRepository implements StatisticsRepository {
  final SqliteDbHelper _db = SqliteDbHelper.instance;

  @override
  Future<Map<String, dynamic>?> getUserStats(String userId) async {
    final res = await _db.query('user_statistics', where: 'user_id = ?', whereArgs: [userId]);
    return res.isNotEmpty ? res.first : null;
  }

  @override
  Future<void> saveUserStats(String userId, Map<String, dynamic> stats) async {
    await _db.insert('user_statistics', {
      'user_id': userId,
      'total_trades': stats['total_trades'] ?? 0,
      'spot_trades': stats['spot_trades'] ?? 0,
      'futures_trades': stats['futures_trades'] ?? 0,
      'winning_trades': stats['winning_trades'] ?? 0,
      'losing_trades': stats['losing_trades'] ?? 0,
      'average_win': stats['average_win'] ?? 0.0,
      'average_loss': stats['average_loss'] ?? 0.0,
      'largest_win': stats['largest_win'] ?? 0.0,
      'largest_loss': stats['largest_loss'] ?? 0.0,
      'average_holding_time': stats['average_holding_time'] ?? 0.0,
      'best_day': stats['best_day'],
      'worst_day': stats['worst_day'],
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getLeaderboardStats(String userId) async {
    final res = await _db.query('leaderboard_stats', where: 'user_id = ?', whereArgs: [userId]);
    return res.isNotEmpty ? res.first : null;
  }

  @override
  Future<void> saveLeaderboardStats(String userId, String username, double winRate, double returnPct, double netProfit) async {
    await _db.insert('leaderboard_stats', {
      'user_id': userId,
      'username': username,
      'win_rate': winRate,
      'return_pct': returnPct,
      'net_profit': netProfit,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getSettings(String userId) async {
    final res = await _db.query('settings', where: 'user_id = ?', whereArgs: [userId]);
    return res.isNotEmpty ? res.first : null;
  }

  @override
  Future<void> saveSettings(String userId, String theme, String language, int defaultLeverage, String chartType) async {
    await _db.insert('settings', {
      'user_id': userId,
      'theme': theme,
      'language': language,
      'default_leverage': defaultLeverage,
      'chart_type': chartType,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getSubscription(String userId) async {
    final res = await _db.query('subscriptions', where: 'user_id = ?', whereArgs: [userId]);
    return res.isNotEmpty ? res.first : null;
  }

  @override
  Future<void> saveSubscription(String userId, String plan, String status, String? purchaseDate, String? expiryDate, String platform) async {
    await _db.insert('subscriptions', {
      'user_id': userId,
      'plan': plan,
      'status': status,
      'purchase_date': purchaseDate,
      'expiry_date': expiryDate,
      'platform': platform,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> clearAllStats(String userId) async {
    await _db.delete('user_statistics', 'user_id = ?', [userId]);
    await _db.delete('leaderboard_stats', 'user_id = ?', [userId]);
    await _db.delete('settings', 'user_id = ?', [userId]);
    await _db.delete('subscriptions', 'user_id = ?', [userId]);
  }
}
