/// Trading engine service interface
/// 
/// Core trading calculations and business logic.
/// Independent from UI and data sources.
library;

import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';

/// Position opening calculation result
class PositionCalculation {
  final double positionValue;
  final double marginRequired;
  final double entryPrice;
  final double fees;
  final double liquidationPrice;
  final bool canOpen;
  final String? error;
  
  const PositionCalculation({
    required this.positionValue,
    required this.marginRequired,
    required this.entryPrice,
    required this.fees,
    required this.liquidationPrice,
    this.canOpen = true,
    this.error,
  });
}

/// Trade validation result
class TradeValidation {
  final bool isValid;
  final String? error;
  final List<String> warnings;
  
  const TradeValidation({
    required this.isValid,
    this.error,
    this.warnings = const [],
  });
  
  factory TradeValidation.valid({List<String> warnings = const []}) {
    return TradeValidation(isValid: true, warnings: warnings);
  }
  
  factory TradeValidation.invalid(String error) {
    return TradeValidation(isValid: false, error: error);
  }
}

/// Trading engine interface
abstract class TradingEngine {
  /// Calculate requirements for opening a position
  PositionCalculation calculatePositionOpen({
    required String symbol,
    required PositionSide side,
    required double quantity,
    required int leverage,
    required double entryPrice,
    required TradingType tradingType,
    required MarketType marketType,
  });
  
  /// Calculate position P&L
  double calculatePnL({
    required double entryPrice,
    required double currentPrice,
    required double quantity,
    required PositionSide side,
    required int leverage,
    required TradingType tradingType,
  });
  
  /// Calculate unrealized P&L for position
  double calculateUnrealizedPnL({
    required double entryPrice,
    required double currentPrice,
    required double quantity,
    required PositionSide side,
    required int leverage,
  });
  
  /// Calculate liquidation price
  double calculateLiquidationPrice({
    required double entryPrice,
    required PositionSide side,
    required int leverage,
    required double margin,
  });
  
  /// Calculate margin requirement
  double calculateMarginRequired({
    required double positionValue,
    required int leverage,
  });
  
  /// Calculate position value
  double calculatePositionValue({
    required double price,
    required double quantity,
    required int leverage,
  });
  
  /// Calculate fees
  double calculateFees({
    required double positionValue,
    required TradingType tradingType,
    required MarketType marketType,
    required bool isMaker,
  });
  
  /// Validate trade parameters
  TradeValidation validateTrade({
    required String symbol,
    required double quantity,
    required int leverage,
    required double balance,
    required double marginUsed,
    required TradingType tradingType,
    required MarketType marketType,
  });
  
  /// Check if position should be liquidated
  bool shouldLiquidate({
    required double entryPrice,
    required double currentPrice,
    required PositionSide side,
    required double margin,
    required int leverage,
  });
  
  /// Calculate margin level percentage
  double calculateMarginLevel({
    required double equity,
    required double marginUsed,
  });
  
  /// Calculate free margin
  double calculateFreeMargin({
    required double equity,
    required double marginUsed,
  });
}
