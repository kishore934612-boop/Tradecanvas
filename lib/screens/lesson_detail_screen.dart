import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/learn_models.dart';
import 'package:app/providers/learn_provider.dart';
import 'package:app/components/ui.dart';

class LessonDetailScreen extends StatelessWidget {
  final Lesson lesson;

  const LessonDetailScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final learnProvider = Provider.of<LearnProvider>(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: lesson.category.label,
              showBackButton: true,
            ),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            '${lesson.estimatedTimeMinutes} min read'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (lesson.isCompleted) ...[
                          const SizedBox(width: 8.0),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: colors.positive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_rounded, size: 10.0, color: colors.positive),
                                const SizedBox(width: 2.0),
                                Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    color: colors.positive,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12.0),

                    // Render content blocks
                    _parseContent(lesson.content, colors),
                    const SizedBox(height: 32.0),

                    // Complete Lesson Action
                    if (!lesson.isCompleted)
                      SizedBox(
                        width: double.infinity,
                        height: 48.0,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            learnProvider.completeLesson(lesson.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lesson completed! +10 XP rewarded.')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Complete Lesson & Claim 10 XP',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        decoration: BoxDecoration(
                          color: colors.positive.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: colors.positive.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: colors.positive, size: 18.0),
                            const SizedBox(width: 8.0),
                            Text(
                              'You completed this lesson',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: colors.positive),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 50.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parses custom markdown subset: `# Heading`, `## Subheading`, `**Bold**`, Lists
  Widget _parseContent(String source, ThemePalette colors) {
    final List<Widget> children = [];
    final lines = source.split('\n');

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8.0));
        continue;
      }

      if (line.startsWith('# ')) {
        // H1 Heading
        children.add(Padding(
          padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
          child: Text(
            line.substring(2).trim(),
            style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w900, color: colors.foreground),
          ),
        ));
      } else if (line.startsWith('## ')) {
        // H2 Heading
        children.add(Padding(
          padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
          child: Text(
            line.substring(3).trim(),
            style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold, color: colors.foreground),
          ),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        // Unordered List
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('  •  ', style: TextStyle(color: colors.primary, fontSize: 13.0, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  line.substring(2).trim(),
                  style: TextStyle(fontSize: 13.5, color: colors.foreground, height: 1.4),
                ),
              ),
            ],
          ),
        ));
      } else if (line.trim().startsWith(RegExp(r'^\d+\.'))) {
        // Ordered List
        final splitIndex = line.indexOf('.') + 1;
        final listNum = line.substring(0, splitIndex).trim();
        final listText = line.substring(splitIndex).trim();
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('  $listNum  ', style: TextStyle(color: colors.primary, fontSize: 12.5, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  listText,
                  style: TextStyle(fontSize: 13.5, color: colors.foreground, height: 1.4),
                ),
              ),
            ],
          ),
        ));
      } else {
        // Standard Paragraph
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            line.trim(),
            style: TextStyle(fontSize: 13.5, color: colors.foreground, height: 1.45),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
