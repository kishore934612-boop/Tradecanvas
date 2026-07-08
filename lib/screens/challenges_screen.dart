import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/gamification.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/components/ui.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = Provider.of<TradingProvider>(context);
    final s = provider.stats;

    final completed = kChallenges.where((c) => c.isComplete(s)).length;

    final byCategory = <ChallengeCategory, List<ChallengeDef>>{};
    for (final c in kChallenges) {
      byCategory.putIfAbsent(c.category, () => []).add(c);
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Challenges', showBackButton: true),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                children: [
          GlassCard(
            color: colors.primary.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(Icons.emoji_events_rounded, color: colors.primary, size: 34.0),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$completed of ${kChallenges.length} complete', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                      const SizedBox(height: 2.0),
                      Text('Build skill and discipline through goals.', style: TextStyle(fontSize: 12.5, color: colors.mutedForeground)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18.0),
          ...byCategory.entries.expand((entry) => [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0, left: 2.0),
                  child: Text(entry.key.label, style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                ),
                ...entry.value.map((c) => _challengeCard(context, c, s, colors)),
                const SizedBox(height: 12.0),
              ]),
        ],
      ),
    ),
          ],
        ),
      ),
    );
  }

  Widget _challengeCard(BuildContext context, ChallengeDef c, TradingStats s, ThemePalette colors) {
    final pct = c.progressPct(s);
    final done = c.isComplete(s);
    final progressColor = done ? colors.positive : colors.primary;
    final current = c.progress(s);

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(color: progressColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12.0)),
                child: Icon(done ? Icons.check_circle_rounded : c.icon, color: progressColor, size: 22.0),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                    const SizedBox(height: 2.0),
                    Text(c.description, style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7.0,
              backgroundColor: colors.muted,
              valueColor: AlwaysStoppedAnimation(progressColor),
            ),
          ),
          const SizedBox(height: 6.0),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              done ? 'Completed' : '${_fmt(current)}${c.unit} / ${_fmt(c.target)}${c.unit}',
              style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: done ? colors.positive : colors.mutedForeground),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}
