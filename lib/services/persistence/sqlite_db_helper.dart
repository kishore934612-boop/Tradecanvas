import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:app/core/logging/logger.dart';

class SqliteDbHelper {
  static const String _dbName = 'tradeverse_local_v1.db';
  static const int _dbVersion = 1;

  static final SqliteDbHelper _instance = SqliteDbHelper._internal();
  static SqliteDbHelper get instance => _instance;

  Database? _db;

  SqliteDbHelper._internal();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, _dbName);
      
      Logger.instance.info('Initializing SQLite Local Database at: $path');
      
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
      );
    } catch (e) {
      Logger.instance.error('SQLite initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    Logger.instance.info('Creating local SQLite database tables...');

    // 1. Profiles
    await db.execute('''
      CREATE TABLE profiles (
        user_id TEXT PRIMARY KEY,
        display_name TEXT,
        email TEXT,
        photo_url TEXT,
        joined_at TEXT NOT NULL,
        last_login TEXT NOT NULL,
        account_type TEXT NOT NULL
      )
    ''');

    // 2. Portfolio
    await db.execute('''
      CREATE TABLE portfolio (
        user_id TEXT PRIMARY KEY,
        initial_balance REAL DEFAULT 100000.0 NOT NULL,
        available_balance REAL DEFAULT 100000.0 NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 3. Open Positions
    await db.execute('''
      CREATE TABLE positions (
        position_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        market_type TEXT NOT NULL,
        entry_price REAL NOT NULL,
        quantity REAL NOT NULL,
        leverage REAL DEFAULT 1.0 NOT NULL,
        margin REAL NOT NULL,
        direction TEXT NOT NULL,
        stop_loss REAL,
        take_profit REAL,
        opened_at TEXT NOT NULL
      )
    ''');

    // 4. Trades
    await db.execute('''
      CREATE TABLE trades (
        trade_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        market_type TEXT NOT NULL,
        direction TEXT NOT NULL,
        entry_price REAL NOT NULL,
        exit_price REAL NOT NULL,
        quantity REAL NOT NULL,
        leverage REAL DEFAULT 1.0 NOT NULL,
        entry_fee REAL DEFAULT 0.0 NOT NULL,
        exit_fee REAL DEFAULT 0.0 NOT NULL,
        liquidation_price REAL,
        realized_pnl REAL NOT NULL,
        return_pct REAL NOT NULL,
        duration INTEGER NOT NULL,
        closed_reason TEXT NOT NULL,
        order_type TEXT NOT NULL,
        trade_status TEXT NOT NULL,
        opened_at TEXT NOT NULL,
        closed_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_trades_user_closed ON trades(user_id, closed_at)');
    await db.execute('CREATE INDEX idx_trades_symbol ON trades(symbol)');

    // 5. Trading Journal
    await db.execute('''
      CREATE TABLE journal_entries (
        journal_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        trade_id TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        emotion TEXT,
        mistakes TEXT NOT NULL,
        lessons TEXT,
        rating INTEGER,
        tags TEXT,
        screenshots TEXT,
        strategy TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_journal_trade ON journal_entries(trade_id)');

    // 6. Learning Progress
    await db.execute('''
      CREATE TABLE learning_progress (
        user_id TEXT NOT NULL,
        lesson_id TEXT NOT NULL,
        completed INTEGER DEFAULT 0 NOT NULL,
        completion_time INTEGER,
        quiz_score INTEGER,
        last_opened TEXT,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, lesson_id)
      )
    ''');

    // 7. Watchlist
    await db.execute('''
      CREATE TABLE watchlist (
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        display_order INTEGER DEFAULT 0 NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, symbol)
      )
    ''');

    // 8. User Statistics
    await db.execute('''
      CREATE TABLE user_statistics (
        user_id TEXT PRIMARY KEY,
        total_trades INTEGER DEFAULT 0 NOT NULL,
        spot_trades INTEGER DEFAULT 0 NOT NULL,
        futures_trades INTEGER DEFAULT 0 NOT NULL,
        winning_trades INTEGER DEFAULT 0 NOT NULL,
        losing_trades INTEGER DEFAULT 0 NOT NULL,
        average_win REAL DEFAULT 0.0 NOT NULL,
        average_loss REAL DEFAULT 0.0 NOT NULL,
        largest_win REAL DEFAULT 0.0 NOT NULL,
        largest_loss REAL DEFAULT 0.0 NOT NULL,
        average_holding_time REAL DEFAULT 0.0 NOT NULL,
        best_day TEXT,
        worst_day TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // 9. Leaderboard Statistics
    await db.execute('''
      CREATE TABLE leaderboard_stats (
        user_id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        win_rate REAL DEFAULT 0.0 NOT NULL,
        return_pct REAL DEFAULT 0.0 NOT NULL,
        net_profit REAL DEFAULT 0.0 NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_leaderboard_return ON leaderboard_stats(return_pct DESC)');

    // 10. User Settings
    await db.execute('''
      CREATE TABLE settings (
        user_id TEXT PRIMARY KEY,
        theme TEXT DEFAULT 'system' NOT NULL,
        language TEXT DEFAULT 'en' NOT NULL,
        default_leverage INTEGER DEFAULT 1 NOT NULL,
        chart_type TEXT DEFAULT 'candles' NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 11. Subscriptions
    await db.execute('''
      CREATE TABLE subscriptions (
        user_id TEXT PRIMARY KEY,
        plan TEXT DEFAULT 'free' NOT NULL,
        status TEXT DEFAULT 'active' NOT NULL,
        purchase_date TEXT,
        expiry_date TEXT,
        platform TEXT DEFAULT 'google_play' NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // 12. Local Sync Queue
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        action TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    Logger.instance.info('SQLite local tables created successfully.');
  }

  // --- CRUD helpers ---
  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> update(String table, Map<String, dynamic> row, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.update(table, row, where: whereClause, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy}) async {
    final db = await database;
    return await db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<int> delete(String table, String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    return await db.delete(table, where: whereClause, whereArgs: whereArgs);
  }

  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    await db.execute(sql, arguments);
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('profiles');
      await txn.delete('portfolio');
      await txn.delete('positions');
      await txn.delete('trades');
      await txn.delete('journal_entries');
      await txn.delete('learning_progress');
      await txn.delete('watchlist');
      await txn.delete('user_statistics');
      await txn.delete('leaderboard_stats');
      await txn.delete('settings');
      await txn.delete('subscriptions');
      await txn.delete('sync_queue');
    });
    Logger.instance.info('SQLite database cleared.');
  }
}
