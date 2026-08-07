abstract class PortfolioRepository {
  Future<double> getInitialBalance(String userId);
  Future<double> getAvailableBalance(String userId);
  Future<void> saveBalances(String userId, double initial, double available);
  Future<void> clearPortfolio(String userId);
}
