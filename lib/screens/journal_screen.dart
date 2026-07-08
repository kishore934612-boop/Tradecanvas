import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';
import 'package:app/widgets/journal_dialogs.dart';
import 'package:app/screens/trade_detail_screen.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = Provider.of<TradingProvider>(context);
    final trades = provider.trades;

    final needsReflection = trades.where((t) => t.exitJournal == null).toList();
    final journaled = trades.where((t) => t.exitJournal != null || t.entryJournal != null).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Trading Journal', showBackButton: true),
            Expanded(
              child: trades.isEmpty
                  ? EmptyState(icon: Icons.menu_book_rounded, message: 'Your journal is empty.\nEvery trade you place will be logged here for reflection.')
                  : ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                      children: [
                if (needsReflection.isNotEmpty) ...[
                  Text('Awaiting Reflection', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                  const SizedBox(height: 4.0),
                  Text('Reflect while the trade is fresh.', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground)),
                  const SizedBox(height: 12.0),
                  ...needsReflection.take(5).map((t) => _pendingCard(context, provider, t, colors)),
                  const SizedBox(height: 18.0),
                ],
                Text('Journal Entries', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                const SizedBox(height: 12.0),
                if (journaled.isEmpty)
                  Text('No reflections yet.', style: TextStyle(color: colors.mutedForeground))
                else
                  ...journaled.map((t) => _journalCard(context, t, colors)),
              ],
            ),
    ),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard(BuildContext context, TradingProvider provider, Trade t, ThemePalette colors) {
    final c = t.isWin ? colors.positive : colors.negative;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t.symbol} · ${t.side.label}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground)),
                Text('${t.isWin ? '+' : ''}${formatCurrency(t.pnl)} · ${formatDate(t.closedAt)}', style: TextStyle(fontSize: 12.0, color: c, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final result = await showExitJournalDialog(context);
              if (result != null) provider.attachExitJournal(t.id, result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.brightness == Brightness.dark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            ),
            child: const Text('Reflect', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _journalCard(BuildContext context, Trade t, ThemePalette colors) {
    final c = t.isWin ? colors.positive : colors.negative;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12.0),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TradeDetailScreen(tradeId: t.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${t.symbol} · ${t.side.label}', style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground, fontSize: 15.0)),
              const Spacer(),
              Text('${t.isWin ? '+' : ''}${formatCurrency(t.pnl)}', style: TextStyle(fontWeight: FontWeight.bold, color: c)),
            ],
          ),
          const SizedBox(height: 2.0),
          Text(formatDate(t.closedAt), style: TextStyle(fontSize: 11.0, color: colors.mutedForeground)),
          if (t.entryJournal != null && t.entryJournal!.strategy.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            _line(colors, 'Strategy', t.entryJournal!.strategy, Icons.flag_rounded),
          ],
          if (t.exitJournal != null) ...[
            if (t.exitJournal!.lessonsLearned.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              _line(colors, 'Lesson', t.exitJournal!.lessonsLearned, Icons.lightbulb_outline_rounded),
            ],
            if (t.exitJournal!.emotionalState.isNotEmpty) ...[
              const SizedBox(height: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(color: colors.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6.0)),
                child: Text(t.exitJournal!.emotionalState, style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: colors.accent)),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _line(ThemePalette colors, String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14.0, color: colors.mutedForeground),
        const SizedBox(width: 6.0),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '$label: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
                TextSpan(text: value, style: TextStyle(fontSize: 12.5, color: colors.foreground, height: 1.3)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
