import 'package:flutter/foundation.dart';
import 'package:app/models/learn_models.dart';
import 'package:app/services/learn_service.dart';

class LearnProvider extends ChangeNotifier {
  final LearnService _learnService;
  
  LessonCategory _selectedCategory = LessonCategory.beginner;
  final List<String> _recentlyViewedIds = [];

  LearnProvider({required this._learnService}) {
    _loadState();
  }

  // --- GETTERS ---
  LessonCategory get selectedCategory => _selectedCategory;
  List<Lesson> get lessons => _learnService.lessons;
  List<Quiz> get quizzes => _learnService.quizzes;

  List<Lesson> getLessonsByCategory(LessonCategory category) {
    return _learnService.lessons.where((l) => l.category == category).toList();
  }

  List<Quiz> getQuizzesByCategory(LessonCategory category) {
    return _learnService.quizzes.where((q) => q.category == category).toList();
  }

  List<Lesson> get completedLessons {
    return _learnService.lessons.where((l) => l.isCompleted).toList();
  }

  List<Lesson> get recentlyViewedLessons {
    return _recentlyViewedIds
        .map((id) => _learnService.lessons.firstWhere((l) => l.id == id))
        .toList();
  }

  double get overallProgressPct {
    if (_learnService.lessons.isEmpty) return 0.0;
    final completed = _learnService.lessons.where((l) => l.isCompleted).length;
    return completed / _learnService.lessons.length;
  }

  // --- ACTIONS ---
  void setSelectedCategory(LessonCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }



  void addRecentlyViewed(String lessonId) {
    final lesson = _findLesson(lessonId);
    if (lesson != null) {
      lesson.lastReadTimestamp = DateTime.now().millisecondsSinceEpoch;
      _recentlyViewedIds.remove(lessonId);
      _recentlyViewedIds.insert(0, lessonId);
      if (_recentlyViewedIds.length > 5) {
        _recentlyViewedIds.removeLast();
      }
      _learnService.saveProgress();
      notifyListeners();
    }
  }

  void completeLesson(String lessonId) {
    final lesson = _findLesson(lessonId);
    if (lesson != null && !lesson.isCompleted) {
      lesson.isCompleted = true;
      _learnService.saveProgress();
      notifyListeners();
    }
  }

  void completeQuiz(String quizId, int scorePercent) {
    final quiz = _learnService.quizzes.firstWhere((q) => q.id == quizId);
    if (!quiz.isCompleted) {
      quiz.isCompleted = true;
      quiz.highestScore = scorePercent;
      _learnService.saveProgress();
      notifyListeners();
    } else if (scorePercent > quiz.highestScore) {
      quiz.highestScore = scorePercent;
      _learnService.saveProgress();
      notifyListeners();
    }
  }

  void resetProgress() {
    for (final lesson in _learnService.lessons) {
      lesson.isCompleted = false;
      lesson.lastReadTimestamp = null;
    }
    for (final quiz in _learnService.quizzes) {
      quiz.isCompleted = false;
      quiz.highestScore = 0;
      for (final question in quiz.questions) {
        question.selectedOptionIndex = null;
      }
    }
    _recentlyViewedIds.clear();
    _learnService.saveProgress();
    notifyListeners();
  }

  // --- HELPERS ---
  Lesson? _findLesson(String id) {
    try {
      return _learnService.lessons.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadState() async {
    await _learnService.loadProgress();
    
    for (final l in _learnService.lessons) {
      if (l.lastReadTimestamp != null) {
        _recentlyViewedIds.add(l.id);
      }
    }

    // Sort recently viewed by timestamp descending
    _recentlyViewedIds.sort((a, b) {
      final la = _findLesson(a)?.lastReadTimestamp ?? 0;
      final lb = _findLesson(b)?.lastReadTimestamp ?? 0;
      return lb.compareTo(la);
    });

    // Keep top 5
    if (_recentlyViewedIds.length > 5) {
      _recentlyViewedIds.removeRange(5, _recentlyViewedIds.length);
    }

    notifyListeners();
  }
}
