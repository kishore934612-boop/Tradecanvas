/// Watchlist repository interface.
library;

abstract class WatchlistRepository {
  Future<List<String>> getWatchlist(String userId);
  Future<void> addToWatchlist(String userId, String symbol);
  Future<void> removeFromWatchlist(String userId, String symbol);
  Future<void> clearWatchlist(String userId);

  /// Persist an explicit ordering after a drag-to-reorder.
  Future<void> reorder(String userId, List<String> symbolsInOrder);
}
