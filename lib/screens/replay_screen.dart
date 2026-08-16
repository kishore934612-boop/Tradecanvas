/// Replay Mode — step through a symbol's history bar-by-bar.
///
/// A separate screen from the live Chart screen: it opens on a fixed
/// historical window (no live prices, no kline stream) and adds transport
/// controls (play/pause, speed, seek, step) below the chart. Drawing tools
/// still work, since [ChartView] only depends on the shared
/// [ChartDataSource] contract.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/chart/chart_painter.dart' show ChartStyle;
import 'package:app/components/chart/chart_toolbar.dart';
import 'package:app/components/chart/chart_view.dart';
import 'package:app/components/chart/indicator_sheet.dart';
import 'package:app/components/chart/drawing_toolbar.dart';
import 'package:app/constants/colors.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/replay_controller.dart';
import 'package:app/models/instrument.dart';
import 'package:app/providers/market_data_provider.dart';
import 'package:app/screens/symbol_search_screen.dart';
import 'package:app/services/symbol_registry.dart';
import 'package:app/utils/haptics.dart';
import 'package:app/components/chart/quick_action_toolbar.dart';
import 'package:app/engine/magnetic_snap.dart';
import 'package:app/models/drawing.dart';
import 'package:app/models/user_profile.dart';
import 'package:app/providers/app_state.dart';
import 'package:app/models/replay_trade.dart';
import 'package:app/screens/backtest_analytics_screen.dart';



class ReplayScreen extends StatefulWidget {
  final Instrument instrument;

  const ReplayScreen({super.key, required this.instrument});

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late ReplayController _replay;
  late DrawingController _drawings;
  late Instrument _instrument;

  final GlobalKey<ChartViewRefState> _chartViewKey =
      GlobalKey<ChartViewRefState>();

  ChartStyle _style = ChartStyle.candles;

  final List<ReplayTrade> _replayTrades = [];

  ReplayTrade? get _openTrade =>
      _replayTrades.any((t) => t.isOpen) ? _replayTrades.firstWhere((t) => t.isOpen) : null;

  void _openLong() {
    if (_openTrade != null) return;
    final current = _replay.candles.lastOrNull;
    if (current == null) return;
    Haptics.selection();
    setState(() {
      _replayTrades.add(ReplayTrade(
        symbol: _instrument.symbol,
        isLong: true,
        entryPrice: current.close,
        entryTime: current.timestamp,
      ));
    });
  }

  void _openShort() {
    if (_openTrade != null) return;
    final current = _replay.candles.lastOrNull;
    if (current == null) return;
    Haptics.selection();
    setState(() {
      _replayTrades.add(ReplayTrade(
        symbol: _instrument.symbol,
        isLong: false,
        entryPrice: current.close,
        entryTime: current.timestamp,
      ));
    });
  }

  void _closePosition() {
    final open = _openTrade;
    if (open == null) return;
    final current = _replay.candles.lastOrNull;
    if (current == null) return;
    Haptics.medium();
    setState(() {
      open.exitPrice = current.close;
      open.exitTime = current.timestamp;
    });
  }

