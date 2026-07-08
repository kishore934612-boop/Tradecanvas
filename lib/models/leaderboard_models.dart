class LeaderboardEntry {
  final int rank;
  final String username;
  final double totalReturnPct;
  final double winRate;
  final int challengesCompleted;
  final bool isCurrentUser;
  final String country;

  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.totalReturnPct,
    required this.winRate,
    required this.challengesCompleted,
    this.isCurrentUser = false,
    this.country = 'Global',
  });
}
