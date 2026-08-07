import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app/services/persistence/sqlite_db_helper.dart';
import 'package:app/core/logging/logger.dart';

class SyncCoordinator {
  static final SyncCoordinator _instance = SyncCoordinator._internal();
  static SyncCoordinator get instance => _instance;

  final SqliteDbHelper _db = SqliteDbHelper.instance;
  bool _isProcessing = false;

  SyncCoordinator._internal();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isAuthenticated => _client.auth.currentUser != null;
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Enqueue a database mutation event to be synced to the cloud.
  Future<void> enqueue(
    String tableName,
    String action, // 'INSERT', 'UPDATE', 'DELETE'
    String recordId,
    Map<String, dynamic>? payload,
  ) async {
    if (!isAuthenticated) return; // Cloud storage is reserved for signed users

    try {
      await _db.insert('sync_queue', {
        'table_name': tableName,
        'action': action,
        'record_id': recordId,
        'payload': payload != null ? jsonEncode(payload) : null,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Fire queue processor asynchronously
      triggerProcessing();
    } catch (e) {
      Logger.instance.error('Failed to enqueue sync task: $e');
    }
  }

  void triggerProcessing() {
    processQueue().catchError((e) {
      Logger.instance.error('Error during background sync processing: $e');
    });
  }

  /// Process all pending mutations in the local sync queue and upload to Supabase.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    if (!isAuthenticated) return;

    _isProcessing = true;
    try {
      final pending = await _db.query('sync_queue', orderBy: 'id ASC');
      if (pending.isEmpty) {
        _isProcessing = false;
        return;
      }

      Logger.instance.info('Sync Queue: processing ${pending.length} pending mutations');

      for (final row in pending) {
        final int queueId = row['id'] as int;
        final String tableName = row['table_name'] as String;
        final String action = row['action'] as String;
        final String recordId = row['record_id'] as String;
        final String? payloadStr = row['payload'] as String?;
        
        final Map<String, dynamic>? payload = 
            payloadStr != null ? jsonDecode(payloadStr) as Map<String, dynamic> : null;

        bool success = false;
        try {
          if (action == 'INSERT' || action == 'UPDATE') {
            if (payload != null) {
              await _client.from(tableName).upsert(payload);
              success = true;
            }
          } else if (action == 'DELETE') {
            // Determine primary key name matching the target table
            String pkField = 'id';
            if (tableName == 'positions') {
              pkField = 'position_id';
            } else if (tableName == 'trades') {
              pkField = 'trade_id';
            } else if (tableName == 'journal_entries') {
              pkField = 'journal_id';
            } else if (tableName == 'watchlist') {
              pkField = 'symbol';
            } else if (tableName == 'learning_progress') {
              pkField = 'lesson_id';
            }

            await _client.from(tableName).delete().eq(pkField, recordId).eq('user_id', currentUserId!);
            success = true;
          }
        } catch (netErr) {
          // Network exception or server down. Halt queue processing to retry later.
          Logger.instance.warning('Sync Queue halted due to network/server issue: $netErr');
          break;
        }

        if (success) {
          // Delete enqueued mutation from local SQLite table on success
          await _db.delete('sync_queue', 'id = ?', [queueId]);
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Syncs data down from Supabase on first sign-in.
  Future<void> syncDownAll(String userId) async {
    try {
      Logger.instance.info('Sync Down: downloading cloud backups for user: $userId');

      // 1. Settings
      final settingsRes = await _client.from('settings').select().eq('user_id', userId).maybeSingle();
      if (settingsRes != null) {
        await _db.insert('settings', settingsRes);
      }

      // 2. Subscriptions
      final subRes = await _client.from('subscriptions').select().eq('user_id', userId).maybeSingle();
      if (subRes != null) {
        await _db.insert('subscriptions', subRes);
      }

      // 3. User Statistics
      final statsRes = await _client.from('user_statistics').select().eq('user_id', userId).maybeSingle();
      if (statsRes != null) {
        await _db.insert('user_statistics', statsRes);
      }

      // 4. Portfolio
      final portfolioRes = await _client.from('portfolio').select().eq('user_id', userId).maybeSingle();
      if (portfolioRes != null) {
        await _db.insert('portfolio', portfolioRes);
      }

      // 5. Positions
      final positionsRes = await _client.from('positions').select().eq('user_id', userId);
      for (final p in positionsRes) {
        await _db.insert('positions', p);
      }

      // 6. Trades
      final tradesRes = await _client.from('trades').select().eq('user_id', userId);
      for (final t in tradesRes) {
        await _db.insert('trades', t);
      }

      // 7. Journal Entries
      final journalsRes = await _client.from('journal_entries').select().eq('user_id', userId);
      for (final j in journalsRes) {
        await _db.insert('journal_entries', j);
      }

      // 8. Learning Progress
      final learnRes = await _client.from('learning_progress').select().eq('user_id', userId);
      for (final l in learnRes) {
        await _db.insert('learning_progress', l);
      }

      // 9. Watchlist
      final watchlistRes = await _client.from('watchlist').select().eq('user_id', userId);
      for (final w in watchlistRes) {
        await _db.insert('watchlist', w);
      }

      Logger.instance.info('Sync Down completed successfully.');
    } catch (e) {
      Logger.instance.error('Sync Down failed: $e');
    }
  }

  /// Migrates local Guest data to Registered user profile in Supabase.
  Future<void> migrateGuestToCloud(String registeredUserId) async {
    try {
      final guestId = 'guest';
      Logger.instance.info('Sync Migration: uploading guest data to registered user: $registeredUserId');

      // 1. Migrate Settings
      final settings = await _db.query('settings', where: 'user_id = ?', whereArgs: [guestId]);
      if (settings.isNotEmpty) {
        final Map<String, dynamic> row = Map.from(settings.first);
        row['user_id'] = registeredUserId;
        row['updated_at'] = DateTime.now().toIso8601String();
        await _db.insert('settings', row);
        await enqueue('settings', 'INSERT', registeredUserId, row);
      }

      // 2. Migrate Portfolio
      final portfolio = await _db.query('portfolio', where: 'user_id = ?', whereArgs: [guestId]);
      if (portfolio.isNotEmpty) {
        final Map<String, dynamic> row = Map.from(portfolio.first);
        row['user_id'] = registeredUserId;
        row['updated_at'] = DateTime.now().toIso8601String();
        await _db.insert('portfolio', row);
        await enqueue('portfolio', 'INSERT', registeredUserId, row);
      }

      // 3. Migrate Positions
      final positions = await _db.query('positions', where: 'user_id = ?', whereArgs: [guestId]);
      for (final pos in positions) {
        final Map<String, dynamic> row = Map.from(pos);
        row['user_id'] = registeredUserId;
        await _db.insert('positions', row);
        await enqueue('positions', 'INSERT', row['position_id'], row);
      }

      // 4. Migrate Trades
      final trades = await _db.query('trades', where: 'user_id = ?', whereArgs: [guestId]);
      for (final trade in trades) {
        final Map<String, dynamic> row = Map.from(trade);
        row['user_id'] = registeredUserId;
        await _db.insert('trades', row);
        await enqueue('trades', 'INSERT', row['trade_id'], row);
      }

      // 5. Migrate Journals
      final journals = await _db.query('journal_entries', where: 'user_id = ?', whereArgs: [guestId]);
      for (final j in journals) {
        final Map<String, dynamic> row = Map.from(j);
        row['user_id'] = registeredUserId;
        await _db.insert('journal_entries', row);
        await enqueue('journal_entries', 'INSERT', row['journal_id'], row);
      }

      // 6. Migrate Learning Progress
      final learn = await _db.query('learning_progress', where: 'user_id = ?', whereArgs: [guestId]);
      for (final l in learn) {
        final Map<String, dynamic> row = Map.from(l);
        row['user_id'] = registeredUserId;
        row['updated_at'] = DateTime.now().toIso8601String();
        await _db.insert('learning_progress', row);
        await enqueue('learning_progress', 'INSERT', row['lesson_id'], row);
      }

      // 7. Migrate Watchlist
      final watchlist = await _db.query('watchlist', where: 'user_id = ?', whereArgs: [guestId]);
      for (final w in watchlist) {
        final Map<String, dynamic> row = Map.from(w);
        row['user_id'] = registeredUserId;
        row['created_at'] = DateTime.now().toIso8601String();
        await _db.insert('watchlist', row);
        await enqueue('watchlist', 'INSERT', row['symbol'], row);
      }

      // 8. Migrate Stats
      final stats = await _db.query('user_statistics', where: 'user_id = ?', whereArgs: [guestId]);
      if (stats.isNotEmpty) {
        final Map<String, dynamic> row = Map.from(stats.first);
        row['user_id'] = registeredUserId;
        row['updated_at'] = DateTime.now().toIso8601String();
        await _db.insert('user_statistics', row);
        await enqueue('user_statistics', 'INSERT', registeredUserId, row);
      }

      // 9. Migrate Leaderboard Stats
      final lstats = await _db.query('leaderboard_stats', where: 'user_id = ?', whereArgs: [guestId]);
      if (lstats.isNotEmpty) {
        final Map<String, dynamic> row = Map.from(lstats.first);
        row['user_id'] = registeredUserId;
        row['updated_at'] = DateTime.now().toIso8601String();
        await _db.insert('leaderboard_stats', row);
        await enqueue('leaderboard_stats', 'INSERT', registeredUserId, row);
      }

      Logger.instance.info('Guest sync migration finished.');
    } catch (e) {
      Logger.instance.error('Migration failed: $e');
    }
  }
}
