import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/portfolio_events.dart';

enum NotificationType { marginCall, liquidation, dailyPnl, tradeCompleted }

class NotificationMessage {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final int timestamp;
  bool isRead;

  NotificationMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationManager extends ChangeNotifier {
  final EventBus _eventBus;
  final List<NotificationMessage> _notifications = [];
  final StreamController<NotificationMessage> _toastController =
      StreamController<NotificationMessage>.broadcast();
  StreamSubscription? _subMarginCall;
  StreamSubscription? _subLiquidation;
  StreamSubscription? _subDailyPnl;
  StreamSubscription? _subTradeCompleted;

  NotificationManager({required EventBus this._eventBus}) {
    _subscribeToEvents();
  }

  List<NotificationMessage> get notifications => List.unmodifiable(_notifications);
  
  Stream<NotificationMessage> get notificationStream => _toastController.stream;

  void _subscribeToEvents() {
    _subMarginCall = _eventBus.subscribe<MarginCallWarningEvent>((event) {
      final msg = NotificationMessage(
        id: 'margin_${DateTime.now().microsecondsSinceEpoch}_${_notifications.length}',
        type: NotificationType.marginCall,
        title: 'Margin Call Warning',
        body: 'Your margin level has dropped to ${event.marginLevel.toStringAsFixed(1)}%. Realize some P&L or add funds to prevent liquidation!',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addNotification(msg);
    });

    _subLiquidation = _eventBus.subscribe<LiquidationWarningEvent>((event) {
      final msg = NotificationMessage(
        id: 'liq_${event.positionId}_${DateTime.now().microsecondsSinceEpoch}_${_notifications.length}',
        type: NotificationType.liquidation,
        title: 'Liquidation Warning',
        body: 'Position for ${event.symbol} is near liquidation. Margin Level: ${event.marginLevel.toStringAsFixed(1)}%, Liquidation Price: \$${event.liquidationPrice.toStringAsFixed(2)}',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addNotification(msg);
    });

    _subDailyPnl = _eventBus.subscribe<DailyPnlUpdatedEvent>((event) {
      final msg = NotificationMessage(
        id: 'pnl_${DateTime.now().microsecondsSinceEpoch}_${_notifications.length}',
        type: NotificationType.dailyPnl,
        title: 'Daily Performance Update',
        body: 'Daily Realized P&L is \$${event.dailyPnl.toStringAsFixed(2)} across ${event.tradesCount} trades.',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addNotification(msg);
    });

    _subTradeCompleted = _eventBus.subscribe<TradeCompletedEvent>((event) {
      final sign = event.pnl >= 0 ? '+' : '';
      final msg = NotificationMessage(
        id: 'trade_${event.tradeId}_${DateTime.now().microsecondsSinceEpoch}_${_notifications.length}',
        type: NotificationType.tradeCompleted,
        title: event.isWin ? 'Trade Won! 🎉' : 'Trade Closed',
        body: 'Closed ${event.symbol} for $sign\$${event.pnl.toStringAsFixed(2)} (${event.closeReason}). R:R: ${event.riskReward?.toStringAsFixed(2) ?? 'N/A'}, Risk: ${event.riskPct.toStringAsFixed(2)}%',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      _addNotification(msg);
    });
  }

  void _addNotification(NotificationMessage msg) {
    _notifications.insert(0, msg);
    if (_notifications.length > 100) {
      _notifications.removeLast();
    }
    _toastController.add(msg);
    notifyListeners();
  }

  void markAsRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _subMarginCall?.cancel();
    _subLiquidation?.cancel();
    _subDailyPnl?.cancel();
    _subTradeCompleted?.cancel();
    _toastController.close();
    super.dispose();
  }
}
