/// Dedicated Backtest Analytics Full Screen Page.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:app/constants/colors.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/replay_trade.dart';
import 'package:app/utils/haptics.dart';

class BacktestAnalyticsScreen extends StatefulWidget {
  final Instrument instrument;
  final List<ReplayTrade> trades;
  final double currentPrice;
  final double startingBalance;

  const BacktestAnalyticsScreen({
    super.key,
    required this.instrument,
    required this.trades,
    required this.currentPrice,
    this.startingBalance = 10000,
  });

  @override
  State<BacktestAnalyticsScreen> createState() => _BacktestAnalyticsScreenState();
}

class _BacktestAnalyticsScreenState extends State<BacktestAnalyticsScreen> {
  int _filterIndex = 0; // 0 = All, 1 = Longs, 2 = Shorts

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final allFilteredTrades = widget.trades.where((t) {
      if (_filterIndex == 1) return t.isLong;
      if (_filterIndex == 2) return !t.isLong;
      return true;
    }).toList();

    final stats = ReplayAnalytics(allFilteredTrades, startingBalance: widget.startingBalance);
    final closedTrades = stats.trades;
    final totalTrades = stats.count;
    final wins = stats.wins;
    final winRate = stats.winRate;
    final profitFactor = stats.profitFactor;
    final netPnl = stats.netPnl;

    final longs = closedTrades.where((t) => t.isLong).toList();
    final longWins = longs.where((t) => t.pnl(widget.currentPrice) > 0).length;
    final longWinRate = longs.isNotEmpty ? (longWins / longs.length) * 100 : 0.0;

