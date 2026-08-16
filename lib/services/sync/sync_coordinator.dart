/// Sync coordinator — local-only database mode (Cloud sync removed).
///
/// Data is persisted directly to local SQLite database.
library;

class SyncCoordinator {
  static final SyncCoordinator _instance = SyncCoordinator._internal();
  static SyncCoordinator get instance => _instance;

  SyncCoordinator._internal();

  bool get isAuthenticated => false;
  String? get currentUserId => null;

  Future<void> enqueue(
    String tableName,
    String action,
    String recordId,
    Map<String, dynamic>? payload,
  ) async {
    // Local DB only; no cloud queuing needed.
  }

  void triggerProcessing() {}

  Future<void> processQueue() async {}

  Future<int> pendingCount() async => 0;

  Future<bool> hasCloudData(String userId) async => false;

  Future<void> syncDownAll(String userId) async {}

  Future<void> migrateGuestToCloud(String userId) async {}
}
