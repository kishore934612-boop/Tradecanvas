/// Portfolio data repository interface
/// 
/// Handles persistence and retrieval of portfolio state.
library;

import 'package:app/domain/entities/result.dart';

abstract class PortfolioRepository {
  /// Initialize and load stored data
  Future<Result<void>> load();
  
  /// Get account balance
  double getBalance();
  
  /// Save balance
  Future<Result<void>> saveBalance(double balance);
  
  /// Get starting capital
  double getStartingCapital();
  
  /// Save starting capital
  Future<Result<void>> saveStartingCapital(double capital);
  
  /// Get realized P&L
  double getRealizedPnl();
  
  /// Save realized P&L
  Future<Result<void>> saveRealizedPnl(double pnl);
  
  /// Get win/loss statistics
  Map<String, int> getWinLossStats();
  
  /// Save win/loss statistics
  Future<Result<void>> saveWinLossStats(int wins, int losses);
  
  /// Get daily P&L map
  Map<String, double> getDailyPnl();
  
  /// Save daily P&L
  Future<Result<void>> saveDailyPnl(String dayKey, double pnl);
  
  /// Get trades per day
  Map<String, int> getTradesPerDay();
  
  /// Save trades per day
  Future<Result<void>> saveTradesPerDay(String dayKey, int count);
  
  /// Reset all portfolio data
  Future<Result<void>> reset();
  
  /// Export portfolio data
  Future<Result<Map<String, dynamic>>> exportData();
  
  /// Import portfolio data
  Future<Result<void>> importData(Map<String, dynamic> data);
}
