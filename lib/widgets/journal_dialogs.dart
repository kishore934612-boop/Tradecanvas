import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/trading_models.dart';

/// Pre-trade journal prompt (Module 6). Returns the captured [EntryJournal] when
/// the user confirms, or null if they cancel the trade.
Future<EntryJournal?> showEntryJournalDialog(BuildContext context) {
  final colors = AppColors.of(context);
  final reasonCtrl = TextEditingController();
  final strategyCtrl = TextEditingController();
  int confidence = 5;

  return showModalBottomSheet<EntryJournal>(
    context: context,
    backgroundColor: colors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16.0),
                  Text('Before You Trade', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  const SizedBox(height: 4.0),
                  Text('Capture your thinking. Great traders journal every entry.', style: TextStyle(fontSize: 13.0, color: colors.mutedForeground)),
                  const SizedBox(height: 18.0),
                  _field(colors, 'Why are you entering?', reasonCtrl, 'e.g. Breakout above resistance', maxLines: 2),
                  const SizedBox(height: 12.0),
                  _field(colors, 'Strategy used', strategyCtrl, 'e.g. Trend continuation'),
                  const SizedBox(height: 16.0),
                  Text('Confidence: $confidence / 10', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  Slider(
                    value: confidence.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: colors.primary,
                    label: '$confidence',
                    onChanged: (v) => setSheet(() => confidence = v.round()),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: Text('Cancel', style: TextStyle(color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(EntryJournal(reason: reasonCtrl.text.trim(), strategy: strategyCtrl.text.trim(), confidence: confidence)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                          ),
                          child: const Text('Confirm Trade', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Post-trade reflection prompt (Module 6).
Future<ExitJournal?> showExitJournalDialog(BuildContext context, {ExitJournal? existing}) {
  final colors = AppColors.of(context);
  final wellCtrl = TextEditingController(text: existing?.whatWentWell ?? '');
  final wrongCtrl = TextEditingController(text: existing?.whatWentWrong ?? '');
  final lessonsCtrl = TextEditingController(text: existing?.lessonsLearned ?? '');
  final emotions = ['Calm', 'Confident', 'Anxious', 'Greedy', 'Fearful', 'Frustrated', 'Disciplined'];
  String emotion = existing?.emotionalState.isNotEmpty == true ? existing!.emotionalState : 'Calm';

  return showModalBottomSheet<ExitJournal>(
    context: context,
    backgroundColor: colors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.0))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16.0),
                  Text('Trade Reflection', style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  const SizedBox(height: 4.0),
                  Text('Review the trade while it is fresh.', style: TextStyle(fontSize: 13.0, color: colors.mutedForeground)),
                  const SizedBox(height: 18.0),
                  _field(colors, 'What went well?', wellCtrl, 'e.g. Followed my plan', maxLines: 2),
                  const SizedBox(height: 12.0),
                  _field(colors, 'What went wrong?', wrongCtrl, 'e.g. Entered too early', maxLines: 2),
                  const SizedBox(height: 16.0),
                  Text('Emotional state', style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: emotions.map((e) {
                      final active = emotion == e;
                      return GestureDetector(
                        onTap: () => setSheet(() => emotion = e),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                          decoration: BoxDecoration(
                            color: active ? colors.primary.withValues(alpha: 0.15) : colors.card,
                            borderRadius: BorderRadius.circular(10.0),
                            border: Border.all(color: active ? colors.primary : colors.border),
                          ),
                          child: Text(e, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: active ? colors.primary : colors.mutedForeground)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14.0),
                  _field(colors, 'Lessons learned', lessonsCtrl, 'e.g. Wait for confirmation', maxLines: 2),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(ExitJournal(
                        whatWentWell: wellCtrl.text.trim(),
                        whatWentWrong: wrongCtrl.text.trim(),
                        emotionalState: emotion,
                        lessonsLearned: lessonsCtrl.text.trim(),
                      )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                      ),
                      child: const Text('Save Reflection', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _field(ThemePalette colors, String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.foreground)),
      const SizedBox(height: 6.0),
      Container(
        decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(8.0), border: Border.all(color: colors.border)),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
        child: TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: TextStyle(color: colors.foreground, fontSize: 14.0),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)), border: InputBorder.none),
        ),
      ),
    ],
  );
}
