import 'package:flutter/foundation.dart';
import 'package:app/models/leaderboard_models.dart';
import 'package:app/services/leaderboard_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  final LeaderboardService _service;
  
  String _timeframe = 'weekly'; // 'daily', 'weekly', 'monthly'
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;

  LeaderboardProvider({required LeaderboardService service}) : _service = service;

  String get timeframe => _timeframe;
  List<LeaderboardEntry> get entries => _entries;
  bool get isLoading => _isLoading;

  void setTimeframe(String timeframe) {
    if (_timeframe != timeframe) {
      _timeframe = timeframe;
      notifyListeners();
    }
  }

  Future<void> fetchLeaderboard({
    required bool isAuthenticated,
    String? currentUsername,
    double currentUserReturn = 0.0,
    double currentUserWinRate = 0.0,
    int currentUserChallenges = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      _entries = await _service.getLeaderboard(
        timeframe: _timeframe,
        isAuthenticated: isAuthenticated,
        currentUsername: currentUsername,
        currentUserReturn: currentUserReturn,
        currentUserWinRate: currentUserWinRate,
        currentUserChallenges: currentUserChallenges,
      );
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }
}
