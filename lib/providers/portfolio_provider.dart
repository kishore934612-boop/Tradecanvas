import 'package:flutter/foundation.dart';
import 'package:app/constants/markets.dart';
import 'package:app/controllers/portfolio_controller.dart';
import 'package:app/controllers/position_controller.dart';
import 'package:app/core/events/event_bus.dart';
import 'package:app/core/events/portfolio_events.dart';
import 'package:app/core/events/trade_events.dart';
import 'package:app/core/events/market_events.dart';

class PortfolioProvider extends ChangeNotifier {
  final PortfolioController _portfolioController;
  final PositionController _positionController;
  final EventBus _eventBus;
  
  // Track last known prices for unrealized calculation
  final Map<String, double> _currentPrices = {};

  PortfolioProvider({
    required PortfolioController this._portfolioController,
    required PositionController this._positionController,
    required EventBus this._eventBus,
  }) {
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    // Listen to price updates to calculate unrealized P&L
    _eventBus.on<PriceUpdatedEvent>().listen((event) {
      _currentPrices[event.symbol] = event.price;
      notifyListeners();
    });

    // Listen to balance changes
    _eventBus.on<BalanceChangedEvent>().listen((_) {
      notifyListeners();
    });

    // Listen to trade changes
    _eventBus.on<TradeCompletedEvent>().listen((_) {
      notifyListeners();
    });
  }

  // --- FINANCIAL GETTERS ---
  double get balance => _portfolioController.balance;
  double get startingCapital => _portfolioController.startingCapital;
  double get realizedPnl => _portfolioController.realizedPnl;

  double get unrealizedPnl {
    return _positionController.getUnrealizedPnl(_currentPrices);
  }

  double get usedMargin {
    return _positionController.getUsedMargin();
  }

  double get equity {
    return _portfolioController.calculateEquity(unrealizedPnl, usedMargin);
  }

  double get freeMargin {
    return _portfolioController.calculateFreeMargin(equity, usedMargin);
  }

  double get marginLevel {
    return _portfolioController.calculateMarginLevel(equity, usedMargin);
  }

  double get totalReturnPct {
    return _portfolioController.calculateTotalReturnPct(equity);
  }

  double get dailyPnl {
    return _portfolioController.getDailyPnl(unrealizedPnl);
  }

  // --- ALLOCATION CHART SEGMENTS ---
  List<double> getTradingTypeAllocations() {
    double spotVal = 0.0;
    double futuresVal = 0.0;

    for (final p in _positionController.openPositions) {
      final currentPrice = _currentPrices[p.symbol] ?? p.entryPrice;
      final val = p.margin + p.pnl(currentPrice);
      if (p.tradingType == TradingType.spot) {
        spotVal += val;
      } else if (p.tradingType == TradingType.futures) {
        futuresVal += val;
      }
    }

    return [balance, spotVal, futuresVal];
  }
}
