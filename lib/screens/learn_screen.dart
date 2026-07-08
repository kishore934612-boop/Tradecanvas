import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/learn_models.dart';
import 'package:app/providers/learn_provider.dart';
import 'package:app/components/ui.dart';
import 'package:app/screens/lesson_detail_screen.dart';
import 'package:app/screens/quiz_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final learnProvider = Provider.of<LearnProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ScreenHeader(title: 'Academy'),
            const SizedBox(height: 12.0),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 100.0),
                children: [
                  _buildRoadmapPhase(context, learnProvider, LessonCategory.beginner, 1, colors, false),
                  _buildRoadmapPhase(context, learnProvider, LessonCategory.technicalAnalysis, 2, colors, false),
                  _buildRoadmapPhase(context, learnProvider, LessonCategory.tradingStrategies, 3, colors, false),
                  _buildRoadmapPhase(context, learnProvider, LessonCategory.riskManagement, 4, colors, false),
                  _buildRoadmapPhase(context, learnProvider, LessonCategory.tradingPsychology, 5, colors, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapPhase(
    BuildContext context,
    LearnProvider provider,
    LessonCategory category,
    int phaseNum,
    ThemePalette colors,
    bool isLast,
  ) {
    final lessons = provider.getLessonsByCategory(category);
    final quizzes = provider.getQuizzesByCategory(category);
    final completedCount = lessons.where((l) => l.isCompleted).length;
    final totalCount = lessons.length;
    final isPhaseCompleted = completedCount == totalCount && (quizzes.isEmpty || quizzes.every((q) => q.isCompleted));
    
    // Determine milestone state: completed, active, or locked/future
    bool isPreviousCompleted = true;
    for (int i = 0; i < category.index; i++) {
      final prevCat = LessonCategory.values[i];
      final prevLessons = provider.getLessonsByCategory(prevCat);
      final prevQuizzes = provider.getQuizzesByCategory(prevCat);
      final pc = prevLessons.where((l) => l.isCompleted).length;
      final pt = prevLessons.length;
      if (pc < pt || (prevQuizzes.isNotEmpty && !prevQuizzes.every((q) => q.isCompleted))) {
        isPreviousCompleted = false;
        break;
      }
    }

    final bool isCompleted = isPhaseCompleted;
    final bool isActive = !isCompleted && isPreviousCompleted;
    final bool isLocked = !isCompleted && !isActive;

    final Color nodeColor = isCompleted
        ? colors.positive
        : (isActive ? colors.primary : colors.mutedForeground.withValues(alpha: 0.3));

    final IconData nodeIcon = isCompleted
        ? Icons.check_circle_rounded
        : (isActive ? Icons.play_circle_filled_rounded : Icons.lock_outline_rounded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Milestone Node & Title
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Glowing Milestone circle node
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.card,
                border: Border.all(
                  color: nodeColor,
                  width: 2.5,
                ),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.4),
                    blurRadius: 10.0,
                    spreadRadius: 2.0,
                  )
                ] : null,
              ),
              child: Icon(
                nodeIcon,
                color: nodeColor,
                size: 18.0,
              ),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PHASE $phaseNum: ${category.label.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: nodeColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    _getPhaseDescription(category),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? colors.mutedForeground : colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '$completedCount of $totalCount Lessons Completed',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Roadmap line connecting downstream nodes + lesson sub-items
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vertical connecting line
            Container(
              width: 36.0,
              alignment: Alignment.center,
              child: Container(
                width: 2.5,
                height: (lessons.length + quizzes.length) * 78.0,
                color: isLast ? Colors.transparent : nodeColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                child: Column(
                  children: [
                    // Lessons list inside this milestone
                    ...lessons.map((lesson) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildRoadmapLessonCard(context, provider, lesson, colors, isLocked),
                      );
                    }),
                    
                    // Quizzes list inside this milestone
                    ...quizzes.map((quiz) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: _buildRoadmapQuizCard(context, quiz, colors, isLocked),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getPhaseDescription(LessonCategory category) {
    switch (category) {
      case LessonCategory.beginner:
        return 'Crypto Basics & Foundations';
      case LessonCategory.technicalAnalysis:
        return 'Charts, Trends & Indicators';
      case LessonCategory.tradingStrategies:
        return 'Proven Entry & Exit Setups';
      case LessonCategory.riskManagement:
        return 'Position Sizing & Margins';
      case LessonCategory.tradingPsychology:
        return 'Mastering Discipline & Logic';
    }
  }

  Widget _buildRoadmapLessonCard(
    BuildContext context,
    LearnProvider provider,
    Lesson lesson,
    ThemePalette colors,
    bool isLocked,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      child: InkWell(
        onTap: isLocked ? () {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please complete the previous phase to unlock this lesson.')),
          );
        } : () {
          HapticFeedback.lightImpact();
          provider.addRecentlyViewed(lesson.id);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonDetailScreen(lesson: lesson),
            ),
          );
        },
        child: Row(
          children: [
            Icon(
              lesson.isCompleted ? Icons.check_circle_rounded : Icons.menu_book_rounded,
              color: lesson.isCompleted ? colors.positive : (isLocked ? colors.mutedForeground.withValues(alpha: 0.4) : colors.primary),
              size: 20.0,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? colors.mutedForeground : colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '${lesson.estimatedTimeMinutes} min read',
                    style: TextStyle(fontSize: 11.0, color: colors.mutedForeground),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded, 
              color: isLocked ? colors.mutedForeground.withValues(alpha: 0.3) : colors.mutedForeground,
              size: 18.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapQuizCard(
    BuildContext context,
    Quiz quiz,
    ThemePalette colors,
    bool isLocked,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: quiz.isCompleted
            ? colors.positive.withValues(alpha: 0.05)
            : (isLocked ? colors.card.withValues(alpha: 0.5) : colors.card),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: quiz.isCompleted 
              ? colors.positive.withValues(alpha: 0.3)
              : (isLocked ? colors.border.withValues(alpha: 0.3) : colors.border),
          width: 0.8,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? () {
            HapticFeedback.vibrate();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please complete the previous phase to unlock this quiz.')),
            );
          } : () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QuizScreen(quiz: quiz),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
            child: Row(
              children: [
                Icon(
                  quiz.isCompleted ? Icons.verified_rounded : Icons.assignment_turned_in_rounded,
                  color: quiz.isCompleted ? colors.positive : (isLocked ? colors.mutedForeground.withValues(alpha: 0.4) : colors.accent),
                  size: 20.0,
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isLocked ? colors.mutedForeground : colors.foreground,
                        ),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        quiz.isCompleted
                            ? 'Quiz Passed  ·  Score: ${quiz.highestScore}%'
                            : 'Phase Quiz  ·  Test your knowledge',
                        style: TextStyle(fontSize: 11.0, color: colors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded, 
                  color: isLocked ? colors.mutedForeground.withValues(alpha: 0.3) : colors.mutedForeground,
                  size: 18.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
