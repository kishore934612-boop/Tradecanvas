import 'package:app/constants/markets.dart';

enum PositionSide { long, short }

extension PositionSideX on PositionSide {
  String get label => this == PositionSide.long ? 'Long' : 'Short';
  String get id => this == PositionSide.long ? 'long' : 'short';
}

PositionSide sideFromId(String id) => id == 'short' ? PositionSide.short : PositionSide.long;

enum MarginMode {
  isolated,
  cross;

  String get id => name;
  String get label => this == MarginMode.isolated ? 'Isolated' : 'Cross';
}

MarginMode marginModeFromId(String id) => id == 'cross' ? MarginMode.cross : MarginMode.isolated;

enum OrderType { market, limit, stop, stopLimit }

extension OrderTypeX on OrderType {
  String get label {
    switch (this) {
      case OrderType.market:
        return 'Market';
      case OrderType.limit:
        return 'Limit';
      case OrderType.stop:
        return 'Stop';
      case OrderType.stopLimit:
        return 'Stop Limit';
    }
  }

  String get id {
    switch (this) {
      case OrderType.market:
        return 'market';
      case OrderType.limit:
        return 'limit';
      case OrderType.stop:
        return 'stop';
      case OrderType.stopLimit:
        return 'stopLimit';
    }
  }
}

OrderType orderTypeFromId(String id) {
  switch (id) {
    case 'limit':
      return OrderType.limit;
    case 'stop':
      return OrderType.stop;
    case 'stopLimit':
      return OrderType.stopLimit;
    default:
      return OrderType.market;
  }
}

/// Journal captured before entering a trade.
class EntryJournal {
  final String reason; // Why are you entering?
  final String strategy;
  final int confidence; // 1-10

  const EntryJournal({this.reason = '', this.strategy = '', this.confidence = 5});

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'strategy': strategy,
        'confidence': confidence,
      };

  factory EntryJournal.fromJson(Map<String, dynamic> j) => EntryJournal(
        reason: j['reason'] ?? '',
        strategy: j['strategy'] ?? '',
        confidence: (j['confidence'] ?? 5) as int,
      );
}

/// Journal captured after closing a trade.
class ExitJournal {
  final String whatWentWell;
  final String whatWentWrong;
  final String emotionalState;
  final String lessonsLearned;

  const ExitJournal({
    this.whatWentWell = '',
    this.whatWentWrong = '',
    this.emotionalState = '',
    this.lessonsLearned = '',
  });

  Map<String, dynamic> toJson() => {
        'whatWentWell': whatWentWell,
        'whatWentWrong': whatWentWrong,
        'emotionalState': emotionalState,
        'lessonsLearned': lessonsLearned,
      };

  factory ExitJournal.fromJson(Map<String, dynamic> j) => ExitJournal(
        whatWentWell: j['whatWentWell'] ?? '',
        whatWentWrong: j['whatWentWrong'] ?? '',
        emotionalState: j['emotionalState'] ?? '',
        lessonsLearned: j['lessonsLearned'] ?? '',
      );
}

MarketType _decodeMarketType(dynamic raw) {
  return MarketType.crypto;
}

/// Helper: safely decode TradingType from string or null.
TradingType _decodeTradingType(dynamic raw, MarketType market) {
  if (raw is String) {
    return tradingTypeFromId(raw);
  }
  return defaultTradingType(market);
}

/// An open leveraged position.
class Position {
  final String id;
  final String symbol;
  final PositionSide side;
  double qty;
  double entryPrice;
  final double leverage;
  double margin; // cash locked as collateral
  double fees; // fees paid on entry
  double? stopLoss;
  double? takeProfit;
  double? trailingStop; // distance in price terms; null = disabled
  double? trailingAnchor; // best price reached (for trailing calc)
  final int openedAt;
  final MarketType marketType;
  final TradingType tradingType;
  final EntryJournal? entryJournal;
  final double initialRiskPerUnit; // |entry - stop| at open, for R:R / risk%
  double accumulatedFunding; // accumulated funding fees (futures)
  final MarginMode marginMode;

