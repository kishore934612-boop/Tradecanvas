/// Replay Mode — step through a symbol's history bar-by-bar.
///
/// A separate screen from the live Chart screen: it opens on a fixed
/// historical window (no live prices, no kline stream) and adds transport
/// controls (play/pause, speed, seek, step) below the chart. Drawing tools
/// still work, since [ChartView] only depends on the shared
/// [ChartDataSource] contract.
///
/// Enhanced with:
/// - Full order execution engine (Market, Limit, Stop-Market)
/// - TP/SL auto-execution with draggable chart lines
/// - Account balance tracking with session P&L
/// - Discipline guardrails (max drawdown, consecutive losses, max trades)
/// - Multi-timeframe SMC dashboard HUD
/// - Volume Profile overlay
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/components/chart/chart_painter.dart' show ChartStyle;
import 'package:app/components/chart/chart_quick_dropdown_menu.dart';
import 'package:app/components/chart/chart_toolbar.dart';
import 'package:app/components/chart/chart_view.dart';
import 'package:app/components/chart/indicator_sheet.dart';
import 'package:app/components/chart/mtf_smc_dashboard.dart';
import 'package:app/components/replay/cooldown_overlay.dart';
import 'package:app/components/replay/risk_calculator_widget.dart';
import 'package:app/analysis_tools/models/analysis_type.dart';
import 'package:app/constants/colors.dart';
import 'package:app/core/di/service_locator.dart';
import 'package:app/core/logging/logger.dart';
import 'package:app/data/providers/market/binance_provider.dart';
import 'package:app/domain/repositories/drawing_repository.dart';
import 'package:app/engine/discipline_guardrails.dart';
import 'package:app/engine/drawing_controller.dart';
import 'package:app/engine/replay_controller.dart';
import 'package:app/models/instrument.dart';
import 'package:app/models/replay_order.dart';
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
  bool _isScrolledAway = false;

  /// Selected order type for the order entry panel.
  OrderType _orderType = OrderType.market;

  /// TP/SL input enablement.
  bool _tpEnabled = false;
  final bool _slEnabled = true;
  OrderSide _calculatorSide = OrderSide.buy;

  /// Limit/stop price for non-market orders.
  final TextEditingController _limitPriceController = TextEditingController();
  final TextEditingController _tpController = TextEditingController();
  final TextEditingController _slController = TextEditingController();

  /// Convert closed ReplayOrders to ReplayTrades for backtest analytics.
  List<ReplayTrade> get _replayTrades =>
      [..._replay.closedTrades, ..._replay.openPositions]
          .map((o) => ReplayTrade.fromOrder(o, _instrument.symbol))
          .toList();

  void _showOrderMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _placeOrder(OrderSide side) {
    _calculatorSide = side;
    final price = _orderType == OrderType.market ? _replay.lastPrice
        : double.tryParse(_limitPriceController.text);
    final sl = double.tryParse(_slController.text);
    final tp = _tpEnabled ? double.tryParse(_tpController.text) : null;
    if (price == null || sl == null || (_tpEnabled && tp == null)) {
      _showOrderMessage('Enter a valid entry, required stop loss and enabled target.');
      return;
    }
    final calc = _replay.calculateOrderRisk(side: side, type: _orderType,
        price: price, stopLossPrice: sl, takeProfitPrice: tp);
    if (!calc.isValid) {
      _showOrderMessage(calc.error ?? 'Invalid trade plan.');
      return;
    }
    Haptics.selection();
    final id = _replay.placeOrder(side: side, type: _orderType, price: price,
      stopLossPrice: sl, takeProfitPrice: tp,
      positionSize: calc.positionSize, quantity: calc.quantity);
    _showOrderMessage(id == null ? _replay.lastOrderError ?? 'Order rejected.'
        : 'Paper order queued for the next bar. Estimated risk: '
          '${calc.riskAmount.toStringAsFixed(2)} ${_instrument.quote}.');
  }

  void _closePosition() {
    Haptics.medium();
    _replay.closePosition();
    setState(() {});
  }

  void _showBacktestAnalytics() {
    _replay.pause();
    Haptics.selection();
    final currentPrice = _replay.candles.lastOrNull?.close ?? 1.0;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BacktestAnalyticsScreen(
          instrument: _instrument,
          trades: _replayTrades,
          startingBalance: _replay.startingBalance,
          currentPrice: currentPrice,
        ),
      ),
    );
  }

  void _showRiskCalculator() {
    _replay.pause();
    Haptics.selection();
    final currentPrice = _orderType == OrderType.market ? _replay.lastPrice
        : double.tryParse(_limitPriceController.text) ?? 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RiskCalculatorWidget(
          accountBalance: _replay.accountBalance,
          entryPrice: currentPrice.toDouble(),
          stopLossPrice: double.tryParse(_slController.text),
          takeProfitPrice: double.tryParse(_tpController.text),
          isLong: _calculatorSide == OrderSide.buy,
          initialRiskPercent: _replay.riskPercent,
          includeEntrySlippage: _orderType != OrderType.limit,
          onApply: (calc) {
            _replay.setRiskPercent(calc.riskPercent);
            setState(() {
              if (calc.stopLossPrice > 0) {
                _slController.text = calc.stopLossPrice.toString();
              }
              _tpEnabled = calc.takeProfitPrice != null;
              _tpController.text = calc.takeProfitPrice?.toString() ?? '';
            });
          },
        ),
      ),
    );
  }

  void _showDisciplineSettings() {
    Haptics.selection();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DisciplineSettingsSheet(
        settings: _replay.disciplineSettings,
        onSave: (settings) {
          _replay.setDisciplineSettings(settings);
          setState(() {});
        },
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
    _limitPriceController.dispose();
    _tpController.dispose();
    _slController.dispose();
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
    _replay.dispose();
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
    _replay.dispose();
    setState(() => _createControllers(target));
  }

  // ignore: unused_element
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

        final categories = [
          (
            name: 'Smart Analysis (SMC)',
            tools: [
              (name: 'Bullish Order Block', icon: Icons.view_headline_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bullishOrderBlock), active: _drawings.activeAnalysisTool == AnalysisType.bullishOrderBlock, isDestructive: false),
              (name: 'Bearish Order Block', icon: Icons.table_rows_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bearishOrderBlock), active: _drawings.activeAnalysisTool == AnalysisType.bearishOrderBlock, isDestructive: false),
              (name: 'Bullish FVG', icon: Icons.unfold_more_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bullishFvg), active: _drawings.activeAnalysisTool == AnalysisType.bullishFvg, isDestructive: false),
              (name: 'Bearish FVG', icon: Icons.unfold_less_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bearishFvg), active: _drawings.activeAnalysisTool == AnalysisType.bearishFvg, isDestructive: false),
              (name: 'Break of Struct', icon: Icons.call_made_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bos), active: _drawings.activeAnalysisTool == AnalysisType.bos, isDestructive: false),
              (name: 'Change of Char', icon: Icons.change_circle_outlined, action: () => _drawings.setActiveAnalysisTool(AnalysisType.choch), active: _drawings.activeAnalysisTool == AnalysisType.choch, isDestructive: false),
            ],
          ),
          (
            name: 'Liquidity',
            tools: [
              (name: 'Buy-side Liquidity', icon: Icons.water_drop_outlined, action: () => _drawings.setActiveAnalysisTool(AnalysisType.bsl), active: _drawings.activeAnalysisTool == AnalysisType.bsl, isDestructive: false),
              (name: 'Sell-side Liquidity', icon: Icons.opacity_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.ssl), active: _drawings.activeAnalysisTool == AnalysisType.ssl, isDestructive: false),
              (name: 'Equilibrium (EQ)', icon: Icons.drag_handle_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.equilibrium), active: _drawings.activeAnalysisTool == AnalysisType.equilibrium, isDestructive: false),
            ],
          ),
          (
            name: 'Supply & Demand',
            tools: [
              (name: 'Supply Zone', icon: Icons.arrow_circle_up_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.supplyZone), active: _drawings.activeAnalysisTool == AnalysisType.supplyZone, isDestructive: false),
              (name: 'Demand Zone', icon: Icons.arrow_circle_down_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.demandZone), active: _drawings.activeAnalysisTool == AnalysisType.demandZone, isDestructive: false),
              (name: 'Premium Zone', icon: Icons.vertical_align_top_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.premiumZone), active: _drawings.activeAnalysisTool == AnalysisType.premiumZone, isDestructive: false),
              (name: 'Discount Zone', icon: Icons.vertical_align_bottom_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.discountZone), active: _drawings.activeAnalysisTool == AnalysisType.discountZone, isDestructive: false),
              (name: 'Support Level', icon: Icons.call_received_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.supportZone), active: _drawings.activeAnalysisTool == AnalysisType.supportZone, isDestructive: false),
              (name: 'Resistance Level', icon: Icons.call_made_rounded, action: () => _drawings.setActiveAnalysisTool(AnalysisType.resistanceZone), active: _drawings.activeAnalysisTool == AnalysisType.resistanceZone, isDestructive: false),
            ],
          ),
          (
            name: 'Lines & Rays',
            tools: [
              (name: 'Trend Line', icon: Icons.show_chart_rounded, action: () => _drawings.setActiveTool(DrawingTool.trendline), active: _drawings.activeTool == DrawingTool.trendline, isDestructive: false),
              (name: 'Arrow', icon: Icons.north_east_rounded, action: () => _drawings.setActiveTool(DrawingTool.arrow), active: _drawings.activeTool == DrawingTool.arrow, isDestructive: false),
              (name: 'Horizontal Line', icon: Icons.horizontal_rule_rounded, action: () => _drawings.setActiveTool(DrawingTool.horizontalLine), active: _drawings.activeTool == DrawingTool.horizontalLine, isDestructive: false),
              (name: 'Vertical Line', icon: Icons.more_vert_rounded, action: () => _drawings.setActiveTool(DrawingTool.verticalLine), active: _drawings.activeTool == DrawingTool.verticalLine, isDestructive: false),
            ],
          ),
          (
            name: 'Shapes & Freehand',
            tools: [
              (name: 'Rectangle Box', icon: Icons.rectangle_outlined, action: () => _drawings.setActiveTool(DrawingTool.rectangle), active: _drawings.activeTool == DrawingTool.rectangle, isDestructive: false),
              (name: 'Triangle', icon: Icons.change_history_rounded, action: () => _drawings.setActiveTool(DrawingTool.triangle), active: _drawings.activeTool == DrawingTool.triangle, isDestructive: false),
            ],
          ),
          (
            name: 'Fibonacci & Math',
            tools: [
              (name: 'Fibonacci', icon: Icons.compress_rounded, action: () => _drawings.setActiveTool(DrawingTool.fibRetracement), active: _drawings.activeTool == DrawingTool.fibRetracement, isDestructive: false),
              (name: 'Fib Extension', icon: Icons.timeline_rounded, action: () => _drawings.setActiveTool(DrawingTool.fibExtension), active: _drawings.activeTool == DrawingTool.fibExtension, isDestructive: false),
            ],
          ),
          (
            name: 'Annotations & Measurement',
            tools: [
              (name: 'Text Label', icon: Icons.text_fields_rounded, action: () => _drawings.setActiveTool(DrawingTool.text), active: _drawings.activeTool == DrawingTool.text, isDestructive: false),
              (name: 'Callout Box', icon: Icons.mark_chat_read_rounded, action: () => _drawings.setActiveTool(DrawingTool.callout), active: _drawings.activeTool == DrawingTool.callout, isDestructive: false),
              (name: 'Measurement', icon: Icons.straighten_rounded, action: () => _drawings.setActiveTool(DrawingTool.measurement), active: _drawings.activeTool == DrawingTool.measurement, isDestructive: false),
            ],
          ),
          (
            name: 'Chart Utilities',
            tools: [
              (name: 'Crosshair: ${profile.crosshairMode.label}', icon: Icons.center_focus_strong_rounded, action: () => appState.setCrosshairMode(profile.crosshairMode.next), active: profile.crosshairMode != CrosshairMode.free, isDestructive: false),
              (name: profile.crosshairShowLabels ? 'Labels: On' : 'Labels: Off', icon: Icons.subtitles_rounded, action: () => appState.setCrosshairShowLabels(!profile.crosshairShowLabels), active: profile.crosshairShowLabels, isDestructive: false),
              (name: profile.autoScale ? 'Auto Scale: On' : 'Auto Scale: Off', icon: Icons.aspect_ratio_rounded, action: () => appState.setAutoScale(!profile.autoScale), active: profile.autoScale, isDestructive: false),
              (name: profile.chartLocked ? 'Chart Locked' : 'Lock Chart', icon: profile.chartLocked ? Icons.lock_rounded : Icons.lock_open_rounded, action: () => appState.setChartLocked(!profile.chartLocked), active: profile.chartLocked, isDestructive: false),
              (name: 'Magnet Snap', icon: Icons.auto_awesome_rounded, action: () => _drawings.cycleMagneticMode(), active: _drawings.magneticMode != MagneticMode.off, isDestructive: false),
              (name: 'Clear All', icon: Icons.delete_outline_rounded, action: () => _drawings.clearSymbol(), active: false, isDestructive: true),
            ],
          ),
        ];

        int selectedCategoryIndex = 0;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final activeCategories = selectedCategoryIndex == -1
                ? categories
                : [categories[selectedCategoryIndex]];

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                        'Drawing & Analysis Tools',
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
                  const SizedBox(height: 8),

                  // Horizontal Category Switcher Chips Bar
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'All',
                          isSelected: selectedCategoryIndex == -1,
                          onTap: () {
                            Haptics.selection();
                            setSheetState(() => selectedCategoryIndex = -1);
                          },
                          colors: colors,
                        ),
                        const SizedBox(width: 6),
                        for (int i = 0; i < categories.length; i++) ...[
                          _CategoryChip(
                            label: categories[i].name,
                            isSelected: selectedCategoryIndex == i,
                            onTap: () {
                              Haptics.selection();
                              setSheetState(() => selectedCategoryIndex = i);
                            },
                            colors: colors,
                          ),
                          if (i < categories.length - 1) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: activeCategories.length,
                      itemBuilder: (context, catIdx) {
                        final cat = activeCategories[catIdx];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (selectedCategoryIndex == -1)
                              Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 6),
                                child: Text(
                                  cat.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.25,
                              ),
                              itemCount: cat.tools.length,
                              itemBuilder: (context, toolIdx) {
                                final item = cat.tools[toolIdx];
                                final isDestructive = item.isDestructive;

                                return InkWell(
                                  onTap: () {
                                    Haptics.selection();
                                    item.action();
                                    Navigator.pop(ctx);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.active
                                          ? colors.primary.withValues(alpha: 0.18)
                                          : colors.border.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDestructive
                                            ? colors.destructive.withValues(alpha: 0.5)
                                            : (item.active ? colors.primary : colors.border),
                                        width: item.active ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 22,
                                          color: isDestructive
                                              ? colors.destructive
                                              : (item.active
                                                    ? colors.primary
                                                    : colors.foreground),
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
                                            color: isDestructive
                                                ? colors.destructive
                                                : (item.active
                                                      ? colors.primary
                                                      : colors.foreground),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
        child: AnimatedBuilder(
          animation: _replay,
          builder: (context, _) {
            final openPos = _replay.openPosition;

            return Stack(
              children: [
                Column(
                  children: [
                    _Header(
                      instrument: _instrument,
                      onSwitchCoin: _pickCoin,
                      onSwipeSymbol: _swipeSymbol,
                      onAnalytics: _showBacktestAnalytics,
                      onBack: () => Navigator.of(context).pop(),
                      accountBalance: _replay.accountBalance,
                      sessionPnl: _replay.sessionPnl,
                      onDisciplineSettings: _showDisciplineSettings,
                      disciplineEnabled: _replay.disciplineSettings.enabled,
                    ),

                    ChartToolbar(
                      timeframe: _replay.timeframe,
                      onTimeframe: _setTimeframe,
                      style: _style,
                      onToggleStyle: _toggleStyle,
                      hasActiveIndicators: _replay.enabledIndicators.isNotEmpty,
                      onIndicators: () {
                        Haptics.selection();
                        showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
                              child: IndicatorSheet(
                                enabled: _replay.enabledIndicators,
                                onToggle: (type) {
                                  Haptics.selection();
                                  setState(() {
                                    _replay.toggleIndicator(type);
                                  });
                                },
                                indicatorStyles: _replay.indicatorStyles,
                                onIndicatorStyleChanged: (type, style) {
                                  Haptics.selection();
                                  setState(() {
                                    _replay.setIndicatorStyle(type, style);
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                            child: ChartView(
                              key: _chartViewKey,
                              controller: _replay,
                              drawings: _drawings,
                              style: _style,
                              onScrolledAwayChanged: (scrolled) {
                                if (_isScrolledAway != scrolled) {
                                  setState(() => _isScrolledAway = scrolled);
                                }
                              },
                            ),
                          ),

                          // MTF SMC Dashboard overlay (top-right).
                          if (_replay.htfTrend != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: MtfSmcDashboard(
                                htfTrend: _replay.htfTrend,
                                htfLabel: _replay.htfTimeframe.label,
                                ltfLabel: _replay.timeframe.label,
                                currentPrice: _replay.lastPrice,
                              ),
                            ),

                          // Live Price Reset Button.
                          if (_isScrolledAway)
                            Positioned(
                              right: 12,
                              bottom: 64,
                              child: FloatingActionButton.small(
                                heroTag: 'replay_reset_view_btn',
                                onPressed: () {
                                  Haptics.selection();
                                  _chartViewKey.currentState?.resetView();
                                },
                                backgroundColor: colors.primary,
                                foregroundColor: colors.primaryForeground,
                                tooltip: 'Jump to Live Price',
                                child: const Icon(Icons.arrow_forward_rounded, size: 20),
                              ),
                            ),

                          // Dropdown Menu.
                          Positioned(
                            right: 12,
                            bottom: 16,
                            child: ChartQuickDropdownMenu(
                              onOpenTools: _showDrawingToolsTray,
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            child: Text('PAPER ONLY · 1x buying power · next-bar entries · '
                                '${_replay.execution.feePercent}% fee/side · '
                                '${_replay.execution.slippagePercent}% market slippage',
                                style: TextStyle(fontSize: 9, color: colors.mutedForeground)),
                          ),
                          if (_replay.activeViolation != null && openPos != null)
                            Text('New entries locked: ${_replay.activeViolation!.label}. You may still close this position.',
                                style: TextStyle(fontSize: 10, color: colors.negative)),
                          if (_replay.lastOrderError != null)
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(_replay.lastOrderError!,
                                style: TextStyle(fontSize: 10, color: colors.negative))),
                          // Order Type Selector (Market / Limit / Stop).
                          if (openPos == null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                              child: Row(
                                children: [
                                  for (final type in OrderType.values) ...[
                                    _OrderTypeChip(
                                      label: type == OrderType.market
                                          ? 'Market'
                                          : type == OrderType.limit
                                              ? 'Limit'
                                              : 'Stop',
                                      active: _orderType == type,
                                      onTap: () {
                                        Haptics.selection();
                                        setState(() => _orderType = type);
                                      },
                                    ),
                                    if (type != OrderType.values.last)
                                      const SizedBox(width: 6),
                                  ],
                                  const Spacer(),
                                  // TP/SL toggles.
                                  _ToggleChip(
                                    label: 'SL*',
                                    active: _slEnabled,
                                    color: colors.negative,
                                    onTap: () {
                                      Haptics.selection();
                                      _showOrderMessage('A protective stop loss is required for every paper trade.');
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  _ToggleChip(
                                    label: 'TP',
                                    active: _tpEnabled,
                                    color: colors.positive,
                                    onTap: () {
                                      Haptics.selection();
                                      setState(() => _tpEnabled = !_tpEnabled);
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  // Risk calculator button.
                                  InkWell(
                                    onTap: _showRiskCalculator,
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: colors.border),
                                      ),
                                      child: Icon(Icons.calculate_rounded, size: 14, color: colors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Limit/Stop price input & TP/SL inputs.
                          if (openPos == null && (_orderType != OrderType.market || _slEnabled || _tpEnabled))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                              child: Row(
                                children: [
                                  if (_orderType != OrderType.market)
                                    Expanded(
                                      child: _CompactInput(
                                        label: _orderType == OrderType.limit ? 'Limit Price' : 'Stop Price',
                                        controller: _limitPriceController,
                                        color: const Color(0xFFF59E0B),
                                        colors: colors,
                                      ),
                                    ),
                                  if (_orderType != OrderType.market && (_slEnabled || _tpEnabled))
                                    const SizedBox(width: 6),
                                  if (_slEnabled)
                                    Expanded(
                                      child: _CompactInput(
                                        label: 'Stop Loss',
                                        controller: _slController,
                                        color: colors.negative,
                                        colors: colors,
                                      ),
                                    ),
                                  if (_slEnabled && _tpEnabled)
                                    const SizedBox(width: 6),
                                  if (_tpEnabled)
                                    Expanded(
                                      child: _CompactInput(
                                        label: 'Take Profit',
                                        controller: _tpController,
                                        color: colors.positive,
                                        colors: colors,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          // Order Execution Buttons / Open Position Card.
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                            child: Row(
                              children: [
                                if (openPos == null) ...[
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
                                      label: Text(
                                        _orderType == OrderType.market ? 'BUY (LONG)' : 'BUY ${_orderType.name.toUpperCase()}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      onPressed: _replay.hasOpenOrPendingOrder || _replay.isAtEnd || _replay.isLoading
                                          ? null : () => _placeOrder(OrderSide.buy),
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
                                      label: Text(
                                        _orderType == OrderType.market ? 'SELL (SHORT)' : 'SELL ${_orderType.name.toUpperCase()}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                      ),
                                      onPressed: _replay.hasOpenOrPendingOrder || _replay.isAtEnd || _replay.isLoading
                                          ? null : () => _placeOrder(OrderSide.sell),
                                    ),
                                  ),
                                ] else ...[
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: colors.background,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: openPos.isLong ? colors.positive : colors.negative,
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${openPos.isLong ? "LONG" : "SHORT"} @ ${(openPos.fillPrice ?? 0).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: openPos.isLong ? colors.positive : colors.negative,
                                                ),
                                              ),
                                              if (openPos.stopLossPrice != null || openPos.takeProfitPrice != null)
                                                Text(
                                                  [
                                                    if (openPos.stopLossPrice != null) 'SL: ${openPos.stopLossPrice!.toStringAsFixed(2)}',
                                                    if (openPos.takeProfitPrice != null) 'TP: ${openPos.takeProfitPrice!.toStringAsFixed(2)}',
                                                  ].join(' · '),
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    color: colors.mutedForeground,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Builder(builder: (context) {
                                            final price = _replay.lastPrice;
                                            final pnlVal = openPos.unrealizedPnl(price);
                                            final pnlPct = openPos.unrealizedPnlPercent(price);
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${pnlVal >= 0 ? "+" : ""}\$${pnlVal.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: pnlVal >= 0 ? colors.positive : colors.negative,
                                                  ),
                                                ),
                                                Text(
                                                  '${pnlPct >= 0 ? "+" : ""}${pnlPct.toStringAsFixed(2)}%',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: pnlPct >= 0 ? colors.positive : colors.negative,
                                                  ),
                                                ),
                                              ],
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

                          // Pending orders chips.
                          if (_replay.pendingOrders.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
                              child: SizedBox(
                                height: 28,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _replay.pendingOrders.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                                  itemBuilder: (_, i) {
                                    final order = _replay.pendingOrders[i];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${order.side.name.toUpperCase()} ${order.type == OrderType.market ? "MKT NEXT BAR" : order.type == OrderType.limit ? "LMT" : "STP"} @ ${order.price.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () {
                                              Haptics.light();
                                              _replay.cancelOrder(order.id);
                                              setState(() {});
                                            },
                                            child: Icon(Icons.close_rounded, size: 12, color: colors.mutedForeground),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          // Playback Transport Bar.
                          _TransportBar(replay: _replay),
                        ],
                      ),
                    ),
                  ],
                ),

                // Cooldown overlay (discipline guardrail violated).
                if (_replay.activeViolation != null && openPos == null)
                  Positioned.fill(
                    child: CooldownOverlay(
                      violation: _replay.activeViolation!,
                      drawdownPercent: _replay.drawdownPercent,
                      consecutiveLosses: _replay.consecutiveLosses,
                      totalTrades: _replay.totalTradesTaken,
                      maxTrades: _replay.disciplineSettings.maxTradesPerSession,
                      sessionPnl: _replay.sessionPnl,
                      wins: _replay.closedTrades.where((t) => t.realizedPnl() > 0).length,
                      losses: _replay.closedTrades.where((t) => t.realizedPnl() < 0).length,
                      onReviewTrades: _showBacktestAnalytics,
                      onResetSession: () {
                        _replay.resetSession();
                        setState(() {});
                      },
                    ),
                  ),
              ],
            );
          },
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
  final double accountBalance;
  final double sessionPnl;
  final VoidCallback? onDisciplineSettings;
  final bool disciplineEnabled;

  /// Called with `true` for a left-swipe (next symbol) or `false` for a
  /// right-swipe (previous symbol).
  final ValueChanged<bool>? onSwipeSymbol;

  const _Header({
    required this.instrument,
    required this.onSwitchCoin,
    required this.onBack,
    required this.onAnalytics,
    required this.accountBalance,
    required this.sessionPnl,
    this.onDisciplineSettings,
    this.disciplineEnabled = false,
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: InkWell(
                onTap: onSwitchCoin,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'REPLAY',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            instrument.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.foreground,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: colors.mutedForeground,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Account balance & session P&L.
                      Row(
                        children: [
                          Text(
                            '\$${accountBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.foreground,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: (sessionPnl >= 0 ? colors.positive : colors.negative)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${sessionPnl >= 0 ? "+" : ""}\$${sessionPnl.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: sessionPnl >= 0 ? colors.positive : colors.negative,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Discipline settings.
            IconButton(
              icon: Icon(
                Icons.shield_rounded,
                color: disciplineEnabled ? colors.primary : colors.mutedForeground,
                size: 20,
              ),
              tooltip: 'Discipline Guardrails',
              onPressed: onDisciplineSettings,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(Icons.assessment_rounded, color: colors.primary, size: 20),
              tooltip: 'Backtest Analytics',
              onPressed: onAnalytics,
              visualDensity: VisualDensity.compact,
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
                tooltip: 'Restart and clear paper trades',
                onTap: () {
                  Haptics.light();
                  replay.restart();
                },
              ),
              _TransportButton(
                icon: Icons.skip_previous_rounded,
                tooltip: 'Step back',
                enabled: !replay.isAtStart && replay.canRewind,
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

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemePalette colors;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : colors.card.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? colors.primaryForeground : colors.foreground,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HELPER ORDER ENTRY WIDGETS
// ============================================================

class _OrderTypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OrderTypeChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? colors.primary.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? colors.primary : colors.border),
        ),
        child: Text(
          label,
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

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.color,
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
          color: active ? color.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: active ? color : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? color : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _CompactInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final ThemePalette colors;

  const _CompactInput({
    required this.label,
    required this.controller,
    required this.color,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          labelText: label,
          labelStyle: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          hintText: label,
          hintStyle: TextStyle(fontSize: 9, color: colors.mutedForeground),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: color, width: 1.2),
          ),
          filled: true,
          fillColor: colors.background,
        ),
      ),
    );
  }
}

class _DisciplineSettingsSheet extends StatefulWidget {
  final DisciplineSettings settings;
  final ValueChanged<DisciplineSettings> onSave;

  const _DisciplineSettingsSheet({
    required this.settings,
    required this.onSave,
  });

  @override
  State<_DisciplineSettingsSheet> createState() => _DisciplineSettingsSheetState();
}

class _DisciplineSettingsSheetState extends State<_DisciplineSettingsSheet> {
  late bool _enabled;
  late double _maxDrawdown;
  late int _maxLosses;
  late int _maxTrades;

  @override
  void initState() {
    super.initState();
    _enabled = widget.settings.enabled;
    _maxDrawdown = widget.settings.maxDailyDrawdownPercent;
    _maxLosses = widget.settings.maxConsecutiveLosses;
    _maxTrades = widget.settings.maxTradesPerSession;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Discipline Guardrails',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.foreground,
                ),
              ),
              const Spacer(),
              Switch(
                value: _enabled,
                activeThumbColor: colors.primary,
                onChanged: (v) => setState(() => _enabled = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Guardrails enforce risk rules during backtesting sessions to prevent overtrading and revenge trading.',
            style: TextStyle(fontSize: 11.5, color: colors.mutedForeground, height: 1.4),
          ),
          const SizedBox(height: 16),
          _SettingSlider(
            label: 'Max Peak Equity Drawdown',
            value: '${_maxDrawdown.toStringAsFixed(1)}%',
            sliderValue: _maxDrawdown,
            min: 1.0,
            max: 10.0,
            colors: colors,
            enabled: _enabled,
            onChanged: (v) => setState(() => _maxDrawdown = v),
          ),
          const SizedBox(height: 12),
          _SettingStepper(
            label: 'Max Consecutive Losses',
            value: '$_maxLosses trades',
            colors: colors,
            enabled: _enabled,
            onDecrement: _maxLosses > 1 ? () => setState(() => _maxLosses--) : null,
            onIncrement: _maxLosses < 10 ? () => setState(() => _maxLosses++) : null,
          ),
          const SizedBox(height: 12),
          _SettingStepper(
            label: 'Max Trades Per Session',
            value: '$_maxTrades trades',
            colors: colors,
            enabled: _enabled,
            onDecrement: _maxTrades > 1 ? () => setState(() => _maxTrades--) : null,
            onIncrement: _maxTrades < 50 ? () => setState(() => _maxTrades++) : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Haptics.medium();
                widget.onSave(widget.settings.copyWith(
                  enabled: _enabled,
                  maxDailyDrawdownPercent: _maxDrawdown,
                  maxConsecutiveLosses: _maxLosses,
                  maxTradesPerSession: _maxTrades,
                ));
                Navigator.pop(context);
              },
              child: const Text('Save Guardrail Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final String value;
  final double sliderValue;
  final double min;
  final double max;
  final ThemePalette colors;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.label,
    required this.value,
    required this.sliderValue,
    required this.min,
    required this.max,
    required this.colors,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: enabled ? colors.foreground : colors.mutedForeground)),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: enabled ? colors.primary : colors.mutedForeground)),
          ],
        ),
        Slider(
          value: sliderValue,
          min: min,
          max: max,
          activeColor: colors.primary,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _SettingStepper extends StatelessWidget {
  final String label;
  final String value;
  final ThemePalette colors;
  final bool enabled;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _SettingStepper({
    required this.label,
    required this.value,
    required this.colors,
    required this.enabled,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: enabled ? colors.foreground : colors.mutedForeground)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              onPressed: enabled ? onDecrement : null,
              color: colors.primary,
            ),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: enabled ? colors.foreground : colors.mutedForeground)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              onPressed: enabled ? onIncrement : null,
              color: colors.primary,
            ),
          ],
        ),
      ],
    );
  }
}

