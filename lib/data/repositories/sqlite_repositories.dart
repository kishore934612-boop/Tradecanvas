/// SQLite-backed repositories for Charty.
///
/// Every write also enqueues a sync mutation so signed-in users get cloud
/// backup. Enqueue is a no-op while signed out.
library;

import 'dart:convert';

import 'package:app/core/logging/logger.dart';
import 'package:app/domain/repositories/chart_prefs_repository.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/domain/repositories/watchlist_repository.dart';
import 'package:app/models/drawing.dart';
import 'package:app/services/persistence/sqlite_db_helper.dart';
import 'package:app/services/session.dart';
import 'package:app/services/sync/sync_coordinator.dart';

// -----------------------------------------------------------------
// WATCHLIST
// -----------------------------------------------------------------
class SqliteWatchlistRepository implements WatchlistRepository {
  final SqliteDbHelper _db;
  final SyncCoordinator _sync;

  SqliteWatchlistRepository({
    SqliteDbHelper? db,
    SyncCoordinator? sync,
  })  : _db = db ?? SqliteDbHelper.instance,
        _sync = sync ?? SyncCoordinator.instance;

  @override
  Future<List<String>> getWatchlist(String userId) async {
    final rows = await _db.query(
      'watchlist',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'display_order ASC, created_at ASC',
    );
    return rows.map((r) => r['symbol'] as String).toList();
  }

  @override
  Future<void> addToWatchlist(String userId, String symbol) async {
    // Append to the end rather than colliding everything at order 0.
    final existing = await _db.rawQuery(
      'SELECT COALESCE(MAX(display_order), -1) AS max_order '
      'FROM watchlist WHERE user_id = ?',
      [userId],
    );
    final nextOrder =
        ((existing.first['max_order'] as num?)?.toInt() ?? -1) + 1;

    final row = {
      'user_id': userId,
      'symbol': symbol,
      'display_order': nextOrder,
      'created_at': DateTime.now().toIso8601String(),
    };
    await _db.insert('watchlist', row);
    await _sync.enqueue('watchlist', 'INSERT', symbol, row);
  }

  @override
  Future<void> removeFromWatchlist(String userId, String symbol) async {
    await _db.delete('watchlist', 'user_id = ? AND symbol = ?', [userId, symbol]);
    await _sync.enqueue('watchlist', 'DELETE', symbol, null);
  }

  @override
  Future<void> clearWatchlist(String userId) async {
    final symbols = await getWatchlist(userId);
    await _db.delete('watchlist', 'user_id = ?', [userId]);
    for (final s in symbols) {
      await _sync.enqueue('watchlist', 'DELETE', s, null);
    }
  }

  @override
  Future<void> reorder(String userId, List<String> symbolsInOrder) async {
    for (var i = 0; i < symbolsInOrder.length; i++) {
      await _db.update(
        'watchlist',
        {'display_order': i},
        'user_id = ? AND symbol = ?',
        [userId, symbolsInOrder[i]],
      );
    }
  }
}

// -----------------------------------------------------------------
// DRAWINGS
// -----------------------------------------------------------------
class SqliteDrawingRepository implements DrawingRepository {
  final SqliteDbHelper _db;
  final SyncCoordinator _sync;
  final SessionProvider _session;
  final Logger _logger;

  SqliteDrawingRepository({
    required SessionProvider session,
    required Logger logger,
    SqliteDbHelper? db,
    SyncCoordinator? sync,
  })  : _session = session,
        _logger = logger,
        _db = db ?? SqliteDbHelper.instance,
        _sync = sync ?? SyncCoordinator.instance;

  @override
  Future<List<Drawing>> getForSymbol(String symbol) async {
    final rows = await _db.query(
      'drawings',
      where: 'user_id = ? AND symbol = ?',
      whereArgs: [_session.userId, symbol],
      orderBy: 'created_at ASC',
    );

    final out = <Drawing>[];
    for (final r in rows) {
      try {
        out.add(_fromRow(r));
      } catch (e) {
        // A single corrupt row should not blank the whole chart.
        _logger.warning('Skipping malformed drawing ${r['drawing_id']}: $e');
      }
    }
    return out;
  }

