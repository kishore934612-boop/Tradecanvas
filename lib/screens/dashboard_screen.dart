/// Dashboard — clean layout featuring header, main chart surface, and category-filtered live watchlist.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/chart/chart_painter.dart' show ChartStyle;
import 'package:app/components/chart/chart_toolbar.dart';
import 'package:app/components/chart/chart_view.dart';
import 'package:app/components/chart/indicator_sheet.dart';
import 'package:app/components/ui.dart';
import 'package:app/components/watchlist_tile.dart';
import 'package:app/constants/colors.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/repositories/chart_prefs_repository.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/engine/chart_controller.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/indicators.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/chart_screen.dart';
import 'package:app/screens/symbol_search_screen.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/utils/haptics.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ChartPrefsRepository _prefsRepo;

  ChartController? _chart;
  DrawingController? _drawings;
  String? _loadedSymbol;

  ChartStyle _style = ChartStyle.candles;

  @override
  void initState() {
    super.initState();
    _prefsRepo = serviceLocator<ChartPrefsRepository>();
  }

  @override
  void dispose() {
    _savePrefs();
    _chart?.dispose();
    _drawings?.dispose();
    super.dispose();
  }

  /// Builds fresh controllers for [instrument] if it differs from what is
  /// currently loaded.
  void _ensureLoaded(Instrument instrument) {
    if (_loadedSymbol == instrument.symbol) return;

    _savePrefs();
    _chart?.dispose();
    _drawings?.dispose();

    final profile = context.read<AppState>().profile;
    _style = profile.chartType == ChartTypePref.area
        ? ChartStyle.area
        : ChartStyle.candles;

    final chart = ChartController(
      provider: serviceLocator<BinanceProvider>(),
      logger: serviceLocator<Logger>(),
      instrument: instrument,
      timeframe: Timeframe.fromApiValue(profile.defaultTimeframe),
      enabledIndicators: profile.defaultIndicators
          .map(IndicatorType.fromName)
          .whereType<IndicatorType>()
          .toSet(),
    );

    final drawings = DrawingController(
      repository: serviceLocator<DrawingRepository>(),
      logger: serviceLocator<Logger>(),
      symbol: instrument.symbol,
    );

    _chart = chart;
    _drawings = drawings;
    _loadedSymbol = instrument.symbol;

    _bootstrap(chart, drawings, instrument.symbol);
  }

  Future<void> _bootstrap(
    ChartController chart,
    DrawingController drawings,
    String symbol,
  ) async {
    try {
      final saved = await _prefsRepo.get(symbol);
      if (saved != null && mounted && _chart == chart) {
        chart.setIndicators(
          saved.indicators
              .map(IndicatorType.fromName)
              .whereType<IndicatorType>()
              .toSet(),
        );
        setState(() {
          _style = saved.chartType == 'area'
              ? ChartStyle.area
              : ChartStyle.candles;
        });
        await chart.setTimeframe(Timeframe.fromApiValue(saved.timeframe));
      }
    } catch (e) {
      serviceLocator<Logger>().warning('Dashboard chart prefs load failed: $e');
    }

    if (_chart != chart) return;
    await Future.wait([chart.load(), drawings.load()]);
  }

  Future<void> _savePrefs() async {
    final chart = _chart;
    if (chart == null) return;
    try {
      await _prefsRepo.save(
        ChartPrefs(
          symbol: chart.instrument.symbol,
          timeframe: chart.timeframe.apiValue,
          chartType: _style == ChartStyle.area ? 'area' : 'candles',
          indicators: chart.enabledIndicators.map((i) => i.name).toList(),
        ),
      );
    } catch (e) {
      serviceLocator<Logger>().warning('Dashboard chart prefs save failed: $e');
    }
  }

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Future<void> _pickCoin(BuildContext navContext) async {
    Haptics.light();
    final picked = await Navigator.of(navContext).push<Instrument>(
      MaterialPageRoute(
        builder: (_) => const SymbolSearchScreen(pickMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    context.read<AppState>().setDashboardSymbol(picked.symbol);
  }

  void _selectFromWatchlist(String symbol) {
    Haptics.selection();
    context.read<AppState>().setDashboardSymbol(symbol);
  }

  /// Swipe left/right on the featured chart's header to step to the next or
  /// previous watchlist symbol. Falls back to a no-op when the watchlist has
  /// fewer than 2 symbols, since there is nowhere to swipe to.
  void _swipeFeaturedSymbol(bool forward) {
    final market = context.read<MarketDataProvider>();
    final watchlist = market.watchlist;
    if (watchlist.length < 2) return;

    final appState = context.read<AppState>();
    final currentIndex = watchlist.indexOf(appState.dashboardSymbol);
    final baseIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (baseIndex + (forward ? 1 : -1)) % watchlist.length;
    final wrapped = nextIndex < 0 ? nextIndex + watchlist.length : nextIndex;

    Haptics.selection();
    appState.setDashboardSymbol(watchlist[wrapped]);
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final appState = context.watch<AppState>();
    final registry = context.watch<SymbolRegistry>();
    final market = context.watch<MarketDataProvider>();

    final instrument = registry.resolve(appState.dashboardSymbol);
    _ensureLoaded(instrument);

    final chart = _chart!;
    final drawings = _drawings!;

    market.addInterest(instrument.symbol);
    final streamedPrice = market.priceOf(instrument.symbol);
    final price = chart.lastPrice > 0 ? chart.lastPrice : streamedPrice;
    final change = market.changeOf(instrument.symbol);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Top Dashboard Header matching Settings & Chart screen style
            SliverToBoxAdapter(
              child: ScreenHeader(
                title: 'Dashboard',
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6.0),
                  child: Image.asset(
                    'assets/icon.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Main Featured Chart Panel in a Separate Box Container
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.6),
                      width: 1.0,
                    ),
                    boxShadow: colors.cardShadow,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _ChartPanel(
                    instrument: instrument,
                    price: price,
                    change: change,
                    chart: chart,
                    drawings: drawings,
                    style: _style,
                    onPickCoin: () => _pickCoin(context),
                    onSwipeSymbol: _swipeFeaturedSymbol,
                    onOpenFullChart: () {
                      Haptics.medium();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChartScreen(instrument: instrument),
                        ),
                      );
                    },
                    onToggleStyle: () {
                      Haptics.selection();
                      setState(() {
                        _style = _style == ChartStyle.candles
                            ? ChartStyle.area
                            : ChartStyle.candles;
                      });
                    },
                    onIndicators: () => showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => IndicatorSheet(
                        enabled: chart.enabledIndicators,
                        onToggle: (type) {
                          Haptics.selection();
                          chart.toggleIndicator(type);
                        },
                      ),
                    ),
                    onTimeframe: (tf) {
                      Haptics.selection();
                      chart.setTimeframe(tf);
                      setState(() {});
                    },
                  ),
                ),
              ),
            ),

            // Watchlist Section Card Container
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        color: colors.primary.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Watchlist',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colors.foreground,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                      alpha: 0.18,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${market.watchlist.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: colors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              tooltip: 'Add symbol',
                              icon: Icon(
                                Icons.add_circle_outline_rounded,
                                color: colors.primary,
                                size: 22,
                              ),
                              onPressed: () {
                                Haptics.light();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const SymbolSearchScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: colors.border.withValues(alpha: 0.5),
                      ),
                      _watchlistCardContent(
                        context,
                        market,
                        registry,
                        instrument,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  Widget _watchlistCardContent(
    BuildContext context,
    MarketDataProvider market,
    SymbolRegistry registry,
    Instrument featured,
  ) {
    if (market.isLoading && !market.hasWatchlist) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!market.hasWatchlist) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        message: 'No symbols yet.\nAdd one to your watchlist.',
        ctaLabel: 'Browse symbols',
        onCta: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SymbolSearchScreen())),
      );
    }

    final symbols = market.watchlist;

    return Column(
      children: [
        for (int i = 0; i < symbols.length; i++) ...[
          WatchlistTile(
            instrument: registry.resolve(symbols[i]),
            price: market.priceOf(symbols[i]),
            change: market.changeOf(symbols[i]),
            sparkline: market.sparklineOf(symbols[i]),
            selected: symbols[i] == featured.symbol,
            onTap: () => _selectFromWatchlist(symbols[i]),
            onRemove: () => market.removeFromWatchlist(symbols[i]),
          ),
          if (i < symbols.length - 1)
            Divider(
              height: 1,
              indent: 14,
              endIndent: 14,
              color: AppColors.of(context).border.withValues(alpha: 0.3),
            ),
        ],
      ],
    );
  }
}

