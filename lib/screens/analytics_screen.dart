import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/models/trading_models.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/ui.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _activeTab = 0; // 0: Stats, 1: Calendar
  DateTime _selectedMonth = DateTime.now();
  DateTime? _selectedDay;
  String _marketFilter = 'All'; // 'All', 'Crypto', 'Stocks', 'Forex'

  @override
  void initState() {
    super.initState();
    // Default select today
    _selectedDay = DateTime.now();
  }

  void _changeMonth(int increment) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + increment, 1);
    });
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

  String _formatCompactPnl(double pnl) {
    final abs = pnl.abs();
    final String sign = pnl >= 0 ? '+' : '-';
    if (abs >= 10000000) {
      return '$sign$appCurrency${(abs / 10000000).toStringAsFixed(1)}Cr';
    }
    if (abs >= 1000000) {
      return '$sign$appCurrency${(abs / 1000000).toStringAsFixed(1)}M';
    }
    if (abs >= 1000) {
      return '$sign$appCurrency${(abs / 1000.0).toStringAsFixed(1)}k';
    }
    return '$sign$appCurrency${abs.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final provider = Provider.of<TradingProvider>(context);

    // Compute generic performance stats
    final totalTrades = provider.winCount + provider.lossCount;
    final winRate = totalTrades > 0 ? (provider.winCount / totalTrades) * 100 : 0.0;
    
    double grossProfit = 0.0;
    double grossLoss = 0.0;
    for (final t in provider.trades) {
      if (t.pnl > 0) {
        grossProfit += t.pnl;
      } else {
        grossLoss += t.pnl.abs();
      }
    }
    final profitFactor = grossLoss > 0 ? grossProfit / grossLoss : (grossProfit > 0 ? double.infinity : 1.0);

    final Map<MarketType, int> counts = {for (var t in MarketType.values) t: 0};
    for (final t in provider.trades) {
      counts[t.marketType] = (counts[t.marketType] ?? 0) + 1;
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Trading Performance', showBackButton: true),
            const SizedBox(height: 12.0),
            
            // Premium Tab Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: colors.border),
                ),
                padding: const EdgeInsets.all(3.0),
                child: Row(
                  children: [
                    _tabButton('Performance Stats', 0, colors),
                    _tabButton('Trading Calendar', 1, colors),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: _activeTab == 0 
                ? _buildStatsView(colors, provider, totalTrades, winRate, profitFactor, counts)
                : _buildCalendarView(colors, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index, ThemePalette colors) {
    final active = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [colors.primary, colors.primary.withValues(alpha: 0.8)])
                : null,
            borderRadius: BorderRadius.circular(6.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.bold,
              color: active ? colors.primaryForeground : colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsView(
    ThemePalette colors, 
    TradingProvider provider, 
    int totalTrades, 
    double winRate, 
    double profitFactor, 
    Map<MarketType, int> counts
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        // Net Profit Summary Card
        GlassCard(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                'Net Realized Profit',
                style: TextStyle(color: colors.mutedForeground, fontSize: 13.0, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6.0),
              Text(
                '${provider.realizedPnl >= 0 ? '+' : ''}${formatCurrency(provider.realizedPnl)}',
                style: TextStyle(
                  color: provider.realizedPnl >= 0 ? colors.positive : colors.negative,
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryStat('Total Trades', '$totalTrades', colors),
                  _summaryStat('Win Rate', '${winRate.toStringAsFixed(1)}%', colors, valueColor: winRate >= 50 ? colors.positive : (totalTrades > 0 ? colors.negative : null)),
                  _summaryStat('Profit Factor', profitFactor == double.infinity ? '∞' : profitFactor.toStringAsFixed(2), colors),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Win / Loss Distribution
        GlassCard(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Win / Loss Distribution', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground)),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Text('Wins (${provider.winCount})', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('Losses (${provider.lossCount})', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8.0),
              ClipRRect(
                borderRadius: BorderRadius.circular(10.0),
                child: Container(
                  height: 16.0,
                  width: double.infinity,
                  color: colors.muted,
                  child: Row(
                    children: [
                      if (totalTrades > 0 && provider.winCount > 0)
                        Expanded(
                          flex: provider.winCount,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [colors.positive, colors.positive.withValues(alpha: 0.8)]),
                            ),
                          ),
                        ),
                      if (totalTrades > 0 && provider.lossCount > 0)
                        Expanded(
                          flex: provider.lossCount,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [colors.negative.withValues(alpha: 0.8), colors.negative]),
                            ),
                          ),
                        ),
                      if (totalTrades == 0)
                        Expanded(
                          child: Container(color: colors.muted.withValues(alpha: 0.8)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Volume by market type
        GlassCard(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trading Volume by Market', style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground)),
              const SizedBox(height: 16.0),
              ...MarketType.values.map((type) {
                final count = counts[type] ?? 0;
                final pct = totalTrades > 0 ? count / totalTrades : 0.0;
                
                Color typeColor = AppColors.marketColor(colors, type);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(type.label, style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                          const Spacer(),
                          Text('$count trades (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6.0,
                          backgroundColor: colors.muted.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarView(ThemePalette colors, TradingProvider provider) {
    // Generate dates for current month
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    
    // Day offset starting from Monday (1)
    final int prefixDays = firstDayOfMonth.weekday - 1;
    
    final List<DateTime?> daysGrid = [];
    for (int i = 0; i < prefixDays; i++) {
      daysGrid.add(null);
    }
    for (int d = 1; d <= lastDayOfMonth.day; d++) {
      daysGrid.add(DateTime(_selectedMonth.year, _selectedMonth.month, d));
    }

    final String monthName = _monthName(_selectedMonth.month);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      children: [
        // Calendar Control and Filters Card
        GlassCard(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Month Swiper Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left_rounded, color: colors.foreground),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    '$monthName ${_selectedMonth.year}',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: colors.foreground),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right_rounded, color: colors.foreground),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 10.0),
              
              // Market Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: ['All', 'Crypto', 'Stocks', 'Forex'].map((m) {
                    final selected = _marketFilter == m;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(m, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: selected ? colors.primaryForeground : colors.mutedForeground)),
                        selected: selected,
                        selectedColor: colors.primary,
                        backgroundColor: colors.card,
                        onSelected: (v) {
                          if (v) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _marketFilter = m;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16.0),
              
              // Weekday names
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                  return SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(fontSize: 11.0, color: colors.mutedForeground.withValues(alpha: 0.8), fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8.0),

              // Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  childAspectRatio: 0.82,
                ),
                itemCount: daysGrid.length,
                itemBuilder: (context, idx) {
                  final day = daysGrid[idx];
                  if (day == null) return const SizedBox();

                  // Filter trades for this day
                  final dayTrades = provider.trades.where((t) {
                    final date = DateTime.fromMillisecondsSinceEpoch(t.closedAt);
                    final matches = date.year == day.year && date.month == day.month && date.day == day.day;
                    if (!matches) return false;
                    if (_marketFilter == 'All') return true;
                    return t.marketType.label.toLowerCase() == _marketFilter.toLowerCase();
                  }).toList();

                  final double dayPnl = dayTrades.fold(0.0, (s, t) => s + t.pnl);
                  final hasTrades = dayTrades.isNotEmpty;
                  final isProfit = dayPnl > 0;
                  final isLoss = dayPnl < 0;
                  
                  final isToday = DateTime.now().year == day.year &&
                      DateTime.now().month == day.month &&
                      DateTime.now().day == day.day;

                  final isSelected = _selectedDay != null &&
                      _selectedDay!.year == day.year &&
                      _selectedDay!.month == day.month &&
                      _selectedDay!.day == day.day;

                  Color cellColor = colors.card;
                  Color textColor = colors.foreground;
                  Border? cellBorder;

                  if (hasTrades) {
                    if (isProfit) {
                      cellColor = colors.positive.withValues(alpha: 0.15);
                      textColor = colors.positive;
                      cellBorder = Border.all(color: colors.positive.withValues(alpha: 0.45), width: 1.2);
                    } else if (isLoss) {
                      cellColor = colors.negative.withValues(alpha: 0.15);
                      textColor = colors.negative;
                      cellBorder = Border.all(color: colors.negative.withValues(alpha: 0.45), width: 1.2);
                    } else {
                      cellColor = colors.muted.withValues(alpha: 0.25);
                      textColor = colors.mutedForeground;
                      cellBorder = Border.all(color: colors.border, width: 1.2);
                    }
                  } else {
                    cellBorder = Border.all(color: colors.border.withValues(alpha: 0.4), width: 0.8);
                  }

                  if (isToday) {
                    cellBorder = Border.all(color: colors.accent, width: 2.0);
                  }

                  if (isSelected) {
                    cellColor = colors.primary.withValues(alpha: 0.25);
                    cellBorder = Border.all(color: colors.primary, width: 1.5);
                  }

                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    borderRadius: BorderRadius.circular(8.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(8.0),
                        border: cellBorder,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: isToday || hasTrades || isSelected ? FontWeight.bold : FontWeight.normal,
                              color: textColor,
                            ),
                          ),
                          if (hasTrades) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              _formatCompactPnl(dayPnl),
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16.0),

        // Day Details panel
        _buildDayDetails(colors, provider),
      ],
    );
  }

  Widget _buildDayDetails(ThemePalette colors, TradingProvider provider) {
    if (_selectedDay == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Select a date in the calendar to view trades.', style: TextStyle(color: colors.mutedForeground, fontSize: 13.5)),
        ),
      );
    }

    final day = _selectedDay!;
    final dayTrades = provider.trades.where((t) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.closedAt);
      final matches = date.year == day.year && date.month == day.month && date.day == day.day;
      if (!matches) return false;
      if (_marketFilter == 'All') return true;
      return t.marketType.label.toLowerCase() == _marketFilter.toLowerCase();
    }).toList();

    final dayPnl = dayTrades.fold<double>(0.0, (sum, t) => sum + t.pnl);
    final winTrades = dayTrades.where((t) => t.pnl >= 0).length;
    final winRate = dayTrades.isNotEmpty ? (winTrades / dayTrades.length) * 100 : 0.0;

    final formattedDate = '${_monthName(day.month)} ${day.day}, ${day.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day level metrics card
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedDate,
              style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground),
            ),
            if (dayTrades.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: dayPnl >= 0 
                      ? colors.positive.withValues(alpha: 0.15) 
                      : colors.negative.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.0),
                ),
                child: Text(
                  '${dayPnl >= 0 ? '+' : ''}${formatCurrency(dayPnl)}',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: dayPnl >= 0 ? colors.positive : colors.negative,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12.0),
        
        if (dayTrades.isEmpty)
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.calendar_today_rounded, color: colors.mutedForeground.withValues(alpha: 0.3), size: 40.0),
                  const SizedBox(height: 8.0),
                  Text('No trades closed on this day.', style: TextStyle(color: colors.mutedForeground, fontSize: 13.0)),
                ],
              ),
            ),
          )
        else ...[
          // Stats Row
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    children: [
                      Text('${dayTrades.length}', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
                      const SizedBox(height: 2.0),
                      Text('Trades', style: TextStyle(fontSize: 10.5, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Column(
                    children: [
                      Text('${winRate.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: winRate >= 50 ? colors.positive : colors.negative)),
                      const SizedBox(height: 2.0),
                      Text('Win Rate', style: TextStyle(fontSize: 10.5, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14.0),
          
          // Trades List
          ...dayTrades.map((t) {
            final isWin = t.pnl >= 0;
            final cardColor = isWin ? colors.positive : colors.negative;
            final durationStr = _formatDuration(t.durationMs);

            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12.0),
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Symbol, Side tag and P&L
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: cardColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          t.side.label.toUpperCase(),
                          style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: cardColor),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        t.symbol,
                        style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: colors.foreground),
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                        decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(4.0)),
                        child: Text(t.tradingType.label, style: TextStyle(fontSize: 9.0, color: colors.mutedForeground, fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(
                        '${t.pnl >= 0 ? '+' : ''}${formatCurrency(t.pnl)}',
                        style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: cardColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  
                  // Execution Prices & Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Entry: ${formatPrice(t.entryPrice, t.marketType)} · Exit: ${formatPrice(t.exitPrice, t.marketType)}',
                        style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        durationStr,
                        style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  
                  // Display notes & journals if present
                  if (t.notes.isNotEmpty || t.entryJournal != null || t.exitJournal != null) ...[
                    const SizedBox(height: 8.0),
                    const Divider(height: 1.0, thickness: 0.5),
                    const SizedBox(height: 8.0),
                    if (t.entryJournal != null && (t.entryJournal!.reason.isNotEmpty || t.entryJournal!.strategy.isNotEmpty)) ...[
                      if (t.entryJournal!.strategy.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text('Setup: ${t.entryJournal!.strategy}', style: TextStyle(fontSize: 12.0, color: colors.foreground.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                        ),
                      if (t.entryJournal!.reason.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Text('Reason: "${t.entryJournal!.reason}"', style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, fontStyle: FontStyle.italic)),
                        ),
                    ],
                    if (t.notes.isNotEmpty)
                      Text('Notes: ${t.notes}', style: TextStyle(fontSize: 11.5, color: colors.mutedForeground)),
                  ],
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  String _monthName(int month) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }

  Widget _summaryStat(String label, String value, ThemePalette colors, {Color? valueColor}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: valueColor ?? colors.foreground)),
        const SizedBox(height: 4.0),
        Text(label, style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
