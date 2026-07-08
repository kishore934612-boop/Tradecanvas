import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';
import 'package:app/widgets/journal_dialogs.dart';

class TradeDetailScreen extends StatelessWidget {
  final String tradeId;
  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = Provider.of<TradingProvider>(context);
    final trade = provider.trades.firstWhere((t) => t.id == tradeId, orElse: () => _missing);

    if (trade.id.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(backgroundColor: colors.card),
        body: const Center(child: Text('Trade not found')),
      );
    }

    final isWin = trade.isWin;
    final c = isWin ? colors.positive : colors.negative;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        title: Text('${trade.symbol} · ${trade.side.label}', style: TextStyle(color: colors.foreground, fontWeight: FontWeight.bold, fontSize: 17.0)),
        iconTheme: IconThemeData(color: colors.foreground),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // P&L hero
            GlassCard(
              color: c.withValues(alpha: 0.12),
              child: Column(
                children: [
                  Text('NET P&L', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w800, color: colors.mutedForeground, letterSpacing: 1.4)),
                  const SizedBox(height: 6.0),
                  Text('${isWin ? '+' : ''}${formatCurrency(trade.pnl)}', style: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: c, letterSpacing: -0.5)),
                  const SizedBox(height: 4.0),
                  Text(formatSignedPct(trade.pnlPct), style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: c)),
                ],
              ),
            ),
            const SizedBox(height: 16.0),

            _section(colors, 'Execution', [
              _row(colors, 'Side', '${trade.side.label} · ${trade.leverage.toStringAsFixed(0)}x'),
              _row(colors, 'Quantity', '${formatQty(trade.qty)} ${trade.symbol}'),
              _row(colors, 'Entry', formatPrice(trade.entryPrice, trade.marketType)),
              _row(colors, 'Exit', formatPrice(trade.exitPrice, trade.marketType)),
              _row(colors, 'Duration', formatDuration(trade.durationMs)),
              _row(colors, 'Closed by', _reasonLabel(trade.closeReason)),
            ]),
            const SizedBox(height: 14.0),

            _section(colors, 'Risk', [
              _row(colors, 'Stop Loss', trade.stopLoss != null ? formatPrice(trade.stopLoss!, trade.marketType) : '—'),
              _row(colors, 'Take Profit', trade.takeProfit != null ? formatPrice(trade.takeProfit!, trade.marketType) : '—'),
              _row(colors, 'Risk %', trade.riskPct > 0 ? formatPct(trade.riskPct) : '—'),
              _row(colors, 'Risk : Reward', trade.riskReward != null ? '1 : ${trade.riskReward!.toStringAsFixed(2)}' : '—'),
            ]),
            const SizedBox(height: 14.0),

            // Entry journal
            if (trade.entryJournal != null) ...[
              _section(colors, 'Before the Trade', [
                if (trade.entryJournal!.reason.isNotEmpty) _journalLine(colors, 'Why', trade.entryJournal!.reason),
                if (trade.entryJournal!.strategy.isNotEmpty) _journalLine(colors, 'Strategy', trade.entryJournal!.strategy),
                _journalLine(colors, 'Confidence', '${trade.entryJournal!.confidence} / 10'),
              ]),
              const SizedBox(height: 14.0),
            ],

            // Exit journal
            _section(colors, 'Reflection', [
              if (trade.exitJournal == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text('No reflection yet. Add one to learn from this trade.', style: TextStyle(color: colors.mutedForeground, fontSize: 13.0)),
                )
              else ...[
                if (trade.exitJournal!.whatWentWell.isNotEmpty) _journalLine(colors, 'Went well', trade.exitJournal!.whatWentWell),
                if (trade.exitJournal!.whatWentWrong.isNotEmpty) _journalLine(colors, 'Went wrong', trade.exitJournal!.whatWentWrong),
                if (trade.exitJournal!.emotionalState.isNotEmpty) _journalLine(colors, 'Emotion', trade.exitJournal!.emotionalState),
                if (trade.exitJournal!.lessonsLearned.isNotEmpty) _journalLine(colors, 'Lessons', trade.exitJournal!.lessonsLearned),
              ],
              const SizedBox(height: 10.0),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await showExitJournalDialog(context, existing: trade.exitJournal);
                    if (result != null) provider.attachExitJournal(trade.id, result);
                  },
                  icon: Icon(trade.exitJournal == null ? Icons.add_rounded : Icons.edit_rounded, size: 18.0, color: colors.primary),
                  label: Text(trade.exitJournal == null ? 'Add Reflection' : 'Edit Reflection', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: colors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)), padding: const EdgeInsets.symmetric(vertical: 12.0)),
                ),
              ),
            ]),
            const SizedBox(height: 14.0),

            // Notes
            _section(colors, 'Notes', [_NotesField(tradeId: trade.id, initial: trade.notes)]),
            const SizedBox(height: 30.0),
          ],
        ),
      ),
    );
  }

  String _reasonLabel(String r) {
    switch (r) {
      case 'stopLoss':
        return 'Stop Loss';
      case 'takeProfit':
        return 'Take Profit';
      case 'trailingStop':
        return 'Trailing Stop';
      case 'liquidation':
        return 'Liquidation';
      default:
        return 'Manual';
    }
  }

  Widget _section(ThemePalette colors, String title, List<Widget> children) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground)),
          const SizedBox(height: 10.0),
          ...children,
        ],
      ),
    );
  }

  Widget _row(ThemePalette colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.mutedForeground)),
          Text(value, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.foreground)),
        ],
      ),
    );
  }

  Widget _journalLine(ThemePalette colors, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w800, color: colors.mutedForeground)),
          const SizedBox(height: 2.0),
          Text(value, style: TextStyle(fontSize: 13.5, color: colors.foreground, height: 1.3)),
        ],
      ),
    );
  }

  static final Trade _missing = Trade(
    id: '', symbol: '', name: '', side: PositionSide.long, qty: 0, entryPrice: 0, exitPrice: 0,
    leverage: 1, fees: 0, openedAt: 0, closedAt: 0, pnl: 0, pnlPct: 0, marketType: MarketType.crypto,
  );
}

class _NotesField extends StatefulWidget {
  final String tradeId;
  final String initial;
  const _NotesField({required this.tradeId, required this.initial});

  @override
  State<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends State<_NotesField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(color: colors.input, borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4.0),
          child: TextField(
            controller: _ctrl,
            maxLines: 3,
            style: TextStyle(color: colors.foreground, fontSize: 14.0),
            decoration: InputDecoration(hintText: 'Add private notes about this trade...', hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.6)), border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 8.0),
        TextButton(
          onPressed: () {
            context.read<TradingProvider>().updateTradeNotes(widget.tradeId, _ctrl.text.trim());
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved'), duration: Duration(seconds: 1)));
          },
          child: Text('Save Notes', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