  @override
  Future<List<String>> symbolsWithDrawings() async {
    final rows = await _db.rawQuery(
      'SELECT DISTINCT symbol FROM drawings WHERE user_id = ? ORDER BY symbol',
      [_session.userId],
    );
    return rows.map((r) => r['symbol'] as String).toList();
  }

  @override
  Future<void> save(Drawing drawing) async {
    final row = _toRow(drawing);
    await _db.insert('drawings', row);
    await _sync.enqueue('drawings', 'INSERT', drawing.id, row);
  }

  @override
  Future<void> delete(String id, String symbol) async {
    await _db.delete(
      'drawings',
      'drawing_id = ? AND user_id = ?',
      [id, _session.userId],
    );
    await _sync.enqueue('drawings', 'DELETE', id, null);
  }

  @override
  Future<void> clearSymbol(String symbol) async {
    final existing = await getForSymbol(symbol);
    await _db.delete(
      'drawings',
      'user_id = ? AND symbol = ?',
      [_session.userId, symbol],
    );
    for (final d in existing) {
      await _sync.enqueue('drawings', 'DELETE', d.id, null);
    }
  }

  Map<String, dynamic> _toRow(Drawing d) {
    String? textColumn = d.text;
    if (d.properties != null && d.properties!.isNotEmpty) {
      textColumn = jsonEncode({
        if (d.text != null) 'text': d.text,
        'properties': d.properties,
      });
    }
    return {
      'drawing_id': d.id,
      'user_id': _session.userId,
      'symbol': d.symbol,
      'tool': d.tool.name,
      'anchors': jsonEncode(d.anchors.map((a) => a.toJson()).toList()),
      'color': d.colorValue,
      'stroke_width': d.strokeWidth,
      'text': textColumn,
      'created_at': d.createdAt,
    };
  }

  Drawing _fromRow(Map<String, dynamic> r) {
    final anchors = (jsonDecode(r['anchors'] as String) as List)
        .map((e) => DrawingAnchor.fromJson(e as Map<String, dynamic>))
        .toList();

    String? text = r['text'] as String?;
    Map<String, dynamic>? properties;

    if (text != null && text.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('properties')) {
            properties = Map<String, dynamic>.from(decoded['properties'] as Map);
            text = decoded['text'] as String?;
          }
        }
      } catch (_) {
        // Plain text string starting with '{'
      }
    }

    return Drawing(
      id: r['drawing_id'] as String,
      tool: DrawingTool.fromId(r['tool'] as String),
      symbol: r['symbol'] as String,
      anchors: anchors,
      colorValue: (r['color'] as num).toInt(),
      strokeWidth: (r['stroke_width'] as num?)?.toDouble() ?? 1.5,
      text: text,
      createdAt: (r['created_at'] as num).toInt(),
      properties: properties,
    );
  }
}

// -----------------------------------------------------------------
// CHART PREFERENCES
// -----------------------------------------------------------------
class SqliteChartPrefsRepository implements ChartPrefsRepository {
  final SqliteDbHelper _db;
  final SyncCoordinator _sync;
  final SessionProvider _session;

  SqliteChartPrefsRepository({
    required SessionProvider session,
    SqliteDbHelper? db,
    SyncCoordinator? sync,
  })  : _session = session,
        _db = db ?? SqliteDbHelper.instance,
        _sync = sync ?? SyncCoordinator.instance;

  @override
  Future<ChartPrefs?> get(String symbol) async {
    final rows = await _db.query(
      'chart_prefs',
      where: 'user_id = ? AND symbol = ?',
      whereArgs: [_session.userId, symbol],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;

    final rawIndicators = r['indicators'] as String?;
    return ChartPrefs(
      symbol: symbol,
      timeframe: r['timeframe'] as String,
      chartType: r['chart_type'] as String? ?? 'candles',
      indicators: rawIndicators == null || rawIndicators.isEmpty
          ? const []
          : (jsonDecode(rawIndicators) as List).cast<String>(),
    );
  }

  @override
  Future<void> save(ChartPrefs prefs) async {
    final row = {
      'user_id': _session.userId,
      'symbol': prefs.symbol,
      'timeframe': prefs.timeframe,
      'indicators': jsonEncode(prefs.indicators),
      'chart_type': prefs.chartType,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _db.insert('chart_prefs', row);
    await _sync.enqueue('chart_prefs', 'INSERT', prefs.symbol, row);
  }
}
