/// Order Controller
///
/// Manages pending orders (limit, stop, stop-limit), validates orders,
/// checks trigger conditions on price updates, and cancels orders.
/// Extracted from TradingProvider as part of Phase 4 refactoring.
library;

import 'package:flutter/foundation.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/constants/markets.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/engine/trading_engine.dart';

/// Result of placing an order.
class OrderResult {
  final bool success;
  final String? error;
  final String? message;
  final PendingOrder? order;

  const OrderResult({
    required this.success,
    this.error,
    this.message,
    this.order,
  });

  factory OrderResult.ok({String? message, PendingOrder? order}) =>
      OrderResult(success: true, message: message, order: order);

  factory OrderResult.fail(String error) =>
      OrderResult(success: false, error: error);
}

class OrderController extends ChangeNotifier {
  final EventBus _eventBus;
  final Logger _logger;

  final List<PendingOrder> _pendingOrders = [];

  OrderController({
    required EventBus this._eventBus,
    required Logger this._logger,
  }) {
    _logger.info('OrderController initialized');
  }

  // ============================================================
  // GETTERS
  // ============================================================

  List<PendingOrder> get pendingOrders => List.unmodifiable(_pendingOrders);

  PendingOrder? getOrder(String orderId) {
    try {
      return _pendingOrders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }

  List<PendingOrder> getOrdersBySymbol(String symbol) =>
      _pendingOrders.where((o) => o.symbol == symbol).toList();

  bool get hasPendingOrders => _pendingOrders.isNotEmpty;
  int get pendingOrderCount => _pendingOrders.length;

  // ============================================================
  // VALIDATE
  // ============================================================

  /// Returns null when valid; a human-readable error string when invalid.
  String? validateOrder({
    required String symbol,
    required PositionSide side,
    required double qty,
    required double leverage,
    required double freeMargin,
    required double referencePrice,
    required MarketConfig config,
    double? limitPrice,
    double? stopPrice,
  }) {
    if (qty <= 0) return 'Quantity must be positive';
    if (!config.shortSellingAllowed && side == PositionSide.short) {
      return 'Short selling not allowed in ${config.toString()} mode';
    }
    if (!config.leverageAllowed && leverage > 1.0) {
      return 'Leverage not available for this instrument';
    }
    if (leverage > config.maxLeverage) {
      return 'Max leverage is ${config.maxLeverage}x';
    }

    // Estimate required margin
    final estPrice = limitPrice ?? stopPrice ?? referencePrice;
    final actualQty = config.lotSizeUsed ? qty * config.lotBaseUnits : qty;
    final estNotional = actualQty * estPrice;
    final estMargin = config.leverageAllowed ? estNotional / leverage : estNotional;

    if (estMargin > freeMargin) {
      return 'Insufficient free margin for this order';
    }

    return null; // Valid
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  /// Queues a pending limit / stop / stop-limit order.
  /// Market orders should NOT be routed through here — use PositionController
  /// directly for market fills.
  OrderResult placeOrder({
    required String symbol,
    required OrderType type,
    required PositionSide side,
    required double qty,
    required double leverage,
    required MarketType marketType,
    required TradingType tradingType,
    required double freeMargin,
    required double referencePrice,
    required String genId,
    double? limitPrice,
    double? stopPrice,
    double? stopLoss,
    double? takeProfit,
    double? trailingStop,
    EntryJournal? entryJournal,
  }) {
    if (type == OrderType.market) {
      return OrderResult.fail('Market orders must be executed immediately, not queued');
    }

    final asset = getAssetBySymbol(symbol);
    if (asset == null) return OrderResult.fail('Asset not found');

    final config = MarketConfig.get(marketType, tradingType);

    // Validate
    if ((type == OrderType.limit || type == OrderType.stopLimit) && limitPrice == null) {
      return OrderResult.fail('Limit price required');
    }
    if ((type == OrderType.stop || type == OrderType.stopLimit) && stopPrice == null) {
      return OrderResult.fail('Stop price required');
    }

    // Phase 5: Delegate validation to TradingEngine
    final validationError = TradingEngine.validateTrade(
      symbol: symbol,
      side: side,
      qty: qty,
      leverage: leverage,
      freeMargin: freeMargin,
      entryPrice: referencePrice,
      config: config,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
    );
    if (validationError != null) return OrderResult.fail(validationError);

    final order = PendingOrder(
      id: genId,
      symbol: symbol,
      type: type,
      side: side,
      qty: qty,
      leverage: leverage,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
      stopLoss: stopLoss,
      takeProfit: takeProfit,
      trailingStop: trailingStop,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      marketType: marketType,
      tradingType: tradingType,
      entryJournal: entryJournal,
    );

    _pendingOrders.insert(0, order);
    _logger.info('Order placed: ${type.label} ${side.label} $qty $symbol');

    _eventBus.publish<OrderPlacedEvent>(OrderPlacedEvent(
      orderId: order.id,
      symbol: symbol,
      orderType: type.label,
      triggerPrice: limitPrice ?? stopPrice ?? referencePrice,
    ));

    notifyListeners();
    return OrderResult.ok(message: '${type.label} order placed', order: order);
  }

  // ============================================================
  // CANCEL
  // ============================================================

  bool cancelOrder(String orderId) {
    final idx = _pendingOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) {
      _logger.warning('cancelOrder: order $orderId not found');
      return false;
    }

    final order = _pendingOrders[idx];
    _pendingOrders.removeAt(idx);
    _logger.info('Order cancelled: ${order.symbol} (${order.type.label})');

    _eventBus.publish<OrderCancelledEvent>(OrderCancelledEvent(
      orderId: orderId,
      reason: 'user_cancelled',
    ));

    notifyListeners();
    return true;
  }

  // ============================================================
  // TRIGGER CHECK
  // ============================================================

  /// Returns orders that should fill at [currentPrice] for [symbol].
  /// Removes them from the pending list.
  List<PendingOrder> consumeTriggeredOrders(String symbol, double currentPrice) {
    final triggered = <PendingOrder>[];

    for (final order in List<PendingOrder>.from(_pendingOrders)) {
      if (order.symbol != symbol) continue;
      if (order.shouldFill(currentPrice)) {
        triggered.add(order);
      }
    }

    if (triggered.isNotEmpty) {
      for (final o in triggered) {
        _pendingOrders.remove(o);
      }
      _logger.info(
        '${triggered.length} order(s) triggered for $symbol @ \$$currentPrice',
      );
      notifyListeners();
    }

    return triggered;
  }

  /// Returns all orders that should fill across any symbol,
  /// given a map of current prices.  Removes them from the pending list.
  List<PendingOrder> consumeAllTriggeredOrders(Map<String, double> currentPrices) {
    final triggered = <PendingOrder>[];

    for (final order in List<PendingOrder>.from(_pendingOrders)) {
      final price = currentPrices[order.symbol];
      if (price == null || price <= 0) continue;
      if (order.shouldFill(price)) {
        triggered.add(order);
      }
    }

    if (triggered.isNotEmpty) {
      for (final o in triggered) {
        _pendingOrders.remove(o);
      }
      _logger.info('${triggered.length} order(s) triggered across all symbols');
      notifyListeners();
    }

    return triggered;
  }

  // ============================================================
  // STATE MANAGEMENT
  // ============================================================

  Map<String, dynamic> toJson() => {
        'pendingOrders': _pendingOrders.map((o) => o.toJson()).toList(),
      };

  void fromJson(Map<String, dynamic> json) {
    _pendingOrders.clear();
    final data = (json['pendingOrders'] ?? json['orders']) as List<dynamic>?;
    if (data != null) {
      for (final item in data) {
        try {
          _pendingOrders.add(PendingOrder.fromJson(item as Map<String, dynamic>));
        } catch (e) {
          _logger.error('Failed to load order: $e');
        }
      }
    }
    _logger.info('Order state loaded: ${_pendingOrders.length} pending orders');
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.info('OrderController disposed');
    super.dispose();
  }
}