// ============================================================
// FEATURED CHART PANEL (CLEAN FULL-WIDTH LAYOUT)
// ============================================================

class _ChartPanel extends StatelessWidget {
  final Instrument instrument;
  final double price;
  final double change;
  final ChartController chart;
  final DrawingController drawings;
  final ChartStyle style;
  final VoidCallback onPickCoin;
  final VoidCallback onOpenFullChart;
  final VoidCallback onToggleStyle;
  final VoidCallback onIndicators;
  final ValueChanged<Timeframe> onTimeframe;

  /// Called with `true` for a left-swipe (next symbol) or `false` for a
  /// right-swipe (previous symbol) on the header.
  final ValueChanged<bool>? onSwipeSymbol;

  const _ChartPanel({
    required this.instrument,
    required this.price,
    required this.change,
    required this.chart,
    required this.drawings,
    required this.style,
    required this.onPickCoin,
    required this.onOpenFullChart,
    required this.onToggleStyle,
    required this.onIndicators,
    required this.onTimeframe,
    this.onSwipeSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final up = change >= 0;
    final accent = up ? colors.positive : colors.negative;

    return Column(
      children: [
        // Header Bar with Ticker & Instrument Picker + Right-Aligned % Badge.
        // Wrapped in a horizontal-swipe detector so swiping left/right steps
        // to the next/previous watchlist symbol without needing to open the
        // symbol picker.
        GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 200 || onSwipeSymbol == null) return;
            onSwipeSymbol!(velocity < 0);
          },
          child: Container(
            width: double.infinity,
            color: colors.primary.withValues(alpha: 0.14),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: Coin Picker & Price
                InkWell(
                  onTap: onPickCoin,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      SymbolAvatar(
                        label: instrument.base,
                        color: colors.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                instrument.displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.foreground,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 16,
                                color: colors.mutedForeground,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            price > 0 ? instrument.formatPrice(price) : '—',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: colors.foreground,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right: Percentage Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 14,
                        color: accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        price > 0
                            ? '${up ? '+' : ''}${change.toStringAsFixed(2)}%'
                            : '—',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Toolbar (Timeframe + Style + Indicators)
        AnimatedBuilder(
          animation: chart,
          builder: (context, _) => ChartToolbar(
            timeframe: chart.timeframe,
            onTimeframe: onTimeframe,
            style: style,
            onToggleStyle: onToggleStyle,
            onIndicators: onIndicators,
            fullscreen: false,
            onToggleFullscreen: onOpenFullChart,
          ),
        ),

        // Interactive Chart Canvas (230px high)
        SizedBox(
          height: 230,
          child: AnimatedBuilder(
            animation: chart,
            builder: (context, _) =>
                ChartView(controller: chart, drawings: drawings, style: style),
          ),
        ),
      ],
    );
  }
}


