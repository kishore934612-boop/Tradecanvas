import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';
import 'package:app/screens/trade_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _winRateOf(List<Trade> list) {
    if (list.isEmpty) return 0.0;
    final wins = list.where((t) => t.isWin).length;
    return (wins / list.length) * 100.0;
  }

  double _pnlOf(List<Trade> list) {
    return list.fold(0.0, (sum, t) => sum + t.pnl);
  }

  String _formatDuration(int ms) {
    final sec = ms ~/ 1000;
    final min = sec ~/ 60;
    final hrs = min ~/ 60;
    if (hrs > 0) {
      return '${hrs}h ${min % 60}m';
    }
    if (min > 0) {
      return '${min}m ${sec % 60}s';
    }
    return '${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = Provider.of<TradingProvider>(context);
    final trades = provider.trades;

    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = trades.where((t) {
      return t.symbol.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Trade History'),
            const SizedBox(height: 12.0),

            // Dynamic Search Bar (Only shown if user has trades)
            if (trades.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: colors.border,
                      width: 1.0,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: colors.mutedForeground, size: 20.0),
                      const SizedBox(width: 10.0),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(
                            color: colors.foreground,
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search trades by symbol (e.g. BTC)...',
                            hintStyle: TextStyle(color: colors.mutedForeground.withValues(alpha: 0.7)),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          onChanged: (v) => setState(() {}),
                          autocorrect: false,
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          child: Icon(Icons.close_rounded, color: colors.mutedForeground, size: 20.0),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
            ],

            // Dynamic Performance metrics
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(child: StatTile(label: 'Total Trades', value: '${filtered.length}')),
                  const SizedBox(width: 8.0),
                  Expanded(child: StatTile(label: 'Win Rate', value: '${_winRateOf(filtered).toStringAsFixed(0)}%')),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: StatTile(
                      label: 'Realized P&L',
                      value: '${_pnlOf(filtered) >= 0 ? '+' : ''}${formatCurrency(_pnlOf(filtered))}',
                      valueColor: _pnlOf(filtered) >= 0 ? colors.positive : colors.negative,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),

            Expanded(
              child: trades.isEmpty
                  ? EmptyState(icon: Icons.history_toggle_off_rounded, message: 'No trades recorded yet.')
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline_rounded, size: 36.0, color: colors.mutedForeground),
                              const SizedBox(height: 12.0),
                              Text(
                                'No trades match your search.',
                                style: TextStyle(color: colors.mutedForeground, fontSize: 13.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length + 1,
                          itemBuilder: (context, index) {
                            if (index == filtered.length) return const SizedBox(height: 110.0);
                            return _tradeRow(context, filtered[index], colors);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tradeRow(BuildContext context, Trade t, ThemePalette colors) {
    final isWin = t.isWin;
    final c = isWin ? colors.positive : colors.negative;
    final sideColor = t.side == PositionSide.long ? colors.positive : colors.negative;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: GlassCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TradeDetailScreen(tradeId: t.id))),
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              width: 42.0,
              height: 42.0,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12.0)),
              child: Icon(isWin ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: c, size: 22.0),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(t.symbol, style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                        decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4.0)),
                        child: Text(
                          '${t.side.label} ${t.leverage.toStringAsFixed(0)}x',
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: sideColor),
                        ),
                      ),
                      if (t.exitJournal != null) ...[
                        const SizedBox(width: 6.0),
                        Icon(Icons.menu_book_rounded, size: 13.0, color: colors.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    '${formatPrice(t.entryPrice, t.marketType)} → ${formatPrice(t.exitPrice, t.marketType)} · ${_formatDuration(t.durationMs)}',
                    style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${isWin ? '+' : ''}${formatCurrency(t.pnl)}', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: c)),
                const SizedBox(height: 2.0),
                Text(formatSignedPct(t.pnlPct), style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: c)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
