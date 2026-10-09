/// Local SQLite database.
///
/// Schema for Charty: profiles, watchlist, drawings, chart preferences,
/// settings and the outbound sync queue. The paper-trading and learning tables
/// from the previous app are dropped on upgrade.
library;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:app/core/logging/logger.dart';

class SqliteDbHelper {
  static const String _dbName = 'charty_local.db';

  /// v1 = TradeVerse (12 tables). v2 = Charty schema. v3 = drawings text column. v4 = alerts & alert_history. v5 = V2 Alert System Upgrade.
  static const int _dbVersion = 5;

  /// Tables removed in v2 because the features no longer exist.
  static const List<String> _legacyTables = [
    'portfolio',
    'positions',
    'trades',
    'journal_entries',
    'learning_progress',
    'user_statistics',
    'leaderboard_stats',
    'subscriptions',
  ];

  static final SqliteDbHelper _instance = SqliteDbHelper._internal();
  static SqliteDbHelper get instance => _instance;

  Database? _db;
  bool _useWebFallback = false;
  final Map<String, List<Map<String, dynamic>>> _webStore = {};

  SqliteDbHelper._internal();

  /// Initialize database or set up web fallback without throwing uncaught errors.
  Future<void> init() async {
    if (_db != null || _useWebFallback) return;
    try {
      _db = await _initDb();
    } catch (e) {
      if (kIsWeb) {
        _useWebFallback = true;
        Logger.instance.warning(
            'SQLite worker unavailable on web. Using in-memory web store fallback for testing.');
      } else {
        rethrow;
      }
    }
  }

  Future<Database?> get database async {
    if (_db != null) return _db;
    if (_useWebFallback) return null;
    await init();
    return _db;
  }

