/// Market session overlay definitions and time-range computation.
///
/// Each session is defined in UTC and projected into the user's local timezone
/// for display. Sessions are computed per visible day on the chart and produce
/// rectangles the chart painter renders behind candles.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:app/domain/entities/candle_data.dart';

enum MarketSessionType {
  sydney,
  tokyo,
  london,
  newYork;

  String get label {
    switch (this) {
      case MarketSessionType.sydney:
        return 'Sydney';
      case MarketSessionType.tokyo:
        return 'Tokyo';
      case MarketSessionType.london:
        return 'London';
      case MarketSessionType.newYork:
        return 'New York';
    }
  }

  /// Session colour (translucent — the painter uses this at low alpha).
  Color get color {
    switch (this) {
      case MarketSessionType.sydney:
        return const Color(0xFFA855F7); // purple
      case MarketSessionType.tokyo:
        return const Color(0xFF3B82F6); // blue
      case MarketSessionType.london:
        return const Color(0xFF10B981); // green
      case MarketSessionType.newYork:
        return const Color(0xFFF59E0B); // orange
    }
  }

  /// Session start hour in UTC.
  int get _startHourUtc {
    switch (this) {
      case MarketSessionType.sydney:
        return 22; // 22:00 UTC (previous day)
      case MarketSessionType.tokyo:
        return 0; // 00:00 UTC
      case MarketSessionType.london:
        return 8; // 08:00 UTC
      case MarketSessionType.newYork:
        return 13; // 13:00 UTC
    }
  }

  /// Session duration in hours.
  int get _durationHours {
    switch (this) {
      case MarketSessionType.sydney:
        return 9;
      case MarketSessionType.tokyo:
        return 9;
      case MarketSessionType.london:
        return 9;
      case MarketSessionType.newYork:
        return 7;
    }
  }
}

/// A computed session rectangle ready for painting.
class SessionRect {
  final MarketSessionType type;

  /// Start and end timestamps in milliseconds since epoch.
  final int startMs;
  final int endMs;

  /// Session high/low computed from candles within the session.
  final double high;
  final double low;
  final double open;
  final double close;

  const SessionRect({
    required this.type,
    required this.startMs,
    required this.endMs,
    required this.high,
    required this.low,
    required this.open,
    required this.close,
  });
}

/// Holds the per-session enabled state and computes session rectangles for
/// the visible candle window.
class SessionOverlayConfig {
  bool masterEnabled;
  final Map<MarketSessionType, bool> sessionEnabled;

  SessionOverlayConfig({
    this.masterEnabled = false,
    Map<MarketSessionType, bool>? sessionEnabled,
  }) : sessionEnabled = sessionEnabled ??
            {
              for (final s in MarketSessionType.values) s: true,
            };

  bool isEnabled(MarketSessionType type) =>
      masterEnabled && (sessionEnabled[type] ?? false);

  void toggle(MarketSessionType type) {
    sessionEnabled[type] = !(sessionEnabled[type] ?? false);
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'sessionEnabled': sessionEnabled.map(
          (key, value) => MapEntry(key.name, value),
        ),
      };

  factory SessionOverlayConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return SessionOverlayConfig();
    final master = j['masterEnabled'] as bool? ?? false;
    final mapRaw = j['sessionEnabled'] as Map<String, dynamic>?;
    final Map<MarketSessionType, bool> map = {};

    for (final s in MarketSessionType.values) {
      if (mapRaw != null && mapRaw.containsKey(s.name)) {
        map[s] = mapRaw[s.name] as bool;
      } else {
        map[s] = true;
      }
    }

    return SessionOverlayConfig(
      masterEnabled: master,
      sessionEnabled: map,
    );
  }

  /// Compute session rectangles for the enabled sessions over the given
  /// candle range. Each day in the visible window produces one rectangle per
  /// enabled session.
  List<SessionRect> compute({
    required List<CandleData> candles,
    required int firstVisibleIndex,
    required int lastVisibleIndex,
  }) {
    if (!masterEnabled || candles.isEmpty) return const [];

    final results = <SessionRect>[];

    // Determine the UTC day range covered by visible candles.
    final firstMs = candles[firstVisibleIndex].timestamp;
    final lastMs = candles[lastVisibleIndex].timestamp;

    final firstDay =
        DateTime.fromMillisecondsSinceEpoch(firstMs, isUtc: true);
    final lastDay =
        DateTime.fromMillisecondsSinceEpoch(lastMs, isUtc: true);

    // Walk each day, from one day before firstDay to one day after lastDay
    // to catch sessions that span midnight.
    final startDate = DateTime.utc(firstDay.year, firstDay.month, firstDay.day)
        .subtract(const Duration(days: 1));
    final endDate = DateTime.utc(lastDay.year, lastDay.month, lastDay.day)
        .add(const Duration(days: 2));

    var current = startDate;
    while (current.isBefore(endDate)) {
      for (final session in MarketSessionType.values) {
        if (!isEnabled(session)) continue;

        final sessionStart = DateTime.utc(
          current.year,
          current.month,
          current.day,
          session._startHourUtc,
        );
        final sessionEnd =
            sessionStart.add(Duration(hours: session._durationHours));

        final sMs = sessionStart.millisecondsSinceEpoch;
        final eMs = sessionEnd.millisecondsSinceEpoch;

        // Skip sessions entirely outside the visible range.
        if (eMs < firstMs || sMs > lastMs) continue;

        // Find candles within this session to compute OHLC.
        var sessionHigh = -double.infinity;
        var sessionLow = double.infinity;
        double? sessionOpen;
        double sessionClose = 0;
        var found = false;

        for (var i = firstVisibleIndex; i <= lastVisibleIndex; i++) {
          final c = candles[i];
          if (c.timestamp >= sMs && c.timestamp <= eMs) {
            sessionHigh = math.max(sessionHigh, c.high);
            sessionLow = math.min(sessionLow, c.low);
            sessionOpen ??= c.open;
            sessionClose = c.close;
            found = true;
          }
        }

        if (!found) continue;

        results.add(SessionRect(
          type: session,
          startMs: sMs,
          endMs: eMs,
          high: sessionHigh,
          low: sessionLow,
          open: sessionOpen ?? sessionClose,
          close: sessionClose,
        ));
      }
      current = current.add(const Duration(days: 1));
    }

    return results;
  }
}
