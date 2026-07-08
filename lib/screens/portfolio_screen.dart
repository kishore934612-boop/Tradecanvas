import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/constants/colors.dart';
import 'package:app/constants/markets.dart';
import 'package:app/providers/trading_provider.dart';
import 'package:app/utils/formatters.dart';
import 'package:app/components/allocation_chart.dart';
import 'package:app/components/ui.dart';
import 'package:app/widgets/position_card.dart';
import 'package:app/screens/main_tabs_screen.dart';
import 'package:app/screens/journal_screen.dart';
import 'package:app/screens/challenges_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    
    // Select selectors to trigger rebuilds only on structural changes, not on price ticks.
    // ignore: unused_local_variable
    final positionsState = context.select<TradingProvider, String>((p) => p.positions.map((x) => '${x.id}_${x.qty}_${x.stopLoss}_${x.takeProfit}').join(','));
    // ignore: unused_local_variable
    final ordersState = context.select<TradingProvider, String>((p) => p.orders.map((x) => x.id).join(','));
    // ignore: unused_local_variable
    final newsState = context.select<TradingProvider, String>((p) => p.news.isNotEmpty ? p.news.first.id : '');
    // ignore: unused_local_variable
    final balanceState = context.select<TradingProvider, double>((p) => p.balance);

    final provider = Provider.of<TradingProvider>(context, listen: false);
    final appState = Provider.of<AppState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              ScreenHeader(
                title: 'Dashboard',
                trailing: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    appState.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                  },
                  child: Container(
                    width: 36.0,
                    height: 36.0,
                    decoration: BoxDecoration(
                      color: colors.muted.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border, width: 0.8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: colors.primary,
                      size: 18.0,
                    ),
                  ),
                ),
              ),

              // 1. Premium Equity Card
              StreamBuilder<String>(
                stream: provider.priceUpdateStream,
                builder: (context, _) {
                  final eq = provider.equity;
                  final pnl = provider.unrealizedPnl + provider.realizedPnl;
                  final isPositive = provider.totalReturnPct >= 0;

                  // Active margin used calculation
                  double marginUsed = 0.0;
                  for (final p in provider.positions) {
                    marginUsed += p.margin;
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    padding: const EdgeInsets.all(22.0),
                    decoration: BoxDecoration(
                      gradient: colors.creditCardGradient,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.25),
                          blurRadius: 16.0,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL EQUITY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.bolt_rounded, color: Colors.white, size: 12.0),
                                  SizedBox(width: 4.0),
                                  Text(
                                    'Crypto Live',
                                    style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          formatCurrency(eq),
                          style: const TextStyle(
                            fontSize: 34.0,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                                    size: 13.0,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4.0),
                                  Text(
                                    '${isPositive ? '+' : ''}${formatCurrency(pnl)} (${formatSignedPct(provider.totalReturnPct)})',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10.0),
                            const Text(
                              'total return',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        Container(
                          height: 1.0,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CASH BALANCE',
                                  style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 3.0),
                                Text(
                                  formatCurrency(provider.balance),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'MARGIN IN USE',
                                  style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.bold, color: Colors.white60, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 3.0),
                                Text(
                                  formatCurrency(marginUsed),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              // 2. 2x2 Quick Actions Grid
              _buildQuickActionsGrid(context, colors),
              const SizedBox(height: 20.0),

              // 3. Asset Allocation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'ASSET ALLOCATION',
                  style: TextStyle(
                    fontSize: 11.0,
                    fontWeight: FontWeight.w800,
                    color: colors.mutedForeground,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              StreamBuilder<String>(
                stream: provider.priceUpdateStream,
                builder: (context, _) {
                  double spotVal = 0.0;
                  double futuresVal = 0.0;
                  for (final p in provider.positions) {
                    final currentPrice = provider.priceOf(p.symbol);
                    final val = p.margin + p.pnl(currentPrice);
                    if (p.tradingType == TradingType.spot) {
                      spotVal += val;
                    } else if (p.tradingType == TradingType.futures) {
                      futuresVal += val;
                    }
                  }
                  final segments = [
                    AllocationSegment(label: 'Cash', value: provider.balance, color: colors.primary.withValues(alpha: 0.65)),
                    AllocationSegment(label: 'Spot Portfolio', value: spotVal, color: colors.crypto),
                    AllocationSegment(label: 'Futures Margin', value: futuresVal, color: colors.accent),
                  ];
                  final total = segments.fold(0.0, (s, e) => s + e.value);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          AllocationChart(segments: segments),
                          const SizedBox(width: 20.0),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: segments.map((s) => _allocProgressRow(context, s, total)).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22.0),

              // Open positions
              SectionTitle('Open Positions', trailing: _countBadge(colors, provider.positions.length)),
              const SizedBox(height: 10.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: provider.positions.isEmpty
                    ? GlassCard(
                        padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 16.0),
                        child: Column(
                          children: [
                            Icon(Icons.donut_large_outlined, size: 38.0, color: colors.mutedForeground.withValues(alpha: 0.7)),
                            const SizedBox(height: 12.0),
                            Text(
                              'No open positions.\nHead to the terminal to buy or sell.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13.0, color: colors.mutedForeground, height: 1.4, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 14.0),
                            TextButton(
                              onPressed: () => mainTabsKey.currentState?.selectTab(2),
                              child: Text('Open Trading Terminal', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    : Column(children: provider.positions.map((p) => PositionCard(position: p)).toList()),
              ),

              // Pending orders
              if (provider.orders.isNotEmpty) ...[
                const SizedBox(height: 16.0),
                SectionTitle('Pending Orders', trailing: _countBadge(colors, provider.orders.length)),
                const SizedBox(height: 10.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(children: provider.orders.map((o) => _orderTile(context, provider, o, colors)).toList()),
                ),
              ],

              // News
              const SizedBox(height: 22.0),
              _newsFeed(context, provider, colors),
              const SizedBox(height: 110.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, ThemePalette colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _quickActionCard(
                  context,
                  colors,
                  icon: Icons.candlestick_chart_rounded,
                  iconColor: colors.primary,
                  title: 'Trading Terminal',
                  subtitle: 'Spot & futures trading',
                  onTap: () => mainTabsKey.currentState?.selectTab(2),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: _quickActionCard(
                  context,
                  colors,
                  icon: Icons.show_chart_rounded,
                  iconColor: colors.accent,
                  title: 'Market Explorer',
                  subtitle: 'Live tickers & lists',
                  onTap: () => mainTabsKey.currentState?.selectTab(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          Row(
            children: [
              Expanded(
                child: _quickActionCard(
                  context,
                  colors,
                  icon: Icons.menu_book_rounded,
                  iconColor: Colors.purple,
                  title: 'Reflections Journal',
                  subtitle: 'Log and review trades',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JournalScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: _quickActionCard(
                  context,
                  colors,
                  icon: Icons.emoji_events_rounded,
                  iconColor: Colors.orange,
                  title: 'Active Challenges',
                  subtitle: 'Track target milestones',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChallengesScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionCard(
    BuildContext context,
    ThemePalette colors, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: colors.border.withValues(alpha: 0.6), width: 0.8),
        boxShadow: colors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18.0),
                ),
                const SizedBox(height: 12.0),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.bold,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.0,
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _countBadge(ThemePalette colors, int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
        decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(8.0)),
        child: Text('$n', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
      );

  Widget _allocProgressRow(BuildContext context, AllocationSegment s, double total) {
    final colors = AppColors.of(context);
    if (s.value <= 0 && s.label != 'Cash') return const SizedBox.shrink();
    final pct = total > 0 ? (s.value / total) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8.0, height: 8.0, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 8.0),
              Text(s.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: colors.mutedForeground)),
              const Spacer(),
              Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w900, color: colors.foreground)),
            ],
          ),
          const SizedBox(height: 4.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              height: 4.0,
              width: double.infinity,
              color: colors.muted.withValues(alpha: 0.3),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct / 100,
                child: Container(color: s.color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderTile(BuildContext context, TradingProvider provider, dynamic o, ThemePalette colors) {
    final sideColor = o.side.id == 'long' ? colors.positive : colors.negative;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(color: sideColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6.0)),
            child: Text('${o.type.label} ${o.side.label}'.toUpperCase(), style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: sideColor)),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.symbol, style: TextStyle(fontWeight: FontWeight.bold, color: colors.foreground)),
                Text('${formatQty(o.qty)} units · trigger ${formatPrice(o.stopPrice ?? o.limitPrice ?? 0, o.marketType)}', style: TextStyle(fontSize: 11.0, color: colors.mutedForeground)),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.cancel_outlined, color: colors.negative, size: 20.0), onPressed: () => provider.cancelOrder(o.id)),
        ],
      ),
    );
  }

  Widget _newsFeed(BuildContext context, TradingProvider provider, ThemePalette colors) {
    if (provider.news.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Market Intelligence', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: colors.foreground)),
              Icon(Icons.bolt_rounded, color: colors.accent, size: 20.0),
            ],
          ),
          const SizedBox(height: 12.0),
          ...provider.news.take(5).map((a) {
            final bull = a.sentiment == 'bullish';
            final sc = bull ? colors.positive : colors.negative;
            final sbg = bull ? colors.positiveBackground : colors.negativeBackground;
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0), decoration: BoxDecoration(color: sbg, borderRadius: BorderRadius.circular(6.0)), child: Text(a.sentiment.toUpperCase(), style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: sc))),
                        const SizedBox(width: 6.0),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0), decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(6.0)), child: Text(a.impactSymbol.toUpperCase(), style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w800, color: colors.mutedForeground))),
                      ]),
                      Text(formatDate(a.timestamp), style: TextStyle(fontSize: 11.0, color: colors.mutedForeground, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                  Text(a.title, style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.foreground, height: 1.2)),
                  const SizedBox(height: 6.0),
                  Text(a.description, style: TextStyle(fontSize: 12.0, color: colors.mutedForeground, height: 1.3, fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