  Future<Database> _initDb() async {
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWeb;
      } catch (_) {}
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    Logger.instance.info('Opening SQLite database at $path (v$_dbVersion)');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onOpen,
      onDowngrade: onDatabaseDowngradeDelete,
    );
  }

  // ==========================================================
  // SCHEMA
  // ==========================================================

  Future<void> _onCreate(Database db, int version) async {
    Logger.instance.info('Creating Charty schema v$version');
    await _createProfiles(db);
    await _createWatchlist(db);
    await _createDrawings(db);
    await _createChartPrefs(db);
    await _createSettings(db);
    await _createSyncQueue(db);
    await _createIndexes(db);
    await _addColumnIfMissing(db, 'drawings', 'text', 'TEXT');
    Logger.instance.info('Schema created');
  }

  Future<void> _onOpen(Database db) async {
    await _addColumnIfMissing(db, 'drawings', 'text', 'TEXT');
  }

  /// Migrations are forward-only and idempotent, so a partially upgraded
  /// database converges on the next open.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    Logger.instance.info('Migrating SQLite v$oldVersion -> v$newVersion');

    if (oldVersion < 2) {
      // Drop everything tied to paper trading, journalling and lessons.
      for (final table in _legacyTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }

      // New tables for charting.
      await _createDrawings(db);
      await _createChartPrefs(db);

      // v1 profiles lacked `country`, which app code already wrote to.
      await _addColumnIfMissing(db, 'profiles', 'country', 'TEXT');

      // Give the sync queue retry accounting so one poisoned row cannot
      // block the whole queue forever.
      await _addColumnIfMissing(
          db, 'sync_queue', 'retry_count', 'INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'sync_queue', 'last_error', 'TEXT');

      // Queued mutations for now-deleted tables can never succeed.
      final placeholders = List.filled(_legacyTables.length, '?').join(',');
      await db.delete(
        'sync_queue',
        where: 'table_name IN ($placeholders)',
        whereArgs: _legacyTables,
      );

      await _createIndexes(db);
    }

    await _addColumnIfMissing(db, 'drawings', 'text', 'TEXT');
    Logger.instance.info('Migration complete');
  }

  Future<void> _createProfiles(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        user_id TEXT PRIMARY KEY,
        display_name TEXT,
        email TEXT,
        photo_url TEXT,
        country TEXT,
        joined_at TEXT NOT NULL,
        last_login TEXT NOT NULL,
        account_type TEXT NOT NULL
      )
    ''');

  Future<void> _createWatchlist(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS watchlist (
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, symbol)
      )
    ''');

  /// Anchors are stored as a JSON array of {t, p} in data space.
  Future<void> _createDrawings(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS drawings (
        drawing_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        tool TEXT NOT NULL,
        anchors TEXT NOT NULL,
        color INTEGER NOT NULL,
        stroke_width REAL NOT NULL DEFAULT 1.5,
        text TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

  /// Per-symbol chart state so a chart reopens exactly as it was left.
  Future<void> _createChartPrefs(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS chart_prefs (
        user_id TEXT NOT NULL,
        symbol TEXT NOT NULL,
        timeframe TEXT NOT NULL,
        indicators TEXT,
        chart_type TEXT NOT NULL DEFAULT 'candles',
        updated_at TEXT NOT NULL,
        PRIMARY KEY (user_id, symbol)
      )
    ''');

  Future<void> _createSettings(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        user_id TEXT PRIMARY KEY,
        theme TEXT NOT NULL DEFAULT 'system',
        theme_index INTEGER NOT NULL DEFAULT 0,
        language TEXT NOT NULL DEFAULT 'en',
        chart_type TEXT NOT NULL DEFAULT 'candles',
        default_timeframe TEXT NOT NULL DEFAULT '1h',
        updated_at TEXT NOT NULL
      )
    ''');

  Future<void> _createSyncQueue(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        action TEXT NOT NULL,
        record_id TEXT NOT NULL,
        payload TEXT,
        created_at TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      )
    ''');

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_watchlist_user ON watchlist(user_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_drawings_user_symbol ON drawings(user_id, symbol)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_chart_prefs_user ON chart_prefs(user_id)');
  }

  /// `ALTER TABLE ADD COLUMN` has no IF NOT EXISTS in SQLite, so the column
  /// list is inspected first. Missing tables are ignored.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      if (info.isEmpty) return; // table absent; nothing to alter
      final exists = info.any((row) => row['name'] == column);
      if (exists) return;
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      Logger.instance.info('Added column $table.$column');
    } catch (e) {
      Logger.instance.warning('Could not add $table.$column: $e');
    }
  }

  // ==========================================================
  // CRUD HELPERS (WITH WEB FALLBACK FOR DEBUGGING)
  // ==========================================================

  Future<int> insert(String table, Map<String, dynamic> row) async {
    await init();
    if (_db != null && !_useWebFallback) {
      return _db!.insert(table, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    _webStore.putIfAbsent(table, () => []);
    _webStore[table]!.add(Map<String, dynamic>.from(row));
    return 1;
  }

  Future<int> update(
    String table,
    Map<String, dynamic> row,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    await init();
    if (_db != null && !_useWebFallback) {
      return _db!.update(table, row, where: whereClause, whereArgs: whereArgs);
    }
    final list = _webStore[table];
    if (list == null) return 0;
    int count = 0;
    for (final item in list) {
      item.addAll(row);
      count++;
    }
    return count;
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    await init();
    if (_db != null && !_useWebFallback) {
      return _db!.query(table,
          where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
    }
    final list = _webStore[table] ?? [];
    if (whereArgs != null && whereArgs.isNotEmpty && list.isNotEmpty) {
      final argStr = whereArgs.first.toString();
      final filtered = list.where((item) {
        return item.values.any((v) => v.toString() == argStr);
      }).toList();
      return filtered;
    }
    return list;
  }

  Future<int> delete(
    String table,
    String whereClause,
    List<dynamic> whereArgs,
  ) async {
    await init();
    if (_db != null && !_useWebFallback) {
      return _db!.delete(table, where: whereClause, whereArgs: whereArgs);
    }
    final list = _webStore[table];
    if (list == null) return 0;
    if (whereArgs.isNotEmpty) {
      final argStr = whereArgs.first.toString();
      list.removeWhere((item) => item.values.any((v) => v.toString() == argStr));
    } else {
      list.clear();
    }
    return 1;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? args,
  ]) async {
    await init();
    if (_db != null && !_useWebFallback) {
      return _db!.rawQuery(sql, args);
    }
    return const [];
  }

  /// Wipe user data. Used on account reset — not on ordinary sign-out.
  Future<void> clearAllData() async {
    await init();
    if (_db != null && !_useWebFallback) {
      final batch = _db!.batch();
      for (final table in [
        'profiles',
        'watchlist',
        'drawings',
        'chart_prefs',
        'settings',
        'sync_queue',
      ]) {
        batch.delete(table);
      }
      await batch.commit(noResult: true);
    } else {
      _webStore.clear();
    }
    Logger.instance.info('Local data cleared');
  }

  /// Reassign guest-owned rows to a real user id after sign-in.
  Future<void> reassignGuestData(String userId) async {
    await init();
    if (_db != null && !_useWebFallback) {
      final batch = _db!.batch();
      for (final table in ['watchlist', 'drawings', 'chart_prefs', 'settings']) {
        batch.update(
          table,
          {'user_id': userId},
          where: 'user_id = ?',
          whereArgs: ['guest'],
        );
      }
      await batch.commit(noResult: true);
    } else {
      for (final list in _webStore.values) {
        for (final row in list) {
          if (row['user_id'] == 'guest') {
            row['user_id'] = userId;
          }
        }
      }
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
