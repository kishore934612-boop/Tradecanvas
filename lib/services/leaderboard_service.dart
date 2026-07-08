import 'package:app/models/leaderboard_models.dart';

class LeaderboardService {
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String timeframe, // 'daily', 'weekly', 'monthly'
    bool isAuthenticated = false,
    String? currentUsername,
    double currentUserReturn = 0.0,
    double currentUserWinRate = 0.0,
    int currentUserChallenges = 0,
  }) async {
    // Return mock leaderboard entries
    final entries = _generateMockEntries(timeframe);

    if (isAuthenticated) {
      // Create user entry
      final userEntry = LeaderboardEntry(
        rank: 4, // Assume user is rank 4 for display
        username: currentUsername ?? 'You',
        totalReturnPct: currentUserReturn,
        winRate: currentUserWinRate,
        challengesCompleted: currentUserChallenges,
        isCurrentUser: true,
        country: 'Global',
      );

      // Insert user entry at index 3 (rank 4) and adjust ranks after that
      final List<LeaderboardEntry> merged = [];
      int rankOffset = 1;
      for (int i = 0; i < entries.length; i++) {
        if (i == 3) {
          merged.add(userEntry);
          rankOffset = 2;
        }
        final e = entries[i];
        merged.add(LeaderboardEntry(
          rank: i + rankOffset,
          username: e.username,
          totalReturnPct: e.totalReturnPct,
          winRate: e.winRate,
          challengesCompleted: e.challengesCompleted,
          country: e.country,
        ));
      }
      return merged;
    }

    return entries;
  }

  List<LeaderboardEntry> _generateMockEntries(String timeframe) {
    // Generate distinct items depending on daily, weekly, or monthly
    final double mult = timeframe == 'monthly' ? 4.5 : (timeframe == 'weekly' ? 1.8 : 0.6);
    return [
      LeaderboardEntry(
        rank: 1,
        username: 'CryptoWhale',
        totalReturnPct: 42.5 * mult,
        winRate: 82.4,
        challengesCompleted: 18,
        country: 'US',
      ),
      LeaderboardEntry(
        rank: 2,
        username: 'SatoshiN',
        totalReturnPct: 35.2 * mult,
        winRate: 78.5,
        challengesCompleted: 15,
        country: 'JP',
      ),
      LeaderboardEntry(
        rank: 3,
        username: 'BullTrader',
        totalReturnPct: 29.8 * mult,
        winRate: 74.0,
        challengesCompleted: 12,
        country: 'IN',
      ),
      LeaderboardEntry(
        rank: 4,
        username: 'HodlMaster',
        totalReturnPct: 21.0 * mult,
        winRate: 68.2,
        challengesCompleted: 9,
        country: 'CA',
      ),
      LeaderboardEntry(
        rank: 5,
        username: 'LunaMoon',
        totalReturnPct: 15.5 * mult,
        winRate: 62.1,
        challengesCompleted: 6,
        country: 'KR',
      ),
      LeaderboardEntry(
        rank: 6,
        username: 'Altseason',
        totalReturnPct: 9.4 * mult,
        winRate: 55.4,
        challengesCompleted: 4,
        country: 'GB',
      ),
    ];
  }
}
