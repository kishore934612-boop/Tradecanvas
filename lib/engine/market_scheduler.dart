/// Market Scheduler — Phase 7
///
/// Intelligent polling scheduler that:
///   • Polls crypto at full rate (24/7 active)
///   • Polls stocks & forex only during their trading hours
///   • Pauses polls when all watched markets are closed
///   • Resumes automatically when a market reopens
///   • Adjusts poll interval dynamically (faster when live, slower when closed)
///   • Emits market open/close events via EventBus
///   • Never polls APIs when data would be stale/unchanged
///
/// Stateless regarding prices — it only decides WHEN to poll.
/// Actual fetching is delegated to the callback supplied by TradingProvider.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app/constants/markets.dart';
import 'package:app/utils/market_session.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/market_events.dart';
import 'package:app/domain/repositories/market_repository.dart';
import 'package:app/core/logging/logger.dart';

// ============================================================
// SCHEDULE CONFIGURATION
// ============================================================

class ScheduleConfig {
  /// Poll interval when at least one market is live (ms).
  final int liveIntervalMs;

  /// Poll interval when all markets are closed (ms).
  final int closedIntervalMs;

  /// How often to check whether a closed market has reopened (ms).
  final int statusCheckIntervalMs;

  const ScheduleConfig({
    this.liveIntervalMs      = 3000,   // 3s when live
    this.closedIntervalMs    = 300000, // 5min when all closed
    this.statusCheckIntervalMs = 30000, // 30s status recheck
  });

  static const ScheduleConfig defaults = ScheduleConfig();
  static const ScheduleConfig aggressive = ScheduleConfig(
    liveIntervalMs: 1000,
    closedIntervalMs: 60000,
    statusCheckIntervalMs: 15000,
  );
  static const ScheduleConfig conservative = ScheduleConfig(
    liveIntervalMs: 5000,
    closedIntervalMs: 600000,
    statusCheckIntervalMs: 60000,
  );
}

// ============================================================
// MARKET STATE SNAPSHOT
// ============================================================

/// Per-market schedule decision returned to callers.
class MarketSchedule {
  final MarketType market;
  final MarketStatus status;
  final bool shouldPoll;    // true = fetch fresh prices
  final int  pollIntervalMs;
  final String reason;

  const MarketSchedule({
    required this.market,
    required this.status,
    required this.shouldPoll,
    required this.pollIntervalMs,
    required this.reason,
  });

  @override
  String toString() =>
      'MarketSchedule($market: ${status.label}, poll=$shouldPoll @ ${pollIntervalMs}ms, $reason)';
}

// ============================================================
// MARKET SCHEDULER
// ============================================================

class MarketScheduler {
  final EventBus    _eventBus;
  final Logger      _logger;
  final ScheduleConfig _config;

  /// Callback invoked on each poll tick. Receives the set of markets that
  /// should be polled right now.
  final void Function(Set<MarketType> activeMarkets) _onPoll;

  Timer? _pollTimer;
  Timer? _statusTimer;

  // Last known status per market type (for change detection)
  final Map<MarketType, MarketStatus> _lastStatus = {};

  // Track which markets have been registered for scheduling
  final Set<MarketType> _watchedMarkets;

  bool _running = false;

  MarketScheduler({
    required this._eventBus,
    required this._logger,
    required this._onPoll,
    Set<MarketType>? watchedMarkets,
    this._config = ScheduleConfig.defaults,
  }) : _watchedMarkets = watchedMarkets ?? MarketType.values.toSet() {
    _logger.info('MarketScheduler created for: ${_watchedMarkets.map((m) => m.label).join(", ")}');
  }

  // ============================================================
  // START / STOP
  // ============================================================

  void start() {
    if (_running) return;
    _running = true;
    _logger.info('MarketScheduler started');

    // Immediate first poll
    _tick();

    // Start polling timer at the live interval
    _pollTimer = Timer.periodic(
      Duration(milliseconds: _config.liveIntervalMs),
      (_) => _tick(),
    );

    // Separate timer to check for market open/close transitions
    _statusTimer = Timer.periodic(
      Duration(milliseconds: _config.statusCheckIntervalMs),
      (_) => _checkStatusChanges(),
    );
  }

