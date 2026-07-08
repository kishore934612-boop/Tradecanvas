import 'package:flutter/material.dart';

enum LessonCategory {
  beginner,
  technicalAnalysis,
  tradingStrategies,
  riskManagement,
  tradingPsychology
}

extension LessonCategoryX on LessonCategory {
  String get label {
    switch (this) {
      case LessonCategory.beginner:
        return 'Beginner';
      case LessonCategory.technicalAnalysis:
        return 'Technical Analysis';
      case LessonCategory.tradingStrategies:
        return 'Trading Strategies';
      case LessonCategory.riskManagement:
        return 'Risk Management';
      case LessonCategory.tradingPsychology:
        return 'Trading Psychology';
    }
  }

  IconData get icon {
    switch (this) {
      case LessonCategory.beginner:
        return Icons.school_outlined;
      case LessonCategory.technicalAnalysis:
        return Icons.analytics_outlined;
      case LessonCategory.tradingStrategies:
        return Icons.query_stats_outlined;
      case LessonCategory.riskManagement:
        return Icons.gavel_outlined;
      case LessonCategory.tradingPsychology:
        return Icons.psychology_outlined;
    }
  }
}

class Lesson {
  final String id;
  final String title;
  final LessonCategory category;
  final String content;
  final int estimatedTimeMinutes;
  final IconData icon;
  bool isCompleted;
  int? lastReadTimestamp;

  Lesson({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.estimatedTimeMinutes,
    required this.icon,
    this.isCompleted = false,
    this.lastReadTimestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isCompleted': isCompleted,
        'lastReadTimestamp': lastReadTimestamp,
      };

  void loadProgress(Map<String, dynamic> json) {
    isCompleted = json['isCompleted'] ?? false;
    lastReadTimestamp = json['lastReadTimestamp'];
  }
}

class QuizQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  int? selectedOptionIndex;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.selectedOptionIndex,
  });

  bool get isCorrect => selectedOptionIndex == correctAnswerIndex;
  bool get isAnswered => selectedOptionIndex != null;
}

class Quiz {
  final String id;
  final String title;
  final LessonCategory category;
  final List<QuizQuestion> questions;
  bool isCompleted;
  int highestScore; // percentage or correct answers count

  Quiz({
    required this.id,
    required this.title,
    required this.category,
    required this.questions,
    this.isCompleted = false,
    this.highestScore = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isCompleted': isCompleted,
        'highestScore': highestScore,
      };

  void loadProgress(Map<String, dynamic> json) {
    isCompleted = json['isCompleted'] ?? false;
    highestScore = json['highestScore'] ?? 0;
  }
}
