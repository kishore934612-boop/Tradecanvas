abstract class StatisticsRepository {
  // User statistics (detailed analytics)
  Future<Map<String, dynamic>?> getUserStats(String userId);
  Future<void> saveUserStats(String userId, Map<String, dynamic> stats);
  
  // Leaderboard statistics (rankings only)
  Future<Map<String, dynamic>?> getLeaderboardStats(String userId);
  Future<void> saveLeaderboardStats(String userId, String username, double winRate, double returnPct, double netProfit);

  // Settings
  Future<Map<String, dynamic>?> getSettings(String userId);
  Future<void> saveSettings(String userId, String theme, String language, int defaultLeverage, String chartType);

  // Subscription status
  Future<Map<String, dynamic>?> getSubscription(String userId);
  Future<void> saveSubscription(String userId, String plan, String status, String? purchaseDate, String? expiryDate, String platform);
  
  Future<void> clearAllStats(String userId);
}