  Position({
    required this.id,
    required this.symbol,
    required this.side,
    required this.qty,
    required this.entryPrice,
    required this.leverage,
    required this.margin,
    required this.fees,
    required this.openedAt,
    required this.marketType,
    this.tradingType = TradingType.spot,
    this.stopLoss,
    this.takeProfit,
    this.trailingStop,
    this.trailingAnchor,
    this.entryJournal,
    this.initialRiskPerUnit = 0.0,
    this.accumulatedFunding = 0.0,
    this.marginMode = MarginMode.isolated,
  });

  double get notional => qty * entryPrice;

  double pnl(double price) {
    final raw = side == PositionSide.long
        ? (price - entryPrice) * qty
        : (entryPrice - price) * qty;
    return raw - accumulatedFunding;
  }

  double pnlPct(double price) {
    if (margin <= 0) return 0;
    return (pnl(price) / margin) * 100.0;
  }

  /// Proper liquidation price based on Maintenance Margin Rate (MMR = 0.5%).
  double get liquidationPrice {
    if (!MarketConfig.get(marketType, tradingType).liquidationExists || leverage <= 0) return 0;
    final mmr = 0.005; // 0.5% MMR
    if (side == PositionSide.long) {
      final num = entryPrice * (1.0 - 1.0 / leverage);
      final den = 1.0 - mmr;
      return den <= 0 ? 0.0 : num / den;
    } else {
      final num = entryPrice * (1.0 + 1.0 / leverage);
      final den = 1.0 + mmr;
      return num / den;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'side': side.id,
        'qty': qty,
        'entryPrice': entryPrice,
        'leverage': leverage,
        'margin': margin,
        'fees': fees,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'trailingStop': trailingStop,
        'trailingAnchor': trailingAnchor,
        'openedAt': openedAt,
        'marketType': marketType.id,
        'tradingType': tradingType.id,
        'entryJournal': entryJournal?.toJson(),
        'initialRiskPerUnit': initialRiskPerUnit,
        'accumulatedFunding': accumulatedFunding,
        'marginMode': marginMode.id,
      };

  factory Position.fromJson(Map<String, dynamic> j) {
    final mt = _decodeMarketType(j['marketType']);
    return Position(
      id: j['id'],
      symbol: j['symbol'],
      side: sideFromId(j['side'] ?? 'long'),
      qty: (j['qty'] as num).toDouble(),
      entryPrice: (j['entryPrice'] as num).toDouble(),
      leverage: (j['leverage'] as num?)?.toDouble() ?? 1.0,
      margin: (j['margin'] as num?)?.toDouble() ?? 0.0,
      fees: (j['fees'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (j['stopLoss'] as num?)?.toDouble(),
      takeProfit: (j['takeProfit'] as num?)?.toDouble(),
      trailingStop: (j['trailingStop'] as num?)?.toDouble(),
      trailingAnchor: (j['trailingAnchor'] as num?)?.toDouble(),
      openedAt: j['openedAt'] as int,
      marketType: mt,
      tradingType: _decodeTradingType(j['tradingType'], mt),
      entryJournal: j['entryJournal'] != null ? EntryJournal.fromJson(j['entryJournal']) : null,
      initialRiskPerUnit: (j['initialRiskPerUnit'] as num?)?.toDouble() ?? 0.0,
      accumulatedFunding: (j['accumulatedFunding'] as num?)?.toDouble() ?? 0.0,
      marginMode: marginModeFromId(j['marginMode'] ?? 'isolated'),
    );
  }
}

/// A pending (not yet filled) order.
class PendingOrder {
  final String id;
  final String symbol;
  final OrderType type;
  final PositionSide side;
  final double qty;
  final double leverage;
  final double? limitPrice;
  final double? stopPrice;
  final double? stopLoss;
  final double? takeProfit;
  final double? trailingStop;
  final int createdAt;
  final MarketType marketType;
  final TradingType tradingType;
  final EntryJournal? entryJournal;
  final MarginMode marginMode;

  PendingOrder({
    required this.id,
    required this.symbol,
    required this.type,
    required this.side,
    required this.qty,
    required this.leverage,
    required this.createdAt,
    required this.marketType,
    this.tradingType = TradingType.spot,
    this.limitPrice,
    this.stopPrice,
    this.stopLoss,
    this.takeProfit,
    this.trailingStop,
    this.entryJournal,
    this.marginMode = MarginMode.isolated,
  });

  /// Returns true when [price] satisfies the trigger condition.
  bool shouldFill(double price) {
    switch (type) {
      case OrderType.market:
        return true;
      case OrderType.limit:
        // Buy/long limit fills at or below limit; sell/short at or above.
        if (limitPrice == null) return false;
        return side == PositionSide.long ? price <= limitPrice! : price >= limitPrice!;
      case OrderType.stop:
        if (stopPrice == null) return false;
        return side == PositionSide.long ? price >= stopPrice! : price <= stopPrice!;
      case OrderType.stopLimit:
        // Trigger when stop is crossed, then require limit condition.
        if (stopPrice == null || limitPrice == null) return false;
        final triggered = side == PositionSide.long ? price >= stopPrice! : price <= stopPrice!;
        if (!triggered) return false;
        return side == PositionSide.long ? price <= limitPrice! : price >= limitPrice!;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'type': type.id,
        'side': side.id,
        'qty': qty,
        'leverage': leverage,
        'limitPrice': limitPrice,
        'stopPrice': stopPrice,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'trailingStop': trailingStop,
        'createdAt': createdAt,
        'marketType': marketType.id,
        'tradingType': tradingType.id,
        'entryJournal': entryJournal?.toJson(),
        'marginMode': marginMode.id,
      };

  factory PendingOrder.fromJson(Map<String, dynamic> j) {
    final mt = _decodeMarketType(j['marketType']);
    return PendingOrder(
      id: j['id'],
      symbol: j['symbol'],
      type: orderTypeFromId(j['type'] ?? 'market'),
      side: sideFromId(j['side'] ?? 'long'),
      qty: (j['qty'] as num).toDouble(),
      leverage: (j['leverage'] as num?)?.toDouble() ?? 1.0,
      limitPrice: (j['limitPrice'] as num?)?.toDouble(),
      stopPrice: (j['stopPrice'] as num?)?.toDouble(),
      stopLoss: (j['stopLoss'] as num?)?.toDouble(),
      takeProfit: (j['takeProfit'] as num?)?.toDouble(),
      trailingStop: (j['trailingStop'] as num?)?.toDouble(),
      createdAt: j['createdAt'] as int,
      marketType: mt,
      tradingType: _decodeTradingType(j['tradingType'], mt),
      entryJournal: j['entryJournal'] != null ? EntryJournal.fromJson(j['entryJournal']) : null,
      marginMode: marginModeFromId(j['marginMode'] ?? 'isolated'),
    );
  }
}

/// A closed trade record.
class Trade {
  final String id;
  final String symbol;
  final String name;
  final PositionSide side;
  final double qty;
  final double entryPrice;
  final double exitPrice;
  final double leverage;
  final double fees;
  final int openedAt;
  final int closedAt;
  final double pnl;
  final double pnlPct;
  final MarketType marketType;
  final TradingType tradingType;
  final double? stopLoss;
  final double? takeProfit;
  final double? riskReward;
  final double riskPct; // risk as % of equity at entry
  final String closeReason; // 'manual' | 'stopLoss' | 'takeProfit' | 'liquidation' | 'trailingStop'
  final EntryJournal? entryJournal;
  ExitJournal? exitJournal;
  String notes;

  Trade({
    required this.id,
    required this.symbol,
    required this.name,
    required this.side,
    required this.qty,
    required this.entryPrice,
    required this.exitPrice,
    required this.leverage,
    required this.fees,
    required this.openedAt,
    required this.closedAt,
    required this.pnl,
    required this.pnlPct,
    required this.marketType,
    this.tradingType = TradingType.spot,
    this.stopLoss,
    this.takeProfit,
    this.riskReward,
    this.riskPct = 0.0,
    this.closeReason = 'manual',
    this.entryJournal,
    this.exitJournal,
    this.notes = '',
  });

  bool get isWin => pnl >= 0;
  int get durationMs => closedAt - openedAt;

  /// Classifies the trade by holding duration into a trading style bucket.
  String get styleBucket {
    final mins = durationMs / 60000.0;
    if (mins < 15) return 'Scalping';
    if (mins < 60 * 8) return 'Day Trading';
    if (mins < 60 * 24 * 7) return 'Swing Trading';
    return 'Position Trading';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'name': name,
        'side': side.id,
        'qty': qty,
        'entryPrice': entryPrice,
        'exitPrice': exitPrice,
        'leverage': leverage,
        'fees': fees,
        'openedAt': openedAt,
        'closedAt': closedAt,
        'pnl': pnl,
        'pnlPct': pnlPct,
        'marketType': marketType.id,
        'tradingType': tradingType.id,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'riskReward': riskReward,
        'riskPct': riskPct,
        'closeReason': closeReason,
        'entryJournal': entryJournal?.toJson(),
        'exitJournal': exitJournal?.toJson(),
        'notes': notes,
      };

  factory Trade.fromJson(Map<String, dynamic> j) {
    final mt = _decodeMarketType(j['marketType']);
    return Trade(
      id: j['id'],
      symbol: j['symbol'],
      name: j['name'],
      side: sideFromId(j['side'] ?? 'long'),
      qty: (j['qty'] as num).toDouble(),
      entryPrice: (j['entryPrice'] as num).toDouble(),
      exitPrice: (j['exitPrice'] as num).toDouble(),
      leverage: (j['leverage'] as num?)?.toDouble() ?? 1.0,
      fees: (j['fees'] as num?)?.toDouble() ?? 0.0,
      openedAt: j['openedAt'] as int,
      closedAt: j['closedAt'] as int,
      pnl: (j['pnl'] as num).toDouble(),
      pnlPct: (j['pnlPct'] as num).toDouble(),
      marketType: mt,
      tradingType: _decodeTradingType(j['tradingType'], mt),
      stopLoss: (j['stopLoss'] as num?)?.toDouble(),
      takeProfit: (j['takeProfit'] as num?)?.toDouble(),
      riskReward: (j['riskReward'] as num?)?.toDouble(),
      riskPct: (j['riskPct'] as num?)?.toDouble() ?? 0.0,
      closeReason: j['closeReason'] ?? 'manual',
      entryJournal: j['entryJournal'] != null ? EntryJournal.fromJson(j['entryJournal']) : null,
      exitJournal: j['exitJournal'] != null ? ExitJournal.fromJson(j['exitJournal']) : null,
      notes: j['notes'] ?? '',
    );
  }
}

class NewsArticle {
  final String id;
  final String title;
  final String description;
  final String impactSymbol;
  final String sentiment; // 'bullish' | 'bearish'
  final double impactFactor;
  final int timestamp;

  NewsArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.impactSymbol,
    required this.sentiment,
    required this.impactFactor,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'impactSymbol': impactSymbol,
        'sentiment': sentiment,
        'impactFactor': impactFactor,
        'timestamp': timestamp,
      };

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
        id: j['id'],
        title: j['title'],
        description: j['description'],
        impactSymbol: j['impactSymbol'],
        sentiment: j['sentiment'],
        impactFactor: (j['impactFactor'] as num).toDouble(),
        timestamp: j['timestamp'] as int,
      );
}

class TradeResult {
  final bool success;
  final String? error;
  final String? message;
  TradeResult({required this.success, this.error, this.message});
}
