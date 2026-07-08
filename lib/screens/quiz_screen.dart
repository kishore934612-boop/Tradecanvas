import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/learn_models.dart';
import 'package:app/providers/learn_provider.dart';
import 'package:app/components/ui.dart';

class QuizScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _correctCount = 0;
  bool _quizFinished = false;

  @override
  void initState() {
    super.initState();
    // Reset any previous selection state in questions
    for (final q in widget.quiz.questions) {
      q.selectedOptionIndex = null;
    }
  }

  void _onOptionSelected(QuizQuestion question, int index) {
    if (question.isAnswered) return; // Prevent multiple selection

    setState(() {
      question.selectedOptionIndex = index;
      if (question.isCorrect) {
        _correctCount++;
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < widget.quiz.questions.length - 1) {
        _currentQuestionIndex++;
      } else {
        _quizFinished = true;
        _saveScore();
      }
    });
  }

  void _saveScore() {
    final provider = context.read<LearnProvider>();
    final scorePercent = ((_correctCount / widget.quiz.questions.length) * 100).round();
    provider.completeQuiz(widget.quiz.id, scorePercent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final questions = widget.quiz.questions;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(title: widget.quiz.title, showBackButton: true),
            const SizedBox(height: 12.0),

            Expanded(
              child: _quizFinished
                  ? _buildQuizResult(colors)
                  : _buildQuestionCard(questions[_currentQuestionIndex], questions.length, colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestion question, int totalQuestions, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / totalQuestions,
              minHeight: 6.0,
              backgroundColor: colors.muted,
              valueColor: AlwaysStoppedAnimation(colors.primary),
            ),
          ),
          const SizedBox(height: 18.0),

          // Question count indicator
          Text(
            'QUESTION ${_currentQuestionIndex + 1} OF $totalQuestions',
            style: TextStyle(fontSize: 11.0, color: colors.mutedForeground, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 8.0),

          // Question Text
          Text(
            question.questionText,
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.foreground),
          ),
          const SizedBox(height: 24.0),

          // Options List
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: question.options.length,
              itemBuilder: (context, index) {
                final optionText = question.options[index];
                return _buildOptionTile(question, index, optionText, colors);
              },
            ),
          ),

          // Next Action Button
          if (question.isAnswered)
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: SizedBox(
                width: double.infinity,
                height: 48.0,
                child: ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentQuestionIndex == totalQuestions - 1 ? 'Show Results' : 'Next Question',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(QuizQuestion question, int index, String optionText, ThemePalette colors) {
    final isAnswered = question.isAnswered;
    final isSelected = question.selectedOptionIndex == index;
    final isCorrect = question.correctAnswerIndex == index;

    Color tileColor = colors.card;
    Color borderColor = colors.border;
    Widget trailingIcon = const SizedBox.shrink();

    if (isAnswered) {
      if (isCorrect) {
        // Highlight correct green
        tileColor = colors.positive.withValues(alpha: 0.12);
        borderColor = colors.positive;
        trailingIcon = Icon(Icons.check_circle_rounded, color: colors.positive, size: 20.0);
      } else if (isSelected) {
        // Highlight selected incorrect red
        tileColor = colors.destructive.withValues(alpha: 0.12);
        borderColor = colors.destructive;
        trailingIcon = Icon(Icons.cancel_rounded, color: colors.destructive, size: 20.0);
      }
    }

    return GestureDetector(
      onTap: () => _onOptionSelected(question, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            // Option letter (A, B, C, D)
            Container(
              width: 26.0,
              height: 26.0,
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.muted.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                String.fromCharCode(65 + index), // A, B, C, D
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (colors.brightness == Brightness.dark ? Colors.black : Colors.white)
                      : colors.foreground,
                ),
              ),
            ),
            const SizedBox(width: 14.0),

            // Option text
            Expanded(
              child: Text(
                optionText,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: colors.foreground,
                ),
              ),
            ),

            trailingIcon,
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResult(ThemePalette colors) {
    final total = widget.quiz.questions.length;
    final pct = ((_correctCount / total) * 100).round();
    final isPass = pct >= 70;

    return Padding(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72.0,
            height: 72.0,
            decoration: BoxDecoration(
              color: isPass ? colors.positive.withValues(alpha: 0.12) : colors.destructive.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPass ? Icons.celebration_rounded : Icons.sentiment_very_dissatisfied_rounded,
              color: isPass ? colors.positive : colors.destructive,
              size: 38.0,
            ),
          ),
          const SizedBox(height: 20.0),
          Text(
            isPass ? 'Congratulations!' : 'Keep Practicing!',
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w900, color: colors.foreground),
          ),
          const SizedBox(height: 6.0),
          Text(
            isPass
                ? 'You passed the quiz!'
                : 'You need 70% or higher to pass this quiz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: colors.mutedForeground),
          ),
          const SizedBox(height: 32.0),

          // Score card
          GlassCard(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text('SCORE', style: TextStyle(fontSize: 11.0, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    Text('$pct%', style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, color: isPass ? colors.positive : colors.destructive)),
                  ],
                ),
                Container(width: 1.0, height: 40.0, color: colors.border),
                Column(
                  children: [
                    Text('CORRECT', style: TextStyle(fontSize: 11.0, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4.0),
                    Text('$_correctCount / $total', style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 48.0,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                elevation: 0,
              ),
              child: const Text('Back to Academy', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20.0),
        ],
      ),
    );
  }
}
