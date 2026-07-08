/// Events related to market data
library;

import 'package:app/core/events/event_bus.dart';

/// Price updated event
class PriceUpdatedEvent extends AppEvent {
  final String symbol;
  final double price;
  final double change;
  final String source; // 'binance-ws', 'binance-rest', 'yahoo'
  
  PriceUpdatedEvent({
    required this.symbol,
    required this.price,
    required this.change,
    required this.source,
  });
}

/// Market status changed event
class MarketStatusChangedEvent extends AppEvent {
  final String symbol;
  final String status; // 'open', 'closed', 'preMarket', 'afterHours'
  
  MarketStatusChangedEvent({
    required this.symbol,
    required this.status,
  });
}

/// Candle updated event (for chart)
class CandleUpdatedEvent extends AppEvent {
  final String symbol;
  final String timeframe;
  final bool isNewCandle; // true if new candle started, false if existing candle updated
  
  CandleUpdatedEvent({
    required this.symbol,
    required this.timeframe,
    required this.isNewCandle,
  });
}

/// Market connection status event
class MarketConnectionEvent extends AppEvent {
  final String provider; // 'binance', 'yahoo'
  final bool connected;
  final String? error;
  
  MarketConnectionEvent({
    required this.provider,
    required this.connected,
    this.error,
  });
}