    final shorts = closedTrades.where((t) => !t.isLong).toList();
    final shortWins = shorts.where((t) => t.pnl(widget.currentPrice) > 0).length;
    final shortWinRate = shorts.isNotEmpty ? (shortWins / shorts.length) * 100 : 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.card,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
          onPressed: () {
            Haptics.light();
            Navigator.pop(context);
          },
        ),
        actions: [IconButton(
          tooltip: 'Copy filtered trade journal as CSV',
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: stats.count == 0 ? null : () async {
            await Clipboard.setData(ClipboardData(text: stats.toCsv()));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trade journal CSV copied.')));
          },
        )],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backtest Analytics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.foreground,
              ),
            ),
            Text(
              widget.instrument.displayName,
              style: TextStyle(
                fontSize: 11,
                color: colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paper simulation · net of fees · no live orders. '
                'Filters apply to all metrics. Results do not predict future returns.',
                style: TextStyle(fontSize: 12, color: colors.mutedForeground)),
            const SizedBox(height: 12),
            // Top Overview Cards
            Row(
              children: [
                _metricCard(
                  colors,
                  'Win Rate',
                  '${winRate.toStringAsFixed(1)}%',
                  '$wins/$totalTrades Wins',
                  winRate >= 50 ? colors.positive : colors.foreground,
                ),
                const SizedBox(width: 10),
                _metricCard(
                  colors,
                  'Profit Factor',
                  profitFactor == null ? 'N/A' : profitFactor.isInfinite ? '∞' : profitFactor.toStringAsFixed(2),
                  'Net winners / net losers',
                  (profitFactor ?? 0) >= 1.5 ? colors.positive : colors.foreground,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _metricCard(
                  colors,
                  'Net PnL',
                  '${netPnl >= 0 ? '+' : ''}\$${netPnl.toStringAsFixed(2)}',
                  'Total Return',
                  netPnl >= 0 ? colors.positive : colors.negative,
                ),
                const SizedBox(width: 10),
                _metricCard(
                  colors,
                  'Total Trades',
                  '${allFilteredTrades.length}',
                  '${closedTrades.length} Closed / ${allFilteredTrades.length - closedTrades.length} Open',
                  colors.primary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final closedPnls = closedTrades.map((t) => t.pnl(widget.currentPrice)).toList();
              final maxWin = closedPnls.isNotEmpty ? closedPnls.fold<double>(0, (a, b) => a > b ? a : b) : 0.0;
              final maxLoss = closedPnls.isNotEmpty ? closedPnls.fold<double>(0, (a, b) => a < b ? a : b) : 0.0;
              final rrs = closedTrades
                  .map((t) => t.achievedRiskReward(widget.currentPrice))
                  .whereType<double>()
                  .toList();
              final avgRr = rrs.isNotEmpty ? rrs.reduce((a, b) => a + b) / rrs.length : 0.0;

              return Column(
                children: [
                  Row(
                    children: [
                      _metricCard(
                        colors,
                        'Best Trade',
                        maxWin > 0 ? '+\$${maxWin.toStringAsFixed(2)}' : '—',
                        'Largest Win',
                        colors.positive,
                      ),
                      const SizedBox(width: 10),
                      _metricCard(
                        colors,
                        'Worst Trade',
                        maxLoss < 0 ? '-\$${maxLoss.abs().toStringAsFixed(2)}' : '—',
                        'Largest Loss',
                        colors.negative,
                      ),
                    ],
                  ),
                  if (rrs.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _metricCard(
                          colors,
                          'Average Net R',
                          '${avgRr.toStringAsFixed(2)} R',
                          'Original risk at entry',
                          avgRr >= 1.5 ? colors.positive : colors.foreground,
                        ),
                        const SizedBox(width: 10),
                        _metricCard(
                          colors,
                          'TP / SL Hits',
                          '${closedTrades.where((t) => t.closedByTp).length} / ${closedTrades.where((t) => t.closedBySl).length}',
                          'Auto-Exit Stats',
                          colors.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 16),

            Row(children: [
              _metricCard(colors, 'Expectancy', '\$${stats.expectancy.toStringAsFixed(2)}',
                  'Net per closed trade', colors.foreground),
              const SizedBox(width: 10),
              _metricCard(colors, 'Max Drawdown', '${stats.maxDrawdownPercent.toStringAsFixed(2)}%',
                  'Closed-balance, filtered', colors.negative),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _metricCard(colors, 'Fees Paid', '\$${stats.totalFees.toStringAsFixed(2)}',
                  'Closed trades only', colors.foreground),
              const SizedBox(width: 10),
              _metricCard(colors, 'Break-even', '${stats.breakEven}',
                  'Zero net P&L', colors.foreground),
            ]),
            const SizedBox(height: 16),
            // Breakdown Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Directional Performance',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _directionStat(
                        colors,
                        'Long Positions',
                        '${longs.length} Trades',
                        '${longWinRate.toStringAsFixed(1)}% Win Rate',
                        colors.positive,
                      ),
                      Container(height: 36, width: 1, color: colors.border),
                      _directionStat(
                        colors,
                        'Short Positions',
                        '${shorts.length} Trades',
                        '${shortWinRate.toStringAsFixed(1)}% Win Rate',
                        colors.negative,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trade Log Header & Filter Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Trade Log (${allFilteredTrades.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      InkWell(
                        onTap: () {
                          Haptics.selection();
                          setState(() => _filterIndex = i);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _filterIndex == i
                                ? colors.primary.withValues(alpha: 0.15)
                                : colors.card,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _filterIndex == i ? colors.primary : colors.border,
                            ),
                          ),
                          child: Text(
                            ['All', 'Longs', 'Shorts'][i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _filterIndex == i ? colors.primary : colors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 4),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Trade Log Items
            if (allFilteredTrades.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'No trades recorded yet.\nExecute BUY or SELL orders in Replay Mode to view detailed trade history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colors.mutedForeground),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: allFilteredTrades.length,
                itemBuilder: (context, i) {
                  final t = allFilteredTrades[i];
                  final pnlVal = t.pnl(widget.currentPrice);
                  final pnlPct = t.pnlPercent(widget.currentPrice);
                  final isWin = pnlVal >= 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (t.isLong ? colors.positive : colors.negative).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t.isLong ? 'LONG' : 'SHORT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: t.isLong ? colors.positive : colors.negative,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Entry: ${t.entryPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.foreground,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                t.isOpen
                                    ? 'Status: Active Position'
                                    : 'Exit: ${t.exitPrice!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${pnlVal >= 0 ? '+' : ''}\$${pnlVal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isWin ? colors.positive : colors.negative,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isWin ? colors.positive : colors.negative,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    ThemePalette colors,
    String label,
    String value,
    String subtitle,
    Color valueColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: colors.mutedForeground),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directionStat(
    ThemePalette colors,
    String title,
    String countText,
    String winRateText,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: colors.foreground),
        ),
        const SizedBox(height: 4),
        Text(
          winRateText,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          countText,
          style: TextStyle(fontSize: 10.5, color: colors.mutedForeground),
        ),
      ],
    );
  }
}
