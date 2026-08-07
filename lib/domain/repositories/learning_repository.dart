
abstract class LearningRepository {
  Future<void> saveProgress(
    String userId,
    String lessonId, {
    required bool completed,
    int? completionTime,
    int? quizScore,
    String? lastOpened,
  });
  Future<Map<String, dynamic>> getProgress(String userId);
  Future<void> clearProgress(String userId);
}