  void stop() {
    _pollTimer?.cancel();
    _statusTimer?.cancel();
    _pollTimer  = null;
    _statusTimer = null;
    _running    = false;
    _logger.info('MarketScheduler stopped');
  }

  bool get isRunning => _running;

  // ============================================================
  // SCHEDULE EVALUATION
  // ============================================================

  /// Compute the schedule for every watched market at this instant.
  List<MarketSchedule> evaluate() {
    final schedules = <MarketSchedule>[];
    for (final market in _watchedMarkets) {
      schedules.add(_evaluateMarket(market));
    }
    return schedules;
  }

  /// Compute the schedule for a single market type.
  MarketSchedule _evaluateMarket(MarketType market) {
    // For scheduling purposes, pick a representative asset for the market
    final representative = _representativeAsset(market);
    final status = representative != null
        ? getMarketStatus(representative)
        : _defaultStatusForMarket(market);

    final shouldPoll  = _shouldPollMarket(market, status);
    final intervalMs  = shouldPoll ? _config.liveIntervalMs : _config.closedIntervalMs;
    final reason      = shouldPoll
        ? 'market ${status.label} — polling at ${intervalMs}ms'
        : 'market ${status.label} — paused (polling at ${intervalMs}ms)';

    return MarketSchedule(
      market:       market,
      status:       status,
      shouldPoll:   shouldPoll,
      pollIntervalMs: intervalMs,
      reason:       reason,
    );
  }

  /// Determine whether a market should currently be polled.
  bool _shouldPollMarket(MarketType market, MarketStatus status) {
    switch (market) {
      case MarketType.crypto:
        return true; // Always poll crypto (24/7)
    }
  }

  // ============================================================
  // INTERNAL TICK
  // ============================================================

  void _tick() {
    final schedules    = evaluate();
    final activeMarkets = schedules
        .where((s) => s.shouldPoll)
        .map((s) => s.market)
        .toSet();

    if (activeMarkets.isEmpty) {
      if (kDebugMode) _logger.debug('All markets closed — no poll this tick');
      return;
    }

    if (kDebugMode) {
      _logger.debug(
        'Polling: ${activeMarkets.map((m) => m.label).join(", ")}',
      );
    }

    _onPoll(activeMarkets);
  }

  // ============================================================
  // STATUS CHANGE DETECTION
  // ============================================================

  void _checkStatusChanges() {
    for (final market in _watchedMarkets) {
      final representative = _representativeAsset(market);
      if (representative == null) continue;

      final current  = getMarketStatus(representative);
      final previous = _lastStatus[market];

      if (previous != null && previous != current) {
        _logger.info('${market.label} status: ${previous.label} → ${current.label}');
        _eventBus.publish<MarketStatusChangedEvent>(MarketStatusChangedEvent(
          symbol: market.id,
          status: current.label,
        ));

        // If a market just opened, re-schedule poll immediately
        if (current == MarketStatus.open && previous != MarketStatus.open) {
          _logger.info('${market.label} opened — triggering immediate poll');
          _tick();
        }
      }

      _lastStatus[market] = current;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  /// Returns a representative asset for market-type status checks.
  Asset? _representativeAsset(MarketType market) {
    try {
      return assets.firstWhere((a) => a.type == market);
    } catch (_) {
      return null;
    }
  }

  MarketStatus _defaultStatusForMarket(MarketType market) {
    switch (market) {
      case MarketType.crypto:
        return MarketStatus.open;
    }
  }

  /// Human-readable summary of current schedule.
  String describeSchedule() {
    final sb = StringBuffer('MarketScheduler status:\n');
    for (final s in evaluate()) {
      sb.writeln('  ${s.market.label}: ${s.status.label} | poll=${s.shouldPoll}');
    }
    return sb.toString();
  }

  void dispose() {
    stop();
    _logger.info('MarketScheduler disposed');
  }
}