  void _showBacktestAnalytics() {
    Haptics.selection();
    final currentPrice = _replay.candles.lastOrNull?.close ?? 1.0;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BacktestAnalyticsScreen(
          instrument: _instrument,
          trades: _replayTrades,
          currentPrice: currentPrice,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _instrument = widget.instrument;
    _createControllers(_instrument);
  }

  void _createControllers(Instrument instrument) {
    final replay = ReplayController(
      provider: serviceLocator<BinanceProvider>(),
      logger: serviceLocator<Logger>(),
      instrument: instrument,
      timeframe: Timeframe.h1,
    );

    // Drawings are keyed with a `replay:` prefix so replay sketches never mix
    // with — or get overwritten by — the live chart's saved drawings for the
    // same symbol.
    final drawings = DrawingController(
      repository: serviceLocator<DrawingRepository>(),
      logger: serviceLocator<Logger>(),
      symbol: 'replay:${instrument.symbol}',
    );

    _replay = replay;
    _drawings = drawings;
    _instrument = instrument;

    replay.load();
    drawings.load();
  }

  @override
  void dispose() {
    _replay.dispose();
    _drawings.dispose();
    super.dispose();
  }

  // ==========================================================
  // ACTIONS
  // ==========================================================

  Future<void> _setTimeframe(Timeframe tf) async {
    Haptics.selection();
    await _replay.setTimeframe(tf);
  }

  void _toggleStyle() {
    Haptics.selection();
    setState(() {
      _style = _style == ChartStyle.candles
          ? ChartStyle.area
          : ChartStyle.candles;
    });
  }

  Future<void> _pickCoin() async {
    Haptics.light();
    final picked = await Navigator.of(context).push<Instrument>(
      MaterialPageRoute(
        builder: (_) => const SymbolSearchScreen(pickMode: true),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.symbol == _instrument.symbol) return;

    _drawings.dispose();
    setState(() => _createControllers(picked));
  }

  /// Swipe left/right on the header to step to the next/previous watchlist
  /// symbol, matching the same gesture on the Dashboard and Chart screens.
  void _swipeSymbol(bool forward) {
    final market = context.read<MarketDataProvider>();
    final watchlist = market.watchlist;
    if (watchlist.length < 2) return;

    final registry = context.read<SymbolRegistry>();
    final currentIndex = watchlist.indexOf(_instrument.symbol);
    final baseIndex = currentIndex < 0 ? 0 : currentIndex;
    final nextIndex = (baseIndex + (forward ? 1 : -1)) % watchlist.length;
    final wrapped = nextIndex < 0 ? nextIndex + watchlist.length : nextIndex;

    final target = registry.resolve(watchlist[wrapped]);
    if (target.symbol == _instrument.symbol) return;

    Haptics.selection();
    _drawings.dispose();
    setState(() => _createControllers(target));
  }

  void _showDrawingToolsTray() {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final colors = AppColors.of(context);
        final appState = context.read<AppState>();
        final profile = appState.profile;

        final toolsList = [
          (
            name: 'Trend Line',
            icon: Icons.show_chart_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.trendline),
            active: _drawings.activeTool == DrawingTool.trendline,
          ),
          (
            name: 'Arrow',
            icon: Icons.north_east_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.arrow),
            active: _drawings.activeTool == DrawingTool.arrow,
          ),
          (
            name: 'Horizontal',
            icon: Icons.horizontal_rule_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.horizontalLine),
            active: _drawings.activeTool == DrawingTool.horizontalLine,
          ),
          (
            name: 'Vertical Line',
            icon: Icons.more_vert_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.verticalLine),
            active: _drawings.activeTool == DrawingTool.verticalLine,
          ),
          (
            name: 'Rectangle Box',
            icon: Icons.rectangle_outlined,
            action: () => _drawings.setActiveTool(DrawingTool.rectangle),
            active: _drawings.activeTool == DrawingTool.rectangle,
          ),
          (
            name: 'Triangle',
            icon: Icons.change_history_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.triangle),
            active: _drawings.activeTool == DrawingTool.triangle,
          ),
          (
            name: 'Fibonacci',
            icon: Icons.compress_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.fibRetracement),
            active: _drawings.activeTool == DrawingTool.fibRetracement,
          ),
          (
            name: 'Fib Extension',
            icon: Icons.timeline_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.fibExtension),
            active: _drawings.activeTool == DrawingTool.fibExtension,
          ),
          (
            name: 'Freehand Brush',
            icon: Icons.brush_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.brush),
            active: _drawings.activeTool == DrawingTool.brush,
          ),
          (
            name: 'Callout Box',
            icon: Icons.mark_chat_read_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.callout),
            active: _drawings.activeTool == DrawingTool.callout,
          ),
          (
            name: 'Text Label',
            icon: Icons.text_fields_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.text),
            active: _drawings.activeTool == DrawingTool.text,
          ),
          (
            name: 'Measurement',
            icon: Icons.straighten_rounded,
            action: () => _drawings.setActiveTool(DrawingTool.measurement),
            active: _drawings.activeTool == DrawingTool.measurement,
          ),
          (
            name: 'Crosshair: ${profile.crosshairMode.label}',
            icon: Icons.center_focus_strong_rounded,
            action: () => appState.setCrosshairMode(profile.crosshairMode.next),
            active: profile.crosshairMode != CrosshairMode.free,
          ),
          (
            name: profile.crosshairShowLabels ? 'Labels: On' : 'Labels: Off',
            icon: Icons.subtitles_rounded,
            action: () => appState.setCrosshairShowLabels(!profile.crosshairShowLabels),
            active: profile.crosshairShowLabels,
          ),
          (
            name: profile.autoScale ? 'Auto Scale: On' : 'Auto Scale: Off',
            icon: Icons.aspect_ratio_rounded,
            action: () => appState.setAutoScale(!profile.autoScale),
            active: profile.autoScale,
          ),
          (
            name: profile.chartLocked ? 'Chart Locked' : 'Lock Chart',
            icon: profile.chartLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            action: () => appState.setChartLocked(!profile.chartLocked),
            active: profile.chartLocked,
          ),
          (
            name: 'Magnet Snap',
            icon: Icons.auto_awesome_rounded,
            action: () => _drawings.cycleMagneticMode(),
            active: _drawings.magneticMode != MagneticMode.off,
          ),
          (
            name: 'Clear All',
            icon: Icons.delete_outline_rounded,
            action: () => _drawings.clearSymbol(),
            active: false,
          ),
        ];

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Drawing Tools',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.foreground,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: colors.foreground),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.15,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: toolsList.length,
                  itemBuilder: (context, index) {
                    final item = toolsList[index];
                    return InkWell(
                      onTap: () {
                        Haptics.selection();
                        item.action();
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: item.active
                              ? colors.primary.withValues(alpha: 0.15)
                              : colors.border.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: item.active ? colors.primary : colors.border,
                            width: item.active ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: item.active
                                  ? colors.primary
                                  : colors.foreground,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: item.active
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: item.active
                                    ? colors.primary
                                    : colors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              instrument: _instrument,
              onSwitchCoin: _pickCoin,
              onSwipeSymbol: _swipeSymbol,
              onAnalytics: _showBacktestAnalytics,
              onBack: () => Navigator.of(context).pop(),
            ),

            ChartToolbar(
              timeframe: _replay.timeframe,
              onTimeframe: _setTimeframe,
              style: _style,
              onToggleStyle: _toggleStyle,
              onIndicators: () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => IndicatorSheet(
                  enabled: _replay.enabledIndicators,
                  onToggle: (type) {
                    Haptics.selection();
                    setState(() {
                      _replay.toggleIndicator(type);
                    });
                  },
                ),
              ),
            ),

            Expanded(
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _replay,
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                      child: ChartView(
                        key: _chartViewKey,
                        controller: _replay,
                        drawings: _drawings,
                        style: _style,
                      ),
                    ),
                  ),


                  // Reset View Button
                  Positioned(
                    right: 12,
                    bottom: 74,
                    child: FloatingActionButton.small(
                      heroTag: 'replay_reset_view_btn',
                      onPressed: () {
                        Haptics.selection();
                        _chartViewKey.currentState?.resetView();
                      },
                      backgroundColor: colors.card,
                      foregroundColor: colors.foreground,
                      child: const Icon(Icons.restart_alt_rounded, size: 20),
                    ),
                  ),

                  // Draw Button opening Drawing Tools Tray
                  Positioned(
                    right: 12,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'replay_draw_tools_btn',
                      onPressed: _showDrawingToolsTray,
                      backgroundColor: colors.primary,
                      foregroundColor: colors.primaryForeground,
                      child: const Icon(Icons.edit_rounded, size: 20),
                    ),
                  ),

                  if (context.watch<AppState>().profile.chartLocked)
                    Positioned(
                      left: 12,
                      bottom: 16,
                      child: GestureDetector(
                        onTap: () {
                          Haptics.selection();
                          context.read<AppState>().setChartLocked(false);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Chart Locked',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_drawings.activeTool != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: QuickActionToolbar(
                        drawings: _drawings,
                        appState: context.watch<AppState>(),
                      ),
                    ),
                ],
              ),
            ),

            // Compact Backtesting & Transport Control Console
            Container(
              decoration: BoxDecoration(
                color: colors.card,
                border: Border(
                  top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Sleek Order Execution Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Row(
                      children: [
                        if (_openTrade == null) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.positive,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.north_rounded, size: 15),
                              label: const Text('BUY (LONG)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: _openLong,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.negative,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.south_rounded, size: 15),
                              label: const Text('SELL (SHORT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: _openShort,
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _openTrade!.isLong ? colors.positive : colors.negative,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _openTrade!.isLong ? 'LONG @ ${_openTrade!.entryPrice.toStringAsFixed(2)}' : 'SHORT @ ${_openTrade!.entryPrice.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: _openTrade!.isLong ? colors.positive : colors.negative,
                                    ),
                                  ),
                                  const Spacer(),
                                  Builder(builder: (context) {
                                    final price = _replay.candles.lastOrNull?.close ?? 1.0;
                                    final pnlVal = _openTrade!.pnl(price);
                                    return Text(
                                      '${pnlVal >= 0 ? '+' : ''}\$${pnlVal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: pnlVal >= 0 ? colors.positive : colors.negative,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: colors.primaryForeground,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _closePosition,
                            child: const Text('CLOSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 2. Playback Transport Bar
                  AnimatedBuilder(
                    animation: _replay,
                    builder: (context, _) => _TransportBar(replay: _replay),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  final Instrument instrument;
  final VoidCallback onSwitchCoin;
  final VoidCallback onBack;
  final VoidCallback onAnalytics;

  /// Called with `true` for a left-swipe (next symbol) or `false` for a
  /// right-swipe (previous symbol).
  final ValueChanged<bool>? onSwipeSymbol;

  const _Header({
    required this.instrument,
    required this.onSwitchCoin,
    required this.onBack,
    required this.onAnalytics,
    this.onSwipeSymbol,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 200 || onSwipeSymbol == null) return;
        onSwipeSymbol!(velocity < 0);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(
            bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: colors.foreground),
              onPressed: onBack,
            ),
            Expanded(
              child: InkWell(
                onTap: onSwitchCoin,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'REPLAY SIMULATOR',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        instrument.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: colors.foreground,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                        color: colors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.assessment_rounded, color: colors.primary),
              tooltip: 'Backtest Analytics',
              onPressed: onAnalytics,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TRANSPORT CONTROLS
// ============================================================

class _TransportBar extends StatelessWidget {
  final ReplayController replay;

  const _TransportBar({required this.replay});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (replay.isLoading) {
      return _shell(
        colors,
        const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (replay.error != null || !replay.hasData) {
      return _shell(
        colors,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              replay.error ?? 'No data',
              style: TextStyle(color: colors.mutedForeground, fontSize: 12),
            ),
          ),
        ),
      );
    }

    return _shell(
      colors,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seekBar(context, colors),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${replay.barsElapsed} / ${replay.totalBars} bars',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colors.mutedForeground,
                  ),
                ),
              ),
              for (final s in ReplaySpeed.values) ...[
                _SpeedChip(
                  speed: s,
                  active: replay.speed == s,
                  onTap: () {
                    Haptics.selection();
                    replay.setSpeed(s);
                  },
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TransportButton(
                icon: Icons.restart_alt_rounded,
                tooltip: 'Restart',
                onTap: () {
                  Haptics.light();
                  replay.restart();
                },
              ),
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Step back',
                enabled: !replay.isAtStart,
                onTap: () {
                  Haptics.light();
                  replay.stepBackward();
                },
              ),
              _PlayButton(replay: replay),
              _TransportButton(
                icon: Icons.skip_next_rounded,
                tooltip: 'Step forward',
                enabled: !replay.isAtEnd,
                onTap: () {
                  Haptics.light();
                  replay.stepForward();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seekBar(BuildContext context, ThemePalette colors) {
    return SizedBox(
      height: 20,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        ),
        child: Slider(
          value: replay.progress.clamp(0.0, 1.0),
          activeColor: colors.primary,
          inactiveColor: colors.border,
          onChangeStart: (_) => Haptics.light(),
          onChanged: (v) => replay.seekToProgress(v),
        ),
      ),
    );
  }

  Widget _shell(ThemePalette colors, Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: child,
    );
  }
}

class _PlayButton extends StatelessWidget {
  final ReplayController replay;
  const _PlayButton({required this.replay});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: () {
          Haptics.medium();
          replay.togglePlay();
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: colors.primaryGradient,
          ),
          child: Icon(
            replay.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 26,
            color: colors.brightness == Brightness.dark
                ? Colors.black
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;

  const _TransportButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 24,
        color: enabled
            ? colors.foreground
            : colors.mutedForeground.withValues(alpha: 0.4),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  final ReplaySpeed speed;
  final bool active;
  final VoidCallback onTap;

  const _SpeedChip({
    required this.speed,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? colors.primary : colors.border),
        ),
        child: Text(
          speed.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? colors.primary : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}
